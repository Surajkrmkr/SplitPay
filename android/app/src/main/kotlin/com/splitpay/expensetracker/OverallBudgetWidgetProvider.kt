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

class OverallBudgetWidgetProvider : HomeWidgetProvider() {
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
        val hasData = value("ob_has_data", "false") == "true"
        val periodLabel = value("ob_period_label", "")
        val percent = value("ob_percent", "0").toIntOrNull() ?: 0
        val spent = value("ob_spent", "0")
        val limit = value("ob_limit", "0")
        val remaining = value("ob_remaining", "0")

        val trackColor = context.getColor(R.color.w2_track)
        val fillColor = try {
            Color.parseColor(value("accent_color", "#00D09C"))
        } catch (_: Exception) {
            context.getColor(R.color.w2_accent)
        }

        val gaugeSizePx = dpToPx(context, 110f)
        val gaugeBitmap = WidgetChartRenderer.drawGauge(
            sizePx = gaugeSizePx,
            percent = percent,
            trackColor = trackColor,
            fillColor = fillColor,
        )

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("dimeflow://widget/budget")
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_overall_budget).apply {
                setOnClickPendingIntent(R.id.ob_period_label, pendingIntent)
                setTextViewText(R.id.ob_period_label, periodLabel)
                setTextViewText(R.id.ob_spent_caption, "SPENT: $percent%")

                if (hasData) {
                    setViewVisibility(R.id.ob_empty_container, View.GONE)
                    setViewVisibility(R.id.ob_gauge_image, View.VISIBLE)
                    setViewVisibility(R.id.ob_gauge_center_text, View.VISIBLE)
                    setViewVisibility(R.id.ob_bottom_row, View.VISIBLE)

                    setImageViewBitmap(R.id.ob_gauge_image, gaugeBitmap)
                    setTextViewText(R.id.ob_remaining_amount, "$currency$remaining")
                    setTextViewText(R.id.ob_spent_text, "$currency$spent")
                    setTextViewText(R.id.ob_limit_text, "$currency$limit")
                } else {
                    setViewVisibility(R.id.ob_gauge_image, View.GONE)
                    setViewVisibility(R.id.ob_gauge_center_text, View.GONE)
                    setViewVisibility(R.id.ob_bottom_row, View.GONE)
                    setViewVisibility(R.id.ob_empty_container, View.VISIBLE)
                    setOnClickPendingIntent(R.id.ob_add_budget_pill, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
