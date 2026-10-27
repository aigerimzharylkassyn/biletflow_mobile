import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/responsive_cards.dart';
import '../attendee/attendee_ui.dart';
import '../operations/operations_ui.dart';
import 'create_event_screen.dart';

class TicketInventoryScreen extends StatelessWidget {
  const TicketInventoryScreen(
      {super.key, required this.eventId, required this.title});
  final String eventId, title;
  Future<void> _edit(OperationsPageState state, Map data, Map? ticket) async {
    final c = state.context, l = c.l10n;
    String? positive(String v) =>
        int.tryParse(v) != null && int.parse(v) > 0 ? null : l.opsInvalid;
    final result = await operationsForm(c,
        title: ticket == null ? l.opsAddTicket : l.opsEditTicket,
        help: l.opsTicketEditHelp,
        fields: [
          OperationField('name', l.creationTicketName,
              initial: ticket?['name'] ?? ''),
          OperationField('description', l.creationTicketDescription,
              initial: ticket?['description'] ?? '',
              multiline: true,
              validate: (_) => null),
          OperationField('kind', l.creationTicketKind,
              initial: ticket?['kind'] ?? 'free',
              options: {'free': l.eventFree, 'paid': l.creationPaid}),
          OperationField('price', l.organizerPriceLabel,
              initial: ((ticket?['price_minor'] as num? ?? 0) / 100)
                  .toStringAsFixed(2),
              number: true,
              validate: (v) =>
                  double.tryParse(v.replaceAll(',', '.')) != null &&
                          double.parse(v.replaceAll(',', '.')) >= 0
                      ? null
                      : l.opsInvalid),
          OperationField('quantity', l.creationQuantity,
              initial: '${ticket?['quantity'] ?? 1}',
              number: true,
              validate: positive),
          OperationField('maximum', l.creationMaximum,
              initial: '${ticket?['max_per_order'] ?? 10}',
              number: true,
              validate: (v) => int.tryParse(v) != null &&
                      int.parse(v) > 0 &&
                      int.parse(v) <= 50
                  ? null
                  : l.opsInvalid),
          OperationField('sales_start', l.creationSalesStart,
              initial:
                  '${ticket?['sales_start'] ?? data['registration_opens_at']}',
              date: true),
          OperationField('sales_end', l.creationSalesEnd,
              initial:
                  '${ticket?['sales_end'] ?? data['registration_closes_at']}',
              date: true),
        ],
        save: (fields) => state.api.request(ticket == null ? 'POST' : 'PATCH',
                '/events/$eventId/ticket-types${ticket == null ? '' : '/${ticket['id']}'}',
                body: {
                  'name': fields['name'],
                  'description': fields['description'],
                  'kind': fields['kind'],
                  'price_minor': fields['kind'] == 'free'
                      ? 0
                      : (double.parse(fields['price']!.replaceAll(',', '.')) *
                              100)
                          .round(),
                  'quantity': int.parse(fields['quantity']!),
                  'max_per_order': int.parse(fields['maximum']!),
                  'sales_start': fields['sales_start'],
                  'sales_end': fields['sales_end'],
                }));
    if (result != null && state.mounted) {
      await state.refresh();
      if (state.mounted) await state.context.read<DataService>().refresh();
    }
  }

  Widget _count(BuildContext c, String label, Object value) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(c).colorScheme.primary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value', style: Theme.of(c).textTheme.titleLarge),
        Text(label, style: Theme.of(c).textTheme.bodySmall)
      ]));
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final manager = user?.isOrganizer == true || user?.isAdmin == true;
    return OperationsPage(
        title: l.opsTickets,
        load: (api) => api.request('GET', '/events/$eventId/inventory'),
        content: (state, data) => [
              OperationsCard(accent: true, children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                Text(l.opsTicketsHelp)
              ]),
              if (manager)
                OperationsCard(children: [
                  if (data['event_status'] == 'draft') ...[
                    FilledButton.icon(
                        onPressed:
                            state.busy ? null : () => _edit(state, data, null),
                        icon: const Icon(Icons.add),
                        label: Text(l.opsAddTicket)),
                  ] else if (data['event_status'] == 'published')
                    OutlinedButton.icon(
                        onPressed: state.busy
                            ? null
                            : () async {
                                final result = await operationsForm(context,
                                    title: l.organizerEditEvent,
                                    submitLabel: l.organizerEditEvent,
                                    help: l.organizerUnpublishForEdit,
                                    fields: [],
                                    save: (_) => state.api.request(
                                        'POST', '/events/$eventId/unpublish'));
                                if (result != null && state.mounted) {
                                  await state.refresh();
                                }
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.organizerEditEvent)),
                ]),
              OperationsCard(children: [
                Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.opsEditingRules),
                        leading: const Icon(Icons.info_outline),
                        children: [
                          Text(l.opsTicketEditHelp),
                          const SizedBox(height: 12),
                          Text(l.opsInventoryHelp)
                        ]))
              ]),
              if ((data['ticket_types'] as List).isEmpty)
                OperationsCard(children: [
                  const Icon(Icons.confirmation_number_outlined, size: 32),
                  Text(l.managementNoData)
                ]),
              for (final t in data['ticket_types'] as List)
                OperationsCard(children: [
                  Text(t['name'],
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(t['description'] ?? ''),
                  Text(t['kind'] == 'free'
                      ? l.eventFree
                      : money(t['price_minor'])),
                  Text(t['is_hidden'] == true ? l.opsHidden : l.opsVisible,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  ResponsiveCards(minimumWidth: 110, children: [
                    _count(context, l.opsAvailable, t['available']),
                    _count(context, l.opsReserved, t['reserved_count']),
                    _count(context, l.opsSold, t['sold_count']),
                    _count(context, l.opsRefunded, t['refunded_count']),
                    _count(context, l.opsChecked, t['checked_in'])
                  ]),
                  if (manager)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: state.busy || t['editable'] != true
                              ? null
                              : () => _edit(state, data, t),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l.opsEditTicket)),
                      OutlinedButton.icon(
                          onPressed: state.busy ||
                                  !['draft', 'published']
                                      .contains(data['event_status'])
                              ? null
                              : () async {
                                  final result = await operationsForm(context,
                                      title: t['is_hidden'] == true
                                          ? l.opsShow
                                          : l.opsHide,
                                      help: l.opsTicketsHelp,
                                      fields: [],
                                      save: (_) => state.api.request('POST',
                                          '/events/$eventId/ticket-types/${t['id']}/${t['is_hidden'] == true ? 'restore' : 'hide'}'));
                                  if (result != null && state.mounted) {
                                    await state.refresh();
                                  }
                                },
                          icon: Icon(t['is_hidden'] == true
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          label: Text(
                              t['is_hidden'] == true ? l.opsShow : l.opsHide)),
                    ]),
                ]),
              if (manager && data['event_status'] == 'draft')
                OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CreateEventScreen(
                                draftId: eventId, openReview: true))),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(l.opsReviewEvent)),
            ]);
  }
}
