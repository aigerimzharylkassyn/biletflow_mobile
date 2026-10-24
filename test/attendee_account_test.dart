import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/profile/account_screens.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/services/auth_service.dart';

http.Response response(Object? value, [int status = 200]) => http.Response(
    jsonEncode(value), status, headers: {'content-type': 'application/json'});
Widget app(Widget child, ApiClient api) => ChangeNotifierProvider(
    create: (_) => AuthService(api),
    child: MaterialApp(locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales, home: child));

void main() {
  testWidgets(
      'profile saves editable fields through backend then refreshes user',
      (tester) async {
    final calls = <http.Request>[];
    final user = {
      'id': 'user-id',
      'full_name': 'Original Name',
      'phone': '123',
      'email': 'test@example.com',
      'roles': ['attendee']
    };
    final api = ApiClient(client: MockClient((r) async {
      calls.add(r);
      return response(user);
    }));
    await tester.pumpWidget(app(const EditProfileScreen(), api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final patch = calls.firstWhere((r) => r.method == 'PATCH');
    expect(
        jsonDecode(patch.body), {'full_name': 'Updated Name', 'phone': '123'});
    expect(calls.where((r) => r.method == 'GET').length, 2);
  });
  testWidgets('notifications mark an owned message as read and reload',
      (tester) async {
    var read = false;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        expect(r.url.path, '/api/v1/notifications/notice-id/read');
        read = true;
        return http.Response('', 204);
      }
      return response([
        {
          'id': 'notice-id',
          'title': 'Tickets ready',
          'message': 'Your booking is confirmed',
          'is_read': read
        }
      ]);
    }));
    await tester.pumpWidget(app(const NotificationsScreen(), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    expect(find.text('Mark as read'), findsNothing);
  });
  testWidgets('support includes the booking context in a new request',
      (tester) async {
    http.Request? sent;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        sent = r;
        return response({'id': 'case-id'}, 201);
      }
      return response([]);
    }));
    await tester.pumpWidget(app(
        const SupportScreen(eventId: 'event-id', orderId: 'order-id'), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Missing ticket');
    await tester.enterText(
        find.byType(TextFormField).last, 'Please help find my booking');
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(sent, isNotNull);
    expect(jsonDecode(sent!.body)['order_id'], 'order-id');
    expect(jsonDecode(sent!.body)['event_id'], 'event-id');
  });
}
