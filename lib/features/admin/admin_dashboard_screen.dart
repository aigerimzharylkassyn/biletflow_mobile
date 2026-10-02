import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/outlined_app_button.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'admin_reports_screen.dart';
import 'organizer_applications_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.adminWelcome(user?.name.split(' ').first ?? ''))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.adminOverview,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ResponsiveCards(
            children: [
              StatCard(
                label: l10n.adminTotalUsers,
                value: data.adminUsers.length.toString(),
                icon: Icons.groups_rounded,
              ),
              StatCard(
                label: l10n.adminTotalEvents,
                value: data.events.length.toString(),
                icon: Icons.event_note_rounded,
                color: const Color(0xFF3E6AE1),
              ),
              StatCard(
                label: l10n.adminTicketsSold,
                value: data.totalTicketsSold.toString(),
                icon: Icons.confirmation_number_rounded,
                color: AppColors.success,
              ),
              StatCard(
                label: l10n.organizerRevenue,
                value: '${data.totalRevenue.toStringAsFixed(0)} ₸',
                icon: Icons.payments_rounded,
                color: const Color(0xFFE0A23B),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedAppButton(
            label: l10n.organizerApplications,
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OrganizerApplicationsScreen(),
            )),
          ),
          const SizedBox(height: 12),
          OutlinedAppButton(
            label: l10n.adminViewReports,
            icon: Icons.bar_chart_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
