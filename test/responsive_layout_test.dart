import 'package:biletflow_mobile/features/operations/invitations_screen.dart';
import 'package:biletflow_mobile/features/operations/payouts_screen.dart';
import 'package:biletflow_mobile/features/admin/platform_settings_screen.dart';
import 'package:biletflow_mobile/features/organizer/ticket_inventory_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_management_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_operations_screen.dart';
import 'event_management_test.dart' as management_fixtures;
import 'package:biletflow_mobile/features/organizer/event_attendees_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_attendance_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:biletflow_mobile/features/staff/staff_event_status_badge.dart';
import 'package:biletflow_mobile/models/staff_event_filter.dart';
import 'package:biletflow_mobile/app/theme.dart';
import 'package:biletflow_mobile/features/auth/email_auth_screen.dart';
import 'package:biletflow_mobile/features/attendee/ticket_email_panel.dart';
import 'package:biletflow_mobile/features/attendee/checkout_screen.dart';
import 'package:biletflow_mobile/features/attendee/order_details_screen.dart';
import 'package:biletflow_mobile/features/profile/account_screens.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/features/profile/support_staff_dialog.dart';
import 'package:biletflow_mobile/features/profile/organizer_application_screen.dart';
import 'package:biletflow_mobile/features/admin/organizer_applications_screen.dart';
import 'package:biletflow_mobile/features/admin/paid_event_applications_screen.dart';
import 'paid_event_admin_test.dart' as paid_fixtures;
import 'package:biletflow_mobile/shared/widgets/paid_event_review_badge.dart';
import 'package:biletflow_mobile/shared/widgets/event_card.dart';
import 'package:biletflow_mobile/features/organizer/assign_staff_dialog.dart';
import 'package:biletflow_mobile/features/staff/staff_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:biletflow_mobile/l10n/gen/app_localizations.dart';
import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:biletflow_mobile/models/ticket.dart';
import 'package:biletflow_mobile/services/api_client.dart';
import 'package:biletflow_mobile/services/auth_service.dart';
import 'package:biletflow_mobile/services/data_service.dart';
import 'package:biletflow_mobile/services/locale_provider.dart';
import 'package:biletflow_mobile/features/auth/login_screen.dart';
import 'package:biletflow_mobile/features/attendee/attendee_shell.dart';
import 'package:biletflow_mobile/features/organizer/organizer_shell.dart';
import 'package:biletflow_mobile/features/admin/admin_shell.dart';
import 'package:biletflow_mobile/features/auth/register_screen.dart';
import 'package:biletflow_mobile/features/attendee/attendee_home_screen.dart';
import 'package:biletflow_mobile/features/attendee/attendee_events_screen.dart';
import 'package:biletflow_mobile/features/attendee/event_details_screen.dart';
import 'package:biletflow_mobile/features/attendee/my_tickets_screen.dart';
import 'package:biletflow_mobile/features/organizer/organizer_dashboard_screen.dart';
import 'package:biletflow_mobile/features/organizer/organizer_events_screen.dart';
import 'package:biletflow_mobile/features/organizer/create_event_screen.dart';
import 'package:biletflow_mobile/features/organizer/event_overview_screen.dart';
import 'package:biletflow_mobile/features/organizer/checkin_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_dashboard_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_events_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_users_screen.dart';
import 'package:biletflow_mobile/features/admin/admin_reports_screen.dart';
import 'package:biletflow_mobile/features/profile/profile_screen.dart';

