import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/organizer/event_attendance_screen.dart';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/features/staff/staff_shell.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';
import 'event_attendees_test.dart' as fixtures;
import 'attendee_flow_test.dart' as events;

List<Map<String, dynamic>> tickets() => [
      {
        'id': 'alice-ticket',
        'attendee_name': 'Alice Guest',
        'attendee_email': 'alice@example.com',
        'status': 'valid',
        'ticket_type': 'General',
        'record_id': null
      },
      {
        'id': 'bob-ticket',
        'attendee_name': 'Bob Guest',
        'attendee_email': 'bob@example.com',
        'status': 'checked_in',
        'ticket_type': 'General',
        'record_id': 'bob-record'
      },
      {
        'id': 'refund-ticket',
        'attendee_name': 'Refunded Guest',
        'attendee_email': 'refund@example.com',
        'status': 'refunded',
        'ticket_type': 'General',
        'record_id': null
      },
    ];
void main() {
  for (final role in [UserRole.staff, UserRole.organizer]) {
    testWidgets(
        '${role.name} sees attendance statistics, searches, admits and reverses',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1800);
      addTearDown(tester.view.reset);
      final rows = tickets();
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        requests.add(r);
        if (r.method == 'POST') {
          if (r.url.path.endsWith('/alice-ticket/admit')) {
            rows[0]['status'] = 'checked_in';
            rows[0]['record_id'] = 'alice-record';
          }
          if (r.url.path.endsWith('/alice-record/reverse')) {
            rows[0]['status'] = 'valid';
            rows[0]['record_id'] = null;
          }
          return http.Response('{}', 200);
        }
        return http.Response(jsonEncode(rows), 200);
      }));
      await tester.pumpWidget(fixtures.app(
          api,
          role,
          const EventAttendanceScreen(
              eventId: 'event-id', eventTitle: 'Concert')));
      await tester.pumpAndSettle();
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance-action-refund-ticket')),
          findsNothing);
      await tester.enterText(
          find.byKey(const ValueKey('attendance-search')), 'alice@');
      await tester.pumpAndSettle();
      expect(find.text('Bob Guest'), findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('attendance-action-alice-ticket')));
      await tester.pumpAndSettle();
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance-success-alice-ticket')),
          findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Undo check-in'), findsOneWidget);
      expect(
          requests.any((r) =>
              r.method == 'POST' &&
              r.url.path
                  .endsWith('/events/event-id/tickets/alice-ticket/admit')),
          isTrue);
      await tester
          .tap(find.byKey(const ValueKey('attendance-action-alice-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo check-in').last);
      await tester.pumpAndSettle();
      expect(find.text('50.0%'), findsOneWidget);
      expect(
          requests
              .any((r) => r.url.path.endsWith('/records/alice-record/reverse')),
          isTrue);
    });
  }
  testWidgets(
      'pending admission shows progress, blocks repeats and does not claim success on failure',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.reset);
    final pending = Completer<http.Response>();
    var posts = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        posts++;
        return pending.future;
      }
      return http.Response(jsonEncode(tickets()), 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.staff,
        const EventAttendanceScreen(
            eventId: 'event-id', eventTitle: 'Concert')));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('attendance-action-alice-ticket'));
    await tester.tap(action);
    await tester.pump();
    expect(find.text('Checking in…'), findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(find.byKey(const ValueKey('attendance-success-alice-ticket')),
        findsNothing);
    await tester.tap(action);
    await tester.pump();
    expect(posts, 1);
    pending.complete(http.Response('{"detail":"Ticket is refunded"}', 409));
    await tester.pumpAndSettle();
    expect(find.text('Ticket is refunded'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-success-alice-ticket')),
        findsNothing);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
  });
  testWidgets(
      'staff navigation has Events, Check-in, Inbox and Profile and opens assigned event',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            jsonEncode(r.url.path.endsWith('/check-in/events')
                ? [events.eventJson]
                : tickets()),
            200)));
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: fixtures.app(api, UserRole.staff, const StaffShell())));
    final context = tester.element(find.byType(StaffShell));
    await context.read<DataService>().refresh();
    await tester.pumpAndSettle();
    final bar =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.items.map((i) => i.label),
        ['Events', 'Check-in', 'Inbox', 'Profile']);
    await tester.tap(find.text(events.eventJson['title'] as String).first);
    await tester.pumpAndSettle();
    expect(find.byType(EventAttendanceScreen), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
  });
  testWidgets('QR page includes manual attendee search and actions',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
        client:
            MockClient((_) async => http.Response(jsonEncode(tickets()), 200)));
    await tester.pumpWidget(fixtures.app(api, UserRole.staff,
        CheckinScreen(event: AppEvent.fromJson(events.eventJson))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('attendance-search')));
    await tester.enterText(
        find.byKey(const ValueKey('attendance-search')), 'Alice');
    await tester.pumpAndSettle();
    expect(find.text('Alice Guest'), findsOneWidget);
    expect(find.text('Bob Guest'), findsNothing);
    expect(find.byKey(const ValueKey('attendance-action-alice-ticket')),
        findsOneWidget);
  });
}
