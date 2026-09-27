import 'package:flutter/material.dart';

import '../../l10n/loc_extensions.dart';
import '../../shared/widgets/role_shell.dart';
import '../profile/profile_screen.dart';
import 'attendee_events_screen.dart';
import 'attendee_home_screen.dart';
import 'my_tickets_screen.dart';

/// Attendee bottom nav: Home | Events | My Tickets | Profile.
class AttendeeShell extends StatelessWidget {
  const AttendeeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleShell(
      items: [
        RoleNavItem(
          label: l10n.navHome,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          screen: const AttendeeHomeScreen(),
        ),
        RoleNavItem(
          label: l10n.navEvents,
          icon: Icons.event_outlined,
          activeIcon: Icons.event_rounded,
          screen: const AttendeeEventsScreen(),
        ),
        RoleNavItem(
          label: l10n.navMyTickets,
          icon: Icons.confirmation_number_outlined,
          activeIcon: Icons.confirmation_number_rounded,
          screen: const MyTicketsScreen(),
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
