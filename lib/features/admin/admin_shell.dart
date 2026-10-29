import 'package:flutter/material.dart';

import '../../l10n/loc_extensions.dart';
import '../../shared/widgets/role_shell.dart';
import '../profile/profile_screen.dart';
import '../profile/support_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_events_screen.dart';
import 'paid_event_applications_screen.dart';

/// Admin bottom nav: Dashboard | Applications | Events | Inbox | Profile.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleShell(
      items: [
        RoleNavItem(
          label: l10n.navDashboard,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          screen: const AdminDashboardScreen(),
        ),
        RoleNavItem(
          label: l10n.navApplications,
          icon: Icons.fact_check_outlined,
          activeIcon: Icons.fact_check_rounded,
          screen: const PaidEventApplicationsScreen(),
        ),
        RoleNavItem(
          label: l10n.navEvents,
          icon: Icons.event_outlined,
          activeIcon: Icons.event_rounded,
          screen: const AdminEventsScreen(),
        ),
        RoleNavItem(
            label: l10n.navSupportInbox,
            icon: Icons.inbox_outlined,
            activeIcon: Icons.inbox,
            screen:
                const SupportScreen(flow: 'organizer_platform', view: 'inbox')),
        RoleNavItem(
          label: l10n.navProfile,
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          screen: const ProfileScreen(),
        ),
      ],
    );
  }
}
