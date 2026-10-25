package com.duyingg.fiveflavordictionary

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.ClipboardManager
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Matrix
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.Display
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.ImageView
import android.widget.Toast
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.min

/** Explicitly enabled, user-visible overlay. No boot receiver or hidden restart. */
class FloatingSearchService : Service() {
    companion object {
        const val PREFS = "floating_search"
        const val CHANNEL = "com.duyingg.fiveflavordictionary/floating_search"
        const val ACTION_QUERY = "com.duyingg.fiveflavordictionary.FLOATING_QUERY"
        const val ACTION_SETTINGS = "com.duyingg.fiveflavordictionary.FLOATING_SETTINGS"
        private const val ACTION_STOP = "com.duyingg.fiveflavordictionary.FLOATING_STOP"
        private const val NOTIFICATION_CHANNEL = "floating_dictionary"
        private const val NOTIFICATION_ID = 3102
        var onDismissed: ((String?) -> Unit)? = null
        private var configuration = "{}"
        private var configurationVersion = 0
        fun updateConfiguration(value: String) {
            if (configuration != value) {
                configuration = value
                configurationVersion++
            }
        }
        private fun configurationPayload(): Map<String, Any> = mapOf(
            "version" to configurationVersion, "configuration" to configuration)

    }

    private val prefs by lazy { getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    private val overlayContext: Context by lazy {
        if (Build.VERSION.SDK_INT >= 30) {
            val display = (getSystemService(DISPLAY_SERVICE) as DisplayManager)
                .getDisplay(Display.DEFAULT_DISPLAY)
                ?: throw IllegalStateException("没有可用的显示屏")
            createDisplayContext(display).createWindowContext(
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        } else this
    }
    private val windows by lazy { overlayContext.getSystemService(WINDOW_SERVICE) as WindowManager }
    private var ball: View? = null
    private var panel: FloatingDictionaryPanel? = null
    private var ballParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var moveStartX = 0
    private var moveStartY = 0
    private var ballY = -1
    private val idleHandler = Handler(Looper.getMainLooper())
    private var ballSleeping = false
    private var checkingBallClipboard = false
    private var lastQueriedClipboard: String? = null
    private val clipboardCheckTimeout = Runnable { finishBallClipboardCheck(read = false) }
    private val clipboardCheckFocused = Runnable { finishBallClipboardCheck(read = true) }

    private fun ballClicked() {
        if (checkingBallClipboard) return
        if (!ballSleeping) {
            showPanel()
        } else if (!appearance().optBoolean("clipboardSearchEnabled", false)) {
            wakeBall()
        } else {
            // Android clipboard access requires a focused window. This brief
            // focus is requested only by a tap, never by background polling.
            val view = ball ?: return
            val params = ballParams ?: return
            checkingBallClipboard = true
            idleHandler.removeCallbacks(tuckBall)
            params.flags = (params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()) or
                WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            updateBallLayout(view, params)
            view.requestFocus()
            idleHandler.postDelayed(clipboardCheckTimeout, 500L)
            if (view.hasWindowFocus()) idleHandler.post(clipboardCheckFocused)
        }
    }

    private fun cancelBallClipboardCheck() {
        checkingBallClipboard = false
        idleHandler.removeCallbacks(clipboardCheckTimeout)
        idleHandler.removeCallbacks(clipboardCheckFocused)
        val view = ball ?: return
        val params = ballParams ?: return
        params.flags = (params.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE) and
            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM.inv()
        updateBallLayout(view, params)
    }

    private fun finishBallClipboardCheck(read: Boolean) {
        if (!checkingBallClipboard) return
        val view = ball ?: return
        if (read && !view.hasWindowFocus()) return
        val query = if (read && appearance().optBoolean("clipboardSearchEnabled", false)) {
            try {
                val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.primaryClip?.takeIf { it.itemCount > 0 }
                    ?.getItemAt(0)?.text?.toString()?.trim()
            } catch (_: RuntimeException) { null }
        } else null
        val valid = query != null && isClipboardQuery(query)
        val changed = valid && query != lastQueriedClipboard
        if (query != null && !valid) lastQueriedClipboard = null
        cancelBallClipboardCheck()
        if (changed) showPanel() else wakeBall()
    }

    // Same unified/compatibility Han ranges and variation selectors as the
    // Flutter query validator; never treat a URL or arbitrary text as a query.
    private fun isClipboardQuery(text: String): Boolean {
        var index = 0
        var count = 0
        while (index < text.length) {
            val code = text.codePointAt(index)
            val han = code in 0x3400..0x4DBF || code in 0x4E00..0x9FFF ||
                code in 0xF900..0xFAFF || code in 0x20000..0x2EE5F ||
                code in 0x2F800..0x2FA1F || code in 0x30000..0x323AF
            if (han) {
                if (++count > 16) return false
            } else if (count == 0 || !(code in 0xFE00..0xFE0F || code in 0xE0100..0xE01EF)) {
                return false
            }
            index += Character.charCount(code)
        }
        return count > 0
    }
    private var dockedLeft = false
    private val tuckBall = Runnable { tuckBallIntoEdge() }
    private var ballAnimation: ValueAnimator? = null
    private var ballFramePending = false
    private var ballAreaHeight = 0
    private var appearanceSource: String? = null
    private var cachedAppearance = JSONObject()
    private val ballFrame = Runnable {
        ballFramePending = false
        val view = ball
        val params = ballParams
        if (view != null && params != null && view.isAttachedToWindow) {
            updateBallLayout(view, params)
        }
    }

    // Touch streams may be faster than the display. Submit only the latest
    // coordinates once per frame instead of one WindowManager IPC per event.
    private fun requestBallFrame() {
        val view = ball ?: return
        if (!ballFramePending && view.isAttachedToWindow) {
            ballFramePending = true
            view.postOnAnimation(ballFrame)
        }
    }

    private fun cancelBallMotion() {
        val animation = ballAnimation
        ballAnimation = null
        animation?.cancel()
        ball?.removeCallbacks(ballFrame)
        ballFramePending = false
    }

    private fun saveBallPosition() {
        val params = ballParams ?: return
        val area = bounds()
        val travel = (area.height() - params.height).coerceAtLeast(1)
        dockedLeft = params.x + params.width / 2 < area.width() / 2
        ballY = params.y
        prefs.edit().putBoolean("ballDockLeft", dockedLeft)
            .putFloat("ballYFraction", (params.y.toFloat() / travel).coerceIn(0f, 1f)).apply()
    }

    private fun snapBallToEdge() {
        val view = ball ?: return
        val params = ballParams ?: return
        if (!view.isAttachedToWindow) return
        cancelBallMotion()
        val area = bounds()
        dockedLeft = params.x + params.width / 2 < area.width() / 2
        val destination = if (dockedLeft) 0 else (area.width() - params.width).coerceAtLeast(0)
        saveBallPosition()
        if (params.x == destination || !view.isEnabled ||
            (Build.VERSION.SDK_INT >= 26 && !ValueAnimator.areAnimatorsEnabled())) {
            params.x = destination
            updateBallLayout(view, params)
            scheduleBallIdle()
            return
        }
        ballAnimation = ValueAnimator.ofInt(params.x, destination).apply {
            duration = 180L
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                if (ball === view) {
                    params.x = it.animatedValue as Int
                    requestBallFrame()
                }
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (ballAnimation === animation) {
                        ballAnimation = null
                        scheduleBallIdle()
                    }
                }
            })
            start()
        }
    }

    private fun scheduleBallIdle() {
        idleHandler.removeCallbacks(tuckBall)
        if (ball != null && !ballSleeping && !checkingBallClipboard) idleHandler.postDelayed(tuckBall, 5000L)
    }

    // Shrink the actual overlay window to the exposed edge tab. The hidden
    // part must not intercept touches intended for the application underneath.
    private fun tuckBallIntoEdge() {
        val view = ball as? ImageView ?: return
        val params = ballParams ?: return
        cancelBallMotion()
        dockedLeft = params.x + params.width / 2 < bounds().width() / 2
        ballSleeping = true
        params.width = dp(18)
        params.x = if (dockedLeft) 0 else bounds().width() - params.width
        val drawable = view.drawable
        view.scaleType = ImageView.ScaleType.MATRIX
        view.imageMatrix = Matrix().apply {
            val left = if (dockedLeft) (dp(18) - dp(52)).toFloat() else 0f
            setRectToRect(RectF(0f, 0f, drawable.intrinsicWidth.coerceAtLeast(1).toFloat(),
                drawable.intrinsicHeight.coerceAtLeast(1).toFloat()),
                RectF(left, 0f, left + dp(52), dp(52).toFloat()), Matrix.ScaleToFit.FILL)
        }
        view.contentDescription = if (appearance().optBoolean("clipboardSearchEnabled", false))
            "五味字典悬浮球已隐藏，点击查询新的剪切板字词或唤醒，再次点击搜索"
            else "五味字典悬浮球已隐藏，点击唤醒，再次点击搜索"
        updateBallLayout(view, params)
    }

    private fun wakeBall(schedule: Boolean = true) {
        val view = ball as? ImageView ?: return
        val params = ballParams ?: return
        ballSleeping = false
        params.width = dp(52)
        params.x = if (dockedLeft) 0 else bounds().width() - params.width
        view.scaleType = ImageView.ScaleType.FIT_CENTER
        view.contentDescription = "五味字典悬浮球，点击搜索，可拖动"
        clamp(params)
        updateBallLayout(view, params)
        if (schedule) scheduleBallIdle()
    }

    private fun updateBallLayout(view: View, params: WindowManager.LayoutParams) {
        clamp(params)
        try { windows.updateViewLayout(view, params) }
        catch (_: RuntimeException) { fail("无法更新悬浮球，请检查悬浮窗权限") }
    }

    override fun onCreate() {
        super.onCreate()
        if (!prefs.getBoolean("requested", false) || !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        try {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(
                    NOTIFICATION_CHANNEL, "悬浮球查询", NotificationManager.IMPORTANCE_LOW,
                ))
            }
            val settings = PendingIntent.getActivity(this, 0,
                Intent(this, MainActivity::class.java).setAction(ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val stop = PendingIntent.getService(this, 1,
                Intent(this, FloatingSearchService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, NOTIFICATION_CHANNEL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            val notification = builder.setSmallIcon(R.drawable.ic_floating_dictionary)
                .setContentTitle("五味字典悬浮查询")
                .setContentText("点击悬浮球搜索字词；点击此通知返回设置")
                .setContentIntent(settings).setOngoing(true)
                .addAction(Notification.Action.Builder(null, "关闭", stop).build())
                .build()
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, 0)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: RuntimeException) {
            fail("无法启动悬浮查询，请检查系统悬浮窗设置")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            dismiss()
        } else if (!prefs.getBoolean("requested", false) || !Settings.canDrawOverlays(this)) {
            stopSelf()
        } else try {
            if (ball == null && panel == null) {
                showBall()
            } else {
                if (checkingBallClipboard && !appearance().optBoolean("clipboardSearchEnabled", false)) {
                    finishBallClipboardCheck(read = false)
                }
                panel?.background = background(18)
                ballParams?.let { params ->
                    params.alpha = ballOpacity()
                    ball?.let {
                        try { windows.updateViewLayout(it, params) }
                        catch (_: RuntimeException) { fail("无法更新悬浮球，请检查悬浮窗权限") }
                    }
                }
                resizePanel()
                panel?.configure()
            }
        } catch (_: RuntimeException) {
            fail("无法创建悬浮窗口，请确认系统已允许五味字典显示在其他应用上层")
        }
        return START_NOT_STICKY
    }

    private fun dp(value: Int) = (overlayContext.resources.displayMetrics.density * value).toInt()
    private fun background(round: Int) = GradientDrawable().apply {
        setColor(appearance().optLong("background", Color.rgb(255, 250, 240).toLong()).toInt())
        cornerRadius = dp(round).toFloat()
        setStroke(dp(1), appearance().optLong("border", Color.rgb(174, 196, 175).toLong()).toInt())
    }

    private fun bounds(): Rect {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            return Rect(0, 0, metrics.bounds.width() - insets.left - insets.right,
                metrics.bounds.height() - insets.top - insets.bottom)
        }
        @Suppress("DEPRECATION")
        val metrics = android.util.DisplayMetrics().also { windows.defaultDisplay.getMetrics(it) }
        return Rect(0, 0, metrics.widthPixels, metrics.heightPixels)
    }

    @Suppress("DEPRECATION")
    private fun parameters(width: Int, height: Int, focusable: Boolean) =
        WindowManager.LayoutParams(width, height,
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                (if (focusable) WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                else WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        }

    private fun clamp(params: WindowManager.LayoutParams) {
        val area = bounds()
        params.x = params.x.coerceIn(0, (area.width() - params.width).coerceAtLeast(0))
        params.y = params.y.coerceIn(0, (area.height() - params.height).coerceAtLeast(0))
    }

    private fun showBall() {
        if (ball != null) return
        val view = object : ImageView(overlayContext) {
            override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
                super.onWindowFocusChanged(hasWindowFocus)
                if (hasWindowFocus && checkingBallClipboard) idleHandler.post(clipboardCheckFocused)
            }
        }.apply {
            setImageDrawable(packageManager.getApplicationIcon(applicationInfo))
            // Keep the square application artwork intact. No round plate or
            // extra padding: the same 52dp image is cropped when edge-docked.
            setPadding(0, 0, 0, 0)
            scaleType = ImageView.ScaleType.FIT_CENTER
            elevation = dp(6).toFloat()
            isFocusable = true
            isFocusableInTouchMode = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            contentDescription = "五味字典悬浮球，点击搜索，可拖动"
        }
        val params = parameters(dp(52), dp(52), false).apply {
            alpha = ballOpacity()
            val area = bounds()
            dockedLeft = prefs.getBoolean("ballDockLeft", appearance().optBoolean("leftHanded", false))
            x = if (dockedLeft) 0 else (area.width() - width).coerceAtLeast(0)
            val fraction = prefs.getFloat("ballYFraction", 1f / 3f).coerceIn(0f, 1f)
            y = ((area.height() - height).coerceAtLeast(0) * fraction).toInt()
            ballAreaHeight = area.height()
        }
        clamp(params)
        ballSleeping = false
        view.setOnClickListener { ballClicked() }
        installBallDrag(view, params)
        try {
            windows.addView(view, params)
            ball = view
            ballParams = params
            scheduleBallIdle()
        } catch (_: RuntimeException) {
            fail("无法显示悬浮球，请重新授权显示在其他应用上层")
        }
    }

    private fun ballOpacity() = appearance().optDouble("opacity", 1.0).toFloat().coerceIn(0.2f, 1f)

    private fun appearance(): JSONObject {
        val source = prefs.getString("appearance", "{}") ?: "{}"
        if (source != appearanceSource) {
            cachedAppearance = try { JSONObject(source) }
                catch (_: RuntimeException) { JSONObject() }
            appearanceSource = source
        }
        return cachedAppearance
    }

    private fun panelWidth(area: Rect): Int {
        val available = area.width().coerceAtLeast(1)
        val ratio = appearance().optDouble("windowWidth", 1.0).coerceIn(.6, 1.0)
        return (available * ratio).toInt().coerceIn(min(dp(260), available), available)
    }

    private fun panelHeight(area: Rect): Int {
        val available = area.height().coerceAtLeast(1)
        val ratio = appearance().optDouble("windowHeight", .4).coerceIn(.35, .95)
        return (available * ratio).toInt().coerceIn(1, available)
    }

    private fun resizePanel() {
        val params = panelParams ?: return
        val area = bounds()
        params.width = panelWidth(area)
        params.height = panelHeight(area)
        params.alpha = 1f
        clamp(params)
        panel?.let { try { windows.updateViewLayout(it, params) } catch (_: RuntimeException) {} }
    }

    private fun savePanelPosition() {
        panelParams?.let { prefs.edit().putInt("panelX", it.x).putInt("panelY", it.y).apply() }
    }

    private fun showPanel() {
        if (panel != null) return
        idleHandler.removeCallbacks(tuckBall)
        if (checkingBallClipboard) cancelBallClipboardCheck()
        cancelBallMotion()
        saveBallPosition()
        remove(ball)
        ball = null
        ballParams = null
        val root = FloatingDictionaryPanel(overlayContext, ::configurationPayload,
            beginMove = {
                moveStartX = panelParams?.x ?: 0
                moveStartY = panelParams?.y ?: 0
            },
            move = { dx, dy ->
                panelParams?.let { params ->
                    params.x = moveStartX + dx.toInt()
                    params.y = moveStartY + dy.toInt()
                    clamp(params)
                    panel?.let { try { windows.updateViewLayout(it, params) } catch (_: RuntimeException) {} }
                }
            },
            command = { name, query ->
                when (name) {
                    "moved" -> savePanelPosition()
                    "clipboardQueried" -> lastQueriedClipboard = query
                    "collapse" -> collapse()
                    "dismiss" -> dismiss()
                    "openApp" -> if (query != null) openInApp(query)
                    "failed" -> {
                        Toast.makeText(this, "悬浮页面加载失败，请重新打开", Toast.LENGTH_LONG).show()
                        collapse()
                    }
                }
            }).apply {
            background = background(18)
            clipToOutline = true
            elevation = dp(8).toFloat()
        }
        val area = bounds()
        val params = parameters(panelWidth(area), panelHeight(area), true).apply {
            alpha = 1f
            x = prefs.getInt("panelX", (area.width() - width) / 2)
            y = prefs.getInt("panelY", ballY.coerceAtLeast(dp(12)).coerceAtMost(area.height() - height))
        }
        clamp(params)
        try {
            windows.addView(root, params)
            panel = root
            panelParams = params
            root.start()
        } catch (_: RuntimeException) {
            root.dispose()
            panel = null
            panelParams = null
            showBall()
        }
    }

    private fun openInApp(query: String) {
        collapse()
        try {
            startActivity(Intent(this, MainActivity::class.java)
                .setAction(ACTION_QUERY).putExtra("query", query)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    or Intent.FLAG_ACTIVITY_CLEAR_TOP))
        } catch (_: RuntimeException) {
            Toast.makeText(this, "无法打开应用，请从桌面进入五味字典", Toast.LENGTH_LONG).show()
        }
    }

    private fun collapse() {
        savePanelPosition()
        panel?.dispose()
        remove(panel)
        panel = null
        panelParams = null
        showBall()
    }

    private fun installBallDrag(view: View, params: WindowManager.LayoutParams) {
        var startX = 0
        var startY = 0
        var downX = 0f
        var downY = 0f
        var moved = false
        var pointerId = MotionEvent.INVALID_POINTER_ID
        val slop = ViewConfiguration.get(overlayContext).scaledTouchSlop
        fun finish(cancelled: Boolean) {
            pointerId = MotionEvent.INVALID_POINTER_ID
            view.isPressed = false
            if (!moved && !cancelled) view.performClick()
            else if (moved) snapBallToEdge()
            if (ballAnimation == null) scheduleBallIdle()
        }
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    idleHandler.removeCallbacks(tuckBall)
                    if (checkingBallClipboard) cancelBallClipboardCheck()
                    cancelBallMotion()
                    startX = params.x; startY = params.y
                    downX = event.rawX; downY = event.rawY; moved = false
                    pointerId = event.getPointerId(0)
                    view.isPressed = true
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val index = event.findPointerIndex(pointerId)
                    if (index >= 0) {
                        // rawX/Y refer to pointer zero on older Android versions.
                        val dx = (event.getX(index) + event.rawX - event.x - downX).toInt()
                        val dy = (event.getY(index) + event.rawY - event.y - downY).toInt()
                        moved = moved || abs(dx) > slop || abs(dy) > slop
                        if (moved) {
                            view.isPressed = false
                            if (ballSleeping) {
                                wakeBall(schedule = false)
                                startX = params.x
                            }
                            params.x = startX + dx; params.y = startY + dy
                            requestBallFrame()
                        }
                    }
                    true
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    if (event.getPointerId(event.actionIndex) == pointerId) finish(cancelled = true)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (pointerId != MotionEvent.INVALID_POINTER_ID) finish(cancelled = false)
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (pointerId != MotionEvent.INVALID_POINTER_ID) finish(cancelled = true)
                    true
                }
                else -> true
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (checkingBallClipboard) cancelBallClipboardCheck()
        cancelBallMotion()
        ballParams?.let { params ->
            val area = bounds()
            val oldTravel = (ballAreaHeight - params.height).coerceAtLeast(1)
            val fraction = (params.y.toFloat() / oldTravel).coerceIn(0f, 1f)
            params.x = if (dockedLeft) 0 else (area.width() - params.width).coerceAtLeast(0)
            params.y = ((area.height() - params.height).coerceAtLeast(0) * fraction).toInt()
            ballAreaHeight = area.height()
            ball?.let { updateBallLayout(it, params) }
            saveBallPosition()
            if (!ballSleeping) scheduleBallIdle()
        }
        panelParams?.let { params ->
            val area = bounds()
            params.width = panelWidth(area)
            params.height = panelHeight(area)
            clamp(params)
            panel?.let { try { windows.updateViewLayout(it, params) } catch (_: RuntimeException) {} }
        }
    }

    private fun remove(view: View?) {
        if (view?.isAttachedToWindow == true) {
            try { windows.removeViewImmediate(view) } catch (_: RuntimeException) {}
        }
    }

    private fun fail(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        dismiss(message)
    }

    private fun dismiss(reason: String? = null) {
        idleHandler.removeCallbacks(tuckBall)
        prefs.edit().putBoolean("requested", false).putBoolean("dismissed", true)
            .putString("lastFailure", reason).apply()
        onDismissed?.invoke(reason)
        stopSelf()
    }

    override fun onDestroy() {
        checkingBallClipboard = false
        idleHandler.removeCallbacks(clipboardCheckTimeout)
        idleHandler.removeCallbacks(clipboardCheckFocused)
        idleHandler.removeCallbacks(tuckBall)
        cancelBallMotion()
        saveBallPosition()
        panel?.dispose()
        remove(panel)
        remove(ball)
        panel = null
        ball = null
        if (!prefs.getBoolean("requested", false)) updateConfiguration("{}")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
