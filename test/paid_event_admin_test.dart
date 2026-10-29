import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/admin/paid_event_applications_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_shell.dart';
import 'package:biletflow_mobile/features/admin/admin_users_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_events_screen.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';
import 'attendee_flow_test.dart' as booking;
import 'event_attendees_test.dart' as fixtures;

Map<String, dynamic> paidApplication() => {
      'status': 'pending_review',
      'reason': '',
      'activation_fee_paid': true,
      'terms_accepted': true,
      'profile': {
        'contact_name': 'Demo Organizer',
        'contact_phone': '+77000000000',
        'organization_name': 'Events KZ',
        'payout_account_masked': '****1234',
        'verification_status': 'verified'
      },
      'event': {
        ...booking.eventJson,
        'status': 'draft',
        'organizer_name': 'Demo Organizer',
        'time_zone': 'Asia/Almaty',
        'capacity': 100,
        'available_ticket_types': [
          {
            'name': 'Standard',
            'quantity': 100,
            'price_minor': 200000,
            'sales_start': '2027-01-01',
            'sales_end': '2027-10-20'
          }
        ]
      },
    };
Widget adminApp(ApiClient api, Widget child) => ChangeNotifierProvider(
    create: (_) => LocaleProvider(),
    child: fixtures.app(api, UserRole.admin, child));
void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2000);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'summary counts every application independently of the selected filter',
      (tester) async {
    viewport(tester);
    final rows = [
      for (final status in [
        'pending_review',
        'approved',
        'rejected',
        'changes_required'
      ])
        {...paidApplication(), 'status': status},
    ];
    final api = ApiClient(
        client: MockClient((_) async => http.Response(jsonEncode(rows), 200)));
    await tester.pumpWidget(adminApp(api, const PaidEventApplicationsScreen()));
    await tester.pumpAndSettle();
    final summary = find.byKey(const ValueKey('paid-applications-summary'));
    expect(
        find.descendant(of: summary, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('1')),
        findsNWidgets(4));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Approved (1)'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: summary, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('1')),
        findsNWidgets(4));
  });
  for (final approve in [true, false]) {
    testWidgets(
        'admin can ${approve ? 'approve' : 'reject with a required reason'} paid application without publishing',
        (tester) async {
      viewport(tester);
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        if (r.method == 'POST') {
          requests.add(r);
          return http.Response('{}', 200);
        }
        return http.Response(
            jsonEncode(requests.isEmpty ? [paidApplication()] : []), 200);
      }));
      await tester
          .pumpWidget(adminApp(api, const PaidEventApplicationsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Community concert'));
      await tester.pumpAndSettle();
      final label = approve ? 'Approve event' : 'Reject event';
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      if (!approve) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(find.text('Explain what the organizer needs to change.'),
            findsOneWidget);
        await tester.enterText(
            find.byType(TextFormField), 'Clarify venue details.');
      }
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(requests.single.url.path,
          '/api/v1/admin/paid-event-applications/event-id/${approve ? 'approve' : 'reject'}');
      expect(jsonDecode(requests.single.body)['reason'],
          approve ? '' : 'Clarify venue details.');
      expect(find.byType(PaidEventReviewScreen), findsNothing);
    });
  }
  testWidgets(
      'admin navigation replaces Users with Applications and users opens from dashboard',
      (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            r.url.path.endsWith('/summary')
                ? '{"events_total":0,"published_events":0,"tickets_issued":0,"confirmed_order_total_minor":0}'
                : '[]',
            200)));
    await tester.pumpWidget(adminApp(api, const AdminShell()));
    await tester.pumpAndSettle();
    final nav =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.items.map((i) => i.label), contains('Applications'));
    expect(nav.items.map((i) => i.label), isNot(contains('Users')));
    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
  testWidgets(
      'admin events filter status and category while totals stay global',
      (tester) async {
    viewport(tester);
    final rows = [
      booking.eventJson,
      {
        ...booking.eventJson,
        'id': 'draft-id',
        'title': 'Business draft',
        'status': 'draft',
        'category': 'business'
      },
      {
        ...booking.eventJson,
        'id': 'cancel-id',
        'title': 'Cancelled concert',
        'status': 'cancelled'
      }
    ];
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/summary')) {
        return http.Response(
            '{"events_total":999,"published_events":111,"tickets_issued":500,"confirmed_order_total_minor":123000}',
            200);
      }
      if (r.url.path.endsWith('/admin/events')) {
        return http.Response(jsonEncode(rows), 200);
      }
      return http.Response('[]', 200);
    }));
    await tester.pumpWidget(adminApp(api, const AdminEventsScreen()));
    await tester.pumpAndSettle();
    await tester
        .element(find.byType(AdminEventsScreen))
        .read<DataService>()
        .refresh();
    await tester.pumpAndSettle();
    expect(find.text('999'), findsOneWidget);
    await tester.tap(find.text('Draft (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Business draft'), findsOneWidget);
    expect(find.text('Community concert'), findsNothing);
    expect(find.text('999'), findsOneWidget);
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-event-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business').last);
    await tester.pumpAndSettle();
    expect(find.text('Business draft'), findsOneWidget);
    expect(find.text('Cancelled concert'), findsNothing);
  });
}
