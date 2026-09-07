package com.recallos.recallos

import android.content.Intent
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
    }
}
