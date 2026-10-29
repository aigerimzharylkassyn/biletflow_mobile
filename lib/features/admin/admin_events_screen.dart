import 'package:flutter/material.dart';
import '../organizer/event_management_screen.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../models/organizer_event_filter.dart';
import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/event_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import '../../shared/widgets/responsive_cards.dart';
import '../../shared/widgets/stat_card.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});
  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  OrganizerEventFilter _status = OrganizerEventFilter.all;
  EventCategory? _category;
  Map<String, dynamic>? _summary;
  String? _summaryError;
  bool _visible = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _loadSummary();
    _visible = visible;
  }

  Future<void> _loadSummary() async {
    try {
      final result = await context
          .read<AuthService>()
          .api
          .request('GET', '/admin/events/summary');
      if (mounted) {
        setState(() {
          _summary = Map<String, dynamic>.from(result);
          _summaryError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _summaryError = e.toString());
    }
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<DataService>().refresh(), _loadSummary()]);
  }

  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = context.watch<DataService>();
    final all = data.events;
    final now = DateTime.now();
    final labels = {
      OrganizerEventFilter.suspended: l.managementSuspended,
      OrganizerEventFilter.all: l.organizerEventsAll,
      OrganizerEventFilter.draft: l.eventStatusDraft,
      OrganizerEventFilter.upcoming: l.organizerEventsUpcoming,
      OrganizerEventFilter.active: l.organizerEventsActive,
      OrganizerEventFilter.past: l.organizerEventsPast,
      OrganizerEventFilter.completed: l.eventStatusCompleted,
      OrganizerEventFilter.cancelled: l.eventStatusCancelled
    };
    final matching = all
        .where((e) =>
            (_category == null || e.category == _category) &&
            '${e.title} ${e.organizerName}'.toLowerCase().contains(_query))
        .toList();
    final events = matching.where((e) => _status.matches(e, now)).toList();
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(l.adminManageEvents),
            actions: [
              IconButton(
                  tooltip: l.refreshStatus,
                  onPressed: data.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh))
            ]),
        body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(l.adminOverallStatistics,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ResponsiveCards(children: [
                    StatCard(
                        label: l.adminTotalEvents,
                        value: '${_summary?['events_total'] ?? '—'}',
                        icon: Icons.event_note_outlined),
                    StatCard(
                        label: l.eventStatusPublished,
                        value: '${_summary?['published_events'] ?? '—'}',
                        icon: Icons.public),
                    StatCard(
                        label: l.adminTicketsIssued,
                        value: '${_summary?['tickets_issued'] ?? '—'}',
                        icon: Icons.confirmation_number_outlined,
                        color: AppColors.success),
                    StatCard(
                        label: l.adminNetSales,
                        value: _summary == null
                            ? '—'
                            : '${((_summary!['confirmed_order_total_minor'] as num) / 100).toStringAsFixed(0)} ₸',
                        icon: Icons.payments_outlined,
                        color: AppColors.primaryInk),
                  ]),
                  const SizedBox(height: 12),
                  Text(l.adminStatisticsHelp,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_summaryError != null)
                    Text(_summaryError!,
                        style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 24),
                  TextField(
                      key: const ValueKey('admin-event-search'),
                      decoration: InputDecoration(
                          labelText: l.adminSearchEvents,
                          prefixIcon: const Icon(Icons.search)),
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase())),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final status in OrganizerEventFilter.values)
                      ChoiceChip(
                          label: Text(
                              '${labels[status]} (${matching.where((e) => status.matches(e, now)).length})'),
                          selected: _status == status,
                          onSelected: (_) => setState(() => _status = status))
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EventCategory?>(
                      key: const ValueKey('admin-event-category'),
                      initialValue: _category,
                      hint: Text(l.adminAllCategories),
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: l.organizerCategoryLabel),
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text(l.adminAllCategories)),
                        for (final c in EventCategory.values)
                          DropdownMenuItem(
                              value: c, child: Text(c.localizedLabel(l)))
                      ],
                      onChanged: (v) => setState(() => _category = v)),
                  const SizedBox(height: 16),
                  if (data.isLoading) const LinearProgressIndicator(),
                  if (data.errorMessage != null)
                    Text(data.errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  if (events.isEmpty && !data.isLoading)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.organizerEventsEmptyGroup)),
                  for (final event in events)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EventCard(
                            event: event,
                            trailingBadge:
                                EventStatusBadge(status: event.eventStatus),
                            onTap: () => _showEventStats(context, event))),
                ])));
  }

  void _showEventStats(BuildContext context, AppEvent event) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                EventManagementScreen(eventId: event.id, title: event.title)));
  }
}
