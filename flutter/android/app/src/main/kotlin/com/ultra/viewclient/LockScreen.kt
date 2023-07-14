package com.ultra.viewclient

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Settings
import com.ultra.viewclient.LockWindowAccessibilityService
import com.ultra.viewclient.LockscreenService
import com.ultra.viewclient.LockScreen

class LockScreen {
    var context: Context? = null
    var disableHomeButton = false
    var prefs: SharedPreferences? = null
    fun init(context: Context?) {
        this.context = context
    }

    fun init(context: Context?, disableHomeButton: Boolean) {
        this.context = context
        this.disableHomeButton = disableHomeButton
    }

    private fun showSettingAccesability() {
        if (!isMyServiceRunning(LockWindowAccessibilityService::class.java)) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            context!!.startActivity(intent)
        }
    }

    fun active() {
        if (disableHomeButton) {
            showSettingAccesability()
        }
        if (context != null) {
            context!!.startService(Intent(context, LockscreenService::class.java))
        }
    }

    fun deactivate() {
        if (context != null) {
            context!!.stopService(Intent(context, LockscreenService::class.java))
        }
    }

    val isActive: Boolean
        get() = if (context != null) {
            isMyServiceRunning(LockscreenService::class.java)
        } else {
            false
        }

    private fun isMyServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = context!!.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    companion object {
        private var singleton: LockScreen? = null
        val instance: LockScreen?
            get() {
                if (singleton == null) {
                    singleton = LockScreen()
                }
                return singleton
            }
    }
}