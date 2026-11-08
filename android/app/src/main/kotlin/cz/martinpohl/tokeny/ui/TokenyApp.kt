package cz.martinpohl.tokeny.ui

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import cz.martinpohl.tokeny.R
import cz.martinpohl.tokeny.SpendViewModel
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.DemoVariant
import cz.martinpohl.tokeny.core.Destination
import cz.martinpohl.tokeny.core.PaneLayout
import cz.martinpohl.tokeny.core.Phase
import cz.martinpohl.tokeny.core.SpendState
import cz.martinpohl.tokeny.core.paneLayoutForWidthDp
import cz.martinpohl.tokeny.core.showsSampleBanner

@Composable
fun TokenyApp(viewModel: SpendViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    OfflineBinding(viewModel)
    val widthDp = with(LocalDensity.current) {
        LocalWindowInfo.current.containerSize.width.toDp().value
    }
    val layout = paneLayoutForWidthDp(widthDp.roundToInt())
    BackHandler(enabled = state.phase is Phase.AuthGap) { viewModel.closeAuthGap() }
    BackHandler(enabled = showsSampleBanner(state.phase)) { viewModel.closeSample() }

    Column(
        Modifier
            .fillMaxSize()
            .safeDrawingPadding()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            PhaseContent(state, layout, viewModel)
        }
    }
}

@Composable
private fun PhaseContent(state: SpendState, layout: PaneLayout, viewModel: SpendViewModel) {
    when (val phase = state.phase) {
            Phase.SignedOut -> SignedOutScreen(
                offline = state.offline,
                onOpenPro = { viewModel.requestDemo(DemoVariant.PRO) },
                onOpenFree = { viewModel.requestDemo(DemoVariant.FREE) },
                onOpenEmpty = { viewModel.requestDemo(DemoVariant.EMPTY) },
                onWhy = viewModel::openAuthGap,
            )
            Phase.AuthGap -> AuthGapScreen(onBack = viewModel::closeAuthGap)
            is Phase.Loading -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SampleBanner(state.offline)
                LoadingSampleScreen()
            }
            is Phase.Failed -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SampleBanner(state.offline)
                FailedSampleScreen(
                    onRetry = { viewModel.requestDemo(phase.variant) },
                    onClose = viewModel::closeSample,
                )
            }
            is Phase.Ready -> ReadyShell(
                state = state,
                summaryPhase = phase,
                layout = layout,
                onSelect = viewModel::select,
                onCurrency = viewModel::setCurrency,
                onClose = viewModel::closeSample,
            )
    }
}

@Composable
private fun ReadyShell(
    state: SpendState,
    summaryPhase: Phase.Ready,
    layout: PaneLayout,
    onSelect: (Destination) -> Unit,
    onCurrency: (Currency) -> Unit,
    onClose: () -> Unit,
) {
    Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        if (layout != PaneLayout.COMPACT) {
            SampleRail(state.destination, onSelect)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SampleBanner(state.offline)
            DemoHeader(state.currency, onCurrency, onClose)
            Column(
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                when (state.destination) {
                    Destination.OVERVIEW -> OverviewScreen(summaryPhase.summary, state.currency, layout)
                    Destination.BREAKDOWN -> BreakdownScreen(summaryPhase.summary, state.currency, layout)
                    Destination.BUDGET -> BudgetScreen(summaryPhase.summary, summaryPhase.variant, state.currency, layout)
                }
            }
            if (layout == PaneLayout.COMPACT) {
                SampleBar(state.destination, onSelect)
            }
        }
    }
}

@Composable
private fun DemoHeader(currency: Currency, onCurrency: (Currency) -> Unit, onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        val currencyDescription = stringResource(R.string.cd_currency)
        SingleChoiceSegmentedButtonRow(
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 48.dp)
                .semantics { contentDescription = currencyDescription },
        ) {
            SegmentedButton(
                selected = currency == Currency.CZK,
                onClick = { onCurrency(Currency.CZK) },
                shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                label = { Text(stringResource(R.string.currency_czk)) },
            )
            SegmentedButton(
                selected = currency == Currency.USD,
                onClick = { onCurrency(Currency.USD) },
                shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                label = { Text(stringResource(R.string.currency_usd)) },
            )
        }
        TextButton(onClick = onClose, modifier = Modifier.heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_close_sample))
        }
    }
}

@Composable
private fun SampleBar(selected: Destination, onSelect: (Destination) -> Unit) {
    NavigationBar {
        NavigationBarItem(
            selected = selected == Destination.OVERVIEW,
            onClick = { onSelect(Destination.OVERVIEW) },
            icon = { Icon(Icons.Filled.Home, contentDescription = null) },
            label = { Text(stringResource(R.string.nav_overview)) },
        )
        NavigationBarItem(
            selected = selected == Destination.BREAKDOWN,
            onClick = { onSelect(Destination.BREAKDOWN) },
            icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) },
            label = { Text(stringResource(R.string.nav_breakdown)) },
        )
        NavigationBarItem(
            selected = selected == Destination.BUDGET,
            onClick = { onSelect(Destination.BUDGET) },
            icon = { Icon(Icons.Filled.DateRange, contentDescription = null) },
            label = { Text(stringResource(R.string.nav_budget)) },
        )
    }
}

@Composable
private fun SampleRail(selected: Destination, onSelect: (Destination) -> Unit) {
    NavigationRail(containerColor = MaterialTheme.colorScheme.background) {
        NavigationRailItem(
            selected = selected == Destination.OVERVIEW,
            onClick = { onSelect(Destination.OVERVIEW) },
            icon = { Icon(Icons.Filled.Home, contentDescription = stringResource(R.string.cd_nav_overview)) },
            label = { Text(stringResource(R.string.nav_overview)) },
        )
        NavigationRailItem(
            selected = selected == Destination.BREAKDOWN,
            onClick = { onSelect(Destination.BREAKDOWN) },
            icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = stringResource(R.string.cd_nav_breakdown)) },
            label = { Text(stringResource(R.string.nav_breakdown)) },
        )
        NavigationRailItem(
            selected = selected == Destination.BUDGET,
            onClick = { onSelect(Destination.BUDGET) },
            icon = { Icon(Icons.Filled.DateRange, contentDescription = stringResource(R.string.cd_nav_budget)) },
            label = { Text(stringResource(R.string.nav_budget)) },
        )
    }
}

@Composable
private fun OfflineBinding(viewModel: SpendViewModel) {
    val context = LocalContext.current
    DisposableEffect(viewModel) {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        if (manager == null) {
            onDispose { }
        } else {
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    viewModel.setOffline(manager.isOffline())
                }

                override fun onLost(network: Network) {
                    viewModel.setOffline(true)
                }

                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    viewModel.setOffline(manager.isOffline())
                }
            }
            viewModel.setOffline(manager.isOffline())
            val registered = runCatching { manager.registerDefaultNetworkCallback(callback) }.isSuccess
            onDispose {
                if (registered) {
                    runCatching { manager.unregisterNetworkCallback(callback) }
                }
            }
        }
    }
}

private fun ConnectivityManager.isOffline(): Boolean {
    val network = activeNetwork ?: return true
    val capabilities = getNetworkCapabilities(network) ?: return true
    return !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}
