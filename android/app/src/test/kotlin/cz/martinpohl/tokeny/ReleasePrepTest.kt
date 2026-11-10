package cz.martinpohl.tokeny

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReleasePrepTest {
    @Test
    fun releaseSigningComesFromTheEnvironmentAndIsNotCommitted() {
        val gradle = file("build.gradle.kts").readText()
        listOf(
            "TOKENY_KEYSTORE_FILE",
            "TOKENY_KEYSTORE_PASSWORD",
            "TOKENY_KEY_ALIAS",
            "TOKENY_KEY_PASSWORD",
        ).forEach { assertTrue(gradle.contains(it)) }
        assertTrue(gradle.contains("pkcs12"))
        assertTrue(gradle.contains("isMinifyEnabled = false"))
        assertFalse(gradle.contains(".p12"))
        assertFalse(gradle.contains(".jks"))
        val ignore = file("../.gitignore").readText()
        assertTrue(ignore.contains("*.p12"))
        assertTrue(ignore.contains("*.jks"))
        assertTrue(ignore.contains("keystore.properties"))
    }

    @Test
    fun playListingStaysInsideTheConsoleLimits() {
        val limits = mapOf("title.txt" to 30, "short_description.txt" to 80, "full_description.txt" to 4000)
        listOf("cs-CZ", "en-US").forEach { locale ->
            limits.forEach { (name, limit) ->
                val text = file("../fastlane/metadata/android/$locale/$name").readText().trim()
                assertTrue("$locale $name is ${text.length}", text.length in 1..limit)
            }
        }
        val download = file("../../src/pages/AndroidDownload.tsx").readText()
        assertTrue(download.contains("92:BD:37:70:0B:21:01:1B:39:FA:C2:7D:8F:2D:4E:F9:9B:61:0A:D0:F9:E5:FD:97:C0:D7:2F:3A:5B:11:D6:2B"))
        assertTrue(download.contains("Doplní se po podepsaném sestavení."))
        assertFalse(download.contains("/support"))
        val privacy = file("../../src/pages/AndroidPrivacy.tsx").readText()
        assertTrue(privacy.contains("ACCESS_NETWORK_STATE"))
        assertTrue(privacy.contains("local-ledger.json"))
        assertTrue(privacy.contains("17256712"))
        val routes = file("../../src/App.tsx").readText()
        assertTrue(routes.contains("path=\"/android\""))
        assertTrue(routes.contains("path=\"/android/privacy\""))
        assertEquals(1, Regex("path=\"/privacy\"").findAll(routes).count())
    }

    private fun file(path: String): File {
        val direct = File(path)
        if (direct.exists()) return direct
        val nested = File("app/$path")
        if (nested.exists()) return nested
        error("missing $path from ${File(".").absolutePath}")
    }
}
