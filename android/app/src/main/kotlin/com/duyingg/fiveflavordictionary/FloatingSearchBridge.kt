package com.duyingg.fiveflavordictionary

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.widget.Toast
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Main-activity control and explicit handoff from the floating window. */
class FloatingSearchBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, FloatingSearchService.CHANNEL)
    private val prefs = activity.getSharedPreferences(FloatingSearchService.PREFS, Activity.MODE_PRIVATE)
    private var permissionResult: MethodChannel.Result? = null
    private val permissionHandler = Handler(Looper.getMainLooper())
    private var hostResumed = false
    private var permissionScreenVisited = false
    private var permissionActivityReturned = false
    private var permissionCheckAttempts = 0
    private val checkPermission = Runnable {
        if (permissionResult != null && hostResumed && activity.hasWindowFocus()) {
            val granted = Settings.canDrawOverlays(activity)
            if (granted || ++permissionCheckAttempts >= 4) {
                completePermissionRequest(granted)
            } else {
                schedulePermissionCheck()
            }
        }
    }

    private fun schedulePermissionCheck() {
        permissionHandler.removeCallbacks(checkPermission)
        if (permissionResult != null && hostResumed && activity.hasWindowFocus() &&
            (permissionScreenVisited || permissionActivityReturned)) {
            // Some Settings implementations report their result before AppOps
            // and the activity/window lifecycle have settled.
            permissionHandler.postDelayed(checkPermission, 200L)
        }
    }

    private fun completePermissionRequest(granted: Boolean) {
        val result = permissionResult ?: return
        permissionResult = null
        permissionHandler.removeCallbacks(checkPermission)
        if (granted) prefs.edit().putBoolean("dismissed", false).remove("lastFailure").apply()
        result.success(granted)
    }

    @Suppress("DEPRECATION")
    private fun requestOverlayPermission(result: MethodChannel.Result) {
        permissionResult = result
        permissionScreenVisited = false
        permissionActivityReturned = false
        permissionCheckAttempts = 0
        val packageUri = Uri.parse("package:${activity.packageName}")
        val destinations = listOf(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri),
        )
        for (destination in destinations) {
            try {
                activity.startActivityForResult(destination, 8701)
                Toast.makeText(activity, "请在系统设置中找到五味字典，允许显示在其他应用上层，然后返回应用", Toast.LENGTH_LONG).show()
                return
            } catch (_: RuntimeException) {
                // Fall back to the standard list/app details if a vendor ROM
                // does not provide the requested permission screen.
            }
        }
        permissionResult = null
        result.error("PERMISSION_SETTINGS", "无法打开悬浮窗授权页，请从系统设置进入五味字典，允许显示在其他应用上层", null)
    }
    private var pendingQuery: String? = null
    private var openSettings = false
    private var launchId = 0
    var suppressClipboardFocus = false
        private set
    private val dismissedCallback: (String?) -> Unit = { message ->
        channel.invokeMethod("stopped", message?.let { mapOf("message" to it) })
    }

    init {
        channel.setMethodCallHandler(::onMethodCall)
        FloatingSearchService.onDismissed = dismissedCallback
        handleIntent(activity.intent)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareEnable" -> {
                if (permissionResult != null) {
                    result.error("PENDING", "请先完成悬浮窗授权", null)
                } else if (Settings.canDrawOverlays(activity)) {
                    prefs.edit().putBoolean("dismissed", false).remove("lastFailure").apply()
                    result.success(true)
                } else {
                    requestOverlayPermission(result)
                }
            }
            "sync" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                val granted = Settings.canDrawOverlays(activity)
                val dismissed = prefs.getBoolean("dismissed", false)
                val service = Intent(activity, FloatingSearchService::class.java)
                if (!enabled || !granted || dismissed) {
                    FloatingSearchService.updateConfiguration("{}")
                    prefs.edit().putBoolean("requested", false).apply()
                    activity.stopService(service)
                } else {
                    FloatingSearchService.updateConfiguration(call.argument<String>("configuration") ?: "{}")
                    val appearance = call.argument<Map<String, Any>>("appearance") ?: emptyMap()
                    prefs.edit().putBoolean("requested", true)
                        .putString("appearance", JSONObject(appearance).toString()).apply()
                    try {
                        if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(service)
                        else activity.startService(service)
                    } catch (_: RuntimeException) {
                        prefs.edit().putBoolean("requested", false).apply()
                        result.error("START_FAILED", "系统阻止启动悬浮查询，请保持应用在前台后重试", null)
                        return
                    }
                }
                result.success(mapOf("permissionGranted" to granted, "dismissed" to dismissed,
                    "message" to prefs.getString("lastFailure", null)))
            }
            "getLaunch" -> result.success(mapOf(
                "id" to launchId, "query" to pendingQuery, "settings" to openSettings))
            "ackLaunch" -> {
                if (call.argument<Int>("id") == launchId) {
                    pendingQuery = null
                    openSettings = false
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            FloatingSearchService.ACTION_QUERY -> {
                launchId++
                pendingQuery = intent.getStringExtra("query")
                openSettings = false
                suppressClipboardFocus = true
                intent.removeExtra("query")
                intent.action = null
                channel.invokeMethod("launchAvailable", null)
            }
            FloatingSearchService.ACTION_SETTINGS -> {
                launchId++
                pendingQuery = null
                openSettings = true
                suppressClipboardFocus = true
                intent.action = null
                channel.invokeMethod("launchAvailable", null)
            }
        }
    }

    fun onResume() {
        // An explicit floating-window query takes priority over automatic
        // clipboard navigation during the same foreground session.
        suppressClipboardFocus = pendingQuery != null || openSettings
        hostResumed = true
        schedulePermissionCheck()
    }

    fun onPause() {
        hostResumed = false
        if (permissionResult != null) permissionScreenVisited = true
        permissionHandler.removeCallbacks(checkPermission)
    }

    fun onWindowFocusChanged(focused: Boolean) {
        if (permissionResult == null) return
        if (!focused) {
            permissionScreenVisited = true
            permissionHandler.removeCallbacks(checkPermission)
        } else {
            schedulePermissionCheck()
        }
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != 8701) return false
        // Do not trust resultCode: overlay Settings commonly returns CANCELED
        // even after granting. onResume/focus provide the fallback if no result
        // callback is delivered by the device's Settings implementation.
        permissionActivityReturned = true
        schedulePermissionCheck()
        return true
    }

    fun dispose() {
        hostResumed = false
        permissionHandler.removeCallbacks(checkPermission)
        permissionResult?.error("DETACHED", "应用已关闭，请重新开启悬浮查询", null)
        permissionResult = null
        if (FloatingSearchService.onDismissed === dismissedCallback) {
            FloatingSearchService.onDismissed = null
        }
        channel.setMethodCallHandler(null)
    }
}
