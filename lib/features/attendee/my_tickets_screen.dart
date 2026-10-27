import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/ticket.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/ticket_card.dart';
import 'attendee_ui.dart';
import 'attendee_events_screen.dart';
import 'order_details_screen.dart';
import 'ticket_support_actions.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = context.watch<DataService>();
    return DefaultTabController(
        length: 3,
        child: Scaffold(
            appBar: AppBar(
                title: Text(l.ticketsTitle),
                actions: [
                  IconButton(
                      tooltip: l.refreshStatus,
                      onPressed: data.isLoading ? null : data.refresh,
                      icon: const Icon(Icons.refresh))
                ],
                bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    tabs: [
                      Tab(text: l.ticketsTabUpcoming),
                      Tab(text: l.ticketsTabPast),
                      Tab(text: l.ordersLabel)
                    ])),
            body: data.isLoading &&
                    data.tickets.isEmpty &&
                    data.attendeeOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    if (data.errorMessage != null)
                      SizedBox(
                          height: 68,
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: TextButton(
                                      onPressed: data.refresh,
                                      child: Text(
                                          '${data.errorMessage}\n${l.commonRetry}'))))),
                    Expanded(
                        child: TabBarView(children: [
                      _TicketList(
                          tickets: data.ticketsByStatus(TicketStatus.upcoming),
                          emptyMessage: l.ticketsNoneUpcoming),
                      _TicketList(
                          tickets: data.ticketsByStatus(TicketStatus.past),
                          emptyMessage: l.ticketsNonePast),
                      RefreshIndicator(
                          onRefresh: data.refresh,
                          child: ListView(
                              padding: const EdgeInsets.all(20),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                if (data.attendeeOrders.isEmpty)
                                  _empty(context, l.noOrders),
                                for (final order in data.attendeeOrders)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: AttendeePanel(children: [
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child:
                                                StatusBadge(order['status'])),
                                        const SizedBox(height: 12),
                                        Text(
                                            data.events
                                                    .where((e) =>
                                                        e.id ==
                                                        order['event_id'])
                                                    .firstOrNull
                                                    ?.title ??
                                                '${l.orderLabel} ${order['id']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        const SizedBox(height: 8),
                                        Text(
                                            money(order['total_minor'] as num)),
                                        const SizedBox(height: 8),
                                        OutlinedButton(
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        OrderDetailsScreen(
                                                            orderId:
                                                                order['id']))),
                                            child: Text(l.viewBooking)),
                                      ])),
                              ])),
                    ])),
                  ])));
  }
}

Widget _empty(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      const Icon(Icons.confirmation_number_outlined, size: 56),
      const SizedBox(height: 16),
      Text(label, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      OutlinedButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AttendeeEventsScreen())),
          child: Text(context.l10n.exploreEvents)),
    ]));

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets, required this.emptyMessage});
  final List<AppTicket> tickets;
  final String emptyMessage;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: context.read<DataService>().refresh,
      child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (tickets.isEmpty) _empty(context, emptyMessage),
            for (final ticket in tickets)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(ticket.admissionStatus)),
                        const SizedBox(height: 6),
                        TicketCard(ticket: ticket),
                        const SizedBox(height: 12),
                        TicketSupportActions(
                            eventId: ticket.event.id,
                            title: ticket.event.title,
                            orderId: ticket.orderId,
                            ticketId: ticket.id,
                            canRequestRefund: ticket.canRequestRefund),
                        if (ticket.orderId != null)
                          TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => OrderDetailsScreen(
                                          orderId: ticket.orderId!))),
                              child: Text(context.l10n.viewBooking)),
                        if (ticket.canShowQr)
                          TextButton.icon(
                              onPressed: () => runAttendeeAction(
                                  context,
                                  () => exportTicket(
                                      context.read<DataService>().api,
                                      ticket.id)),
                              icon: const Icon(Icons.ios_share),
                              label: Text(context.l10n.exportPdf)),
                      ])),
          ]));
}
