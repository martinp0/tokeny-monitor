package cz.martinpohl.tokeny

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.DemoVariant
import cz.martinpohl.tokeny.core.Destination
import cz.martinpohl.tokeny.core.SpendModel
import cz.martinpohl.tokeny.core.SpendState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SpendViewModel : ViewModel() {
    private val model = SpendModel()
    private val states = MutableStateFlow(model.state)
    val state: StateFlow<SpendState> = states.asStateFlow()

    fun openAuthGap() = update { openAuthGap() }

    fun closeAuthGap() = update { closeAuthGap() }

    fun closeSample() = update { closeSample() }

    fun select(destination: Destination) = update { select(destination) }

    fun setCurrency(currency: Currency) = update { setCurrency(currency) }

    fun setOffline(offline: Boolean) = update { setOffline(offline) }

    fun requestDemo(variant: DemoVariant) {
        val generation = model.requestDemo(variant)
        publish()
        viewModelScope.launch {
            val loaded = runCatching {
                withContext(Dispatchers.Default) { model.load(variant) }
            }
            loaded.fold(
                onSuccess = { model.succeed(generation, it) },
                onFailure = { model.fail(generation) },
            )
            publish()
        }
    }

    private fun update(block: SpendModel.() -> Unit) {
        model.block()
        publish()
    }

    private fun publish() {
        states.value = model.state
    }
}
