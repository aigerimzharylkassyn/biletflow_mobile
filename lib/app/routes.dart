import 'package:flutter/material.dart';

import '../features/admin/admin_shell.dart';
import '../features/attendee/attendee_shell.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/organizer/organizer_shell.dart';
import '../features/splash/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const attendee = '/attendee';
  static const organizer = '/organizer';
  static const admin = '/admin';

  static Map<String, WidgetBuilder> get table => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        attendee: (_) => const AttendeeShell(),
        organizer: (_) => const OrganizerShell(),
        admin: (_) => const AdminShell(),
      };
}
