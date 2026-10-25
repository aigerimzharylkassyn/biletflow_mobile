import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/organizer_events_screen.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/organizer_event_filter.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';

AppEvent event(String id, String status, DateTime start, DateTime end) =>
    AppEvent(
        id: id,
        title: id,
        eventStatus: status,
        date: start,
        endsAt: end,
        startTime: '18:00',
        endTime: '22:00',
        venue: 'Hall',
        city: 'Almaty',
        description: 'Description',
        organizerName: 'Organizer',
        price: 0,
        category: EventCategory.music,
        accentColor: Colors.blue,
        icon: Icons.event);

class FilterAuth extends AuthService {
  FilterAuth() : super(ApiClient());
  @override
  AppUser get currentUser => const AppUser(
      id: 'organizer-id',
      name: 'Organizer',
      email: 'host@example.com',
      role: UserRole.organizer);
}

class FilterData extends DataService {
  FilterData(super.api, super.auth, this.rows);
  List<AppEvent> rows;
  @override
  List<AppEvent> eventsByOrganizer(String _) => rows;
  void replace(List<AppEvent> values) {
    rows = values;
    notifyListeners();
  }
}

void main() {
  test(
      'time groups and saved statuses remain distinct and handle exact boundaries',
      () {
    final now = DateTime.utc(2030, 1, 1, 12);
    final cases = [
      (
        event('draft', 'draft', now.subtract(const Duration(days: 2)),
            now.subtract(const Duration(days: 1))),
        OrganizerEventFilter.draft
      ),
      (
        event('future', 'published', now.add(const Duration(hours: 1)),
            now.add(const Duration(hours: 2))),
        OrganizerEventFilter.upcoming
      ),
      (
        event('start', 'published', now, now.add(const Duration(hours: 1))),
        OrganizerEventFilter.active
      ),
      (
        event('end', 'published', now.subtract(const Duration(hours: 1)), now),
        OrganizerEventFilter.past
      ),
      (
        event('complete', 'completed', now.subtract(const Duration(days: 2)),
            now.subtract(const Duration(days: 1))),
        OrganizerEventFilter.completed
      ),
      (
        event('cancel', 'cancelled', now, now.add(const Duration(hours: 1))),
        OrganizerEventFilter.cancelled
      ),
    ];
    for (final row in cases) {
      expect(OrganizerEventFilter.all.matches(row.$1, now), isTrue);
      expect(
          OrganizerEventFilter.values.where((filter) =>
              filter != OrganizerEventFilter.all &&
              filter.matches(row.$1, now)),
          [row.$2]);
    }
  });
  testWidgets('filters show totals, event status badges and live count changes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1100);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final before = now.subtract(const Duration(hours: 1)),
        after = now.add(const Duration(hours: 1));
    final rows = [
      event('Draft idea', 'draft', after, after.add(const Duration(hours: 1))),
      event('Upcoming one', 'published', after,
          after.add(const Duration(hours: 1))),
      event('Upcoming two', 'published', after,
          after.add(const Duration(hours: 1))),
      event('Ongoing', 'published', before, after),
      event('Past show', 'published', before.subtract(const Duration(hours: 1)),
          before),
      event('Finished show', 'completed',
          before.subtract(const Duration(hours: 1)), before),
      event('Cancelled show', 'cancelled', after,
          after.add(const Duration(hours: 1)))
    ];
    final auth = FilterAuth();
    final data = FilterData(ApiClient(), auth, rows);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<DataService>.value(value: data),
        ],
        child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: OrganizerEventsScreen())));
    await tester.pumpAndSettle();
    for (final label in [
      'All (7)',
      'Draft (1)',
      'Upcoming (2)',
      'Active (1)',
      'Past (1)',
      'Completed (1)',
      'Cancelled (1)'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    data.replace(
        [...rows, event('Another ongoing', 'published', before, after)]);
    await tester.pumpAndSettle();
    expect(find.text('Active (2)'), findsOneWidget);
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Finished show'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Ongoing'), findsNothing);
    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled show'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    data.dispose();
    auth.dispose();
  });
}
