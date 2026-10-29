import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/features/profile/profile_screen.dart';
import 'package:biletflow_mobile/features/staff/staff_shell.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/support_service.dart';
import 'event_attendees_test.dart' as fixtures;
import 'attendee_flow_test.dart' as booking;
import 'package:biletflow_mobile/features/attendee/event_details_screen.dart';
import 'package:biletflow_mobile/models/event.dart';

Map<String, dynamic> platformCase() => {
      'id': 'platform-case',
      'number': 'BF-12345',
      'flow': 'organizer_platform',
      'routing': 'platform',
      'subject': 'Activation help',
      'category': 'activation',
      'status': 'open',
      'requester_id': 'user-id',
      'assigned_to': 'admin-one',
      'assignee_name': 'Admin One',
      'can_manage': false,
      'can_refund': false,
    };
void viewport(WidgetTester t) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(900, 1800);
  addTearDown(t.view.reset);
}

Widget supportApp(ApiClient api, UserRole role, Widget child) =>
    ChangeNotifierProvider(
        create: (_) => LocaleProvider(), child: fixtures.app(api, role, child));

class SupportStaffAuth extends fixtures.ListAuth {
  SupportStaffAuth(ApiClient api) : super(api, UserRole.staff);
  @override
  AppUser get currentUser => const AppUser(
      id: 'user-id',
      name: 'Support Staff',
      email: 'staff@example.com',
      role: UserRole.staff,
      supportAccess: true);
  @override
  Future<void> refreshUser() async {}
}

