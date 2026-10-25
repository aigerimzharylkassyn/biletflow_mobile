import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../shared/widgets/outlined_app_button.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/event_status_badge.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'checkin_screen.dart';
import 'assign_staff_dialog.dart';
import 'event_attendance_screen.dart';

class EventOverviewScreen extends StatelessWidget {
  final AppEvent event;
  const EventOverviewScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(event.date);

    return Scaffold(
      appBar: AppBar(title: Text(event.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: EventStatusBadge(status: event.eventStatus)),
          const SizedBox(height: 12),
          Text(dateLabel,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${event.venue}, ${event.city}',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ResponsiveCards(children: [
            StatCard(
                label: l10n.organizerTicketSales,
                value:
                    l10n.organizerSoldOf(event.ticketsSold, event.ticketsTotal),
                icon: Icons.confirmation_number_rounded),
            StatCard(
                label: l10n.organizerRevenue,
                value:
                    '${context.watch<DataService>().eventRevenue(event.id).toStringAsFixed(0)} ₸',
                icon: Icons.payments_rounded,
                color: const Color(0xFF3E6AE1)),
          ]),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.organizerCheckinTitle,
            icon: Icons.qr_code_scanner_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CheckinScreen(event: event)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedAppButton(
            label: l10n.organizerAssignStaff,
            icon: Icons.person_add_alt_outlined,
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => AssignStaffDialog(
                  event: event, data: context.read<DataService>()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedAppButton(
            label: l10n.organizerViewAttendees,
            icon: Icons.groups_outlined,
            onPressed: () => _showAttendees(context),
          ),
        ],
      ),
    );
  }

  void _showAttendees(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EventAttendanceScreen(
                eventId: event.id, eventTitle: event.title)));
  }
}
