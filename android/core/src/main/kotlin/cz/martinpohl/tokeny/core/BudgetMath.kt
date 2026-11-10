package cz.martinpohl.tokeny.core

enum class BudgetLevel { UNDER, THRESHOLD, OVER, UNSET }

data class BudgetProgress(
    val spentUsd: Double,
    val monthlyUsd: Double,
    val percent: Double,
    val level: BudgetLevel,
    val remainingUsd: Double,
    val alertsEnabled: Boolean,
    val thresholdPercent: Double,
)

fun budgetProgress(spentUsd: Double, budget: Budget?): BudgetProgress? {
    if (budget == null) return null
    if (!budget.monthlyUsd.isFinite() || budget.monthlyUsd <= 0.0) {
        return BudgetProgress(
            spentUsd = spentUsd,
            monthlyUsd = budget.monthlyUsd,
            percent = Double.POSITIVE_INFINITY,
            level = BudgetLevel.UNSET,
            remainingUsd = 0.0,
            alertsEnabled = budget.enabled,
            thresholdPercent = budget.thresholdPercent,
        )
    }
    val percent = spentUsd / budget.monthlyUsd * 100.0
    val level = when {
        percent >= 100.0 -> BudgetLevel.OVER
        percent >= budget.thresholdPercent -> BudgetLevel.THRESHOLD
        else -> BudgetLevel.UNDER
    }
    return BudgetProgress(
        spentUsd = spentUsd,
        monthlyUsd = budget.monthlyUsd,
        percent = percent,
        level = level,
        remainingUsd = (budget.monthlyUsd - spentUsd).coerceAtLeast(0.0),
        alertsEnabled = budget.enabled,
        thresholdPercent = budget.thresholdPercent,
    )
}

data class RankedShare(
    val name: String,
    val costUsd: Double,
    val fraction: Double,
)

fun rankShares(items: List<NamedSpend>, totalUsd: Double): List<RankedShare> {
    val total = if (totalUsd > 0.0) totalUsd else items.sumOf { it.costUsd }
    return items.sortedByDescending { it.costUsd }.map { item ->
        RankedShare(
            name = item.name,
            costUsd = item.costUsd,
            fraction = if (total > 0.0) (item.costUsd / total).coerceIn(0.0, 1.0) else 0.0,
        )
    }
}

data class ChartFacts(
    val days: Int,
    val maxDate: String,
    val maxUsd: Double,
    val lastDate: String,
    val lastUsd: Double,
)

fun chartFacts(days: List<DailySpend>): ChartFacts? {
    if (days.isEmpty()) return null
    val ordered = days.sortedBy { it.date }
    val max = ordered.maxBy { it.costUsd }
    val last = ordered.last()
    return ChartFacts(ordered.size, max.date, max.costUsd, last.date, last.costUsd)
}

fun sortedDaily(days: List<DailySpend>): List<DailySpend> = days.sortedBy { it.date }
