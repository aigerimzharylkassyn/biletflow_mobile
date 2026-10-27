import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/responsive_cards.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import '../attendee/attendee_ui.dart';
import 'event_attendees_screen.dart';
import 'ticket_inventory_screen.dart';
import '../operations/invitations_screen.dart';
import 'management_confirmation.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen(
      {super.key,
      required this.eventId,
      required this.title,
      this.historyOnly = false});
  final String eventId, title;
  final bool historyOnly;
  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  Map<String, dynamic>? _analytics;
  List<dynamic> _history = [];
  DateTimeRange? _range;
  String? _type;
  String _activity = '';
  String _tab = 'analytics';
  String? _error;
  bool _loading = true, _busy = false;
  int _request = 0;
  String? _eventStatus, _salesStatus;
  @override
  void initState() {
    super.initState();
    if (widget.historyOnly) _tab = 'history';
    if (!widget.historyOnly &&
        context.read<AuthService>().currentUser?.isAdmin == true) {
      _tab = 'operations';
    }
    _load();
  }

  Future<void> _load() async {
    final version = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<DataService>().api;
    final params = <String, String>{
      if (_range != null)
        'date_from': DateFormat('yyyy-MM-dd').format(_range!.start),
      if (_range != null)
        'date_to': DateFormat('yyyy-MM-dd').format(_range!.end),
    };
    try {
      // Both reads share the same date range; ticket filters only affect analytics.
      final values = await Future.wait([
        if (!widget.historyOnly)
          api.request(
              'GET',
              Uri(
                  path: '/events/${widget.eventId}/analytics',
                  queryParameters: {
                    ...params,
                    if (_type != null) 'ticket_type_id': _type!
                  }).toString()),
        api.request(
            'GET',
            Uri(path: '/events/${widget.eventId}/activity', queryParameters: {
              ...params,
              if (_activity.isNotEmpty) 'action': _activity
            }).toString()),
      ]);
      if (!mounted || version != _request) return;
      setState(() {
        if (!widget.historyOnly) {
          _analytics = Map<String, dynamic>.from(values.first as Map);
        }
        _history = values.last as List;
      });
    } catch (e) {
      if (mounted && version == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  Future<void> _dates() async {
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _range);
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _control(String action, String label) async {
    final reason = await managementReason(
        context, label, context.l10n.managementControlHelp);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<DataService>().api.request(
          'POST', '/admin/events/${widget.eventId}/controls',
          body: {'action': action, 'reason': reason});
      if (!mounted) return;
      setState(() {
        _eventStatus = result['status'];
        _salesStatus = result['paid_sales_status'];
      });
      await context.read<DataService>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.managementSuccess)));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children
          ])));

  String _activityLabel(String action) {
    final l = context.l10n;
    return switch (action) {
      'operations.suspend_event' => l.managementSuspendEvent,
      'operations.restore_event' => l.managementRestoreEvent,
      'operations.suspend_sales' => l.managementSuspendSales,
      'operations.restore_sales' => l.managementRestoreSales,
      'event.duplicated' || 'event.copy_created' => l.managementDuplicate,
      'event.cancelled' => l.eventStatusCancelled,
      'event.published' => l.eventStatusPublished,
      'event.unpublished' => l.eventStatusDraft,
      'order.refunded' => l.managementRefunds,
      'order.registration_cancelled' => l.managementCancelRegistration,
      'order.payment_failed' => l.statusFailed,
      _ => action.startsWith('support.')
          ? l.supportInbox
          : action.startsWith('ticket_type.')
              ? l.managementTypes
              : action.startsWith('ticket.')
                  ? l.managementChecked
                  : action.startsWith('order.')
                      ? l.managementOrders
                      : action.startsWith('campaign.')
                          ? l.managementCampaigns
                          : action.startsWith('paid_')
                              ? l.paidEventApplications
                              : l.managementEventActivity,
    };
  }

  Widget _metric(String label, Object? value, IconData icon) => StatCard(
      label: label,
      value: '${value ?? 0}',
      icon: icon,
      color: AppColors.primaryInk);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = _analytics;
    final admin = context.watch<AuthService>().currentUser?.isAdmin == true;
    final events = context
        .watch<DataService>()
        .events
        .where((e) => e.id == widget.eventId);
    final status =
        _eventStatus ?? (events.isEmpty ? '' : events.first.eventStatus);
    final sales =
        _salesStatus ?? (events.isEmpty ? '' : events.first.paidSalesStatus);
    final locked = status == 'cancelled' || status == 'completed';
    return Scaffold(
        backgroundColor: AppColors.caseBackground,
        appBar: AppBar(
            title: Text(
                widget.historyOnly ? l.managementHistory : l.managementTitle),
            actions: [
              IconButton(
                  tooltip: l.refreshStatus,
                  onPressed: _loading || _busy ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!widget.historyOnly &&
                                context.read<DataService>().events.length > 1)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<String>(
                                      initialValue: widget.eventId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: l.organizerMyEvents),
                                      items: [
                                        for (final e in context
                                            .read<DataService>()
                                            .events)
                                          DropdownMenuItem(
                                              value: e.id,
                                              child: Text(e.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                      ],
                                      onChanged: _busy
                                          ? null
                                          : (id) {
                                              if (id != null &&
                                                  id != widget.eventId) {
                                                final e = context
                                                    .read<DataService>()
                                                    .events
                                                    .firstWhere(
                                                        (e) => e.id == id);
                                                Navigator.pushReplacement(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            EventManagementScreen(
                                                                eventId: e.id,
                                                                title:
                                                                    e.title)));
                                              }
                                            })),
                            Text(widget.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            if (status.isNotEmpty)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: EventStatusBadge(status: status)),
                            const SizedBox(height: 16),
                            if (!widget.historyOnly)
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final entry in {
                                  'analytics': l.managementAnalytics,
                                  'history': l.managementHistory,
                                  if (admin)
                                    'operations': l.managementOperations
                                }.entries)
                                  ChoiceChip(
                                      label: Text(entry.value),
                                      selected: _tab == entry.key,
                                      onSelected: (_) =>
                                          setState(() => _tab = entry.key)),
                              ]),
                            const SizedBox(height: 16),
                            if (!widget.historyOnly) ...[
                              OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => EventAttendeesScreen(
                                              eventId: widget.eventId,
                                              eventTitle: widget.title))),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: Text(l.managementOrders)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => TicketInventoryScreen(
                                              eventId: widget.eventId,
                                              title: widget.title))),
                                  icon: const Icon(
                                      Icons.confirmation_number_outlined),
                                  label: Text(l.opsTickets)),
                              if (events.isNotEmpty &&
                                  events.first.visibility == 'private') ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => InvitationsScreen(
                                                eventId: widget.eventId,
                                                title: widget.title))),
                                    icon: const Icon(Icons.lock_outline),
                                    label: Text(l.opsInvitations)),
                              ],
                              const SizedBox(height: 16),
                            ],
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton.icon(
                                  onPressed: _loading ? null : _dates,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(_range == null
                                      ? l.managementAllDates
                                      : '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_range!.start)} – ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_range!.end)}')),
                              if (_range != null)
                                TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            setState(() => _range = null);
                                            _load();
                                          },
                                    child: Text(l.clearFilters))
                            ]),
                            if (!widget.historyOnly &&
                                a != null &&
                                _tab == 'analytics') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  key: ValueKey(_type),
                                  initialValue: _type ?? '',
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: l.managementTypes),
                                  items: [
                                    DropdownMenuItem(
                                        value: '',
                                        child: Text(l.managementAllTypes)),
                                    for (final t
                                        in a['available_ticket_types'] as List)
                                      DropdownMenuItem(
                                          value: t['id'] as String,
                                          child: Text(t['name']))
                                  ],
                                  onChanged: _loading
                                      ? null
                                      : (value) {
                                          setState(() => _type =
                                              value == '' ? null : value);
                                          _load();
                                        }),
                              const SizedBox(height: 12),
                              Text(l.managementDateHelp,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            const SizedBox(height: 16),
                            if (_loading || _busy)
                              const LinearProgressIndicator(),
                            if (_error != null)
                              _section(l.commonErrorGeneric, [
                                Text(_error!),
                                TextButton(
                                    onPressed: _load,
                                    child: Text(l.commonRetry))
                              ]),
                            if (!_loading &&
                                _error == null &&
                                a != null &&
                                !widget.historyOnly &&
                                _tab == 'analytics') ...[
                              _section(l.managementAnalytics, [
                                ResponsiveCards(children: [
                                  _metric(l.managementCapacity, a['capacity'],
                                      Icons.groups_outlined),
                                  _metric(l.managementSold, a['tickets_sold'],
                                      Icons.confirmation_number_outlined),
                                  _metric(
                                      l.managementRemaining,
                                      a['tickets_remaining'],
                                      Icons.event_seat_outlined),
                                ]),
                                const SizedBox(height: 16),
                                LinearProgressIndicator(
                                    value:
                                        ((a['percentage_sold'] as num? ?? 0) /
                                                100)
                                            .clamp(0, 1)),
                                const SizedBox(height: 8),
                                Text('${a['percentage_sold']}%'),
                                const SizedBox(height: 16),
                                ResponsiveCards(children: [
                                  _metric(
                                      l.managementPeriodTickets,
                                      a['cohort_tickets'] ?? a['tickets_sold'],
                                      Icons.confirmation_number_outlined),
                                  _metric(l.managementChecked, a['checked_in'],
                                      Icons.how_to_reg),
                                  _metric(l.managementAbsent, a['absent'],
                                      Icons.person_outline),
                                  _metric(
                                      l.managementChecked,
                                      '${a['check_in_percentage']}%',
                                      Icons.percent),
                                ])
                              ]),
                              _section(l.managementNet, [
                                Text(l.managementSimulation),
                                const SizedBox(height: 16),
                                ResponsiveCards(children: [
                                  _metric(
                                      l.managementGross,
                                      money(a['gross_sales_minor'] ?? 0),
                                      Icons.payments_outlined),
                                  _metric(
                                      l.managementDiscounts,
                                      money(a['discounts_minor'] ?? 0),
                                      Icons.discount_outlined),
                                  _metric(
                                      l.managementFees,
                                      money(a['processing_fees_minor'] ?? 0),
                                      Icons.receipt_outlined),
                                  _metric(
                                      l.managementRefunds,
                                      money(a['refunds_minor'] ?? 0),
                                      Icons.undo),
                                  _metric(
                                      l.managementNet,
                                      money(a['net_revenue_minor'] ?? 0),
                                      Icons.account_balance_wallet_outlined),
                                ])
                              ]),
                              _section(l.managementSalesSeries, [
                                if ((a['sales_series'] as List).isEmpty)
                                  Text(l.managementNoData),
                                for (final row in a['sales_series'] as List)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                                '${row['date']} · ${row['tickets']} ${l.managementIssued.toLowerCase()}'),
                                            Text(money(row['revenue_minor'])),
                                            const Divider()
                                          ]))
                              ]),
                              _section(l.managementTypes, [
                                for (final row in a['ticket_types'] as List)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(row['name'],
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                '${row['tickets']} / ${row['capacity']}'),
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(
                                                value: ((row['tickets']
                                                            as num) /
                                                        ((row['capacity']
                                                                    as num) ==
                                                                0
                                                            ? 1
                                                            : row['capacity']
                                                                as num))
                                                    .clamp(0, 1))
                                          ]))
                              ]),
                              _section(l.managementCampaigns, [
                                if ((a['campaigns'] as List).isEmpty)
                                  Text(l.managementNoData),
                                for (final c in a['campaigns'] as List)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('${c['name']} · ${c['code']}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                '${l.managementRedemptions}: ${c['redemptions']}'),
                                            Text(
                                                '${l.managementAttributedTickets}: ${c['tickets']}'),
                                            Text(
                                                '${l.managementNet}: ${money(c['revenue_minor'])}'),
                                            const Divider()
                                          ]))
                              ]),
                            ],
                            if (admin &&
                                !widget.historyOnly &&
                                _tab == 'operations')
                              _section(l.managementOperations, [
                                Text(
                                    sales == 'active'
                                        ? l.managementSalesActive
                                        : sales == 'suspended'
                                            ? l.managementSalesPaused
                                            : l.managementSalesNotReady,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 12),
                                Text(l.managementControlHelp),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                    onPressed: _busy || locked || status.isEmpty
                                        ? null
                                        : () => _control(
                                            status == 'suspended'
                                                ? 'restore_event'
                                                : 'suspend_event',
                                            status == 'suspended'
                                                ? l.managementRestoreEvent
                                                : l.managementSuspendEvent),
                                    icon:
                                        const Icon(Icons.pause_circle_outline),
                                    label: Text(status == 'suspended'
                                        ? l.managementRestoreEvent
                                        : l.managementSuspendEvent)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                    onPressed: _busy ||
                                            locked ||
                                            !['active', 'suspended']
                                                .contains(sales)
                                        ? null
                                        : () => _control(
                                            sales == 'suspended'
                                                ? 'restore_sales'
                                                : 'suspend_sales',
                                            sales == 'suspended'
                                                ? l.managementRestoreSales
                                                : l.managementSuspendSales),
                                    icon: const Icon(Icons.payments_outlined),
                                    label: Text(sales == 'suspended'
                                        ? l.managementRestoreSales
                                        : l.managementSuspendSales)),
                              ]),
                            if (_tab == 'history')
                              _section(l.managementHistory, [
                                DropdownButtonFormField<String>(
                                    initialValue: _activity,
                                    isExpanded: true,
                                    items: [
                                      for (final entry in {
                                        '': l.managementAllActivity,
                                        'event': l.managementEventActivity,
                                        'order': l.managementOrderActivity,
                                        'operations': l.managementOperations,
                                        'paid_review': l.paidEventApplications,
                                        'ticket': l.managementChecked,
                                        'ticket_type': l.managementTypes,
                                        'campaign': l.managementCampaigns,
                                        'support': l.supportInbox,
                                        'paid_sales': l.paidChecklist
                                      }.entries)
                                        DropdownMenuItem(
                                            value: entry.key,
                                            child: Text(entry.value))
                                    ],
                                    onChanged: _loading
                                        ? null
                                        : (value) {
                                            setState(() => _activity = value!);
                                            _load();
                                          }),
                                const SizedBox(height: 16),
                                if (!_loading &&
                                    _history.isEmpty &&
                                    _error == null)
                                  Text(l.managementNoData),
                                if (!_loading && _error == null)
                                  for (final row in _history)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: DecoratedBox(
                                            decoration: BoxDecoration(
                                                color: AppColors.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          _activityLabel(
                                                              row['action']
                                                                  as String),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelMedium),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          row['description'] ??
                                                              '',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          '${row['actor']} · ${(row['actor_roles'] as List).map((r) => switch (r) {
                                                                'organizer' =>
                                                                  l.adminRoleOrganizer,
                                                                'platform_admin' =>
                                                                  l.adminRoleAdmin,
                                                                'event_admin' =>
                                                                  l.adminRoleStaff,
                                                                _ =>
                                                                  l.adminRoleAttendee
                                                              }).join(', ')}'),
                                                      Text(DateFormat.yMMMd(
                                                              Localizations
                                                                      .localeOf(
                                                                          context)
                                                                  .toString())
                                                          .add_Hm()
                                                          .format(DateTime
                                                                  .parse(row[
                                                                      'created_at'])
                                                              .toLocal())),
                                                      SelectableText(
                                                          '${row['entity_type']} · ${row['entity_id']}',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall)
                                                    ])))),
                              ]),
                          ])))
            ])));
  }
}
