import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/attendee/attendee_ui.dart';
import 'package:biletflow_mobile/features/attendee/checkout_screen.dart';
import 'package:biletflow_mobile/features/attendee/event_details_screen.dart';
import 'package:biletflow_mobile/features/attendee/order_details_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/ticket.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/shared/widgets/ticket_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

final eventJson = <String, dynamic>{
  'id': 'event-id',
  'title': 'Community concert',
  'description': 'Music for everyone',
  'starts_at': '2027-10-20T12:00:00Z',
  'ends_at': '2027-10-20T15:00:00Z',
  'category': 'music',
  'status': 'published',
  'paid_sales_status': 'active',
  'venue': {'name': 'Main hall', 'address': 'Abay 1', 'city': 'Almaty'},
  'refund_policy': 'Contact host before the event',
  'available_ticket_types': [],
};
Map<String, dynamic> ticketType({int reserved = 1}) => {
      'id': 'type-id',
      'name': 'Standard',
      'kind': 'paid',
      'price_minor': 200000,
      'quantity': 5,
      'sold_count': 1,
      'reserved_count': reserved,
      'max_per_order': 2,
      'sales_start': '2025-01-01T00:00:00Z',
      'sales_end': '2035-01-01T00:00:00Z'
    };
final order = {
  'id': 'order-id',
  'event_id': 'event-id',
  'status': 'confirmed',
  'attendee_name': 'Test Attendee',
  'attendee_email': 'test@example.com',
  'subtotal_minor': 400000,
  'discount_minor': 10000,
  'processing_fee_minor': 3000,
  'total_minor': 393000,
  'expires_at': '2030-01-01T00:00:00Z'
};
http.Response response(Object? v, [int status = 200]) =>
    http.Response(jsonEncode(v), status,
        headers: {'content-type': 'application/json'});
Widget app(Widget child, ApiClient api) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService(api)),
          ChangeNotifierProvider(
              create: (c) => DataService(api, c.read<AuthService>())),
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: child));

