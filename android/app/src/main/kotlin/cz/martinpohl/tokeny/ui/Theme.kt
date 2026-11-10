package cz.martinpohl.tokeny.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import cz.martinpohl.tokeny.core.SpendPalette
import cz.martinpohl.tokeny.core.SpendRoles

private fun Long.argb(): Color = Color(toInt())

private fun SpendRoles.toColorScheme(dark: Boolean): ColorScheme {
    val roles = this
    return if (dark) {
        darkColorScheme(
            primary = roles.primary.argb(),
            onPrimary = roles.onPrimary.argb(),
            primaryContainer = roles.primaryContainer.argb(),
            onPrimaryContainer = roles.onPrimaryContainer.argb(),
            secondary = roles.secondary.argb(),
            onSecondary = roles.onSecondary.argb(),
            secondaryContainer = roles.secondaryContainer.argb(),
            onSecondaryContainer = roles.onSecondaryContainer.argb(),
            tertiary = roles.tertiary.argb(),
            onTertiary = roles.onTertiary.argb(),
            background = roles.background.argb(),
            onBackground = roles.onBackground.argb(),
            surface = roles.surface.argb(),
            onSurface = roles.onSurface.argb(),
            surfaceVariant = roles.surfaceVariant.argb(),
            onSurfaceVariant = roles.onSurfaceVariant.argb(),
            surfaceContainer = roles.surfaceContainer.argb(),
            error = roles.error.argb(),
            onError = roles.onError.argb(),
            outline = roles.outline.argb(),
        )
    } else {
        lightColorScheme(
            primary = roles.primary.argb(),
            onPrimary = roles.onPrimary.argb(),
            primaryContainer = roles.primaryContainer.argb(),
            onPrimaryContainer = roles.onPrimaryContainer.argb(),
            secondary = roles.secondary.argb(),
            onSecondary = roles.onSecondary.argb(),
            secondaryContainer = roles.secondaryContainer.argb(),
            onSecondaryContainer = roles.onSecondaryContainer.argb(),
            tertiary = roles.tertiary.argb(),
            onTertiary = roles.onTertiary.argb(),
            background = roles.background.argb(),
            onBackground = roles.onBackground.argb(),
            surface = roles.surface.argb(),
            onSurface = roles.onSurface.argb(),
            surfaceVariant = roles.surfaceVariant.argb(),
            onSurfaceVariant = roles.onSurfaceVariant.argb(),
            surfaceContainer = roles.surfaceContainer.argb(),
            error = roles.error.argb(),
            onError = roles.onError.argb(),
            outline = roles.outline.argb(),
        )
    }
}

val SampleBanner = SpendPalette.light.sampleBanner.argb()
val SampleBannerInk = SpendPalette.light.sampleBannerInk.argb()

@Composable
fun TokenyTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = (if (dark) SpendPalette.dark else SpendPalette.light).toColorScheme(dark),
        content = content,
    )
}

/**
 * Paints the scheme background and supplies [onBackground] as the default text color.
 * Without this, the window stays the brand purple from `themes.xml` and untouched
 * `Text` stays black, which is the light scheme's ink on a dark window.
 */
@Composable
fun TokenyPage(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
        contentColor = MaterialTheme.colorScheme.onBackground,
        content = content,
    )
}
