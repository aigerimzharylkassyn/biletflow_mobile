import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event_creation.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import '../../services/event_creation_service.dart';
import 'event_creation_helpers.dart';
import 'paid_activation_panel.dart';
import '../../app/theme.dart';
import 'event_information_widgets.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.draftId, this.openReview = false});
  final String? draftId;
  final bool openReview;
  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _detailsForm = GlobalKey<FormState>(),
      _ticketsForm = GlobalKey<FormState>();
  late final EventCreationService _session;
  final _scroll = ScrollController();
  bool _loading = false, _busy = false, _paidActive = false;
  int _step = 0;
  String? _error;
  EventDraft get _details => _session.details;
  @override
  void initState() {
    super.initState();
    _session = EventCreationService(context.read<DataService>().api);
    if (widget.draftId != null) {
      _loading = true;
      _resume();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showStep(int value) {
    setState(() {
      _step = value;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _showError(Object error) {
    setState(() => _error = creationError(context, error));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _resume() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _session.resume(widget.draftId!);
      _paidActive = false;
      if (widget.openReview) _step = 2;
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDetails() async {
    if (_busy || !_detailsForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.saveDetails();
      if (mounted) _showStep(1);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTickets() async {
    if (_busy || !_ticketsForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.saveTickets();
      if (mounted) _showStep(2);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave({bool publish = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (publish) {
        _details.body();
        await _session.publish();
      }
      if (!mounted) return;
      await context.read<DataService>().refresh();
      if (!mounted) return;
      if (publish) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.organizerPublished)));
      }
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label,
          {int min = 0,
          int? max,
          bool venue = false,
          bool multiline = false,
          TextInputType? keyboard}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              key: ValueKey('detail-$key-0'),
              initialValue: _details.fields[key],
              enabled: !_busy && !(venue && _session.saved != null),
              decoration: InputDecoration(
                labelText: label,
                helperText: keyboard == null
                    ? creationTextHint(context, min: min, max: max)
                    : null,
                helperMaxLines: 4,
                errorMaxLines: 4,
              ),
              minLines: multiline ? 3 : 1,
              maxLines: multiline ? 6 : 1,
              maxLength: max,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              keyboardType: keyboard,
              onChanged: (v) => _details.fields[key] = v,
              validator: (v) =>
                  creationTextError(context, v, min: min, max: max)));
  Widget _detailsStep() {
    final l = context.l10n;
    return Form(
        key: _detailsForm,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EventInfoSection(
              title: l.creationPricing,
              icon: Icons.sell_outlined,
              highlight: true,
              children: [
                DropdownButtonFormField<bool>(
                  key: ValueKey('free-event-${_details.freeOnly}'),
                  initialValue: _details.freeOnly,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.creationPricing),
                  items: [
                    DropdownMenuItem(
                        value: true, child: Text(l.creationFreeEvent)),
                    DropdownMenuItem(
                        value: false, child: Text(l.creationPaidMixed)),
                  ],
                  onChanged: _busy ||
                          _session.tickets.any((ticket) =>
                              !ticket.canEdit &&
                              ticket.fields['kind'] == 'paid')
                      ? null
                      : (value) => setState(() {
                            _details.freeOnly = value!;
                            if (value) {
                              for (final ticket in _session.tickets
                                  .where((ticket) => ticket.canEdit)) {
                                ticket.fields['kind'] = 'free';
                                ticket.fields['price'] = '0';
                              }
                            }
                          }),
                ),
                const SizedBox(height: 12),
                Text(_details.freeOnly
                    ? l.creationFreeEventHelp
                    : l.creationPaidMixedHelp),
              ]),
          EventInfoSection(
              title: l.eventInfoSection,
              icon: Icons.article_outlined,
              children: [
                _field('title', l.organizerEventTitleLabel, min: 3, max: 250),
                DropdownButtonFormField<String>(
                  key: const ValueKey('event-category'),
                  initialValue: _details.fields['category'],
                  isExpanded: true,
                  decoration:
                      InputDecoration(labelText: l.organizerCategoryLabel),
                  items: [
                    for (final category in EventCategory.values)
                      DropdownMenuItem(
                          value: category.name,
                          child: Text(category.localizedLabel(l))),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _details.fields['category'] = value!),
                ),
                const SizedBox(height: 16),
                _field('banner', l.creationBanner, keyboard: TextInputType.url),
                _field('description', l.eventDescription,
                    min: 3, multiline: true),
              ]),
          EventInfoSection(
              title: l.eventScheduleSection,
              icon: Icons.event_outlined,
              children: [
                Text(l.creationTimezone,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                for (final item in [
                  ('starts', l.creationStarts),
                  ('ends', l.creationEnds),
                  ('opens', l.creationOpens),
                  ('closes', l.creationCloses)
                ])
                  CreationDateField(
                      label: item.$2,
                      value: _details.dates[item.$1],
                      enabled: !_busy,
                      onChanged: (v) =>
                          setState(() => _details.dates[item.$1] = v)),
              ]),
          EventInfoSection(
              title: l.eventVenueSection,
              icon: Icons.place_outlined,
              children: [
                _field('venue', l.organizerVenueLabel,
                    min: 2, max: 250, venue: true),
                _field('city', l.creationCity, min: 1, max: 120, venue: true),
                _field('address', l.creationAddress,
                    min: 3, max: 500, venue: true),
                if (_session.saved != null) ...[
                  Text(l.creationSavedVenue),
                  const SizedBox(height: 16)
                ],
              ]),
          EventInfoSection(
              title: l.eventAccessSection,
              icon: Icons.groups_outlined,
              children: [
                _field('capacity', l.creationCapacity,
                    min: 1, keyboard: TextInputType.number),
                DropdownButtonFormField<String>(
                    initialValue: _details.fields['visibility'],
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: l.creationVisibility),
                    items: [
                      for (final item in [
                        ('public', l.creationPublic),
                        ('unlisted', l.creationUnlisted),
                        ('private', l.creationPrivate)
                      ])
                        DropdownMenuItem(value: item.$1, child: Text(item.$2))
                    ],
                    onChanged: _busy
                        ? null
                        : (v) =>
                            setState(() => _details.fields['visibility'] = v!)),
                const SizedBox(height: 16),
              ]),
          EventInfoSection(
              title: l.refundPolicy,
              icon: Icons.policy_outlined,
              children: [
                _field(
                    'refund',
                    _details.freeOnly
                        ? l.refundPolicyOptional
                        : l.refundPolicyRequired,
                    min: _details.freeOnly ? 0 : 1,
                    multiline: true),
              ]),
          FilledButton(
              onPressed: _busy ? null : _saveDetails,
              child: Text(_busy ? l.commonLoading : l.creationSaveDetails)),
          if (_session.bannerFailed) ...[
            const SizedBox(height: 12),
            Text(l.creationBannerFailed),
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _session.skipBanner();
                          _error = null;
                          _step = 1;
                        }),
                child: Text(l.creationSkipBanner))
          ],
        ]));
  }

  Widget _ticketField(TicketDraft ticket, String key, String label,
          {int min = 0,
          int? max,
          TextInputType? keyboard,
          bool multiline = false,
          bool freePrice = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              key: ValueKey(
                  '${ticket.key}-$key-${freePrice ? ticket.fields['kind'] : ''}'),
              initialValue: freePrice && ticket.fields['kind'] == 'free'
                  ? '0'
                  : ticket.fields[key],
              enabled: !_busy &&
                  ticket.canEdit &&
                  !(freePrice && ticket.fields['kind'] == 'free'),
              decoration: InputDecoration(
                labelText: label,
                helperText: keyboard == null
                    ? creationTextHint(context, min: min, max: max)
                    : null,
                helperMaxLines: 4,
                errorMaxLines: 4,
              ),
              minLines: multiline ? 2 : 1,
              maxLines: multiline ? 5 : 1,
              maxLength: max,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              keyboardType: keyboard,
              onChanged: (v) => ticket.fields[key] = v,
              validator: (v) =>
                  creationTextError(context, v, min: min, max: max)));
  Widget _ticketsStep() {
    final l = context.l10n;
    return Form(
        key: _ticketsForm,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < _session.tickets.length; i++)
            _ticketCard(_session.tickets[i], i),
          OutlinedButton.icon(
              onPressed: _busy || _session.tickets.length >= 50
                  ? null
                  : () => setState(
                      () => _session.tickets.add(TicketDraft(_details))),
              icon: const Icon(Icons.add),
              label: Text(l.creationAddType)),
          TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _step = 0;
                        _error = null;
                      }),
              child: Text(l.creationBackDetails)),
          FilledButton(
              onPressed:
                  _busy || _session.tickets.isEmpty ? null : _saveTickets,
              child: Text(_busy ? l.commonLoading : l.creationSaveTickets)),
        ]));
  }

  Widget _ticketCard(TicketDraft ticket, int index) {
    final l = context.l10n;
    return Card(
        key: ValueKey(ticket.key),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${l.creationTicketType} ${index + 1}',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (ticket.savedId != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(ticket.editableSaved
                            ? l.managementCopiedTypeHelp
                            : l.creationSavedType))
                  else
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _session.tickets.remove(ticket)),
                            child: Text(l.creationRemoveType))),
                  _ticketField(ticket, 'name', l.creationTicketName,
                      min: 1, max: 150),
                  DropdownButtonFormField<String>(
                      initialValue: ticket.fields['kind'],
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: l.creationTicketKind),
                      items: [
                        DropdownMenuItem(
                            value: 'free', child: Text(l.eventFree)),
                        DropdownMenuItem(
                            value: 'paid', child: Text(l.creationPaid))
                      ],
                      onChanged: _busy || !ticket.canEdit || _details.freeOnly
                          ? null
                          : (v) => setState(() => ticket.fields['kind'] = v!)),
                  const SizedBox(height: 16),
                  _ticketField(
                      ticket, 'price', '${l.organizerPriceLabel} (KZT)',
                      freePrice: true,
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true)),
                  _ticketField(ticket, 'quantity', l.creationQuantity,
                      min: 1, keyboard: TextInputType.number),
                  CreationDateField(
                      label: l.creationSalesStart,
                      value: ticket.start,
                      enabled: !_busy && ticket.canEdit,
                      onChanged: (v) => setState(() => ticket.start = v)),
                  CreationDateField(
                      label: l.creationSalesEnd,
                      value: ticket.end,
                      enabled: !_busy && ticket.canEdit,
                      onChanged: (v) => setState(() => ticket.end = v)),
                  _ticketField(ticket, 'maximum', l.creationMaximum,
                      min: 1, keyboard: TextInputType.number),
                  _ticketField(
                      ticket, 'description', l.creationTicketDescription,
                      multiline: true),
                ])));
  }

  Widget _review() {
    final l = context.l10n;
    final hasPaid = _session.tickets.any((t) => t.fields['kind'] == 'paid');
    final images = _session.saved?['images'] as List? ?? [];
    final previousBanner = images.isEmpty
        ? ''
        : (images.first is String
            ? images.first as String
            : images.first['url'] as String? ?? '');
    final banner = _details.fields['banner']!.trim().isEmpty
        ? previousBanner
        : _details.fields['banner']!.trim();
    final dateFormat = DateFormat(
        'dd MMM yyyy · HH:mm', Localizations.localeOf(context).languageCode);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EventInfoSection(
          title: l.eventPreviewTitle,
          icon: Icons.fact_check_outlined,
          highlight: true,
          children: [
            if (banner.isNotEmpty) EventCover(url: banner),
            Text(_details.fields['title']!,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.eventPreviewHelp),
          ]),
      EventInfoSection(
          title: l.eventInfoSection,
          icon: Icons.article_outlined,
          children: [
            Text(_details.fields['description']!,
                style: const TextStyle(height: 1.6)),
          ]),
      EventInfoSection(
          title: l.eventScheduleSection,
          icon: Icons.event_outlined,
          children: [
            Text(l.creationTimezone,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            for (final item in [
              ('starts', l.creationStarts),
              ('ends', l.creationEnds),
              ('opens', l.creationOpens),
              ('closes', l.creationCloses)
            ])
              EventInfoRow(
                  icon: Icons.schedule_outlined,
                  label: item.$2,
                  value: dateFormat.format(_details.dates[item.$1]!)),
          ]),
      EventInfoSection(
          title: l.eventVenueSection,
          icon: Icons.place_outlined,
          children: [
            EventInfoRow(
                icon: Icons.location_on_outlined,
                label: l.organizerVenueLabel,
                value:
                    '${_details.fields['venue']}\n${_details.fields['address']} · ${_details.fields['city']}'),
          ]),
      EventInfoSection(
          title: l.eventAccessSection,
          icon: Icons.groups_outlined,
          children: [
            EventInfoRow(
                icon: Icons.groups_outlined,
                label: l.creationCapacity,
                value: _details.fields['capacity']!),
            EventInfoRow(
                icon: Icons.visibility_outlined,
                label: l.creationVisibility,
                value: switch (_details.fields['visibility']) {
                  'public' => l.creationPublic,
                  'unlisted' => l.creationUnlisted,
                  _ => l.creationPrivate
                }),
          ]),
      EventInfoSection(
          title: l.creationTickets,
          icon: Icons.confirmation_number_outlined,
          children: [
            for (final ticket in _session.tickets)
              EventInfoRow(
                  icon: Icons.local_activity_outlined,
                  label: ticket.fields['name']!,
                  value:
                      '${ticket.fields['quantity']} × ${ticket.fields['kind'] == 'free' ? l.eventFree : '${ticket.fields['price']} ₸'}'),
          ]),
      if (_details.fields['refund']!.trim().isNotEmpty)
        EventInfoSection(
            title: l.refundPolicy,
            icon: Icons.policy_outlined,
            children: [
              Text(_details.fields['refund']!,
                  style: const TextStyle(height: 1.6))
            ]),
      if (hasPaid)
        PaidActivationPanel(
            session: _session,
            onActive: (v) {
              if (mounted && v != _paidActive) setState(() => _paidActive = v);
            })
      else
        Text(l.creationFreeHelp),
      const SizedBox(height: 20),
      TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _step = 1;
                    _error = null;
                  }),
          child: Text(l.creationBackTickets)),
    ]);
  }

  Widget _reviewActions() {
    final l = context.l10n;
    final hasPaid = _session.tickets.any((t) => t.fields['kind'] == 'paid');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onPressed: _busy ? null : _leave,
                        child: Text(l.creationKeepDraft,
                            textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onPressed: _busy || (hasPaid && !_paidActive)
                            ? null
                            : () => _leave(publish: true),
                        child: Text(
                            _busy ? l.commonLoading : l.organizerPublish,
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
            backgroundColor: AppColors.caseBackground,
            appBar: AppBar(title: Text(l.organizerCreateEventTitle)),
            bottomNavigationBar:
                !_loading && _step == 2 && _session.saved != null
                    ? _reviewActions()
                    : null,
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                        Center(
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 760),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(l.eventCreationHelp,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge),
                                      const SizedBox(height: 16),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final item in [
                                              (0, l.creationDetails),
                                              (1, l.creationTickets),
                                              (2, l.creationReview)
                                            ])
                                              Chip(
                                                  label: Text(
                                                      '${item.$1 + 1}. ${item.$2}'),
                                                  backgroundColor: _step ==
                                                          item.$1
                                                      ? AppColors.primarySoft
                                                      : AppColors.surface),
                                          ]),
                                      const SizedBox(height: 16),
                                      if (_session.saved != null) ...[
                                        SelectableText(
                                            '${l.creationSavedDraft}: ${_session.id}'),
                                        const SizedBox(height: 16)
                                      ],
                                      if (_error != null) ...[
                                        Text(_error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                        const SizedBox(height: 16)
                                      ],
                                      if (widget.draftId != null &&
                                          _session.saved == null)
                                        OutlinedButton(
                                            onPressed: _resume,
                                            child: Text(l.commonRetry))
                                      else
                                        KeyedSubtree(
                                            key: ValueKey('step-$_step'),
                                            child: switch (_step) {
                                              0 => _detailsStep(),
                                              1 => _ticketsStep(),
                                              _ => _review()
                                            }),
                                      if (_session.saved != null &&
                                          _step != 2) ...[
                                        const SizedBox(height: 16),
                                        OutlinedButton(
                                            onPressed: _busy ? null : _leave,
                                            child: Text(l.creationKeepDraft))
                                      ],
                                    ]))),
                      ])));
  }
}
