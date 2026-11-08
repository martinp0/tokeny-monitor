package cz.martinpohl.tokeny.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Purple = Color(0xFF6D28D9)
private val PurpleDeep = Color(0xFF2E1065)
private val Ink = Color(0xFF1C1430)
private val Paper = Color(0xFFF7F4FB)
private val PaperCard = Color(0xFFFFFFFF)

private val LightColors = lightColorScheme(
    primary = Purple,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFEDE9FE),
    onPrimaryContainer = PurpleDeep,
    secondary = Color(0xFF4C1D95),
    onSecondary = Color.White,
    tertiary = Color(0xFFB45309),
    onTertiary = Color.White,
    background = Paper,
    onBackground = Ink,
    surface = PaperCard,
    onSurface = Ink,
    surfaceVariant = Color(0xFFEDE9FE),
    onSurfaceVariant = Color(0xFF4C3D63),
    error = Color(0xFFB91C1C),
    onError = Color.White,
    outline = Color(0xFFD4C8E6),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFC4B5FD),
    onPrimary = PurpleDeep,
    primaryContainer = Color(0xFF4C1D95),
    onPrimaryContainer = Color(0xFFEDE9FE),
    secondary = Color(0xFFDDD6FE),
    onSecondary = PurpleDeep,
    tertiary = Color(0xFFFBBF24),
    onTertiary = Color(0xFF1A1203),
    background = Color(0xFF120E1A),
    onBackground = Color(0xFFF5F3FF),
    surface = Color(0xFF1C1626),
    onSurface = Color(0xFFF5F3FF),
    surfaceVariant = Color(0xFF2A2238),
    onSurfaceVariant = Color(0xFFD4C8E6),
    error = Color(0xFFFCA5A5),
    onError = Color(0xFF450A0A),
    outline = Color(0xFF4C3D63),
)

val SampleBanner = Color(0xFFF59E0B)
val SampleBannerInk = Color(0xFF1A1203)

@Composable
fun TokenyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}
