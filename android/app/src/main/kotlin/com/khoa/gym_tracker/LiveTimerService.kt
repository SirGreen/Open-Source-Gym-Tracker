package com.khoa.gym_tracker

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Holds the running timer's notification as a foreground service.
 *
 * The platform only treats an ongoing notification as a promotable Live
 * Update — the status-bar chip, and Samsung's Now Bar — when it belongs to a
 * foreground service. The type is `specialUse` rather than `health`: health
 * demands body-sensor or activity-recognition access, which a stopwatch has
 * no business asking for.
 *
 * A watchdog stops the service if the app stops feeding it. Dart pushes an
 * update every second while a timer runs, so silence means the app is gone,
 * and an orphaned timer stuck on the lock screen would be worse than none.
 */
class LiveTimerService : Service() {

    companion object {
        const val ACTION_STOP = "com.khoa.gym_tracker.LIVE_STOP"

        /** Comfortably longer than the one-second update cadence. */
        private const val IDLE_TIMEOUT_MS = 30_000L

        /** Built by [LiveTimer]; handed over rather than re-parcelled. */
        @Volatile
        var pending: Notification? = null

        @Volatile
        var running = false

        @Volatile
        private var instance: LiveTimerService? = null

        fun start(context: Context, notification: Notification) {
            pending = notification
            context.startForegroundService(
                Intent(context, LiveTimerService::class.java)
            )
        }

        /** Called on every in-place update, to hold the watchdog off. */
        fun keepAlive() = instance?.resetWatchdog()

        fun stop(context: Context) {
            pending = null
            if (!running) return
            context.startService(
                Intent(context, LiveTimerService::class.java)
                    .setAction(ACTION_STOP)
            )
        }
    }

    private val watchdog = Handler(Looper.getMainLooper())
    private val giveUp = Runnable { shutdown() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }

        val notification = pending
        if (notification == null) {
            shutdown()
            return START_NOT_STICKY
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                LiveTimer.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(LiveTimer.NOTIFICATION_ID, notification)
        }
        instance = this
        running = true
        resetWatchdog()
        // The workout ends when the app says so, not when the system feels
        // like restarting us with no timer left to show.
        return START_NOT_STICKY
    }

    fun resetWatchdog() {
        watchdog.removeCallbacks(giveUp)
        watchdog.postDelayed(giveUp, IDLE_TIMEOUT_MS)
    }

    private fun shutdown() {
        watchdog.removeCallbacks(giveUp)
        running = false
        instance = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        watchdog.removeCallbacks(giveUp)
        running = false
        instance = null
        super.onDestroy()
    }
}