void main() {
  test(
      'availability gates event window, inventory, paid activation and max per order',
      () {
    final event = AppEvent.fromJson(eventJson);
    expect(ticketLimit(event, ticketType()), 2);
    expect(ticketLimit(event, ticketType(reserved: 4)), 0);
    expect(
        ticketLimit(
            AppEvent.fromJson({...eventJson, 'paid_sales_status': 'suspended'}),
            ticketType()),
        0);
    expect(
        ticketLimit(AppEvent.fromJson({...eventJson, 'status': 'cancelled'}),
            ticketType()),
        0);
    expect(
        ticketLimit(
            AppEvent.fromJson(
                {...eventJson, 'registration_opens_at': '2035-01-01T00:00:00'}),
            ticketType()),
        0);
  });
  test('calendar escapes event text, folds long UTF8 lines and exports UTC',
      () {
    final value = eventCalendar(AppEvent.fromJson(
        {...eventJson, 'title': 'Hello, world;\n${'Қазақша' * 30}'}));
    expect(value, contains(r'Hello\, world\;\n'));
    expect(value, contains('DTSTART:20271020T120000Z'));
    expect(value.split('\r\n').every((line) => utf8.encode(line).length <= 75),
        isTrue);
  });
  testWidgets('selection respects limit and sends promo quote with quantities',
      (tester) async {
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (r.url.path.endsWith('ticket-types')) return response([ticketType()]);
      if (r.url.path.endsWith('validate')) {
        return response({...order, 'promo_code': 'SAVE'});
      }
      return response(eventJson);
    }));
    await tester.pumpWidget(
        app(EventDetailsScreen(event: AppEvent.fromJson(eventJson)), api));
    await tester.pumpAndSettle();
    final add = find.byIcon(Icons.add_circle_outline);
    await tester.scrollUntilVisible(add, 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(
                find.ancestor(of: add, matching: find.byType(IconButton)))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'save');
    final apply = find.text('Apply promo code');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    final request =
        requests.firstWhere((r) => r.url.path.endsWith('/validate'));
    expect(jsonDecode(request.body), {
      'event_id': 'event-id',
      'items': [
        {'ticket_type_id': 'type-id', 'quantity': 2}
      ],
      'promo_code': 'SAVE'
    });
    expect(find.text('Promo code applied: SAVE'), findsOneWidget);
  });
  testWidgets(
      'checkout retains idempotency key on retry and does not issue tickets after failure',
      (tester) async {
    final reserves = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/complete')) {
        return response({...order, 'status': 'payment_failed'});
      }
      reserves.add(r);
      return reserves.length == 1
          ? response({'detail': 'Try again'}, 503)
          : response({...order, 'status': 'pending'});
    }));
    await tester.pumpWidget(app(
        CheckoutScreen(event: AppEvent.fromJson(eventJson), items: const [
          {'ticket_type_id': 'type-id', 'quantity': 2}
        ], types: [
          ticketType()
        ]),
        api));
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Attendee');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'test@example.com');
    await tester.ensureVisible(find.text('Reserve and review'));
    await tester.tap(find.text('Reserve and review'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Reserve and review'));
    await tester.pumpAndSettle();
    expect(reserves[0].headers['Idempotency-Key'], isNotEmpty);
    expect(reserves[0].headers['Idempotency-Key'],
        reserves[1].headers['Idempotency-Key']);
    final confirm = find.textContaining('Confirm booking');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Booking was not confirmed. No tickets have been issued.'),
        findsOneWidget);
    expect(find.byType(OrderDetailsScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'order displays only its own tickets, blocks refunded QR, and shows money breakdown',
      (tester) async {
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.contains('/orders/')) return response(order);
      if (r.url.path.endsWith('/tickets')) {
        return response([
          {
            'id': 'ticket-own',
            'order_id': 'order-id',
            'status': 'refunded',
            'attendee_name': 'Own ticket',
            'qr_credential': 'ticket.refunded'
          },
          {
            'id': 'ticket-other',
            'order_id': 'other-order',
            'status': 'valid',
            'attendee_name': 'Other ticket',
            'qr_credential': 'ticket.other'
          },
        ]);
      }
      return response(eventJson);
    }));
    await tester
        .pumpWidget(app(const OrderDetailsScreen(orderId: 'order-id'), api));
    await tester.pumpAndSettle();
    expect(find.text('Processing fee'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Own ticket'), findsOneWidget);
    expect(find.text('Other ticket'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Not valid for admission'), findsOneWidget);
  });
  testWidgets('cancelled tickets never show admission QR in ticket cards',
      (tester) async {
    final api = ApiClient();
    await tester.pumpWidget(app(
        Scaffold(
            body: TicketCard(
                ticket: AppTicket(
                    id: 'ticket-id',
                    event: AppEvent.fromJson(eventJson),
                    ticketCode: 'ticket.cancelled',
                    status: TicketStatus.past,
                    holderName: 'Name',
                    admissionStatus: 'cancelled'))),
        api));
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets('expired reservations cannot be confirmed', (tester) async {
    var completions = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/complete')) completions++;
      return response({
        ...order,
        'status': 'pending',
        'expires_at': '2020-01-01T00:00:00Z'
      });
    }));
    await tester.pumpWidget(app(
        CheckoutScreen(event: AppEvent.fromJson(eventJson), items: const [
          {'ticket_type_id': 'type-id', 'quantity': 1}
        ], types: [
          ticketType()
        ]),
        api));
    await tester.enterText(find.byType(TextFormField).first, 'Test Attendee');
    await tester.enterText(find.byType(TextFormField).last, 'test@example.com');
    await tester.ensureVisible(find.text('Reserve and review'));
    await tester.tap(find.text('Reserve and review'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This reservation expired and its inventory has been released. Start again to check current availability.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(completions, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missing quote endpoint allows promo validation at reservation',
      (tester) async {
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/validate')) {
        return response({'detail': 'Not Found'}, 404);
      }
      if (r.url.path.endsWith('/ticket-types')) return response([ticketType()]);
      return response(eventJson);
    }));
    await tester.pumpWidget(
        app(EventDetailsScreen(event: AppEvent.fromJson(eventJson)), api));
    await tester.pumpAndSettle();
    final add = find.byIcon(Icons.add_circle_outline);
    await tester.scrollUntilVisible(add, 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'SAVE');
    final next = find.text('Proceed to checkout');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(tester.widget<CheckoutScreen>(find.byType(CheckoutScreen)).promo,
        'SAVE');
  });
}
