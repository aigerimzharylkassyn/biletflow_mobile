import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/staff_event_filter.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/event_card.dart';
import '../../shared/widgets/category_chip.dart';
import '../organizer/event_attendance_screen.dart';

class StaffEventsScreen extends StatefulWidget {
  const StaffEventsScreen({super.key});
  @override
  State<StaffEventsScreen> createState() => _StaffEventsScreenState();
}

class _StaffEventsScreenState extends State<StaffEventsScreen> {
  StaffEventFilter _filter = StaffEventFilter.all;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final l = context.l10n;
    final now = DateTime.now();
    final all = sortedStaffEvents(data.events);
    final events = all.where((event) => _filter.matches(event, now)).toList();
    final labels = {
      StaffEventFilter.all: l.organizerEventsAll,
      StaffEventFilter.upcoming: l.organizerEventsUpcoming,
      StaffEventFilter.live: l.staffEventsLive,
      StaffEventFilter.past: l.organizerEventsPast,
      StaffEventFilter.cancelled: l.eventStatusCancelled,
    };
    return Scaffold(
        appBar: AppBar(title: Text(l.staffAssignedEvents), actions: [
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: data.isLoading ? null : data.refresh,
              icon: const Icon(Icons.refresh)),
        ]),
        body: RefreshIndicator(
            onRefresh: data.refresh,
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final filter in StaffEventFilter.values)
                                    CategoryChip(
                                        label:
                                            '${labels[filter]} (${all.where((e) => filter.matches(e, now)).length})',
                                        selected: filter == _filter,
                                        onTap: () =>
                                            setState(() => _filter = filter)),
                                ]),
                                const SizedBox(height: 16),
                                Text(l.staffEventsTimeOrder,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                if (data.isLoading)
                                  const LinearProgressIndicator(),
                                if (data.errorMessage != null)
                                  Text(data.errorMessage!),
                                if (!data.isLoading && events.isEmpty)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 32),
                                      child: Text(
                                          all.isEmpty
                                              ? l.homeNoEvents
                                              : l.organizerEventsEmptyGroup,
                                          textAlign: TextAlign.center)),
                              ]))),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.builder(
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final group = StaffEventFilter.values.firstWhere(
                                (f) =>
                                    f != StaffEventFilter.all &&
                                    f.matches(event, now));
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: EventCard(
                                    event: event,
                                    trailingBadge: Text(labels[group]!,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                group == StaffEventFilter.live
                                                    ? const Color(0xFF176B3A)
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant)),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                EventAttendanceScreen(
                                                    eventId: event.id,
                                                    eventTitle:
                                                        event.title)))));
                          })),
                ])));
  }
}
