import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/api_client.dart';
import '../../services/data_service.dart';
import '../attendee/attendee_ui.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage(
      {super.key,
      required this.title,
      required this.load,
      required this.content});
  final String title;
  final Future<dynamic> Function(ApiClient) load;
  final List<Widget> Function(OperationsPageState, dynamic) content;
  @override
  State<OperationsPage> createState() => OperationsPageState();
}

class OperationsPageState extends State<OperationsPage> {
  dynamic data;
  bool busy = false;
  String? error;
  ApiClient get api => context.read<DataService>().api;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.load(api);
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.caseBackground,
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
            tooltip: context.l10n.refreshStatus,
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (busy)
                                const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: LinearProgressIndicator()),
                              if (error != null)
                                OperationsCard(children: [
                                  const Icon(Icons.cloud_off_outlined,
                                      color: AppColors.error),
                                  Text(error!),
                                  OutlinedButton(
                                      onPressed: busy ? null : refresh,
                                      child: Text(context.l10n.commonRetry))
                                ]),
                              if (data != null) ...widget.content(this, data),
                            ])))
              ])));
}

class OperationsCard extends StatelessWidget {
  const OperationsCard(
      {super.key, required this.children, this.accent = false});
  final List<Widget> children;
  final bool accent;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
          color: accent ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: accent ? AppColors.primarySoft : AppColors.divider)),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      children[i]
                    ]
                  ]))));
}

class OperationsStatus extends StatelessWidget {
  const OperationsStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = switch (status) {
      'accepted' => l.opsAccepted,
      'revoked' => l.opsRevoked,
      'under_review' => l.opsUnderReview,
      'dismissed' => l.opsDismissed,
      'resolved' => l.supportSolved,
      'open' => l.supportOpen,
      'processing' => l.opsProcessing,
      'paid' => l.opsPaid,
      'blocked' => l.opsBlocked,
      _ => statusLabel(context, status)
    };
    final color = switch (status) {
      'accepted' || 'paid' || 'resolved' => AppColors.success,
      'revoked' || 'blocked' || 'dismissed' => AppColors.error,
      _ => AppColors.primaryInk
    };
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12)),
            child: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600))));
  }
}

class OperationField {
  const OperationField(this.key, this.label,
      {this.initial = '',
      this.options,
      this.number = false,
      this.multiline = false,
      this.date = false,
      this.validate});
  final String key, label, initial;
  final Map<String, String>? options;
  final bool number, multiline, date;
  final String? Function(String)? validate;
}

Future<dynamic> operationsForm(BuildContext context,
        {required String title,
        required String help,
        String? submitLabel,
        required List<OperationField> fields,
        required Future<dynamic> Function(Map<String, String>) save}) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OperationsForm(
            title: title,
            help: help,
            submitLabel: submitLabel,
            fields: fields,
            save: save));

class _OperationsForm extends StatefulWidget {
  const _OperationsForm(
      {required this.title,
      required this.help,
      required this.fields,
      required this.save,
      this.submitLabel});
  final String title, help;
  final String? submitLabel;
  final List<OperationField> fields;
  final Future<dynamic> Function(Map<String, String>) save;
  @override
  State<_OperationsForm> createState() => _OperationsFormState();
}

class _OperationsFormState extends State<_OperationsForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _fields = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: f.initial)
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget
          .save({for (final f in _fields.entries) f.key: f.value.text.trim()});
      if (mounted) Navigator.pop(context, result ?? true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _date(OperationField f) async {
    final original =
        DateTime.tryParse(_fields[f.key]!.text)?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: original,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(original));
    if (time == null || !mounted) return;
    setState(() => _fields[f.key]!.text =
        DateTime(date.year, date.month, date.day, time.hour, time.minute)
            .toUtc()
            .toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
            scrollable: true,
            title: Text(widget.title),
            content: Form(
                key: _form,
                child: SizedBox(
                    width: 500,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(widget.help),
                          if (widget.fields.any((f) => f.date)) ...[
                            const SizedBox(height: 8),
                            Text(l.opsLocalTime)
                          ],
                          const SizedBox(height: 20),
                          for (final f in widget.fields)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: f.options != null
                                    ? DropdownButtonFormField<String>(
                                        itemHeight: null,
                                        initialValue: _fields[f.key]!.text,
                                        isExpanded: true,
                                        decoration:
                                            InputDecoration(labelText: f.label),
                                        items: [
                                          for (final option
                                              in f.options!.entries)
                                            DropdownMenuItem(
                                                value: option.key,
                                                child: Text(option.value))
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (v) => _fields[f.key]!.text = v!)
                                    : f.date
                                        ? FormField<String>(
                                            validator: (_) =>
                                                DateTime.tryParse(_fields[f.key]!.text) ==
                                                        null
                                                    ? l.opsInvalid
                                                    : null,
                                            builder: (state) => InkWell(
                                                onTap: _busy
                                                    ? null
                                                    : () => _date(f),
                                                child: InputDecorator(
                                                    decoration: InputDecoration(
                                                        labelText: f.label,
                                                        errorText:
                                                            state.errorText,
                                                        suffixIcon: const Icon(
                                                            Icons.calendar_month)),
                                                    child: Text(DateTime.tryParse(_fields[f.key]!.text) == null ? '—' : DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(DateTime.parse(_fields[f.key]!.text).toLocal())))))
                                        : TextFormField(controller: _fields[f.key], enabled: !_busy, minLines: f.multiline ? 3 : 1, maxLines: f.multiline ? 6 : 1, maxLength: f.multiline ? 1000 : 250, keyboardType: f.number ? const TextInputType.numberWithOptions(decimal: true) : null, decoration: InputDecoration(labelText: f.label, errorMaxLines: 4, counterText: ''), validator: (v) => f.validate != null ? f.validate!(v?.trim() ?? '') : ((v ?? '').trim().isEmpty ? l.opsInvalid : null))),
                          if (_error != null)
                            Text(_error!,
                                style: const TextStyle(color: AppColors.error)),
                          if (_busy) const LinearProgressIndicator(),
                        ]))),
            actions: [
              TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(l.commonCancel)),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(widget.submitLabel ?? l.opsSave))
            ]));
  }
}
