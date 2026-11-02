package com.opendex.companion

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject

class NotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn ?: return

        val extras = sbn.notification.extras ?: return
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val pkg = sbn.packageName

        if (pkg == "android" || pkg == "com.android.systemui") return

        val payload = JSONObject().apply {
            put("type", "notification")
            put("package", pkg)
            put("title", title)
            put("text", text)
            put("id", sbn.key)
            put("time", sbn.postTime)
        }

        CompanionServer.broadcast(payload.toString())
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        sbn ?: return
        val payload = JSONObject().apply {
            put("type", "notification_removed")
            put("id", sbn.key)
            put("package", sbn.packageName)
        }
        CompanionServer.broadcast(payload.toString())
    }
}
