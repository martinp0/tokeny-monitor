package cz.martinpohl.tokeny.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cz.martinpohl.tokeny.R
import cz.martinpohl.tokeny.core.Currency
import cz.martinpohl.tokeny.core.DailySpend
import cz.martinpohl.tokeny.core.chartFacts
import cz.martinpohl.tokeny.core.formatMoney
import cz.martinpohl.tokeny.core.sortedDaily

@Composable
fun SampleBanner(offline: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Surface(
            color = SampleBanner,
            contentColor = SampleBannerInk,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = stringResource(R.string.banner_sample),
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .semantics { heading() },
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )
        }
        if (offline) {
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant,
                contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = stringResource(R.string.banner_offline),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.semantics { heading() },
    )
}

@Composable
fun MetricCard(label: String, value: String, supporting: String? = null) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        shape = RoundedCornerShape(16.dp),
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                text = value,
                style = MaterialTheme.typography.headlineMedium.copy(fontFeatureSettings = "tnum"),
                fontWeight = FontWeight.SemiBold,
            )
            if (supporting != null) {
                Text(supporting, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
fun SpendChart(days: List<DailySpend>, currency: Currency, rate: Double?, sample: Boolean) {
    val ordered = sortedDaily(days)
    val facts = chartFacts(ordered)
    if (facts == null) {
        Text(
            stringResource(if (sample) R.string.chart_empty else R.string.local_empty_rows),
            style = MaterialTheme.typography.bodyLarge,
        )
        return
    }
    val spoken = pluralStringResource(
        if (sample) R.plurals.chart_summary else R.plurals.local_chart_summary,
        facts.days,
        facts.days,
        facts.maxDate,
        formatMoney(facts.maxUsd, currency, rate),
        facts.lastDate,
        formatMoney(facts.lastUsd, currency, rate),
    )
    val barColor = MaterialTheme.colorScheme.primary
    val gapColor = MaterialTheme.colorScheme.surfaceVariant
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionTitle(stringResource(if (sample) R.string.label_chart else R.string.local_chart))
        Box(Modifier.fillMaxWidth().testTag("spend-bars")) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .clearAndSetSemantics { contentDescription = spoken },
            ) {
                val max = ordered.maxOf { it.costUsd }.coerceAtLeast(0.0001)
                val gap = 3.dp.toPx()
                val barWidth = ((size.width - gap * (ordered.size - 1).coerceAtLeast(0)) / ordered.size).coerceAtLeast(1f)
                ordered.forEachIndexed { index, day ->
                    val fraction = (day.costUsd / max).toFloat().coerceIn(0f, 1f)
                    val barHeight = (size.height * fraction).coerceAtLeast(if (day.costUsd > 0.0) 2.dp.toPx() else 0f)
                    val left = index * (barWidth + gap)
                    drawRoundRect(
                        color = if (day.costUsd > 0.0) barColor else gapColor,
                        topLeft = Offset(left, size.height - barHeight),
                        size = Size(barWidth, barHeight),
                        cornerRadius = CornerRadius(3.dp.toPx(), 3.dp.toPx()),
                    )
                }
            }
        }
        Text(spoken, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun ShareRow(name: String, amount: String, fraction: Float, percent: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Text(
                amount,
                style = MaterialTheme.typography.bodyLarge.copy(fontFeatureSettings = "tnum"),
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.End,
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.heightIn(min = 48.dp),
        ) {
            LinearProgressIndicator(
                progress = { fraction.coerceIn(0f, 1f) },
                modifier = Modifier
                    .weight(1f)
                    .height(8.dp)
                    .clearAndSetSemantics { },
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
            )
            Text(
                percent,
                style = MaterialTheme.typography.labelLarge.copy(fontFeatureSettings = "tnum"),
                modifier = Modifier.heightIn(min = 48.dp),
            )
        }
    }
}

@Composable
fun InfoCard(title: String, body: String) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionTitle(title)
            Text(body, style = MaterialTheme.typography.bodyLarge)
        }
    }
}
