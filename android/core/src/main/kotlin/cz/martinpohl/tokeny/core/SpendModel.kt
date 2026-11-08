package cz.martinpohl.tokeny.core

enum class Destination { OVERVIEW, BREAKDOWN, BUDGET }

enum class PaneLayout { COMPACT, MEDIUM, EXPANDED }

/**
 * Material window-width breakpoints. Below 600dp is compact, below 840dp is medium,
 * and 840dp or more is expanded. A non-positive width is compact: the first frame
 * often reports 0 before the window is measured. A Galaxy Fold cover and an unfolded
 * inner display differ by this width. This function does not read a hinge angle.
 */
fun paneLayoutForWidthDp(widthDp: Int): PaneLayout = when {
    widthDp < 600 -> PaneLayout.COMPACT
    widthDp < 840 -> PaneLayout.MEDIUM
    else -> PaneLayout.EXPANDED
}

sealed interface Phase {
    data object SignedOut : Phase
    data object AuthGap : Phase
    data class Loading(val variant: DemoVariant) : Phase
    data class Ready(val variant: DemoVariant, val summary: UsageSummary) : Phase
    data class Failed(val variant: DemoVariant) : Phase
    data object ReadingImport : Phase
    data class ImportFailed(val error: ImportFileError) : Phase
    data class Previewing(val preview: ImportPreview) : Phase
    data class Local(val picture: LocalPicture) : Phase
    data object ConfirmClear : Phase
    data object LedgerUnreadable : Phase
}

/** Sample chrome stays up for the whole demo flow, including loading and failure. */
fun showsSampleBanner(phase: Phase): Boolean = when (phase) {
    is Phase.Loading, is Phase.Ready, is Phase.Failed -> true
    Phase.SignedOut, Phase.AuthGap, Phase.ReadingImport, is Phase.ImportFailed,
    is Phase.Previewing, is Phase.Local, Phase.ConfirmClear, Phase.LedgerUnreadable,
    -> false
}

data class SpendState(
    val phase: Phase,
    val destination: Destination,
    val currency: Currency,
    val offline: Boolean,
    val loadGeneration: Int,
    val ledger: List<StoredRow> = emptyList(),
)

/**
 * Single-threaded UI state. There is no signed-in phase: a successful load can only
 * become a labeled sample.
 */
class SpendModel(
    private val catalog: DemoCatalog = DemoCatalog(),
) {
    var state: SpendState = SpendState(
        phase = Phase.SignedOut,
        destination = Destination.OVERVIEW,
        currency = Currency.CZK,
        offline = false,
        loadGeneration = 0,
    )
        private set

    fun openAuthGap() {
        if (state.phase != Phase.SignedOut) return
        state = state.copy(phase = Phase.AuthGap)
    }

    fun closeAuthGap() {
        if (state.phase != Phase.AuthGap) return
        state = state.copy(phase = Phase.SignedOut)
    }

    fun requestDemo(variant: DemoVariant): Int {
        val generation = state.loadGeneration + 1
        state = state.copy(
            phase = Phase.Loading(variant),
            destination = Destination.OVERVIEW,
            loadGeneration = generation,
        )
        return generation
    }

    fun load(variant: DemoVariant): UsageSummary = catalog.load(variant)

    fun succeed(generation: Int, summary: UsageSummary) {
        val loading = state.phase as? Phase.Loading ?: return
        if (generation != state.loadGeneration) return
        state = state.copy(phase = Phase.Ready(loading.variant, summary))
    }

    fun fail(generation: Int) {
        val loading = state.phase as? Phase.Loading ?: return
        if (generation != state.loadGeneration) return
        state = state.copy(phase = Phase.Failed(loading.variant))
    }

    fun closeSample() {
        state = state.copy(
            phase = Phase.SignedOut,
            destination = Destination.OVERVIEW,
            loadGeneration = state.loadGeneration + 1,
        )
    }

    fun select(destination: Destination) {
        if (state.phase !is Phase.Ready && state.phase !is Phase.Local) return
        state = state.copy(destination = destination)
    }

    fun beginRead(): Int {
        val generation = state.loadGeneration + 1
        state = state.copy(phase = Phase.ReadingImport, loadGeneration = generation)
        return generation
    }

    fun failRead(generation: Int, error: ImportFileError) {
        if (generation != state.loadGeneration) return
        if (state.phase !is Phase.ReadingImport) return
        state = state.copy(phase = Phase.ImportFailed(error))
    }

    fun previewRead(generation: Int, preview: ImportPreview) {
        if (generation != state.loadGeneration) return
        if (state.phase !is Phase.ReadingImport) return
        state = state.copy(phase = Phase.Previewing(preview), destination = Destination.OVERVIEW)
    }

    fun discardPreview() {
        if (state.phase !is Phase.Previewing && state.phase !is Phase.ImportFailed) return
        state = state.copy(phase = homePhase(), destination = Destination.OVERVIEW)
    }

    fun cancelRead() {
        if (state.phase !is Phase.ReadingImport) return
        state = state.copy(
            phase = homePhase(),
            destination = Destination.OVERVIEW,
            loadGeneration = state.loadGeneration + 1,
        )
    }

    fun leaveLocal() {
        if (state.phase !is Phase.Local && state.phase != Phase.LedgerUnreadable) return
        state = state.copy(phase = Phase.SignedOut, destination = Destination.OVERVIEW)
    }

    /** Returns the rows to persist, or null when the preview cannot be saved. */
    fun confirmPreview(nowMillis: Long): List<StoredRow>? {
        val preview = (state.phase as? Phase.Previewing)?.preview ?: return null
        if (!preview.canSave) return null
        val rows = applyMerge(state.ledger, preview.rows, preview.policy)
        state = state.copy(
            ledger = rows,
            phase = Phase.Local(localPicture(rows, nowMillis)),
            destination = Destination.OVERVIEW,
        )
        return rows
    }

    fun showLocal(nowMillis: Long) {
        if (state.ledger.isEmpty()) return
        state = state.copy(
            phase = Phase.Local(localPicture(state.ledger, nowMillis)),
            destination = Destination.OVERVIEW,
        )
    }

    fun askClear() {
        if (state.ledger.isEmpty()) return
        state = state.copy(phase = Phase.ConfirmClear)
    }

    fun cancelClear() {
        if (state.phase != Phase.ConfirmClear) return
        state = state.copy(phase = homePhase())
    }

    fun clearLedger() {
        state = state.copy(ledger = emptyList(), phase = Phase.SignedOut, destination = Destination.OVERVIEW)
    }

    fun replaceLedger(rows: List<StoredRow>) {
        state = state.copy(ledger = rows)
    }

    fun markLedgerUnreadable() {
        state = state.copy(phase = Phase.LedgerUnreadable, ledger = emptyList())
    }

    private fun homePhase(): Phase =
        if (state.ledger.isEmpty()) Phase.SignedOut
        else Phase.Local(localPicture(state.ledger, System.currentTimeMillis()))

    fun setCurrency(currency: Currency) {
        state = state.copy(currency = currency)
    }

    fun setOffline(offline: Boolean) {
        state = state.copy(offline = offline)
    }
}
