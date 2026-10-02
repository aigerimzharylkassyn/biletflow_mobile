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
  DataService(this.api, this.auth) { auth.addListener(_sessionChanged); }
  final ApiClient api;
  final AuthService auth;
  String? _userId;
  int _generation = 0;
  bool isLoading = false;
  String? errorMessage;
  List<AppEvent> _events = [];
  List<AppTicket> _tickets = [];
  List<AdminUserRow> _adminUsers = [];
  final Map<String, String> _organizers = {};
  List<AppEvent> get events => List.unmodifiable(_events);
  List<AppTicket> get tickets => List.unmodifiable(_tickets);
  List<AdminUserRow> get adminUsers => List.unmodifiable(_adminUsers);
  List<AppEvent> get featuredEvents => _events.where((e) => e.featured).take(5).toList();
  List<AppEvent> eventsByOrganizer(String _) => _events.where((e) => _organizers[e.id] == auth.currentUser?.id).toList();
  List<AppTicket> ticketsByStatus(TicketStatus status) => _tickets.where((t) => t.status == status).toList();
  int get totalTicketsSold => _events.fold(0, (sum, e) => sum + e.ticketsSold);
  Map<String, List<Map<String, dynamic>>> _orders = {};
  List<Map<String, dynamic>> eventOrders(String eventId) => _orders[eventId] ?? [];
  double eventRevenue(String eventId) => eventOrders(eventId).fold<double>(0, (sum, o) => sum + (o["total_minor"] as num) / 100);
  double _revenue = 0;
  double get totalRevenue => _revenue;
  void _sessionChanged() {
    if (_userId == auth.currentUser?.id) return;
    _userId = auth.currentUser?.id;
    _generation++;
    _events = []; _tickets = []; _adminUsers = []; _organizers.clear(); _revenue = 0; _orders = {};
    errorMessage = null;
    if (_userId != null) { refresh(); } else { isLoading = false; notifyListeners(); }
  }
  Future<void> refresh() async {
    final user = auth.currentUser;
    if (user == null) return;
    final generation = ++_generation;
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      final path = switch(user.role) {
        UserRole.admin => '/admin/events',
        UserRole.organizer => '/organizer/events',
        UserRole.staff => '/check-in/events',
        UserRole.attendee => '/events',
      };
      final rows = (await api.request('GET', path) as List).cast<Map<String, dynamic>>();
      final events = rows.map(AppEvent.fromJson).toList();
      final tickets = <AppTicket>[];
      final users = <AdminUserRow>[];
      double revenue = 0;
      final eventOrders = <String, List<Map<String, dynamic>>>{};
      if (user.role == UserRole.attendee) {
        final ticketRows = await api.request('GET', '/tickets') as List;
        for (final row in ticketRows) {
          final event = events.where((e) => e.id == row['event_id']).firstOrNull ??
              AppEvent.fromJson(Map<String, dynamic>.from(await api.request('GET', '/tickets/${row['id']}/event')));
          tickets.add(AppTicket(id: row['id'], event: event, ticketCode: row['qr_credential'],
            status: row['status'] == 'valid' && event.date.isAfter(DateTime.now()) ? TicketStatus.upcoming : TicketStatus.past,
            holderName: row['attendee_name']));
        }
      } else if (user.role == UserRole.admin) {
        final userRows = await api.request('GET', '/admin/users') as List;
        for (final row in userRows) {
          users.add(AdminUserRow(user: AppUser.fromJson(Map<String, dynamic>.from(row)), active: row['is_active']));
        }
      }
      // Calculate revenue from settled orders, including fees and discounts.
      if (user.role == UserRole.organizer || user.role == UserRole.admin) {
        for (final event in events) {
          final orders = await api.request('GET', '/events/${event.id}/orders') as List;
          eventOrders[event.id] = orders.where((o) => o['status'] == 'confirmed').map((o) => Map<String, dynamic>.from(o)).toList();
          revenue += orders.where((o) => o['status'] == 'confirmed').fold<double>(0, (sum, o) => sum + (o['total_minor'] as num) / 100);
        }
      }
      if (generation != _generation) return;
      _events = events; _tickets = tickets; _adminUsers = users; _revenue = revenue; _orders = eventOrders;
      _organizers.clear();
      for (final row in rows) { _organizers[row['id']] = row['organizer_id']; }
    } catch (error) {
      if (generation == _generation) errorMessage = error.toString();
    } finally {
      if (generation == _generation) { isLoading = false; notifyListeners(); }
    }
  }
  Future<List<Map<String, dynamic>>> ticketTypes(AppEvent event) async {
    final rows = (await api.request('GET', '/events/${event.id}/ticket-types') as List).cast<Map<String, dynamic>>();
    final now = DateTime.now().toUtc();
    DateTime utc(String value) => DateTime.parse(RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value) ? value : '${value}Z');
    return rows.where((t) => t['quantity'] > t['sold_count'] + t['reserved_count'] &&
      !now.isBefore(utc(t['sales_start'])) && now.isBefore(utc(t['sales_end']))).toList();
  }
  Future<Map<String, dynamic>> checkout(AppEvent event, String typeId) async {
    final user = auth.currentUser!;
    return Map<String, dynamic>.from(await api.request('POST', '/checkout/sessions', body: {
      'event_id': event.id, 'attendee_name': user.name, 'attendee_email': user.email,
      'items': [{'ticket_type_id': typeId, 'quantity': 1}],
    }));
  }
  Future<void> cancelCheckout(String orderId) async {
    await api.request('POST', '/checkout/sessions/$orderId/complete', body: {'outcome': 'failure'});
  }
  Future<void> completeCheckout(String orderId) async {
    await api.request('POST', '/checkout/sessions/$orderId/complete', body: {'outcome': 'success'});
    await refresh();
  }
  Future<void> createEvent(AppEvent event, {required String address, required String city}) async {
    final start = DateTime(event.date.year, event.date.month, event.date.day, 18).toUtc();
    final end = start.add(const Duration(hours: 4));
    final now = DateTime.now().toUtc().toIso8601String();
    final draft = await api.request('POST', '/events', body: {
      'title': event.title, 'description': event.description, 'category': event.category.name,
      'venue': {'name': event.venue, 'address': address, 'city': city},
      'starts_at': start.toIso8601String(), 'ends_at': end.toIso8601String(),
      'registration_opens_at': now, 'registration_closes_at': start.toIso8601String(),
      'capacity': event.ticketsTotal,
    });
    final id = draft['id'];
    try {
      await api.request('POST', '/events/$id/ticket-types', body: {
        'name': 'General admission', 'kind': event.isFree ? 'free' : 'paid',
        'price_minor': (event.price * 100).round(), 'quantity': event.ticketsTotal,
        'sales_start': now, 'sales_end': start.toIso8601String(),
      });
      await api.request('POST', '/events/$id/publish');
    } catch (error) {
      await refresh();
      throw ApiException('Draft $id was saved, but publishing did not finish: $error');
    }
    await refresh();
  }
  Future<void> toggleUserActive(String userId) async {
    final row = _adminUsers.firstWhere((r) => r.user.id == userId);
    if (!row.active) throw const ApiException('The backend does not support reactivating suspended accounts.');
    await api.request('POST', '/admin/users/$userId/suspend');
    await refresh();
  }
  Future<String> admit(String eventId, String credential) async {
    final result = await api.request('POST', '/check-in/events/$eventId/admit?qr_payload=${Uri.encodeQueryComponent(credential)}');
    return result['attendee_name'];
  }
  @override
  void dispose() { auth.removeListener(_sessionChanged); super.dispose(); }
}
