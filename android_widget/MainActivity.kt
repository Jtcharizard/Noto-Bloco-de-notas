package com.example.bloco_personalizavel

import android.annotation.TargetApi
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.view.WindowManager
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
                } else if (call.method == "pinShortcut") {
                    result.success(
                        Build.VERSION.SDK_INT >= 26 &&
                            pinShortcut(
                                call.argument<String>("id") ?: "",
                                call.argument<String>("title") ?: "",
                            ),
                    )
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    /** Ícone de uma nota na tela inicial; abre como o widget (noto://abrir?id=). */
    @TargetApi(26)
    private fun pinShortcut(id: String, title: String): Boolean {
        if (id.isEmpty()) return false
        return try {
            val manager = getSystemService(ShortcutManager::class.java) ?: return false
            if (!manager.isRequestPinShortcutSupported) return false
            val open = Intent(
                "es.antonborri.home_widget.action.LAUNCH",
                Uri.parse("noto://abrir?id=" + Uri.encode(id)),
                this,
                MainActivity::class.java,
            )
            val label = title.ifBlank { "Nota" }
            val info = ShortcutInfo.Builder(this, "nota-$id")
                .setShortLabel(label.take(24))
                .setLongLabel(label.take(60))
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(open)
                .build()
            manager.requestPinShortcut(info, null)
        } catch (e: Exception) {
            false
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
