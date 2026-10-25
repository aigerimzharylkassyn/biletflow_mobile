import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/staff/staff_events_screen.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/staff_event_filter.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/shared/widgets/event_card.dart';
import 'organizer_event_filters_test.dart' as fixtures;

class StaffData extends fixtures.FilterData {
  StaffData(super.api, super.auth, super.rows);
  @override
  List<AppEvent> get events => rows;
}

void main() {
  test(
      'staff groups use exact start/end times and cancellation overrides dates',
      () {
    final now = DateTime.utc(2030, 1, 1, 12);
    final cases = [
      (
        fixtures.event(
            'future',
            'published',
            now.add(const Duration(minutes: 1)),
            now.add(const Duration(hours: 1))),
        StaffEventFilter.upcoming
      ),
      (
        fixtures.event(
            'start', 'published', now, now.add(const Duration(hours: 1))),
        StaffEventFilter.live
      ),
      (
        fixtures.event(
            'end', 'published', now.subtract(const Duration(hours: 1)), now),
        StaffEventFilter.past
      ),
      (
        fixtures.event(
            'complete', 'completed', now, now.add(const Duration(hours: 1))),
        StaffEventFilter.past
      ),
      (
        fixtures.event(
            'cancel',
            'cancelled',
            now.subtract(const Duration(days: 2)),
            now.subtract(const Duration(days: 1))),
        StaffEventFilter.cancelled
      ),
    ];
    for (final row in cases) {
      expect(
          StaffEventFilter.values.where(
              (f) => f != StaffEventFilter.all && f.matches(row.$1, now)),
          [row.$2]);
    }
    expect(sortedStaffEvents(cases.reversed.map((r) => r.$1)).map((e) => e.id),
        ['cancel', 'end', 'complete', 'start', 'future']);
  });
  testWidgets(
      'assigned events are chronological with counted filters and matching events',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    AppEvent event(String id, String status, int hours) => fixtures.event(
        id,
        status,
        now.add(Duration(hours: hours)),
        now.add(Duration(hours: hours + 2)));
    final auth = fixtures.FilterAuth();
    final data = StaffData(ApiClient(), auth, [
      event('Later event', 'published', 5),
      event('Cancelled event', 'cancelled', 3),
      event('Live event', 'published', -1),
      event('Past event', 'published', -5),
      event('Soon event', 'published', 2)
    ]);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<DataService>.value(value: data),
        ],
        child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StaffEventsScreen())));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<EventCard>(find.byType(EventCard))
            .map((c) => c.event.id),
        [
          'Past event',
          'Live event',
          'Soon event',
          'Cancelled event',
          'Later event'
        ]);
    for (final label in [
      'All (5)',
      'Upcoming (2)',
      'Live (1)',
      'Past (1)',
      'Cancelled (1)'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Upcoming (2)'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<EventCard>(find.byType(EventCard))
            .map((c) => c.event.id),
        ['Soon event', 'Later event']);
    await tester.tap(find.text('Live (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Live event'), findsOneWidget);
    expect(find.text('Later event'), findsNothing);
    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled event'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    data.dispose();
    auth.dispose();
  });
}
