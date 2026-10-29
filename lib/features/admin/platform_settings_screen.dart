import 'package:flutter/material.dart';
import '../../l10n/loc_extensions.dart';
import '../attendee/attendee_ui.dart';
import '../operations/operations_ui.dart';

class PlatformSettingsScreen extends StatelessWidget {
  const PlatformSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OperationsPage(
        title: l.opsSettings,
        load: (api) => api.request('GET', '/admin/platform-settings'),
        content: (state, data) => [
              OperationsCard(accent: true, children: [
                const Icon(Icons.tune_rounded, size: 32),
                Text(l.opsSettingsHelp)
              ]),
              OperationsCard(children: [
                Text(l.managementActivationFee,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(money(data['activation_fee_minor']),
                    style: Theme.of(context).textTheme.headlineSmall),
                const Divider(),
                Text(l.opsProcessingPercent,
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${(data['processing_fee_bps'] as num) / 100}%',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Divider(),
                Text(l.opsHoldMinutes,
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${data['hold_minutes']}',
                    style: Theme.of(context).textTheme.headlineSmall),
                FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final result = await operationsForm(context,
                                title: l.opsSettings,
                                help: l.opsSettingsHelp,
                                fields: [
                                  OperationField(
                                      'fee', l.managementActivationFee,
                                      initial: ((data['activation_fee_minor']
                                                  as num) /
                                              100)
                                          .toStringAsFixed(2),
                                      number: true, validate: (v) {
                                    final n =
                                        double.tryParse(v.replaceAll(',', '.'));
                                    return n != null && n >= 0 && n <= 1000000
                                        ? null
                                        : l.opsInvalid;
                                  }),
                                  OperationField(
                                      'processing', l.opsProcessingPercent,
                                      initial:
                                          ((data['processing_fee_bps'] as num) /
                                                  100)
                                              .toString(),
                                      number: true, validate: (v) {
                                    final n =
                                        double.tryParse(v.replaceAll(',', '.'));
                                    return n != null && n >= 0 && n <= 30
                                        ? null
                                        : l.opsInvalid;
                                  }),
                                  OperationField('hold', l.opsHoldMinutes,
                                      initial: '${data['hold_minutes']}',
                                      number: true, validate: (v) {
                                    final n = int.tryParse(v);
                                    return n != null && n >= 1 && n <= 60
                                        ? null
                                        : l.opsInvalid;
                                  }),
                                  OperationField('reason', l.managementReason,
                                      multiline: true,
                                      validate: (v) =>
                                          v.length >= 3 ? null : l.opsInvalid),
                                ],
                                save: (f) => state.api.request(
                                        'PATCH', '/admin/platform-settings',
                                        body: {
                                          'activation_fee_minor': (double.parse(
                                                      f['fee']!.replaceAll(
                                                          ',', '.')) *
                                                  100)
                                              .round(),
                                          'processing_fee_bps': (double.parse(
                                                      f['processing']!
                                                          .replaceAll(
                                                              ',', '.')) *
                                                  100)
                                              .round(),
                                          'hold_minutes': int.parse(f['hold']!),
                                          'version': data['version'],
                                          'reason': f['reason']
                                        }));
                            if (result != null && state.mounted) {
                              await state.refresh();
                            }
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.opsSave)),
              ]),
            ]);
  }
}
