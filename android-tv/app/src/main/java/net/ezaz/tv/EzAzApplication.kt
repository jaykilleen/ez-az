package net.ezaz.tv

import android.app.Application
import android.os.Build
import android.webkit.WebView

class EzAzApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Enable WebView debugging on debug builds (lets you inspect from
        // chrome://inspect on a host machine while developing).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT &&
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        ) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
    }
}