final api = ApiClient(client: MockClient((request) async {
  final path = request.url.path;
  dynamic payload = [];
  final type = {
    'id': 'type-id',
    'name': 'A long ticket type name for admission',
    'kind': 'paid',
    'description': 'Ticket description',
    'price_minor': 125000,
    'quantity': 100,
    'sold_count': 2,
    'reserved_count': 0,
    'max_per_order': 5,
    'sales_start': '2025-01-01T00:00:00Z',
    'sales_end': '2035-01-01T00:00:00Z'
  };
  if (path.endsWith('/events/event-id')) {
    payload = {
      'id': 'event-id',
      'title': event.title,
      'description': event.description,
      'category': 'music',
      'status': 'published',
      'paid_sales_status': 'active',
      'starts_at': '2027-01-01T13:00:00Z',
      'ends_at': '2027-01-01T17:00:00Z',
      'venue': {
        'name': event.venue,
        'address': 'A very long street address in the city center',
        'city': event.city
      },
      'available_ticket_types': [type],
      'refund_policy':
          'Refunds are available according to the organizer policy. ' * 4,
    };
  }
  if (path.endsWith('/support/cases/case-id/messages') ||
      path.endsWith('/support/cases/platform-case/messages')) {
    payload = [
      {
        'sender_id': 'attendee-id',
        'body': 'Please review my refund request for this event.'
      }
    ];
  }
  if (path.endsWith('/support/cases/platform-case')) {
    payload = {
      'id': 'platform-case',
      'flow': 'organizer_platform',
      'number': 'BF-12345',
      'subject': 'A long platform activation support case title',
      'category': 'activation',
      'status': 'waiting_for_customer',
      'event_title': event.title,
      'can_manage': true,
      'can_refund': false
    };
  }
  if (path.endsWith('/support/cases/case-id')) {
    payload = {
      'id': 'case-id',
      'subject': 'Refund request for a long event name',
      'category': 'refund',
      'status': 'open',
      'event_title': event.title,
      'order_id': 'order-id',
      'order_status': 'confirmed',
      'refund_policy': 'Full refunds are available before the event starts.',
      'can_manage': true,
      'can_refund': true,
      'order_total_minor': 123456789000
    };
  }
  if (path.endsWith('/attendees')) {
    payload = [
      {
        'id': 'ticket-id',
        'attendee_name': 'A very long attendee name for admission testing',
        'attendee_email': 'a.very.long.attendee.email.address@example.com',
        'status': 'valid',
        'ticket_type': 'A long general admission ticket type name',
        'record_id': null
      }
    ];
  }
  if (path.endsWith('/analytics')) {
    payload = management_fixtures.analyticsFixture();
  }
  if (path.endsWith('/activity')) {
    payload = management_fixtures.historyFixture();
  }
  if (path.endsWith('/operations/orders')) {
    payload = {
      'orders': [
        {
          'id': 'order-with-a-long-reference-for-layout-testing',
          'event_id': 'event-id',
          'event_title':
              'An event with a long title for operational monitoring',
          'attendee_name':
              'A very long attendee name for the operations monitor',
          'attendee_email': 'a.very.long.attendee.email.address@example.com',
          'status': 'payment_failed',
          'total_minor': 123456789000,
          'created_at': '2026-10-27T10:00:00Z',
          'payments': [
            {
              'status': 'failed',
              'amount_minor': 123456789000,
              'reference':
                  'sim_payment_with_a_long_provider_reference_for_testing'
            }
          ],
          'refunds': [],
        }
      ],
      'activation_fee_minor': 100000,
      'processing_fee_bps': 300
    };
  }
  if (path.endsWith('/inventory')) {
    payload = {
      'event_status': 'draft',
      'capacity': 100,
      'refund_policy': 'Refund before start',
      'registration_opens_at': '2027-01-01T00:00:00Z',
      'registration_closes_at': '2027-10-20T10:00:00Z',
      'ticket_types': [
        {
          ...type,
          'editable': true,
          'available': 100,
          'checked_in': 0,
          'sold_count': 0,
          'refunded_count': 0,
          'is_hidden': false
        }
      ]
    };
  }
  if (path.endsWith('/invitations')) {
    payload = [
      {
        'id': 'invitation-id',
        'email': 'a.long.invited.attendee.address@example.com',
        'status': 'accepted',
        'expires_at': '2027-10-20T10:00:00Z'
      }
    ];
  }
  if (path.endsWith('/events/invited/mine')) {
    payload = [
      {
        ...paid_fixtures.paidApplication()['event'] as Map,
        'visibility': 'private'
      }
    ];
  }
  if (path.endsWith('/admin/platform-settings')) {
    payload = {
      'activation_fee_minor': 100000,
      'processing_fee_bps': 300,
      'hold_minutes': 15,
      'version': 1
    };
  }
  if (path.endsWith('/organizer/payouts')) {
    payload = [
      {
        'event_id': 'event-id',
        'event_title': 'A long event title for simulated payout testing',
        'gross_minor': 123456789000,
        'discounts_minor': 120000,
        'fees_minor': 30000,
        'refunds_minor': 500000,
        'estimated_payout_minor': 1234560000,
        'status': 'pending',
        'eligible': true,
        'open_dispute': false,
        'amount_minor': 0,
        'note': 'Waiting for demonstration settlement.'
      }
    ];
  }
  if (path.endsWith('/ticket-types')) payload = [type];
  if (path.endsWith('/events/event-id/orders')) {
    payload = [
      {
        'id': 'order-id',
        'attendee_name': 'A very long attendee name for the guest list',
        'attendee_email':
            'a.very.long.email.address.for.attendee.testing@example.com',
        'status': 'confirmed',
        'total_minor': 123456789000,
        'items': [
          {'quantity': 10}
        ]
      }
    ];
  }
  if (path.endsWith('/orders/order-id')) {
    payload = {
      'id': 'order-id',
      'event_id': 'event-id',
      'status': 'confirmed',
      'attendee_name': 'A long attendee name for ticket holder',
      'attendee_email': 'long.address@example.com',
      'total_minor': 12345000,
      'subtotal_minor': 12000000,
      'discount_minor': 0,
      'processing_fee_minor': 345000,
      'tickets': [
        {
          'id': 'ticket-id',
          'attendee_name': 'Long attendee name',
          'status': 'valid',
          'qr_credential': 'ticket.signed-credential'
        },
        {
          'id': 'refunded-ticket',
          'attendee_name': 'Long attendee name',
          'status': 'refunded',
          'qr_credential': 'ticket.refunded'
        }
      ]
    };
  }
  if (path.endsWith('/organizer-applications/me')) payload = null;
  if (path.endsWith('/users/me')) {
    payload = {
      'id': 'user-id',
      'full_name': 'Very long full name',
      'email': 'test@example.com',
      'roles': ['attendee']
    };
  }
  return http.Response(jsonEncode(payload), 200);
}));

