import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart';

class AdminUserRow {
  final AppUser user;
  bool active;
  AdminUserRow({required this.user, this.active = true});
}

class DataService extends ChangeNotifier {
  DataService(this.api, this.auth) {
    auth.addListener(_sessionChanged);
  }
  final ApiClient api;
  final AuthService auth;
  String? _userId;
  UserRole? _userRole;
  int _generation = 0;
  bool isLoading = false;
  String? errorMessage;
  List<AppEvent> _events = [];
  List<AppTicket> _tickets = [];
  List<Map<String, dynamic>> _attendeeOrders = [];
  List<Map<String, dynamic>> get attendeeOrders =>
      List.unmodifiable(_attendeeOrders);
  List<AdminUserRow> _adminUsers = [];
  final Map<String, String> _organizers = {};
  List<AppEvent> get events => List.unmodifiable(_events);
  List<AppTicket> get tickets => List.unmodifiable(_tickets);
  List<AdminUserRow> get adminUsers => List.unmodifiable(_adminUsers);
  List<AppEvent> get featuredEvents =>
      _events.where((e) => e.featured).take(5).toList();
  List<AppEvent> eventsByOrganizer(String _) =>
      _events.where((e) => _organizers[e.id] == auth.currentUser?.id).toList();
  List<AppTicket> ticketsByStatus(TicketStatus status) =>
      _tickets.where((t) => t.status == status).toList();
  int get totalTicketsSold => _events.fold(0, (sum, e) => sum + e.ticketsSold);
  Map<String, List<Map<String, dynamic>>> _orders = {};
  List<Map<String, dynamic>> eventOrders(String eventId) =>
      _orders[eventId] ?? [];
  double eventRevenue(String eventId) => eventOrders(eventId)
      .fold<double>(0, (sum, o) => sum + (o["total_minor"] as num) / 100);
  double _revenue = 0;
  double get totalRevenue => _revenue;
  void _sessionChanged() {
    if (_userId == auth.currentUser?.id && _userRole == auth.currentUser?.role) {
      return;
    }
    _userId = auth.currentUser?.id;
    _userRole = auth.currentUser?.role;
    _generation++;
    _events = [];
    _tickets = [];
    _attendeeOrders = [];
    _adminUsers = [];
    _organizers.clear();
    _revenue = 0;
    _orders = {};
    errorMessage = null;
    if (_userId != null) {
      refresh();
    } else {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final user = auth.currentUser;
    if (user == null) return;
    final generation = ++_generation;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final path = switch (user.role) {
        UserRole.admin => '/admin/events',
        UserRole.organizer => '/organizer/events',
        UserRole.staff => '/check-in/events',
        UserRole.attendee => '/events',
      };
      final rows =
          (await api.request('GET', path) as List).cast<Map<String, dynamic>>();
      final events = rows.map(AppEvent.fromJson).toList();
      final tickets = <AppTicket>[];
      final ownedOrders = <Map<String, dynamic>>[];
      final users = <AdminUserRow>[];
      double revenue = 0;
      final eventOrders = <String, List<Map<String, dynamic>>>{};
      if (user.role == UserRole.attendee) {
        ownedOrders.addAll((await api.request('GET', '/orders') as List)
            .map((o) => Map<String, dynamic>.from(o)));
        final ticketRows = await api.request('GET', '/tickets') as List;
        for (final row in ticketRows) {
          final event =
              events.where((e) => e.id == row['event_id']).firstOrNull ??
                  AppEvent.fromJson(Map<String, dynamic>.from(
                      await api.request('GET', '/tickets/${row['id']}/event')));
          tickets.add(AppTicket(
              id: row['id'],
              event: event,
              ticketCode: row['qr_credential'],
              status: row['status'] == 'valid' &&
                      (event.endsAt ?? event.date).isAfter(DateTime.now())
                  ? TicketStatus.upcoming
                  : TicketStatus.past,
              holderName: row['attendee_name'],
              admissionStatus: row['status'],
              orderId: row['order_id'],
              ticketTypeId: row['ticket_type_id'],
              seat: row['seat'],
              section: row['section'],
              row: row['row']));
        }
      } else if (user.role == UserRole.admin) {
        final userRows = await api.request('GET', '/admin/users') as List;
        for (final row in userRows) {
          users.add(AdminUserRow(
              user: AppUser.fromJson(Map<String, dynamic>.from(row)),
              active: row['is_active']));
        }
      }
      // Calculate revenue from settled orders, including fees and discounts.
      if (user.role == UserRole.organizer || user.role == UserRole.admin) {
        for (final event in events) {
          final orders =
              await api.request('GET', '/events/${event.id}/orders') as List;
          eventOrders[event.id] = orders
              .where((o) => o['status'] == 'confirmed')
              .map((o) => Map<String, dynamic>.from(o))
              .toList();
          revenue += orders
              .where((o) => o['status'] == 'confirmed')
              .fold<double>(
                  0, (sum, o) => sum + (o['total_minor'] as num) / 100);
        }
      }
      if (generation != _generation) return;
      _events = events;
      _tickets = tickets;
      _attendeeOrders = ownedOrders;
      _adminUsers = users;
      _revenue = revenue;
      _orders = eventOrders;
      _organizers.clear();
      for (final row in rows) {
        _organizers[row['id']] = row['organizer_id'];
      }
    } catch (error) {
      if (generation == _generation) errorMessage = error.toString();
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<AppEvent> eventDetails(String id) async => AppEvent.fromJson(
      Map<String, dynamic>.from(await api.request('GET', '/events/$id')));
  Future<Map<String, dynamic>> orderDetails(String id) async =>
      Map<String, dynamic>.from(await api.request('GET', '/orders/$id'));
  Future<Map<String, dynamic>> quote(String eventId,
          List<Map<String, dynamic>> items, String promo) async =>
      Map<String, dynamic>.from(
          await api.request('POST', '/promo-codes/validate', body: {
        'event_id': eventId,
        'items': items,
        'promo_code': promo.trim().isEmpty ? null : promo.trim().toUpperCase(),
      }));
  Future<List<Map<String, dynamic>>> allTicketTypes(String eventId) async =>
      (await api.request('GET', '/events/$eventId/ticket-types') as List)
          .map((t) => Map<String, dynamic>.from(t))
          .where((t) => t['is_hidden'] != true)
          .toList();
  Future<Map<String, dynamic>> reserveTickets(
          String eventId, List<Map<String, dynamic>> items,
          {required String name,
          required String email,
          required String key,
          String promo = ''}) async =>
      Map<String, dynamic>.from(await api
          .request('POST', '/checkout/sessions', idempotencyKey: key, body: {
        'event_id': eventId,
        'items': items,
        'attendee_name': name.trim(),
        'attendee_email': email.trim(),
        if (promo.trim().isNotEmpty) 'promo_code': promo.trim().toUpperCase(),
      }));
  Future<Map<String, dynamic>> confirmReservation(String id, String key) async {
    final result = Map<String, dynamic>.from(await api.request(
        'POST', '/checkout/sessions/$id/complete',
        idempotencyKey: key, body: {'outcome': 'success'}));
    if (result['status'] != 'confirmed') {
      throw const ApiException(
          'Booking was not confirmed. No tickets have been issued.');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> ticketTypes(AppEvent event) async {
    final rows =
        (await api.request('GET', '/events/${event.id}/ticket-types') as List)
            .cast<Map<String, dynamic>>();
    final now = DateTime.now().toUtc();
    DateTime utc(String value) => DateTime.parse(
        RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value) ? value : '${value}Z');
    return rows
        .where((t) =>
            t['quantity'] > t['sold_count'] + t['reserved_count'] &&
            !now.isBefore(utc(t['sales_start'])) &&
            now.isBefore(utc(t['sales_end'])))
        .toList();
  }

  Future<Map<String, dynamic>> checkout(AppEvent event, String typeId) async {
    final user = auth.currentUser!;
    return Map<String, dynamic>.from(
        await api.request('POST', '/checkout/sessions', body: {
      'event_id': event.id,
      'attendee_name': user.name,
      'attendee_email': user.email,
      'items': [
        {'ticket_type_id': typeId, 'quantity': 1}
      ],
    }));
  }

  Future<void> cancelCheckout(String orderId) async {
    await api.request('POST', '/checkout/sessions/$orderId/complete',
        body: {'outcome': 'failure'});
  }

  Future<void> completeCheckout(String orderId) async {
    await api.request('POST', '/checkout/sessions/$orderId/complete',
        body: {'outcome': 'success'});
    await refresh();
  }

  Future<void> toggleUserActive(String userId) async {
    final row = _adminUsers.firstWhere((r) => r.user.id == userId);
    if (!row.active) {
      throw const ApiException(
          'The backend does not support reactivating suspended accounts.');
    }
    await api.request('POST', '/admin/users/$userId/suspend');
    await refresh();
  }

  Future<void> assignStaff(String eventId, String email) async {
    final query =
        Uri(queryParameters: {'email': email.trim().toLowerCase()}).query;
    await api.request('POST', '/events/$eventId/staff?$query');
  }

  Future<String> admit(String eventId, String credential) async {
    final result = await api.request('POST',
        '/check-in/events/$eventId/admit?qr_payload=${Uri.encodeQueryComponent(credential)}');
    return result['attendee_name'];
  }

  @override
  void dispose() {
    auth.removeListener(_sessionChanged);
    super.dispose();
  }
}
