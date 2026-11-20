import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/locale_provider.dart';
import 'routes.dart';
import 'theme.dart';

class BiletFlowApp extends StatelessWidget {
  const BiletFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;

    return MaterialApp(
      title: 'BiletFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: LocaleProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRoutes.generate,
      // One route preserves cold-start links without constructing intermediate
      // splash/login routes that could replace the link while it is being read.
      onGenerateInitialRoutes: (name) =>
          [AppRoutes.generate(RouteSettings(name: name))],
    );
  }
}
