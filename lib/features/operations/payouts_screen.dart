import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/responsive_cards.dart';
import '../attendee/attendee_ui.dart';
import '../organizer/event_management_screen.dart';
import 'operations_ui.dart';

class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final admin = context.watch<AuthService>().currentUser?.isAdmin == true;
    Widget metric(String label, num amount) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(money(amount), style: Theme.of(context).textTheme.titleMedium)
        ]));
    return OperationsPage(
        title: l.opsPayouts,
        load: (api) => api.request('GET', '/organizer/payouts'),
        content: (state, rows) => [
              OperationsCard(accent: true, children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 32),
                Text(l.opsPayoutHelp)
              ]),
              if ((rows as List).isEmpty)
                OperationsCard(children: [Text(l.managementNoData)]),
              for (final r in rows)
                OperationsCard(children: [
                  Text(r['event_title'],
                      style: Theme.of(context).textTheme.titleLarge),
                  OperationsStatus(r['status']),
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.opsEstimated),
                            const SizedBox(height: 8),
                            Text(money(r['estimated_payout_minor']),
                                style:
                                    Theme.of(context).textTheme.headlineSmall)
                          ])),
                  ResponsiveCards(minimumWidth: 130, children: [
                    metric(l.managementGross, r['gross_minor']),
                    metric(l.managementDiscounts, r['discounts_minor']),
                    metric(l.managementFees, r['fees_minor']),
                    metric(l.managementRefunds, r['refunds_minor'])
                  ]),
                  if (r['eligible'] != true) Text(l.opsPayoutIneligible),
                  if ((r['amount_minor'] as num) > 0)
                    Text(
                        '${l.opsRecordedTransfer}: ${money(r['amount_minor'])}'),
                  if ((r['note'] as String).isNotEmpty) Text(r['note']),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EventManagementScreen(
                                  eventId: r['event_id'],
                                  title: r['event_title']))),
                      icon: const Icon(Icons.insights_outlined),
                      label: Text(l.managementTitle)),
                  if (r['recorded_paid'] == true && r['status'] != 'paid')
                    Text(l.opsPayoutReconcile),
                  if (admin &&
                      r['status'] != 'paid' &&
                      r['recorded_paid'] != true)
                    FilledButton.icon(
                        onPressed: state.busy
                            ? null
                            : () async {
                                final result = await operationsForm(context,
                                    title: l.opsPayoutUpdate,
                                    submitLabel: l.opsPayoutUpdate,
                                    help: l.opsPayoutHelp,
                                    fields: [
                                      OperationField('status', l.opsStatus,
                                          initial: 'pending',
                                          options: {
                                            'pending': l.statusPending,
                                            'blocked': l.opsBlocked,
                                            if (r['eligible'] == true)
                                              'processing': l.opsProcessing,
                                            if (r['eligible'] == true)
                                              'paid': l.opsPaid
                                          }),
                                      OperationField('note', l.opsResolution,
                                          multiline: true,
                                          validate: (v) => v.length >= 3
                                              ? null
                                              : l.opsInvalid)
                                    ],
                                    save: (f) => state.api.request('PATCH',
                                        '/admin/payouts/${r['event_id']}',
                                        body: f));
                                if (result != null && state.mounted) {
                                  await state.refresh();
                                }
                              },
                        icon: const Icon(Icons.account_balance_outlined),
                        label: Text(l.opsPayoutUpdate)),
                ]),
            ]);
  }
}
