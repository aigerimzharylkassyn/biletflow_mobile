import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/features/organizer/organizer_events_screen.dart';
import 'package:biletflow_mobile/features/organizer/create_event_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_overview_screen.dart';
import 'package:biletflow_mobile/features/organizer/paid_activation_panel.dart';
import 'package:biletflow_mobile/features/profile/account_screens.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'attendee_flow_test.dart' as booking;
import 'event_attendees_test.dart' as fixtures;

Map<String, dynamic> draft(String status, {bool published = false}) => {
      ...booking.eventJson,
      'organizer_id': 'user-id',
      'visibility': 'public',
      'capacity': 100,
      'status': published ? 'published' : 'draft',
      'paid_review_status': status,
      'paid_sales_status': status == 'approved'
          ? 'active'
          : status == 'pending_review'
              ? status
              : 'not_ready',
      'registration_opens_at': '2026-01-01T00:00:00Z',
      'registration_closes_at': '2027-10-20T11:00:00Z',
      'available_ticket_types': [booking.ticketType()],
    };
Map<String, dynamic> checklist(String status) => {
      'status': status == 'approved'
          ? 'active'
          : status == 'pending_review'
              ? status
              : 'not_ready',
      'review_status': status,
      'review_reason': 'Please update the venue description.',
      'checklist': {
        'has_paid_ticket': true,
        'identity_verified': true,
        'payout_connected': true,
        'activation_fee_paid': true,
        'terms_accepted': true
      },
      'can_activate': !['approved', 'pending_review'].contains(status),
    };
void viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2000);
  addTearDown(tester.view.reset);
}

void main() {
  for (final entry in {
    'approved': 'Approved · ready to publish',
    'pending_review': 'Awaiting review',
    'rejected': 'Rejected',
    'changes_required': 'Needs resubmission'
  }.entries) {
    testWidgets('My Events shows ${entry.value} and opens the review step',
        (tester) async {
      viewport(tester);
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/organizer/events')) {
          return http.Response(jsonEncode([draft(entry.key)]), 200);
        }
        if (r.url.path.endsWith('/paid-sales')) {
          return http.Response(jsonEncode(checklist(entry.key)), 200);
        }
        return http.Response('[]', 200);
      }));
      await tester.pumpWidget(
          fixtures.app(api, UserRole.organizer, const OrganizerEventsScreen()));
      await tester.pumpAndSettle();
      await tester
          .element(find.byType(OrganizerEventsScreen))
          .read<DataService>()
          .refresh();
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(find.text('Community concert'));
      await tester.pumpAndSettle();
      expect(find.byType(PaidActivationPanel), findsOneWidget);
      final publish = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Publish Event'));
      expect(publish.onPressed, entry.key == 'approved' ? isNotNull : isNull);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    });
  }
  for (final state in ['draft', 'published', 'missing']) {
    testWidgets(
        'review notification opens current $state event without mutating it',
        (tester) async {
      viewport(tester);
      final requests = <http.Request>[];
      final api = ApiClient(client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/notifications')) {
          return http.Response(
              jsonEncode([
                {
                  'id': 'notice',
                  'title': 'Paid event approved',
                  'message': 'You can now publish.',
                  'is_read': false,
                  'kind': 'paid_event_review',
                  'data': {'event_id': 'event-id', 'status': 'approved'}
                }
              ]),
              200);
        }
        if (r.url.path.endsWith('/organizer/events')) {
          return http.Response(
              jsonEncode(state == 'missing'
                  ? []
                  : [draft('approved', published: state == 'published')]),
              200);
        }
        if (r.url.path.endsWith('/paid-sales')) {
          return http.Response(jsonEncode(checklist('approved')), 200);
        }
        return http.Response('[]', 200);
      }));
      await tester.pumpWidget(
          fixtures.app(api, UserRole.organizer, const NotificationsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open event'));
      await tester.pumpAndSettle();
      if (state == 'draft') {
        expect(find.byType(CreateEventScreen), findsOneWidget);
        expect(find.byType(PaidActivationPanel), findsOneWidget);
      } else if (state == 'published') {
        expect(find.byType(EventOverviewScreen), findsOneWidget);
      } else {
        expect(find.text('This event is no longer available to this account.'),
            findsOneWidget);
        expect(find.byType(CreateEventScreen), findsNothing);
      }
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    });
  }
}
