import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/organizer_event_filter.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/event_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import 'create_event_screen.dart';
import 'event_overview_screen.dart';
import '../../shared/widgets/paid_event_review_badge.dart';

class OrganizerEventsScreen extends StatefulWidget {
  const OrganizerEventsScreen({super.key});
  @override
  State<OrganizerEventsScreen> createState() => _OrganizerEventsScreenState();
}

class _OrganizerEventsScreenState extends State<OrganizerEventsScreen> {
  OrganizerEventFilter _filter = OrganizerEventFilter.all;
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
    final l = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();
    final all = data.eventsByOrganizer(user?.name ?? '');
    final now = DateTime.now();
    final labels = {
      OrganizerEventFilter.all: l.organizerEventsAll,
      OrganizerEventFilter.draft: l.eventStatusDraft,
      OrganizerEventFilter.upcoming: l.organizerEventsUpcoming,
      OrganizerEventFilter.active: l.organizerEventsActive,
      OrganizerEventFilter.past: l.organizerEventsPast,
      OrganizerEventFilter.completed: l.eventStatusCompleted,
      OrganizerEventFilter.cancelled: l.eventStatusCancelled,
    };
    final events = all.where((e) => _filter.matches(e, now)).toList();
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l.organizerMyEvents),
          actions: [
            IconButton(
                tooltip: l.refreshStatus,
                onPressed: data.isLoading ? null : data.refresh,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip: l.organizerCreateEvent,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateEventScreen()))),
          ]),
      body: RefreshIndicator(
          onRefresh: data.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final group in OrganizerEventFilter.values)
                          CategoryChip(
                            label:
                                '${labels[group]} (${all.where((e) => group.matches(e, now)).length})',
                            selected: _filter == group,
                            onTap: () => setState(() => _filter = group),
                          ),
                      ]))),
              if (data.isLoading)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (data.errorMessage != null)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton(
                            onPressed: data.refresh,
                            child: Text(
                                '${data.errorMessage}\n${l.commonRetry}')))),
              if (events.isEmpty && !data.isLoading)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          const Icon(Icons.event_busy_outlined, size: 48),
                          const SizedBox(height: 16),
                          Text(
                              all.isEmpty
                                  ? l.homeNoEvents
                                  : l.organizerEventsEmptyGroup,
                              textAlign: TextAlign.center)
                        ]))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EventCard(
                            event: event,
                            trailingBadge: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  EventStatusBadge(status: event.eventStatus),
                                  if (event.eventStatus == 'draft' &&
                                      event.paidReviewStatus !=
                                          'not_applicable') ...[
                                    const SizedBox(height: 8),
                                    PaidEventReviewBadge(
                                        status: event.paidReviewStatus),
                                  ],
                                  if (event.eventStatus != 'draft') ...[
                                    const SizedBox(height: 6),
                                    Text(l.organizerSoldOf(
                                        event.ticketsSold, event.ticketsTotal))
                                  ],
                                ]),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => event.eventStatus == 'draft'
                                        ? CreateEventScreen(
                                            draftId: event.id,
                                            openReview: [
                                              'approved',
                                              'pending_review',
                                              'rejected',
                                              'changes_required'
                                            ].contains(event.paidReviewStatus))
                                        : EventOverviewScreen(event: event))),
                          ));
                    },
                  )),
            ],
          )),
    );
  }
}
