import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../organizer/management_confirmation.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _busy = false;
  String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
        UserRole.attendee => l10n.adminRoleAttendee,
        UserRole.organizer => l10n.adminRoleOrganizer,
        UserRole.staff => l10n.adminRoleStaff,
        UserRole.admin => l10n.adminRoleAdmin,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<DataService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminManageUsers)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: data.adminUsers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final row = data.adminUsers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AppAvatar(initials: row.user.initials, size: 40),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(row.user.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)))
              ]),
              const SizedBox(height: 8),
              Text('${row.user.email} · ${_roleLabel(l10n, row.user.role)}'),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final reason = await managementReason(
                                context,
                                row.active
                                    ? l10n.adminSuspendUser
                                    : l10n.adminActivateUser,
                                l10n.managementUserHelp);
                            if (reason == null || !context.mounted) return;
                            setState(() => _busy = true);
                            try {
                              await context
                                  .read<DataService>()
                                  .toggleUserActive(row.user.id,
                                      reason: reason);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())));
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(
                        row.active
                            ? l10n.adminSuspendUser
                            : l10n.adminActivateUser,
                        style: TextStyle(
                            color: row.active
                                ? AppColors.error
                                : AppColors.success,
                            fontSize: 13)),
                  )),
            ]),
          );
        },
      ),
    );
  }
}
