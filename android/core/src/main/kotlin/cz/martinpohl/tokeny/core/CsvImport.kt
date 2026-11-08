package cz.martinpohl.tokeny.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Local reading of the two CSV shapes the web importer accepts
 * (`src/lib/csv-parser.ts` and `src/lib/usage-export.ts`).
 *
 * OpenRouter activity: header has `generation_id` and `created_at`. Costs use the same
 * `parseFloat` rules as the web. Duplicate ids inside the file: last row wins. Re-import
 * overwrites the same id (the web posts these without `ignoreDuplicates`).
 *
 * Cursor / Grok Bot usage export: header aliases match `HEADER_ALIASES`. Duplicate ids
 * inside the file: first row wins. Re-import keeps the row already stored
 * (`ignoreDuplicates: true`). A currency other than blank or USD is skipped. Email,
 * principal id, and charge category are not kept.
 *
 * A cost that is only a comma decimal (`0,50`) is skipped. The web's usage-export
 * cleaner would delete the comma and store 50, which is a hundred times the written
 * amount. OpenRouter's `parseFloat` would keep only the digits before the comma.
 * Neither of those is stored here.
 */
object CsvLimits {
    const val MAX_FILE_BYTES = 8 * 1024 * 1024
    const val MAX_DATA_ROWS = 20_000
    const val MAX_STORED_ROWS = 20_000
    const val MAX_FIELD_CHARS = 16_000
    const val MAX_ID_CHARS = 300
}

enum class CsvFormat { OPENROUTER, USAGE_EXPORT }

enum class SkipReason {
    MISSING_ID,
    ID_TOO_LONG,
    MISSING_DATE,
    BAD_TIME,
    UNKNOWN_PRODUCT,
    CURRENCY,
    AMBIGUOUS_DECIMAL,
    FIELD_TOO_LONG,
}

enum class ConflictPolicy { UPSERT, IGNORE }

enum class ImportFileError {
    EMPTY,
    TOO_LARGE,
    TOO_MANY_ROWS,
    MALFORMED,
    UNRECOGNIZED,
    NOT_UTF8,
    UNREADABLE,
}

data class StoredRow(
    val generationId: String,
    val createdAt: String,
    val epochMillis: Long,
    val pragueDay: String,
    val costUsd: Double,
    val tokensPrompt: Long,
    val tokensCompletion: Long,
    val tokensReasoning: Long,
    val tokensCached: Long,
    val tokensCacheWrite: Long,
    val model: String,
    val provider: String,
    val providerSource: String,
    val requestCount: Long,
    val billingType: String?,
)

data class ImportDiagnostics(
    val dataRows: Int,
    val accepted: Int,
    val duplicatesInFile: Int,
    val skipped: Map<SkipReason, Int>,
    /** OpenRouter costs that were not a plain number and were stored as the web's parseFloat (often 0). */
    val partialNumbers: Int,
)

data class MergePlan(
    val toInsert: Int,
    val toOverwrite: Int,
    val alreadyStored: Int,
    val storedAfter: Int,
    val exceedsStoreLimit: Boolean,
)

data class ImportPreview(
    val fileName: String,
    val format: CsvFormat,
    val policy: ConflictPolicy,
    val rows: List<StoredRow>,
    val diagnostics: ImportDiagnostics,
    val merge: MergePlan,
) {
    val canSave: Boolean = rows.isNotEmpty() && !merge.exceedsStoreLimit
}

sealed class CsvRead {
    data class Ok(val preview: ImportPreview) : CsvRead()
    data class Failed(val error: ImportFileError) : CsvRead()
}

