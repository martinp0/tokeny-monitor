package cz.martinpohl.tokeny.core

import java.text.NumberFormat
import java.util.Locale
import kotlin.math.abs

enum class Currency { CZK, USD }

/** Positive finite rate, otherwise the web fallback of 23.5. */
fun effectiveUsdCzk(rate: Double?): Double =
    if (rate != null && rate > 0.0 && rate.isFinite()) rate else FALLBACK_USD_CZK

/**
 * Currency picks the number style, matching the web: CZK is cs-CZ with a "Kč" suffix,
 * USD is en-US with a "$" prefix. Amounts under one hundredth of the displayed unit
 * keep four decimals so a tiny charge does not collapse to zero.
 */
fun formatMoney(usd: Double, currency: Currency, rate: Double?): String {
    val amount = if (currency == Currency.CZK) usd * effectiveUsdCzk(rate) else usd
    if (!amount.isFinite()) return if (currency == Currency.CZK) "— Kč" else "$—"
    val digits = if (amount != 0.0 && abs(amount) < 0.01) 4 else 2
    val locale = if (currency == Currency.CZK) Locale.forLanguageTag("cs-CZ") else Locale.US
    val fmt = NumberFormat.getNumberInstance(locale)
    fmt.minimumFractionDigits = digits
    fmt.maximumFractionDigits = digits
    val num = fmt.format(amount)
    return if (currency == Currency.CZK) "$num Kč" else "$$num"
}

fun formatCount(n: Long, locale: Locale): String {
    val absN = abs(n)
    val signed = if (n < 0) -1 else 1
    return when {
        absN >= 1_000_000L -> {
            val fmt = NumberFormat.getNumberInstance(locale)
            fmt.minimumFractionDigits = 1
            fmt.maximumFractionDigits = 1
            fmt.format(signed * (absN / 1_000_000.0)) + "M"
        }
        absN >= 1_000L -> {
            val fmt = NumberFormat.getIntegerInstance(locale)
            fmt.format(signed * (absN / 1_000L)) + "K"
        }
        else -> NumberFormat.getIntegerInstance(locale).format(n)
    }
}

fun formatPercent(percent: Double, locale: Locale): String {
    if (!percent.isFinite()) return "—"
    val fmt = NumberFormat.getNumberInstance(locale)
    fmt.minimumFractionDigits = 1
    fmt.maximumFractionDigits = 1
    return fmt.format(percent) + " %"
}

/** ISO-8601 timestamps show as the calendar date. Anything else is returned unchanged. */
fun displayDay(raw: String?): String {
    if (raw.isNullOrBlank()) return ""
    val day = raw.take(10)
    return if (DAY.matches(day)) day else raw
}

private val DAY = Regex("\\d{4}-\\d{2}-\\d{2}")
