import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/flow2/taskDetail_screen.dart';
import 'client_service.dart';

// Gère le cycle de vie des notifications push FCM : permission, envoi du
// token au backend (POST /devices, voir AuthController::registerDevice côté
// Laravel), et réaction à un message reçu (premier plan) ou tapé (ouverture
// de l'app depuis la notification système).
//
// ChangeNotifier : les écrans affichant un badge de notifications non lues
// (ex. ProjetListeScreen) s'abonnent pour se rafraîchir dès qu'un push
// arrive pendant qu'ils sont déjà affichés — sinon le badge ne se met à
// jour qu'au prochain changement d'écran, jamais en direct.
class PushService extends ChangeNotifier with WidgetsBindingObserver {
  PushService._();
  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  GlobalKey<NavigatorState>? _navigatorKey;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey => _scaffoldMessengerKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Premier plan : FCM n'affiche rien tout seul dans ce cas (contrairement
    // à l'arrière-plan/app fermée, où le système affiche automatiquement le
    // bloc "notification" du payload) — on le fait nous-mêmes via un SnackBar.
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null && body == null) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text([title, body].where((s) => s != null && s.isNotEmpty).join(' — ')),
          duration: const Duration(seconds: 4),
        ),
      );
      notifyListeners();
    });

    // L'app était en arrière-plan et l'utilisateur a tapé la notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFromData(message.data));

    // L'app était totalement fermée et a été lancée en tapant la notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openFromData(initialMessage.data);
    }

    _messaging.onTokenRefresh.listen(_registerToken);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Couvre le cas où l'utilisateur rouvre l'app normalement (pas en tapant
    // la notification) après qu'un push soit arrivé pendant qu'elle était en
    // arrière-plan : sans ça, le badge resterait faux jusqu'au prochain
    // changement d'écran qui refait l'appel réseau.
    if (state == AppLifecycleState.resumed) {
      notifyListeners();
    }
  }

  void _openFromData(Map<String, dynamic> data) {
    final taskId = data['task_id'];
    if (taskId == null) return;
    final id = int.tryParse(taskId.toString());
    if (id == null) return;
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(builder: (context) => TaskDetailScreen(taskId: id)),
    );
  }

  // À appeler après une connexion réussie : récupère le token FCM courant et
  // l'envoie au backend. Ne doit jamais faire échouer le login si ça rate
  // (réseau, permission refusée...) — d'où le try/catch qui avale l'erreur.
  Future<void> registerDevice() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (_) {
      // Pas bloquant : l'utilisateur reste connecté même sans push. Le
      // prochain appel à registerDevice() (ex. reconnexion) retentera.
    }
  }

  Future<void> _registerToken(String deviceToken) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('token');
    if (authToken == null) return;

    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/auth/devices"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $authToken",
      },
      body: jsonEncode({
        'device_token': deviceToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }),
    );
    // registerDevice() avale déjà toute exception (ne doit jamais bloquer le
    // login) — mais un échec HTTP silencieux (mauvaise route, 422...) ne
    // lève rien côté http.post. On le logue au moins, pour ne pas repasser
    // des heures à chercher pourquoi aucun push n'arrive.
    if (response.statusCode != 200) {
      debugPrint('PushService: échec enregistrement device (${response.statusCode}) ${response.body}');
    }
  }
}
