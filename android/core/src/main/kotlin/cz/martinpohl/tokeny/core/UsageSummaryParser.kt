package cz.martinpohl.tokeny.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull

class SummaryParseException(message: String) : Exception(message)

object UsageSummaryParser {
    private val json = Json { ignoreUnknownKeys = true }

    fun parse(text: String): UsageSummary {
        val root = try {
            json.parseToJsonElement(text)
        } catch (_: Exception) {
            throw SummaryParseException("invalid json")
        }
        if (root !is JsonObject) throw SummaryParseException("expected object")
        val version = root.optional("version")?.asInt() ?: 1
        if (version != 1) throw SummaryParseException("unsupported version")
        val plan = when (val raw = root.optional("plan")?.asString()) {
            null -> UsageSummary.Plan.PRO
            "free" -> UsageSummary.Plan.FREE
            "pro" -> UsageSummary.Plan.PRO
            else -> throw SummaryParseException("unknown plan")
        }
        return UsageSummary(
            version = version,
            plan = plan,
            generatedAt = root.required("generated_at").asString(),
            timeZone = root.optional("tz")?.asString()?.takeIf { it.isNotBlank() } ?: "Europe/Prague",
            today = root.required("today").asBucket(),
            month = root.required("month").asBucket(),
            previousMonth = root.optional("previous_month")?.asBucket(),
            forecastMonthUsd = root.optional("forecast_month_usd")?.asFiniteDouble(),
            forecast = root.optional("forecast")?.asForecast(),
            budget = root.optional("budget")?.asBudget(),
            usdCzk = root.optional("usd_czk")?.asRate(),
            daily = root.optional("daily")?.asArray()?.map { it.asDaily() } ?: emptyList(),
            topModels = root.optional("top_models")?.asArray()?.map { it.asNamed() } ?: emptyList(),
            providers = root.optional("providers")?.asArray()?.map { it.asNamed() } ?: emptyList(),
            lastActivityAt = root.optional("last_activity_at")?.asString()?.takeIf { it.isNotBlank() },
        )
    }
}

/** Public `GET /api/exchange-rate` body: `{ "rate": number, "date": string|null }`. */
data class PublicExchangeRate(val rate: Double, val date: String?)

object PublicExchangeRateParser {
    private val json = Json { ignoreUnknownKeys = true }

    fun parse(text: String): PublicExchangeRate {
        val root = try {
            json.parseToJsonElement(text)
        } catch (_: Exception) {
            throw SummaryParseException("invalid json")
        }
        if (root !is JsonObject) throw SummaryParseException("expected object")
        val rate = root.required("rate").asFiniteDouble()
        if (rate <= 0.0) throw SummaryParseException("non-positive rate")
        val date = root.optional("date")?.asString()?.takeIf { it.isNotBlank() }
        return PublicExchangeRate(rate, date)
    }
}

private fun JsonObject.required(name: String): JsonElement =
    optional(name) ?: throw SummaryParseException("missing $name")

private fun JsonObject.optional(name: String): JsonElement? =
    this[name]?.takeUnless { it is JsonNull }

private fun JsonElement.asObject(): JsonObject =
    this as? JsonObject ?: throw SummaryParseException("expected object")

private fun JsonElement.asArray(): JsonArray =
    this as? JsonArray ?: throw SummaryParseException("expected array")

private fun JsonElement.asPrimitive(): JsonPrimitive =
    this as? JsonPrimitive ?: throw SummaryParseException("expected scalar")

private fun JsonElement.asString(): String {
    val primitive = asPrimitive()
    if (!primitive.isString) throw SummaryParseException("expected string")
    return primitive.content
}

private fun JsonElement.asInt(): Int =
    asPrimitive().intOrNull ?: throw SummaryParseException("expected int")

private fun JsonElement.asFiniteDouble(): Double {
    val n = asPrimitive().doubleOrNull ?: throw SummaryParseException("expected number")
    if (!n.isFinite()) throw SummaryParseException("non-finite number")
    return n
}

private fun JsonElement.asLong(): Long {
    val p = asPrimitive()
    p.longOrNull?.let { return it }
    val d = p.doubleOrNull ?: throw SummaryParseException("expected number")
    if (!d.isFinite()) throw SummaryParseException("non-finite number")
    return d.toLong()
}

private fun JsonElement.asBucket(): SpendBucket {
    val o = asObject()
    return SpendBucket(
        costUsd = o.required("cost_usd").asFiniteDouble(),
        tokens = o.required("tokens").asLong(),
        requests = o.required("requests").asLong(),
        key = o.optional("key")?.asString()?.takeIf { it.isNotBlank() },
    )
}

private fun JsonElement.asForecast(): ForecastBand {
    val o = asObject()
    return ForecastBand(
        lowUsd = o.optional("low_usd")?.asFiniteDouble(),
        highUsd = o.optional("high_usd")?.asFiniteDouble(),
        confidence = o.required("confidence").asString(),
        daysObserved = o.required("days_observed").asInt(),
        method = o.required("method").asString(),
    )
}

private fun JsonElement.asBudget(): Budget {
    val o = asObject()
    return Budget(
        monthlyUsd = o.required("monthly_usd").asFiniteDouble(),
        thresholdPercent = o.required("threshold_pct").asFiniteDouble(),
        enabled = o.required("enabled").asPrimitive().booleanOrNull
            ?: throw SummaryParseException("expected boolean"),
    )
}

private fun JsonElement.asRate(): ExchangeRate {
    val o = asObject()
    return ExchangeRate(
        rate = o.required("rate").asFiniteDouble(),
        date = o.optional("date")?.asString()?.takeIf { it.isNotBlank() },
    )
}

private fun JsonElement.asDaily(): DailySpend {
    val o = asObject()
    val date = o.required("date").asString()
    if (date.isBlank()) throw SummaryParseException("blank date")
    return DailySpend(date = date, costUsd = o.required("cost_usd").asFiniteDouble())
}

private fun JsonElement.asNamed(): NamedSpend {
    val o = asObject()
    val name = o.required("name").asString()
    if (name.isBlank()) throw SummaryParseException("blank name")
    return NamedSpend(name = name, costUsd = o.required("cost_usd").asFiniteDouble())
}
