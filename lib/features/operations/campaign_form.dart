import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';

/// Fixed KZT discounts use integer tiyn; floats never determine stored prices.
int? campaignMinorUnits(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
}

class CampaignForm extends StatefulWidget {
  const CampaignForm(
      {super.key,
      required this.eventId,
      required this.ticketTypes,
      this.campaign});
  final String eventId;
  final List<Map<String, dynamic>> ticketTypes;
  final Map<String, dynamic>? campaign;
  @override
  State<CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends State<CampaignForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _code, _value, _maximum;
  late DateTime _from, _until;
  late String _kind;
  late Set<String> _types;
  late bool _allTypes;
  bool _busy = false;
  String? _error;
  bool get _editing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _name = TextEditingController(text: c?['name'] as String? ?? '');
    final random = Random.secure();
    _code = TextEditingController(
        text: c?['code'] as String? ??
            'BF${List.generate(8, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[random.nextInt(32)]).join()}');
    _kind = c?['discount_type'] as String? ?? 'percentage';
    _value = TextEditingController(
        text: c == null
            ? '10'
            : (_kind == 'percentage'
                ? '${c['discount_value']}'
                : ((c['discount_value'] as num) / 100).toStringAsFixed(2)));
    _maximum = TextEditingController(text: '${c?['max_redemptions'] ?? 100}');
    _from = c == null
        ? DateTime.now()
        : parseApiDate(c['valid_from'] as String).toLocal();
    _until = c == null
        ? _from.add(const Duration(days: 7))
        : parseApiDate(c['valid_until'] as String).toLocal();
    _types = Set<String>.from(c?['applicable_ticket_type_ids'] as List? ?? []);
    _allTypes = _types.isEmpty;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _value, _maximum]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final original = start ? _from : _until;
    final date = await showDatePicker(
        context: context,
        initialDate: original,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(original));
    if (time == null || !mounted) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _from = selected;
      } else {
        _until = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final l = context.l10n;
    if (!_until.isAfter(_from)) {
      setState(() => _error = l.campaignDatesInvalid);
      return;
    }
    if (!_allTypes && _types.isEmpty) {
      setState(() => _error = l.opsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<DataService>().api.request(_editing ? 'PATCH' : 'POST',
          '/events/${Uri.encodeComponent(widget.eventId)}/campaigns${_editing ? '/${Uri.encodeComponent(widget.campaign!['id'] as String)}' : ''}',
          body: {
            'name': _name.text.trim(),
            if (!_editing) ...{
              'code': _code.text.trim().toUpperCase(),
              'discount_type': _kind,
              'discount_value': _kind == 'percentage'
                  ? int.parse(_value.text)
                  : campaignMinorUnits(_value.text),
            },
            'valid_from': _from.toUtc().toIso8601String(),
            'valid_until': _until.toUtc().toIso8601String(),
            'max_redemptions': int.parse(_maximum.text),
            'applicable_ticket_type_ids': _allTypes ? null : _types.toList(),
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String format(DateTime date) =>
        DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .add_Hm()
            .format(date);
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar:
              AppBar(title: Text(_editing ? l.campaignEdit : l.campaignCreate)),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Form(
                      key: _form,
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(l.campaignHelp),
                            if (_editing) Text(l.campaignImmutable),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _name,
                                enabled: !_busy,
                                maxLength: 150,
                                decoration:
                                    InputDecoration(labelText: l.campaignName),
                                validator: (v) => (v ?? '').trim().length < 2
                                    ? l.opsInvalid
                                    : null),
                            TextFormField(
                                controller: _code,
                                enabled: !_busy && !_editing,
                                maxLength: 40,
                                autocorrect: false,
                                decoration:
                                    InputDecoration(labelText: l.promoCode),
                                validator: (v) =>
                                    RegExp(r'^[A-Za-z0-9_-]{3,40}$')
                                            .hasMatch((v ?? '').trim())
                                        ? null
                                        : l.opsInvalid),
                            DropdownButtonFormField<String>(
                                initialValue: _kind,
                                isExpanded: true,
                                decoration:
                                    InputDecoration(labelText: l.campaignType),
                                items: [
                                  DropdownMenuItem(
                                      value: 'percentage',
                                      child: Text(l.campaignPercent)),
                                  DropdownMenuItem(
                                      value: 'fixed_kzt',
                                      child: Text(l.campaignFixed))
                                ],
                                onChanged: _busy || _editing
                                    ? null
                                    : (v) => setState(() => _kind = v!)),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _value,
                                enabled: !_busy && !_editing,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                    labelText: l.campaignValue,
                                    suffixText:
                                        _kind == 'percentage' ? '%' : '₸',
                                    errorMaxLines: 4),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  final minor = campaignMinorUnits(v ?? '');
                                  return _kind == 'percentage'
                                      ? (n != null && n > 0 && n <= 100
                                          ? null
                                          : l.campaignAmountInvalid)
                                      : (minor != null && minor > 0
                                          ? null
                                          : l.campaignAmountInvalid);
                                }),
                            const SizedBox(height: 16),
                            Text(l.opsLocalTime),
                            OutlinedButton.icon(
                                onPressed: _busy ? null : () => _date(true),
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                    '${l.campaignFrom}: ${format(_from)}')),
                            OutlinedButton.icon(
                                onPressed: _busy ? null : () => _date(false),
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                    '${l.campaignUntil}: ${format(_until)}')),
                            TextFormField(
                                controller: _maximum,
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: l.campaignMaximum),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  final used =
                                      (widget.campaign?['redemption_count']
                                                  as int? ??
                                              0) +
                                          (widget.campaign?['held_redemptions']
                                                  as int? ??
                                              0);
                                  return n != null &&
                                          n > 0 &&
                                          n <= 1000000 &&
                                          n >= used
                                      ? null
                                      : l.opsInvalid;
                                }),
                            const SizedBox(height: 16),
                            Text(l.campaignTypes,
                                style: Theme.of(context).textTheme.titleMedium),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l.campaignAllTypes),
                                value: _allTypes,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _allTypes = v!)),
                            if (!_allTypes)
                              for (final t in widget.ticketTypes
                                  .where((t) => t['kind'] == 'paid'))
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(t['name'] as String),
                                    value: _types.contains(t['id']),
                                    onChanged: _busy
                                        ? null
                                        : (v) => setState(() {
                                              if (v!) {
                                                _types.add(t['id'] as String);
                                              } else {
                                                _types.remove(t['id']);
                                              }
                                            })),
                            if (_error != null)
                              Semantics(
                                  liveRegion: true,
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 16),
                            if (_busy) const LinearProgressIndicator(),
                            FilledButton(
                                onPressed: _busy ? null : _save,
                                child: Text(l.opsSave)),
                          ])))),
        ));
  }
}
