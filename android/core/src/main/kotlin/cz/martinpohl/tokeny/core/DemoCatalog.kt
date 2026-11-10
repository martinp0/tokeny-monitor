package cz.martinpohl.tokeny.core

/**
 * Bundled sample summaries. They are parsed with the same parser as a server payload
 * and are only shown behind an explicit sample label. They are not an account.
 */
enum class DemoVariant { PRO, FREE, EMPTY }

class DemoCatalog {
    fun json(variant: DemoVariant): String = when (variant) {
        DemoVariant.PRO -> proJson()
        DemoVariant.FREE -> FREE_JSON
        DemoVariant.EMPTY -> EMPTY_JSON
    }

    fun load(variant: DemoVariant): UsageSummary = UsageSummaryParser.parse(json(variant))
}

internal fun scaledSampleDays(target: Double = 38.2): List<Double> {
    val raw = (1..30).map { i -> ((i * 37) % 23) / 10.0 }
    val sum = raw.sum()
    val scaled = raw.map { kotlin.math.round(it / sum * target * 10_000.0) / 10_000.0 }.toMutableList()
    val drift = kotlin.math.round((target - scaled.sum()) * 10_000.0) / 10_000.0
    scaled[scaled.lastIndex] = kotlin.math.round((scaled.last() + drift) * 10_000.0) / 10_000.0
    return scaled
}

private fun proJson(): String {
    val days = scaledSampleDays()
    val daily = days.mapIndexed { index, cost ->
        val day = (index + 1).toString().padStart(2, '0')
        """{"date":"2026-10-$day","cost_usd":${jsonNumber(cost)}}"""
    }.joinToString(",")
    val today = days.last()
    return """
        {
          "version": 1,
          "plan": "pro",
          "generated_at": "2026-10-30T08:00:00.000Z",
          "tz": "Europe/Prague",
          "today": { "cost_usd": ${jsonNumber(today)}, "tokens": 188000, "requests": 41 },
          "month": { "cost_usd": 38.2, "tokens": 9800000, "requests": 2140, "key": "2026-10" },
          "previous_month": { "cost_usd": 41.7, "tokens": 10100000, "requests": 2311, "key": "2026-09" },
          "forecast_month_usd": 47.4,
          "forecast": {
            "low_usd": 42.1,
            "high_usd": 53.8,
            "confidence": "high",
            "days_observed": 28,
            "method": "weighted_run_rate"
          },
          "budget": { "monthly_usd": 50, "threshold_pct": 80, "enabled": true },
          "usd_czk": { "rate": 23.4, "date": "2026-10-29" },
          "daily": [$daily],
          "top_models": [
            { "name": "anthropic/claude-sonnet-4.5", "cost_usd": 18.6 },
            { "name": "openai/gpt-5-mini", "cost_usd": 12.4 },
            { "name": "google/gemini-2.5-flash", "cost_usd": 7.2 }
          ],
          "providers": [
            { "name": "Anthropic", "cost_usd": 22.4 },
            { "name": "OpenAI", "cost_usd": 11.1 },
            { "name": "Google", "cost_usd": 4.7 }
          ],
          "last_activity_at": "2026-10-30T07:40:00Z"
        }
    """.trimIndent()
}

private fun jsonNumber(n: Double): String {
    val text = String.format(java.util.Locale.US, "%.4f", n).trimEnd('0').trimEnd('.')
    return if (text.isEmpty() || text == "-") "0" else text
}

private val FREE_JSON = """
    {
      "version": 1,
      "plan": "free",
      "generated_at": "2026-10-30T08:00:00Z",
      "tz": "Europe/Prague",
      "today": { "cost_usd": 0.4, "tokens": 22000, "requests": 6 },
      "month": { "cost_usd": 3.5, "tokens": 120000, "requests": 40, "key": "2026-10" },
      "previous_month": null,
      "forecast_month_usd": null,
      "forecast": null,
      "budget": null,
      "usd_czk": { "rate": 23.4, "date": "2026-10-29" },
      "daily": [
        { "date": "2026-10-28", "cost_usd": 1.2 },
        { "date": "2026-10-29", "cost_usd": 1.9 },
        { "date": "2026-10-30", "cost_usd": 0.4 }
      ],
      "top_models": [ { "name": "openrouter/sample-mini", "cost_usd": 3.5 } ],
      "providers": [ { "name": "OpenRouter", "cost_usd": 3.5 } ],
      "last_activity_at": "2026-10-30T07:10:00Z"
    }
""".trimIndent()

private val EMPTY_JSON = """
    {
      "version": 1,
      "plan": "free",
      "generated_at": "2026-10-30T08:00:00Z",
      "tz": "Europe/Prague",
      "today": { "cost_usd": 0, "tokens": 0, "requests": 0 },
      "month": { "cost_usd": 0, "tokens": 0, "requests": 0, "key": "2026-10" },
      "previous_month": null,
      "forecast_month_usd": null,
      "forecast": null,
      "budget": null,
      "usd_czk": null,
      "daily": [],
      "top_models": [],
      "providers": [],
      "last_activity_at": null
    }
""".trimIndent()
