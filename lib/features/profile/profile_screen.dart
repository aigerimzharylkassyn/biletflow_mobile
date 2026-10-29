import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import 'organizer_application_screen.dart';
import 'account_screens.dart';
import 'support_screen.dart';
import '../operations/invitations_screen.dart';
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
      appBar: AppBar(title: Text(l10n.navProfile), actions: [
        if (user?.role == UserRole.staff)
          IconButton(
              tooltip: l10n.refreshStatus,
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                try {
                  await context.read<AuthService>().refreshUser();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }),
      ]),
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
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 16),
            _EmailVerificationCard(verified: user.emailVerified),
          ],
          const SizedBox(height: 24),
          if (user?.role == UserRole.attendee) ...[
            _ProfileRow(
              icon: Icons.event_available_outlined,
              label: l10n.becomeOrganizer,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const OrganizerApplicationScreen(),
              )),
            ),
            const Divider(),
          ],
          _ProfileRow(
            icon: Icons.edit_outlined,
            label: l10n.profileEdit,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const Divider(),
          _ProfileRow(
            icon: Icons.notifications_outlined,
            label: l10n.profileNotifications,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          const Divider(),
          if (user?.role == UserRole.attendee) ...[
            _ProfileRow(
                icon: Icons.key_outlined,
                label: l10n.opsPrivateEvents,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InvitedEventsScreen()))),
            const Divider(),
          ],
          const LanguageSettingsRow(),
          const Divider(),
          if (user?.role == UserRole.attendee ||
              user?.role == UserRole.organizer) ...[
            _ProfileRow(
              icon: Icons.help_outline_rounded,
              label: l10n.profileFaq,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
            const Divider(),
          ],
          if (user?.role != UserRole.admin) ...[
            _ProfileRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: user?.role == UserRole.organizer ||
                      user?.role == UserRole.staff
                  ? l10n.supportContactPlatform
                  : l10n.profileContactUs,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SupportScreen(
                          flow: user?.role == UserRole.organizer ||
                                  user?.role == UserRole.staff
                              ? 'organizer_platform'
                              : 'attendee',
                          view: 'mine'))),
            ),
            const Divider(),
          ],
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
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HelpScreen(policy: l10n.profileTerms))),
                  child: Text(l10n.profileTerms)),
              const Text('|', style: TextStyle(color: AppColors.textTertiary)),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HelpScreen(policy: l10n.profilePrivacy))),
                  child: Text(l10n.profilePrivacy)),
            ],
          ),
        ],
      ),
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
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text(l10n.profileSignOut,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _EmailVerificationCard extends StatefulWidget {
  final bool verified;
  const _EmailVerificationCard({required this.verified});

  @override
  State<_EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<_EmailVerificationCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AuthService auth) action, String? success) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(context.read<AuthService>());
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = widget.verified ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.verified ? Icons.verified_outlined : Icons.mark_email_unread_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.verified ? l10n.profileEmailVerified : l10n.profileEmailNotVerified,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          if (!widget.verified)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _run((auth) => auth.resendVerification(), l10n.profileVerificationResent),
                  child: Text(l10n.profileResendVerification),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run((auth) => auth.refreshUser(), null),
                  child: Text(l10n.profileRefreshStatus),
                ),
              ],
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
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
