package top.jtmonster.jhentai

import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterFragmentActivity() {
    private var interceptVolumeEvent = false;

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "volume.event.intercept"
        ).setMethodCallHandler { call, result ->
            if (call.method == "set") {
                val value = call.arguments<Boolean>()
                if (value != null) {
                    interceptVolumeEvent = value
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation to avoid
            // a flicker before the similar frame is drawn in Flutter.
            splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
        }

        super.onCreate(savedInstanceState)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!interceptVolumeEvent) {
            return super.onKeyDown(keyCode, event)
        }

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            return true
        }
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            return true
        }

        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (!interceptVolumeEvent) {
            return super.onKeyUp(keyCode, event)
        }

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            return true
        }
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            return true
        }

        return super.onKeyUp(keyCode, event)
    }
}
