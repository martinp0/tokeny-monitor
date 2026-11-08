package cz.martinpohl.tokeny.core

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Spend computed only from rows stored on this phone.
 * Amounts stay in USD. There is no exchange rate and no budget or forecast:
 * those come from a connected account, which this build does not open.
 */
data class BillingSplit(
    val freshInput: Long,
    val cachedRead: Long,
    val cacheWrite: Long,
    val output: Long,
    val includedCostUsd: Double,
    val onDemandCostUsd: Double,
    val creditsCostUsd: Double,
    val includedCalls: Long,
    val onDemandCalls: Long,
    val creditsCalls: Long,
)

data class LocalPicture(
    val rowCount: Int,
    val sources: List<String>,
    val firstDay: String?,
    val lastDay: String?,
    val allCostUsd: Double,
    val allTokens: Long,
    val allRequests: Long,
    val pragueToday: String,
    val todayCostUsd: Double,
    val focusMonth: String?,
    val focusMonthCostUsd: Double,
    val focusMonthTokens: Long,
    val focusMonthRequests: Long,
    val previousMonth: String?,
    val previousMonthCostUsd: Double?,
    val daily: List<DailySpend>,
    val providers: List<NamedSpend>,
    val models: List<NamedSpend>,
    val billing: BillingSplit?,
)

fun localPicture(rows: List<StoredRow>, nowMillis: Long): LocalPicture {
    val today = PragueTime.day(nowMillis)
    val sources = rows.map { it.providerSource }.distinct().sorted()
    val days = rows.map { it.pragueDay }
    val first = days.minOrNull()
    val last = days.maxOrNull()
    val focus = last?.let { PragueTime.month(it) }
    val previous = focus?.let { previousMonth(it) }
    val focusRows = rows.filter { PragueTime.month(it.pragueDay) == focus }
    val previousRows = if (previous == null) emptyList() else rows.filter { PragueTime.month(it.pragueDay) == previous }
    return LocalPicture(
        rowCount = rows.size,
        sources = sources,
        firstDay = first,
        lastDay = last,
        allCostUsd = rows.sumOf { it.costUsd },
        allTokens = rows.sumOf { it.tokensPrompt + it.tokensCompletion + it.tokensReasoning },
        allRequests = rows.sumOf { it.requestCount },
        pragueToday = today,
        todayCostUsd = rows.filter { it.pragueDay == today }.sumOf { it.costUsd },
        focusMonth = focus,
        focusMonthCostUsd = focusRows.sumOf { it.costUsd },
        focusMonthTokens = focusRows.sumOf { it.tokensPrompt + it.tokensCompletion + it.tokensReasoning },
        focusMonthRequests = focusRows.sumOf { it.requestCount },
        previousMonth = if (previousRows.isEmpty()) null else previous,
        previousMonthCostUsd = if (previousRows.isEmpty()) null else previousRows.sumOf { it.costUsd },
        daily = focus?.let { monthDays(it, focusRows) } ?: emptyList(),
        providers = ranked(focusRows) { it.provider.ifBlank { "" } },
        models = ranked(focusRows) { it.model.ifBlank { "" } },
        billing = billingSplit(rows),
    )
}

fun shortModelName(name: String): String {
    if (name.isEmpty()) return name
    return name.substringAfterLast('/')
}

private fun ranked(rows: List<StoredRow>, name: (StoredRow) -> String): List<NamedSpend> {
    val totals = linkedMapOf<String, Double>()
    for (row in rows) {
        val key = name(row)
        totals[key] = (totals[key] ?: 0.0) + row.costUsd
    }
    return totals.entries
        .sortedByDescending { it.value }
        .map { NamedSpend(it.key, it.value) }
}

private fun monthDays(month: String, rows: List<StoredRow>): List<DailySpend> {
    val byDay = rows.groupBy { it.pragueDay }
    return daysOfMonth(month).map { day ->
        DailySpend(day, byDay[day]?.sumOf { it.costUsd } ?: 0.0)
    }
}

