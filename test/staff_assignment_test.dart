import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/organizer/assign_staff_dialog.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';


final event = AppEvent(
    id: 'event-id',
    title: 'Concert',
    date: DateTime(2027),
    startTime: '18:00',
    endTime: '22:00',
    venue: 'Hall',
    city: 'Almaty',
    description: '',
    organizerName: 'Organizer',
    price: 0,
    category: EventCategory.music,
    accentColor: Colors.blue,
    icon: Icons.event);

Widget app(DataService data) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: AssignStaffDialog(event: event, data: data)));

DataService service(Future<http.Response> Function(http.Request) handler) {
  final api = ApiClient(client: MockClient(handler));
  return DataService(api, AuthService(api));
}

void main() {
  testWidgets(
      'Assignment normalizes and encodes email, submits once and confirms success',
      (tester) async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    final data = service((request) {
      requests.add(request);
      return pending.future;
    });
    await tester.pumpWidget(app(data));
    await tester.enterText(
        find.byType(TextFormField), ' Staff+Entry@Example.com ');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/events/event-id/staff');
    expect(requests.single.url.queryParameters['email'],
        'staff+entry@example.com');
    expect(requests.single.body, isEmpty);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    pending.complete(http.Response(
        '{"id":"assignment-id","permissions":["check_in"]}', 201));
    await tester.pumpAndSettle();
    expect(find.textContaining('Staff assigned.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('Invalid email does not call backend', (tester) async {
    var calls = 0;
    final data = service((_) async {
      calls++;
      return http.Response('{}', 201);
    });
    await tester.pumpWidget(app(data));
    await tester.enterText(find.byType(TextFormField), 'bad-address');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('User-not-found error keeps form available for correction',
      (tester) async {
    final data =
        service((_) async => http.Response('{"detail":"User not found"}', 404));
    await tester.pumpWidget(app(data));
    await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('User not found'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
}
