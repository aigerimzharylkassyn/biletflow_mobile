import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../operations/operations_ui.dart';
import 'support_case_widgets.dart';

/// Presents the platform outcome within the same attendee conversation.
class SupportFormalReview extends StatelessWidget {
  const SupportFormalReview(
      {super.key, required this.caseData, required this.onChanged});
  final Map<String, dynamic> caseData;
  final Future<void> Function() onChanged;

  Future<void> _decide(BuildContext context) async {
    final l = context.l10n;
    final api = context.read<AuthService>().api;
    final result = await operationsForm(context,
        title: l.formalDecision,
        help: caseData['formal_type'] == 'dispute'
            ? l.formalDisputesHelp
            : l.formalReportsHelp,
        fields: [
          OperationField('status', l.opsStatus,
              initial: 'under_review',
              options: {
                'under_review': l.opsUnderReview,
                'resolved': l.formalResolve,
                'dismissed': l.formalDismiss,
              }),
          OperationField('resolution', l.opsResolution,
              multiline: true,
              validate: (v) => v.trim().length >= 3 ? null : l.opsInvalid),
        ],
        save: (fields) => api.request('PATCH',
            '/admin/${caseData['formal_type'] == 'dispute' ? 'disputes' : 'event-reports'}/${caseData['formal_id']}',
            body: fields));
    if (result != null && context.mounted) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = switch (caseData['formal_status']) {
      'under_review' => l.opsUnderReview,
      'resolved' => l.supportSolved,
      'dismissed' => l.opsDismissed,
      _ => l.supportOpen,
    };
    return SupportCasePanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${l.opsStatus}: $status',
          style: Theme.of(context).textTheme.titleSmall),
      if ('${caseData['formal_resolution'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 8),
        SelectableText('${l.opsResolution}: ${caseData['formal_resolution']}'),
      ],
      if (context.watch<AuthService>().currentUser?.isAdmin == true &&
          ['open', 'under_review'].contains(caseData['formal_status'])) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => _decide(context),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(l.formalDecision)),
      ],
    ]));
  }
}
