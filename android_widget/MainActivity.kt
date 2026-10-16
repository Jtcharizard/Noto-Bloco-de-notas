package com.example.bloco_personalizavel

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Recebe texto de outros apps ("Compartilhar > Noto") e entrega para o Flutter
 * pelo canal noto/share.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = sharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noto/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val shared = sharedText(intent) ?: return
        setIntent(intent)
        pending = shared
        channel?.invokeMethod("sharedText", null)
    }

    private fun sharedText(source: Intent?): Map<String, String>? {
        val received: Intent = source ?: return null
        if (received.action != Intent.ACTION_SEND) return null
        val type: String = received.type ?: return null
        if (!type.startsWith("text/")) return null
        val text: String = received.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        val subject: String = received.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
        // Evita abrir a mesma nota de novo se o app for recriado.
        received.action = Intent.ACTION_MAIN
        return mapOf("text" to text, "subject" to subject)
    }
}
