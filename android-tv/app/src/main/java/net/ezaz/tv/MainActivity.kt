package net.ezaz.tv

import android.annotation.SuppressLint
import android.graphics.Color
import android.net.ConnectivityManager
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback

class MainActivity : ComponentActivity() {

    private lateinit var webView: WebView
    private lateinit var errorView: View

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Build the layout in code (no XML inflation, smallest possible APK)
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0a0a12"))
        }

        webView = WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0a0a12"))
            isFocusable = true
            isFocusableInTouchMode = true
        }

        configureWebView()

        errorView = buildErrorView()
        errorView.visibility = View.GONE

        container.addView(webView)
        container.addView(errorView)
        setContentView(container)

        enterImmersiveMode()
        loadUrl()

        // Back button: navigate back in WebView history if possible,
        // otherwise let the system close the app.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebView() {
        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_DEFAULT
            loadsImagesAutomatically = true
            useWideViewPort = true
            loadWithOverviewMode = true
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            allowFileAccess = false
            allowContentAccess = false
            // Identify ourselves so analytics/logs can tell us apart from a generic browser
            userAgentString = "$userAgentString EzAzTv/1.0"
        }

        webView.webChromeClient = WebChromeClient()

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                // Keep all navigation inside the WebView (no external browser)
                val host = request.url.host ?: return false
                return !(host.endsWith("ez-az.net") || host == "localhost")
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                // Only surface errors for the main document, not sub-resources.
                if (request.isForMainFrame) {
                    showError()
                }
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (errorView.visibility == View.VISIBLE) {
                    hideError()
                }
            }
        }
    }

    private fun loadUrl() {
        if (isOnline()) {
            hideError()
            webView.loadUrl(URL)
        } else {
            showError()
        }
    }

    private fun isOnline(): Boolean {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = cm.activeNetworkInfo ?: return false
        return activeNetwork.isConnected
    }

    private fun buildErrorView(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0a0a12"))
            setPadding(120, 80, 120, 80)
        }

        val title = TextView(this).apply {
            text = getString(R.string.error_title)
            textSize = 48f
            setTextColor(Color.parseColor("#00ffc8"))
        }

        val body = TextView(this).apply {
            text = getString(R.string.error_body)
            textSize = 22f
            setTextColor(Color.parseColor("#cfe6f0"))
            gravity = android.view.Gravity.CENTER
            setPadding(0, 40, 0, 60)
        }

        val retry = Button(this).apply {
            text = getString(R.string.error_retry)
            textSize = 22f
            setTextColor(Color.parseColor("#0a0a12"))
            setBackgroundColor(Color.parseColor("#00ffc8"))
            setPadding(80, 30, 80, 30)
            isFocusable = true
            isFocusableInTouchMode = true
            setOnClickListener { loadUrl() }
        }

        layout.addView(title)
        layout.addView(body)
        layout.addView(retry)
        return layout
    }

    private fun showError() {
        webView.visibility = View.GONE
        errorView.visibility = View.VISIBLE
        errorView.requestFocus()
    }

    private fun hideError() {
        errorView.visibility = View.GONE
        webView.visibility = View.VISIBLE
        webView.requestFocus()
    }

    /**
     * Hide system bars and let the WebView use the full TV display.
     */
    @Suppress("DEPRECATION")
    private fun enterImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(android.view.WindowInsets.Type.statusBars()
                        or android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterImmersiveMode()
    }

    override fun onPause() {
        webView.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
    }

    override fun onDestroy() {
        webView.stopLoading()
        webView.destroy()
        super.onDestroy()
    }

    /**
     * Forward the Android TV remote's MEDIA_PLAY_PAUSE / MENU keys
     * as keyboard events the web app already understands.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                webView.dispatchKeyEvent(
                    KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_SPACE)
                )
                true
            }
            KeyEvent.KEYCODE_MENU -> {
                webView.dispatchKeyEvent(
                    KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ESCAPE)
                )
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    companion object {
        const val URL = "https://ez-az.net/tv"
    }
}
