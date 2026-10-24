import 'dart:convert';
import 'package:biletflow_mobile/features/attendee/checkout_screen.dart';
import 'package:biletflow_mobile/features/attendee/order_details_screen.dart';
import 'package:biletflow_mobile/features/profile/account_screens.dart';
import 'package:biletflow_mobile/features/profile/support_screen.dart';
import 'package:biletflow_mobile/features/profile/organizer_application_screen.dart';
import 'package:biletflow_mobile/features/admin/organizer_applications_screen.dart';
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
  if (path.endsWith('/ticket-types')) payload = [type];
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
  LayoutAuth() : super(api);
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get currentUser => const AppUser(
      id: 'user-id',
      name: 'VeryLongFirstname Very Long Surname',
      email: 'long.email.address.for.layout.testing@example.com',
      role: UserRole.attendee);
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

void main() {
  final screens = <String, Widget Function()>{
    'attendee shell': () => const AttendeeShell(),
    'organizer shell': () => const OrganizerShell(),
    'admin shell': () => const AdminShell(),
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'home': () => const AttendeeHomeScreen(),
    'events': () => const AttendeeEventsScreen(),
    'event details': () => EventDetailsScreen(event: event),
    'tickets': () => const MyTicketsScreen(),
    'organizer dashboard': () => const OrganizerDashboardScreen(),
    'organizer events': () => const OrganizerEventsScreen(),
    'create event': () => const CreateEventScreen(),
    'event overview': () => EventOverviewScreen(event: event),
    'staff shell': () => const StaffShell(),
    'assign staff': () =>
        AssignStaffDialog(event: event, data: LayoutData(LayoutAuth())),
    'check-in': () => CheckinScreen(event: event),
    'admin dashboard': () => const AdminDashboardScreen(),
    'admin events': () => const AdminEventsScreen(),
    'admin users': () => const AdminUsersScreen(),
    'admin reports': () => const AdminReportsScreen(),
    'checkout': () => CheckoutScreen(event: event, items: const [
          {'ticket_type_id': 'type-id', 'quantity': 2}
        ], types: const []),
    'order details': () => const OrderDetailsScreen(orderId: 'order-id'),
    'edit profile': () => const EditProfileScreen(),
    'notifications': () => const NotificationsScreen(),
    'support': () => const SupportScreen(),
    'FAQ': () => const HelpScreen(),
    'profile': () => const ProfileScreen(),
    'application form': () => const OrganizerApplicationScreen(),
    'admin applications': () => const OrganizerApplicationsScreen(),
  };
  for (final locale in ['en', 'ru', 'kk']) {
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
          final auth = LayoutAuth();
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
                theme: ThemeData(
                    elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14))),
                    outlinedButtonTheme: OutlinedButtonThemeData(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14)))),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(config.scale)),
                    child: child!),
                home: screen.value(),
              )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Inspect content further down each scrollable page as well.
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -900));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}
