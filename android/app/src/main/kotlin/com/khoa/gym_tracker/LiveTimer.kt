package com.khoa.gym_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The running timer, as a system Live Update.
 *
 * An ongoing notification that asks to be promoted is what Android 16 shows
 * as a status-bar chip, and what Samsung's Now Bar picks up on the lock
 * screen. Promotion has to be requested — qualifying for it is not enough —
 * and the request is a notification extra. Below API 36 the same notification
 * still posts — it just sits in the shade like any other ongoing one, which is
 * the honest fallback rather than nothing.
 *
 * The time itself is drawn by the platform chronometer from [WHEN], so the
 * seconds keep ticking even between our updates.
 */
class LiveTimer(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "chalk/live_timer"
        private const val CHANNEL_ID = "chalk_live_timer"
        const val NOTIFICATION_ID = 8412
        private const val TAG = "ChalkLiveTimer"

        /** Notification channels, and the builder that takes one, need O. */
        private const val MIN_SDK = Build.VERSION_CODES.O

        /** ProgressStyle, short critical text and the promoted flag. */
        private const val LIVE_UPDATE_SDK = 36

        /**
         * How an app asks for promotion. There is a setter for it —
         * `NotificationCompat.Builder.setRequestPromotedOngoing`, and
         * `Notification.Builder.setRequestPromotedOngoing` from platform 36.1 —
         * but the compat one does nothing except put this boolean, so the extra
         * *is* the request, and writing it directly works on plain 36 too,
         * where the setter does not exist to be called.
         */
        private const val EXTRA_REQUEST_PROMOTED_ONGOING =
            "android.requestPromotedOngoing"
    }

    /** Diagnosis is logged once per timer, not once a second. */
    private var diagnosed = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "show" -> {
                    show(call)
                    result.success(null)
                }
                "hide" -> {
                    hide()
                    result.success(null)
                }
                "status" -> result.success(status())
                "openSettings" -> {
                    openSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // A timer that cannot be mirrored is not a reason to break logging.
            result.error("live_timer", e.message, null)
        }
    }

    private fun notifications(): NotificationManager =
        context.getSystemService(NotificationManager::class.java)

    private fun ensureChannel() {
        val manager = notifications()
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Workout timers",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "The set or rest timer, while a workout is running."
            // It updates every second; it must never make a sound for it.
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun contentIntent(): PendingIntent? {
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            } ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun show(call: MethodCall) {
        if (Build.VERSION.SDK_INT < MIN_SDK) return
        ensureChannel()

        val title = call.argument<String>("title") ?: "Workout"
        val text = call.argument<String>("text") ?: ""
        val shortText = call.argument<String>("shortText") ?: ""
        val countdown = call.argument<Boolean>("countdown") ?: false
        val whenMillis = call.argument<Number>("whenMillis")?.toLong()
            ?: System.currentTimeMillis()
        val progress = call.argument<Number>("progress")?.toInt() ?: 0
        val progressMax = call.argument<Number>("progressMax")?.toInt() ?: 0
        val color = call.argument<Number>("color")?.toInt() ?: 0xFF00C853.toInt()

        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_chalk)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setLocalOnly(true)
            .setShowWhen(true)
            .setWhen(whenMillis)
            // The platform ticks the clock for us, between our updates.
            .setUsesChronometer(true)
            .setChronometerCountDown(countdown)
            .setCategory(
                if (countdown) Notification.CATEGORY_STOPWATCH
                else Notification.CATEGORY_WORKOUT
            )
            // Deliberately not setColorized: a notification that paints its
            // own background is disqualified from promotion, so the coloured
            // shade entry would cost us the chip. setColor on its own is only
            // an accent, and is allowed. Tried the other way round on One UI
            // 8.5, on the theory that its capsule sorts off the colorized
            // foreground-service section — it does not; the notification stays
            // in the ordinary section either way.
            .setColor(color)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            // A crashed app should not leave a timer stuck on the lock screen.
            .setTimeoutAfter(3 * 60 * 60 * 1000L)

        contentIntent()?.let { builder.setContentIntent(it) }

        if (Build.VERSION.SDK_INT >= LIVE_UPDATE_SDK) {
            promote(builder, shortText, progress, progressMax, color)
        }

        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= LIVE_UPDATE_SDK) {
            // Belt and braces for the first Android 16 release, which read
            // promotion off the posted notification's flags before 36.1 moved
            // the request into the extra above. The platform clears it again if
            // it disagrees, so claiming it costs nothing.
            notification.flags = notification.flags or Notification.FLAG_PROMOTED_ONGOING
        }
        if (LiveTimerService.running) {
            // Already in the foreground; update in place and keep it alive.
            LiveTimerService.pending = notification
            notifications().notify(NOTIFICATION_ID, notification)
            LiveTimerService.keepAlive()
            // Only once it is really up: starting the service is asynchronous,
            // so on the first tick there is nothing posted to read back yet.
            diagnose(notification)
        } else {
            LiveTimerService.start(context, notification)
        }
    }

    /**
     * The Android 16 half: the short text is what the status-bar chip shows
     * when collapsed, and a progress bar is one of the shapes the system will
     * promote. Without a max there is nothing to fill, so it runs
     * indeterminate rather than pretending to a total it does not have.
     */
    private fun promote(
        builder: Notification.Builder,
        shortText: String,
        progress: Int,
        progressMax: Int,
        color: Int,
    ) {
        if (shortText.isNotEmpty()) builder.setShortCriticalText(shortText)

        val style = Notification.ProgressStyle()
        if (progressMax > 0) {
            style.setProgressSegments(
                listOf(Notification.ProgressStyle.Segment(progressMax).setColor(color))
            )
            style.setProgress(progress.coerceIn(0, progressMax))
        } else {
            style.setProgressIndeterminate(true)
        }
        builder.setStyle(style)
        // The part that qualifying does not do for you: ask.
        builder.addExtras(
            Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) }
        )
    }


    /**
     * Says in logcat why the chip is or is not there, because three separate
     * gates can hold it back and only the first is ours to fix: the
     * notification must qualify, the user must not have turned Live Updates off
     * for this app, and Samsung keeps third-party live notifications behind a
     * developer setting of its own on early One UI 8.
     *
     *     adb logcat -s ChalkLiveTimer
     */
    private fun diagnose(notification: Notification) {
        if (Build.VERSION.SDK_INT < LIVE_UPDATE_SDK || diagnosed) return
        diagnosed = true
        try {
            val posted = notifications().activeNotifications
                .firstOrNull { it.id == NOTIFICATION_ID }
                ?.notification
            Log.i(
                TAG,
                "qualifies=${notification.hasPromotableCharacteristics()}" +
                    " allowed=${notifications().canPostPromotedNotifications()}" +
                    " promoted=${
                        posted != null &&
                            (posted.flags and Notification.FLAG_PROMOTED_ONGOING) != 0
                    }",
            )
        } catch (e: Exception) {
            Log.w(TAG, "could not read promotion state", e)
        }
    }

    /**
     * The same three gates as [diagnose], as data rather than a log line, so
     * the app can tell you which one is shut. Reading it while a timer runs
     * says the most, because only a posted notification can report whether the
     * platform actually promoted it.
     */
    private fun status(): Map<String, Any> {
        val out = mutableMapOf<String, Any>(
            "sdk" to Build.VERSION.SDK_INT,
            "supported" to (Build.VERSION.SDK_INT >= LIVE_UPDATE_SDK),
            "notifications" to false,
            "allowed" to false,
            "running" to false,
            "qualifies" to false,
            "promoted" to false,
        )
        if (Build.VERSION.SDK_INT < MIN_SDK) return out

        val manager = notifications()
        out["notifications"] = manager.areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < LIVE_UPDATE_SDK) return out

        out["allowed"] = manager.canPostPromotedNotifications()
        val posted = manager.activeNotifications
            .firstOrNull { it.id == NOTIFICATION_ID }
            ?.notification
            ?: return out
        out["running"] = true
        out["qualifies"] = posted.hasPromotableCharacteristics()
        out["promoted"] = (posted.flags and Notification.FLAG_PROMOTED_ONGOING) != 0
        return out
    }

    /**
     * The system's own Live Updates screen for this app. Falls back to the
     * plain notification settings, which is where the switch lives on a phone
     * that has no separate one.
     */
    private fun openSettings() {
        val promotion = Build.VERSION.SDK_INT >= LIVE_UPDATE_SDK
        val actions = if (promotion) {
            listOf(
                Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS,
                Settings.ACTION_APP_NOTIFICATION_SETTINGS,
            )
        } else {
            listOf(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        }
        for (action in actions) {
            val intent = Intent(action)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w(TAG, "no settings screen for $action", e)
            }
        }
    }

    private fun hide() {
        if (Build.VERSION.SDK_INT < MIN_SDK) return
        diagnosed = false
        LiveTimerService.stop(context)
        notifications().cancel(NOTIFICATION_ID)
    }
}
