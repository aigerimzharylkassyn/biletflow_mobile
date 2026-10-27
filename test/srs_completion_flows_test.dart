import 'package:biletflow_mobile/features/attendee/checkout_screen.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/admin/platform_settings_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_users_screen.dart';
import 'package:biletflow_mobile/features/organizer/ticket_inventory_screen.dart';
import 'package:biletflow_mobile/features/operations/invitations_screen.dart';
import 'package:biletflow_mobile/features/attendee/event_details_screen.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'event_attendees_test.dart' as fixtures;
import 'attendee_flow_test.dart' as booking;

void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1600);
  addTearDown(tester.view.reset);
}

http.Response response(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> inventory({bool hidden = false}) => {
      'event_status': 'draft',
      'capacity': 20,
      'refund_policy': 'Refund before start',
      'registration_opens_at': '2030-01-01T00:00:00Z',
      'registration_closes_at': '2030-10-20T00:00:00Z',
      'ticket_types': [
        {
          'id': 'type-id',
          'name': 'Standard admission',
          'description': 'Admission to the event',
          'kind': 'free',
          'price_minor': 0,
          'quantity': 20,
          'available': 20,
          'sold_count': 0,
          'reserved_count': 0,
          'refunded_count': 0,
          'checked_in': 0,
          'editable': true,
          'max_per_order': 5,
          'sales_start': '2030-01-01T00:00:00Z',
          'sales_end': '2030-10-20T00:00:00Z',
          'is_hidden': hidden
        }
      ]
    };
void main() {
  testWidgets(
      'ticket visibility is confirmed on server and existing admissions are retained',
      (tester) async {
    viewport(tester);
    bool hidden = false;
    final posts = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        posts.add(r);
        hidden = true;
        return response({});
      }
      return response(inventory(hidden: hidden));
    }));
    await tester.pumpWidget(fixtures.app(api, UserRole.organizer,
        const TicketInventoryScreen(eventId: 'event-id', title: 'Concert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from sales'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(posts, hasLength(1));
    expect(posts.single.url.path.endsWith('/type-id/hide'), isTrue);
    expect(find.text('Hidden from sales'), findsOneWidget);
    expect(find.text('Show for sales'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'ticket editor keeps entered values and inline server errors on failure',
      (tester) async {
    viewport(tester);
    int writes = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'PATCH') {
        writes++;
        return response(
            {'detail': 'Ticket inventory changed. Refresh before editing.'},
            409);
      }
      return response(inventory());
    }));
    await tester.pumpWidget(fixtures.app(api, UserRole.organizer,
        const TicketInventoryScreen(eventId: 'event-id', title: 'Concert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit ticket type'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Updated admission');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Ticket inventory changed. Refresh before editing.'),
        findsOneWidget);
    expect(find.text('Updated admission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'platform settings save integer KZT minor units, basis points and concurrency version',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? saved;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'PATCH') saved = jsonDecode(r.body);
      return response({
        'activation_fee_minor': saved?['activation_fee_minor'] ?? 100000,
        'processing_fee_bps': saved?['processing_fee_bps'] ?? 300,
        'hold_minutes': saved?['hold_minutes'] ?? 15,
        'version': saved == null ? 1 : 2
      });
    }));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.admin, const PlatformSettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '2500');
    await tester.enterText(fields.at(1), '4,5');
    await tester.enterText(fields.at(2), '5');
    await tester.enterText(fields.at(3), 'Updated demonstration fees');
    await tester.tap(find.text('Save changes').last);
    await tester.pumpAndSettle();
    expect(saved, containsPair('activation_fee_minor', 250000));
    expect(saved, containsPair('processing_fee_bps', 450));
    expect(saved, containsPair('hold_minutes', 5));
    expect(saved, containsPair('version', 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'invitation acceptance respects server denial and does not navigate on failure',
      (tester) async {
    viewport(tester);
    String? token;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        token = jsonDecode(r.body)['token'];
        return response(
            {'detail': 'Sign in using the invited email address'}, 403);
      }
      return response([]);
    }));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.attendee, const InvitedEventsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter invitation code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'secure-invitation-code-123');
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(token, 'secure-invitation-code-123');
    expect(
        find.text('Sign in using the invited email address'), findsOneWidget);
    expect(find.byType(EventDetailsScreen), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('accepted invitation opens the server-returned private event',
      (tester) async {
    viewport(tester);
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        return response({...booking.eventJson, 'visibility': 'private'});
      }
      return response([]);
    }));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.attendee, const InvitedEventsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter invitation code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'secure-invitation-code-123');
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'admin user search sends the query and displays matching remote accounts',
      (tester) async {
    viewport(tester);
    final queries = <String>[];
    final api = ApiClient(client: MockClient((r) async {
      queries.add(r.url.queryParameters['q'] ?? '');
      return response([
        {
          'id': 'other-id',
          'email': 'organizer@example.com',
          'full_name': 'Айгерім',
          'roles': ['organizer'],
          'is_active': true
        }
      ]);
    }));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.admin, const AdminUsersScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Айгерім');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(queries.last, 'Айгерім');
    expect(find.text('organizer@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'abandoning checkout releases its hold without recording payment failure',
      (tester) async {
    viewport(tester);
    final posts = <String>[];
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') posts.add(r.url.path);
      return response({
        ...booking.order,
        'status': r.url.path.endsWith('/cancel') ? 'cancelled' : 'pending'
      });
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.attendee,
        Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
                                    event: AppEvent.fromJson(booking.eventJson),
                                    items: const [
                                      {
                                        'ticket_type_id': 'type-id',
                                        'quantity': 1
                                      }
                                    ],
                                    types: [
                                      booking.ticketType()
                                    ]))),
                    child: const Text('Open checkout'))))));
    await tester.tap(find.text('Open checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reserve and review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(posts.where((p) => p.endsWith('/cancel')), isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(posts.where((p) => p.endsWith('/cancel')), hasLength(1));
    expect(posts.where((p) => p.endsWith('/complete')), isEmpty);
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(find.text('Open checkout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
