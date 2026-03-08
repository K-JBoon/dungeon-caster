package com.campaigntool

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.Menu
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var castContext: CastContext
    private val serverUrl = "http://192.168.1.100:4000" // Configure via Settings in future
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
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        setSupportActionBar(findViewById(R.id.toolbar))

        castContext = CastContext.getSharedInstance(this)

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

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        CastButtonFactory.setUpMediaRouteButton(applicationContext, menu, R.id.media_route_menu_item)
        return true
    }

    override fun onResume() {
        super.onResume()
        castContext.sessionManager.addSessionManagerListener(sessionManagerListener, CastSession::class.java)
    }

    override fun onPause() {
        super.onPause()
        castContext.sessionManager.removeSessionManagerListener(sessionManagerListener, CastSession::class.java)
    }

    private fun launchReceiver(session: CastSession) {
        val sid = currentSessionId ?: return
        // The Cast SDK already launched the receiver app via App ID.
        // The receiver page connects to Phoenix directly via WebSocket.
        // Nothing more needed — receiver self-manages via Phoenix Channel.
        @Suppress("UNUSED_VARIABLE")
        val receiverUrl = "$serverUrl/receiver?session_id=$sid"
    }
}
