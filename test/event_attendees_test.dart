import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/event_attendees_screen.dart';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_attendance_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'attendee_flow_test.dart' as fixtures;
import 'package:biletflow_mobile/models/event.dart';

class ListAuth extends AuthService {
  ListAuth(super.api, this.role);
  final UserRole role;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get currentUser => AppUser(
      id: 'user-id',
      name: 'Example User',
      email: 'user@example.com',
      role: role);
}

Widget app(ApiClient api, UserRole role, Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(
              create: (_) => ListAuth(api, role)),
          ChangeNotifierProvider(
              create: (c) => DataService(api, c.read<AuthService>())),
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: child));
List<Map<String, dynamic>> rows() => [
      {
        'id': 'order-alice',
        'attendee_name': 'Alice Example',
        'attendee_email': 'alice@example.com',
        'status': 'confirmed',
        'total_minor': 200000,
        'items': [
          {'quantity': 2}
        ]
      },
      {
        'id': 'order-bob',
        'attendee_name': 'Bob Example',
        'attendee_email': 'bob@example.com',
        'status': 'pending',
        'total_minor': 100000
      },
    ];
void main() {
  for (final role in [UserRole.organizer, UserRole.staff]) {
    testWidgets(
        '${role.name} loads event orders with search and status filters',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode(rows()), 200);
      }));
      api.token = 'session-token';
      await tester.pumpWidget(app(
          api,
          role,
          const EventAttendeesScreen(
              eventId: 'event-id', eventTitle: 'Community concert')));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/api/v1/events/event-id/orders');
      expect(requests.single.headers['Authorization'], 'Bearer session-token');
      expect(find.text('Alice Example'), findsOneWidget);
      expect(find.text('Bob Example'), findsOneWidget);
      expect(find.text('Tickets: 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bob@');
      await tester.pumpAndSettle();
      expect(find.text('Bob Example'), findsOneWidget);
      expect(find.text('Alice Example'), findsNothing);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All orders (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed (1)').last);
      await tester.pumpAndSettle();
      expect(find.text('Alice Example'), findsOneWidget);
      expect(find.text('Bob Example'), findsNothing);
    });
  }
  testWidgets(
      'staff can open the attendee list for the selected check-in event',
      (tester) async {
    final api =
        ApiClient(client: MockClient((_) async => http.Response('[]', 200)));
    await tester.pumpWidget(app(api, UserRole.staff,
        CheckinScreen(event: AppEvent.fromJson(fixtures.eventJson))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View attendees').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<EventAttendanceScreen>(find.byType(EventAttendanceScreen))
            .eventId,
        'event-id');
  });
  testWidgets('denied access shows the backend message and no attendee details',
      (tester) async {
    final api = ApiClient(
        client: MockClient((_) async =>
            http.Response('{"detail":"Not authorized for this event"}', 403)));
    await tester.pumpWidget(app(
        api,
        UserRole.staff,
        const EventAttendeesScreen(
            eventId: 'other-event', eventTitle: 'Other event')));
    await tester.pumpAndSettle();
    expect(find.text('Not authorized for this event'), findsOneWidget);
    expect(find.text('Alice Example'), findsNothing);
  });
}
