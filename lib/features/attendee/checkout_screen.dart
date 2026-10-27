import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import 'attendee_ui.dart';
import 'order_details_screen.dart';

String checkoutKey() => base64UrlEncode(
    List<int>.generate(24, (_) => Random.secure().nextInt(256)));

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen(
      {super.key,
      required this.event,
      required this.items,
      required this.types,
      this.promo = ''});
  final AppEvent event;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> types;
  final String promo;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _name, _email;
  Timer? _clock;
  Map<String, dynamic>? _order;
  String? _error, _signature;
  String _reserveKey = checkoutKey();
  final String _completeKey = checkoutKey();
  bool _busy = false, _leaving = false;
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _name = TextEditingController(text: user?.name);
    _email = TextEditingController(text: user?.email);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  int get _seconds {
    final expires = _order?['expires_at'] as String?;
    if (expires == null) return 0;
    return max(
        0, parseApiDate(expires).difference(DateTime.now().toUtc()).inSeconds);
  }

  Future<void> _reserve() async {
    if (_busy || !_form.currentState!.validate()) return;
    final signature = '${_name.text.trim()}|${_email.text.trim()}';
    if (_signature != signature) {
      _signature = signature;
      _reserveKey = checkoutKey();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await context.read<DataService>().reserveTickets(
          widget.event.id, widget.items,
          name: _name.text,
          email: _email.text,
          promo: widget.promo,
          key: _reserveKey);
      if (!mounted) return;
      setState(() => _order = order);
      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _seconds == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = context.read<DataService>();
    try {
      final confirmed =
          await data.confirmReservation(_order!['id'], _completeKey);
      if (!mounted) return;
      unawaited(data.refresh());
      _clock?.cancel();
      setState(() => _leaving = true);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: confirmed['id'])));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_order != null && _seconds > 0) {
      final l = context.l10n;
      final cancel = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  scrollable: true,
                  title: Text(l.closeCheckout),
                  content: Text(l.closeCheckoutHelp),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(l.keepBooking)),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(l.commonCancel))
                  ]));
      if (cancel != true || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await context.read<DataService>().cancelCheckout(_order!['id']);
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _busy = false;
          });
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
          appBar: AppBar(
              title: Text(_order == null ? l.attendeeDetails : l.reviewBooking),
              leading: IconButton(
                  onPressed: _busy ? null : _close,
                  icon: const Icon(Icons.close))),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Text(widget.event.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16)
                    ],
                    if (_order == null)
                      Form(
                          key: _form,
                          child: Column(children: [
                            TextFormField(
                                controller: _name,
                                enabled: !_busy,
                                maxLength: 200,
                                autofillHints: const [AutofillHints.name],
                                decoration:
                                    InputDecoration(labelText: l.authNameLabel),
                                validator: (v) => (v ?? '').trim().length < 2
                                    ? l.authValidationNameRequired
                                    : null),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                    labelText: l.authEmailLabel),
                                validator: (v) =>
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch((v ?? '').trim())
                                        ? null
                                        : l.authValidationEmailInvalid),
                            const SizedBox(height: 20),
                            Text(l.finalTotalHelp),
                            const SizedBox(height: 20),
                            FilledButton(
                                onPressed: _busy ? null : _reserve,
                                child: Text(
                                    _busy ? l.commonLoading : l.reserveReview)),
                          ]))
                    else ...[
                      AttendeePanel(children: [
                        Text(
                            '${_order!['attendee_name']}\n${_order!['attendee_email']}'),
                        const Divider(),
                        for (final item in widget.items)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${item['quantity']} × ${widget.types.where((t) => t['id'] == item['ticket_type_id']).firstOrNull?['name'] ?? l.eventTicketInfo}')),
                        const Divider(),
                        MoneySummary(order: _order!)
                      ]),
                      const SizedBox(height: 16),
                      if (widget.promo.isNotEmpty)
                        Text('${l.promoCode}: ${widget.promo}'),
                      Text(_seconds > 0
                          ? '${l.reservationExpires} ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'
                          : l.opsExpiredHelp),
                      if (_seconds == 0)
                        OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () {
                                    _clock?.cancel();
                                    setState(() {
                                      _order = null;
                                      _signature = null;
                                      _reserveKey = checkoutKey();
                                    });
                                  },
                            icon: const Icon(Icons.restart_alt),
                            label: Text(l.opsStartAgain)),
                      const SizedBox(height: 20),
                      Text(l.demoPaymentHelp),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: _busy || _seconds == 0 ? null : _confirm,
                          child: Text(_busy
                              ? l.commonLoading
                              : '${l.confirmBooking} · ${money(_order!['total_minor'] as num)}')),
                    ],
                  ])))),
    );
  }
}
