package com.example.bloco_personalizavel

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Widget "Nova nota": abre o Noto direto numa nota em branco. */
class NotoQuickWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val pending = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("noto://nova-nota"),
            )
            val views = RemoteViews(context.packageName, R.layout.noto_quick_widget)
            views.setOnClickPendingIntent(R.id.quick_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
