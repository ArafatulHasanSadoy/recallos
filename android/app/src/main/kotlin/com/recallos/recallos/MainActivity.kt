package com.recallos.recallos

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * A [FlutterFragmentActivity] rather than a plain `FlutterActivity`.
 *
 * `local_auth` shows the system biometric prompt through `androidx.biometric`,
 * which is a `DialogFragment` and therefore needs a `FragmentActivity` to
 * attach to. With a plain `FlutterActivity` the plugin does not fail at build
 * time — it throws at the moment the user first tries to unlock, which is the
 * worst possible time to discover it.
 */
class MainActivity : FlutterFragmentActivity() {

    /**
     * Opens the phone's own security settings.
     *
     * The wallet cannot be locked until the phone itself is, and that is not
     * something an app can do on the user's behalf — it is a decision for the
     * phone's owner, made in the OS. What the app *can* do is stop being a dead
     * end about it. Without this, "Lock the wallet" is a switch that does
     * nothing when tapped and a line of grey text explaining why, which is how
     * a working feature reads as broken.
     *
     * A method channel rather than a package: this is one intent, and
     * `url_launcher` cannot express it.
     */
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSecuritySettings" -> result.success(openSecuritySettings())
                    else -> result.notImplemented()
                }
            }

        // What a bug report needs: which build, on which phone. A channel
        // rather than `package_info_plus` — three values do not justify a
        // dependency and the permission audit every new one costs.
        MethodChannel(engine.dartExecutor.binaryMessenger, APP_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> result.success(version())
                    // The phone's time zone, as an IANA id ("Asia/Dhaka"), so
                    // a 9 AM reminder means 9 AM wherever the phone is.
                    "timezone" -> result.success(java.util.TimeZone.getDefault().id)
                    // The way out when reminders are off: RecallOS's own page
                    // in Android's notification settings.
                    "openNotificationSettings" -> {
                        val intent = Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                        startActivity(intent)
                        result.success(true)
                    }
                    "restart" -> {
                        result.success(null)
                        restart()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Starts a fresh process on the launch screen.
     *
     * A restore is staged while the app runs and swapped in when the database
     * is next opened — which, to be safe, has to be a process that has never
     * opened it. Relaunching is how the user gets there without being told to
     * swipe the app away and find it again.
     */
    private fun restart() {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        window.decorView.postDelayed({
            startActivity(intent)
            Runtime.getRuntime().exit(0)
        }, 150)
    }

    private fun version(): Map<String, Any> {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "name" to (info.versionName ?: ""),
            "code" to code,
            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "android" to Build.VERSION.RELEASE,
        )
    }

    private fun openSecuritySettings(): Boolean {
        // Security first — that is where "Screen lock" lives on stock Android.
        // The top-level settings screen is the fallback, because OEM ROMs move
        // the security page around and an intent that resolves to nothing would
        // put us back to doing nothing when tapped.
        for (action in listOf(Settings.ACTION_SECURITY_SETTINGS, Settings.ACTION_SETTINGS)) {
            val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }

    private companion object {
        const val CHANNEL = "recallos/system_settings"
        const val APP_INFO_CHANNEL = "recallos/app_info"
    }
}
