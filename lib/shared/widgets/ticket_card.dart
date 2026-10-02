import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/ticket.dart';

class TicketCard extends StatelessWidget {
  final AppTicket ticket;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPast = ticket.status == TicketStatus.past;
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(ticket.event.date);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap ?? () => showDialog<void>(context: context, builder: (_) => AlertDialog(
          scrollable: true,
          title: Text(ticket.event.title),
          content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.network('${ApiClient.baseUrl}/tickets/${ticket.id}/qr', headers: context.read<AuthService>().api.headers,
              errorBuilder: (_, __, ___) => const Text('Unable to load QR. Please retry.')),
            SelectableText(ticket.ticketCode),
          ])),
        )),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Opacity(
          opacity: isPast ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: const [
                BoxShadow(color: Color(0x1F1D1D1D), blurRadius: 4, offset: Offset(0, 0)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(dateLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${ticket.event.venue}, ${ticket.event.city}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.l10n.ticketsCode}: ${ticket.id.substring(0, 8)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  alignment: Alignment.center,
                  child: Image.network('${ApiClient.baseUrl}/tickets/${ticket.id}/qr', headers: context.read<AuthService>().api.headers, errorBuilder: (_, __, ___) => const Icon(Icons.error_outline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
