package com.splitpay.expensetracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RecentTransactionsWidgetProvider : HomeWidgetProvider() {
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
        val hasData = value("rt_has_data", "false") == "true"
        val netWeekRaw = value("rt_net_week", "0.00")

        val netAmount = netWeekRaw.toDoubleOrNull() ?: 0.0
        val netFormatted = when {
            netAmount > 0 -> "+$currency${netWeekRaw.removePrefix("+")}"
            netAmount < 0 -> "-$currency${netWeekRaw.removePrefix("-")}"
            else -> "$currency$netWeekRaw"
        }

        val incomeColor = context.getColor(R.color.w2_accent)
        val expenseColor = context.getColor(R.color.w2_expense)
        val primaryColor = context.getColor(R.color.w2_text_primary)

        data class Tx(val note: String, val amount: String, val type: String)

        val txs = (1..3).map { i ->
            Tx(
                note = value("tx${i}_note", ""),
                amount = value("tx${i}_amount", ""),
                type = value("tx${i}_type", ""),
            )
        }.filter { it.note.isNotEmpty() }

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("dimeflow://widget/transactions")
        )

        val rowIds = listOf(
            Triple(R.id.rt_tx1_row, R.id.rt_tx1_note, R.id.rt_tx1_amount),
            Triple(R.id.rt_tx2_row, R.id.rt_tx2_note, R.id.rt_tx2_amount),
            Triple(R.id.rt_tx3_row, R.id.rt_tx3_note, R.id.rt_tx3_amount),
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_recent_transactions).apply {
                setOnClickPendingIntent(R.id.rt_net_week, pendingIntent)
                setTextViewText(R.id.rt_net_week, netFormatted)
                setTextColor(
                    R.id.rt_net_week,
                    when {
                        netAmount > 0 -> incomeColor
                        netAmount < 0 -> expenseColor
                        else -> primaryColor
                    }
                )

                if (hasData && txs.isNotEmpty()) {
                    setViewVisibility(R.id.rt_empty_container, View.GONE)
                    setViewVisibility(R.id.rt_tx_container, View.VISIBLE)

                    rowIds.forEachIndexed { index, (rowId, noteId, amountId) ->
                        val tx = txs.getOrNull(index)
                        if (tx != null) {
                            setViewVisibility(rowId, View.VISIBLE)
                            setTextViewText(noteId, tx.note)
                            setTextViewText(amountId, tx.amount)
                            setTextColor(amountId, if (tx.type == "income") incomeColor else expenseColor)
                        } else {
                            setViewVisibility(rowId, View.GONE)
                        }
                    }
                } else {
                    setViewVisibility(R.id.rt_tx_container, View.GONE)
                    setViewVisibility(R.id.rt_empty_container, View.VISIBLE)
                    setOnClickPendingIntent(R.id.rt_add_expense_pill, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
