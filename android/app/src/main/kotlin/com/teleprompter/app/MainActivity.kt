package com.teleprompter.app

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android Picture-in-Picture for the teleprompter workspace.
 * The same Flutter activity keeps running (and scrolling) while it is shown in
 * the system PiP window; playback is controlled via PiP remote actions.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "teleprompter/pip"
    private val actionName = "com.teleprompter.app.PIP_ACTION"
    private var channel: MethodChannel? = null
    private var autoEnter = false
    private var playing = false
    private var portrait = false
    private var receiverRegistered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.getStringExtra("cmd")?.let { channel?.invokeMethod("pipAction", it) }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                )
                "configure" -> {
                    autoEnter = call.argument<Boolean>("autoEnter") ?: false
                    playing = call.argument<Boolean>("playing") ?: false
                    portrait = call.argument<Boolean>("portrait") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        runCatching { setPictureInPictureParams(buildParams()) }
                    }
                    result.success(null)
                }
                "minimize" -> { moveTaskToBack(true); result.success(null) }
                "enter" -> {
                    portrait = call.argument<Boolean>("portrait") ?: portrait
                    playing = call.argument<Boolean>("playing") ?: playing
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(runCatching { enterPictureInPictureMode(buildParams()) }.getOrDefault(false))
                    } else result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun action(cmd: String, icon: Int, title: String, code: Int): RemoteAction {
        val i = Intent(actionName).setPackage(packageName).putExtra("cmd", cmd)
        val pi = PendingIntent.getBroadcast(this, code, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return RemoteAction(Icon.createWithResource(this, icon), title, title, pi)
    }

    private fun buildParams(): PictureInPictureParams {
        val b = PictureInPictureParams.Builder()
            .setAspectRatio(if (portrait) Rational(9, 16) else Rational(16, 9))
            .setActions(listOf(
                action("slower", android.R.drawable.ic_media_rew, "Slower", 1),
                if (playing) action("pause", android.R.drawable.ic_media_pause, "Pause", 2)
                else action("play", android.R.drawable.ic_media_play, "Play", 3),
                action("faster", android.R.drawable.ic_media_ff, "Faster", 4),
            ))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) b.setAutoEnterEnabled(autoEnter)
        return b.build()
    }

    // Android 8–11: enter PiP when the user leaves while playing (12+ uses auto-enter).
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoEnter && Build.VERSION.SDK_INT in Build.VERSION_CODES.O until Build.VERSION_CODES.S) {
            runCatching { enterPictureInPictureMode(buildParams()) }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    override fun onStart() {
        super.onStart()
        if (!receiverRegistered) {
            val f = IntentFilter(actionName)
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, f, Context.RECEIVER_NOT_EXPORTED)
            else registerReceiver(receiver, f)
            receiverRegistered = true
        }
    }

    override fun onDestroy() {
        if (receiverRegistered) { unregisterReceiver(receiver); receiverRegistered = false }
        super.onDestroy()
    }
}
