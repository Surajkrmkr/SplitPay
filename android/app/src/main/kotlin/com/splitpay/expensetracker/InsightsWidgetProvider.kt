package com.splitpay.expensetracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class InsightsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        fun value(key: String, fallback: String): String {
            return try {
                val v = widgetData.getString(key, null)
                if (v.isNullOrEmpty()) fallback else v
            } catch (_: Exception) {
                fallback
            }
        }

        val currency = value("currency", "₹")
        val hasData = value("in_has_data", "false") == "true"
        val monthTotal = value("in_month_total", "0.00")
        val bucketValues = (0..4).map { i ->
            value("in_bucket$i", "0").toDoubleOrNull() ?: 0.0
        }

        val trackColor = context.getColor(R.color.w2_track)
        val fillColor = try {
            Color.parseColor(value("accent_color", "#00D09C"))
        } catch (_: Exception) {
            context.getColor(R.color.w2_accent)
        }

        val chartWidthPx = dpToPx(context, 220f)
        val chartHeightPx = dpToPx(context, 70f)
        val chartBitmap = WidgetChartRenderer.drawBarChart(
            widthPx = chartWidthPx,
            heightPx = chartHeightPx,
            values = bucketValues,
            trackColor = trackColor,
            fillColor = fillColor,
        )

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("dimeflow://widget/insights")
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_insights).apply {
                setOnClickPendingIntent(R.id.in_week_total, pendingIntent)
                setTextViewText(R.id.in_week_total, "$currency$monthTotal")
                setImageViewBitmap(R.id.in_bar_chart_image, chartBitmap)

                if (hasData) {
                    setViewVisibility(R.id.in_empty_container, View.GONE)
                } else {
                    setViewVisibility(R.id.in_empty_container, View.VISIBLE)
                    setOnClickPendingIntent(R.id.in_add_expense_pill, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
