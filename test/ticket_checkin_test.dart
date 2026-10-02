import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/ticket.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/shared/widgets/ticket_card.dart';

final event = AppEvent(
    id: 'event-id',
    title: 'Test Concert',
    date: DateTime(2027),
    startTime: '18:00',
    endTime: '22:00',
    venue: 'Hall',
    city: 'Almaty',
    description: 'Concert',
    organizerName: 'Organizer',
    price: 0,
    category: EventCategory.music,
    accentColor: Colors.blue,
    icon: Icons.event);


class TestData extends DataService {
  TestData()
      : super(ApiClient(), AuthService(ApiClient()));
  final calls = <String>[];
  final response = Completer<String>();
  @override
  Future<String> admit(String eventId, String credential) {
    calls.add('$eventId:$credential');
    return response.future;
  }
}

Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child);

void main() {
  testWidgets(
      'Ticket preview and full-size QR use the exact server-issued credential',
      (tester) async {
    const credential = 'ticket.signed-backend-admission-credential';
    final ticket = AppTicket(
        id: 'ticket-id-123',
        event: event,
        ticketCode: credential,
        status: TicketStatus.upcoming,
        holderName: 'Attendee');
    await tester.pumpWidget(app(Scaffold(body: TicketCard(ticket: ticket))));
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.text('Test Concert'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNWidgets(2));
    final expected = await tester.runAsync(() =>
        QrPainter(data: credential, version: QrVersions.auto, gapless: true)
            .toImageData(260));
    final qrPainters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<QrPainter>();
    expect(qrPainters.length, 2);
    for (final painter in qrPainters) {
      final rendered = await tester.runAsync(() => painter.toImageData(260));
      expect(rendered!.buffer.asUint8List(), expected!.buffer.asUint8List());
    }
    expect(find.text('Show this QR code to the organizer at the entrance.'),
        findsOneWidget);
  });
  testWidgets(
      'Admission is sent once to the selected event and displays backend success',
      (tester) async {
    final data = TestData();
    await tester.pumpWidget(ChangeNotifierProvider<DataService>.value(
        value: data, child: app(CheckinScreen(event: event))));
    await tester.enterText(find.byType(TextField), 'ticket.signed-code');
    await tester.ensureVisible(find.text('Check in'));
    await tester.tap(find.text('Check in'));
    await tester.pump();
    expect(data.calls, ['event-id:ticket.signed-code']);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    data.response.complete('Attendee');
    await tester.pumpAndSettle();
    expect(find.text('Ticket accepted'), findsOneWidget);
    expect(find.text('Checked in: Attendee'), findsOneWidget);
  });
  testWidgets('Already-used tickets display backend rejection', (tester) async {
    final data = TestData();
    await tester.pumpWidget(ChangeNotifierProvider<DataService>.value(
        value: data, child: app(CheckinScreen(event: event))));
    await tester.enterText(find.byType(TextField), 'ticket.used-code');
    await tester.ensureVisible(find.text('Check in'));
    await tester.tap(find.text('Check in'));
    await tester.pump();
    data.response
        .completeError(const ApiException('Ticket status is checked_in', 409));
    await tester.pumpAndSettle();
    expect(find.text('Ticket not accepted'), findsOneWidget);
    expect(find.text('Ticket status is checked_in'), findsOneWidget);
  });
}