fun readCsv(
    fileName: String,
    bytes: ByteArray,
    existing: List<StoredRow>,
): CsvRead {
    if (bytes.size > CsvLimits.MAX_FILE_BYTES) return CsvRead.Failed(ImportFileError.TOO_LARGE)
    if (bytes.any { it == 0.toByte() }) return CsvRead.Failed(ImportFileError.MALFORMED)
    val text = try {
        String(bytes, Charsets.UTF_8)
    } catch (_: Exception) {
        return CsvRead.Failed(ImportFileError.NOT_UTF8)
    }
    if (text.isBlank()) return CsvRead.Failed(ImportFileError.EMPTY)
    val table = try {
        parseCsvTable(text, CsvLimits.MAX_DATA_ROWS)
    } catch (_: CsvSyntaxException) {
        return CsvRead.Failed(ImportFileError.MALFORMED)
    } catch (_: TooManyRowsException) {
        return CsvRead.Failed(ImportFileError.TOO_MANY_ROWS)
    }
    if (table.rows.isEmpty() && table.headers.isEmpty()) return CsvRead.Failed(ImportFileError.EMPTY)
    val format = when {
        isUsageExport(table.headers) -> CsvFormat.USAGE_EXPORT
        isOpenRouter(table.headers) -> CsvFormat.OPENROUTER
        else -> return CsvRead.Failed(ImportFileError.UNRECOGNIZED)
    }
    val built = when (format) {
        CsvFormat.USAGE_EXPORT -> mapUsageExport(table.rows)
        CsvFormat.OPENROUTER -> mapOpenRouter(table.rows)
    }
    if (built.rows.isEmpty() && built.diagnostics.dataRows == 0) {
        return CsvRead.Failed(ImportFileError.EMPTY)
    }
    val policy = if (format == CsvFormat.USAGE_EXPORT) ConflictPolicy.IGNORE else ConflictPolicy.UPSERT
    val merge = planMerge(existing, built.rows, policy)
    return CsvRead.Ok(
        ImportPreview(
            fileName = fileName.ifBlank { "import.csv" },
            format = format,
            policy = policy,
            rows = built.rows,
            diagnostics = built.diagnostics,
            merge = merge,
        ),
    )
}

fun planMerge(existing: List<StoredRow>, incoming: List<StoredRow>, policy: ConflictPolicy): MergePlan {
    val have = existing.map { it.generationId }.toMutableSet()
    var insert = 0
    var overwrite = 0
    var already = 0
    for (row in incoming) {
        if (row.generationId in have) {
            if (policy == ConflictPolicy.UPSERT) overwrite += 1 else already += 1
        } else {
            insert += 1
            have += row.generationId
        }
    }
    val after = existing.size + insert
    return MergePlan(insert, overwrite, already, after, after > CsvLimits.MAX_STORED_ROWS)
}

fun applyMerge(existing: List<StoredRow>, incoming: List<StoredRow>, policy: ConflictPolicy): List<StoredRow> {
    val plan = planMerge(existing, incoming, policy)
    if (plan.exceedsStoreLimit) return existing
    val map = LinkedHashMap<String, StoredRow>(existing.size + incoming.size)
    for (row in existing) map[row.generationId] = row
    for (row in incoming) {
        val previous = map[row.generationId]
        if (previous == null) map[row.generationId] = row
        else if (policy == ConflictPolicy.UPSERT) map[row.generationId] = row
    }
    return map.values.toList()
}

private data class Built(val rows: List<StoredRow>, val diagnostics: ImportDiagnostics)

private fun mapOpenRouter(rows: List<Map<String, String>>): Built {
    val skipped = mutableMapOf<SkipReason, Int>()
    var partial = 0
    val byId = LinkedHashMap<String, StoredRow>()
    var dupes = 0
    for (row in rows) {
        when (val mapped = mapOpenRouterRow(row)) {
            is RowResult.Skip -> skipped.bump(mapped.reason)
            is RowResult.Keep -> {
                partial += mapped.partialNumbers
                if (byId.put(mapped.row.generationId, mapped.row) != null) dupes += 1
            }
        }
    }
    return Built(
        byId.values.toList(),
        ImportDiagnostics(rows.size, byId.size, dupes, skipped.toMap(), partial),
    )
}

private fun mapUsageExport(rows: List<Map<String, String>>): Built {
    val skipped = mutableMapOf<SkipReason, Int>()
    val byId = LinkedHashMap<String, StoredRow>()
    var dupes = 0
    for (row in rows) {
        when (val mapped = mapUsageRow(row)) {
            is RowResult.Skip -> skipped.bump(mapped.reason)
            is RowResult.Keep -> {
                if (byId.containsKey(mapped.row.generationId)) dupes += 1
                else byId[mapped.row.generationId] = mapped.row
            }
        }
    }
    return Built(
        byId.values.toList(),
        ImportDiagnostics(rows.size, byId.size, dupes, skipped.toMap(), 0),
    )
}

private sealed class RowResult {
    data class Keep(val row: StoredRow, val partialNumbers: Int = 0) : RowResult()
    data class Skip(val reason: SkipReason) : RowResult()
}

