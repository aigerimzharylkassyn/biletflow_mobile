import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/auth/email_auth_screen.dart';
import 'package:biletflow_mobile/features/auth/login_screen.dart';
import 'package:biletflow_mobile/features/attendee/ticket_email_panel.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/demo_email_flow.dart';
import 'event_attendees_test.dart' as fixtures;
import 'responsive_layout_test.dart' as layout;

void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 1200);
  addTearDown(tester.view.reset);
}

void main() {
  test('demo codes expire, enforce cooldown and attempts, and cannot be reused',
      () async {
    var now = DateTime.utc(2030);
    final demo = DemoEmailFlow(now: () => now);
    await demo.requestCode('test@example.com', EmailPurpose.verification);
    await expectLater(
        demo.requestCode('test@example.com', EmailPurpose.verification),
        throwsA(DemoEmailFailure.cooldown));
    await demo.confirmCode(
        'test@example.com', EmailPurpose.verification, DemoEmailFlow.code);
    await expectLater(
        demo.confirmCode(
            'test@example.com', EmailPurpose.verification, DemoEmailFlow.code),
        throwsA(DemoEmailFailure.invalidCode));
    now = now.add(const Duration(minutes: 1));
    await demo.requestCode('test@example.com', EmailPurpose.passwordReset);
    for (var i = 0; i < 4; i++) {
      await expectLater(
          demo.confirmCode(
              'test@example.com', EmailPurpose.passwordReset, '999999'),
          throwsA(DemoEmailFailure.invalidCode));
    }
    await expectLater(
        demo.confirmCode(
            'test@example.com', EmailPurpose.passwordReset, '999999'),
        throwsA(DemoEmailFailure.locked));
    await expectLater(
        demo.confirmCode(
            'test@example.com', EmailPurpose.passwordReset, DemoEmailFlow.code),
        throwsA(DemoEmailFailure.locked));
    now = now.add(const Duration(minutes: 1));
    await demo.requestCode('test@example.com', EmailPurpose.passwordReset);
    now = now.add(DemoEmailFlow.expiry);
    await expectLater(
        demo.confirmCode(
            'test@example.com', EmailPurpose.passwordReset, DemoEmailFlow.code),
        throwsA(DemoEmailFailure.expiredCode));
  });

  testWidgets('forgot password opens a clearly labelled demo', (tester) async {
    viewport(tester);
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester
        .pumpWidget(fixtures.app(api, UserRole.attendee, const LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();
    expect(find.byType(EmailAuthScreen), findsOneWidget);
    expect(find.text('Email demo'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets(
      'reset preview validates inputs and never sends a password to the API',
      (tester) async {
    viewport(tester);
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(fixtures.app(
        api, UserRole.attendee, const EmailAuthScreen(resetPassword: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get demo code'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email-demo-code')), findsNothing);
    await tester.enterText(
        find.byType(TextFormField).first, 'demo@example.com');
    await tester.tap(find.text('Get demo code'));
    await tester.pumpAndSettle();
    expect(
        find.text('Demo code: 123456 · valid for 15 minutes'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('email-demo-code')), '999999');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'ExamplePassword123!');
    await tester.enterText(fields.at(2), 'DoesNotMatch123!');
    await tester.ensureVisible(find.text('Preview password reset'));
    await tester.tap(find.text('Preview password reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset preview complete'), findsNothing);
    await tester.enterText(fields.at(2), 'ExamplePassword123!');
    await tester.ensureVisible(find.text('Preview password reset'));
    await tester.tap(find.text('Preview password reset'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect code. Try again.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('email-demo-code')), DemoEmailFlow.code);
    await tester.ensureVisible(find.text('Preview password reset'));
    await tester.tap(find.text('Preview password reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset preview complete'), findsOneWidget);
    expect(find.textContaining('No password was saved or changed.'),
        findsOneWidget);
    expect(requests, 0);
    expect(api.token, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'verification demo never updates the real user or calls the backend',
      (tester) async {
    viewport(tester);
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.attendee, const EmailAuthScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('email-demo-code')), DemoEmailFlow.code);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Check code'));
    await tester.tap(find.widgetWithText(FilledButton, 'Check code'));
    await tester.pumpAndSettle();
    expect(find.text('Verification preview complete'), findsOneWidget);
    expect(
        find.textContaining('real email verification status has not changed.'),
        findsOneWidget);
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'confirmation previews real order details and simulated delivery makes no requests',
      (tester) async {
    viewport(tester);
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.attendee,
        Scaffold(
            body: ListView(children: [
          TicketEmailPanel(
              orderId: 'order-123',
              email: 'demo@example.com',
              attendeeName: 'Demo Guest',
              totalMinor: 125000,
              event: layout.event,
              ticketIds: const ['ticket-one', 'ticket-two']),
        ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview email'));
    await tester.pumpAndSettle();
    expect(find.text('To: demo@example.com'), findsOneWidget);
    expect(find.text('ticket-ticket-one.pdf'), findsOneWidget);
    expect(find.text('ticket-ticket-two.pdf'), findsOneWidget);
    await tester.ensureVisible(find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate sending'));
    await tester.pumpAndSettle();
    expect(find.text('Demo sending complete. No email was delivered.'),
        findsOneWidget);
    expect(requests, 0);
  });
}
