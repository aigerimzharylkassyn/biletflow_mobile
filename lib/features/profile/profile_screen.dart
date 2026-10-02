import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/language_selector.dart';

/// Profile screen shared by Attendee, Organizer and Admin (BiletFlow spec
/// section 13 - reusable components, avoid duplicating UI across roles).
/// Adapted from the Figma "Profile page" - avatar, name/email, a list of
/// settings rows with dividers, and Sign Out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              AppAvatar(initials: user?.initials ?? '?', size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileRow(
            icon: Icons.edit_outlined,
            label: l10n.profileEdit,
            onTap: () => _showComingSoon(context),
          ),
          const Divider(),
          _ProfileRow(
            icon: Icons.notifications_outlined,
            label: l10n.profileNotifications,
            onTap: () => _showComingSoon(context),
          ),
          const Divider(),
          const LanguageSettingsRow(),
          const Divider(),
          _ProfileRow(
            icon: Icons.help_outline_rounded,
            label: l10n.profileFaq,
            onTap: () => _showComingSoon(context),
          ),
          const Divider(),
          _ProfileRow(
            icon: Icons.mail_outline_rounded,
            label: l10n.profileContactUs,
            onTap: () => _showComingSoon(context),
          ),
          const Divider(),
          _ProfileRow(
            icon: Icons.logout_rounded,
            label: l10n.profileSignOut,
            iconColor: AppColors.error,
            labelColor: AppColors.error,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(onPressed: () => _showComingSoon(context), child: Text(l10n.profileTerms)),
              const Text('|', style: TextStyle(color: AppColors.textTertiary)),
              TextButton(onPressed: () => _showComingSoon(context), child: Text(l10n.profilePrivacy)),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.commonComingSoon)),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.profileSignOutConfirmTitle),
        content: Text(l10n.profileSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthService>().logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text(l10n.profileSignOut, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
