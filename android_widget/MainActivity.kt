package com.example.bloco_personalizavel

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Recebe texto de outros apps ("Compartilhar > Noto") e entrega para o Flutter
 * pelo canal noto/share.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null
    private var speechChannel: MethodChannel? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var queuedSpeech: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = sharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noto/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(pending)
                    pending = null
                } else if (call.method == "setSecure") {
                    // Com o cofre aberto: sem prints e conteúdo escondido nos apps recentes.
                    if (call.arguments == true) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
        // Ler a nota em voz alta com o leitor de texto do próprio Android.
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noto/speech").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        speak(call.arguments as? String ?: "")
                        result.success(true)
                    }
                    "stop" -> {
                        queuedSpeech = null
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun speak(text: String) {
        if (text.isBlank()) return
        if (tts == null) {
            queuedSpeech = text
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    ttsReady = true
                    tts?.setLanguage(Locale.forLanguageTag("pt-BR"))
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {}
                        override fun onDone(utteranceId: String?) {
                            if (utteranceId == "noto-fim") finishedSpeaking()
                        }
                        @Deprecated("Deprecated in Java")
                        override fun onError(utteranceId: String?) {
                            finishedSpeaking()
                        }
                    })
                    queuedSpeech?.let { say(it) }
                    queuedSpeech = null
                } else {
                    tts = null
                    queuedSpeech = null
                    runOnUiThread { speechChannel?.invokeMethod("error", null) }
                }
            }
            return
        }
        if (!ttsReady) {
            queuedSpeech = text
            return
        }
        say(text)
    }

    private fun finishedSpeaking() {
        runOnUiThread { speechChannel?.invokeMethod("done", null) }
    }

    private fun say(text: String) {
        val engine = tts ?: return
        val limit = (TextToSpeech.getMaxSpeechInputLength() - 200).coerceAtLeast(500)
        val parts = mutableListOf<String>()
        for (paragraph in text.split("\n")) {
            if (paragraph.isBlank()) continue
            var rest = paragraph
            while (rest.length > limit) {
                val cut = rest.lastIndexOf(' ', limit).takeIf { it > 0 } ?: limit
                parts.add(rest.substring(0, cut))
                rest = rest.substring(cut)
            }
            parts.add(rest)
        }
        if (parts.isEmpty()) return
        parts.forEachIndexed { index, part ->
            engine.speak(
                part,
                if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD,
                null,
                if (index == parts.lastIndex) "noto-fim" else "noto-$index",
            )
        }
    }

    override fun onDestroy() {
        tts?.shutdown()
        tts = null
        super.onDestroy()
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
        // Texto direto ou um arquivo de texto (.txt, .md) compartilhado.
        val stream: Uri? = if (Build.VERSION.SDK_INT >= 33) {
            received.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            received.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        val text: String = received.getStringExtra(Intent.EXTRA_TEXT)
            ?: stream?.let { readText(it) }
            ?: return null
        val subject: String = received.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: stream?.let { fileTitle(it) }
            ?: ""
        // Evita abrir a mesma nota de novo se o app for recriado.
        received.action = Intent.ACTION_MAIN
        return mapOf("text" to text, "subject" to subject)
    }

    private fun readText(uri: Uri): String? = try {
        contentResolver.openInputStream(uri)?.use { input ->
            // Limite de 2 MB para não travar com arquivos enormes.
            input.readBytes().take(2_000_000).toByteArray().toString(Charsets.UTF_8)
        }
    } catch (e: Exception) {
        null
    }

    private fun fileTitle(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)?.replace(Regex("\\.(txt|md|markdown)$", RegexOption.IGNORE_CASE), "")
                } else {
                    null
                }
            }
    } catch (e: Exception) {
        null
    }
}
