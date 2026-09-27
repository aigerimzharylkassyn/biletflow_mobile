import 'package:flutter/material.dart';

import '../../l10n/loc_extensions.dart';
import '../../shared/widgets/role_shell.dart';
import '../profile/profile_screen.dart';
import 'checkin_screen.dart';
import 'organizer_dashboard_screen.dart';
import 'organizer_events_screen.dart';

/// Organizer bottom nav: Dashboard | Events | Check-in | Profile.
class OrganizerShell extends StatelessWidget {
  const OrganizerShell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleShell(
      items: [
        RoleNavItem(
          label: l10n.navDashboard,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          screen: const OrganizerDashboardScreen(),
        ),
        RoleNavItem(
          label: l10n.navEvents,
          icon: Icons.event_outlined,
          activeIcon: Icons.event_rounded,
          screen: const OrganizerEventsScreen(),
        ),
        RoleNavItem(
          label: l10n.navCheckin,
          icon: Icons.qr_code_scanner_outlined,
          activeIcon: Icons.qr_code_scanner_rounded,
          screen: const CheckinScreen(),
        ),
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
