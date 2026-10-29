import 'package:flutter/material.dart';

import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';

class AssignStaffDialog extends StatefulWidget {
  const AssignStaffDialog({super.key, required this.event, required this.data});

  final AppEvent event;
  final DataService data;

  @override
  State<AssignStaffDialog> createState() => _AssignStaffDialogState();
}

class _AssignStaffDialogState extends State<AssignStaffDialog> {
  final _form = GlobalKey<FormState>();
  String _email = '';
  String? _error;
  bool _busy = false;
  bool _assigned = false;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.data.assignStaff(widget.event.id, _email);
      if (mounted) setState(() => _assigned = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l.organizerAssignStaff),
        content: _assigned
            ? Text(l.staffAssignmentSuccess)
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.title),
                    const SizedBox(height: 12),
                    Text(l.staffAssignmentHelp),
                    const SizedBox(height: 16),
                    TextFormField(
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      decoration:
                          InputDecoration(labelText: l.staffAssignmentEmail),
                      onChanged: (value) => _email = value,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch((value ?? '').trim())
                              ? null
                              : l.staffAssignmentInvalidEmail,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ],
                ),
              ),
        actions: _assigned
            ? [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.commonOk))
              ]
            : [
                TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(l.commonCancel)),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.organizerAssignStaff),
                ),
              ],
      ),
    );
  }
}
