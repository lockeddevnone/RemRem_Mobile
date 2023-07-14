package com.ultra.viewclient

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import com.ultra.viewclient.LockScreen
import com.ultra.viewclient.TeamViewApplication

class LockWindowAccessibilityService : AccessibilityService() {
    override fun onKeyEvent(event: KeyEvent): Boolean {
        LockScreen.instance?.init(this)
        if ((application as TeamViewApplication).lockScreenShow) {
            // disable home
            if (event.keyCode == KeyEvent.KEYCODE_HOME || event.keyCode == KeyEvent.KEYCODE_DPAD_CENTER) {
                return true
            }
        }
        return super.onKeyEvent(event)
    }

    override fun onAccessibilityEvent(accessibilityEvent: AccessibilityEvent) {
        //Log.d("onAccessibilityEvent","onAccessibilityEvent");
    }

    override fun onInterrupt() {}
}