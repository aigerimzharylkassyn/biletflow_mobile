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

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.draftId});
  final String? draftId;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_details.fields['refund']!.isEmpty && _session.saved == null) {
      _details.fields['refund'] = context.l10n.creationDefaultRefund;
    }
  }

  Future<void> _resume() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _session.resume(widget.draftId!);
      _paidActive = _session.saved?['paid_sales_status'] == 'active';
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
          DropdownButtonFormField<bool>(
            key: ValueKey('free-event-${_details.freeOnly}'),
            initialValue: _details.freeOnly,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.creationPricing),
            items: [
              DropdownMenuItem(value: true, child: Text(l.creationFreeEvent)),
              DropdownMenuItem(value: false, child: Text(l.creationPaidMixed)),
            ],
            onChanged: _busy ||
                    _session.tickets.any((ticket) =>
                        ticket.savedId != null &&
                        ticket.fields['kind'] == 'paid')
                ? null
                : (value) => setState(() {
                      _details.freeOnly = value!;
                      if (value) {
                        for (final ticket in _session.tickets
                            .where((ticket) => ticket.savedId == null)) {
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
          const SizedBox(height: 20),
          _field('title', l.organizerEventTitleLabel, min: 3, max: 250),
          DropdownButtonFormField<String>(
            key: const ValueKey('event-category'),
            initialValue: _details.fields['category'],
            isExpanded: true,
            decoration: InputDecoration(labelText: l.organizerCategoryLabel),
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
          _field('description', l.eventDescription, min: 3, multiline: true),
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
                onChanged: (v) => setState(() => _details.dates[item.$1] = v)),
          _field('venue', l.organizerVenueLabel, min: 2, max: 250, venue: true),
          _field('city', l.creationCity, min: 1, max: 120, venue: true),
          _field('address', l.creationAddress, min: 3, max: 500, venue: true),
          if (_session.saved != null) ...[
            Text(l.creationSavedVenue),
            const SizedBox(height: 16)
          ],
          _field('capacity', l.creationCapacity,
              min: 1, keyboard: TextInputType.number),
          DropdownButtonFormField<String>(
              initialValue: _details.fields['visibility'],
              isExpanded: true,
              decoration: InputDecoration(labelText: l.creationVisibility),
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
                  : (v) => setState(() => _details.fields['visibility'] = v!)),
          const SizedBox(height: 16),
          _field('refund', l.refundPolicy, min: 1, multiline: true),
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
                  ticket.savedId == null &&
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
                        child: Text(l.creationSavedType))
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
                      onChanged: _busy ||
                              ticket.savedId != null ||
                              _details.freeOnly
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
                      enabled: !_busy && ticket.savedId == null,
                      onChanged: (v) => setState(() => ticket.start = v)),
                  CreationDateField(
                      label: l.creationSalesEnd,
                      value: ticket.end,
                      enabled: !_busy && ticket.savedId == null,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (banner.isNotEmpty)
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(banner,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 80,
                    child: Icon(Icons.image_not_supported_outlined)))),
      const SizedBox(height: 16),
      Text(_details.fields['title']!,
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(
          '${DateFormat('dd MMM yyyy HH:mm').format(_details.dates['starts']!)} – ${DateFormat('dd MMM yyyy HH:mm').format(_details.dates['ends']!)} · UTC+05:00'),
      const SizedBox(height: 12),
      Text(
          '${_details.fields['venue']} · ${_details.fields['address']} · ${_details.fields['city']}'),
      const SizedBox(height: 12),
      Text(_details.fields['description']!),
      const SizedBox(height: 12),
      Text('${l.creationCapacity}: ${_details.fields['capacity']}'),
      Text('${l.creationVisibility}: ${switch (_details.fields['visibility']) {
        'public' => l.creationPublic,
        'unlisted' => l.creationUnlisted,
        _ => l.creationPrivate
      }}'),
      const SizedBox(height: 12),
      Text('${l.refundPolicy}\n${_details.fields['refund']}'),
      for (final ticket in _session.tickets)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                '${ticket.fields['name']} · ${ticket.fields['quantity']} × ${ticket.fields['kind'] == 'free' ? l.eventFree : '${ticket.fields['price']} ₸'}')),
      const Divider(height: 32),
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
      const SizedBox(height: 12),
      FilledButton(
          onPressed: _busy || (hasPaid && !_paidActive)
              ? null
              : () => _leave(publish: true),
          child: Text(_busy ? l.commonLoading : l.organizerPublish)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
            appBar: AppBar(title: Text(l.organizerCreateEventTitle)),
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
                                      Text(l.creationTimezone),
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
                                                  backgroundColor:
                                                      _step == item.$1
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primaryContainer
                                                          : null),
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
                                      if (_session.saved != null) ...[
                                        const SizedBox(height: 16),
                                        OutlinedButton(
                                            onPressed: _busy ? null : _leave,
                                            child: Text(l.creationKeepDraft))
                                      ],
                                    ]))),
                      ])));
  }
}
