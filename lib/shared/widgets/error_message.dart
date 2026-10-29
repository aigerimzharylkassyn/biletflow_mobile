import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import 'outlined_app_button.dart';

/// Shown for empty states and error states alike - an icon, a message,
/// and an optional retry action.
class AppErrorMessage extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  const AppErrorMessage({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedAppButton(
                  label: context.l10n.commonRetry, onPressed: onRetry),
            ],
          ],
        ),
      ),
    ));
  }
}
