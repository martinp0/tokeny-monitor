package cz.martinpohl.tokeny.core

import org.junit.Assert.assertTrue
import org.junit.Test

class SpendPaletteTest {
    @Test
    fun lightAndDarkRolesClearTheirBackgrounds() {
        val failures = (contrastChecks(SpendPalette.light, "light") + contrastChecks(SpendPalette.dark, "dark"))
            .map { check -> check to contrastRatio(check.foreground, check.background) }
            .filter { (check, ratio) -> ratio < check.minimum }
        assertTrue(
            failures.joinToString("\n") { (check, ratio) ->
                "${check.name} ${rgbHex(check.foreground)} on ${rgbHex(check.background)} is ${"%.2f".format(ratio)}, needs ${check.minimum}"
            },
            failures.isEmpty(),
        )
    }

    @Test
    fun brandPurpleIsNotAPageBackground() {
        val purple = 0xFF2E1065
        assertTrue(contrastRatio(SpendPalette.light.onBackground, purple) < 4.5)
        assertTrue(contrastRatio(SpendPalette.light.primary, purple) < 3.0)
        assertTrue(SpendPalette.light.background != purple)
        assertTrue(SpendPalette.dark.background != purple)
    }
}
