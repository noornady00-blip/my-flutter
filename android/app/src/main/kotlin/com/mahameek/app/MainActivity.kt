package com.mahameek.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mahameek.app/settings"

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    try {
                        val intent = Intent()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!channelId.isNullOrEmpty()) {
                                intent.action = Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS
                                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                intent.putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                            } else {
                                intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            intent.data = Uri.fromParts("package", packageName, null)
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                "clearLaunchIntent" -> {
                    try {
                        // Clear notification extras from the current activity intent so subsequent normal launches don't re-trigger
                        intent?.replaceExtras(null as Bundle?)
                        val emptyIntent = Intent(Intent.ACTION_MAIN)
                        emptyIntent.addCategory(Intent.CATEGORY_LAUNCHER)
                        intent = emptyIntent
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