private fun mapOpenRouterRow(row: Map<String, String>): RowResult {
    val id = row["generation_id"].orEmpty().trim()
    if (id.isEmpty()) return RowResult.Skip(SkipReason.MISSING_ID)
    if (id.length > CsvLimits.MAX_ID_CHARS) return RowResult.Skip(SkipReason.ID_TOO_LONG)
    val created = row["created_at"].orEmpty().trim()
    if (created.isEmpty()) return RowResult.Skip(SkipReason.MISSING_DATE)
    if (created.length > 40) return RowResult.Skip(SkipReason.BAD_TIME)
    for (value in row.values) if (value.length > CsvLimits.MAX_FIELD_CHARS) return RowResult.Skip(SkipReason.FIELD_TOO_LONG)
    val costRaw = row["cost_total"].orEmpty()
    if (isCommaDecimal(costRaw)) return RowResult.Skip(SkipReason.AMBIGUOUS_DECIMAL)
    val epoch = PragueTime.parseEpochMillis(created) ?: return RowResult.Skip(SkipReason.BAD_TIME)
    val cost = jsParseFloat(costRaw)
    val partial = if (costRaw.isBlank() || isPlainNumber(costRaw.trim())) 0 else 1
    return RowResult.Keep(
        stored(
            id = id,
            createdAt = created,
            epoch = epoch,
            cost = cost,
            prompt = clampCount(row["tokens_prompt"]),
            completion = clampCount(row["tokens_completion"]),
            reasoning = clampCount(row["tokens_reasoning"]),
            cached = clampCount(row["tokens_cached"]),
            cacheWrite = 0,
            model = row["model_permaslug"].orEmpty().trim(),
            provider = row["provider_name"].orEmpty().trim(),
            source = "openrouter",
            billing = null,
        ),
        partial,
    )
}

private fun mapUsageRow(row: Map<String, String>): RowResult {
    val id = row["Billing Item ID"].orEmpty().trim()
    if (id.isEmpty()) return RowResult.Skip(SkipReason.MISSING_ID)
    if (id.length > CsvLimits.MAX_ID_CHARS) return RowResult.Skip(SkipReason.ID_TOO_LONG)
    val time = row["Event Time"].orEmpty().trim()
    if (time.isEmpty() || time.length > 40) return RowResult.Skip(SkipReason.BAD_TIME)
    for (value in row.values) if (value.length > CsvLimits.MAX_FIELD_CHARS) return RowResult.Skip(SkipReason.FIELD_TOO_LONG)
    val product = PRODUCTS[normalizeProduct(row["Product"].orEmpty())] ?: return RowResult.Skip(SkipReason.UNKNOWN_PRODUCT)
    val currency = row["Pricing Currency"].orEmpty().trim()
    if (currency.isNotEmpty() && !currency.equals("USD", ignoreCase = true)) return RowResult.Skip(SkipReason.CURRENCY)
    val costRaw = row["Pricing Contracted"].orEmpty()
    val cost = usageCost(costRaw) ?: return RowResult.Skip(SkipReason.AMBIGUOUS_DECIMAL)
    val epoch = PragueTime.parseEpochMillis(time) ?: return RowResult.Skip(SkipReason.BAD_TIME)
    val usage = usageObject(row)
    val fresh = positiveInt(usage["prompt-text-tokens"])
    val cached = positiveInt(usage["cached-prompt-text-tokens"])
    val cacheWrite = positiveInt(usage["cache-write-text-tokens"])
    val output = positiveInt(usage["completion-text-tokens"])
    val billingRaw = row["Usage Type"].orEmpty().trim().lowercase()
    val billing = if (billingRaw in BILLING) billingRaw else null
    val model = row["Model"].orEmpty().trim().ifEmpty { product.source }
    val createdAt = InstantText.ofEpoch(epoch)
    return RowResult.Keep(
        stored(
            id = id,
            createdAt = createdAt,
            epoch = epoch,
            cost = cost,
            prompt = fresh + cached + cacheWrite,
            completion = output,
            reasoning = 0,
            cached = cached,
            cacheWrite = cacheWrite,
            model = model,
            provider = product.name,
            source = product.source,
            billing = billing,
        ),
    )
}

private fun stored(
    id: String,
    createdAt: String,
    epoch: Long,
    cost: Double,
    prompt: Long,
    completion: Long,
    reasoning: Long,
    cached: Long,
    cacheWrite: Long,
    model: String,
    provider: String,
    source: String,
    billing: String?,
) = StoredRow(
    generationId = id,
    createdAt = createdAt,
    epochMillis = epoch,
    pragueDay = PragueTime.day(epoch),
    costUsd = cost,
    tokensPrompt = prompt,
    tokensCompletion = completion,
    tokensReasoning = reasoning,
    tokensCached = cached,
    tokensCacheWrite = cacheWrite,
    model = model,
    provider = provider,
    providerSource = source,
    requestCount = 1,
    billingType = billing,
)

