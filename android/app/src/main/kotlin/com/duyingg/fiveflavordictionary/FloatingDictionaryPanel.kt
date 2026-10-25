package com.duyingg.fiveflavordictionary

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.JSONMethodCodec
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.LegacySharedPreferencesPlugin
import org.json.JSONObject

/** Hosts the independent Flutter lookup window and native window gestures. */
class FloatingDictionaryPanel(
    context: Context,
    private val configuration: () -> Map<String, Any>,
    private val beginMove: () -> Unit,
    private val move: (Float, Float) -> Unit,
    private val command: (String, String?) -> Unit,
) : FrameLayout(context) {
    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var preferences: PreferenceTransactionsBridge? = null
    private var channel: MethodChannel? = null
    private var clipboardChannel: EventChannel? = null
    private var clipboardEvents: EventChannel.EventSink? = null
    private var clipboardManager: ClipboardManager? = null
    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        if (!disposed && hasWindowFocus() && visibility == View.VISIBLE) clipboardEvents?.success("changed")
    }
    private var ready = false
    private var disposed = false
    private var downX = 0f
    private var downY = 0f
    private var rawX = 0f
    private var rawY = 0f
    private var moving = false
    private var pointerDown = false
    private val timeout = Runnable { command("failed", null) }

    fun start() {
        try {
            val flutterEngine = FlutterEngine(context.applicationContext, null, false)
            engine = flutterEngine
            // Only the preference plugin is needed. Do not register the main
            // activity's file picker, Hive or other activity-aware plugins.
            flutterEngine.plugins.add(LegacySharedPreferencesPlugin())
            preferences = PreferenceTransactionsBridge(flutterEngine.dartExecutor.binaryMessenger)
            installPlatformMessages(flutterEngine)
            installClipboardEvents(flutterEngine)
            channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                "com.duyingg.fiveflavordictionary/floating_view").also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> { ready = true; result.success(configuration()) }
                        "rendered" -> { handler.removeCallbacks(timeout); result.success(null) }
                        "startMoveWindow" -> {
                            if (pointerDown) {
                                moving = true
                                move(rawX - downX, rawY - downY)
                            }
                            result.success(null)
                        }
                        "moveWindow" -> {
                            if (moving) move(rawX - downX, rawY - downY)
                            result.success(null)
                        }
                        "endMoveWindow" -> {
                            if (moving) {
                                moving = false
                                command("moved", null)
                            }
                            result.success(null)
                        }
                        "collapse", "dismiss", "failed", "openApp", "clipboardQueried" -> {
                            result.success(null)
                            handler.post {
                                if (!disposed) command(call.method, call.arguments as? String)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
            val texture = FlutterTextureView(context).apply { isOpaque = false }
            flutterView = FlutterView(context, texture).also {
                addView(it, LayoutParams(-1, -1))
                it.attachToFlutterEngine(flutterEngine)
                it.isFocusableInTouchMode = true
                it.requestFocus()
            }
            val loader = FlutterInjector.instance().flutterLoader()
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "floatingDictionaryMain"))
            flutterEngine.lifecycleChannel.appIsResumed()
            if (hasWindowFocus()) flutterEngine.lifecycleChannel.aWindowIsFocused()
            handler.postDelayed(timeout, 30000)
        } catch (_: RuntimeException) {
            handler.post { if (!disposed) command("failed", null) }
        }
    }

    fun configure() {
        if (ready && !disposed) channel?.invokeMethod("configure", configuration())
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        rawX = event.rawX
        rawY = event.rawY
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            downX = rawX
            downY = rawY
            pointerDown = true
            moving = false
            beginMove()
        } else if (event.actionMasked == MotionEvent.ACTION_MOVE && moving) {
            // Native screen coordinates remain stable as the overlay moves.
            // Flutter only identifies the title gesture; it does not stream deltas.
            move(rawX - downX, rawY - downY)
        } else if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
            pointerDown = false
            if (moving) {
                if (event.actionMasked == MotionEvent.ACTION_UP) move(rawX - downX, rawY - downY)
                moving = false
                command("moved", null)
            }
        } else if (event.actionMasked == MotionEvent.ACTION_OUTSIDE) {
            handler.post { if (!disposed) command("collapse", null) }
            return true
        }
        return super.dispatchTouchEvent(event)
    }

    override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
        super.onWindowFocusChanged(hasWindowFocus)
        if (hasWindowFocus) engine?.lifecycleChannel?.aWindowIsFocused()
        else engine?.lifecycleChannel?.noWindowsAreFocused()
        clipboardEvents?.success(if (hasWindowFocus) "focus" else "blur")
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_UP) engine?.navigationChannel?.popRoute()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        if (visibility == View.VISIBLE) engine?.lifecycleChannel?.appIsResumed()
        else engine?.lifecycleChannel?.appIsPaused()
    }

    private fun stopClipboardListener() {
        clipboardManager?.removePrimaryClipChangedListener(clipboardListener)
        clipboardManager = null
        clipboardEvents = null
    }

    private fun installClipboardEvents(flutterEngine: FlutterEngine) {
        clipboardChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.duyingg.fiveflavordictionary/clipboard").also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stopClipboardListener()
                    clipboardEvents = events
                    clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboardManager?.addPrimaryClipChangedListener(clipboardListener)
                    events.success(if (hasWindowFocus()) "focus" else "blur")
                }
                override fun onCancel(arguments: Any?) { stopClipboardListener() }
            })
        }
    }

    private fun installPlatformMessages(flutterEngine: FlutterEngine) {
        // PlatformPlugin normally belongs to an Activity. This service hosts
        // only a window, so supply clipboard operations needed by Flutter's
        // real text fields and selection menus without altering system bars.
        flutterEngine.dartExecutor.binaryMessenger.setMessageHandler("flutter/platform") { message, reply ->
            if (message == null) {
                reply.reply(null)
                return@setMessageHandler
            }
            try {
                val call = JSONMethodCodec.INSTANCE.decodeMethodCall(message)
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val value: Any? = when (call.method) {
                    "Clipboard.getData" -> clipboard.primaryClip?.takeIf { it.itemCount > 0 }
                        ?.getItemAt(0)?.coerceToText(context)?.let { mapOf("text" to it.toString()) }
                    "Clipboard.hasStrings" -> mapOf("value" to clipboard.hasPrimaryClip())
                    "Clipboard.setData" -> {
                        val text = (call.arguments as JSONObject).optString("text")
                        clipboard.setPrimaryClip(ClipData.newPlainText("五味字典", text))
                        null
                    }
                    "SystemNavigator.pop" -> { handler.post { command("collapse", null) }; null }
                    else -> null
                }
                reply.reply(JSONMethodCodec.INSTANCE.encodeSuccessEnvelope(value))
            } catch (error: RuntimeException) {
                reply.reply(JSONMethodCodec.INSTANCE.encodeErrorEnvelope("PLATFORM", error.message, null))
            }
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        stopClipboardListener()
        clipboardChannel?.setStreamHandler(null)
        clipboardChannel = null
        handler.removeCallbacksAndMessages(null)
        (context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
            .hideSoftInputFromWindow(windowToken, 0)
        flutterView?.detachFromFlutterEngine()
        flutterView = null
        val oldEngine = engine
        engine = null
        oldEngine?.lifecycleChannel?.appIsDetached()
        channel?.setMethodCallHandler(null)
        channel = null
        preferences?.closeWhenIdle { handler.post { oldEngine?.destroy() } }
        if (preferences == null) oldEngine?.destroy()
        preferences = null
    }
}
