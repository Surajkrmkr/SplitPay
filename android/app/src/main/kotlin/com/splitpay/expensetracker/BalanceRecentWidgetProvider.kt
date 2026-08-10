package com.splitpay.expensetracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BalanceRecentWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val groupPrefs = try {
            context.getSharedPreferences("group.com.splitpay.expensetracker", Context.MODE_PRIVATE)
        } catch (_: Exception) {
            null
        }

        fun getValue(key: String, fallback: String): String {
            val fromWidgetData = try { widgetData.getString(key, null) } catch (_: Exception) { null }
            if (!fromWidgetData.isNullOrEmpty()) return fromWidgetData

            val fromGroupPrefs = try { groupPrefs?.getString(key, null) } catch (_: Exception) { null }
            if (!fromGroupPrefs.isNullOrEmpty()) return fromGroupPrefs

            return fallback
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_balance_recent).apply {
                val balance = getValue("balance", "$0.00")
                val income = getValue("total_income", "+$0.00")
                val expense = getValue("total_expense", "-$0.00")

                setTextViewText(R.id.widget_balance_text, balance)
                setTextViewText(R.id.widget_income_text, "Income $income")
                setTextViewText(R.id.widget_expense_text, "Expense $expense")

                val primaryColor = Color.parseColor("#00D09C")
                val expenseColor = Color.parseColor("#FF6B6B")

                val tx1Note = getValue("tx1_note", "")
                val tx1Amount = getValue("tx1_amount", "")
                val tx1Type = getValue("tx1_type", "")

                if (tx1Note.isNotEmpty()) {
                    setViewVisibility(R.id.widget_tx1_row, View.VISIBLE)
                    setTextViewText(R.id.widget_tx1_note, tx1Note)
                    setTextViewText(R.id.widget_tx1_amount, tx1Amount)
                    setTextColor(R.id.widget_tx1_amount, if (tx1Type == "income") primaryColor else expenseColor)
                } else {
                    setViewVisibility(R.id.widget_tx1_row, View.VISIBLE)
                    setTextViewText(R.id.widget_tx1_note, "No recent transactions")
                    setTextViewText(R.id.widget_tx1_amount, "")
                }

                val tx2Note = getValue("tx2_note", "")
                val tx2Amount = getValue("tx2_amount", "")
                val tx2Type = getValue("tx2_type", "")

                if (tx2Note.isNotEmpty()) {
                    setViewVisibility(R.id.widget_tx2_row, View.VISIBLE)
                    setTextViewText(R.id.widget_tx2_note, tx2Note)
                    setTextViewText(R.id.widget_tx2_amount, tx2Amount)
                    setTextColor(R.id.widget_tx2_amount, if (tx2Type == "income") primaryColor else expenseColor)
                } else {
                    setViewVisibility(R.id.widget_tx2_row, View.GONE)
                }

                val tx3Note = getValue("tx3_note", "")
                val tx3Amount = getValue("tx3_amount", "")
                val tx3Type = getValue("tx3_type", "")

                if (tx3Note.isNotEmpty()) {
                    setViewVisibility(R.id.widget_tx3_row, View.VISIBLE)
                    setTextViewText(R.id.widget_tx3_note, tx3Note)
                    setTextViewText(R.id.widget_tx3_amount, tx3Amount)
                    setTextColor(R.id.widget_tx3_amount, if (tx3Type == "income") primaryColor else expenseColor)
                } else {
                    setViewVisibility(R.id.widget_tx3_row, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
