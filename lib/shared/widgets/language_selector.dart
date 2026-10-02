import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/locale_provider.dart';

/// Each language's name is shown in its own endonym (the way people
/// naturally refer to their own language), regardless of the app's
/// current locale - the same convention used by almost every app's
/// language picker. This is the one place in the UI that intentionally
/// is not run through AppLocalizations.
const List<_LanguageOption> _languageOptions = [
  _LanguageOption(code: 'kk', label: 'Қазақша'),
  _LanguageOption(code: 'ru', label: 'Русский'),
  _LanguageOption(code: 'en', label: 'English'),
];

class _LanguageOption {
  final String code;
  final String label;
  const _LanguageOption({required this.code, required this.label});
}

String currentLanguageLabel(BuildContext context) {
  final code = context.watch<LocaleProvider>().locale.languageCode;
  return _languageOptions.firstWhere((o) => o.code == code).label;
}

Future<void> showLanguageSheet(BuildContext context) {
  final localeProvider = context.read<LocaleProvider>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SingleChildScrollView(
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  sheetContext.l10n.languageTitle,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              ..._languageOptions.map((option) {
                final selected =
                    localeProvider.locale.languageCode == option.code;
                return ListTile(
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    localeProvider.setLocale(Locale(option.code));
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ));
    },
  );
}

/// Globe icon button for the AppBar (used on the login screen, per spec).
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language_rounded),
      tooltip: context.l10n.languageTitle,
      onPressed: () => showLanguageSheet(context),
    );
  }
}

/// Settings-style row used on the Profile screen: "Language  Қазақша  >"
class LanguageSettingsRow extends StatelessWidget {
  const LanguageSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showLanguageSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.language_rounded,
                color: AppColors.textPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.languageTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(currentLanguageLabel(context),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textTertiary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
