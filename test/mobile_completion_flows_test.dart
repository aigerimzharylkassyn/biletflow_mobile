import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/app_link.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/features/attendee/attendee_ui.dart';
import 'package:biletflow_mobile/features/attendee/event_details_screen.dart';
import 'package:biletflow_mobile/features/attendee/ticket_email_panel.dart';
import 'package:biletflow_mobile/features/operations/campaign_form.dart';
import 'package:biletflow_mobile/features/operations/campaigns_screen.dart';
import 'package:biletflow_mobile/features/operations/campaign_analytics_screen.dart';
import 'package:biletflow_mobile/features/operations/formal_cases_screen.dart';
import 'package:biletflow_mobile/features/operations/open_link_screen.dart';
import 'package:biletflow_mobile/features/splash/splash_screen.dart';
import 'package:biletflow_mobile/features/auth/login_screen.dart';
import 'event_attendees_test.dart' as auth_fixtures;
import 'attendee_flow_test.dart' as fixtures;

http.Response response(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> campaign() => {
      'id': 'campaign-id',
      'name': 'VIP offer',
      'code': 'VIP50',
      'state': 'active',
      'discount_type': 'percentage',
      'discount_value': 50,
      'valid_from': '2030-01-01T00:00:00Z',
      'valid_until': '2030-02-01T00:00:00Z',
      'max_redemptions': 100,
      'redemption_count': 1,
      'held_redemptions': 0,
      'applicable_ticket_type_ids': ['vip'],
      'enabled': true,
      'campaign_url': 'https://example.com/campaign/opaque',
    };
Map<String, dynamic> caseRecord() => {
      'id': 'case-id',
      'event_id': 'event-id',
      'event_title': 'Community concert',
      'created_at': '2030-01-01T00:00:00Z',
      'reason': 'Payment issue',
      'status': 'open',
      'resolution': '',
      'order_id': 'order-id',
      'order_status': 'confirmed',
      'total_minor': 100000,
    };
List<Map<String, dynamic>> types() => [
      {'id': 'vip', 'name': 'VIP', 'kind': 'paid'}
    ];

Widget app(ApiClient api, Widget child,
        {UserRole role = UserRole.attendee,
        Locale locale = const Locale('en'),
        double scale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(
              create: (_) => auth_fixtures.ListAuth(api, role)),
          ChangeNotifierProvider(
              create: (c) => DataService(api, c.read<AuthService>())),
        ],
        child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/attendee': (_) => const Scaffold(body: Text('Account home')),
              '/login': (_) => const Scaffold(body: Text('Sign in again'))
            },
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: child));

