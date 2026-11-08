package cz.martinpohl.tokeny.core

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * Facts about the existing HTTP contract. This module does not open a socket.
 * Every credential shape the server understands today is rejected here: this build
 * has no tested mobile session, so it must not assemble an Authorization header.
 */
object TokenyApiContract {
    const val PRODUCTION_ORIGIN = "https://tokeny.martinpohl.cz"

    fun usageSummaryUrl(timeZone: String, origin: String = PRODUCTION_ORIGIN): String {
        val tz = timeZone.trim().ifEmpty { "Europe/Prague" }
        val encoded = URLEncoder.encode(tz, StandardCharsets.UTF_8)
        return origin.trimEnd('/') + "/api/usage-summary?tz=" + encoded
    }
}

enum class CredentialRejection {
    BLANK,
    COOKIE_SHAPED,
    PROVIDER_KEY,
    PERSONAL_MCP_TOKEN,
    JWT_NEEDS_A_SESSION_FLOW,
    UNRECOGNIZED,
}

private val ORM_TOKEN = Regex("^orm_[0-9a-fA-F]{64}$")
private val JWT_PART = Regex("^[A-Za-z0-9_-]+$")

fun rejectCredential(raw: String): CredentialRejection {
    val token = raw.trim()
    if (token.isEmpty()) return CredentialRejection.BLANK
    val lower = token.lowercase()
    if (
        token.contains('=') ||
        token.contains(';') ||
        lower.contains("cookie") ||
        lower.contains("session_token")
    ) {
        return CredentialRejection.COOKIE_SHAPED
    }
    if (
        lower.startsWith("sk-") ||
        lower.startsWith("sk_") ||
        lower.startsWith("or-") ||
        lower.startsWith("anthropic")
    ) {
        return CredentialRejection.PROVIDER_KEY
    }
    if (ORM_TOKEN.matches(token)) return CredentialRejection.PERSONAL_MCP_TOKEN
    if (looksLikeJwt(token)) return CredentialRejection.JWT_NEEDS_A_SESSION_FLOW
    return CredentialRejection.UNRECOGNIZED
}

private fun looksLikeJwt(token: String): Boolean {
    val parts = token.split('.')
    return parts.size == 3 && parts.all { it.isNotEmpty() && JWT_PART.matches(it) }
}

enum class SummaryFailure {
    UNAUTHORIZED,
    PRO_REQUIRED,
    FORBIDDEN,
    NOT_DEPLOYED,
    SERVER,
}

data class ClassifiedStatus(val failure: SummaryFailure, val status: Int)

fun classifySummaryStatus(status: Int, body: String): ClassifiedStatus? {
    if (status in 200..299) return null
    val failure = when (status) {
        401 -> SummaryFailure.UNAUTHORIZED
        403 -> if (errorCode(body) == "pro_required") SummaryFailure.PRO_REQUIRED else SummaryFailure.FORBIDDEN
        404 -> SummaryFailure.NOT_DEPLOYED
        else -> SummaryFailure.SERVER
    }
    return ClassifiedStatus(failure, status)
}

private fun errorCode(body: String): String? = try {
    val root = kotlinx.serialization.json.Json.parseToJsonElement(body)
    if (root !is kotlinx.serialization.json.JsonObject) null
    else (root["error"] as? kotlinx.serialization.json.JsonPrimitive)?.takeIf { it.isString }?.content
} catch (_: Exception) {
    null
}
