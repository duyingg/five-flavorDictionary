package com.duyingg.fiveflavordictionary

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var clipboardChannel: EventChannel? = null
    private var clipboardEvents: EventChannel.EventSink? = null
    private var clipboardManager: ClipboardManager? = null
    private var floatingSearch: FloatingSearchBridge? = null
    private var preferenceTransactions: PreferenceTransactionsBridge? = null
    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        if (hasWindowFocus()) clipboardEvents?.success("changed")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        preferenceTransactions = PreferenceTransactionsBridge(flutterEngine.dartExecutor.binaryMessenger)
        floatingSearch = FloatingSearchBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        clipboardChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.duyingg.fiveflavordictionary/clipboard",
        ).also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stopClipboardListener()
                    clipboardEvents = events
                    clipboardManager =
                        getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboardManager?.addPrimaryClipChangedListener(clipboardListener)
                    if (hasWindowFocus()) {
                        if (floatingSearch?.suppressClipboardFocus != true) events.success("focus")
                    } else events.success("blur")
                }

                override fun onCancel(arguments: Any?) {
                    stopClipboardListener()
                }
            })
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        floatingSearch?.onWindowFocusChanged(hasFocus)
        if (hasFocus && floatingSearch?.suppressClipboardFocus != true)
            clipboardEvents?.success("focus")
        else if (!hasFocus) clipboardEvents?.success("blur")
    }

    override fun onResume() {
        floatingSearch?.onResume()
        super.onResume()
    }

    override fun onPause() {
        floatingSearch?.onPause()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        floatingSearch?.handleIntent(intent)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        floatingSearch?.onActivityResult(requestCode)
    }

    private fun stopClipboardListener() {
        clipboardManager?.removePrimaryClipChangedListener(clipboardListener)
        clipboardManager = null
        clipboardEvents = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        preferenceTransactions?.dispose()
        preferenceTransactions = null
        floatingSearch?.dispose()
        floatingSearch = null
        stopClipboardListener()
        clipboardChannel?.setStreamHandler(null)
        clipboardChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
