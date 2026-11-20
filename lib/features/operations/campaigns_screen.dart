import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import 'package:intl/intl.dart';
import 'campaign_form.dart';
import 'campaign_qr_screen.dart';
import 'campaign_analytics_screen.dart';
import 'operations_ui.dart';

String campaignStateLabel(BuildContext context, String state) {
  final l = context.l10n;
  return switch (state) {
    'active' => l.campaignActive,
    'disabled' => l.campaignDisabled,
    'scheduled' => l.campaignScheduled,
    'exhausted' => l.campaignExhausted,
    'expired' => l.statusExpired,
    _ => state,
  };
}

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen(
      {super.key,
      required this.eventId,
      required this.title,
      this.canCreate = true});
  final String eventId, title;
  final bool canCreate;

  Future<void> _edit(
      OperationsPageState state, List<Map<String, dynamic>> types,
      [Map<String, dynamic>? campaign]) async {
    final saved = await Navigator.push<bool>(
        state.context,
        MaterialPageRoute(
            builder: (_) => CampaignForm(
                eventId: eventId, ticketTypes: types, campaign: campaign)));
    if (saved == true && state.mounted) await state.refresh();
  }

  Future<void> _toggle(
      OperationsPageState state, Map<String, dynamic> campaign) async {
    final l = state.context.l10n;
    final result = await operationsForm(state.context,
        title:
            campaign['enabled'] == true ? l.campaignDisable : l.campaignEnable,
        help: l.campaignHelp,
        fields: const [],
        save: (_) => state.api.request('PATCH',
            '/events/${Uri.encodeComponent(eventId)}/campaigns/${Uri.encodeComponent(campaign['id'] as String)}',
            body: {'enabled': campaign['enabled'] != true}));
    if (result != null && state.mounted) await state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OperationsPage(
        title: l.campaignTitle,
        load: (api) async {
          final values = await Future.wait([
            api.request(
                'GET', '/events/${Uri.encodeComponent(eventId)}/campaigns'),
            api.request(
                'GET', '/events/${Uri.encodeComponent(eventId)}/inventory'),
          ]);
          return {'campaigns': values[0], 'types': values[1]['ticket_types']};
        },
        content: (state, data) {
          final types = (data['types'] as List).cast<Map<String, dynamic>>();
          final campaigns =
              (data['campaigns'] as List).cast<Map<String, dynamic>>();
          String date(String value) =>
              DateFormat.yMMMd(Localizations.localeOf(context).toString())
                  .add_Hm()
                  .format(parseApiDate(value).toLocal());
          return [
            OperationsCard(children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              Text(l.campaignHelp),
              if (canCreate)
                FilledButton.icon(
                    onPressed: state.busy ? null : () => _edit(state, types),
                    icon: const Icon(Icons.add),
                    label: Text(l.campaignCreate)),
              OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CampaignAnalyticsScreen(eventId: eventId))),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l.campaignAnalytics)),
            ]),
            if (campaigns.isEmpty)
              OperationsCard(children: [Text(l.managementNoData)]),
            for (final c in campaigns)
              OperationsCard(children: [
                Text(c['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium),
                SelectableText('${l.promoCode}: ${c['code']}'),
                Text(campaignStateLabel(context, c['state'] as String)),
                Text(
                    '${l.campaignFrom}: ${date(c['valid_from'] as String)}\n${l.campaignUntil}: ${date(c['valid_until'] as String)}'),
                Text(
                    '${l.managementRedemptions}: ${c['redemption_count']} / ${c['max_redemptions']}'),
                SelectableText(c['campaign_url'] as String),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton(
                      onPressed:
                          state.busy ? null : () => _edit(state, types, c),
                      child: Text(l.campaignEdit)),
                  OutlinedButton(
                      onPressed: state.busy ? null : () => _toggle(state, c),
                      child: Text(c['enabled'] == true
                          ? l.campaignDisable
                          : l.campaignEnable)),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CampaignQrScreen(
                                  eventId: eventId, campaign: c))),
                      icon: const Icon(Icons.qr_code),
                      label: Text(l.campaignQr)),
                  TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: c['campaign_url'] as String));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.opsCopied)));
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(l.opsCopy)),
                ]),
              ]),
          ];
        });
  }
}
