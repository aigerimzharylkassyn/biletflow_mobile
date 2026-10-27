import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/features/organizer/create_event_screen.dart';
import 'package:biletflow_mobile/features/profile/profile_screen.dart';
import 'package:biletflow_mobile/features/attendee/ticket_support_actions.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/models/event_creation.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';
import 'package:provider/provider.dart';
import 'event_attendees_test.dart' as fixtures;
import 'event_creation_test.dart' as creation;

Map<String, dynamic> requestCase(
        {String id = 'case-id',
        String status = 'open',
        String category = 'refund',
        String event = 'event-id',
        bool manage = true}) =>
    {
      'id': id,
      'subject':
          category == 'refund' ? 'Refund my concert' : 'Technical question',
      'category': category,
      'status': status,
      'event_id': event,
      'event_title': event == 'event-id' ? 'Concert' : 'Workshop',
      'order_id': 'order-id',
      'order_status': status == 'resolved' ? 'refunded' : 'confirmed',
      'order_total_minor': 200000,
      'currency': 'KZT',
      'can_manage': manage,
      'can_refund': manage && status != 'resolved' && category == 'refund',
      'refund_policy': 'Contact the organizer before the event starts.',
    };
void viewport(WidgetTester t) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(900, 1800);
  addTearDown(t.view.reset);
}

void main() {
  test('paid events require a policy; free events accept a blank policy', () {
    final draft = EventDraft();
    creation.fill(draft);
    draft.fields['refund'] = '   ';
    expect(draft.body()['refund_policy'], '');
    draft.freeOnly = false;
    expect(
        () => draft.body(),
        throwsA(isA<CreationValidation>()
            .having((e) => e.code, 'code', 'refundPolicy')));
    draft.fields['refund'] = 'Full refund before event start';
    expect(draft.body()['refund_policy'], isNotEmpty);
  });
  testWidgets(
      'paid pricing requires the policy field while free pricing leaves it optional',
      (tester) async {
    viewport(tester);
    await tester
        .pumpWidget(creation.app(const CreateEventScreen(), ApiClient()));
    await tester.pumpAndSettle();
    TextFormField policy() => tester
        .widget<TextFormField>(find.byKey(const ValueKey('detail-refund-0')));
    expect(find.text('Refund policy (optional)'), findsOneWidget);
    expect(policy().validator!('   '), isNull);
    await tester.tap(find.byKey(const ValueKey('free-event-true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid / mixed tickets').last);
    await tester.pumpAndSettle();
    expect(find.text('Refund policy (required)'), findsOneWidget);
    expect(policy().validator!('   '), 'This field is required.');
    expect(policy().validator!('Full refund until one day before the event.'),
        isNull);
  });
  testWidgets(
      'ticket refund action submits a linked request and opens its conversation',
      (tester) async {
    viewport(tester);
    Map<String, dynamic>? posted;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') {
        posted = jsonDecode(r.body);
        return http.Response(jsonEncode(requestCase(manage: false)), 201);
      }
      if (r.url.path.endsWith('/case-id/messages')) {
        return http.Response(
            '[{"sender_id":"user-id","body":"Unable to attend"}]', 200);
      }
      if (r.url.path.endsWith('/case-id')) {
        return http.Response(jsonEncode(requestCase(manage: false)), 200);
      }
      return http.Response('[]', 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api,
        UserRole.attendee,
        const Scaffold(
            body: TicketSupportActions(
                eventId: 'event-id',
                orderId: 'order-id',
                ticketId: 'ticket-id',
                title: 'Concert',
                canRequestRefund: true))));
    expect(find.text('Request refund'), findsOneWidget);
    expect(find.text('Contact organizer'), findsOneWidget);
    await tester.tap(find.text('Request refund'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-search')), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Message'), 'Unable to attend');
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(posted!['category'], 'refund');
    expect(posted!['order_id'], 'order-id');
    expect(posted!['ticket_id'], 'ticket-id');
    expect(posted!['event_id'], 'event-id');
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Unable to attend'), findsOneWidget);
    expect(find.text('Approve full refund'), findsNothing);
  });
  testWidgets(
      'organizer inbox searches and filters status, event, and category',
      (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            jsonEncode([
              requestCase(),
              requestCase(
                  id: 'technical-case',
                  status: 'resolved',
                  category: 'technical',
                  event: 'workshop-id')
            ]),
            200)));
    await tester.pumpWidget(
        fixtures.app(api, UserRole.organizer, const SupportScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Refund my concert'), findsOneWidget);
    expect(find.text('Technical question'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('support-search')), 'technical-case');
    await tester.pumpAndSettle();
    expect(find.text('Refund my concert'), findsNothing);
    expect(find.text('Technical question'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('support-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved').last);
    await tester.pumpAndSettle();
    expect(find.text('Refund my concert'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('support-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All statuses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support-event-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concert').last);
    await tester.pumpAndSettle();
    expect(find.text('Technical question'), findsNothing);
    expect(find.text('Refund my concert'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund').last);
    await tester.pumpAndSettle();
    expect(find.text('Refund my concert'), findsOneWidget);
  });
  testWidgets(
      'organizer approval changes the thread to solved and hides reply and approval controls',
      (tester) async {
    viewport(tester);
    bool refunded = false;
    int approvals = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/history') ||
          r.url.path.endsWith('/assignees')) {
        return http.Response('[]', 200);
      }
      if (r.method == 'POST') {
        refunded = true;
        approvals++;
        return http.Response(jsonEncode(requestCase(status: 'resolved')), 200);
      }
      if (r.url.path.endsWith('/messages')) {
        return http.Response(
            jsonEncode([
              {
                'sender_id': 'buyer',
                'body': refunded ? 'Refund approved.' : 'Unable to attend'
              }
            ]),
            200);
      }
      return http.Response(
          jsonEncode(requestCase(status: refunded ? 'resolved' : 'open')), 200);
    }));
    await tester.pumpWidget(fixtures.app(
        api, UserRole.organizer, const SupportScreen(caseId: 'case-id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve full refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve full refund').last);
    await tester.pumpAndSettle();
    expect(approvals, 1);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Refund approved.'), findsOneWidget);
    expect(find.text('Approve full refund'), findsNothing);
    expect(find.text('Send message'), findsNothing);
  });
  testWidgets(
      'staff profile links platform support and attendee inbox explains authorization',
      (tester) async {
    viewport(tester);
    final api = ApiClient(
        client: MockClient((r) async => http.Response(
            r.url.path.endsWith('/users/me')
                ? jsonEncode({
                    'id': 'user-id',
                    'email': 'staff@example.com',
                    'roles': ['event_admin'],
                    'support_access': false
                  })
                : '[]',
            200)));
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: fixtures.app(api, UserRole.staff, const ProfileScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Contact Platform Admin'), findsOneWidget);
    expect(find.text('Support inbox'), findsNothing);
    await tester.pumpWidget(
        fixtures.app(api, UserRole.staff, const SupportScreen(view: 'inbox')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No support access yet'), findsOneWidget);
    expect(find.text('Send message'), findsNothing);
  });
}
