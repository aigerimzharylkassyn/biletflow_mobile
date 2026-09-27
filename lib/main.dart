 import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/locale_provider.dart';
import 'services/data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale(); // remembers language across restarts

  final api = ApiClient();
  final auth = AuthService(api);
  final data = DataService(api, auth);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: data),
      ],
      child: const BiletFlowApp(),
    ),
  );
}
