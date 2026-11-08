package cz.martinpohl.tokeny

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class NativeShellTest {
    @Test
    fun manifestStaysNativeAndDoesNotOpenTheNetwork() {
        val manifest = file("src/main/AndroidManifest.xml").readText()
        assertFalse(manifest.contains("android.permission.INTERNET"))
        assertFalse(manifest.contains("WebView"))
        assertTrue(manifest.contains("android.permission.ACCESS_NETWORK_STATE"))
        assertTrue(manifest.contains("android:allowBackup=\"false\""))
        assertTrue(manifest.contains("usesCleartextTraffic=\"false\""))
    }

    @Test
    fun uiCodeDoesNotCollectSecretsOrWrapTheWeb() {
        val sources = file("src/main").walkTopDown()
            .filter { it.extension == "kt" }
            .joinToString("\n") { it.readText() }
        assertFalse(sources.contains("WebView"))
        assertFalse(sources.contains("TextField"))
        assertFalse(sources.contains("Authorization"))
        assertFalse(sources.contains("HttpURLConnection"))
        assertFalse(sources.contains("CredentialPolicy"))
        assertFalse(sources.contains("okhttp"))
        assertFalse(sources.contains("password"))
    }

    @Test
    fun gradleDoesNotPullABrowserOrABillingClient() {
        val gradle = file("build.gradle.kts").readText()
        assertFalse(gradle.contains("billing"))
        assertFalse(gradle.contains("webkit"))
        assertFalse(gradle.contains("okhttp"))
        assertFalse(gradle.contains("retrofit"))
    }

    @Test
    fun sampleCopyIsExplicitInBothLanguages() {
        val czech = strings("src/main/res/values/strings.xml")
        val english = strings("src/main/res/values-en/strings.xml")
        assertEquals(czech.keys, english.keys)
        assertEquals(names("src/main/res/values/strings.xml", "plurals"), names("src/main/res/values-en/strings.xml", "plurals"))
        assertTrue(czech.getValue("banner_sample").contains("UKÁZKA"))
        assertTrue(czech.getValue("banner_sample").contains("nejsou tvoje"))
        assertTrue(english.getValue("banner_sample").contains("SAMPLE"))
        assertTrue(english.getValue("banner_sample").contains("not your spend"))
        assertTrue(czech.getValue("auth_gap_p2").contains("401"))
        assertTrue(english.getValue("budget_missing_free").contains("does not sell Pro"))
        val joined = (czech.values + english.values).joinToString("\n").lowercase()
        assertFalse(joined.contains("stripe"))
        assertFalse(joined.contains("play.google.com"))
        assertFalse(joined.contains("buymeacoffee"))
        assertFalse(joined.contains("sk-ant"))
    }

    private fun strings(path: String): Map<String, String> {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file(path))
        val nodes = doc.getElementsByTagName("string")
        val out = linkedMapOf<String, String>()
        for (i in 0 until nodes.length) {
            val node = nodes.item(i) as Element
            out[node.getAttribute("name")] = node.textContent
        }
        return out
    }

    private fun names(path: String, tag: String): Set<String> {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file(path))
        val nodes = doc.getElementsByTagName(tag)
        return buildSet {
            for (i in 0 until nodes.length) {
                add((nodes.item(i) as Element).getAttribute("name"))
            }
        }
    }

    private fun file(path: String): File {
        val direct = File(path)
        if (direct.exists()) return direct
        val nested = File("app/$path")
        if (nested.exists()) return nested
        error("missing $path from ${File(".").absolutePath}")
    }
}
