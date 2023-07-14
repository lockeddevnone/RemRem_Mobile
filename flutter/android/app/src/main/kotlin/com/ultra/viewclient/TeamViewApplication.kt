package com.ultra.viewclient

import android.app.Application

class TeamViewApplication : Application() {
    @JvmField
    var lockScreenShow = false
    var notificationId = 1989
    override fun onCreate() {
        super.onCreate()
    }
}