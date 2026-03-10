package com.dungeoncaster

import android.annotation.SuppressLint
import android.os.Bundle
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.mediarouter.app.MediaRouteButton
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var castContext: CastContext
    private val serverUrl = "http://192.168.1.109:4000" // Configure via Settings in future
    private var currentSessionId: String? = null

    private val sessionManagerListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) {
            launchReceiver(session)
        }
        override fun onSessionEnded(session: CastSession, error: Int) {}
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {}
        override fun onSessionStartFailed(session: CastSession, error: Int) {}
        override fun onSessionEnding(session: CastSession) {}
        override fun onSessionResuming(session: CastSession, sessionId: String) {}
        override fun onSessionStarting(session: CastSession) {}
        override fun onSessionSuspended(session: CastSession, reason: Int) {}
        override fun onSessionResumeFailed(session: CastSession, error: Int) {}
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        castContext = CastContext.getSharedInstance(this)

        val castButton = findViewById<MediaRouteButton>(R.id.media_route_menu_item)
        CastButtonFactory.setUpMediaRouteButton(applicationContext, castButton)

        val gestureZone = findViewById<View>(R.id.cast_gesture_zone)
        gestureZone.setOnTouchListener(TripleTapListener { castButton.performClick() })

        webView = findViewById(R.id.webview)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                if (url.startsWith(serverUrl)) {
                    // Extract session_id from URL if navigating to a session
                    val match = Regex("/sessions/([^/]+)/run").find(url)
                    currentSessionId = match?.groupValues?.get(1)
                    return false // load in WebView
                }
                return false
            }
        }
        webView.loadUrl(serverUrl)
    }

    override fun onResume() {
        super.onResume()
        castContext.sessionManager.addSessionManagerListener(sessionManagerListener, CastSession::class.java)
    }

    override fun onPause() {
        super.onPause()
        castContext.sessionManager.removeSessionManagerListener(sessionManagerListener, CastSession::class.java)
    }

    private inner class TripleTapListener(private val onTripleTap: () -> Unit) : View.OnTouchListener {
        private var tapCount = 0
        private var lastTapTime = 0L
        private val windowMs = 600L

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, event: MotionEvent): Boolean {
            if (event.actionMasked != MotionEvent.ACTION_DOWN) return false
            val now = SystemClock.elapsedRealtime()
            if (now - lastTapTime > windowMs) tapCount = 0
            lastTapTime = now
            tapCount++
            if (tapCount >= 3) {
                tapCount = 0
                onTripleTap()
            }
            return true
        }
    }

    private fun launchReceiver(session: CastSession) {
        val sid = currentSessionId ?: return
        // Send session_id to the receiver via a custom Cast namespace.
        // The receiver listens for this message to know which Phoenix channel to join.
        session.sendMessage(
            "urn:x-cast:com.dungeoncaster",
            """{"session_id":"$sid"}"""
        )
    }
}
