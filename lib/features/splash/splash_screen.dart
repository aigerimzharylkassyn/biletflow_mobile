import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../auth/login_screen.dart';

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
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      if (route.isCurrent) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        // iOS can deliver its cold-start URL after opening '/'. Prepare a
        // useful back destination without replacing the visible link screen.
        Navigator.of(context).replace(
            oldRoute: route,
            newRoute: MaterialPageRoute(
                settings: const RouteSettings(name: '/login'),
                builder: (_) => const LoginScreen()));
      }
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
          child: Text('BiletFlow',
              style: AppTheme.logoStyle.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
