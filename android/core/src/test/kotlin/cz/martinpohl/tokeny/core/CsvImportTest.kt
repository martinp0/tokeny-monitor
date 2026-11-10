package cz.martinpohl.tokeny.core

import java.io.File
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CsvImportTest {
    @Test
    fun pragueDayFollowsDstBoundaries() {
        fun day(iso: String) = PragueTime.day(Instant.parse(iso).toEpochMilli())
        assertEquals("2026-03-28", day("2026-03-28T22:30:00Z"))
        assertEquals("2026-03-29", day("2026-03-28T23:30:00Z"))
        assertEquals("2026-10-24", day("2026-10-24T21:30:00Z"))
        assertEquals("2026-10-25", day("2026-10-24T22:30:00Z"))
        assertEquals("2026-10-25", day("2026-10-25T00:30:00Z"))
        assertEquals("2026-10-25", day("2026-10-25T01:30:00Z"))
    }

    @Test
    fun naiveClockIsPragueWallTimeIncludingTheGapAndOverlap() {
        val evening = PragueTime.parseEpochMillis("2026-05-13 23:30:00.000")!!
        assertEquals("2026-05-13", PragueTime.day(evening))
        val gap = PragueTime.parseEpochMillis("2026-03-29 02:30:00")!!
        assertEquals("2026-03-29", PragueTime.day(gap))
        assertEquals(Instant.parse("2026-03-29T01:30:00Z").toEpochMilli(), gap)
        val overlap = PragueTime.parseEpochMillis("2026-10-25 02:30:00")!!
        assertEquals("2026-10-25", PragueTime.day(overlap))
        assertEquals(Instant.parse("2026-10-25T00:30:00Z").toEpochMilli(), overlap)
        assertNull(PragueTime.parseEpochMillis("yesterday"))
    }

    @Test
    fun usageExportMatchesWebFixture() {
        val text = fixture("usage-export-sample.csv")
        val read = readCsv("usage.csv", text.toByteArray(), emptyList()) as CsvRead.Ok
        val preview = read.preview
        assertEquals(CsvFormat.USAGE_EXPORT, preview.format)
        assertEquals(ConflictPolicy.IGNORE, preview.policy)
        assertEquals(10, preview.diagnostics.dataRows)
        assertEquals(6, preview.diagnostics.accepted)
        assertEquals(1, preview.diagnostics.duplicatesInFile)
        assertEquals(1, preview.diagnostics.skipped[SkipReason.MISSING_ID])
        assertEquals(1, preview.diagnostics.skipped[SkipReason.UNKNOWN_PRODUCT])
        assertEquals(1, preview.diagnostics.skipped[SkipReason.CURRENCY])
        val byId = preview.rows.associateBy { it.generationId.takeLast(1) }
        assertEquals("grok-bot", byId.getValue("1").providerSource)
        assertEquals("Grok Bot", byId.getValue("1").provider)
        assertEquals("grok-bot", byId.getValue("1").model)
        assertEquals(32100L, byId.getValue("1").tokensPrompt)
        assertEquals(30000L, byId.getValue("1").tokensCached)
        assertEquals(2000L, byId.getValue("1").tokensCacheWrite)
        assertEquals(300L, byId.getValue("1").tokensCompletion)
        assertEquals(0.0, byId.getValue("1").costUsd, 0.0)
        assertEquals("included", byId.getValue("1").billingType)
        assertEquals("2026-10-22T09:15:00.000Z", byId.getValue("1").createdAt)
        assertEquals("2026-10-22", byId.getValue("1").pragueDay)
        assertEquals(0.125, byId.getValue("4").costUsd, 0.0000001)
        assertEquals("claude-4.5-sonnet", byId.getValue("4").model)
        assertEquals("on_demand", byId.getValue("4").billingType)
        assertEquals(900L, byId.getValue("5").tokensPrompt)
        assertEquals("credits", byId.getValue("5").billingType)
        assertEquals(0L, byId.getValue("6").tokensPrompt)
        val dumped = preview.rows.joinToString { it.model + it.provider + it.generationId }
        assertFalse(dumped.contains("example.com"))
        assertFalse(dumped.contains("user_demo"))
    }

    @Test
    fun usageExportAliasesAndReimportKeepTheFirstRow() {
        val csv = """
            billing_item_id,timestamp,product,usage_type,currency,cost,model,input_tokens,cached_tokens,cache_write_tokens,output_tokens,user_email
            a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,${'$'}0.50,grok-4.3,100,2000,30,40,x@example.com
            a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,${'$'}9.00,grok-4.3,1,0,0,1,x@example.com
            a2,2026-10-22T10:00:00Z,cursor,included,USD,0,,10,0,0,5,x@example.com
        """.trimIndent()
        val first = (readCsv("a.csv", csv.toByteArray(), emptyList()) as CsvRead.Ok).preview
        assertEquals(1, first.diagnostics.duplicatesInFile)
        assertEquals(2, first.rows.size)
        assertEquals(0.5, first.rows.first { it.generationId == "a1" }.costUsd, 0.0001)
        assertEquals(2130L, first.rows.first { it.generationId == "a1" }.tokensPrompt)
        assertFalse(first.rows.joinToString().contains("x@example.com"))
        val stored = applyMerge(emptyList(), first.rows, first.policy)
        val again = (readCsv("a.csv", csv.toByteArray(), stored) as CsvRead.Ok).preview
        assertEquals(0, again.merge.toInsert)
        assertEquals(2, again.merge.alreadyStored)
        assertEquals(0, again.merge.toOverwrite)
        val kept = applyMerge(stored, again.rows, again.policy)
        assertEquals(0.5, kept.first { it.generationId == "a1" }.costUsd, 0.0001)
    }

    @Test
    fun openRouterLastWinsAndReimportOverwrites() {
        val header = "generation_id,created_at,cost_total,tokens_prompt,tokens_completion,model_permaslug,provider_name"
        val csv = "$header\r\ngen-1,2026-05-13 23:30:00.000,1.5,10,1,anthropic/claude,Anthropic\r\n" +
            "gen-1,2026-05-13 23:30:00.000,2.5,10,1,anthropic/claude,Anthropic\r\n" +
            ",2026-05-13 01:00:00,9,1,1,x,Y\r\n"
        val preview = (readCsv("or.csv", csv.toByteArray(), emptyList()) as CsvRead.Ok).preview
        assertEquals(CsvFormat.OPENROUTER, preview.format)
        assertEquals(ConflictPolicy.UPSERT, preview.policy)
        assertEquals(1, preview.rows.size)
        assertEquals(2.5, preview.rows[0].costUsd, 0.0)
        assertEquals("2026-05-13", preview.rows[0].pragueDay)
        assertEquals(1, preview.diagnostics.duplicatesInFile)
        assertEquals(1, preview.diagnostics.skipped[SkipReason.MISSING_ID])
        val stored = applyMerge(emptyList(), preview.rows, preview.policy)
        val update = "$header\ngen-1,2026-05-14 01:00:00,9,1,1,openai/gpt,OpenAI\n"
        val second = (readCsv("or.csv", update.toByteArray(), stored) as CsvRead.Ok).preview
        assertEquals(1, second.merge.toOverwrite)
        assertEquals(0, second.merge.toInsert)
        val merged = applyMerge(stored, second.rows, second.policy)
        assertEquals(1, merged.size)
        assertEquals(9.0, merged[0].costUsd, 0.0)
        assertEquals("OpenAI", merged[0].provider)
    }

    @Test
    fun commaDecimalIsSkippedAndGarbageCostIsZero() {
        val header = "generation_id,created_at,cost_total,model_permaslug,provider_name"
        val comma = "$header\na,2026-05-13 01:00:00,\"0,50\",m,P\nb,2026-05-13 01:00:00,abc,m,P\n"
        val preview = (readCsv("c.csv", comma.toByteArray(), emptyList()) as CsvRead.Ok).preview
        assertEquals(1, preview.diagnostics.skipped[SkipReason.AMBIGUOUS_DECIMAL])
        assertEquals(1, preview.diagnostics.partialNumbers)
        assertEquals(0.0, preview.rows.single().costUsd, 0.0)
        assertEquals("b", preview.rows.single().generationId)
    }

    @Test
    fun usageCommaDecimalIsNotMultiplied() {
        val csv = "Billing Item ID,Event Time,Product,Usage,Pricing Currency,Pricing Contracted\n" +
            "id1,2026-10-22T09:15:00Z,cursor,{},USD,\"0,50\"\n" +
            "id2,2026-10-22T09:15:00Z,cursor,{},USD,\"\$1,234.50\"\n"
        val preview = (readCsv("u.csv", csv.toByteArray(), emptyList()) as CsvRead.Ok).preview
        assertEquals(1, preview.diagnostics.skipped[SkipReason.AMBIGUOUS_DECIMAL])
        assertEquals(1234.50, preview.rows.single().costUsd, 0.001)
    }

    @Test
    fun malformedQuoteAndUnknownHeaderAndSize() {
        assertEquals(
            ImportFileError.MALFORMED,
            (readCsv("b.csv", "a,b\n\"unterminated,1\n".toByteArray(), emptyList()) as CsvRead.Failed).error,
        )
        assertEquals(
            ImportFileError.UNRECOGNIZED,
            (readCsv("b.csv", "foo,bar\n1,2\n".toByteArray(), emptyList()) as CsvRead.Failed).error,
        )
        assertEquals(
            ImportFileError.TOO_LARGE,
            (readCsv("b.csv", ByteArray(CsvLimits.MAX_FILE_BYTES + 1), emptyList()) as CsvRead.Failed).error,
        )
    }

    @Test
    fun localPictureUsesTheLatestPragueMonthAndDoesNotInventARate() {
        val csv = "generation_id,created_at,cost_total,tokens_prompt,tokens_completion,model_permaslug,provider_name\n" +
            "a,2026-10-24 23:30:00,1.5,10,1,anthropic/claude-sonnet,Anthropic\n" +
            "b,2026-10-25 00:30:00,2.5,4,1,openai/gpt,OpenAI\n"
        val rows = (readCsv("m.csv", csv.toByteArray(), emptyList()) as CsvRead.Ok).preview.rows
        assertEquals("2026-10-24", rows.first { it.generationId == "a" }.pragueDay)
        assertEquals("2026-10-25", rows.first { it.generationId == "b" }.pragueDay)
        val now = Instant.parse("2026-11-08T12:00:00Z").toEpochMilli()
        val picture = localPicture(rows, now)
        assertEquals("2026-11-08", picture.pragueToday)
        assertEquals(0.0, picture.todayCostUsd, 0.0)
        assertEquals("2026-10", picture.focusMonth)
        assertEquals(4.0, picture.focusMonthCostUsd, 0.0)
        assertEquals(31, picture.daily.size)
        assertEquals("claude-sonnet", shortModelName(picture.models.first { it.costUsd == 1.5 }.name))
        assertNull(picture.billing)
        val file = File.createTempFile("ledger", ".json")
        val store = LedgerFile(file)
        store.save(rows)
        val loaded = store.load() as LedgerLoad.Ready
        assertEquals(rows.map { it.generationId }, loaded.rows.map { it.generationId })
        file.writeText("{")
        assertTrue(store.load() is LedgerLoad.Unreadable)
    }

    @Test
    fun demoPhaseStaysSeparateFromALocalLedger() {
        val model = SpendModel()
        val csv = "generation_id,created_at,cost_total\nok,2026-10-01 00:00:00,3\n"
        val preview = (readCsv("t.csv", csv.toByteArray(), emptyList()) as CsvRead.Ok).preview
        val generation = model.beginRead()
        model.previewRead(generation, preview)
        assertFalse(showsSampleBanner(model.state.phase))
        val saved = model.confirmPreview(Instant.parse("2026-11-08T12:00:00Z").toEpochMilli())!!
        assertEquals(1, saved.size)
        assertTrue(model.state.phase is Phase.Local)
        assertFalse(showsSampleBanner(model.state.phase))
        val demo = model.requestDemo(DemoVariant.EMPTY)
        model.succeed(demo, model.load(DemoVariant.EMPTY))
        assertTrue(showsSampleBanner(model.state.phase))
        assertTrue(model.state.phase is Phase.Ready)
        assertEquals(1, model.state.ledger.size)
        model.closeSample()
        model.showLocal(Instant.parse("2026-11-08T12:00:00Z").toEpochMilli())
        assertEquals(3.0, (model.state.phase as Phase.Local).picture.allCostUsd, 0.0)
        model.clearLedger()
        assertTrue(model.state.ledger.isEmpty())
        assertTrue(model.state.phase is Phase.SignedOut)
    }

    private fun fixture(name: String): String {
        val candidates = listOf(
            File("src/test/fixtures/$name"),
            File("../../src/test/fixtures/$name"),
            File("../src/test/fixtures/$name"),
        )
        return candidates.first { it.exists() }.readText()
    }
}
