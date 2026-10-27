import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/event_overview_screen.dart';
import 'package:biletflow_mobile/features/organizer/create_event_screen.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'attendee_flow_test.dart' as event_fixtures;
import 'event_attendees_test.dart' as fixtures;

void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(700, 1200);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'organizer can move an existing event to draft for editing and review',
      (tester) async {
    viewport(tester);
    var unpublishCalls = 0;
    final draft = {
      ...event_fixtures.eventJson,
      'status': 'draft',
      'organizer_id': 'user-id',
      'registration_opens_at': '2026-10-01T00:00:00Z',
      'registration_closes_at': '2027-10-20T11:00:00Z',
      'capacity': 100
    };
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        unpublishCalls++;
        expect(r.url.path, '/api/v1/events/event-id/unpublish');
        return http.Response(jsonEncode(draft), 200);
      }
      if (r.url.path.endsWith('/organizer/events')) {
        return http.Response(jsonEncode([draft]), 200);
      }
      return http.Response('[]', 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.organizer,
        EventOverviewScreen(
            event: AppEvent.fromJson(event_fixtures.eventJson))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit event'));
    await tester.pumpAndSettle();
    expect(unpublishCalls, 0);
    await tester.tap(find.text('Edit event').last);
    await tester.pumpAndSettle();
    expect(unpublishCalls, 1);
    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  for (final fails in [false, true]) {
    testWidgets(
        'confirmed event cancellation ${fails ? 'preserves state on failure' : 'updates details and cached event'}',
        (tester) async {
      viewport(tester);
      var calls = 0;
      var cancelled = false;
      final initial = {...event_fixtures.eventJson, 'organizer_id': 'user-id'};
      final api = ApiClient(client: MockClient((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, '/api/v1/events/event-id/cancel');
          calls++;
          if (fails) {
            return http.Response('{"detail":"Cancellation failed"}', 503);
          }
          cancelled = true;
          return http.Response(
              jsonEncode({
                ...initial,
                'status': 'cancelled',
                'paid_sales_status': 'suspended'
              }),
              200);
        }
        if (r.url.path.endsWith('/organizer/events')) {
          return http.Response(jsonEncode([initial]), 200);
        }
        return http.Response('[]', 200);
      }));
      await tester.pumpWidget(fixtures.app(api, UserRole.organizer,
          EventOverviewScreen(event: AppEvent.fromJson(initial))));
      await tester.pumpAndSettle();
      final data =
          tester.element(find.byType(EventOverviewScreen)).read<DataService>();
      await data.refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel event'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Cancel event').last);
      await tester.pumpAndSettle();
      expect(calls, 1);
      if (fails) {
        expect(cancelled, isFalse);
        expect(data.events.single.eventStatus, 'published');
        expect(find.text('Cancel event'), findsOneWidget);
        expect(find.text('Cancellation failed'), findsOneWidget);
      } else {
        expect(data.events.single.eventStatus, 'cancelled');
        expect(data.events.single.paidSalesStatus, 'suspended');
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('Cancel event'), findsNothing);
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
      }
    });
  }
  testWidgets('dismissing cancellation leaves event unchanged', (tester) async {
    viewport(tester);
    var calls = 0;
    final api = ApiClient(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.organizer,
        EventOverviewScreen(
            event: AppEvent.fromJson(event_fixtures.eventJson))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Cancel event'), findsOneWidget);
  });
  for (final row in [
    (UserRole.staff, 'published'),
    (UserRole.organizer, 'cancelled'),
    (UserRole.organizer, 'completed')
  ]) {
    testWidgets('${row.$1.name} cannot cancel ${row.$2} event from overview',
        (tester) async {
      viewport(tester);
      final api =
          ApiClient(client: MockClient((_) async => http.Response('[]', 200)));
      await tester.pumpWidget(fixtures.app(
          api,
          row.$1,
          EventOverviewScreen(
              event: AppEvent.fromJson(
                  {...event_fixtures.eventJson, 'status': row.$2}))));
      await tester.pumpAndSettle();
      expect(find.text('Cancel event'), findsNothing);
    });
  }
}
