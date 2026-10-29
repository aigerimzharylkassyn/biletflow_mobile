import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../attendee/event_details_screen.dart';
import 'operations_ui.dart';

class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen(
      {super.key, required this.eventId, required this.title});
  final String eventId, title;
  Future<void> _invite(OperationsPageState state) async {
    final context = state.context, l = context.l10n;
    final result = await operationsForm(context,
        title: l.opsInvite,
        submitLabel: l.opsInvite,
        help: l.opsInvitationsHelp,
        fields: [
          OperationField('email', l.authEmailLabel,
              validate: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                  ? null
                  : l.authValidationEmailInvalid),
          OperationField('days', l.opsInviteDays,
              initial: '14',
              number: true,
              validate: (v) => int.tryParse(v) != null &&
                      int.parse(v) >= 1 &&
                      int.parse(v) <= 365
                  ? null
                  : l.opsInvalid),
        ],
        save: (f) => state.api.request('POST', '/events/$eventId/invitations',
            body: {'email': f['email'], 'days': int.parse(f['days']!)}));
    if (result == null || !state.mounted) return;
    await showDialog(
        context: state.context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: Text(l.opsInviteCode),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(result['email']),
                      const SizedBox(height: 12),
                      Text(l.opsInviteCodeHelp),
                      const SizedBox(height: 20),
                      SelectableText(result['token'])
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(l.opsDone)),
                  FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: result['token']));
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text(l.opsCopied)));
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(l.opsCopy))
                ]));
    if (state.mounted) await state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OperationsPage(
        title: l.opsInvitations,
        load: (api) => api.request('GET', '/events/$eventId/invitations'),
        content: (state, rows) => [
              OperationsCard(accent: true, children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                Text(l.opsInvitationsHelp),
                FilledButton.icon(
                    onPressed: state.busy ? null : () => _invite(state),
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: Text(l.opsInvite))
              ]),
              if ((rows as List).isEmpty)
                OperationsCard(children: [
                  const Icon(Icons.mail_outline, size: 32),
                  Text(l.managementNoData)
                ]),
              for (final r in rows)
                OperationsCard(children: [
                  Text(r['email'],
                      style: Theme.of(context).textTheme.titleMedium),
                  OperationsStatus(r['status']),
                  Text(
                      '${l.opsAccessUntil}: ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(DateTime.parse(r['expires_at']).toLocal())}'),
                  if (!['revoked', 'expired'].contains(r['status']))
                    OutlinedButton.icon(
                        onPressed: state.busy
                            ? null
                            : () async {
                                final result = await operationsForm(context,
                                    title: l.opsRevoke,
                                    submitLabel: l.opsRevoke,
                                    help: l.opsInvitationsHelp,
                                    fields: [],
                                    save: (_) => state.api.request('POST',
                                        '/events/$eventId/invitations/${r['id']}/revoke'));
                                if (result != null && state.mounted) {
                                  await state.refresh();
                                }
                              },
                        icon: const Icon(Icons.person_remove_outlined),
                        label: Text(l.opsRevoke)),
                ]),
            ]);
  }
}

class InvitedEventsScreen extends StatelessWidget {
  const InvitedEventsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OperationsPage(
        title: l.opsPrivateEvents,
        load: (api) => api.request('GET', '/events/invited/mine'),
        content: (state, rows) => [
              OperationsCard(accent: true, children: [
                Text(l.opsJoinHelp),
                FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final result = await operationsForm(context,
                                title: l.opsJoin,
                                submitLabel: l.opsAcceptInvitation,
                                help: l.opsJoinHelp,
                                fields: [
                                  OperationField('token', l.opsInviteCode,
                                      validate: (v) =>
                                          v.length >= 16 ? null : l.opsInvalid)
                                ],
                                save: (f) => state.api.request(
                                    'POST', '/invitations/accept',
                                    body: {'token': f['token']}));
                            if (result != null && state.mounted) {
                              final event = AppEvent.fromJson(
                                  Map<String, dynamic>.from(result));
                              await state.refresh();
                              if (state.mounted) {
                                await Navigator.push(
                                    state.context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            EventDetailsScreen(event: event)));
                              }
                            }
                          },
                    icon: const Icon(Icons.key_outlined),
                    label: Text(l.opsJoin))
              ]),
              if ((rows as List).isEmpty)
                OperationsCard(children: [
                  const Icon(Icons.lock_outline, size: 32),
                  Text(l.managementNoData)
                ]),
              for (final r in rows)
                OperationsCard(children: [
                  Text(r['title'],
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('${r['venue']['name']} · ${r['venue']['city']}'),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EventDetailsScreen(
                                  event: AppEvent.fromJson(
                                      Map<String, dynamic>.from(r))))),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l.creationDetails))
                ]),
            ]);
  }
}
