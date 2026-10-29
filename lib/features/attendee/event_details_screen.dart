import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/primary_button.dart';
import 'my_tickets_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final AppEvent event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _purchasing = false;

  Future<void> _getTicket() async {
    final l10n = context.l10n;
    setState(() => _purchasing = true);
    final data = context.read<DataService>();
    Map<String, dynamic> confirmed;
    try {
      final types = await data.ticketTypes(widget.event);
      if (!mounted) return;
      if (types.isEmpty) throw ApiException(l10n.checkoutNoTickets);
      final type = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.checkoutChooseTicket),
        children: types.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, t),
          child: Text('${t['name']} — ${kzt(t['price_minor'] as num)}'),
        )).toList(),
      ));
      if (type == null || !mounted) return;
      // Returns the applied promo code ('' for none), or null when the attendee backs out.
      final promoCode = await showDialog<String>(
        context: context,
        builder: (_) => _QuoteDialog(event: widget.event, ticketType: type),
      );
      if (promoCode == null || !mounted) return;
      final order = await data.checkout(widget.event, type['id'], promoCode: promoCode);
      if (!mounted) return;
      final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(l10n.checkoutConfirmTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Totals(totals: order),
          const SizedBox(height: 12),
          Text(l10n.checkoutSimulatedNote, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.checkoutConfirm)),
        ],
      ));
      if (confirm != true) { await data.cancelCheckout(order['id']); return; }
      confirmed = await data.completeCheckout(order['id']);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
        title: Text(l10n.eventTicketConfirmedTitle, textAlign: TextAlign.center),
        content: Text(
          '${l10n.eventTicketConfirmedBody}\n\n${l10n.eventTicketsEmailed(confirmed['attendee_email'] as String)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
            },
            child: Text(l10n.eventViewTicket),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final event = widget.event;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(event.date);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: event.accentColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: event.accentColor,
                alignment: Alignment.center,
                child: Icon(event.icon, size: 72, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.calendar_today_rounded, label: l10n.eventDate, value: dateLabel),
                  _InfoRow(icon: Icons.access_time_rounded, label: l10n.eventTime, value: '${event.startTime} - ${event.endTime}'),
                  _InfoRow(icon: Icons.location_on_outlined, label: l10n.eventLocation, value: '${event.venue}, ${event.city}'),
                  _InfoRow(icon: Icons.person_outline_rounded, label: l10n.eventOrganizer, value: event.organizerName),
                  const SizedBox(height: 20),
                  Text(l10n.eventDescription,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(event.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.eventTicketInfo, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                event.isFree ? l10n.eventFree : '${event.price.toStringAsFixed(0)} ₸',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${event.ticketsTotal - event.ticketsSold}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrimaryButton(
            label: event.isFree ? l10n.eventGetTicket : l10n.eventBuyTicket,
            onPressed: _getTicket,
            isLoading: _purchasing,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

String kzt(num minor) => '${NumberFormat.decimalPattern().format(minor / 100)} ₸';

/// Server-priced totals; the discount line appears only when a promo code applied.
class _Totals extends StatelessWidget {
  final Map<String, dynamic> totals;
  const _Totals({required this.totals});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discount = totals['discount_minor'] as num? ?? 0;
    Widget line(String label, String value, {bool bold = false}) {
      final style = TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      line(l10n.checkoutSubtotal, kzt(totals['subtotal_minor'] as num)),
      if (discount > 0) line(l10n.checkoutDiscount(totals['promo_code'] as String? ?? ''), '−${kzt(discount)}'),
      line(l10n.checkoutFee, kzt(totals['processing_fee_minor'] as num)),
      const Divider(),
      line(l10n.checkoutTotal, kzt(totals['total_minor'] as num), bold: true),
    ]);
  }
}

class _QuoteDialog extends StatefulWidget {
  final AppEvent event;
  final Map<String, dynamic> ticketType;
  const _QuoteDialog({required this.event, required this.ticketType});

  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  final _code = TextEditingController();
  Map<String, dynamic>? _quote;
  String _applied = '';
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  /// Keeps the last valid quote when a code is rejected, and shows the backend's reason.
  Future<void> _load(String code) async {
    setState(() { _busy = true; _error = null; });
    try {
      final quote = await context.read<DataService>().quote(widget.event, widget.ticketType['id'], promoCode: code);
      if (!mounted) return;
      setState(() { _quote = quote; _applied = code.trim().toUpperCase(); });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quote = _quote;
    return AlertDialog(
      title: Text(widget.ticketType['name'] as String),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _code,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.checkoutPromoLabel,
                  errorText: quote == null ? null : _error,
                  errorMaxLines: 3,
                ),
                onSubmitted: (value) => _load(value),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _busy ? null : () => _load(_code.text),
                child: Text(l10n.checkoutPromoApply),
              ),
            ),
          ]),
          if (_applied.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : () { _code.clear(); _load(''); },
              child: Text(l10n.checkoutPromoRemove),
            ),
          if (quote == null && _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 12),
          if (quote != null) _Totals(totals: quote) else if (_busy) const Center(child: CircularProgressIndicator()),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed: _busy || quote == null ? null : () => Navigator.pop(context, _applied),
          child: Text(l10n.checkoutContinue),
        ),
      ],
    );
  }
}
