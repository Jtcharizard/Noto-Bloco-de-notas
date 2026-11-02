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
            NotoWidgetStyle.background(views, widgetData, R.id.summary_bg)
            NotoWidgetStyle.tag(views, widgetData, R.id.summary_tag)
            NotoWidgetStyle.button(views, widgetData, R.id.summary_note_bg, R.id.summary_note_text)
            NotoWidgetStyle.button(views, widgetData, R.id.summary_list_bg, R.id.summary_list_text, soft = true)
            views.setTextViewText(R.id.summary_count, widgetData.getString("summary_count", "0"))
            views.setTextViewText(R.id.summary_label, widgetData.getString("summary_label", "tarefas a fazer"))
            views.setTextViewText(R.id.summary_next, widgetData.getString("summary_next", "Sem lembretes"))
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
