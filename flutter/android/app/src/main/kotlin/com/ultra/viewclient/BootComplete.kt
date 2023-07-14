package com.ultra.viewclient

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.WINDOW_SERVICE
import android.content.Intent
import android.graphics.PixelFormat
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.core.content.ContextCompat.startActivity
import com.amirarcane.lockscreen.activity.EnterPinActivity



class BootComplete : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action;

        if (action.equals(Intent.ACTION_SCREEN_OFF) ) {
            start_lockscreen(context)
        }
        if (action.equals(Intent.ACTION_SCREEN_ON) ) {
        }
    }

    // Display lock screen
    private fun start_lockscreen(context: Context) {
        val mIntent = Intent(context, EnterPinActivity::class.java)
        mIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(mIntent)
    }
}

