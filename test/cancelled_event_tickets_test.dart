import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:biletflow_mobile/features/attendee/order_details_screen.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/ticket.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/shared/widgets/ticket_card.dart';
import 'attendee_flow_test.dart' as booking;
import 'event_attendees_test.dart' as fixtures;

void main() {
  for (final admission in ['valid', 'checked_in', 'cancelled', 'refunded']) {
    testWidgets('cancelled event hides QR for $admission ticket',
        (tester) async {
      final event =
          AppEvent.fromJson({...booking.eventJson, 'status': 'cancelled'});
      final ticket = AppTicket(
          id: 'ticket-demo-id',
          event: event,
          ticketCode: 'old-signed-qr',
          status: TicketStatus.past,
          holderName: 'Attendee',
          admissionStatus: admission);
      expect(ticket.canShowQr, isFalse);
      await tester.pumpWidget(fixtures.app(ApiClient(), UserRole.attendee,
          Scaffold(body: TicketCard(ticket: ticket))));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  }
  testWidgets(
      'cancelled booking keeps order and refund support but hides admission QR and PDF',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/orders/order-id')) {
        return http.Response(
            jsonEncode({
              ...booking.order,
              'tickets': [
                {
                  'id': 'ticket-id',
                  'status': 'valid',
                  'qr_credential': 'old-signed-qr',
                  'attendee_name': 'Attendee'
                },
              ]
            }),
            200);
      }
      return http.Response(
          jsonEncode({...booking.eventJson, 'status': 'cancelled'}), 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api, UserRole.attendee, const OrderDetailsScreen(orderId: 'order-id')));
    await tester.pumpAndSettle();
    expect(find.text('Event cancelled'), findsOneWidget);
    expect(find.textContaining('Any refund will be processed separately'),
        findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(find.text('Request refund'), findsOneWidget);
    expect(find.textContaining('order-id'), findsWidgets);
  });
}
