package cz.martinpohl.tokeny.core

/**
 * Color roles the Android UI is allowed to paint.
 * Light and dark are both explicit. The page background is not the brand purple:
 * that purple is `primary` (and the mark), and it fails contrast on itself.
 */
data class SpendRoles(
    val primary: Long,
    val onPrimary: Long,
    val primaryContainer: Long,
    val onPrimaryContainer: Long,
    val secondary: Long,
    val onSecondary: Long,
    val secondaryContainer: Long,
    val onSecondaryContainer: Long,
    val tertiary: Long,
    val onTertiary: Long,
    val error: Long,
    val onError: Long,
    val outline: Long,
    val background: Long,
    val onBackground: Long,
    val surface: Long,
    val onSurface: Long,
    val surfaceVariant: Long,
    val onSurfaceVariant: Long,
    val surfaceContainer: Long,
    val sampleBanner: Long,
    val sampleBannerInk: Long,
)

object SpendPalette {
    val light = SpendRoles(
        primary = 0xFF6D28D9,
        onPrimary = 0xFFFFFFFF,
        primaryContainer = 0xFFEDE9FE,
        onPrimaryContainer = 0xFF2E1065,
        secondary = 0xFF4C1D95,
        onSecondary = 0xFFFFFFFF,
        secondaryContainer = 0xFFEDE9FE,
        onSecondaryContainer = 0xFF2E1065,
        tertiary = 0xFFB45309,
        onTertiary = 0xFFFFFFFF,
        error = 0xFFB91C1C,
        onError = 0xFFFFFFFF,
        outline = 0xFFD4C8E6,
        background = 0xFFF7F4FB,
        onBackground = 0xFF1C1430,
        surface = 0xFFFFFFFF,
        onSurface = 0xFF1C1430,
        surfaceVariant = 0xFFEDE9FE,
        onSurfaceVariant = 0xFF4C3D63,
        surfaceContainer = 0xFFFFFFFF,
        sampleBanner = 0xFFF59E0B,
        sampleBannerInk = 0xFF1A1203,
    )

    val dark = SpendRoles(
        primary = 0xFFC4B5FD,
        onPrimary = 0xFF2E1065,
        primaryContainer = 0xFF4C1D95,
        onPrimaryContainer = 0xFFEDE9FE,
        secondary = 0xFFDDD6FE,
        onSecondary = 0xFF2E1065,
        secondaryContainer = 0xFF4C1D95,
        onSecondaryContainer = 0xFFEDE9FE,
        tertiary = 0xFFFBBF24,
        onTertiary = 0xFF1A1203,
        error = 0xFFFCA5A5,
        onError = 0xFF450A0A,
        outline = 0xFF4C3D63,
        background = 0xFF120E1A,
        onBackground = 0xFFF5F3FF,
        surface = 0xFF1C1626,
        onSurface = 0xFFF5F3FF,
        surfaceVariant = 0xFF2A2238,
        onSurfaceVariant = 0xFFD4C8E6,
        surfaceContainer = 0xFF1C1626,
        sampleBanner = 0xFFF59E0B,
        sampleBannerInk = 0xFF1A1203,
    )
}

/** WCAG 2 contrast ratio. Both arguments are opaque sRGB `0xAARRGGBB`. */
fun contrastRatio(foreground: Long, background: Long): Double {
    fun channel(raw: Int): Double {
        val value = raw / 255.0
        return if (value <= 0.04045) value / 12.92 else Math.pow((value + 0.055) / 1.055, 2.4)
    }
    fun luminance(color: Long): Double {
        val red = channel(((color shr 16) and 0xFF).toInt())
        val green = channel(((color shr 8) and 0xFF).toInt())
        val blue = channel((color and 0xFF).toInt())
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
    val lighter = maxOf(luminance(foreground), luminance(background))
    val darker = minOf(luminance(foreground), luminance(background))
    return (lighter + 0.05) / (darker + 0.05)
}

data class ContrastCheck(val name: String, val foreground: Long, val background: Long, val minimum: Double)

/**
 * Pairs the screens actually paint.
 * Text and button labels need 4.5. Chart and budget bars need 3.
 * `onSurface` is also checked against the page background because section titles
 * sit on the page, not inside a card.
 */
fun contrastChecks(roles: SpendRoles, mode: String): List<ContrastCheck> = listOf(
    ContrastCheck("$mode page text", roles.onBackground, roles.background, 4.5),
    ContrastCheck("$mode section title on page", roles.onSurface, roles.background, 4.5),
    ContrastCheck("$mode card text", roles.onSurface, roles.surface, 4.5),
    ContrastCheck("$mode caption on page", roles.onSurfaceVariant, roles.background, 4.5),
    ContrastCheck("$mode caption on card", roles.onSurfaceVariant, roles.surface, 4.5),
    ContrastCheck("$mode nav unselected", roles.onSurfaceVariant, roles.surfaceContainer, 4.5),
    ContrastCheck("$mode text button", roles.primary, roles.background, 4.5),
    ContrastCheck("$mode filled button", roles.onPrimary, roles.primary, 4.5),
    ContrastCheck("$mode import banner", roles.onPrimaryContainer, roles.primaryContainer, 4.5),
    ContrastCheck("$mode nav selected", roles.onSecondaryContainer, roles.secondaryContainer, 4.5),
    ContrastCheck("$mode sample banner", roles.sampleBannerInk, roles.sampleBanner, 4.5),
    ContrastCheck("$mode chart bar", roles.primary, roles.background, 3.0),
    ContrastCheck("$mode budget bar", roles.tertiary, roles.surface, 3.0),
    ContrastCheck("$mode over-budget bar", roles.error, roles.surface, 3.0),
)

fun rgbHex(color: Long): String = "#%06X".format(color and 0xFFFFFF)
