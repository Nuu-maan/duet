package dev.duet.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DrawingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val bitmap = widgetData.getString("drawing", null)?.let { encoded ->
            runCatching {
                val bytes = Base64.decode(encoded, Base64.DEFAULT)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }.getOrNull()
        }
        val open = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("duet://draw"),
        )
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.drawing_widget)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.drawing, bitmap)
            }
            views.setViewVisibility(R.id.drawing, if (bitmap != null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.empty, if (bitmap != null) View.GONE else View.VISIBLE)
            views.setOnClickPendingIntent(R.id.root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
