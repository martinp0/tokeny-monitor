package cz.martinpohl.tokeny

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.CsvRead
import cz.martinpohl.tokeny.core.DemoVariant
import cz.martinpohl.tokeny.core.Destination
import cz.martinpohl.tokeny.core.ImportFileError
import cz.martinpohl.tokeny.core.LedgerFile
import cz.martinpohl.tokeny.core.LedgerLoad
import cz.martinpohl.tokeny.core.SpendModel
import cz.martinpohl.tokeny.core.SpendState
import cz.martinpohl.tokeny.core.readCsv
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SpendViewModel(app: Application) : AndroidViewModel(app) {
    private val model = SpendModel()
    private val ledgerFile = LedgerFile(File(app.filesDir, "local-ledger.json"))
    private val states = MutableStateFlow(model.state)
    val state: StateFlow<SpendState> = states.asStateFlow()

    init {
        when (val loaded = ledgerFile.load()) {
            is LedgerLoad.Ready -> model.replaceLedger(loaded.rows)
            LedgerLoad.Missing -> Unit
            LedgerLoad.Unreadable -> model.markLedgerUnreadable()
        }
        publish()
    }

    fun openAuthGap() = update { openAuthGap() }

    fun closeAuthGap() = update { closeAuthGap() }

    fun closeSample() = update { closeSample() }

    fun select(destination: Destination) = update { select(destination) }

    fun setCurrency(currency: Currency) = update { setCurrency(currency) }

    fun setOffline(offline: Boolean) = update { setOffline(offline) }

    fun showLocal(nowMillis: Long = System.currentTimeMillis()) = update { showLocal(nowMillis) }

    fun discardPreview() = update { discardPreview() }

    fun cancelRead() = update { cancelRead() }

    fun leaveLocal() = update { leaveLocal() }

    fun askClear() = update { askClear() }

    fun cancelClear() = update { cancelClear() }

    fun confirmPreview(nowMillis: Long = System.currentTimeMillis()) {
        val rows = model.confirmPreview(nowMillis) ?: return
        ledgerFile.save(rows)
        publish()
    }

    fun clearLedger() {
        model.clearLedger()
        ledgerFile.delete()
        publish()
    }

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

    fun importUri(resolver: ContentResolver, uri: Uri) {
        val generation = model.beginRead()
        val existing = model.state.ledger
        publish()
        viewModelScope.launch {
            val parsed = withContext(Dispatchers.IO) {
                when (val bytes = readCsvBytes(resolver, uri)) {
                    CsvBytesRead.TooLarge -> CsvRead.Failed(ImportFileError.TOO_LARGE)
                    CsvBytesRead.Unreadable -> CsvRead.Failed(ImportFileError.UNREADABLE)
                    is CsvBytesRead.Ok -> readCsv(bytes.name, bytes.bytes, existing)
                }
            }
            when (parsed) {
                is CsvRead.Failed -> model.failRead(generation, parsed.error)
                is CsvRead.Ok -> model.previewRead(generation, parsed.preview)
            }
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
