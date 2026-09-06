package com.adai.taskhub_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Doit exister AVANT qu'un push n'arrive et AVEC l'id déclaré dans
        // AndroidManifest.xml (com.google.firebase.messaging.default_notification_channel_id) :
        // sinon FCM utilise un canal par défaut créé avec IMPORTANCE_DEFAULT,
        // qui ne montre jamais de bandeau (heads-up) automatique — la
        // notification arrive mais reste invisible tant qu'on ne tire pas le
        // tiroir de notifications.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                getString(R.string.default_notification_channel_id),
                "Notifications ADAI TaskHub",
                NotificationManager.IMPORTANCE_HIGH,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
