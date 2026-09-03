package com.example.bloco_personalizavel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NotoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_widget)
            views.setTextViewText(R.id.widget_title, widgetData.getString("note_title", "Noto"))
            views.setTextViewText(R.id.widget_body, widgetData.getString("note_body", "Toca para abrir tuas notas"))
            views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
