import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';

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
