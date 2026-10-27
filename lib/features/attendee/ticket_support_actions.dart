import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';
import '../profile/support_screen.dart';

class TicketSupportActions extends StatelessWidget {
  const TicketSupportActions(
      {super.key,
      required this.eventId,
      required this.title,
      this.orderId,
      this.ticketId,
      this.canRequestRefund = false,
      this.beforeOpen});
  final String eventId, title;
  final String? orderId, ticketId;
  final bool canRequestRefund;
  final VoidCallback? beforeOpen;
  Future<void> _open(BuildContext context, bool refund) async {
    final navigator = Navigator.of(context);
    final data = context.read<DataService>();
    final l = context.l10n;
    final subject = '${refund ? l.requestRefund : l.contactOrganizer}: $title';
    beforeOpen?.call();
    await navigator.push(MaterialPageRoute(
        builder: (_) => SupportScreen(
            eventId: eventId,
            orderId: orderId,
            ticketId: ticketId,
            startNew: true,
            flow: 'attendee',
            view: 'mine',
            initialCategory: refund ? 'refund' : 'event_information',
            subject:
                subject.length > 200 ? subject.substring(0, 200) : subject)));
    await data.refresh();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (canRequestRefund) ...[
          OutlinedButton.icon(
              onPressed: () => _open(context, true),
              icon: const Icon(Icons.currency_exchange),
              label: Text(context.l10n.requestRefund)),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
            onPressed: () => _open(context, false),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(context.l10n.contactOrganizer)),
      ]);
}
