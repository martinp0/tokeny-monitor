package cz.martinpohl.tokeny.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class UsageSummaryParserTest {
    @Test
    fun parsesProContractIncludingForecastBand() {
        val summary = UsageSummaryParser.parse(PRO_FIXTURE)
        assertEquals(1, summary.version)
        assertEquals(UsageSummary.Plan.PRO, summary.plan)
        assertEquals("Europe/Prague", summary.timeZone)
        assertEquals(38.2, summary.month.costUsd, 0.0001)
        assertEquals("2026-10", summary.month.key)
        assertEquals(41.7, summary.previousMonth!!.costUsd, 0.0001)
        assertEquals(47.4, summary.forecastMonthUsd!!, 0.0001)
        assertEquals(42.1, summary.forecast!!.lowUsd!!, 0.0001)
        assertEquals(53.8, summary.forecast.highUsd!!, 0.0001)
        assertEquals("high", summary.forecast.confidence)
        assertEquals(28, summary.forecast.daysObserved)
        assertEquals("weighted_run_rate", summary.forecast.method)
        assertEquals(50.0, summary.budget!!.monthlyUsd, 0.0001)
        assertEquals(80.0, summary.budget.thresholdPercent, 0.0001)
        assertEquals(true, summary.budget.enabled)
        assertEquals(23.41, summary.usdCzk!!.rate, 0.0001)
        assertEquals("Anthropic", summary.providers.first().name)
        assertEquals(2, summary.daily.size)
    }

    @Test
    fun freeSummaryOmitsProFields() {
        val summary = UsageSummaryParser.parse(FREE_FIXTURE)
        assertEquals(UsageSummary.Plan.FREE, summary.plan)
        assertNull(summary.previousMonth)
        assertNull(summary.forecastMonthUsd)
        assertNull(summary.forecast)
        assertNull(summary.budget)
        assertNull(summary.usdCzk)
        assertEquals(true, summary.daily.isEmpty())
        assertNull(summary.lastActivityAt)
    }

    @Test
    fun missingPlanDefaultsToProForLegacyPersonalTokenPayloads() {
        val summary = UsageSummaryParser.parse(LEGACY_FIXTURE)
        assertEquals(UsageSummary.Plan.PRO, summary.plan)
        assertEquals(1, summary.version)
        assertEquals("Europe/Prague", summary.timeZone)
        assertEquals(emptyList<DailySpend>(), summary.daily)
        assertNull(summary.budget)
        assertNull(summary.usdCzk!!.date)
    }

    @Test
    fun rejectsMalformedPayloads() {
        assertThrows(SummaryParseException::class.java) { UsageSummaryParser.parse("{") }
        assertThrows(SummaryParseException::class.java) { UsageSummaryParser.parse("[]") }
        assertThrows(SummaryParseException::class.java) {
            UsageSummaryParser.parse(PRO_FIXTURE.replace("\"version\": 1", "\"version\": 2"))
        }
        assertThrows(SummaryParseException::class.java) {
            UsageSummaryParser.parse(PRO_FIXTURE.replace("\"plan\": \"pro\"", "\"plan\": \"enterprise\""))
        }
        assertThrows(SummaryParseException::class.java) {
            UsageSummaryParser.parse(PRO_FIXTURE.replace("\"month\":", "\"not_month\":"))
        }
    }

    @Test
    fun parsesCapturedPublicExchangeRate() {
        val rate = PublicExchangeRateParser.parse("""{"rate":21.804,"date":"06.11.2026"}""")
        assertEquals(21.804, rate.rate, 0.0001)
        assertEquals("06.11.2026", rate.date)
    }

    @Test
    fun rejectsNonPositivePublicRate() {
        assertThrows(SummaryParseException::class.java) {
            PublicExchangeRateParser.parse("""{"rate":0,"date":null}""")
        }
    }

    private companion object {
        const val PRO_FIXTURE = """
        {
          "version": 1,
          "plan": "pro",
          "generated_at": "2026-10-30T06:52:11.482Z",
          "tz": "Europe/Prague",
          "today": { "cost_usd": 1.8421, "tokens": 412000, "requests": 96 },
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
          "usd_czk": { "rate": 23.41, "date": "2026-10-29" },
          "daily": [ { "date": "2026-10-29", "cost_usd": 2.1 }, { "date": "2026-10-30", "cost_usd": 1.8421 } ],
          "top_models": [ { "name": "anthropic/claude-sonnet-4.5", "cost_usd": 21.3 } ],
          "providers": [ { "name": "Anthropic", "cost_usd": 24 }, { "name": "OpenAI", "cost_usd": 14.2 } ],
          "last_activity_at": "2026-10-30T06:40:00+00:00"
        }
        """

        const val FREE_FIXTURE = """
        {
          "version": 1,
          "plan": "free",
          "generated_at": "2026-10-30T06:52:11Z",
          "tz": "Europe/Prague",
          "today": { "cost_usd": 0, "tokens": 0, "requests": 0 },
          "month": { "cost_usd": 3.5, "tokens": 120000, "requests": 40, "key": "2026-10" },
          "previous_month": null,
          "forecast_month_usd": null,
          "budget": null,
          "usd_czk": null,
          "daily": [],
          "top_models": [],
          "providers": [],
          "last_activity_at": null
        }
        """

        const val LEGACY_FIXTURE = """
        {
          "version": 1,
          "generated_at": "2026-10-25T10:00:00Z",
          "today": { "cost_usd": 1, "tokens": 10, "requests": 1 },
          "month": { "cost_usd": 2, "tokens": 20, "requests": 2, "key": "2026-10" },
          "previous_month": { "cost_usd": 3, "tokens": 30, "requests": 3, "key": "2026-09" },
          "forecast_month_usd": 4,
          "budget": null,
          "usd_czk": { "rate": 24, "date": null },
          "last_activity_at": "2026-10-25T09:58:00Z"
        }
        """
    }
}
