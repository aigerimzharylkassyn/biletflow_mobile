import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';
import '../models/event.dart';

/// Lets screens write `context.l10n.someKey` instead of the longer
/// `AppLocalizations.of(context)!.someKey`.
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension EventCategoryLocalization on EventCategory {
  String localizedLabel(AppLocalizations l) => switch (this) {
        EventCategory.music => l.categoryMusic,
        EventCategory.sport => l.categorySport,
        EventCategory.business => l.categoryBusiness,
        EventCategory.art => l.categoryArt,
        EventCategory.food => l.categoryFood,
        EventCategory.tech => l.categoryTech,
        EventCategory.student => l.categoryStudent,
        EventCategory.other => l.categoryOther,
      };
}
