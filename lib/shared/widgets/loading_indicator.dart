import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';

/// Centered loading spinner with an optional label, used for full-screen
/// or full-section loading states.
class AppLoadingIndicator extends StatelessWidget {
  final String? label;

  const AppLoadingIndicator({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            label ?? context.l10n.commonLoading,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
