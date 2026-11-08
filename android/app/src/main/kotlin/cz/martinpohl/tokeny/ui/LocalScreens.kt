package cz.martinpohl.tokeny.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.martinpohl.tokeny.R
import cz.martinpohl.tokeny.core.CsvFormat
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.Destination
import cz.martinpohl.tokeny.core.ImportFileError
import cz.martinpohl.tokeny.core.ImportPreview
import cz.martinpohl.tokeny.core.LocalPicture
import cz.martinpohl.tokeny.core.PaneLayout
import cz.martinpohl.tokeny.core.SkipReason
import cz.martinpohl.tokeny.core.formatMoney
import cz.martinpohl.tokeny.core.shortModelName

@Composable
fun ImportBanner() {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = stringResource(R.string.import_banner),
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .semantics { heading() },
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
fun ReadingImportScreen() {
    Column(Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        CircularProgressIndicator()
        Text(
            stringResource(R.string.reading_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(stringResource(R.string.reading_body), style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
fun ImportProblemScreen(error: ImportFileError, onClose: () -> Unit) {
    Column(Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            stringResource(R.string.preview_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(importErrorText(error), style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onClose, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_back))
        }
    }
}

@Composable
fun ImportPreviewScreen(preview: ImportPreview, onSave: () -> Unit, onDiscard: () -> Unit) {
    val first = preview.rows.minOfOrNull { it.pragueDay }
    val last = preview.rows.maxOfOrNull { it.pragueDay }
    val cost = preview.rows.sumOf { it.costUsd }
    Column(
        Modifier.verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            stringResource(R.string.preview_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(preview.fileName, style = MaterialTheme.typography.titleMedium)
        Text(
            if (preview.format == CsvFormat.OPENROUTER) {
                stringResource(R.string.preview_format_openrouter)
            } else {
                stringResource(R.string.preview_format_usage)
            },
            style = MaterialTheme.typography.bodyLarge,
        )
        Text(stringResource(R.string.preview_intro), style = MaterialTheme.typography.bodyLarge)
        Text(
            stringResource(
                R.string.preview_counts,
                preview.diagnostics.accepted,
                preview.diagnostics.dataRows,
                preview.merge.toInsert,
                preview.merge.toOverwrite,
                preview.merge.alreadyStored,
            ),
            style = MaterialTheme.typography.bodyLarge,
        )
        if (preview.diagnostics.duplicatesInFile > 0) {
            Text(
                stringResource(R.string.preview_dupes, preview.diagnostics.duplicatesInFile),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        preview.diagnostics.skipped.forEach { (reason, count) ->
            if (count > 0) {
                Text(
                    stringResource(R.string.preview_skip, skipLabel(reason), count),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
        if (preview.diagnostics.partialNumbers > 0) {
            Text(
                stringResource(R.string.preview_partial, preview.diagnostics.partialNumbers),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        if (first != null && last != null) {
            Text(
                stringResource(
                    R.string.preview_span,
                    first,
                    last,
                    formatMoney(cost, Currency.USD, null),
                ),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        Text(stringResource(R.string.preview_usd_only), style = MaterialTheme.typography.bodyLarge)
        Text(stringResource(R.string.preview_no_pro), style = MaterialTheme.typography.bodyLarge)
        if (preview.merge.exceedsStoreLimit) {
            Text(
                stringResource(R.string.preview_too_many, cz.martinpohl.tokeny.core.CsvLimits.MAX_STORED_ROWS),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        if (!preview.canSave) {
            Text(stringResource(R.string.preview_none), style = MaterialTheme.typography.bodyLarge)
        }
        if (preview.canSave) {
            Button(onClick = onSave, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text(stringResource(R.string.action_confirm_save))
            }
        }
        OutlinedButton(onClick = onDiscard, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_discard_import))
        }
    }
}

@Composable
fun LocalOverview(picture: LocalPicture, layout: PaneLayout) {
    Text(
        stringResource(R.string.local_span, picture.firstDay ?: "—", picture.lastDay ?: "—"),
        style = MaterialTheme.typography.bodyLarge,
    )
    Text(
        stringResource(R.string.local_sources, picture.sources.joinToString().ifBlank { "—" }),
        style = MaterialTheme.typography.bodyLarge,
    )
    MetricCard(stringResource(R.string.local_all), formatMoney(picture.allCostUsd, Currency.USD, null))
    MetricCard(
        stringResource(R.string.local_today, picture.pragueToday),
        formatMoney(picture.todayCostUsd, Currency.USD, null),
        supporting = if (picture.todayCostUsd == 0.0) stringResource(R.string.local_no_today) else null,
    )
    val focus = picture.focusMonth
    if (focus != null) {
        MetricCard(
            stringResource(R.string.local_focus, focus),
            formatMoney(picture.focusMonthCostUsd, Currency.USD, null),
        )
    }
    picture.previousMonthCostUsd?.let { previous ->
        Text(
            stringResource(
                R.string.local_previous,
                picture.previousMonth ?: "",
                formatMoney(previous, Currency.USD, null),
            ),
            style = MaterialTheme.typography.bodyLarge,
        )
    }
    SpendChart(picture.daily, Currency.USD, null, sample = false)
    Text(stringResource(R.string.local_usd_only), style = MaterialTheme.typography.bodyMedium)
    if (layout == PaneLayout.EXPANDED) {
        Text(stringResource(R.string.local_focus, picture.focusMonth ?: "—"), style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
fun LocalBreakdown(picture: LocalPicture, layout: PaneLayout) {
    val providers = @Composable {
        ShareBlock(stringResource(R.string.local_providers), picture.providers, picture.focusMonthCostUsd)
    }
    val models = @Composable {
        ShareBlock(
            stringResource(R.string.local_models),
            picture.models.map { it.copy(name = shortModelName(it.name)) },
            picture.focusMonthCostUsd,
        )
    }
    if (layout == PaneLayout.EXPANDED) {
        androidx.compose.foundation.layout.Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(Modifier.weight(1f)) { providers() }
            Column(Modifier.weight(1f)) { models() }
        }
    } else {
        providers()
        models()
    }
    picture.billing?.let { billing ->
        SectionTitle(stringResource(R.string.local_billing_title))
        Text(
            stringResource(
                R.string.local_billing_body,
                formatMoney(billing.includedCostUsd, Currency.USD, null),
                billing.includedCalls,
                formatMoney(billing.onDemandCostUsd, Currency.USD, null),
                billing.onDemandCalls,
                formatMoney(billing.creditsCostUsd, Currency.USD, null),
                billing.creditsCalls,
            ),
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}

@Composable
fun LocalBudgetNotice(picture: LocalPicture) {
    InfoCard(stringResource(R.string.local_budget_title), stringResource(R.string.local_budget_body))
    val focus = picture.focusMonth
    if (focus != null) {
        MetricCard(
            stringResource(R.string.local_focus, focus),
            formatMoney(picture.focusMonthCostUsd, Currency.USD, null),
        )
    }
}

@Composable
fun ConfirmClearScreen(onDelete: () -> Unit, onCancel: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            stringResource(R.string.clear_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(stringResource(R.string.clear_body), style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onDelete, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_confirm_delete))
        }
        OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_cancel))
        }
    }
}

@Composable
fun UnreadableLedgerScreen(onDelete: () -> Unit, onClose: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            stringResource(R.string.unreadable_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(stringResource(R.string.unreadable_body), style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onDelete, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_confirm_delete))
        }
        TextButton(onClick = onClose, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(stringResource(R.string.action_back))
        }
    }
}

@Composable
private fun ShareBlock(
    title: String,
    items: List<cz.martinpohl.tokeny.core.NamedSpend>,
    total: Double,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle(title)
        if (items.isEmpty()) {
            Text(stringResource(R.string.local_empty_rows), style = MaterialTheme.typography.bodyLarge)
        } else {
            cz.martinpohl.tokeny.core.rankShares(items, total).forEach { share ->
                ShareRow(
                    name = share.name.ifBlank { stringResource(R.string.local_blank_name) },
                    amount = formatMoney(share.costUsd, Currency.USD, null),
                    fraction = share.fraction.toFloat(),
                    percent = cz.martinpohl.tokeny.core.formatPercent(share.fraction * 100.0, java.util.Locale.US),
                )
            }
        }
    }
}

@Composable
private fun skipLabel(reason: SkipReason): String = stringResource(
    when (reason) {
        SkipReason.MISSING_ID -> R.string.skip_missing_id
        SkipReason.ID_TOO_LONG -> R.string.skip_id_too_long
        SkipReason.MISSING_DATE -> R.string.skip_missing_date
        SkipReason.BAD_TIME -> R.string.skip_bad_time
        SkipReason.UNKNOWN_PRODUCT -> R.string.skip_unknown_product
        SkipReason.CURRENCY -> R.string.skip_currency
        SkipReason.AMBIGUOUS_DECIMAL -> R.string.skip_ambiguous_decimal
        SkipReason.FIELD_TOO_LONG -> R.string.skip_field_too_long
    },
)

@Composable
private fun importErrorText(error: ImportFileError): String = stringResource(
    when (error) {
        ImportFileError.EMPTY -> R.string.error_empty
        ImportFileError.TOO_LARGE -> R.string.error_too_large
        ImportFileError.TOO_MANY_ROWS -> R.string.error_too_many
        ImportFileError.MALFORMED -> R.string.error_malformed
        ImportFileError.UNRECOGNIZED -> R.string.error_unrecognized
        ImportFileError.NOT_UTF8 -> R.string.error_not_utf8
        ImportFileError.UNREADABLE -> R.string.error_unreadable_file
    },
)
