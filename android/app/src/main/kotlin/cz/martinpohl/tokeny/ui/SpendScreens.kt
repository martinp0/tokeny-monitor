package cz.martinpohl.tokeny.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import cz.martinpohl.tokeny.R
import cz.martinpohl.tokeny.core.BudgetLevel
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.DemoVariant
import cz.martinpohl.tokeny.core.PaneLayout
import cz.martinpohl.tokeny.core.UsageSummary
import cz.martinpohl.tokeny.core.budgetProgress
import cz.martinpohl.tokeny.core.displayDay
import cz.martinpohl.tokeny.core.formatCount
import cz.martinpohl.tokeny.core.formatMoney
import cz.martinpohl.tokeny.core.formatPercent
import cz.martinpohl.tokeny.core.rankShares
import java.util.Locale

@Composable
fun OverviewScreen(summary: UsageSummary, currency: Currency, layout: PaneLayout) {
    val rate = summary.usdCzk?.rate
    if (summary.isEmptySpend) {
        InfoCard(stringResource(R.string.empty_title), stringResource(R.string.empty_body))
        MetaNotes(summary)
        return
    }
    val today = @Composable {
        MetricCard(stringResource(R.string.label_today), formatMoney(summary.today.costUsd, currency, rate))
    }
    val month = @Composable {
        MetricCard(
            stringResource(R.string.label_month, summary.month.key ?: ""),
            formatMoney(summary.month.costUsd, currency, rate),
        )
    }
    val tokens = @Composable {
        MetricCard(stringResource(R.string.label_tokens), formatCount(summary.month.tokens, uiLocale()))
    }
    val requests = @Composable {
        MetricCard(stringResource(R.string.label_requests), formatCount(summary.month.requests, uiLocale()))
    }
    PlanChip(summary)
    if (layout == PaneLayout.COMPACT) {
        today()
        month()
        tokens()
        requests()
    } else {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                today()
                tokens()
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                month()
                requests()
            }
        }
    }
    summary.previousMonth?.let { previous ->
        Text(
            stringResource(
                R.string.label_previous,
                previous.key ?: "",
                formatMoney(previous.costUsd, currency, rate),
            ),
            style = MaterialTheme.typography.bodyLarge,
        )
    }
    SpendChart(summary.daily, currency, rate, sample = true)
    MetaNotes(summary)
}

@Composable
fun BreakdownScreen(summary: UsageSummary, currency: Currency, layout: PaneLayout) {
    if (summary.providers.isEmpty() && summary.topModels.isEmpty()) {
        InfoCard(stringResource(R.string.empty_breakdown_title), stringResource(R.string.empty_breakdown_body))
        return
    }
    val providers = @Composable {
        ShareList(
            title = stringResource(R.string.label_providers),
            items = summary.providers,
            total = summary.month.costUsd,
            currency = currency,
            rate = summary.usdCzk?.rate,
        )
    }
    val models = @Composable {
        ShareList(
            title = stringResource(R.string.label_models),
            items = summary.topModels,
            total = summary.month.costUsd,
            currency = currency,
            rate = summary.usdCzk?.rate,
        )
    }
    if (layout == PaneLayout.EXPANDED) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) { providers() }
            Column(Modifier.weight(1f)) { models() }
        }
    } else {
        providers()
        models()
    }
}

@Composable
fun BudgetScreen(summary: UsageSummary, variant: DemoVariant, currency: Currency, layout: PaneLayout) {
    val rate = summary.usdCzk?.rate
    val progress = budgetProgress(summary.month.costUsd, summary.budget)
    if (progress == null) {
        val body = if (variant == DemoVariant.FREE) {
            stringResource(R.string.budget_missing_free)
        } else {
            stringResource(R.string.budget_missing_empty)
        }
        InfoCard(stringResource(R.string.budget_missing_title), body)
        if (summary.forecastMonthUsd == null) {
            Text(stringResource(R.string.forecast_missing), style = MaterialTheme.typography.bodyLarge)
        }
        return
    }
    val budgetCard = @Composable { BudgetCard(summary, progress, currency, rate) }
    val forecastCard = @Composable { ForecastCard(summary, currency, rate) }
    if (layout == PaneLayout.EXPANDED) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) { budgetCard() }
            Column(Modifier.weight(1f)) { forecastCard() }
        }
    } else {
        budgetCard()
        forecastCard()
    }
}

