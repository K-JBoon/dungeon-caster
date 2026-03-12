package com.dungeoncaster

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.JavascriptInterface
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
    private lateinit var castButton: MediaRouteButton
    private val serverUrl = "http://192.168.1.109:4000" // Configure via Settings in future
    private var currentSessionId: String? = null
    private var castChooserReady = false

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

        castButton = findViewById(R.id.media_route_menu_item)
        CastButtonFactory.setUpMediaRouteButton(applicationContext, castButton)
        castChooserReady = true

        webView = findViewById(R.id.webview)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.addJavascriptInterface(AndroidCastBridge(), "AndroidCast")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                if (url.startsWith(serverUrl)) {
                    updateCurrentSessionId(url)
                    return false
                }

                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                return true
            }

            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                updateCurrentSessionId(url)
            }

            override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
                super.doUpdateVisitedHistory(view, url, isReload)
                updateCurrentSessionId(url)
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

    private inner class AndroidCastBridge {
        @JavascriptInterface
        fun isAvailable(): Boolean = castChooserReady

        @JavascriptInterface
        fun openChooser() {
            if (!castChooserReady) return

            runOnUiThread {
                castButton.performClick()
            }
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

    private fun updateCurrentSessionId(url: String?) {
        val sessionPath = url ?: run {
            currentSessionId = null
            return
        }

        val match = Regex("/sessions/([^/]+)/run").find(sessionPath)
        currentSessionId = match?.groupValues?.get(1)
    }
}
