import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Brief branded splash screen (matches the Figma "Splash screen" frame:
/// the BiletFlow wordmark, coral-to-black gradient, centered on white).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ).createShader(bounds),
          child: Text('BiletFlow', style: AppTheme.logoStyle.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
