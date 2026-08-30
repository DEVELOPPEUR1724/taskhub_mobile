import 'package:flutter/foundation.dart';

class ClientService {
  // 127.0.0.1 pointe vers la machine elle-même (Web/Windows), mais vers
  // l'émulateur Android lui-même quand on tourne dedans — 10.0.2.2 est
  // l'adresse spéciale qui, depuis un émulateur Android, redirige vers le
  // "localhost" de la machine hôte (celle qui fait tourner `php artisan
  // serve`). Sur un vrai appareil (USB), aucune des deux ne fonctionne : il
  // faut alors remplacer temporairement par l'adresse IP locale du PC (ex.
  // 192.168.1.x), affichée par `ipconfig`.
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000/api";
    }
    return "http://127.0.0.1:8000/api";
  }
}
