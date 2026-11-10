package cz.martinpohl.tokeny.core

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SpendAndMoneyTest {
    private val catalog = DemoCatalog()

    @Test
    fun proSampleIsInternallyConsistentAndLabeledOnlyByTheCaller() {
        val summary = catalog.load(DemoVariant.PRO)
        assertEquals(UsageSummary.Plan.PRO, summary.plan)
        assertEquals(38.2, summary.month.costUsd, 0.0001)
        assertEquals(38.2, summary.providers.sumOf { it.costUsd }, 0.0001)
        assertEquals(38.2, summary.topModels.sumOf { it.costUsd }, 0.0001)
        assertEquals(38.2, summary.daily.sumOf { it.costUsd }, 0.05)
        assertEquals(summary.today.costUsd, summary.daily.last().costUsd, 0.0001)
        assertEquals("2026-10", summary.month.key)
        assertTrue(summary.forecast!!.highUsd!! > summary.budget!!.monthlyUsd)
        assertFalse(summary.isEmptySpend)
    }

    @Test
    fun freeAndEmptySamplesMatchTheServerOmissions() {
        val free = catalog.load(DemoVariant.FREE)
        assertEquals(UsageSummary.Plan.FREE, free.plan)
        assertNull(free.forecast)
        assertNull(free.budget)
        assertNull(free.previousMonth)
        val empty = catalog.load(DemoVariant.EMPTY)
        assertTrue(empty.isEmptySpend)
        assertNull(empty.usdCzk)
    }

    @Test
    fun moneyUsesWebFallbackAndCurrencyStyle() {
        assertEquals("893,88 Kč", formatMoney(38.2, Currency.CZK, 23.4))
        assertEquals("$38.20", formatMoney(38.2, Currency.USD, 23.4))
        assertEquals("23,50 Kč", formatMoney(1.0, Currency.CZK, 0.0))
        assertEquals("23,50 Kč", formatMoney(1.0, Currency.CZK, null))
        assertEquals("$0.0010", formatMoney(0.001, Currency.USD, null))
        assertEquals(FALLBACK_USD_CZK, effectiveUsdCzk(-1.0), 0.0)
    }

    @Test
    fun countsAndPercentsFollowLocale() {
        assertEquals("9,8M", formatCount(9_800_000, Locale.forLanguageTag("cs-CZ")))
        assertEquals("9.8M", formatCount(9_800_000, Locale.US))
        assertEquals("412K", formatCount(412_000, Locale.US))
        assertEquals("76,4 %", formatPercent(76.4, Locale.forLanguageTag("cs-CZ")))
        assertEquals("2026-10-30", displayDay("2026-10-30T07:40:00Z"))
        assertEquals("06.11.2026", displayDay("06.11.2026"))
    }

    @Test
    fun budgetLevelsFollowThresholdAndCap() {
        val budget = Budget(monthlyUsd = 50.0, thresholdPercent = 80.0, enabled = true)
        val under = budgetProgress(38.2, budget)!!
        assertEquals(BudgetLevel.UNDER, under.level)
        assertEquals(76.4, under.percent, 0.0001)
        assertEquals(11.8, under.remainingUsd, 0.0001)
        assertEquals(BudgetLevel.THRESHOLD, budgetProgress(40.0, budget)!!.level)
        assertEquals(BudgetLevel.OVER, budgetProgress(50.0, budget)!!.level)
        assertEquals(0.0, budgetProgress(60.0, budget)!!.remainingUsd, 0.0)
        assertEquals(BudgetLevel.UNSET, budgetProgress(1.0, budget.copy(monthlyUsd = 0.0))!!.level)
        assertNull(budgetProgress(1.0, null))
    }

    @Test
    fun sharesAndChartUseMonthTotal() {
        val summary = catalog.load(DemoVariant.PRO)
        val ranked = rankShares(summary.providers, summary.month.costUsd)
        assertEquals("Anthropic", ranked.first().name)
        assertEquals(1.0, ranked.sumOf { it.fraction }, 0.0001)
        val facts = chartFacts(summary.daily)!!
        assertEquals(30, facts.days)
        assertEquals(summary.daily.maxOf { it.costUsd }, facts.maxUsd, 0.0001)
        assertEquals(summary.daily.last().date, facts.lastDate)
        assertNull(chartFacts(emptyList()))
    }

    @Test
    fun widthBreakpointsMatchMaterialAndDoNotSpecialCaseZero() {
        assertEquals(PaneLayout.COMPACT, paneLayoutForWidthDp(0))
        assertEquals(PaneLayout.COMPACT, paneLayoutForWidthDp(-1))
        assertEquals(PaneLayout.COMPACT, paneLayoutForWidthDp(599))
        assertEquals(PaneLayout.MEDIUM, paneLayoutForWidthDp(600))
        assertEquals(PaneLayout.MEDIUM, paneLayoutForWidthDp(839))
        assertEquals(PaneLayout.EXPANDED, paneLayoutForWidthDp(840))
        assertEquals(PaneLayout.EXPANDED, paneLayoutForWidthDp(1200))
    }
}
