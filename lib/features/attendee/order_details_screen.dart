import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import 'attendee_ui.dart';
import 'ticket_email_panel.dart';
import 'my_tickets_screen.dart';
import 'ticket_support_actions.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  AppEvent? _event;
  List<Map<String, dynamic>> _tickets = [];
  String? _error, _ticketError, _exporting;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _ticketError = null;
    });
    final data = context.read<DataService>();
    try {
      final order = await data.orderDetails(widget.orderId);
      AppEvent event;
      try {
        event = await data.eventDetails(order['event_id']);
      } catch (_) {
        final cached =
            data.events.where((e) => e.id == order['event_id']).firstOrNull;
        if (cached == null) rethrow;
        event = cached;
      }
      var tickets = <Map<String, dynamic>>[];
      String? ticketError;
      if (order['tickets'] is List) {
        tickets = (order['tickets'] as List)
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      } else if (['confirmed', 'partially_refunded', 'refunded', 'cancelled']
          .contains(order['status'])) {
        try {
          final rows = (await data.api.request('GET', '/tickets') as List)
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
          if (rows.any((t) => t['order_id'] == null)) {
            if (mounted) ticketError = context.l10n.ticketMappingUnavailable;
          } else {
            tickets =
                rows.where((t) => t['order_id'] == widget.orderId).toList();
          }
        } catch (e) {
          ticketError = e.toString();
        }
      }
      if (mounted) {
        setState(() {
          _order = order;
          _event = event;
          _tickets = tickets;
          _ticketError = ticketError;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String id) async {
    if (_exporting != null) return;
    setState(() => _exporting = id);
    await runAttendeeAction(
        context, () => exportTicket(context.read<DataService>().api, id));
    if (mounted) setState(() => _exporting = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final order = _order;
    final event = _event;
    return Scaffold(
        appBar: AppBar(title: Text(l.bookingDetails), actions: [
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || order == null || event == null
                ? Center(
                    child: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error ?? l.commonErrorGeneric),
                                  TextButton(
                                      onPressed: _load,
                                      child: Text(l.commonRetry))
                                ]))))
                : RefreshIndicator(
                    onRefresh: _load,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: StatusBadge(order['status'])),
                                    const SizedBox(height: 16),
                                    Text(
                                        event.eventStatus == 'cancelled'
                                            ? l.eventCancelled
                                            : order['status'] == 'confirmed'
                                                ? l.bookingConfirmed
                                                : l.bookingDetails,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium),
                                    const SizedBox(height: 8),
                                    Text(event.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    if (event.eventStatus == 'cancelled')
                                      const CancelledEventNotice(),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                        '${l.orderLabel}: ${order['id']}'),
                                    if (order['status'] == 'pending') ...[
                                      const SizedBox(height: 16),
                                      Text(l.pendingOrderHelp)
                                    ],
                                    const SizedBox(height: 20),
                                    AttendeePanel(children: [
                                      Text(
                                          '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(event.date)} · ${event.startTime} – ${event.endTime}\n${event.date.timeZoneName}'),
                                      const SizedBox(height: 12),
                                      Text(
                                          '${event.venue}\n${event.address}\n${event.city}'),
                                      const SizedBox(height: 12),
                                      Text(
                                          '${order['attendee_name']}\n${order['attendee_email']}'),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                          onPressed: () => runAttendeeAction(
                                              context,
                                              () => shareCalendar(
                                                  context, event)),
                                          icon:
                                              const Icon(Icons.calendar_month),
                                          label: Text(l.addCalendar)),
                                    ]),
                                    const SizedBox(height: 16),
                                    AttendeePanel(children: [
                                      Text(l.orderSummary,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      for (final item
                                          in order['items'] as List? ?? [])
                                        Text(
                                            '${item['quantity']} × ${l.eventTicketInfo} · ${money((item['unit_price_minor'] as num) * (item['quantity'] as num))}'),
                                      MoneySummary(order: order),
                                      if ((order['total_minor'] as num) > 0)
                                        Text(l.demoPaymentHelp),
                                    ]),
                                    if (order['status'] == 'confirmed' &&
                                        event.eventStatus != 'cancelled' &&
                                        _tickets.any((t) => [
                                              'valid',
                                              'checked_in'
                                            ].contains(t['status']))) ...[
                                      const SizedBox(height: 16),
                                      TicketEmailPanel(
                                          orderId: widget.orderId,
                                          email: order['attendee_email']
                                                  as String? ??
                                              '',
                                          attendeeName: order['attendee_name']
                                                  as String? ??
                                              '',
                                          totalMinor:
                                              order['total_minor'] as num? ?? 0,
                                          event: event,
                                          ticketIds: _tickets
                                              .where((t) => [
                                                    'valid',
                                                    'checked_in'
                                                  ].contains(t['status']))
                                              .map((t) => t['id'] as String)
                                              .toList()),
                                    ],
                                    const SizedBox(height: 24),
                                    TicketSupportActions(
                                        eventId: event.id,
                                        title: event.title,
                                        orderId: widget.orderId,
                                        canRequestRefund: order['status'] ==
                                                'confirmed' &&
                                            (order['total_minor'] as num) > 0),
                                    const SizedBox(height: 20),
                                    Text(l.digitalTickets,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 12),
                                    if (_ticketError != null) ...[
                                      Text(_ticketError!),
                                      TextButton(
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const MyTicketsScreen())),
                                          child: Text(l.navMyTickets)),
                                      TextButton(
                                          onPressed: _load,
                                          child: Text(l.commonRetry))
                                    ],
                                    for (final ticket in _tickets)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          child: AttendeePanel(children: [
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: StatusBadge(
                                                    event.eventStatus ==
                                                                'cancelled' &&
                                                            ticket['status'] ==
                                                                'valid'
                                                        ? 'cancelled'
                                                        : ticket['status'])),
                                            const SizedBox(height: 12),
                                            if (event.eventStatus !=
                                                    'cancelled' &&
                                                [
                                                  'valid',
                                                  'checked_in'
                                                ].contains(ticket['status']) &&
                                                (ticket['qr_credential']
                                                            as String? ??
                                                        '')
                                                    .isNotEmpty)
                                              Center(
                                                  child: SizedBox(
                                                      width: 240,
                                                      height: 240,
                                                      child: QrImageView(
                                                          data: ticket[
                                                              'qr_credential'],
                                                          backgroundColor:
                                                              Colors.white)))
                                            else
                                              Text(l.notValidAdmission),
                                            const SizedBox(height: 12),
                                            Text(ticket['attendee_name']),
                                            if (ticket['seat'] != null)
                                              Text('${l.seatLabel}: ${[
                                                ticket['section'],
                                                ticket['row'],
                                                ticket['seat']
                                              ].whereType<String>().join(' / ')}'),
                                            const SizedBox(height: 8),
                                            SelectableText(
                                                '${l.ticketsCode}: ${ticket['id']}'),
                                            const SizedBox(height: 12),
                                            if (event.eventStatus !=
                                                    'cancelled' &&
                                                ['valid', 'checked_in']
                                                    .contains(ticket['status']))
                                              Text(l.ticketQrHelp),
                                            if (event.eventStatus !=
                                                    'cancelled' &&
                                                ['valid', 'checked_in']
                                                    .contains(ticket['status']))
                                              OutlinedButton.icon(
                                                  onPressed: _exporting != null
                                                      ? null
                                                      : () =>
                                                          _export(ticket['id']),
                                                  icon: const Icon(
                                                      Icons.ios_share),
                                                  label: Text(
                                                      _exporting == ticket['id']
                                                          ? l.commonLoading
                                                          : l.exportPdf)),
                                          ])),
                                    if (_tickets.isEmpty &&
                                        _ticketError == null)
                                      Text(order['status'] == 'confirmed'
                                          ? l.noIssuedTickets
                                          : l.pendingOrderHelp),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(l.commonOk)),
                                  ]))),
                    ])));
  }
}
