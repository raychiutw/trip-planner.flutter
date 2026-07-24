package com.raychiu.tripline

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "tripline/notification-permission"
    private val requestCode = 7301
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var permissionChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        permissionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { channel -> channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(notificationPermissionStatus())
                "request" -> requestNotificationPermission(result)
                "openSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } }
    }

    private fun notificationPermissionStatus(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                return if (notificationsEnabled()) "granted" else "denied"
            }
            val requested = getPreferences(MODE_PRIVATE)
                .getBoolean("notification_permission_requested", false)
            return if (requested) "denied" else "notDetermined"
        }
        return if (notificationsEnabled()) "granted" else "denied"
    }

    private fun notificationsEnabled(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.N ||
            getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(notificationPermissionStatus())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "通知權限要求進行中", null)
            return
        }
        getPreferences(MODE_PRIVATE)
            .edit()
            .putBoolean("notification_permission_requested", true)
            .apply()
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            requestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != this.requestCode) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(notificationPermissionStatus())
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pendingPermissionResult?.error(
            "ACTIVITY_DETACHED",
            "通知權限要求因畫面關閉而中止",
            null,
        )
        pendingPermissionResult = null
        permissionChannel?.setMethodCallHandler(null)
        permissionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun openNotificationSettings() {
        startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
        )
    }
}
