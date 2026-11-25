import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../attendee/attendee_ui.dart';
import '../organizer/event_management_screen.dart';
import 'operations_ui.dart';

/// Administrator review workspace; attendees use Support Chat.
class FormalCasesScreen extends StatefulWidget {
  const FormalCasesScreen(
      {super.key, this.disputes = false, this.review = false});
  final bool disputes, review;
  @override
  State<FormalCasesScreen> createState() => _FormalCasesScreenState();
}

class _FormalCasesScreenState extends State<FormalCasesScreen> {
  String _status = '';
  String _query = '';

  Future<void> _decide(
      OperationsPageState state, Map<String, dynamic> row) async {
    final l = context.l10n;
    final result = await operationsForm(context,
        title: l.formalDecision,
        help: widget.disputes ? l.formalDisputesHelp : l.formalReportsHelp,
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
              validate: (v) => v.length >= 3 ? null : l.opsInvalid),
        ],
        save: (f) => state.api.request('PATCH',
            '/admin/${widget.disputes ? 'disputes' : 'event-reports'}/${Uri.encodeComponent(row['id'] as String)}',
            body: f));
    if (result != null && state.mounted) await state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final admin = context.watch<AuthService>().currentUser?.isAdmin == true;
    final review = widget.review && admin;
    return OperationsPage(
      title: widget.disputes ? l.formalDisputes : l.formalReports,
      load: (api) => api.request(
          'GET',
          widget.review
              ? '/admin/${widget.disputes ? 'disputes' : 'event-reports'}'
              : '/${widget.disputes ? 'disputes' : 'reports'}/mine'),
      content: (state, value) {
        final rows = (value as List)
            .cast<Map<String, dynamic>>()
            .where((r) =>
                (_status.isEmpty || r['status'] == _status) &&
                [r['event_title'], r['order_id'], r['reason'], r['resolution']]
                    .any((v) => '$v'.toLowerCase().contains(_query)))
            .toList();
        return [
          OperationsCard(children: [
            Text(widget.disputes ? l.formalDisputesHelp : l.formalReportsHelp),
            TextField(
                decoration: InputDecoration(
                    labelText: l.homeSearchHint,
                    prefixIcon: const Icon(Icons.search)),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase())),
            DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.opsStatus),
                items: [
                  DropdownMenuItem(value: '', child: Text(l.categoryAll)),
                  DropdownMenuItem(value: 'open', child: Text(l.supportOpen)),
                  DropdownMenuItem(
                      value: 'under_review', child: Text(l.opsUnderReview)),
                  DropdownMenuItem(
                      value: 'resolved', child: Text(l.supportSolved)),
                  DropdownMenuItem(
                      value: 'dismissed', child: Text(l.opsDismissed)),
                ],
                onChanged: (v) => setState(() => _status = v ?? '')),
          ]),
          if (rows.isEmpty)
            OperationsCard(children: [Text(l.managementNoData)]),
          for (final row in rows)
            OperationsCard(children: [
              Text(row['event_title'] as String,
                  style: Theme.of(context).textTheme.titleMedium),
              OperationsStatus(row['status'] as String),
              Text(DateFormat.yMMMd(Localizations.localeOf(context).toString())
                  .add_Hm()
                  .format(parseApiDate(row['created_at'] as String).toLocal())),
              if (widget.disputes) ...[
                Text(money(row['total_minor'] as num)),
                StatusBadge(row['order_status'] as String),
              ],
              Text(row['reason'] as String),
              if ('${row['resolution'] ?? ''}'.isNotEmpty)
                Text('${l.opsResolution}: ${row['resolution']}'),
              if (review) ...[
                OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EventManagementScreen(
                                eventId: row['event_id'] as String,
                                title: row['event_title'] as String))),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(l.opsReviewEvent)),
                if (['open', 'under_review'].contains(row['status']))
                  FilledButton(
                      onPressed: state.busy ? null : () => _decide(state, row),
                      child: Text(l.formalDecision)),
              ],
            ]),
        ];
      },
    );
  }
}