internal fun daysOfMonth(month: String): List<String> {
    val year = month.substring(0, 4).toInt()
    val mon = month.substring(5, 7).toInt()
    val length = java.time.YearMonth.of(year, mon).lengthOfMonth()
    return (1..length).map { day -> "%04d-%02d-%02d".format(year, mon, day) }
}

private fun previousMonth(month: String): String {
    val year = month.substring(0, 4).toInt()
    val mon = month.substring(5, 7).toInt()
    return if (mon == 1) "%04d-12".format(year - 1) else "%04d-%02d".format(year, mon - 1)
}

private fun billingSplit(rows: List<StoredRow>): BillingSplit? {
    val tagged = rows.filter { it.billingType != null }
    if (tagged.isEmpty()) return null
    var fresh = 0L
    var cached = 0L
    var write = 0L
    var output = 0L
    var included = 0.0
    var onDemand = 0.0
    var credits = 0.0
    var includedCalls = 0L
    var onDemandCalls = 0L
    var creditsCalls = 0L
    for (row in tagged) {
        cached += row.tokensCached
        write += row.tokensCacheWrite
        fresh += (row.tokensPrompt - row.tokensCached - row.tokensCacheWrite).coerceAtLeast(0)
        output += row.tokensCompletion
        when (row.billingType) {
            "included" -> {
                included += row.costUsd
                includedCalls += row.requestCount
            }
            "on_demand" -> {
                onDemand += row.costUsd
                onDemandCalls += row.requestCount
            }
            else -> {
                credits += row.costUsd
                creditsCalls += row.requestCount
            }
        }
    }
    return BillingSplit(
        fresh, cached, write, output, included, onDemand, credits, includedCalls, onDemandCalls, creditsCalls,
    )
}

@Serializable
data class LedgerFileDto(
    val version: Int = 1,
    val rows: List<StoredRowDto> = emptyList(),
)

@Serializable
data class StoredRowDto(
    val generationId: String,
    val createdAt: String,
    val epochMillis: Long,
    val pragueDay: String,
    val costUsd: Double,
    val tokensPrompt: Long,
    val tokensCompletion: Long,
    val tokensReasoning: Long = 0,
    val tokensCached: Long = 0,
    val tokensCacheWrite: Long = 0,
    val model: String,
    val provider: String,
    val providerSource: String,
    val requestCount: Long = 1,
    val billingType: String? = null,
)

fun StoredRow.toDto() = StoredRowDto(
    generationId, createdAt, epochMillis, pragueDay, costUsd, tokensPrompt, tokensCompletion,
    tokensReasoning, tokensCached, tokensCacheWrite, model, provider, providerSource, requestCount, billingType,
)

fun StoredRowDto.toRow() = StoredRow(
    generationId, createdAt, epochMillis, pragueDay, costUsd, tokensPrompt, tokensCompletion,
    tokensReasoning, tokensCached, tokensCacheWrite, model, provider, providerSource, requestCount, billingType,
)

sealed class LedgerLoad {
    data class Ready(val rows: List<StoredRow>) : LedgerLoad()
    data object Missing : LedgerLoad()
    data object Unreadable : LedgerLoad()
}

private val ledgerJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

class LedgerFile(private val file: File) {
    fun load(): LedgerLoad {
        if (!file.exists()) return LedgerLoad.Missing
        return try {
            val dto = ledgerJson.decodeFromString(LedgerFileDto.serializer(), file.readText())
            if (dto.version != 1) LedgerLoad.Unreadable
            else LedgerLoad.Ready(dto.rows.map { it.toRow() })
        } catch (_: Exception) {
            LedgerLoad.Unreadable
        }
    }

    fun save(rows: List<StoredRow>) {
        file.parentFile?.mkdirs()
        val dto = LedgerFileDto(version = 1, rows = rows.map { it.toDto() })
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(ledgerJson.encodeToString(LedgerFileDto.serializer(), dto))
        if (!tmp.renameTo(file)) {
            file.writeText(tmp.readText())
            tmp.delete()
        }
    }

    fun delete() {
        file.delete()
    }
}
