package com.example.bloco_personalizavel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget 2x2: tarefas que faltam, próximo lembrete e atalhos de nota e lista. */
class NotoSummaryWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_summary_widget)
            views.setTextViewText(R.id.summary_count, widgetData.getString("summary_count", "0"))
            views.setTextViewText(R.id.summary_label, widgetData.getString("summary_label", "tarefas a fazer"))
            views.setTextViewText(R.id.summary_next, widgetData.getString("summary_next", "Toque para abrir o Noto"))
            views.setOnClickPendingIntent(
                R.id.summary_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("noto://tarefas")),
            )
            views.setOnClickPendingIntent(
                R.id.summary_new_note,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("noto://nova-nota")),
            )
            views.setOnClickPendingIntent(
                R.id.summary_new_list,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("noto://nova-lista")),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
