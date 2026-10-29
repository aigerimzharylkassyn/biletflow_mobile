import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

class SupportStaffDialog extends StatefulWidget {
  const SupportStaffDialog({super.key});
  @override
  State<SupportStaffDialog> createState() => _SupportStaffDialogState();
}

class _SupportStaffDialogState extends State<SupportStaffDialog> {
  final _email = TextEditingController();
  String? _event, _error;
  List<dynamic> _staff = [];
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_event == null) return;
    try {
      final rows = await context
          .read<AuthService>()
          .api
          .request('GET', '/support/events/$_event/staff') as List;
      if (mounted) setState(() => _staff = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _act([String? remove]) async {
    if (_busy || _event == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AuthService>().api;
      if (remove != null) {
        await api.request('DELETE', '/support/events/$_event/staff/$remove');
      } else {
        await api.request('POST', '/support/events/$_event/staff',
            body: {'email': _email.text.trim().toLowerCase()});
        _email.clear();
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final events = context.watch<DataService>().events;
    return AlertDialog(
        scrollable: true,
        title: Text(l.supportAuthorizeStaff),
        content: SizedBox(
            width: 440,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.supportExplicitPermission),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      initialValue: _event,
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: l.supportEventFilter),
                      items: [
                        for (final e in events)
                          DropdownMenuItem(
                              value: e.id,
                              child: Text(e.title,
                                  overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() {
                                _event = v;
                                _staff = [];
                              });
                              _load();
                            }),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          InputDecoration(labelText: l.staffAssignmentEmail)),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _busy || _event == null ? null : () => _act(),
                      child: Text(
                          _busy ? l.commonLoading : l.supportAuthorizeStaff)),
                  if (_error != null) Text(_error!),
                  for (final member in _staff)
                    ListTile(
                        title: Text(member['name']),
                        trailing: IconButton(
                            tooltip: l.supportRevoke,
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed:
                                _busy ? null : () => _act(member['id']))),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel))
        ]);
  }
}
