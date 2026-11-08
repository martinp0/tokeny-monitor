package cz.martinpohl.tokeny

import android.content.res.Configuration
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import cz.martinpohl.tokeny.core.DailySpend
import cz.martinpohl.tokeny.core.LocalPicture
import cz.martinpohl.tokeny.core.PaneLayout
import cz.martinpohl.tokeny.ui.LocalOverview
import cz.martinpohl.tokeny.ui.TokenyPage
import cz.martinpohl.tokeny.ui.TokenyTheme
import kotlin.math.sqrt
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/**
 * Renders the saved-import overview in both system modes and reads pixels.
 * The page background has to be the scheme background, and the text, text buttons,
 * and chart bar have to clear that background. A stubbed document picker is not involved.
 */
class ThemeContrastTest {
    @get:Rule
    val compose = createComposeRule()

    private val strings = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun lightImportOverviewClearsThePage() = assertOverview(night = false)

    @Test
    fun darkImportOverviewClearsThePage() = assertOverview(night = true)

    private fun assertOverview(night: Boolean) {
        val expectedBackground = if (night) 0xFF120E1A else 0xFFF7F4FB
        val back = strings.getString(R.string.action_back)
        val delete = strings.getString(R.string.action_remove_import)
        compose.setContent {
            val current = LocalConfiguration.current
            val forced = Configuration(current)
            forced.uiMode = (forced.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            CompositionLocalProvider(LocalConfiguration provides forced) {
                TokenyTheme {
                    TokenyPage {
                        Column(Modifier.testTag("page").padding(16.dp)) {
                            TextButton(onClick = {}, modifier = Modifier.testTag("back")) {
                                Text(back)
                            }
                            TextButton(onClick = {}, modifier = Modifier.testTag("delete")) {
                                Text(delete)
                            }
                            LocalOverview(samplePicture(), PaneLayout.COMPACT)
                        }
                    }
                }
            }
        }
        compose.waitForIdle()
        val background = compose.onNodeWithTag("page").captureToImage().toPixelMap().let { it[2, 2] }
        assertClose(background, expectedBackground, "page background")
        val mode = if (night) "dark" else "light"
        assertInk(compose.onNodeWithText(spanText(), substring = true).captureToImage(), background, 4.5, "$mode date span")
        assertInk(compose.onNodeWithText(sourcesText(), substring = true).captureToImage(), background, 4.5, "$mode sources")
        assertInk(compose.onNodeWithText(chartTitle(), substring = true).captureToImage(), background, 4.5, "$mode chart title")
        assertInk(compose.onNodeWithTag("back").captureToImage(), background, 4.5, "$mode back")
        assertInk(compose.onNodeWithTag("delete").captureToImage(), background, 4.5, "$mode delete")
        val bar = compose.onNodeWithTag("spend-bars").captureToImage().toPixelMap()
        val center = bar[bar.width / 2, bar.height / 2]
        val barContrast = center.contrastAgainst(background)
        assertTrue("$mode chart bar contrast $barContrast", barContrast >= 3.0)
        assertTrue("$mode chart bar is not the page color", center.distanceTo(background) > 0.25f)
    }

    private fun spanText(): String = strings.getString(R.string.local_span, "2026-10-25", "2026-10-25")

    private fun sourcesText(): String = strings.getString(R.string.local_sources, "openrouter")

    private fun chartTitle(): String = strings.getString(R.string.local_chart)

    private fun assertInk(image: ImageBitmap, background: Color, minimum: Double, label: String) {
        val ratio = image.toPixelMap().coreInkContrast(background)
        assertTrue("$label contrast $ratio", ratio >= minimum)
    }

    private fun assertClose(actual: Color, expected: Long, label: String) {
        val target = Color(expected.toInt())
        assertTrue(
            "$label ${actual.red},${actual.green},${actual.blue} is not ${target.red},${target.green},${target.blue}",
            actual.distanceTo(target) < 0.04f,
        )
    }
}

private fun samplePicture() = LocalPicture(
    rowCount = 1,
    sources = listOf("openrouter"),
    firstDay = "2026-10-25",
    lastDay = "2026-10-25",
    allCostUsd = 4.0,
    allTokens = 11,
    allRequests = 1,
    pragueToday = "2026-11-08",
    todayCostUsd = 0.0,
    focusMonth = "2026-10",
    focusMonthCostUsd = 4.0,
    focusMonthTokens = 11,
    focusMonthRequests = 1,
    previousMonth = null,
    previousMonthCostUsd = null,
    daily = listOf(DailySpend("2026-10-25", 4.0)),
    providers = emptyList(),
    models = emptyList(),
    billing = null,
)

private fun PixelMap.coreInkContrast(background: Color): Double {
    val samples = mutableListOf<Color>()
    for (y in 0 until height) {
        for (x in 0 until width) {
            val pixel = this[x, y]
            if (pixel.alpha < 0.9f) continue
            if (pixel.distanceTo(background) > 0.2f) samples += pixel
        }
    }
    check(samples.isNotEmpty()) { "no ink pixels" }
    val ranked = samples.sortedByDescending { it.distanceTo(background) }
    val core = ranked.take((ranked.size * 0.25).toInt().coerceAtLeast(1))
    return core.minOf { it.contrastAgainst(background) }
}

private fun Color.distanceTo(other: Color): Float {
    val dr = red - other.red
    val dg = green - other.green
    val db = blue - other.blue
    return sqrt(dr * dr + dg * dg + db * db)
}

private fun Color.contrastAgainst(other: Color): Double {
    fun channel(value: Float): Double {
        val scaled = value.toDouble()
        return if (scaled <= 0.04045) scaled / 12.92 else Math.pow((scaled + 0.055) / 1.055, 2.4)
    }
    fun luminance(color: Color) = 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    val lighter = maxOf(luminance(this), luminance(other))
    val darker = minOf(luminance(this), luminance(other))
    return (lighter + 0.05) / (darker + 0.05)
}
