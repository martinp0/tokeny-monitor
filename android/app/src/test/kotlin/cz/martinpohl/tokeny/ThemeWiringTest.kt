package cz.martinpohl.tokeny

import cz.martinpohl.tokeny.core.SpendPalette
import cz.martinpohl.tokeny.core.rgbHex
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ThemeWiringTest {
    @Test
    fun windowBackgroundFollowsTheSchemeInBothModes() {
        assertEquals(rgbHex(SpendPalette.light.background), color("src/main/res/values/colors.xml"))
        assertEquals(rgbHex(SpendPalette.dark.background), color("src/main/res/values-night/colors.xml"))
        val theme = file("src/main/res/values/themes.xml").readText()
        assertTrue(theme.contains("@color/window_background"))
        assertTrue(theme.contains("android:forceDarkAllowed"))
        assertTrue(theme.contains("tools:targetApi=\"29\">false"))
        assertTrue(!theme.contains("#2E1065"))
    }

    @Test
    fun pagePaintsSchemeBackgroundAndOnBackground() {
        val theme = file("src/main/kotlin/cz/martinpohl/tokeny/ui/Theme.kt").readText()
        val activity = file("src/main/kotlin/cz/martinpohl/tokeny/MainActivity.kt").readText()
        assertTrue(theme.contains("color = MaterialTheme.colorScheme.background"))
        assertTrue(theme.contains("contentColor = MaterialTheme.colorScheme.onBackground"))
        assertTrue(theme.contains("SpendPalette.light"))
        assertTrue(theme.contains("SpendPalette.dark"))
        assertTrue(activity.contains("TokenyPage"))
    }

    private fun color(path: String): String {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file(path))
        val nodes = doc.getElementsByTagName("color")
        for (i in 0 until nodes.length) {
            val node = nodes.item(i)
            if (node.attributes.getNamedItem("name").nodeValue == "window_background") {
                return node.textContent.trim()
            }
        }
        error("window_background missing from $path")
    }

    private fun file(path: String): File {
        val direct = File(path)
        if (direct.exists()) return direct
        val nested = File("app/$path")
        if (nested.exists()) return nested
        error("missing $path from ${File(".").absolutePath}")
    }
}
