package dev.duet.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            listOf(
                "streak" to "Streak reminders",
                "friend" to "Friend activity",
                "games" to "Games",
            ).forEach { (id, name) ->
                manager.createNotificationChannel(
                    NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH),
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        getSystemService(NotificationManager::class.java).cancelAll()
    }
}