private data class Product(val source: String, val name: String)

private val PRODUCTS = mapOf(
    "cursor" to Product("cursor", "Cursor"),
    "grok-bot" to Product("grok-bot", "Grok Bot"),
)
private val BILLING = setOf("included", "on_demand", "credits")
private val TOKEN_KEYS = listOf(
    "prompt-text-tokens",
    "cached-prompt-text-tokens",
    "cache-write-text-tokens",
    "completion-text-tokens",
)

private fun normalizeProduct(raw: String): String =
    raw.trim().lowercase().replace(Regex("[\\s_]+"), "-")

private val HEADER_ALIASES: Map<String, String> = buildMap {
    fun add(canon: String, aliases: List<String>) {
        for (alias in aliases) put(alias, canon)
    }
    add("Billing Item ID", listOf("billingitemid", "billingid", "itemid", "eventid", "requestid", "id"))
    add("Event Time", listOf("eventtime", "timestamp", "time", "createdat", "date", "datetime"))
    add("Product", listOf("product", "productname", "source"))
    add("Usage", listOf("usage", "usagejson"))
    add("Usage Type", listOf("usagetype", "billingtype", "chargetype"))
    add("Pricing Currency", listOf("pricingcurrency", "currency"))
    add("Pricing Contracted", listOf("pricingcontracted", "cost", "costusd", "amount", "amountusd", "price", "priceusd", "charge"))
    add("Model", listOf("model", "modelname"))
    add("prompt-text-tokens", listOf("prompttexttokens", "prompttokens", "inputtokens", "freshinputtokens"))
    add("cached-prompt-text-tokens", listOf("cachedprompttexttokens", "cachedtokens", "cachereadtokens", "cachedinputtokens"))
    add("cache-write-text-tokens", listOf("cachewritetexttokens", "cachewritetokens", "cachecreationtokens"))
    add("completion-text-tokens", listOf("completiontexttokens", "completiontokens", "outputtokens"))
}

private fun squash(header: String): String =
    header.removePrefix("\uFEFF").lowercase().replace(Regex("[^a-z0-9]"), "")

private fun canonicalHeader(header: String): String {
    val trimmed = header.trim().removePrefix("\uFEFF")
    return HEADER_ALIASES[squash(trimmed)] ?: trimmed
}

private fun isUsageExport(headers: List<String>): Boolean {
    val set = headers.map(::canonicalHeader).toSet()
    val hasUsage = "Usage" in set || TOKEN_KEYS.any { it in set }
    return "Billing Item ID" in set && "Event Time" in set && "Product" in set && hasUsage
}

private fun isOpenRouter(headers: List<String>): Boolean {
    val set = headers.map { it.trim().removePrefix("\uFEFF") }.toSet()
    return "generation_id" in set && "created_at" in set
}

private val json = Json { ignoreUnknownKeys = true }

private fun usageObject(row: Map<String, String>): Map<String, String> {
    val out = linkedMapOf<String, String>()
    val raw = row["Usage"].orEmpty()
    if (raw.isNotBlank()) {
        try {
            val element = json.parseToJsonElement(raw)
            if (element is JsonObject) {
                for ((key, value) in element) {
                    val primitive = value as? JsonPrimitive ?: continue
                    out[canonicalHeader(key)] = primitive.content
                }
            }
        } catch (_: Exception) {
            // Malformed Usage JSON contributes zeros; the row can still be stored, as on the web.
        }
    }
    for (key in TOKEN_KEYS) {
        if (out[key] == null && !row[key].isNullOrEmpty()) out[key] = row[key].orEmpty()
    }
    return out
}

/** Web `int()`: only a finite value strictly above zero, then rounded. */
private fun positiveInt(raw: String?): Long {
    val n = raw?.trim()?.toDoubleOrNull() ?: return 0
    if (!n.isFinite() || n <= 0.0) return 0
    return n.toLong()
}

private fun clampCount(raw: String?): Long {
    val n = jsParseFloat(raw.orEmpty())
    if (!n.isFinite() || n <= 0.0) return 0
    return n.toLong().coerceAtMost(2_000_000_000L)
}

private fun isCommaDecimal(raw: String): Boolean =
    Regex("^\\d+,\\d+$").matches(raw.trim())

private fun isPlainNumber(raw: String): Boolean =
    Regex("^[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?$").matches(raw.trim())

