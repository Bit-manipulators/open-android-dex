package com.opendex.companion

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CopyOnWriteArrayList

object CompanionServer {
    private const val PORT = 8888
    private val clientWriters = CopyOnWriteArrayList<PrintWriter>()
    private var serverJob: Job? = null

    fun start(scope: CoroutineScope) {
        if (serverJob != null && serverJob?.isActive == true) return

        serverJob = scope.launch(Dispatchers.IO) {
            try {
                // Bind exclusively to 127.0.0.1 loopback interface so the service is only
                // accessible via authorized ADB port forwarding (adb forward tcp:8888 tcp:8888)
                // and never exposed to untrusted local Wi-Fi or external networks.
                val serverSocket = ServerSocket(PORT, 50, InetAddress.getByName("127.0.0.1"))
                while (isActive) {
                    val socket = serverSocket.accept()
                    launch(Dispatchers.IO) {
                        handleClient(socket)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun handleClient(socket: Socket) {
        val writer = PrintWriter(socket.getOutputStream(), true)
        clientWriters.add(writer)

        try {
            val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
            while (true) {
                val line = reader.readLine() ?: break
                // Process incoming desktop commands (e.g. ping, request_apps)
            }
        } catch (_: Exception) {
        } finally {
            clientWriters.remove(writer)
            try { socket.close() } catch (_: Exception) {}
        }
    }

    fun broadcast(message: String) {
        for (writer in clientWriters) {
            try {
                writer.println(message)
            } catch (_: Exception) {}
        }
    }
}

class CompanionServerService : Service() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notif = createNotification()
        startForeground(101, notif)
        CompanionServer.start(scope)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "opendex_companion",
                "Open DeX Server",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "opendex_companion")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Open DeX Companion")
            .setContentText("Connected and streaming telemetry to PC")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .build()
    }
}
