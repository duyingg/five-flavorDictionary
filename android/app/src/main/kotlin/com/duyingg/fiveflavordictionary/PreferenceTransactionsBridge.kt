package com.duyingg.fiveflavordictionary

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** All handlers run on the platform thread; ownership is tied to an engine. */
class PreferenceTransactionsBridge(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger,
        "com.duyingg.fiveflavordictionary/preference_transactions")
    private var closing = false
    private var onClosed: (() -> Unit)? = null

    companion object {
        private data class Request(val owner: PreferenceTransactionsBridge,
            val group: String, val result: MethodChannel.Result)
        private val clients = mutableSetOf<PreferenceTransactionsBridge>()
        private val waiting = ArrayDeque<Request>()
        private var current: Request? = null
        private var token = 0

        private fun next() {
            if (current != null || waiting.isEmpty()) return
            current = waiting.removeFirst()
            token++
            current?.result?.success(token)
        }

        private fun release() {
            val previous = current ?: return
            current = null
            clients.filter { it !== previous.owner }.forEach {
                it.channel.invokeMethod("changed", previous.group)
            }
            next()
            previous.owner.completeIfIdle()
        }
    }

    init {
        clients.add(this)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    if (closing) {
                        result.error("DETACHED", "窗口已关闭", null)
                        return@setMethodCallHandler
                    }
                    waiting.add(Request(this, call.arguments as? String ?: "", result))
                    next()
                }
                "release" -> {
                    if (current?.owner === this &&
                        call.argument<Number>("token")?.toInt() == token) release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun completeIfIdle() {
        if (!closing || current?.owner === this || waiting.any { it.owner === this }) return
        clients.remove(this)
        channel.setMethodCallHandler(null)
        val done = onClosed
        onClosed = null
        done?.invoke()
    }

    fun closeWhenIdle(done: () -> Unit) {
        closing = true
        onClosed = done
        completeIfIdle()
    }

    fun dispose() {
        clients.remove(this)
        waiting.filter { it.owner === this }.forEach {
            waiting.remove(it)
            it.result.error("DETACHED", "窗口已关闭", null)
        }
        if (current?.owner === this) release()
        channel.setMethodCallHandler(null)
    }
}
