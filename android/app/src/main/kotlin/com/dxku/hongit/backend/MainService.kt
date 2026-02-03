package com.dxku.hongit.backend

import android.content.Context
import android.util.Log
import com.dxku.hongit.backend.server.LocalHttpServer

object MainService {

    private var server: LocalHttpServer? = null

    fun start(context: Context) {
        if (server != null) return

        try {
            server = LocalHttpServer(8080, context.applicationContext)
            server?.start()
            Log.i("LocalBackend", "Server started on port 8080")
        } catch (e: Exception) {
            Log.e("LocalBackend", "Failed to start server", e)
        }
    }

    fun stop() {
        server?.stop()
        server = null
        Log.i("LocalBackend", "Server stopped")
    }
}
