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
}

/** Sample chrome stays up for the whole demo flow, including loading and failure. */
fun showsSampleBanner(phase: Phase): Boolean = when (phase) {
    is Phase.Loading, is Phase.Ready, is Phase.Failed -> true
    Phase.SignedOut, Phase.AuthGap -> false
}

data class SpendState(
    val phase: Phase,
    val destination: Destination,
    val currency: Currency,
    val offline: Boolean,
    val loadGeneration: Int,
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
        if (state.phase !is Phase.Ready) return
        state = state.copy(destination = destination)
    }

    fun setCurrency(currency: Currency) {
        state = state.copy(currency = currency)
    }

    fun setOffline(offline: Boolean) {
        state = state.copy(offline = offline)
    }
}
