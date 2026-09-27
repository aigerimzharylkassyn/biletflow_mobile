import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/error_message.dart';
import '../../shared/widgets/event_card.dart';
import 'create_event_screen.dart';
import 'event_overview_screen.dart';

class OrganizerEventsScreen extends StatelessWidget {
  const OrganizerEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final events = context.watch<DataService>().eventsByOrganizer(user?.name ?? '');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.organizerMyEvents),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateEventScreen()),
            ),
          ),
        ],
      ),
      body: events.isEmpty
          ? AppErrorMessage(message: l10n.homeNoEvents, icon: Icons.event_busy_rounded)
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = events[index];
                return EventCard(
                  event: event,
                  trailingBadge: Text(
                    l10n.organizerSoldOf(event.ticketsSold, event.ticketsTotal),
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EventOverviewScreen(event: event)),
                  ),
                );
              },
            ),
    );
  }
}
