import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

/// Lets screens write `context.l10n.someKey` instead of the longer
/// `AppLocalizations.of(context)!.someKey`.
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
