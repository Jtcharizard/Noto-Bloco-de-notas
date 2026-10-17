package com.example.bloco_personalizavel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NotoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_widget)
            views.setTextViewText(R.id.widget_title, widgetData.getString("note_title", "Noto"))
            views.setTextViewText(R.id.widget_body, widgetData.getString("note_body", "Toque para abrir suas notas"))
            // Tocar no widget abre direto a nota mostrada nele.
            val noteId = widgetData.getString("note_id", "") ?: ""
            val uri = if (noteId.isEmpty()) Uri.parse("noto://inicio") else Uri.parse("noto://abrir?id=" + Uri.encode(noteId))
            views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
