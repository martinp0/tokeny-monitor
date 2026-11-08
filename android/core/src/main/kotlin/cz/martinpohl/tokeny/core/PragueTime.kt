package cz.martinpohl.tokeny.core

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

/**
 * Europe/Prague calendar days for spend grouping.
 *
 * Zoned timestamps (a `Z` or a numeric offset) are instants, then the Prague civil day.
 * That matches `localDay` in `server/lib/forecast.ts`, including the DST boundaries:
 * Prague is UTC+1 in winter and UTC+2 in summer. Spring forward 2026 is 29 March
 * (02:00–03:00 does not exist). Fall back 2026 is 25 October (02:00–03:00 happens twice).
 *
 * A timestamp with no offset is a Prague wall clock, not the phone's zone. OpenRouter's
 * activity CSV is this shape (`2026-05-13 11:45:06.165`). The web dashboard then shows
 * the written date; interpreting it as Prague keeps that date instead of shifting it
 * into the device zone or into UTC.
 */
object PragueTime {
    val zone: ZoneId = ZoneId.of("Europe/Prague")

    fun day(epochMillis: Long): String =
        Instant.ofEpochMilli(epochMillis).atZone(zone).toLocalDate().toString()

    fun month(day: String): String = day.take(7)

    /** Null when the text is not a timestamp we can place on the Prague calendar. */
    fun parseEpochMillis(raw: String): Long? {
        val text = raw.trim()
        if (text.isEmpty() || text.length > 40) return null
        parseOffset(text)?.let { return it.toInstant().toEpochMilli() }
        val local = parseWall(text) ?: return null
        // Gap: move forward by the missing hour. Overlap: Java keeps the earlier offset (summer).
        return ZonedDateTime.of(local, zone).toInstant().toEpochMilli()
    }

    private fun parseOffset(text: String): OffsetDateTime? {
        if (!hasExplicitOffset(text)) return null
        val iso = text.replace(' ', 'T')
        return try {
            OffsetDateTime.parse(iso)
        } catch (_: DateTimeParseException) {
            null
        }
    }

    private fun hasExplicitOffset(text: String): Boolean {
        if (text.endsWith("Z", ignoreCase = true)) return true
        return OFFSET_TAIL.containsMatchIn(text)
    }

    private fun parseWall(text: String): LocalDateTime? {
        val normalized = text.replace(' ', 'T')
        for (formatter in WALL) {
            try {
                return if (formatter == DATE_ONLY) {
                    LocalDate.parse(normalized, formatter).atStartOfDay()
                } else {
                    LocalDateTime.parse(normalized, formatter)
                }
            } catch (_: DateTimeParseException) {
                continue
            }
        }
        return null
    }

    private val DATE_ONLY: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE
    private val WALL = listOf(
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS"),
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"),
        DateTimeFormatter.ISO_LOCAL_DATE,
    )
    private val OFFSET_TAIL = Regex(".*[+-]\\d{2}:\\d{2}$")

    /** Exposed for tests that want the post-gap instant, not only the day. */
    fun offsetAt(epochMillis: Long): ZoneOffset =
        zone.rules.getOffset(Instant.ofEpochMilli(epochMillis))
}
