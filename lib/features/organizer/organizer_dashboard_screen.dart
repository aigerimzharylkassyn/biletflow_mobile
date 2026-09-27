import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/event_card.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/stat_card.dart';
import 'create_event_screen.dart';
import 'event_overview_screen.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();
    final myEvents = data.eventsByOrganizer(user?.name ?? '');
    final sold = myEvents.fold(0, (sum, e) => sum + e.ticketsSold);
    final attendees = sold; // One admission per ticket.
    final revenue = data.totalRevenue;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.organizerWelcome(user?.name.split(' ').first ?? ''))),
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                label: l10n.organizerTicketSales,
                value: sold.toString(),
                icon: Icons.confirmation_number_rounded,
              ),
              StatCard(
                label: l10n.organizerAttendees,
                value: attendees.toString(),
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
          Text(l10n.organizerMyEvents,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          for (final event in myEvents) ...[
            EventCard(
              event: event,
              trailingBadge: Text(
                l10n.organizerSoldOf(event.ticketsSold, event.ticketsTotal),
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EventOverviewScreen(event: event)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
