import 'package:flutter/material.dart';
import '../profile/support_screen.dart';

import '../../l10n/loc_extensions.dart';
import '../../shared/widgets/role_shell.dart';
import '../organizer/checkin_screen.dart';
import '../profile/profile_screen.dart';
import 'staff_events_screen.dart';

/// Navigation available to users assigned as event check-in staff.
class StaffShell extends StatelessWidget {
  const StaffShell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleShell(
      items: [
        RoleNavItem(
            label: l10n.navEvents,
            icon: Icons.event_outlined,
            activeIcon: Icons.event,
            screen: const StaffEventsScreen()),
        RoleNavItem(
          label: l10n.navCheckin,
          icon: Icons.qr_code_scanner_outlined,
          activeIcon: Icons.qr_code_scanner_rounded,
          screen: const CheckinScreen(),
        ),
        RoleNavItem(
            label: l10n.navSupportInbox,
            icon: Icons.inbox_outlined,
            activeIcon: Icons.inbox,
            screen: const SupportScreen(flow: 'attendee', view: 'inbox')),
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
