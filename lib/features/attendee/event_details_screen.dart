import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
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
    try {
      final types = await data.ticketTypes(widget.event);
      if (!mounted) return;
      if (types.isEmpty) throw Exception('No tickets are currently available.');
      final type = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose a ticket'),
        children: types.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, t),
          child: Text('${t['name']} — ${(t['price_minor'] as num) / 100} ₸'),
        )).toList(),
      ));
      if (type == null) return;
      final order = await data.checkout(widget.event, type['id']);
      if (!mounted) return;
      final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm reservation'),
        content: Text('Total: ${(order['total_minor'] as num) / 100} ₸\nIncludes fees. Payment is simulated; no card will be charged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ));
      if (confirm != true) { await data.cancelCheckout(order['id']); return; }
      await data.completeCheckout(order['id']);
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
        content: Text(l10n.eventTicketConfirmedBody, textAlign: TextAlign.center),
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
