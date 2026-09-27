import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The "Profile Photo" component from the Figma design system, adapted to
/// show initials on a tinted background instead of an uploaded photo
/// (no real photo upload in this prototype).
class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const AppAvatar({super.key, required this.initials, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