class LayoutAuth extends AuthService {
  LayoutAuth({this.role = UserRole.attendee}) : super(api);
  final UserRole role;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get currentUser => AppUser(
      id: 'user-id',
      name: 'VeryLongFirstname Very Long Surname',
      email: 'long.email.address.for.layout.testing@example.com',
      role: role);
}

final event = AppEvent(
    id: 'event-id',
    title: 'A very long event title that should wrap on smaller phones',
    date: DateTime(2027),
    startTime: '18:00',
    endTime: '22:00',
    venue: 'Long venue name',
    city: 'Almaty',
    description: 'A long event description. ' * 5,
    organizerName: 'Long Organizer Name',
    price: 12345678,
    category: EventCategory.music,
    accentColor: Colors.blue,
    icon: Icons.event,
    featured: true);

class LayoutData extends DataService {
  LayoutData(AuthService auth) : super(api, auth) {
    errorMessage =
        'A long backend connection error that should remain scrollable without hiding the screen. ' *
            3;
  }
  @override
  List<AppEvent> get events => [event];
  @override
  List<AppEvent> get featuredEvents => events;
  @override
  List<AppEvent> eventsByOrganizer(String _) => events;
  @override
  List<AppTicket> ticketsByStatus(TicketStatus status) => [
        AppTicket(
            id: 'ticket-123456',
            event: event,
            ticketCode: 'ticket.signed-test-credential',
            status: status,
            holderName: 'Attendee')
      ];
  @override
  List<AdminUserRow> get adminUsers => [AdminUserRow(user: auth.currentUser!)];
  @override
  double get totalRevenue => 1234567890123;
}

