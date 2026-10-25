import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event_creation.dart';

String creationError(BuildContext context, Object error) {
  if (error is! CreationValidation) return error.toString();
  final l = context.l10n;
  return switch (error.code) {
    'dates' => l.creationDateError,
    'future' => l.creationFutureError,
    'end' => l.creationEndError,
    'registration' => l.creationRegistrationError,
    'banner' => l.creationBannerError,
    'quantity' => l.creationQuantityError,
    'price' => l.creationPriceError,
    'maximum' => l.creationMaximumError,
    'sales' => l.creationSalesError,
    'tickets' || 'name' => l.creationTicketsError,
    'capacity' => l.creationCapacityError,
    'notDraft' => l.creationNotDraft,
    _ => l.applicationInvalid,
  };
}

class CreationDateField extends StatelessWidget {
  const CreationDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.enabled = true});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => FormField<DateTime>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      validator: (v) => v == null ? context.l10n.applicationInvalid : null,
      builder: (state) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: !enabled
                ? null
                : () async {
                    final initial = value ??
                        kazakhstanWallTime(DateTime.now())
                            .add(const Duration(days: 7));
                    final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime(initial.year, initial.month, initial.day),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                            hour: initial.hour, minute: initial.minute));
                    if (time == null || !context.mounted) return;
                    final next = DateTime.utc(date.year, date.month, date.day,
                        time.hour, time.minute);
                    state.didChange(next);
                    onChanged(next);
                  },
            child: InputDecorator(
                decoration: InputDecoration(
                    labelText: label,
                    errorText: state.errorText,
                    enabled: enabled,
                    suffixIcon: const Icon(Icons.event)),
                child: Text(value == null
                    ? '—'
                    : DateFormat('dd MMM yyyy · HH:mm',
                            Localizations.localeOf(context).languageCode)
                        .format(value!))),
          )));
}

/// Backend string limits count Unicode code points; surrounding spaces are not content.
String? creationTextError(BuildContext context, String? value,
    {int min = 0, int? max}) {
  final length = (value ?? '').trim().runes.length;
  final l = context.l10n;
  if (min > 0 && length == 0) return l.fieldRequired;
  if (length < min) return l.fieldMinCharacters(min);
  if (max != null && length > max) return l.fieldMaxCharacters(max);
  return null;
}

String? creationTextHint(BuildContext context, {int min = 0, int? max}) {
  final l = context.l10n;
  if (min > 0 && max != null) return l.fieldLengthRange(min, max);
  if (max != null) return l.fieldLengthMaximum(max);
  if (min > 1) return l.fieldLengthMinimum(min);
  return null;
}
