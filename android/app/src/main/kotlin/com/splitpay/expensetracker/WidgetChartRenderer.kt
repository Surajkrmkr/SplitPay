package com.splitpay.expensetracker

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Canvas-drawn chart bitmaps for the home-screen widgets. RemoteViews cannot render
 * arbitrary arcs/bars directly, so these are pre-rendered to Bitmaps and set via
 * RemoteViews.setImageViewBitmap.
 */
object WidgetChartRenderer {

    /**
     * Draws a ~270° speedometer-style arc gauge that opens at the bottom.
     * [percent] is clamped to 0..100. Track is drawn first, then the filled
     * portion on top, both with round caps.
     */
    fun drawGauge(
        sizePx: Int,
        percent: Int,
        trackColor: Int,
        fillColor: Int,
    ): Bitmap {
        val size = max(sizePx, 1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val gaugeStrokeWidth = size * 0.13f
        val inset = gaugeStrokeWidth / 2f + size * 0.02f
        val rect = RectF(inset, inset, size - inset, size - inset)

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = gaugeStrokeWidth
            strokeCap = Paint.Cap.ROUND
            color = trackColor
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = gaugeStrokeWidth
            strokeCap = Paint.Cap.ROUND
            color = fillColor
        }

        val startAngle = 135f
        val totalSweep = 270f
        val clampedPercent = min(100, max(0, percent))
        val fillSweep = totalSweep * (clampedPercent / 100f)

        // Track draws only its *remaining* (untraveled) portion, starting
        // exactly where the fill arc ends, so the two arcs' round caps meet
        // at a single shared point instead of the fill's rounded tip
        // overlapping a flat mid-stroke point on a full-length track — that
        // mismatch is what produced a stray "floating dot" where the two
        // colors met.
        val remainingSweep = totalSweep - fillSweep
        if (remainingSweep > 0f) {
            canvas.drawArc(rect, startAngle + fillSweep, remainingSweep, false, trackPaint)
        }
        if (fillSweep > 0f) {
            canvas.drawArc(rect, startAngle, fillSweep, false, fillPaint)
        }

        return bitmap
    }

    /**
     * Draws a 7-bar pill-style bar chart. Each bar is drawn as a light-gray
     * full-height "track" pill with a colored fill pill on top representing
     * the value, scaled against the max of [values]. A minimum bar height is
     * always shown so bars remain visible even at 0.
     */
    fun drawBarChart(
        widthPx: Int,
        heightPx: Int,
        values: List<Double>,
        trackColor: Int,
        fillColor: Int,
    ): Bitmap {
        val width = max(widthPx, 1)
        val height = max(heightPx, 1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = trackColor
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = fillColor
        }

        val count = values.size.coerceAtLeast(1)
        val maxValue = values.maxOrNull()?.takeIf { it > 0.0 } ?: 1.0

        val slotWidth = width.toFloat() / count
        val barWidth = slotWidth * 0.42f
        val cornerRadius = barWidth / 2f
        val minBarHeight = height * 0.06f
        val maxBarHeight = height.toFloat()

        for (i in 0 until count) {
            val centerX = slotWidth * i + slotWidth / 2f
            val left = centerX - barWidth / 2f
            val right = centerX + barWidth / 2f

            // Full-height track pill.
            val trackRect = RectF(left, 0f, right, maxBarHeight)
            canvas.drawRoundRect(trackRect, cornerRadius, cornerRadius, trackPaint)

            val ratio = (values.getOrElse(i) { 0.0 } / maxValue).coerceIn(0.0, 1.0)
            val barHeight = max(minBarHeight, (maxBarHeight * ratio).toFloat())
            val fillRect = RectF(left, maxBarHeight - barHeight, right, maxBarHeight)
            canvas.drawRoundRect(fillRect, cornerRadius, cornerRadius, fillPaint)
        }

        return bitmap
    }
}

/** Simple dp -> px helper for use inside AppWidgetProvider code. */
fun dpToPx(context: android.content.Context, dp: Float): Int {
    val density = context.resources.displayMetrics.density
    return (dp * density).roundToInt()
}