@Composable
private fun BudgetCard(
    summary: UsageSummary,
    progress: cz.martinpohl.tokeny.core.BudgetProgress,
    currency: Currency,
    rate: Double?,
) {
    val locale = uiLocale()
    val levelText = when (progress.level) {
        BudgetLevel.UNDER -> stringResource(R.string.budget_under)
        BudgetLevel.THRESHOLD -> stringResource(R.string.budget_threshold)
        BudgetLevel.OVER -> stringResource(R.string.budget_over)
        BudgetLevel.UNSET -> stringResource(R.string.budget_unset)
    }
    val barColor = when (progress.level) {
        BudgetLevel.OVER -> MaterialTheme.colorScheme.error
        BudgetLevel.THRESHOLD -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.primary
    }
    val percentText = formatPercent(progress.percent, locale)
    Surface(
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionTitle(stringResource(R.string.label_budget))
            Text(
                stringResource(
                    R.string.spent_of_budget,
                    formatMoney(progress.spentUsd, currency, rate),
                    formatMoney(progress.monthlyUsd, currency, rate),
                    percentText,
                ),
                style = MaterialTheme.typography.bodyLarge,
            )
            if (progress.level != BudgetLevel.UNSET) {
                androidx.compose.material3.LinearProgressIndicator(
                    progress = { (progress.percent / 100.0).toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth(),
                    color = barColor,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                )
            }
            Text(levelText, style = MaterialTheme.typography.bodyLarge)
            Text(
                stringResource(R.string.label_threshold, formatPercent(progress.thresholdPercent, locale)),
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                stringResource(R.string.remaining, formatMoney(progress.remainingUsd, currency, rate)),
                style = MaterialTheme.typography.bodyLarge,
            )
            SectionTitle(stringResource(R.string.label_alerts))
            Text(
                if (progress.alertsEnabled) stringResource(R.string.alerts_on) else stringResource(R.string.alerts_off),
                style = MaterialTheme.typography.bodyLarge,
            )
            summary.previousMonth?.let { previous ->
                Text(
                    stringResource(
                        R.string.label_previous,
                        previous.key ?: "",
                        formatMoney(previous.costUsd, currency, rate),
                    ),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
    }
}

@Composable
private fun ForecastCard(summary: UsageSummary, currency: Currency, rate: Double?) {
    val point = summary.forecastMonthUsd
    val band = summary.forecast
    Surface(
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionTitle(stringResource(R.string.label_forecast))
            if (point == null) {
                Text(stringResource(R.string.forecast_missing), style = MaterialTheme.typography.bodyLarge)
            } else {
                Text(formatMoney(point, currency, rate), style = MaterialTheme.typography.headlineMedium)
            }
            if (band != null) {
                val low = band.lowUsd
                val high = band.highUsd
                if (low != null && high != null) {
                    Text(
                        stringResource(
                            R.string.label_range,
                            formatMoney(low, currency, rate),
                            formatMoney(high, currency, rate),
                        ),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
                Text(
                    stringResource(R.string.label_confidence, confidenceText(band.confidence)),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    stringResource(R.string.label_method, methodText(band.method)),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    stringResource(R.string.label_days_observed, band.daysObserved),
                    style = MaterialTheme.typography.bodyLarge,
                )
                val budget = summary.budget
                if (high != null && budget != null && budget.monthlyUsd > 0.0 && high > budget.monthlyUsd) {
                    Text(stringResource(R.string.forecast_crosses), style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}

@Composable
private fun ShareList(
    title: String,
    items: List<cz.martinpohl.tokeny.core.NamedSpend>,
    total: Double,
    currency: Currency,
    rate: Double?,
) {
    val locale = uiLocale()
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle(title)
        if (items.isEmpty()) {
            Text(stringResource(R.string.chart_empty), style = MaterialTheme.typography.bodyLarge)
        } else {
            rankShares(items, total).forEach { share ->
                ShareRow(
                    name = share.name,
                    amount = formatMoney(share.costUsd, currency, rate),
                    fraction = share.fraction.toFloat(),
                    percent = formatPercent(share.fraction * 100.0, locale),
                )
            }
        }
    }
}

@Composable
private fun PlanChip(summary: UsageSummary) {
    val label = if (summary.plan == UsageSummary.Plan.PRO) {
        stringResource(R.string.sample_plan_pro)
    } else {
        stringResource(R.string.sample_plan_free)
    }
    Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(999.dp)) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
        )
    }
}

@Composable
private fun MetaNotes(summary: UsageSummary) {
    val rate = summary.usdCzk
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.tz_note, summary.timeZone), style = MaterialTheme.typography.bodyMedium)
        if (rate != null && rate.rate > 0.0) {
            Text(
                stringResource(
                    R.string.rate_note,
                    formatMoney(1.0, Currency.CZK, rate.rate),
                    rate.date ?: displayDay(summary.generatedAt),
                ),
                style = MaterialTheme.typography.bodyMedium,
            )
        } else {
            Text(stringResource(R.string.rate_fallback), style = MaterialTheme.typography.bodyMedium)
        }
        val activity = summary.lastActivityAt
        Text(
            if (activity.isNullOrBlank()) {
                stringResource(R.string.no_activity)
            } else {
                stringResource(R.string.last_activity, displayDay(activity))
            },
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            stringResource(R.string.generated, displayDay(summary.generatedAt)),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun confidenceText(raw: String): String = when (raw) {
    "none" -> stringResource(R.string.confidence_none)
    "low" -> stringResource(R.string.confidence_low)
    "medium" -> stringResource(R.string.confidence_medium)
    "high" -> stringResource(R.string.confidence_high)
    else -> stringResource(R.string.confidence_unknown, raw)
}

@Composable
private fun methodText(raw: String): String = when (raw) {
    "weighted_run_rate" -> stringResource(R.string.method_weighted)
    else -> raw
}

@Composable
private fun uiLocale(): Locale = LocalConfiguration.current.locales[0]
