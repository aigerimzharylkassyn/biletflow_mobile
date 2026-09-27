import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/event_card.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = context.watch<DataService>().events;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.adminManageEvents)),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return EventCard(
            event: event,
            trailingBadge: Text(
              event.organizerName,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            onTap: () => _showEventStats(context, event),
          );
        },
      ),
    );
  }

  void _showEventStats(BuildContext context, AppEvent event) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('${l10n.eventOrganizer}: ${event.organizerName}'),
              const SizedBox(height: 4),
              Text(l10n.organizerSoldOf(event.ticketsSold, event.ticketsTotal)),
              const SizedBox(height: 4),
              Text('${l10n.organizerRevenue}: ${(event.price * event.ticketsSold).toStringAsFixed(0)} ₸'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