void viewport(WidgetTester tester, [Size size = const Size(900, 1800)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'cold link remains visible and back cannot reveal an expired splash',
      (tester) async {
    viewport(tester);
    final key = GlobalKey<NavigatorState>();
    final api = ApiClient(client: MockClient((r) async => response([])));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService(api)),
          ChangeNotifierProvider(
              create: (c) => DataService(api, c.read<AuthService>())),
        ],
        child: MaterialApp(
            navigatorKey: key,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SplashScreen(),
            routes: {'/login': (_) => const LoginScreen()})));
    key.currentState!.push(MaterialPageRoute(
        builder: (_) => const OpenLinkScreen(
            link: AppLink(AppLinkKind.verification, 'signed.token'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Verify email'), findsOneWidget);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
  testWidgets('campaign destination survives signing in', (tester) async {
    viewport(tester);
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return response({
          'access_token': 'session',
          'user': {
            'id': 'buyer',
            'full_name': 'Buyer',
            'email': 'buyer@example.com',
            'roles': ['attendee']
          }
        });
      }
      if (r.url.path.contains('/campaigns/resolve/')) {
        return response(
            {'state': 'active', 'promo_code': 'VIP50', 'event_id': 'event-id'});
      }
      if (r.url.path.endsWith('/events/event-id')) {
        return response(fixtures.eventJson);
      }
      return response([]);
    }));
    await tester.pumpWidget(fixtures.app(
        const OpenLinkScreen(link: AppLink(AppLinkKind.campaign, 'opaque')),
        api));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'buyer@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'TestPass123!');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Promo code: VIP50'), findsOneWidget);
    expect(find.text('Continue in BiletFlow'), findsOneWidget);
  });

  testWidgets(
      'reset link validates passwords, submits token and clears the old session',
      (tester) async {
    viewport(tester);
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      return http.Response('', 204);
    }));
    api.token = 'old-session';
    await tester.pumpWidget(fixtures.app(
        const OpenLinkScreen(
            link: AppLink(AppLinkKind.passwordReset, 'signed.token')),
        api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'NewPass123!');
    await tester.enterText(find.byType(TextFormField).last, 'NewPass123!');
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/api/v1/auth/reset-password');
    expect(jsonDecode(requests.single.body),
        {'token': 'signed.token', 'password': 'NewPass123!'});
    expect(api.token, isNull);
    expect(find.text('Password updated. Sign in with your new password.'),
        findsOneWidget);
  });

  testWidgets(
      'expired email link stays recoverable without claiming verification',
      (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async =>
            response({'detail': 'Verification link expired'}, 400)));
    await tester.pumpWidget(app(
        api,
        const OpenLinkScreen(
            link: AppLink(AppLinkKind.verification, 'expired.token'))));
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(find.text('Verification link expired'), findsOneWidget);
    expect(find.text('Email address verified.'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Verify email'))
            .onPressed,
        isNotNull);
  });

  testWidgets(
      'formal report submission requires a reason and opens requester history',
      (tester) async {
    viewport(tester);
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      return r.method == 'POST'
          ? response(caseRecord(), 201)
          : response([caseRecord()]);
    }));
    await tester.pumpWidget(app(
        api,
        Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () =>
                        submitFormalCase(context, eventId: 'event-id'),
                    child: const Text('Open report'))))));
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(FilledButton, 'Submit formal event report'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.enterText(
        find.byType(TextFormField), 'Incorrect venue advertised');
    await tester
        .tap(find.widgetWithText(FilledButton, 'Submit formal event report'));
    await tester.pumpAndSettle();
    expect(requests.first.url.path, '/api/v1/events/event-id/reports');
    expect(jsonDecode(requests.first.body),
        {'reason': 'Incorrect venue advertised'});
    expect(requests.last.url.path, '/api/v1/reports/mine');
    expect(find.byType(FormalCasesScreen), findsOneWidget);
  });

  testWidgets(
      'ticket email failure remains retryable and in-flight taps cannot duplicate requests',
      (tester) async {
    viewport(tester);
    final pending = Completer<http.Response>();
    var count = 0;
    final api = ApiClient(client: MockClient((r) async {
      count++;
      return count == 1
          ? response({'detail': 'Mail queue unavailable'}, 503)
          : pending.future;
    }));
    await tester.pumpWidget(app(
        api,
        Scaffold(
            body: TicketEmailPanel(
                orderId: 'order-id',
                email: 'guest@example.com',
                attendeeName: 'Guest',
                event: AppEvent.fromJson(fixtures.eventJson),
                totalMinor: 100000,
                ticketIds: const ['ticket-id']))));
    await tester.tap(find.text('Request ticket email'));
    await tester.pumpAndSettle();
    expect(find.text('Mail queue unavailable'), findsOneWidget);
    expect(find.text('Ticket email requested. Delivery may take a moment.'),
        findsNothing);
    await tester.tap(find.text('Request ticket email'));
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithIcon(TextButton, Icons.send_outlined))
            .onPressed,
        isNull);
    pending.complete(response({}, 202));
    await tester.pumpAndSettle();
    expect(count, 2);
    expect(find.text('Ticket email requested. Delivery may take a moment.'),
        findsOneWidget);
  });

  testWidgets(
      'fixed KZT campaign and ticket eligibility are sent in the backend format',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? saved;
    final api = ApiClient(client: MockClient((r) async {
      saved = jsonDecode(r.body);
      expect(r.method, 'POST');
      expect(r.url.path, '/api/v1/events/event-id/campaigns');
      return response(campaign(), 201);
    }));
    await tester.pumpWidget(app(
        api, CampaignForm(eventId: 'event-id', ticketTypes: types()),
        role: UserRole.organizer));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'VIP launch');
    await tester.enterText(fields.at(1), 'campus');
    await tester.tap(find.text('Percentage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixed amount in KZT').last);
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(2), '1250,50');
    await tester.tap(find.text('All paid ticket types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIP'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved, containsPair('discount_value', 125050));
    expect(saved, containsPair('discount_type', 'fixed_kzt'));
    expect(saved, containsPair('code', 'CAMPUS'));
    expect(saved, containsPair('applicable_ticket_type_ids', ['vip']));
    expect(
        DateTime.parse(saved!['valid_until'] as String)
            .isAfter(DateTime.parse(saved!['valid_from'] as String)),
        isTrue);
  });

  testWidgets(
      'campaign edit preserves immutable pricing and retains input on server rejection',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? saved;
    final api = ApiClient(client: MockClient((r) async {
      saved = jsonDecode(r.body);
      expect(r.method, 'PATCH');
      return response({'detail': 'Campaign changed. Refresh and retry.'}, 409);
    }));
    await tester.pumpWidget(app(
        api,
        CampaignForm(
            eventId: 'event-id', ticketTypes: types(), campaign: campaign()),
        role: UserRole.organizer));
    await tester.enterText(
        find.byType(TextFormField).first, 'Updated VIP offer');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved!.containsKey('code'), isFalse);
    expect(saved!.containsKey('discount_type'), isFalse);
    expect(saved!.containsKey('discount_value'), isFalse);
    expect(find.text('Updated VIP offer'), findsOneWidget);
    expect(find.text('Campaign changed. Refresh and retry.'), findsOneWidget);
  });

  testWidgets(
      'dispute resolution is explicit and never calls refund or suspension endpoints',
      (tester) async {
    viewport(tester);
    final requests = <http.Request>[];
    var row = caseRecord();
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (r.method == 'PATCH') {
        row = {...row, ...jsonDecode(r.body) as Map<String, dynamic>};
        return response(row);
      }
      return response([row]);
    }));
    await tester.pumpWidget(app(
        api, const FormalCasesScreen(disputes: true, review: true),
        role: UserRole.admin));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review decision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under review').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Payment records checked');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final writes = requests.where((r) => r.method != 'GET').toList();
    expect(writes, hasLength(1));
    expect(writes.single.url.path, '/api/v1/admin/disputes/case-id');
    expect(jsonDecode(writes.single.body),
        {'status': 'resolved', 'resolution': 'Payment records checked'});
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Decision / progress note: Payment records checked'),
        findsOneWidget);
  });

  testWidgets(
      'requesters load only their formal records and cannot review decisions',
      (tester) async {
    viewport(tester);
    final paths = <String>[];
    final api = ApiClient(client: MockClient((r) async {
      paths.add(r.url.path);
      return response([caseRecord()]);
    }));
    await tester.pumpWidget(app(api, const FormalCasesScreen()));
    await tester.pumpAndSettle();
    expect(paths, ['/api/v1/reports/mine']);
    expect(find.text('Review decision'), findsNothing);
  });

  testWidgets(
      'campaign link resolves on the server and pre-fills a validated promo',
      (tester) async {
    viewport(tester);
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (r.url.path.contains('/campaigns/resolve/')) {
        return response(
            {'state': 'active', 'promo_code': 'VIP50', 'event_id': 'event-id'});
      }
      if (r.url.path.endsWith('/ticket-types')) {
        return response([fixtures.ticketType()]);
      }
      if (r.url.path.endsWith('/validate')) {
        return response({...fixtures.order, 'promo_code': 'VIP50'});
      }
      return response(fixtures.eventJson);
    }));
    await tester.pumpWidget(app(api,
        const OpenLinkScreen(link: AppLink(AppLinkKind.campaign, 'opaque'))));
    await tester.pumpAndSettle();
    expect(find.text('Promo code: VIP50'), findsOneWidget);
    await tester.tap(find.text('Continue in BiletFlow'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byType(TextField).last);
    expect(input.controller!.text, 'VIP50');
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(
        jsonDecode(requests
            .lastWhere((r) => r.url.path.endsWith('/validate'))
            .body)['promo_code'],
        'VIP50');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inactive campaign cannot proceed to checkout', (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async => response({
              'state': 'expired',
              'promo_code': null,
              'message': 'Promo code expired'
            })));
    await tester.pumpWidget(app(api,
        const OpenLinkScreen(link: AppLink(AppLinkKind.campaign, 'expired'))));
    await tester.pumpAndSettle();
    expect(find.text('Promo code expired'), findsOneWidget);
    expect(find.text('Continue in BiletFlow'), findsNothing);
  });

  testWidgets(
      'email verification submits the signed token only after confirmation',
      (tester) async {
    viewport(tester);
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      return response({'id': 'different-user'});
    }));
    await tester.pumpWidget(app(
        api,
        const OpenLinkScreen(
            link: AppLink(AppLinkKind.verification, 'signed.token'))));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/api/v1/auth/verify-email');
    expect(jsonDecode(requests.single.body), {'token': 'signed.token'});
    expect(find.text('Email address verified.'), findsOneWidget);
  });

  testWidgets('late quote from an older cart cannot replace its newer quote',
      (tester) async {
    viewport(tester);
    final old = Completer<http.Response>();
    final current = Completer<http.Response>();
    var quotes = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/ticket-types')) {
        return response([fixtures.ticketType()]);
      }
      if (r.url.path.endsWith('/validate')) {
        return ++quotes == 1 ? old.future : current.future;
      }
      return response(fixtures.eventJson);
    }));
    await tester.pumpWidget(app(
        api,
        EventDetailsScreen(
            event: AppEvent.fromJson(fixtures.eventJson),
            initialPromo: 'SAVE')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(quotes, 2);
    current.complete(response({...fixtures.order, 'discount_minor': 20000}));
    await tester.pumpAndSettle();
    old.complete(response({...fixtures.order, 'discount_minor': 9999}));
    await tester.pumpAndSettle();
    final summary = tester.widget<MoneySummary>(find.byType(MoneySummary));
    expect(summary.order['discount_minor'], 20000);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in ['en', 'ru', 'kk']) {
    for (final page in [
      'campaigns',
      'campaign form',
      'analytics',
      'reports',
      'disputes',
      'link'
    ]) {
      testWidgets('$page fits a 320px $locale phone at 1.5 text scale',
          (tester) async {
        viewport(tester, const Size(320, 640));
        final api = ApiClient(client: MockClient((r) async {
          if (r.url.path.endsWith('/inventory')) {
            return response({'ticket_types': types()});
          }
          if (r.url.path.endsWith('/campaigns') &&
              !r.url.path.contains('/analytics/')) {
            return response([campaign()]);
          }
          if (r.url.path.contains('/analytics/')) {
            return response([
              {
                'name': 'VIP offer',
                'code': 'VIP50',
                'state': 'active',
                'visits': 10,
                'redemptions': 1,
                'maximum': 100,
                'orders': 1,
                'tickets_sold': 1,
                'gross_revenue_minor': 100000,
                'discount_minor': 50000,
                'net_revenue_minor': 50000,
                'refunded_orders': 0,
                'refunded_minor': 0,
                'conversion_rate': 10,
              }
            ]);
          }
          return response([caseRecord()]);
        }));
        final Widget screen = switch (page) {
          'campaigns' => const CampaignsScreen(
              eventId: 'event-id', title: 'Community concert'),
          'campaign form' =>
            CampaignForm(eventId: 'event-id', ticketTypes: types()),
          'analytics' => const CampaignAnalyticsScreen(eventId: 'event-id'),
          'reports' => const FormalCasesScreen(review: true),
          'disputes' => const FormalCasesScreen(disputes: true, review: true),
          _ => const OpenLinkScreen(),
        };
        await tester.pumpWidget(app(api, screen,
            role: UserRole.admin, locale: Locale(locale), scale: 1.5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -1400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
