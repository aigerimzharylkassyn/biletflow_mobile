import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../services/auth_service.dart';

class RoleNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;

  const RoleNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });
}

/// Generic bottom-navigation scaffold shared by the Attendee, Organizer
/// and Admin shells, so the nav bar isn't reimplemented three times
/// (BiletFlow spec section 13). Each role just supplies its own list of
/// [RoleNavItem]s (icon + label + screen).
class RoleShell extends StatefulWidget {
  final List<RoleNavItem> items;

  const RoleShell({super.key, required this.items});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    if (!context.watch<AuthService>().isAuthenticated) {
      return Scaffold(
          body: Center(
              child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil("/login", (_) => false),
                  child: const Text("Session ended. Sign in again."))));
    }
    return Scaffold(
      body: LayoutBuilder(
          builder: (context, constraints) => Column(children: [
                if (data.isLoading) const LinearProgressIndicator(),
                if (data.errorMessage != null)
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.3),
                      child: SingleChildScrollView(
                          child: MaterialBanner(
                              content: Text(data.errorMessage!),
                              actions: [
                            TextButton(
                                onPressed: data.refresh,
                                child: const Text("Retry"))
                          ]))),
                Expanded(
                    child: IndexedStack(
                  index: _index,
                  children: widget.items.map((item) => item.screen).toList(),
                )),
              ])),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          data.refresh();
        },
        items: widget.items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
