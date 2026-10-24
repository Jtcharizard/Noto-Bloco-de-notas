package com.example.bloco_personalizavel

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Locale

/** Cores dos widgets: seguem a cor de destaque escolhida no app. */
object NotoWidgetStyle {
    private fun color(data: SharedPreferences, key: String, fallback: Long): Int =
        (data.getString(key, null)?.toLongOrNull() ?: fallback).toInt()

    fun background(views: RemoteViews, data: SharedPreferences, imageId: Int) {
        val bg = color(data, "widget_bg", 0xF21C1430)
        views.setInt(imageId, "setColorFilter", bg or 0xFF000000.toInt())
        views.setInt(imageId, "setImageAlpha", Color.alpha(bg))
    }

    fun button(views: RemoteViews, data: SharedPreferences, imageId: Int, textId: Int, soft: Boolean = false) {
        val accent = color(data, "widget_accent", 0xFF7C3AED)
        views.setInt(imageId, "setColorFilter", accent or 0xFF000000.toInt())
        views.setInt(imageId, "setImageAlpha", if (soft) 70 else 255)
        views.setTextColor(
            textId,
            if (soft) Color.WHITE else color(data, "widget_on_accent", 0xFFFFFFFF),
        )
    }

    fun tag(views: RemoteViews, data: SharedPreferences, vararg textIds: Int) {
        val soft = color(data, "widget_accent_soft", 0xFFC4A6FF)
        textIds.forEach { views.setTextColor(it, soft) }
    }

    fun open(context: Context, uri: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}

private val weekdaysPt = arrayOf(
    "DOMINGO", "SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO",
)
private val monthsPt = arrayOf(
    "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
    "agosto", "setembro", "outubro", "novembro", "dezembro",
)

/** Widget 2x2 "Hoje": a data grande e um toque para a nota do dia. */
class NotoTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Calendar.getInstance()
        val key = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH),
        )
        val written = widgetData.getString("today_note_day", "") == key
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_today_widget)
            NotoWidgetStyle.background(views, widgetData, R.id.today_bg)
            NotoWidgetStyle.tag(views, widgetData, R.id.today_weekday)
            NotoWidgetStyle.button(views, widgetData, R.id.today_button_bg, R.id.today_button_text)
            views.setTextViewText(R.id.today_weekday, weekdaysPt[now.get(Calendar.DAY_OF_WEEK) - 1])
            views.setTextViewText(R.id.today_day, now.get(Calendar.DAY_OF_MONTH).toString())
            views.setTextViewText(R.id.today_month, "de " + monthsPt[now.get(Calendar.MONTH)])
            views.setTextViewText(
                R.id.today_button_text,
                if (written) "Abrir nota de hoje" else "✎  Escrever hoje",
            )
            views.setOnClickPendingIntent(R.id.today_root, NotoWidgetStyle.open(context, "noto://hoje"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** Widget 2x2 "Tarefas": as próximas tarefas que faltam fazer. */
class NotoTasksWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_tasks_widget)
            NotoWidgetStyle.background(views, widgetData, R.id.tasks_bg)
            NotoWidgetStyle.tag(views, widgetData, R.id.tasks_tag, R.id.tasks_count)
            views.setTextViewText(R.id.tasks_count, widgetData.getString("tasks_count", "0"))
            views.setTextViewText(
                R.id.tasks_list,
                widgetData.getString("tasks_preview", "Nada pendente. Tudo feito! 🎉"),
            )
            views.setOnClickPendingIntent(R.id.tasks_root, NotoWidgetStyle.open(context, "noto://tarefas"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** Widget 2x2 "Atalhos": nova nota, nova lista, ditar e buscar. */
class NotoActionsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val tiles = listOf(
            Triple(R.id.action_note, R.id.action_note_bg, R.id.action_note_text) to "noto://nova-nota",
            Triple(R.id.action_list, R.id.action_list_bg, R.id.action_list_text) to "noto://nova-lista",
            Triple(R.id.action_dictate, R.id.action_dictate_bg, R.id.action_dictate_text) to "noto://ditar",
            Triple(R.id.action_search, R.id.action_search_bg, R.id.action_search_text) to "noto://buscar",
        )
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.noto_actions_widget)
            NotoWidgetStyle.background(views, widgetData, R.id.actions_bg)
            tiles.forEachIndexed { index, (ids, uri) ->
                NotoWidgetStyle.button(views, widgetData, ids.second, ids.third, soft = index > 0)
                views.setOnClickPendingIntent(ids.first, NotoWidgetStyle.open(context, uri))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