/** JavaScript `parseFloat`, empty and non-numeric → 0, comma stops the scan. */
internal fun jsParseFloat(raw: String): Double {
    val s = raw.trim()
    if (s.isEmpty()) return 0.0
    var i = 0
    if (s[0] == '+' || s[0] == '-') i = 1
    val body = i
    var dot = false
    while (i < s.length) {
        val c = s[i]
        if (c.isDigit()) i++
        else if (c == '.' && !dot) {
            dot = true
            i++
        } else break
    }
    if (i == body || (dot && i == body + 1)) return 0.0
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
        var j = i + 1
        if (j < s.length && (s[j] == '+' || s[j] == '-')) j++
        val exp = j
        while (j < s.length && s[j].isDigit()) j++
        if (j > exp) i = j
    }
    return s.substring(0, i).toDoubleOrNull() ?: 0.0
}

/**
 * Usage-export cost. `$` and spaces are removed. A thousands comma with a dot
 * (`$1,234.50`) is the web's rule. A comma used as the decimal mark is refused.
 */
internal fun usageCost(raw: String): Double? {
    val stripped = raw.trim().replace(Regex("[\$\\s]"), "")
    if (stripped.isEmpty()) return 0.0
    if (isCommaDecimal(stripped)) return null
    val n = stripped.replace(",", "").toDoubleOrNull()
    return if (n != null && n.isFinite()) n else 0.0
}

private fun MutableMap<SkipReason, Int>.bump(reason: SkipReason) {
    this[reason] = (this[reason] ?: 0) + 1
}

private object InstantText {
    fun ofEpoch(epochMillis: Long): String {
        val instant = java.time.Instant.ofEpochMilli(epochMillis)
        val seconds = java.time.format.DateTimeFormatter.ISO_INSTANT.format(
            java.time.Instant.ofEpochSecond(instant.epochSecond),
        ).removeSuffix("Z")
        val millis = instant.nano / 1_000_000
        return String.format(java.util.Locale.US, "%s.%03dZ", seconds, millis)
    }
}

private class CsvSyntaxException : Exception()
private class TooManyRowsException : Exception()

private data class CsvTable(val headers: List<String>, val rows: List<Map<String, String>>)

private fun parseCsvTable(text: String, maxRows: Int): CsvTable {
    val records = ArrayList<List<String>>()
    val row = ArrayList<String>()
    val field = StringBuilder()
    var quoted = false
    val src = if (text.startsWith("\uFEFF")) text.substring(1) else text
    var i = 0
    fun endField() {
        row += field.toString()
        field.clear()
    }
    fun endRecord() {
        endField()
        val blank = row.all { it.isBlank() }
        if (!blank) {
            if (records.size >= maxRows + 1) throw TooManyRowsException()
            records += row.toList()
        }
        row.clear()
    }
    while (i < src.length) {
        val c = src[i]
        if (quoted) {
            if (c == '"') {
                if (i + 1 < src.length && src[i + 1] == '"') {
                    field.append('"')
                    i += 2
                    continue
                }
                quoted = false
                i++
                continue
            }
            field.append(c)
            i++
            continue
        }
        when (c) {
            '"' -> {
                if (field.isEmpty()) quoted = true else field.append('"')
                i++
            }
            ',' -> {
                endField()
                i++
            }
            '\n' -> {
                endRecord()
                i++
            }
            '\r' -> {
                endRecord()
                if (i + 1 < src.length && src[i + 1] == '\n') i += 2 else i++
            }
            else -> {
                field.append(c)
                i++
            }
        }
    }
    if (quoted) throw CsvSyntaxException()
    if (field.isNotEmpty() || row.isNotEmpty()) endRecord()
    if (records.isEmpty()) return CsvTable(emptyList(), emptyList())
    val header = records.first().map { canonicalHeader(it.trim()) }
    // OpenRouter headers must stay exact after trim, so detect on the raw trim too.
    val rawHeader = records.first().map { it.trim().removePrefix("\uFEFF") }
    val body = records.drop(1)
    val rows = body.map { cells ->
        val raw = LinkedHashMap<String, String>()
        val canon = LinkedHashMap<String, String>()
        for (index in cells.indices) {
            val name = rawHeader.getOrElse(index) { "" }
            val canonName = header.getOrElse(index) { "" }
            if (name.isNotEmpty() && name !in raw) raw[name] = cells[index]
            if (canonName.isNotEmpty() && canonName !in canon) canon[canonName] = cells[index]
        }
        if (isOpenRouterHeader(rawHeader)) raw else canon
    }
    return CsvTable(rawHeader, rows)
}

private fun isOpenRouterHeader(headers: List<String>): Boolean =
    "generation_id" in headers && "created_at" in headers
