package com.dxku.hongit

import android.os.Bundle
import com.dxku.hongit.backend.MainService
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MainService.start(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        MainService.stop()
    }
}
