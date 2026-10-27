import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/event_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'create_event_screen.dart';
import 'event_overview_screen.dart';
import 'event_management_screen.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();
    final myEvents = data.eventsByOrganizer(user?.name ?? '');
    final sold = myEvents.fold(0, (sum, e) => sum + e.ticketsSold);
    final remaining = myEvents.fold(
        0,
        (sum, e) =>
            sum + (e.ticketsTotal - e.ticketsSold).clamp(0, e.ticketsTotal));
    final revenue = data.totalRevenue;

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title:
              Text(l10n.organizerWelcome(user?.name.split(' ').first ?? ''))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PrimaryButton(
            label: l10n.organizerCreateEvent,
            icon: Icons.add_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateEventScreen()),
            ),
          ),
          const SizedBox(height: 20),
          ResponsiveCards(
            children: [
              StatCard(
                label: l10n.organizerTicketSales,
                value: sold.toString(),
                icon: Icons.confirmation_number_rounded,
              ),
              StatCard(
                label: l10n.managementRemaining,
                value: remaining.toString(),
                icon: Icons.groups_rounded,
                color: AppColors.success,
              ),
              StatCard(
                label: l10n.organizerRevenue,
                value: '${revenue.toStringAsFixed(0)} ₸',
                icon: Icons.payments_rounded,
                color: const Color(0xFFE0A23B),
              ),
              StatCard(
                label: l10n.organizerMyEvents,
                value: myEvents.length.toString(),
                icon: Icons.event_note_rounded,
                color: const Color(0xFF3E6AE1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (myEvents.isNotEmpty) ...[
            OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EventManagementScreen(
                            eventId: myEvents.first.id,
                            title: myEvents.first.title))),
                icon: const Icon(Icons.insights_outlined),
                label: Text(l10n.managementAnalytics)),
            const SizedBox(height: 16),
          ],
          Text(l10n.organizerMyEvents,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          for (final event in myEvents) ...[
            EventCard(
              event: event,
              trailingBadge: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EventStatusBadge(status: event.eventStatus),
                    if (event.eventStatus != 'draft') ...[
                      const SizedBox(height: 6),
                      Text(l10n.organizerSoldOf(
                          event.ticketsSold, event.ticketsTotal))
                    ],
                  ]),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => event.eventStatus == 'draft'
                        ? CreateEventScreen(draftId: event.id)
                        : EventOverviewScreen(event: event)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