void expectTranslatedLabelsFit(WidgetTester tester, Set<String> labels) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject as RenderParagraph;
    final text = paragraph.text.toPlainText();
    var isActionLabel = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is ButtonStyleButton || ancestor.widget is RawChip) {
        isActionLabel = true;
        return false;
      }
      return true;
    });
    // Buttons and filter chips must show their full action. Editable-field
    // hints and navigation titles follow their own scrolling/truncation rules.
    if (isActionLabel && labels.contains(text)) {
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: 'Translated label is clipped: $text');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(
          rootBundle.load('assets/fonts/noto_sans/NotoSans-$weight.ttf'));
    }
    await font.load();
  });
  final screens = <String, Widget Function()>{
    'attendee shell': () => const AttendeeShell(),
    'organizer shell': () => const OrganizerShell(),
    'admin shell': () => const AdminShell(),
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'verify email demo': () => const EmailAuthScreen(),
    'password reset demo': () => const EmailAuthScreen(
        resetPassword: true, initialEmail: 'demo@example.com'),
    'ticket email demo': () => Scaffold(
            body: ListView(children: [
          TicketEmailPanel(
              orderId: 'order-123',
              email: 'demo@example.com',
              attendeeName: 'Example Guest',
              totalMinor: 125000,
              event: event,
              ticketIds: const ['ticket-12345678-long-id']),
        ])),
    'home': () => const AttendeeHomeScreen(),
    'events': () => const AttendeeEventsScreen(),
    'event details': () => EventDetailsScreen(event: event),
    'tickets': () => const MyTicketsScreen(),
    'organizer dashboard': () => const OrganizerDashboardScreen(),
    'organizer events': () => const OrganizerEventsScreen(),
    'approved organizer event': () => Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
          EventCard(
              event: event,
              trailingBadge: const PaidEventReviewBadge(status: 'approved'))
        ])),
    'create event': () => const CreateEventScreen(),
    'admin event controls': () => const EventManagementScreen(
        eventId: 'event-id', title: 'A long event title for operations'),
    'event analytics': () => const EventManagementScreen(
        eventId: 'event-id', title: 'A long event title for analytics'),
    'event activity history': () => const EventManagementScreen(
        eventId: 'event-id',
        title: 'A long event title for activity',
        historyOnly: true),
    'ticket inventory': () => const TicketInventoryScreen(
        eventId: 'event-id', title: 'A long event title for inventory'),
    'private invitations': () => const InvitationsScreen(
        eventId: 'event-id', title: 'A long private event title'),
    'invited events': () => const InvitedEventsScreen(),
    'platform settings': () => const PlatformSettingsScreen(),
    'event report chat': () => const SupportScreen(
        eventId: 'event-id',
        subject: 'An event with a long title',
        initialCategory: 'report_event',
        startNew: true,
        view: 'mine'),
    'organizer payouts': () => const PayoutsScreen(),
    'admin payouts': () => const PayoutsScreen(),
    'operations monitor': () => const AdminOperationsScreen(),
    'event overview': () => EventOverviewScreen(event: event),
    'event attendees': () => const EventAttendeesScreen(
        eventId: 'event-id', eventTitle: 'An event with a long title'),
    'event attendance': () => const EventAttendanceScreen(
        eventId: 'event-id', eventTitle: 'A long event title for attendance'),
    'staff shell': () => const StaffShell(),
    'staff event statuses': () => Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
          for (final group in StaffEventFilter.values
              .where((g) => g != StaffEventFilter.all))
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventCard(
                    event: event,
                    trailingBadge: StaffEventStatusBadge(group: group))),
        ])),
    'assign staff': () =>
        AssignStaffDialog(event: event, data: LayoutData(LayoutAuth())),
    'check-in': () => CheckinScreen(event: event),
    'admin dashboard': () => const AdminDashboardScreen(),
    'admin events': () => const AdminEventsScreen(),
    'admin users': () => const AdminUsersScreen(),
    'admin reports': () => const AdminReportsScreen(),
    'paid event applications': () => const PaidEventApplicationsScreen(),
    'paid event review': () =>
        PaidEventReviewScreen(application: paid_fixtures.paidApplication()),
    'checkout': () => CheckoutScreen(event: event, items: const [
          {'ticket_type_id': 'type-id', 'quantity': 2}
        ], types: const []),
    'order details': () => const OrderDetailsScreen(orderId: 'order-id'),
    'edit profile': () => const EditProfileScreen(),
    'notifications': () => const NotificationsScreen(),
    'support': () => const SupportScreen(),
    'platform support request': () => const SupportScreen(
        flow: 'organizer_platform', view: 'mine', startNew: true),
    'platform support conversation': () => const SupportScreen(
        caseId: 'platform-case', flow: 'organizer_platform', view: 'inbox'),
    'authorize support staff': () => const Scaffold(body: SupportStaffDialog()),
    'refund request': () => const SupportScreen(
        startNew: true,
        initialCategory: 'refund',
        eventId: 'event-id',
        orderId: 'order-id'),
    'refund approval': () => const SupportScreen(caseId: 'case-id'),
    'FAQ': () => const HelpScreen(),
    'organizer FAQ': () => ChangeNotifierProvider<AuthService>(
        create: (_) => LayoutAuth(role: UserRole.organizer),
        child: const HelpScreen()),
    'profile': () => const ProfileScreen(),
    'application form': () => const OrganizerApplicationScreen(),
    'admin applications': () => const OrganizerApplicationsScreen(),
  };
  for (final locale in ['en', 'ru', 'kk']) {
    final labels =
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>)
            .entries
            .where((e) => !e.key.startsWith('@') && e.value is String)
            .map((e) => e.value as String)
            .toSet();
    for (final config in [
      (size: const Size(800, 1024), scale: 1.5, keyboard: 0.0),
      (size: const Size(320, 568), scale: 1.0, keyboard: 0.0),
      (size: const Size(320, 568), scale: 2.0, keyboard: 0.0),
      (size: const Size(568, 320), scale: 1.5, keyboard: 0.0),
      (size: const Size(320, 568), scale: 1.5, keyboard: 250.0),
    ]) {
      for (final screen in screens.entries) {
        testWidgets(
            '${screen.key} $locale ${config.size} text ${config.scale} keyboard ${config.keyboard}',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = config.size;
          tester.view.viewInsets = FakeViewPadding(bottom: config.keyboard);
          addTearDown(tester.view.reset);
          final auth = LayoutAuth(
              role: [
            'admin event controls',
            'platform settings',
            'admin payouts'
          ].contains(screen.key)
                  ? UserRole.admin
                  : [
                      'event overview',
                      'event attendees',
                      'event analytics',
                      'ticket inventory',
                      'private invitations',
                      'organizer payouts'
                    ].contains(screen.key)
                      ? UserRole.organizer
                      : UserRole.attendee);
          await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthService>.value(value: auth),
                ChangeNotifierProvider<DataService>(
                    create: (_) => LayoutData(auth)),
                ChangeNotifierProvider(create: (_) => LocaleProvider()),
              ],
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(config.scale)),
                    child: child!),
                home: screen.value(),
              )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectTranslatedLabelsFit(tester, labels);
          if (screen.key == 'operations monitor') {
            final l = AppLocalizations.of(
                tester.element(find.byType(AdminOperationsScreen)));
            await tester.scrollUntilVisible(find.text(l.operationsDetails), 200,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.operationsDetails));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if ([
            'ticket inventory',
            'private invitations',
            'invited events',
            'platform settings',
            'admin payouts'
          ].contains(screen.key)) {
            final l = AppLocalizations.of(
                tester.element(find.byType(Scaffold).first));
            final action = switch (screen.key) {
              'ticket inventory' => l.opsEditTicket,
              'private invitations' => l.opsInvite,
              'invited events' => l.opsJoin,
              'platform settings' => l.opsSave,
              _ => l.opsPayoutUpdate,
            };
            await tester.scrollUntilVisible(find.text(action).first, 200,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.tap(find.text(action).first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectTranslatedLabelsFit(tester, labels);
          }
          if (screen.key == 'password reset demo') {
            final l = AppLocalizations.of(
                tester.element(find.byType(EmailAuthScreen)));
            await tester.scrollUntilVisible(
                find.text(l.passwordSendDemoCode), 180,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.passwordSendDemoCode));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
                find.byKey(const ValueKey('email-demo-code')), findsOneWidget);
          }
          if (screen.key == 'ticket email demo') {
            final l = AppLocalizations.of(
                tester.element(find.byType(TicketEmailPanel)));
            await tester.ensureVisible(find.text(l.emailPreviewAction));
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.emailPreviewAction));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          // Inspect content further down each scrollable page as well.
          final scroll = screen.key == 'ticket email demo'
              ? find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable))
              : find.byType(AlertDialog).evaluate().isNotEmpty
                  ? find.descendant(
                      of: find.byType(AlertDialog).last,
                      matching: find.byType(Scrollable))
                  : find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -900));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectTranslatedLabelsFit(tester, labels);
          }
        });
      }
    }
  }
}
