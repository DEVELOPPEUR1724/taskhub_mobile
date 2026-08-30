import 'package:flutter/material.dart';

import 'screens/flow1/login_screen.dart';
import 'services/app_database.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();

  // Drift (sqlite natif) n'existe pas sur Flutter Web — isAvailable()
  // détecte l'échec une fois pour toutes, et SyncService bascule alors en
  // mode dégradé (appels directs à l'API, sans file d'attente locale).
  await AppDatabase.instance.isAvailable();
  await SyncService.instance.init();
  await ConnectivityService.instance.init();
  ConnectivityService.instance.onReconnect = () => SyncService.instance.syncNow();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ADAI TaskHub',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const LoginScreen(),
        );
      },
    );
  }
}
