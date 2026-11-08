package cz.martinpohl.tokeny.core

/**
 * Read model of `GET /api/usage-summary` (server/usage-summary.ts, version 1).
 * Money is USD. Nothing in this type means the numbers belong to the person holding the phone.
 */
data class UsageSummary(
    val version: Int,
    val plan: Plan,
    val generatedAt: String,
    val timeZone: String,
    val today: SpendBucket,
    val month: SpendBucket,
    val previousMonth: SpendBucket?,
    val forecastMonthUsd: Double?,
    val forecast: ForecastBand?,
    val budget: Budget?,
    val usdCzk: ExchangeRate?,
    val daily: List<DailySpend>,
    val topModels: List<NamedSpend>,
    val providers: List<NamedSpend>,
    val lastActivityAt: String?,
) {
    enum class Plan { FREE, PRO }

    val isEmptySpend: Boolean
        get() = today.costUsd == 0.0 &&
            month.costUsd == 0.0 &&
            providers.isEmpty() &&
            topModels.isEmpty() &&
            daily.all { it.costUsd == 0.0 }
}

data class SpendBucket(
    val costUsd: Double,
    val tokens: Long,
    val requests: Long,
    /** "YYYY-MM" for a month bucket. */
    val key: String?,
)

data class ForecastBand(
    val lowUsd: Double?,
    val highUsd: Double?,
    val confidence: String,
    val daysObserved: Int,
    val method: String,
)

data class Budget(
    val monthlyUsd: Double,
    val thresholdPercent: Double,
    val enabled: Boolean,
)

data class ExchangeRate(
    val rate: Double,
    val date: String?,
)

data class DailySpend(
    val date: String,
    val costUsd: Double,
)

data class NamedSpend(
    val name: String,
    val costUsd: Double,
)

/** Same fallback as FALLBACK_RATE in src/lib/format.ts. */
const val FALLBACK_USD_CZK = 23.5
