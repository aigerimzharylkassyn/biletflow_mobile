import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/profile/account_screens.dart';
import 'package:biletflow_mobile/features/profile/profile_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';

class FaqAuth extends AuthService {
  FaqAuth(this.role) : super(ApiClient());
  final UserRole role;
  @override
  AppUser get currentUser => AppUser(
      id: 'user-id',
      name: 'Example User',
      email: 'test@example.com',
      role: role);
}

Widget app(UserRole role, Widget screen) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => FaqAuth(role)),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen));

void main() {
  for (final role in UserRole.values) {
    testWidgets('FAQ entry visibility for ${role.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(role, const ProfileScreen()));
      await tester.pumpAndSettle();
      final entry = find.byIcon(Icons.help_outline_rounded);
      if (role == UserRole.attendee || role == UserRole.organizer) {
        expect(entry, findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
            find.text(
                role == UserRole.attendee ? 'Attendee FAQ' : 'Organizer FAQ'),
            findsOneWidget);
      } else {
        expect(entry, findsNothing);
        expect(find.text('Frequently Asked Questions'), findsNothing);
      }
    });
  }
  testWidgets('attendee FAQ explains bookings instead of event management',
      (tester) async {
    await tester.pumpWidget(app(UserRole.attendee, const HelpScreen()));
    await tester.pumpAndSettle();
    expect(find.text('How do I book tickets and use a promo code?'),
        findsOneWidget);
    expect(find.text('How do I create and publish an event?'), findsNothing);
    await tester.tap(find.text('How do I book tickets and use a promo code?'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Complete checkout before the reservation timer expires.'),
        findsOneWidget);
  });
  testWidgets('organizer FAQ explains publishing and staff assignment',
      (tester) async {
    await tester.pumpWidget(app(UserRole.organizer, const HelpScreen()));
    await tester.pumpAndSettle();
    expect(find.text('How do I create and publish an event?'), findsOneWidget);
    expect(find.text('Where are my tickets?'), findsNothing);
    await tester.tap(find.text('How do I assign event staff?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('email of an existing registered user'),
        findsOneWidget);
  });
  for (final role in [UserRole.admin, UserRole.staff]) {
    testWidgets('policy page remains available to ${role.name}',
        (tester) async {
      await tester
          .pumpWidget(app(role, const HelpScreen(policy: 'Privacy Policy')));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.textContaining('No published policy'), findsOneWidget);
    });
  }
}
