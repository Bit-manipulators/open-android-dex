package com.opendex.companion

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "Open DeX Companion"
            textSize = 22f
            setPadding(0, 0, 0, 24)
        }
        layout.addView(title)

        val status = TextView(this).apply {
            text = "Companion service bridges notifications and media to Open Android DeX on your PC."
            textSize = 14f
            setPadding(0, 0, 0, 32)
        }
        layout.addView(status)

        // Button to grant Notification Access
        val btnPerm = Button(this).apply {
            text = "Grant Notification Access"
            setOnClickListener {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                startActivity(intent)
            }
        }
        layout.addView(btnPerm)

        // Button to start foreground server
        val btnStart = Button(this).apply {
            text = "Start Background Bridge"
            setOnClickListener {
                val intent = Intent(this@MainActivity, CompanionServerService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }
        }
        layout.addView(btnStart)

        setContentView(layout)

        // Automatically start the service upon opening
        val intent = Intent(this, CompanionServerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