void main() {
  testWidgets('report event opens a prefilled private platform support request',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? submitted;
    final row = {
      ...platformCase(),
      'flow': 'attendee',
      'category': 'report_event',
      'event_id': 'event-id',
      'subject': 'Community concert'
    };
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        submitted = jsonDecode(r.body);
        return http.Response(jsonEncode(row), 201);
      }
      if (r.url.path.endsWith('/messages') ||
          r.url.path.endsWith('/history') ||
          r.url.path.endsWith('/cases') ||
          r.url.path.endsWith('/ticket-types')) {
        return http.Response('[]', 200);
      }
      return http.Response(jsonEncode(row), 200);
    }));
    await tester.pumpWidget(supportApp(api, UserRole.attendee,
        EventDetailsScreen(event: AppEvent.fromJson(booking.eventJson))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Report event'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Report event'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);
    expect(find.textContaining('This report goes directly to Platform Admin.'),
        findsOneWidget);
    expect(find.text('Sent to the organizer of the selected event or booking.'),
        findsNothing);
    expect(find.text('Event: Community concert'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Message'),
        'The venue information looks misleading.');
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(submitted?['category'], 'report_event');
    expect(submitted?['event_id'], 'event-id');
    expect(submitted?['flow'], 'attendee');
    expect(submitted?.containsKey('order_id'), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final role in [UserRole.attendee, UserRole.organizer, UserRole.admin]) {
    testWidgets('$role profile has no separate reports or disputes page',
        (tester) async {
      viewport(tester);
      final api =
          ApiClient(client: MockClient((_) async => http.Response('[]', 200)));
      await tester.pumpWidget(supportApp(api, role, const ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('My reports & disputes'), findsNothing);
      expect(find.text('Moderation & disputes'), findsNothing);
    });
  }

  testWidgets('admin profile has no personal support chat entry',
      (tester) async {
    viewport(tester);
    final api =
        ApiClient(client: MockClient((_) async => http.Response('[]', 200)));
    await tester
        .pumpWidget(supportApp(api, UserRole.admin, const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Support chat'), findsNothing);
    expect(find.text('Contact Platform Admin'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets(
      'platform admin inbox includes general attendee help but excludes event cases',
      (tester) async {
    viewport(tester);
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.queryParameters['flow'] == 'attendee') {
        return http.Response(
            jsonEncode([
              {
                ...platformCase(),
                'id': 'report',
                'flow': 'attendee',
                'routing': 'platform',
                'category': 'report_event',
                'event_id': 'event-id',
                'subject': 'Misleading venue'
              },
              {
                ...platformCase(),
                'id': 'general',
                'flow': 'attendee',
                'routing': 'platform',
                'subject': 'General attendee help'
              },
              {
                ...platformCase(),
                'id': 'event',
                'flow': 'attendee',
                'routing': 'organizer',
                'subject': 'Event organizer question'
              },
            ]),
            200);
      }
      return http.Response(jsonEncode([platformCase()]), 200);
    }));
    await tester.pumpWidget(supportApp(api, UserRole.admin,
        const SupportScreen(flow: 'organizer_platform', view: 'inbox')));
    await tester.pumpAndSettle();
    expect(find.text('General attendee help'), findsOneWidget);
    expect(find.text('Misleading venue'), findsOneWidget);
    expect(find.text('Activation help'), findsOneWidget);
    expect(find.text('Event organizer question'), findsNothing);
  });

  for (final target in ['event', 'order', 'general_after_order']) {
    testWidgets('new attendee chat routes $target with validated context',
        (tester) async {
      viewport(tester);
      Map<String, dynamic>? submitted;
      final row = {
        ...platformCase(),
        'flow': 'attendee',
        'category': 'ticket_delivery'
      };
      final api = ApiClient(client: MockClient((r) async {
        if (r.url.path.endsWith('/events')) {
          return http.Response(
              '[{"id":"event-one","title":"Jazz Night"}]', 200);
        }
        if (r.url.path.endsWith('/orders')) {
          return http.Response(
              '[{"id":"booking-one","event_id":"event-one"}]', 200);
        }
        if (r.method == 'POST') {
          submitted = jsonDecode(r.body);
          return http.Response(jsonEncode(row), 201);
        }
        if (r.url.path.endsWith('/cases') ||
            r.url.path.endsWith('/messages') ||
            r.url.path.endsWith('/history')) {
          return http.Response('[]', 200);
        }
        return http.Response(jsonEncode(row), 200);
      }));
      await tester.pumpWidget(supportApp(api, UserRole.attendee,
          const SupportScreen(view: 'mine', startNew: true)));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Message'),
          'Please help with my booking.');
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.text('Choose who to contact'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('support-destination')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('An event or booking').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      await tester.tap(find.byKey(const ValueKey('support-context-event')));
      await tester.pumpAndSettle();
      await tester.tap(target == 'event'
          ? find.text('Jazz Night').last
          : find.textContaining('Order #booking-').last);
      await tester.pumpAndSettle();
      expect(
          find.text('Sent to the organizer of the selected event or booking.'),
          findsOneWidget);
      if (target == 'general_after_order') {
        await tester.tap(find.byKey(const ValueKey('support-destination')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General app or account help').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(submitted!['flow'], 'attendee');
      if (target == 'general_after_order') {
        expect(submitted!.containsKey('event_id'), isFalse);
        expect(submitted!.containsKey('order_id'), isFalse);
      } else {
        expect(submitted!['event_id'], 'event-one');
        expect(
            submitted!['order_id'], target == 'order' ? 'booking-one' : isNull);
      }
    });
  }

  testWidgets(
      'attendee profile opens a simple Support chat and starts a conversation',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? submitted;
    final row = {
      ...platformCase(),
      'flow': 'attendee',
      'category': 'ticket_delivery',
      'subject': 'Missing ticket'
    };
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/events') || r.url.path.endsWith('/orders')) {
        return http.Response('[]', 200);
      }
      if (r.method == 'POST') {
        submitted = jsonDecode(r.body);
        return http.Response(jsonEncode(row), 201);
      }
      if (r.url.path.endsWith('/messages') || r.url.path.endsWith('/history')) {
        return http.Response('[]', 200);
      }
      return http.Response(
          jsonEncode(r.url.path.endsWith('/cases') ? [row] : row), 200);
    }));
    await tester
        .pumpWidget(supportApp(api, UserRole.attendee, const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Contact Us'), findsNothing);
    await tester.tap(find.text('Support chat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-filters')), findsNothing);
    expect(find.byKey(const ValueKey('support-search')), findsNothing);
    expect(find.text('Missing ticket'), findsOneWidget);
    expect(find.textContaining('Admin One'), findsNothing);
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Subject'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('support-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General app or account help').last);
    await tester.pumpAndSettle();
    expect(find.text('Sent to Platform Admin for app and account support.'),
        findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Message'),
        'Please help me find my ticket.');
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(submitted!['flow'], 'attendee');
    expect(submitted!['category'], 'ticket_delivery');
    expect(submitted!.containsKey('event_id'), isFalse);
    expect(submitted!.containsKey('order_id'), isFalse);
    expect(submitted!['message'], 'Please help me find my ticket.');
  });

  testWidgets('staff inbox automatically shows newly assigned cases',
      (tester) async {
    viewport(tester);
    var assigned = false;
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            jsonEncode([
              {
                ...platformCase(),
                'flow': 'attendee',
                'category': 'technical',
                'subject': 'My assigned case',
                'assigned_to': assigned ? 'user-id' : 'other-staff'
              },
              {
                ...platformCase(),
                'id': 'other-case',
                'flow': 'attendee',
                'category': 'technical',
                'subject': 'Another staff case',
                'assigned_to': 'other-staff'
              },
            ]),
            200)));
    await tester.pumpWidget(supportApp(
        api,
        UserRole.staff,
        ChangeNotifierProvider<AuthService>(
            create: (_) => SupportStaffAuth(api),
            child: const SupportScreen(flow: 'attendee', view: 'inbox'))));
    await tester.pumpAndSettle();
    expect(find.text('My assigned case'), findsNothing);
    assigned = true;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('My assigned case'), findsOneWidget);
    expect(find.text('Another staff case'), findsNothing);
  });
  for (final role in [UserRole.organizer, UserRole.staff]) {
    testWidgets('${role.name} profile opens personal platform support',
        (tester) async {
      viewport(tester);
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/users/me')) {
          return http.Response(
              jsonEncode({
                'id': 'user-id',
                'email': 'user@example.com',
                'roles': ['event_admin'],
                'support_access': false
              }),
              200);
        }
        return http.Response('[]', 200);
      }));
      await tester.pumpWidget(supportApp(api, role, const ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Support inbox'), findsNothing);
      await tester.tap(find.text('Contact Platform Admin'));
      await tester.pumpAndSettle();
      expect(find.text('New request'), findsOneWidget);
      final query = requests.last.url.queryParameters;
      expect(query['flow'], 'organizer_platform');
      expect(query['view'], 'mine');
    });
  }
  testWidgets('organizer attendee inbox has no platform support entry',
      (tester) async {
    viewport(tester);
    final api =
        ApiClient(client: MockClient((r) async => http.Response('[]', 200)));
    await tester.pumpWidget(supportApp(api, UserRole.organizer,
        const SupportScreen(flow: 'attendee', view: 'inbox')));
    await tester.pumpAndSettle();
    expect(find.text('Contact Platform Admin'), findsNothing);
    expect(find.text('Platform support'), findsNothing);
    expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);
  });
  testWidgets('staff always have inbox and see guidance before authorization',
      (tester) async {
    viewport(tester);
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/users/me')) {
        return http.Response(
            jsonEncode({
              'id': 'user-id',
              'email': 'user@example.com',
              'roles': ['event_admin'],
              'support_access': false
            }),
            200);
      }
      return http.Response('[]', 200);
    }));
    await tester
        .pumpWidget(supportApp(api, UserRole.staff, const StaffShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No support access yet'), findsOneWidget);
    expect(find.text('Contact Platform Admin'), findsNothing);
  });
  testWidgets(
      'organizer platform request sends explicit flow and opens admin conversation',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? body;
    String? key;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        body = jsonDecode(r.body);
        key = r.headers['Idempotency-Key'];
        return http.Response(jsonEncode(platformCase()), 201);
      }
      if (r.url.path.endsWith('/messages')) {
        return http.Response(
            '[{"id":"msg-one","sender_id":"user-id","sender_name":"Organizer","created_at":"2030-01-01T12:00:00Z","body":"Activation failed"}]',
            200);
      }
      if (r.url.path.endsWith('/history')) return http.Response('[]', 200);
      if (r.url.path.endsWith('/platform-case')) {
        return http.Response(jsonEncode(platformCase()), 200);
      }
      return http.Response('[]', 200);
    }));
    await tester.pumpWidget(supportApp(
        api,
        UserRole.organizer,
        const SupportScreen(
            flow: 'organizer_platform',
            view: 'mine',
            startNew: true,
            initialCategory: 'activation',
            eventId: 'event-id')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Message'), 'Activation failed');
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(body!['flow'], 'organizer_platform');
    expect(body!['category'], 'activation');
    expect(body!['event_id'], 'event-id');
    expect(key, isNotEmpty);
    expect(find.textContaining('BF-12345'), findsOneWidget);
    expect(find.textContaining('Admin One'), findsOneWidget);
    expect(find.text('Activation failed'), findsOneWidget);
    expect(find.text('Platform support'), findsWidgets);
  });
  testWidgets(
      'platform admin can assign, reply and set status in a separate queue',
      (tester) async {
    viewport(tester);
    var assigned = 'admin-one', status = 'open';
    final mutations = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'PATCH') {
        mutations.add(r);
        if (r.url.path.endsWith('/assignee')) {
          assigned = jsonDecode(r.body)['user_id'];
        } else {
          status = r.url.queryParameters['status']!;
        }
      }
      if (r.method == 'POST') {
        mutations.add(r);
        return http.Response('{}', 201);
      }
      if (r.url.path.endsWith('/assignees')) {
        return http.Response(
            '[{"id":"admin-one","name":"Admin One"},{"id":"admin-two","name":"Admin Two"}]',
            200);
      }
      if (r.url.path.endsWith('/history') || r.url.path.endsWith('/messages')) {
        return http.Response('[]', 200);
      }
      final row = {
        ...platformCase(),
        'can_manage': true,
        'assigned_to': assigned,
        'status': status
      };
      if (r.url.path.endsWith('/cases')) {
        expect(r.url.queryParameters['flow'],
            anyOf('organizer_platform', 'attendee'));
        expect(r.url.queryParameters['view'], 'inbox');
        if (r.url.queryParameters['flow'] == 'attendee') {
          return http.Response('[]', 200);
        }
        return http.Response(jsonEncode([row]), 200);
      }
      return http.Response(jsonEncode(row), 200);
    }));
    await tester.pumpWidget(supportApp(api, UserRole.admin,
        const SupportScreen(flow: 'organizer_platform', view: 'inbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activation help'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('case-assignee-admin-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin Two').last);
    await tester.pumpAndSettle();
    expect(assigned, 'admin-two');
    await tester.tap(find.byKey(const ValueKey('case-status-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    expect(status, 'in_progress');
    await tester.enterText(find.widgetWithText(TextFormField, 'Message'),
        'Please retry activation');
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(
        mutations
            .where((r) => r.method == 'POST')
            .single
            .headers['Idempotency-Key'],
        isNotEmpty);
  });
  test(
      'message retries reuse a key and successful repeated messages get a new key',
      () async {
    final requests = <http.Request>[];
    var fail = true;
    final service = SupportService(ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (fail) {
        fail = false;
        throw http.ClientException('Lost acknowledgement');
      }
      return http.Response('{}', 201);
    })));
    await expectLater(
        service.reply('case-id', 'Hello'), throwsA(isA<ApiException>()));
    await service.reply('case-id', 'Hello');
    await service.reply('case-id', 'Hello');
    expect(requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key']);
    expect(requests[2].headers['Idempotency-Key'],
        isNot(requests[1].headers['Idempotency-Key']));
  });
  testWidgets(
      'polling stops for inactive tabs, background lifecycle, and disposal',
      (tester) async {
    var calls = 0;
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    final api = ApiClient(client: MockClient((r) async {
      calls++;
      return http.Response('[]', 200);
    }));
    await tester.pumpWidget(supportApp(
        api,
        UserRole.attendee,
        ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, enabled, child) => TickerMode(
                enabled: enabled, child: const SupportScreen(view: 'mine')))));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(calls, 1);
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 2);
  });
}
