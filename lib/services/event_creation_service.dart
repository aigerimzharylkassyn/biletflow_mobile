import 'dart:convert';
import '../models/event_creation.dart';
import 'api_client.dart';

/// Retains saved IDs after partial failures so retries do not recreate saved rows.
class EventCreationService {
  EventCreationService(this.api);
  final ApiClient api;
  final details = EventDraft();
  final tickets = <TicketDraft>[];
  Map<String, dynamic>? saved;
  bool bannerFailed = false;
  String _savedBanner = '';
  final _keys = <String, (String, String)>{};
  String get id => saved!['id'] as String;
  String _key(String name, Object body) {
    final signature = jsonEncode(body);
    if (_keys[name]?.$1 != signature) _keys[name] = (signature, creationKey());
    return _keys[name]!.$2;
  }

  Future<void> resume(String draftId) async {
    final rows = await api.request('GET', '/organizer/events') as List;
    final row = rows.where((e) => e['id'] == draftId).firstOrNull;
    if (row == null) throw const ApiException('Draft not found.', 404);
    if (row['status'] != 'draft') throw const CreationValidation('notDraft');
    saved = Map<String, dynamic>.from(row);
    details.load(saved!);
    _savedBanner = details.fields['banner']!;
    tickets.clear();
    details.freeOnly = !(row['available_ticket_types'] as List? ?? [])
        .any((type) => type['kind'] == 'paid');
    for (final type in row['available_ticket_types'] as List? ?? []) {
      tickets.add(TicketDraft(details)..load(Map<String, dynamic>.from(type)));
    }
  }

  Future<void> saveDetails() async {
    final body = details.body();
    if (saved == null) {
      saved = Map<String, dynamic>.from(await api.request('POST', '/events',
          body: body, idempotencyKey: _key('event', body)));
    } else {
      final update = Map<String, dynamic>.from(body)
        ..remove('venue')
        ..remove('time_zone')
        ..remove('admission_type');
      saved = Map<String, dynamic>.from(
          await api.request('PATCH', '/events/$id', body: update));
    }
    final banner = details.fields['banner']!.trim();
    bannerFailed = false;
    if (banner.isNotEmpty && banner != _savedBanner) {
      try {
        await api.request('POST', '/events/$id/images', body: {'url': banner});
        _savedBanner = banner;
      } catch (_) {
        bannerFailed = true;
        rethrow;
      }
    }
    if (tickets.isEmpty) tickets.add(TicketDraft(details, initial: true));
  }

  void skipBanner() {
    details.fields['banner'] = '';
    bannerFailed = false;
    if (tickets.isEmpty) tickets.add(TicketDraft(details, initial: true));
  }

  Future<void> saveTickets() async {
    if (saved == null || tickets.isEmpty) {
      throw const CreationValidation('tickets');
    }
    final bodies = tickets.map((t) => t.body(details)).toList();
    if (bodies.fold<int>(0, (sum, t) => sum + (t['quantity'] as int)) >
        positiveWhole(details.fields['capacity']!)) {
      throw const CreationValidation('capacity');
    }
    for (var i = 0; i < tickets.length; i++) {
      final ticket = tickets[i];
      if (ticket.savedId != null) continue;
      final row = await api.request('POST', '/events/$id/ticket-types',
          body: bodies[i], idempotencyKey: _key(ticket.key, bodies[i]));
      ticket.savedId = row['id'];
    }
  }

  Future<Map<String, dynamic>> checklist() async => Map<String, dynamic>.from(
      await api.request('GET', '/events/$id/paid-sales'));
  Future<void> publish() async {
    await api.request('POST', '/events/$id/publish',
        idempotencyKey: _key('publish', id));
  }
}
