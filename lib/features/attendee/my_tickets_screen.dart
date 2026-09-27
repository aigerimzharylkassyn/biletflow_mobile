import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/ticket.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/error_message.dart';
import '../../shared/widgets/ticket_card.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<DataService>();
    final upcoming = data.ticketsByStatus(TicketStatus.upcoming);
    final past = data.ticketsByStatus(TicketStatus.past);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ticketsTitle),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: l10n.ticketsTabUpcoming),
              Tab(text: l10n.ticketsTabPast),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TicketList(tickets: upcoming, emptyMessage: l10n.ticketsNoneUpcoming),
            _TicketList(tickets: past, emptyMessage: l10n.ticketsNonePast),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<AppTicket> tickets;
  final String emptyMessage;
  const _TicketList({required this.tickets, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return AppErrorMessage(message: emptyMessage, icon: Icons.confirmation_number_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => TicketCard(ticket: tickets[index]),
    );
  }
}
