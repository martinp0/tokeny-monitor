package cz.martinpohl.tokeny

import android.app.Activity
import android.app.Application
import android.app.Instrumentation
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.intent.Intents
import androidx.test.espresso.intent.Intents.intending
import androidx.test.espresso.intent.matcher.IntentMatchers.hasAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Drives the real activity, preview, confirm, disk reload, re-import, and delete.
 *
 * The system document picker is not opened. Espresso Intents answers
 * `ACTION_OPEN_DOCUMENT` with a content URI. That is a stubbed picker result,
 * not a DocumentsUI end-to-end run.
 */
@RunWith(AndroidJUnit4::class)
class ImportFlowTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private var scenario: ActivityScenario<MainActivity>? = null

    @Before
    fun setUp() {
        Intents.init()
        File(app.filesDir, "local-ledger.json").delete()
        device.pressHome()
    }

    @After
    fun tearDown() {
        scenario?.close()
        Intents.release()
        File(app.filesDir, "local-ledger.json").delete()
    }

    @Test
    fun openRouterPreviewCountsPersistAcrossRestartAndDelete() {
        val uri = stage("openrouter.csv", OPENROUTER)
        answerPicker(uri)
        launch()
        click(text(R.string.action_import_csv))
        waitFor(text(R.string.preview_title))
        waitFor(
            text(
                R.string.preview_counts,
                /* accepted */ 1,
                /* data rows */ 3,
                /* new */ 1,
                /* overwrite */ 0,
                /* already stored */ 0,
            ),
        )
        waitFor(text(R.string.preview_skip, text(R.string.skip_missing_id), 1))
        click(text(R.string.action_confirm_save))
        waitFor(text(R.string.import_banner))
        waitFor("$4.00")
        assertTrue(File(app.filesDir, "local-ledger.json").readText().contains("keep-1"))

        relaunch()
        click(text(R.string.action_open_import))
        waitFor(text(R.string.import_banner))
        waitFor("$4.00")

        click(text(R.string.action_back))
        click(text(R.string.action_import_csv))
        waitFor(
            text(
                R.string.preview_counts,
                1,
                3,
                /* new */ 0,
                /* overwrite */ 1,
                0,
            ),
        )
        click(text(R.string.action_discard_import))
        // A discarded re-import returns to the saved import, which is still on disk.
        waitFor(text(R.string.import_banner))
        waitFor("$4.00")
        click(text(R.string.action_remove_import))
        click(text(R.string.action_confirm_delete))
        assertGone(text(R.string.action_open_import))
        assertFalse(File(app.filesDir, "local-ledger.json").exists())

        relaunch()
        assertGone(text(R.string.action_open_import))
        assertTrue(device.hasObject(By.text(text(R.string.action_import_csv))))
    }

    @Test
    fun usageExportReimportKeepsTheStoredRow() {
        val uri = stage("usage.csv", USAGE)
        answerPicker(uri)
        launch()
        click(text(R.string.action_import_csv))
        waitFor(
            text(
                R.string.preview_counts,
                /* accepted */ 1,
                /* data rows */ 2,
                /* new */ 1,
                0,
                0,
            ),
        )
        waitFor(text(R.string.preview_skip, text(R.string.skip_currency), 1))
        click(text(R.string.action_confirm_save))
        waitFor("$1.00")

        relaunch()
        click(text(R.string.action_import_csv))
        waitFor(
            text(
                R.string.preview_counts,
                1,
                2,
                /* new */ 0,
                0,
                /* already stored */ 1,
            ),
        )
        click(text(R.string.action_confirm_save))
        waitFor("$1.00")
        val ledger = File(app.filesDir, "local-ledger.json").readText()
        assertTrue(ledger.contains("id-keep"))
        assertFalse(ledger.contains("9.00"))
    }

    private fun answerPicker(uri: Uri) {
        intending(hasAction(Intent.ACTION_OPEN_DOCUMENT)).respondWith(
            Instrumentation.ActivityResult(
                Activity.RESULT_OK,
                Intent().setData(uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
            ),
        )
    }

    private fun stage(name: String, csv: String): Uri {
        val dir = File(app.cacheDir, "inbox").apply { mkdirs() }
        val file = File(dir, name)
        file.writeText(csv)
        return FileProvider.getUriForFile(app, "${app.packageName}.debugfileprovider", file)
    }

    private fun launch() {
        scenario?.close()
        scenario = ActivityScenario.launch(MainActivity::class.java)
        device.wait(Until.hasObject(By.pkg(app.packageName)), 8_000)
    }

    private fun relaunch() {
        scenario?.onActivity { it.finishAndRemoveTask() }
        scenario?.close()
        scenario = null
        device.wait(Until.gone(By.pkg(app.packageName)), 5_000)
        launch()
        waitFor(text(R.string.action_import_csv))
    }

    private fun text(id: Int, vararg args: Any): String =
        if (args.isEmpty()) app.getString(id) else app.getString(id, *args)

    private fun click(label: String) {
        val node = device.wait(Until.findObject(By.text(label)), 8_000)
            ?: scrollTo(label)
        checkNotNull(node) { dump("missing click: $label") }
        node.click()
        device.waitForIdle(1_000)
    }

    private fun waitFor(label: String) {
        val found = device.wait(Until.hasObject(By.text(label)), 8_000) ||
            scrollUntil(label)
        check(found) { dump("missing text: $label") }
    }

    private fun assertGone(label: String) {
        device.wait(Until.gone(By.text(label)), 4_000)
        assertFalse(dump("still visible: $label"), device.hasObject(By.text(label)))
    }

    private fun scrollTo(label: String) = if (scrollUntil(label)) device.findObject(By.text(label)) else null

    private fun scrollUntil(label: String): Boolean {
        val scrollable = device.findObject(By.scrollable(true)) ?: return false
        repeat(4) {
            if (device.hasObject(By.text(label))) return true
            scrollable.scroll(androidx.test.uiautomator.Direction.DOWN, 0.7f)
        }
        return device.hasObject(By.text(label))
    }

    private fun dump(reason: String): String {
        val lines = device.findObjects(By.textStartsWith("")).mapNotNull { it.text }.filter { it.isNotBlank() }
        return reason + "\n" + lines.joinToString(" | ")
    }

    private companion object {
        val OPENROUTER = """
            generation_id,created_at,cost_total,model_permaslug,provider_name
            keep-1,2026-10-25 00:30:00,2.00,openai/gpt,OpenAI
            ,2026-10-25 01:00:00,9,m,P
            keep-1,2026-10-25 00:30:00,4.00,openai/gpt,OpenAI
        """.trimIndent() + "\n"

        val USAGE = """
            Billing Item ID,Event Time,Product,Usage,Pricing Currency,Pricing Contracted
            id-keep,2026-10-22T09:15:00Z,cursor,{},USD,1.00
            id-eur,2026-10-22T10:00:00Z,cursor,{},EUR,9.00
        """.trimIndent() + "\n"
    }
}
