package com.ultra.viewclient

/**
 * Handle events from flutter
 * Request MediaProjection permission
 *
 * Inspired by [droidVNC-NG] https://github.com/bk138/droidVNC-NG
 */

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.app.KeyguardManager
import android.content.ContextWrapper
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.IBinder
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import com.amirarcane.lockscreen.activity.EnterPinActivity
import android.view.WindowManager
import com.hjq.permissions.XXPermissions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.admin.DevicePolicyManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.PowerManager
import android.provider.Settings


@RequiresApi(VERSION_CODES.M)
class MainActivity : FlutterActivity(), SensorEventListener {
    companion object {
        var flutterMethodChannel: MethodChannel? = null
    }

    private val channelTag = "mChannel"
    private val logTag = "mMainActivity"
    private var mainService: MainService? = null
    private val REQUEST_CODE = 2023;
    private lateinit var sensorManager: SensorManager
    private var proximity: Sensor? = null
    private lateinit var powerManager: PowerManager
    private lateinit var wakeLock: PowerManager.WakeLock
    // Interaction with the DevicePolicyManager
   private lateinit var mDPM: DevicePolicyManager
   private lateinit var mAdminName: ComponentName
    
    
    @SuppressLint("InvalidWakeLockTag")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (MainService.isReady) {
            Intent(activity, MainService::class.java).also {
                bindService(it, serviceConnection, Context.BIND_AUTO_CREATE)
            }
        }
        flutterMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelTag
        )
        initFlutterChannel(flutterMethodChannel!!)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        proximity = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        powerManager = applicationContext.getSystemService(POWER_SERVICE) as PowerManager
        // Prepare to work with the DPM
        mDPM = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "TAG"
        )
    }

    override fun onResume() {
        super.onResume()
        val inputPer = InputService.isOpen
        activity.runOnUiThread {
            flutterMethodChannel?.invokeMethod(
                "on_state_changed",
                mapOf("name" to "input", "value" to inputPer.toString())
            )
        }
        proximity?.also { proximity ->
            sensorManager.registerListener(this, proximity, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun requestMediaProjection() {
        val intent = Intent(this, PermissionRequestTransparentActivity::class.java).apply {
            action = ACT_REQUEST_MEDIA_PROJECTION
        }
        startActivityForResult(intent, REQ_INVOKE_PERMISSION_ACTIVITY_MEDIA_PROJECTION)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_INVOKE_PERMISSION_ACTIVITY_MEDIA_PROJECTION && resultCode == RES_FAILED) {
            flutterMethodChannel?.invokeMethod("on_media_projection_canceled", null)
        }
        if (requestCode == REQUEST_CODE && resultCode == -1) {
            startService(Intent(this, LockscreenService::class.java))
            LockScreen.instance?.init(this,true);
            LockScreen.instance?.active();
        }
    }

    override fun onDestroy() {
        Log.e(logTag, "onDestroy")
        mainService?.let {
            unbindService(serviceConnection)
        }
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val distance = event.values[0]
        // Do something with this sensor data.
        if(distance <1f) {
            wakeLock.acquire()
        }

    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        // Do something here if sensor accuracy changes.
        wakeLock.acquire()
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d(logTag, "onServiceConnected")
            val binder = service as MainService.LocalBinder
            mainService = binder.getService()
            mAdminName = name as ComponentName
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(logTag, "onServiceDisconnected")
            mainService = null
            mAdminName = name as ComponentName
        }
    }

    @RequiresApi(VERSION_CODES.M)
    private fun initFlutterChannel(flutterMethodChannel: MethodChannel) {
        flutterMethodChannel.setMethodCallHandler { call, result ->
            // make sure result will be invoked, otherwise flutter will await forever
            when (call.method) {
                "init_service" -> {
                    Intent(activity, MainService::class.java).also {
                        bindService(it, serviceConnection, Context.BIND_AUTO_CREATE)
                    }
                    if (MainService.isReady) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    requestMediaProjection()
                    result.success(true)
                }
                "start_capture" -> {
                    mainService?.let {
                        result.success(it.startCapture())
                    } ?: let {
                        result.success(false)
                    }
                }
                "stop_service" -> {
                    Log.d(logTag, "Stop service")
                    mainService?.let {
                        it.destroy()
                        result.success(true)
                    } ?: let {
                        result.success(false)
                    }
                }
                "check_permission" -> {
                    if (call.arguments is String) {
                        result.success(XXPermissions.isGranted(context, call.arguments as String))
                    } else {
                        result.success(false)
                    }
                }
                "request_permission" -> {
                    if (call.arguments is String) {
                        requestPermission(context, call.arguments as String)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                START_ACTION -> {
                    if (call.arguments is String) {
                        startAction(context, call.arguments as String)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "check_video_permission" -> {
                    mainService?.let {
                        result.success(it.checkMediaPermission())
                    } ?: let {
                        result.success(false)
                    }
                }
                "check_service" -> {
                    Companion.flutterMethodChannel?.invokeMethod(
                        "on_state_changed",
                        mapOf("name" to "input", "value" to InputService.isOpen.toString())
                    )
                    Companion.flutterMethodChannel?.invokeMethod(
                        "on_state_changed",
                        mapOf("name" to "media", "value" to MainService.isReady.toString())
                    )
                    result.success(true)
                }
                "stop_input" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        InputService.ctx?.disableSelf()
                    }
                    InputService.ctx = null
                    Companion.flutterMethodChannel?.invokeMethod(
                        "on_state_changed",
                        mapOf("name" to "input", "value" to InputService.isOpen.toString())
                    )
                    result.success(true)
                }
                "cancel_notification" -> {
                    if (call.arguments is Int) {
                        val id = call.arguments as Int
                        mainService?.cancelNotification(id)
                    } else {
                        result.success(true)
                    }
                }
                "enable_soft_keyboard" -> {
                    // https://blog.csdn.net/hanye2020/article/details/105553780
                    if (call.arguments as Boolean) {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                    } else {
                        window.addFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                    }
                    result.success(true)

                }
                GET_START_ON_BOOT_OPT -> {
                    val prefs = getSharedPreferences(KEY_SHARED_PREFERENCES, MODE_PRIVATE)
                    result.success(prefs.getBoolean(KEY_START_ON_BOOT_OPT, false))
                }
                SET_START_ON_BOOT_OPT -> {
                    if (call.arguments is Boolean) {
                        val prefs = getSharedPreferences(KEY_SHARED_PREFERENCES, MODE_PRIVATE)
                        val edit = prefs.edit()
                        edit.putBoolean(KEY_START_ON_BOOT_OPT, call.arguments as Boolean)
                        edit.apply()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                IS_ADMIN_APP -> {
                    val _isAlreadyAdminApp = checkAdmin()
                    result.success(_isAlreadyAdminApp)
                }
                SYNC_APP_DIR_CONFIG_PATH -> {
                    if (call.arguments is String) {
                        val prefs = getSharedPreferences(KEY_SHARED_PREFERENCES, MODE_PRIVATE)
                        val edit = prefs.edit()
                        edit.putString(KEY_APP_DIR_CONFIG_PATH, call.arguments as String)
                        edit.apply()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "check_passcode" -> {
                    val checkLockedScreen = checkScreenIsLock()
                    result.success(checkLockedScreen)
                }
                "set_passcode" -> {
                    val intent = EnterPinActivity.getIntent(ContextWrapper(applicationContext), true)
                    startActivityForResult(intent, REQUEST_CODE)
                }
                "open_set_new_password" -> {
                    val intent: Intent = Intent(DevicePolicyManager.ACTION_SET_NEW_PASSWORD)
                    startActivity(intent)
                }
                "open_language_setting" -> {
                    val intent: Intent = Intent(Settings.ACTION_LOCALE_SETTINGS)
                    startActivity(intent)
                }
                "lock_screen_now" -> {
                    mDPM.lockNow()
                }
                "reset_lockscreen_password" -> {
                    mDPM.resetPassword("999999", DevicePolicyManager.RESET_PASSWORD_REQUIRE_ENTRY);
                }
                "request_admin_privillege" -> {
                    val intent: Intent = Intent()
                    intent.component = ComponentName("com.android.settings","com.android.settings.DeviceAdminSettings")
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
                "user_update" -> {
                    val idLogin = call.argument<Int>("idLogin");
                    val token = call.argument<String>("token");
                    val pref = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    idLogin?.let { pref.edit().putInt("idLogin", it).commit() }
                    token?.let { pref.edit().putString("token", it).commit() }
                    result.success(null)
                }
                "open_language_setting" -> {
                    startActivity( Intent(Settings.ACTION_LOCALE_SETTINGS));
                }
                else -> {
                    result.error("-1", "No such method", null)
                }
            }
        }
    }

    @RequiresApi(VERSION_CODES.M)
    private fun checkScreenIsLock(): Boolean {
        val keyguardManager: KeyguardManager =
            ContextWrapper(applicationContext).getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager;
        return keyguardManager.isDeviceSecure;
    }
    @RequiresApi(VERSION_CODES.M)
    private fun checkAdmin(): Boolean {
        val _isAlreadyAdminApp = mDPM.isAdminActive(mAdminName);
        if (_isAlreadyAdminApp){
            return true;
        }
        return false;
    }

}
