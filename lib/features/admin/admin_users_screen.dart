import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/app_avatar.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
        UserRole.attendee => l10n.adminRoleAttendee,
        UserRole.organizer => l10n.adminRoleOrganizer,
        UserRole.admin => l10n.adminRoleAdmin,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<DataService>();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.adminManageUsers)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: data.adminUsers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final row = data.adminUsers[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: AppAvatar(initials: row.user.initials, size: 40),
            title: Text(row.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${row.user.email} · ${_roleLabel(l10n, row.user.role)}'),
            trailing: TextButton(
              onPressed: row.active ? () async {
                try { await context.read<DataService>().toggleUserActive(row.user.id); }
                catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
              } : null,
              child: Text(
                row.active ? l10n.adminSuspendUser : l10n.adminActivateUser,
                style: TextStyle(color: row.active ? AppColors.error : AppColors.success, fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }
}
