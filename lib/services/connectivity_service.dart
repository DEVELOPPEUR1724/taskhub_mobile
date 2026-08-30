import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

// Détecte l'état de connexion et déclenche une synchro automatique au retour
// du réseau. Note : connectivity_plus indique l'état de l'interface réseau
// (wifi/données associées), pas un vrai test d'accès Internet — si un flush
// échoue quand même (faux positif), les actions restent simplement en file,
// donc ça ne casse rien.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool isOnline = true;

  // Branché depuis main.dart une fois SyncService prêt, pour éviter une
  // dépendance circulaire entre les deux fichiers au chargement.
  void Function()? onReconnect;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    isOnline = !result.contains(ConnectivityResult.none);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = isOnline;
      isOnline = !results.contains(ConnectivityResult.none);
      if (!wasOnline && isOnline) {
        onReconnect?.call();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final connectivityService = ConnectivityService.instance;
