import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'screens/flow1/login_screen.dart';
import 'services/app_database.dart';
import 'services/connectivity_service.dart';
import 'services/push_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Doit être une fonction top-level (ou statique) : FCM la relance dans un
// isolate séparé quand un message arrive alors que l'app est en arrière-plan
// ou totalement fermée. On ne fait rien ici — le système affiche déjà tout
// seul la notification (bloc "notification" du payload), ce handler ne sert
// qu'à empêcher FCM de logguer une erreur pour l'absence de handler enregistré.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushService.instance.init(navigatorKey);

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
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: PushService.instance.scaffoldMessengerKey,
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
