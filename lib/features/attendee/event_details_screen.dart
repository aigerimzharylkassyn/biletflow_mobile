import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import '../../services/api_client.dart';
import 'attendee_ui.dart';
import 'checkout_screen.dart';

int ticketLimit(AppEvent event, Map<String, dynamic> type, {DateTime? now}) {
  final clock = (now ?? DateTime.now()).toUtc();
  bool before(DateTime? v) => v != null && clock.isBefore(v.toUtc());
  bool after(DateTime? v) => v != null && !clock.isBefore(v.toUtc());
  DateTime? date(dynamic value) => value is String ? parseApiDate(value) : null;
  if (event.eventStatus != 'published' ||
      type['is_hidden'] == true ||
      before(event.registrationOpensAt) ||
      after(event.registrationClosesAt) ||
      before(date(type['sales_start'])) ||
      after(date(type['sales_end']))) {
    return 0;
  }
  if (type['kind'] == 'paid' && event.paidSalesStatus != 'active') return 0;
  final remaining = (type['quantity'] as int? ?? 0) -
      (type['sold_count'] as int? ?? 0) -
      (type['reserved_count'] as int? ?? 0);
  return remaining.clamp(0, type['max_per_order'] as int? ?? 10);
}

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});
  final AppEvent event;
  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late AppEvent _event;
  List<Map<String, dynamic>> _types = [];
  final Map<String, int> _quantities = {};
  final _promo = TextEditingController();
  String _appliedPromo = '';
  Map<String, dynamic>? _quote;
  String? _error, _quoteError;
  bool _loading = true, _quoting = false;
  bool _quoteUnavailable = false;
  int _quoteGeneration = 0;
  Timer? _availabilityClock;
  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
    _availabilityClock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _availabilityClock?.cancel();
    _promo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = context.read<DataService>();
    try {
      final event = await data.eventDetails(widget.event.id);
      final types = event.eventStatus == 'published'
          ? await data.allTicketTypes(event.id)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _event = event;
        _types = types;
        _quote = null;
        _quantities.clear();
        _appliedPromo = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items => [
        for (final t in _types)
          if ((_quantities[t['id']] ?? 0) > 0)
            {'ticket_type_id': t['id'], 'quantity': _quantities[t['id']]}
      ];
  int get _subtotal => _types.fold(
      0,
      (sum, t) =>
          sum + (t['price_minor'] as int) * (_quantities[t['id']] ?? 0));
  bool get _valid =>
      _items.isNotEmpty &&
      _types
          .every((t) => (_quantities[t['id']] ?? 0) <= ticketLimit(_event, t));
  Future<void> _applyPromo() async {
    if (!_valid || _quoting) return;
    final generation = ++_quoteGeneration;
    setState(() {
      _quoting = true;
      _quoteError = null;
      _quote = null;
      _appliedPromo = '';
    });
    try {
      final code = _promo.text.trim().toUpperCase();
      final quote =
          await context.read<DataService>().quote(_event.id, _items, code);
      if (mounted && generation == _quoteGeneration) {
        setState(() {
          _quote = quote;
          _appliedPromo = code;
        });
      }
    } on ApiException catch (e) {
      if (mounted && generation == _quoteGeneration) {
        setState(() {
          _quoteUnavailable = e.status == 404 || e.status == 405;
          _quoteError = _quoteUnavailable ? null : e.toString();
        });
      }
    } catch (e) {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoteError = e.toString());
      }
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoting = false);
      }
    }
  }

  void _changeQuantity(String id, int quantity) {
    setState(() {
      _quantities[id] = quantity;
      _quote = null;
      _appliedPromo = '';
      _quoteError = null;
    });
  }

  Future<void> _checkout() async {
    if (!_valid || _quoting) return;
    if (_promo.text.trim().isNotEmpty &&
        _appliedPromo != _promo.text.trim().toUpperCase()) {
      await _applyPromo();
      if (!mounted || (_quote == null && !_quoteUnavailable)) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckoutScreen(
            event: _event,
            items: _items,
            types: _types,
            promo: _quoteUnavailable
                ? _promo.text.trim().toUpperCase()
                : _appliedPromo)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final event = _event;
    return Scaffold(
        appBar: AppBar(title: Text(l.eventTicketInfo)),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                    height: 190,
                                    child: event.imageUrl != null
                                        ? Image.network(event.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _banner(event))
                                        : _banner(event))),
                            const SizedBox(height: 20),
                            Text(event.title,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            if (event.eventStatus == 'cancelled') ...[
                              Text(l.eventCancelled,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                              const SizedBox(height: 12)
                            ],
                            Text(
                                '${DateFormat.yMMMMEEEEd(Localizations.localeOf(context).languageCode).format(event.date)}\n${event.startTime} – ${event.endTime} · ${event.date.timeZoneName}'),
                            const SizedBox(height: 20),
                            AttendeePanel(children: [
                              Text(l.eventDescription,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              Text(event.description),
                              const Divider(height: 32),
                              Text(
                                  '${l.eventOrganizer}\n${event.organizerName}'),
                            ]),
                            const SizedBox(height: 16),
                            AttendeePanel(children: [
                              Text(l.eventLocation,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(
                                  '${event.venue}\n${event.address}\n${event.city}'),
                              TextButton.icon(
                                  onPressed: () => runAttendeeAction(
                                      context, () => openEventMap(event)),
                                  icon: const Icon(Icons.map_outlined),
                                  label: Text(l.viewMap)),
                              const Divider(),
                              Text(l.refundPolicy,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(event.refundPolicy.isEmpty
                                  ? l.noRefundPolicy
                                  : event.refundPolicy),
                              OutlinedButton.icon(
                                  onPressed: () => runAttendeeAction(context,
                                      () => shareCalendar(context, event)),
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(l.addCalendar)),
                            ]),
                            const SizedBox(height: 20),
                            Text(l.chooseTickets,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            if (_loading)
                              const Center(child: CircularProgressIndicator())
                            else if (_error != null) ...[
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                              OutlinedButton(
                                  onPressed: _load, child: Text(l.commonRetry))
                            ] else ...[
                              if (_types.isEmpty) Text(l.ticketsUnavailable),
                              for (final type in _types)
                                _typeCard(context, type),
                              if (_types.isNotEmpty)
                                AttendeePanel(children: [
                                  TextField(
                                      controller: _promo,
                                      enabled: !_quoting,
                                      decoration: InputDecoration(
                                          labelText: l.promoCode),
                                      onChanged: (_) => setState(() {
                                            _quote = null;
                                            _appliedPromo = '';
                                            _quoteError = null;
                                          })),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                      onPressed: !_valid || _quoting
                                          ? null
                                          : _applyPromo,
                                      child: Text(_quoting
                                          ? l.commonLoading
                                          : l.applyPromo)),
                                  if (_quoteError != null)
                                    Text(_quoteError!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                  if (_appliedPromo.isNotEmpty)
                                    Text('${l.promoApplied}: $_appliedPromo'),
                                  const SizedBox(height: 16),
                                  if (_quote != null)
                                    MoneySummary(order: _quote!)
                                  else ...[
                                    Text(
                                        '${l.estimatedTotal}: ${money(_subtotal)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(l.finalTotalHelp),
                                  ],
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: _valid && !_quoting
                                          ? _checkout
                                          : null,
                                      child: Text(l.proceedCheckout)),
                                ]),
                            ],
                          ]))),
            ])));
  }

  Widget _banner(AppEvent event) => Container(
      color: event.accentColor,
      child: Icon(event.icon, color: Colors.white, size: 72));
  Widget _typeCard(BuildContext context, Map<String, dynamic> type) {
    final l = context.l10n;
    final id = type['id'] as String;
    final count = _quantities[id] ?? 0;
    final limit = ticketLimit(_event, type);
    final remaining = ((type['quantity'] as int) -
            (type['sold_count'] as int? ?? 0) -
            (type['reserved_count'] as int? ?? 0))
        .clamp(0, 100000000);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AttendeePanel(children: [
          Text(type['name'] as String,
              style: Theme.of(context).textTheme.titleMedium),
          if ((type['description'] as String? ?? '').isNotEmpty)
            Text(type['description']),
          const SizedBox(height: 12),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Text(
                    (type['price_minor'] as num) == 0
                        ? l.eventFree
                        : money(type['price_minor']),
                    style: Theme.of(context).textTheme.titleLarge),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: '${l.commonCancel} ${type['name']}',
                      onPressed: count > 0 && !_quoting
                          ? () => _changeQuantity(id, count - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Semantics(liveRegion: true, child: Text('$count')),
                  IconButton(
                      tooltip: '${l.chooseTickets} ${type['name']}',
                      onPressed: count < limit && !_quoting
                          ? () => _changeQuantity(id, count + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline)),
                ]),
              ]),
          const SizedBox(height: 8),
          Text(limit == 0
              ? (remaining == 0 ? l.soldOut : l.salesUnavailable)
              : '${l.remainingLabel}: $remaining · ${l.maximumLabel}: ${type['max_per_order'] ?? 10}'),
        ]));
  }
}
