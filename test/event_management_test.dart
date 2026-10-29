import 'package:provider/provider.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/services/event_creation_service.dart';
import 'package:biletflow_mobile/models/event_creation.dart';
import 'event_creation_test.dart' as creation;
import 'attendee_flow_test.dart' as booking;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/organizer/event_management_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_attendees_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_operations_screen.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'event_attendees_test.dart' as fixtures;

Map<String, dynamic> analyticsFixture() => {
      'capacity': 100,
      'tickets_sold': 20,
      'tickets_remaining': 80,
      'percentage_sold': 20,
      'gross_sales_minor': 200000,
      'discounts_minor': 10000,
      'processing_fees_minor': 5000,
      'refunds_minor': 20000,
      'net_revenue_minor': 175000,
      'checked_in': 5,
      'absent': 15,
      'check_in_percentage': 25,
      'available_ticket_types': [
        {'id': 'type-id', 'name': 'Standard admission'}
      ],
      'ticket_types': [
        {
          'id': 'type-id',
          'name': 'Standard admission',
          'capacity': 100,
          'tickets': 20,
          'checked_in': 5
        }
      ],
      'sales_series': [
        {'date': '2026-10-27', 'tickets': 20, 'revenue_minor': 175000}
      ],
      'campaigns': [
        {
          'name': 'Student campaign',
          'code': 'STUDENT',
          'redemptions': 4,
          'tickets': 8,
          'revenue_minor': 60000
        }
      ],
    };
List<Map<String, dynamic>> historyFixture() => [
      {
        'id': 'audit-id',
        'created_at': '2026-10-27T10:00:00Z',
        'action': 'order.refunded',
        'actor': 'Organizer Name',
        'actor_roles': ['organizer'],
        'entity_type': 'order',
        'entity_id': 'order-id',
        'description': 'Full demonstration refund approved'
      }
    ];

