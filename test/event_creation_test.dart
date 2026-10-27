import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/create_event_screen.dart';
import 'package:biletflow_mobile/features/organizer/paid_activation_panel.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event_creation.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/services/event_creation_service.dart';

void fill(EventDraft draft) {
  draft.fields.addAll({
    'title': 'Community festival',
    'category': 'concerts',
    'description': 'A multi-ticket community event',
    'venue': 'Central Hall',
    'address': '1 Abay Avenue',
    'city': 'Almaty',
    'capacity': '20',
    'refund': 'Contact host',
    'visibility': 'unlisted'
  });
  draft.dates.addAll({
    'starts': DateTime.utc(2030, 6, 10, 18, 30),
    'ends': DateTime.utc(2030, 6, 10, 23),
    'opens': DateTime.utc(2030, 5, 1, 9),
    'closes': DateTime.utc(2030, 6, 10, 17)
  });
}

http.Response jsonResponse(Object? value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
Map<String, dynamic> savedDraft(EventDraft draft) => {
      ...draft.body(),
      'id': 'draft-id',
      'status': 'draft',
      'available_ticket_types': [],
      'images': []
    };
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
            home: Scaffold(body: child)));

void main() {
  testWidgets(
      'short event details are valid and maximum lengths are upper bounds',
      (tester) async {
    final api = ApiClient();
    await tester.pumpWidget(app(const CreateEventScreen(), api));
    await tester.pumpAndSettle();
    TextFormField field(String name) =>
        tester.widget<TextFormField>(find.byKey(ValueKey('detail-$name-0')));
    expect(field('venue').validator!('Hall'), isNull);
    expect(field('venue').validator!('A' * 250), isNull);
    expect(field('venue').validator!('A'), 'Enter at least 2 characters.');
    expect(field('venue').validator!('A' * 251),
        'Use no more than 250 characters.');
    expect(field('address').validator!('Abay 1'), isNull);
    expect(field('address').validator!('A' * 500), isNull);
    expect(field('address').validator!('A' * 501),
        'Use no more than 500 characters.');
    expect(field('title').validator!('Gig'), isNull);
    expect(field('title').validator!('Hi'), 'Enter at least 3 characters.');
    expect(field('description').validator!('Live music'), isNull);
    expect(field('city').validator!('Almaty'), isNull);
    expect(field('city').validator!('A' * 121),
        'Use no more than 120 characters.');
    expect(field('banner').validator!(''), isNull);
    expect(field('refund').validator!('  '), isNull);
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey('detail-venue-0')),
                matching: find.byType(TextField)))
            .decoration!
            .helperText,
        contains('2–250'));
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey('detail-address-0')),
                matching: find.byType(TextField)))
            .decoration!
            .helperText,
        contains('3–500'));
  });

  test('free events create every ticket type with zero price', () {
    final draft = EventDraft();
    fill(draft);
    expect(draft.freeOnly, isTrue);
    for (final ticket in [
      TicketDraft(draft, initial: true),
      TicketDraft(draft)..fields['name'] = 'Free workshop'
    ]) {
      expect(ticket.body(draft)['kind'], 'free');
      expect(ticket.body(draft)['price_minor'], 0);
    }
    draft.freeOnly = false;
    final paid = TicketDraft(draft)
      ..fields.addAll({'name': 'VIP', 'price': '2500'});
    expect(paid.body(draft)['kind'], 'paid');
    expect(paid.body(draft)['price_minor'], 250000);
  });
  test(
      'details send the complete web contract using UTC+05 independent of device zone',
      () {
    final draft = EventDraft();
    fill(draft);
    final body = draft.body();
    expect(body['starts_at'], '2030-06-10T13:30:00.000Z');
    expect(body['ends_at'], '2030-06-10T18:00:00.000Z');
    expect(body['venue'],
        {'name': 'Central Hall', 'address': '1 Abay Avenue', 'city': 'Almaty'});
    expect(body['capacity'], 20);
    expect(body['visibility'], 'unlisted');
    expect(body['refund_policy'], 'Contact host');
    expect(body['time_zone'], 'Asia/Almaty');
    expect(body['admission_type'], 'general_admission');
  });
  test(
      'invalid chronology, banner and decimal prices are rejected before transport',
      () {
    final draft = EventDraft();
    fill(draft);
    draft.dates['ends'] = draft.dates['starts'];
    expect(() => draft.body(), throwsA(isA<CreationValidation>()));
    fill(draft);
    draft.dates['closes'] = draft.dates['ends'];
    expect(() => draft.body(), throwsA(isA<CreationValidation>()));
    fill(draft);
    draft.fields['banner'] = 'file:///tmp/photo';
    expect(() => draft.body(), throwsA(isA<CreationValidation>()));
    expect(kztMinor('12,34'), 1234);
    expect(kztMinor('0.01'), 1);
    for (final value in ['-1', '12.345', '1e4', 'not money']) {
      expect(() => kztMinor(value), throwsA(isA<CreationValidation>()));
    }
  });
  test('ticket counts, sales windows and order limits match web validation',
      () {
    final draft = EventDraft();
    fill(draft);
    final ticket = TicketDraft(draft, initial: true);
    expect(ticket.body(draft)['price_minor'], 0);
    ticket.fields['maximum'] = '51';
    expect(() => ticket.body(draft), throwsA(isA<CreationValidation>()));
    ticket.fields['maximum'] = '10';
    ticket.start = draft.dates['opens']!.subtract(const Duration(minutes: 1));
    expect(() => ticket.body(draft), throwsA(isA<CreationValidation>()));
    ticket.start = draft.dates['opens'];
    ticket.fields['kind'] = 'paid';
    ticket.fields['price'] = '0';
    expect(() => ticket.body(draft), throwsA(isA<CreationValidation>()));
  });
  test(
      'banner failure retains draft id and retry patches instead of creating another event',
      () async {
    final calls = <http.Request>[];
    var failBanner = true;
    late EventCreationService session;
    final api = ApiClient(client: MockClient((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/images')) {
        if (failBanner) {
          return jsonResponse({'detail': 'Banner unavailable'}, 503);
        }
        return jsonResponse({});
      }
      return jsonResponse(savedDraft(session.details));
    }));
    session = EventCreationService(api);
    fill(session.details);
    session.details.fields['banner'] = 'https://example.com/banner.jpg';
    await expectLater(session.saveDetails(), throwsA(isA<ApiException>()));
    expect(session.id, 'draft-id');
    expect(session.bannerFailed, isTrue);
    failBanner = false;
    await session.saveDetails();
    expect(
        calls
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/events'))
            .length,
        1);
    expect(calls.where((r) => r.method == 'PATCH').length, 1);
    expect(session.tickets, hasLength(1));
  });
  test(
      'partial ticket save retries only unsaved types and enforces total capacity',
      () async {
    final created = <String>[];
    var failSecond = true;
    final api = ApiClient(client: MockClient((r) async {
      final name = jsonDecode(r.body)['name'] as String;
      created.add(name);
      if (name == 'VIP' && failSecond) {
        return jsonResponse({'detail': 'Retry VIP'}, 503);
      }
      return jsonResponse({'id': 'saved-$name'});
    }));
    final session = EventCreationService(api);
    fill(session.details);
    session.saved = savedDraft(session.details);
    final standard = TicketDraft(session.details, initial: true)
      ..fields['quantity'] = '10';
    final vip = TicketDraft(session.details)
      ..fields.addAll(
          {'name': 'VIP', 'kind': 'paid', 'quantity': '5', 'price': '2000.50'});
    session.tickets.addAll([standard, vip]);
    await expectLater(session.saveTickets(), throwsA(isA<ApiException>()));
    expect(standard.savedId, isNotNull);
    failSecond = false;
    await session.saveTickets();
    expect(created, ['General admission', 'VIP', 'VIP']);
    vip.fields['quantity'] = '11';
    await expectLater(
        session.saveTickets(), throwsA(isA<CreationValidation>()));
    expect(created, hasLength(3));
  });
  testWidgets(
      'saved draft resumes with editable venue and configurable ticket step',
      (tester) async {
    final details = EventDraft();
    fill(details);
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      return jsonResponse(
          r.method == 'GET' ? [savedDraft(details)] : savedDraft(details));
    }));
    await tester
        .pumpWidget(app(const CreateEventScreen(draftId: 'draft-id'), api));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free-event-true')), findsOneWidget);
    final categoryPicker = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('event-category')));
    final categoryButton = tester.widget<DropdownButton<String>>(
        find.descendant(
            of: find.byKey(const ValueKey('event-category')),
            matching: find.byType(DropdownButton<String>)));
    expect(categoryButton.items!.map((item) => item.value), [
      'music',
      'sport',
      'business',
      'art',
      'food',
      'tech',
      'student',
      'other'
    ]);
    // Legacy web categories are normalized when a saved draft is reopened.
    expect(categoryPicker.initialValue, 'music');

    final venue = tester
        .widget<TextFormField>(find.byKey(const ValueKey('detail-venue-0')));
    expect(venue.enabled, isTrue);
    final save = find.text('Save details & continue');
    await tester.scrollUntilVisible(save, 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Ticket type 1'), findsOneWidget);
    expect(find.text('Add ticket type'), findsOneWidget);
    expect(
        requests
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/events')),
        isEmpty);
    final patch = requests.firstWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body)['venue'], details.body()['venue']);
    await tester.scrollUntilVisible(find.text('Save tickets & continue'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save tickets & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Free-only events do not require paid-sales activation.'),
        findsOneWidget);
    final ticketRequest = requests
        .firstWhere((request) => request.url.path.endsWith('/ticket-types'));
    expect(jsonDecode(ticketRequest.body)['kind'], 'free');
    expect(jsonDecode(ticketRequest.body)['price_minor'], 0);
    expect(find.byType(PaidActivationPanel), findsNothing);
    final publish = find.ancestor(
        of: find.text('Publish Event'), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
    expect(find.text('Keep as draft'), findsOneWidget);
  });
  testWidgets(
      'paid checklist requires terms and fee, then waits for manual approval',
      (tester) async {
    var terms = false, fee = false, submitted = false, approved = false;
    final posts = <String>[];
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        posts.add(r.url.path);
        if (r.url.path.endsWith('accept-terms')) {
          terms = true;
          return jsonResponse({'accepted': true});
        }
        if (r.url.path.endsWith('activation-fee')) {
          fee = true;
          return jsonResponse({'status': 'succeeded', 'amount_minor': 100000});
        }
        if (r.url.path.endsWith('/apply')) {
          submitted = true;
          return jsonResponse({'status': 'pending_review'});
        }
      }
      return jsonResponse({
        'status': approved
            ? 'active'
            : submitted
                ? 'pending_review'
                : 'not_ready',
        'review_status': approved
            ? 'approved'
            : submitted
                ? 'pending_review'
                : 'not_submitted',
        'checklist': {
          'has_paid_ticket': true,
          'identity_verified': true,
          'payout_connected': true,
          'terms_accepted': terms,
          'activation_fee_paid': fee
        },
        'can_activate': terms && fee
      });
    }));
    final session = EventCreationService(api)..saved = {'id': 'draft-id'};
    bool? confirmed;
    await tester.pumpWidget(app(
        SingleChildScrollView(
            child: PaidActivationPanel(
                session: session, onActive: (v) => confirmed = v)),
        api));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
    expect(confirmed, isFalse);
    final accept = find.text('Accept paid-event terms');
    expect(
        tester
            .widget<OutlinedButton>(find.ancestor(
                of: accept, matching: find.byType(OutlinedButton)))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    final pay = find.text('Pay simulated activation fee');
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();
    final activate = find.text('Submit for admin review');
    await tester.ensureVisible(activate);
    await tester.tap(activate);
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
    expect(find.text('Awaiting review'), findsOneWidget);
    expect(posts.length, 3);
    approved = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect(find.textContaining('Platform Admin approved this paid event.'),
        findsOneWidget);
    expect(posts.length, 3);
  });
  for (final locale in ['en', 'ru', 'kk']) {
    for (final config in [
      (const Size(320, 568), 2.0, 0.0),
      (const Size(568, 320), 1.5, 0.0),
      (const Size(800, 1024), 1.5, 0.0),
      (const Size(320, 568), 1.5, 250.0)
    ]) {
      testWidgets(
          'wizard tickets and review $locale ${config.$1} ${config.$2} keyboard ${config.$3}',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = config.$1;
        tester.view.viewInsets = FakeViewPadding(bottom: config.$3);
        addTearDown(tester.view.reset);
        final details = EventDraft();
        fill(details);
        details.fields['title'] =
            'A very long event title that wraps on small mobile screens';
        final api = ApiClient(client: MockClient((r) async {
          if (r.method == 'GET') return jsonResponse([savedDraft(details)]);
          if (r.url.path.endsWith('/ticket-types')) {
            return jsonResponse({'id': 'type-id'});
          }
          return jsonResponse(savedDraft(details));
        }));
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthService(api)),
              ChangeNotifierProvider(
                  create: (c) => DataService(api, c.read<AuthService>())),
            ],
            child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(config.$2)),
                    child: child!),
                home: const CreateEventScreen(draftId: 'draft-id'))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l =
            AppLocalizations.of(tester.element(find.byType(CreateEventScreen)));
        final save = find.text(l.creationSaveDetails);
        await tester.scrollUntilVisible(save, 400,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('${l.creationTicketType} 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final next = find.text(l.creationSaveTickets);
        await tester.scrollUntilVisible(next, 400,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text(l.creationFreeHelp), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
