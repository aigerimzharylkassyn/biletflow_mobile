import 'package:flutter/material.dart';
import '../../l10n/loc_extensions.dart';
import '../attendee/attendee_ui.dart';
import 'operations_ui.dart';
import 'campaigns_screen.dart';

class CampaignAnalyticsScreen extends StatelessWidget {
  const CampaignAnalyticsScreen({super.key, required this.eventId});
  final String eventId;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OperationsPage(
        title: l.campaignAnalytics,
        load: (api) => api.request(
            'GET',
            Uri(
                path: '/organizer/analytics/campaigns',
                queryParameters: {'event_id': eventId}).toString()),
        content: (state, data) => [
              OperationsCard(children: [Text(l.campaignAnalyticsHelp)]),
              if ((data as List).isEmpty)
                OperationsCard(children: [Text(l.managementNoData)]),
              for (final row in data)
                OperationsCard(children: [
                  Text('${row['name']} · ${row['code']}',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(campaignStateLabel(context, row['state'] as String)),
                  for (final metric in {
                    l.campaignVisits: '${row['visits']}',
                    l.managementRedemptions:
                        '${row['redemptions']} / ${row['maximum']}',
                    l.campaignOrders: '${row['orders']}',
                    l.managementAttributedTickets: '${row['tickets_sold']}',
                    l.managementGross: money(row['gross_revenue_minor'] as num),
                    l.managementDiscounts: money(row['discount_minor'] as num),
                    l.managementNet: money(row['net_revenue_minor'] as num),
                    l.opsRefunded:
                        '${row['refunded_orders']} · ${money(row['refunded_minor'] as num)}',
                    l.campaignConversion: row['conversion_rate'] == null
                        ? '—'
                        : '${row['conversion_rate']}%',
                  }.entries)
                    Text('${metric.key}: ${metric.value}'),
                ]),
            ]);
  }
}
