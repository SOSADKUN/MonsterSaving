package app.savingmonster.saving_monster

import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onPause() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onPause()
    }
}
