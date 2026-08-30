import 'package:drift/drift.dart';

// Utilisé sur Flutter Web (dart:io indisponible) — la première requête
// échoue, ce qu'AppDatabase.isAvailable() intercepte pour basculer
// SyncService en mode dégradé (appels API directs, sans cache/file).
QueryExecutor connect() {
  return LazyDatabase(() async {
    throw UnsupportedError('Drift natif indisponible sur cette plateforme (ex. Flutter Web).');
  });
}