void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1600);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'organizer sees authoritative analytics and can filter ticket type and history',
      (tester) async {
    viewport(tester);
    final paths = <Uri>[];
    final api = ApiClient(client: MockClient((r) async {
      paths.add(r.url);
      return http.Response(
          jsonEncode(r.url.path.endsWith('/analytics')
              ? analyticsFixture()
              : r.url.path.endsWith('/activity')
                  ? historyFixture()
                  : []),
          200);
    }));
    await tester.pumpWidget(fixtures.app(api, UserRole.organizer,
        const EventManagementScreen(eventId: 'event-id', title: 'Concert')));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard admission').last);
    await tester.pumpAndSettle();
    expect(paths.any((p) => p.queryParameters['ticket_type_id'] == 'type-id'),
        isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Activity history'));
    await tester.pumpAndSettle();
    expect(find.text('Full demonstration refund approved'), findsOneWidget);
    expect(find.text('Gross sales'), findsNothing);
    expect(find.text('Suspend event'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order actions').last);
    await tester.pumpAndSettle();
    expect(paths.any((p) => p.queryParameters['action'] == 'order'), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'staff history requests no financial data and has no order controls',
      (tester) async {
    viewport(tester);
    final paths = <String>[];
    final api = ApiClient(client: MockClient((r) async {
      paths.add(r.url.path);
      return http.Response(jsonEncode(historyFixture()), 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.staff,
        const EventManagementScreen(
            eventId: 'event-id', title: 'Concert', historyOnly: true)));
    await tester.pumpAndSettle();
    expect(paths.every((p) => p.endsWith('/activity')), isTrue);
    expect(find.text('Orders & registrations'), findsNothing);
    expect(find.text('Full demonstration refund approved'), findsOneWidget);
  });
  for (final refund in [true, false]) {
    testWidgets(
        '${refund ? 'refund' : 'free cancellation'} requires reason, submits only after confirmation and refreshes status',
        (tester) async {
      viewport(tester);
      final posts = <http.Request>[];
      bool done = false;
      final api = ApiClient(client: MockClient((r) async {
        if (r.method == 'POST') {
          posts.add(r);
          done = true;
          return http.Response('{}', 200);
        }
        if (r.url.path.endsWith('/events/event-id/orders')) {
          return http.Response(
              jsonEncode([
                {
                  'id': 'order-id',
                  'attendee_name': 'Alice',
                  'attendee_email': 'alice@example.com',
                  'status':
                      done ? (refund ? 'refunded' : 'cancelled') : 'confirmed',
                  'total_minor': refund ? 200000 : 0,
                  'can_cancel_registration': !refund
                }
              ]),
              200);
        }
        return http.Response('[]', 200);
      }));
      await tester.pumpWidget(fixtures.app(
          api,
          UserRole.organizer,
          const EventAttendeesScreen(
              eventId: 'event-id', eventTitle: 'Concert')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(refund ? 'Refund full order' : 'Cancel free registration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm action'));
      await tester.pumpAndSettle();
      expect(posts, isEmpty);
      await tester.enterText(
          find.byType(TextFormField), 'Attendee requested cancellation');
      await tester.tap(find.text('Confirm action'));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
      expect(
          posts.single.url.path
              .endsWith(refund ? '/refunds' : '/cancel-registration'),
          isTrue);
      expect(jsonDecode(posts.single.body)['reason'],
          'Attendee requested cancellation');
      expect(
          find.text(refund ? 'Refund full order' : 'Cancel free registration'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'operations monitor searches payment references and filters failed orders',
      (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'orders': [
                {
                  'id': 'order-id',
                  'event_id': 'event-id',
                  'event_title': 'Concert',
                  'attendee_name': 'Alice',
                  'attendee_email': 'alice@example.com',
                  'status': 'payment_failed',
                  'total_minor': 100000,
                  'currency': 'KZT',
                  'created_at': '2026-10-27',
                  'payments': [
                    {
                      'reference': 'sim_failed_reference',
                      'status': 'failed',
                      'amount_minor': 100000
                    }
                  ],
                  'refunds': []
                }
              ],
              'activation_fee_minor': 100000,
              'processing_fee_bps': 300
            }),
            200)));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.admin, const AdminOperationsScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sim_failed_reference');
    await tester.pumpAndSettle();
    expect(find.text('Concert'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Concert'), findsNothing);
    expect(find.text('No records for these filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'a copied past draft can reschedule existing ticket types without creating duplicates',
      () async {
    final draft = EventDraft();
    creation.fill(draft);
    final ticket = TicketDraft(draft, initial: true);
    final row = {
      ...creation.savedDraft(draft),
      'is_duplicate': true,
      'available_ticket_types': [
        {
          ...ticket.body(draft),
          'id': 'copied-type',
          'sold_count': 0,
          'reserved_count': 0,
          'refunded_count': 0
        }
      ]
    };
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (r.method == 'GET') return http.Response(jsonEncode([row]), 200);
      return http.Response(
          jsonEncode({...row, ...jsonDecode(r.body) as Map}), 200);
    }));
    final service = EventCreationService(api);
    await service.resume('draft-id');
    expect(service.tickets.single.canEdit, isTrue);
    for (final key in service.details.dates.keys.toList()) {
      service.details.dates[key] =
          service.details.dates[key]!.add(const Duration(days: 365));
    }
    await service.saveDetails();
    expect(service.tickets.single.start, service.details.dates['opens']);
    expect(service.tickets.single.end, service.details.dates['closes']);
    await service.saveTickets();
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    final update = requests.last;
    expect(update.method, 'PATCH');
    expect(update.url.path.endsWith('/ticket-types/copied-type'), isTrue);
    expect(jsonDecode(update.body)['sales_start'],
        kazakhstanTimestamp(service.details.dates['opens']!));
  });

  testWidgets(
      'admin suspends and restores event through confirmed server actions',
      (tester) async {
    viewport(tester);
    final posts = <http.Request>[];
    String status = 'published';
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        posts.add(r);
        status = jsonDecode(r.body)['action'] == 'suspend_event'
            ? 'suspended'
            : 'published';
        return http.Response(
            jsonEncode({'status': status, 'paid_sales_status': 'active'}), 200);
      }
      final value = r.url.path.endsWith('/admin/events')
          ? [
              {
                ...booking.eventJson,
                'status': status,
                'paid_sales_status': 'active'
              }
            ]
          : r.url.path.endsWith('/analytics')
              ? analyticsFixture()
              : [];
      return http.Response(jsonEncode(value), 200);
    }));
    await tester.pumpWidget(fixtures.app(api, UserRole.admin,
        const EventManagementScreen(eventId: 'event-id', title: 'Concert')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(EventManagementScreen));
    await context.read<DataService>().refresh();
    await tester.pumpAndSettle();
    for (final label in ['Suspend event', 'Restore event']) {
      await tester.tap(find.widgetWithText(OutlinedButton, label));
      await tester.pumpAndSettle();
      expect(posts.length, label == 'Suspend event' ? 0 : 1);
      await tester.enterText(
          find.byType(TextFormField), 'Operational safety review');
      await tester.tap(find.text('Confirm action'));
      await tester.pumpAndSettle();
    }
    expect(posts.map((r) => jsonDecode(r.body)['action']),
        ['suspend_event', 'restore_event']);
    expect(tester.takeException(), isNull);
  });
}
