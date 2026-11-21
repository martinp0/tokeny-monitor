// Explainable spend tips. Dollar figures are user tokens or recorded spend multiplied by
// shared/pricing/model-prices.json. A model with no row contributes no price. The cache rule's
// 50% share is a named assumption (`assumed_share`), not a measured prompt overlap.
// Same thresholds as apple/TokenyKit/Sources/TokenyCore/OptimizationTips.swift.
//
// Plan gating (server/lib/plan.ts `insightAmounts`): Free replaces each computed USD amount
// with the smallest published band in SAVINGS_BANDS_USD that contains it. Pro keeps the exact
// USD and the CZK conversion at the stored ČNB rate. The band is not a second estimate.
import {
  bundledCatalog,
  listCost,
  priceById,
  priceForModel,
  type ModelCatalog,
  type ModelPrice,
} from "./model-catalog.js";
import { insightAmounts, type InsightAmounts } from "./plan.js";

export const RULES = {
  repetitiveRequests: 20,
  maxAverageOutput: 800,
  repetitiveTokens: 500_000,
  minCostShare: 0.25,
  minSavingUSD: 0.05,
  cacheMinUncached: 100_000,
  cacheMaxReadRatio: 0.1,
  cacheAssumedShare: 0.5,
  batchMinRequests: 10,
  spikeMultiple: 2.5,
  spikeMinExcessUSD: 1,
  maxTips: 5,
  maxModels: 12,
  maxGroups: 8,
} as const;

/** Upper edges of the Free savings bands, in USD. A value of 0.4 is 0–1; 24 is 20–100; above the last edge is open. */
export const SAVINGS_BANDS_USD = [1, 5, 20, 100, 500, 2_000, 10_000] as const;

export function savingsBand(usd: number): { low_usd: number; high_usd: number | null } {
  const value = Number.isFinite(usd) ? Math.max(0, usd) : 0;
  let low = 0;
  for (const edge of SAVINGS_BANDS_USD) {
    if (value <= edge) return { low_usd: low, high_usd: edge };
    low = edge;
  }
  return { low_usd: SAVINGS_BANDS_USD[SAVINGS_BANDS_USD.length - 1], high_usd: null };
}

export interface InsightFact {
  model: string;
  providerSource: string;
  apiKeyName: string;
  appName: string;
  project: string;
  variant: string;
  /** Local calendar day, yyyy-mm-dd. */
  day: string;
  costUSD: number;
  tokensPrompt: number;
  tokensCached: number;
  tokensCacheWrite: number;
  tokensCompletion: number;
  requestCount: number;
}

export interface TokenParts {
  uncached: number;
  cached: number;
  write: number;
  output: number;
}

export function tokenParts(row: {
  tokensPrompt: number; tokensCached: number; tokensCacheWrite: number; tokensCompletion: number;
}): TokenParts {
  const prompt = Math.max(0, Math.round(row.tokensPrompt));
  const cached = Math.min(Math.max(0, Math.round(row.tokensCached)), prompt);
  const write = Math.min(Math.max(0, Math.round(row.tokensCacheWrite)), Math.max(0, prompt - cached));
  return { uncached: Math.max(0, prompt - cached - write), cached, write, output: Math.max(0, Math.round(row.tokensCompletion)) };
}

const PLACEHOLDERS = new Set(["", "any", "main", "default", "unknown", "null"]);
const SYNC_APP = /^(openrouter-activity-sync|anthropic-admin-sync|openai-admin-sync)\b/;

/** A name worth showing. Sync placeholders and empty ids are dropped. Long ids keep only their ends. */
export function groupLabel(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed || PLACEHOLDERS.has(trimmed.toLowerCase()) || SYNC_APP.test(trimmed)) return null;
  if (!/\s/.test(trimmed) && trimmed.length >= 12) return `${trimmed.slice(0, 4)}…${trimmed.slice(-4)}`;
  return trimmed.slice(0, 80);
}

export type TipKind = "cheaperModel" | "promptCache" | "batch" | "spike" | "spendLimit";
export type CostBasis = "billed" | "list" | "observed" | "assumed_cache_share";

interface RawTip {
  id: string;
  kind: TipKind;
  model: string | null;
  alternative: string | null;
  savingUSD: number | null;
  basis: CostBasis;
  price: ModelPrice | null;
  alt: ModelPrice | null;
  assumedShare: number | null;
  day: string | null;
  costUSD: number | null;
  medianUSD: number | null;
  requests: number | null;
  tokens: number | null;
  periodNote: boolean;
}

interface RawModel {
  model: string;
  provider: string;
  billedUSD: number;
  listUSD: number | null;
  requests: number;
  tokens: number;
  cacheHitRate: number | null;
  price: ModelPrice | null;
  share: number | null;
}

interface RawGroup {
  kind: "api_key" | "project";
  label: string;
  billedUSD: number;
  requests: number;
  tokens: number;
}

export interface InsightReport {
  tips: RawTip[];
  models: RawModel[];
  groups: RawGroup[];
  cacheHitRate: number | null;
  monthCostUSD: number;
  truncated: boolean;
}

export interface MoneyExact {
  kind: "exact";
  usd: number;
  czk: number | null;
}

export interface MoneyRange {
  kind: "range";
  low_usd: number;
  high_usd: number | null;
  low_czk: number | null;
  high_czk: number | null;
}

export type Money = MoneyExact | MoneyRange;

export interface PublicTip {
  id: string;
  kind: TipKind;
  model: string | null;
  alternative: string | null;
  explanation: string;
  saving: Money | null;
  observed: { cost: Money; median: Money } | null;
  price_source: string | null;
  price_checked: string | null;
  context_note: string | null;
  basis: CostBasis;
  assumed_share: number | null;
  requests: number | null;
  tokens: number | null;
}

export interface PublicModel {
  model: string;
  provider: string;
  share: number | null;
  requests: number;
  tokens: number;
  cache_hit_rate: number | null;
  cost: Money | null;
  cost_basis: "billed" | "list" | null;
  price_source: string | null;
  price_checked: string | null;
}

export interface PublicGroup {
  kind: "api_key" | "project";
  label: string;
  share: number | null;
  requests: number;
  tokens: number;
  cost: Money | null;
}

export interface PublicInsights {
  version: 1;
  plan: "free" | "pro";
  amounts: InsightAmounts;
  cache_hit_rate: number | null;
  model_mix: PublicModel[];
  groups: PublicGroup[];
  tips: PublicTip[];
  truncated: boolean;
}

function slug(model: string): string {
  return model.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48) || "model";
}

function round4(n: number): number {
  return Math.round(n * 1e4) / 1e4;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function finite(n: number): number {
  return Number.isFinite(n) ? n : 0;
}

function partsOf(group: Acc): TokenParts {
  return tokenParts({
    tokensPrompt: group.prompt,
    tokensCached: group.cached,
    tokensCacheWrite: group.write,
    tokensCompletion: group.completion,
  });
}

function isRepetitive(requests: number, completion: number, totalTokens: number): boolean {
  if (requests >= RULES.repetitiveRequests) {
    const average = requests > 0 ? Math.floor(completion / requests) : 0;
    return average <= RULES.maxAverageOutput;
  }
  return requests === 0 && totalTokens >= RULES.repetitiveTokens;
}

/** OpenAI admin sync writes `batch` or an empty variant, so an empty variant is a known standard tier. Other providers need a variant. */
function batchCounts(provider: string, variant: string, requests: number): { batch: number; known: number } {
  const v = variant.trim().toLowerCase();
  const n = Math.max(0, Math.round(requests));
  const known = v.length > 0 || provider === "openai";
  const isBatch = v === "batch" || v.includes("batch");
  return { batch: known && isBatch ? n : 0, known: known ? n : 0 };
}

interface Acc {
  model: string;
  provider: string;
  facts: InsightFact[];
  billed: number;
  requests: number;
  prompt: number;
  cached: number;
  write: number;
  completion: number;
  batch: number;
  known: number;
}

function accumulate(facts: InsightFact[]): Map<string, Acc> {
  const map = new Map<string, Acc>();
  for (const fact of facts) {
    const model = fact.model.trim();
    if (!model) continue;
    const key = `${fact.providerSource}\0${model}`;
    let acc = map.get(key);
    if (!acc) {
      acc = {
        model, provider: fact.providerSource, facts: [], billed: 0, requests: 0,
        prompt: 0, cached: 0, write: 0, completion: 0, batch: 0, known: 0,
      };
      map.set(key, acc);
    }
    acc.facts.push(fact);
    acc.billed += finite(fact.costUSD);
    acc.requests += Math.max(0, Math.round(fact.requestCount));
    acc.prompt += Math.max(0, Math.round(fact.tokensPrompt));
    acc.cached += Math.max(0, Math.round(fact.tokensCached));
    acc.write += Math.max(0, Math.round(fact.tokensCacheWrite));
    acc.completion += Math.max(0, Math.round(fact.tokensCompletion));
    const tier = batchCounts(fact.providerSource, fact.variant, fact.requestCount);
    acc.batch += tier.batch;
    acc.known += tier.known;
  }
  return map;
}

function cheaperTips(groups: Acc[], monthCostUSD: number, catalog: ModelCatalog): RawTip[] {
  const found: RawTip[] = [];
  for (const group of groups) {
    const totalTokens = group.prompt + group.completion;
    if (!isRepetitive(group.requests, group.completion, totalTokens)) continue;
    let altId: string | null = null;
    let mixed = false;
    let currentList = 0;
    let altList = 0;
    let billedCovered = 0;
    let display: ModelPrice | null = null;
    let displayAlt: ModelPrice | null = null;
    const periods = new Set<string>();
    for (const fact of group.facts) {
      const current = priceForModel(catalog, fact.model, fact.day);
      const alt = current?.alternative ? priceById(catalog, current.alternative, fact.day) : null;
      if (!current || !alt) continue;
      if (altId && altId !== alt.id) { mixed = true; break; }
      altId = alt.id;
      const parts = tokenParts(fact);
      const currentCost = listCost(current, parts);
      const altCost = listCost(alt, parts);
      if (!(currentCost > 0) || !(altCost < currentCost * 0.98)) continue;
      currentList += currentCost;
      altList += altCost;
      billedCovered += finite(fact.costUSD);
      periods.add(`${current.id}|${current.input}|${current.output}|${current.validFrom ?? ""}|${current.validThrough ?? ""}`);
      if (!display) { display = current; displayAlt = alt; }
    }
    if (mixed || !display || !displayAlt || !(currentList > 0)) continue;
    if (monthCostUSD > 0 && billedCovered > 0 && billedCovered / monthCostUSD < RULES.minCostShare) continue;
    const billed = billedCovered > 0.01;
    const saving = billed ? billedCovered * (1 - altList / currentList) : currentList - altList;
    if (saving < RULES.minSavingUSD) continue;
    found.push({
      id: `cheaper-${display.id}-${slug(group.model)}`,
      kind: "cheaperModel",
      model: group.model,
      alternative: displayAlt.id,
      savingUSD: saving,
      basis: billed ? "billed" : "list",
      price: display,
      alt: displayAlt,
      assumedShare: null,
      day: null,
      costUSD: null,
      medianUSD: null,
      requests: group.requests,
      tokens: totalTokens,
      periodNote: periods.size > 1,
    });
  }
  return found.sort((a, b) => (b.savingUSD ?? 0) - (a.savingUSD ?? 0)).slice(0, 2);
}

function cacheTips(groups: Acc[], catalog: ModelCatalog): RawTip[] {
  const found: RawTip[] = [];
  for (const group of groups) {
    const parts = partsOf(group);
    const inputTotal = parts.uncached + parts.cached;
    if (parts.uncached < RULES.cacheMinUncached || inputTotal <= 0) continue;
    if (parts.cached / inputTotal >= RULES.cacheMaxReadRatio) continue;
    let saving = 0;
    let display: ModelPrice | null = null;
    let best = 0;
    const periods = new Set<string>();
    for (const fact of group.facts) {
      const price = priceForModel(catalog, fact.model, fact.day);
      if (!price || price.cached == null) continue;
      const factParts = tokenParts(fact);
      const piece = factParts.uncached * RULES.cacheAssumedShare * (price.input - price.cached) / 1_000_000;
      if (piece <= 0) continue;
      saving += piece;
      periods.add(`${price.input}|${price.cached}|${price.validFrom ?? ""}|${price.validThrough ?? ""}`);
      if (piece > best) { best = piece; display = price; }
    }
    if (!display || saving < RULES.minSavingUSD) continue;
    found.push({
      id: `cache-${display.id}-${slug(group.model)}`,
      kind: "promptCache",
      model: group.model,
      alternative: null,
      savingUSD: saving,
      basis: "assumed_cache_share",
      price: display,
      alt: null,
      assumedShare: RULES.cacheAssumedShare,
      day: null,
      costUSD: null,
      medianUSD: null,
      requests: null,
      tokens: parts.uncached,
      periodNote: periods.size > 1,
    });
  }
  return found.sort((a, b) => (b.savingUSD ?? 0) - (a.savingUSD ?? 0)).slice(0, 1);
}

function batchTips(groups: Acc[], catalog: ModelCatalog): RawTip[] {
  const found: RawTip[] = [];
  for (const group of groups) {
    const totalTokens = group.prompt + group.completion;
    if (group.known <= 0) continue;
    if (group.requests < RULES.batchMinRequests && totalTokens < RULES.repetitiveTokens) continue;
    const batchShare = group.batch / Math.max(group.known, 1);
    if (batchShare >= 0.5) continue;
    const nonBatch = 1 - batchShare;
    let saving = 0;
    let display: ModelPrice | null = null;
    let best = 0;
    for (const fact of group.facts) {
      const price = priceForModel(catalog, fact.model, fact.day);
      if (!price || price.batchFraction == null || price.batchFraction >= 1) continue;
      const list = listCost(price, tokenParts(fact));
      const base = group.billed > 0.01 ? finite(fact.costUSD) : list;
      if (!(base > 0)) continue;
      const piece = base * nonBatch * (1 - price.batchFraction);
      saving += piece;
      if (piece > best) { best = piece; display = price; }
    }
    if (!display || saving < RULES.minSavingUSD) continue;
    found.push({
      id: `batch-${display.id}-${slug(group.model)}`,
      kind: "batch",
      model: group.model,
      alternative: null,
      savingUSD: saving,
      basis: group.billed > 0.01 ? "billed" : "list",
      price: display,
      alt: null,
      assumedShare: null,
      day: null,
      costUSD: null,
      medianUSD: null,
      requests: group.requests,
      tokens: totalTokens,
      periodNote: false,
    });
  }
  return found.sort((a, b) => (b.savingUSD ?? 0) - (a.savingUSD ?? 0)).slice(0, 1);
}

function spikeTip(facts: InsightFact[]): RawTip | null {
  const byDay = new Map<string, number>();
  for (const fact of facts) {
    if (!fact.day) continue;
    byDay.set(fact.day, (byDay.get(fact.day) ?? 0) + finite(fact.costUSD));
  }
  const positive = [...byDay.entries()].filter(([, cost]) => cost > 0).sort((a, b) => a[1] - b[1]);
  if (positive.length < 3) return null;
  const peak = positive[positive.length - 1];
  const others = positive.slice(0, -1);
  const mid = Math.floor(others.length / 2);
  const median = others.length % 2 === 1 ? others[mid][1] : (others[mid - 1][1] + others[mid][1]) / 2;
  if (!(median > 0 && peak[1] >= median * RULES.spikeMultiple && peak[1] - median >= RULES.spikeMinExcessUSD)) return null;
  return {
    id: `spike-${peak[0]}`, kind: "spike", model: null, alternative: null, savingUSD: null,
    basis: "observed", price: null, alt: null, assumedShare: null, day: peak[0],
    costUSD: peak[1], medianUSD: median, requests: null, tokens: null, periodNote: false,
  };
}

function modelMix(groups: Acc[], catalog: ModelCatalog, on: string): RawModel[] {
  const rows: RawModel[] = [];
  for (const group of groups) {
    const parts = partsOf(group);
    const input = parts.uncached + parts.cached;
    let list = 0;
    let pricedFacts = 0;
    for (const fact of group.facts) {
      const price = priceForModel(catalog, fact.model, fact.day);
      if (!price) continue;
      list += listCost(price, tokenParts(fact));
      pricedFacts += 1;
    }
    const display = priceForModel(catalog, group.model, on)
      ?? group.facts.map((f) => priceForModel(catalog, f.model, f.day)).find((price) => price != null)
      ?? null;
    rows.push({
      model: group.model,
      provider: group.provider,
      billedUSD: group.billed,
      listUSD: pricedFacts > 0 ? list : null,
      requests: group.requests,
      tokens: parts.uncached + parts.cached + parts.write + parts.output,
      cacheHitRate: input > 0 ? parts.cached / input : null,
      price: display,
      share: null,
    });
  }
  const billedTotal = rows.reduce((sum, row) => sum + row.billedUSD, 0);
  const listTotal = rows.reduce((sum, row) => sum + (row.listUSD ?? 0), 0);
  const useBilled = billedTotal > 0;
  for (const row of rows) {
    const part = useBilled ? row.billedUSD : (row.listUSD ?? 0);
    const total = useBilled ? billedTotal : listTotal;
    row.share = total > 0 ? round4(part / total) : null;
  }
  return rows.sort((a, b) => b.billedUSD - a.billedUSD || b.tokens - a.tokens).slice(0, RULES.maxModels);
}

function groupsOf(facts: InsightFact[]): RawGroup[] {
  const acc = new Map<string, RawGroup>();
  const add = (kind: RawGroup["kind"], raw: string, fact: InsightFact) => {
    const label = groupLabel(raw);
    if (!label) return;
    const key = `${kind}\0${label}`;
    let row = acc.get(key);
    if (!row) {
      row = { kind, label, billedUSD: 0, requests: 0, tokens: 0 };
      acc.set(key, row);
    }
    const parts = tokenParts(fact);
    row.billedUSD += finite(fact.costUSD);
    row.requests += Math.max(0, Math.round(fact.requestCount));
    row.tokens += parts.uncached + parts.cached + parts.write + parts.output;
  };
  for (const fact of facts) {
    add("api_key", fact.apiKeyName, fact);
    const project = fact.project.trim() ? fact.project : fact.appName;
    add("project", project, fact);
  }
  const ranked = [...acc.values()].sort((a, b) => b.billedUSD - a.billedUSD || b.tokens - a.tokens);
  const keys = ranked.filter((g) => g.kind === "api_key").slice(0, RULES.maxGroups);
  const projects = ranked.filter((g) => g.kind === "project").slice(0, RULES.maxGroups);
  return [...keys, ...projects];
}

/** Tips, model mix, cache hit rate and key/project groups. Amounts are still raw USD. */
export function buildInsights(facts: InsightFact[], catalog: ModelCatalog, on: string, hasBudget: boolean, truncated = false): InsightReport {
  const groups = [...accumulate(facts).values()];
  const monthCostUSD = groups.reduce((sum, g) => sum + g.billed, 0);
  const tips: RawTip[] = [
    ...cheaperTips(groups, monthCostUSD, catalog),
    ...cacheTips(groups, catalog),
    ...batchTips(groups, catalog),
  ];
  const spike = spikeTip(facts);
  if (spike) tips.push(spike);
  if (monthCostUSD > 0 && !hasBudget) {
    tips.push({
      id: "spend-limit", kind: "spendLimit", model: null, alternative: null, savingUSD: null,
      basis: "observed", price: null, alt: null, assumedShare: null, day: null,
      costUSD: null, medianUSD: null, requests: null, tokens: null, periodNote: false,
    });
  }
  let cached = 0;
  let input = 0;
  for (const group of groups) {
    const parts = partsOf(group);
    cached += parts.cached;
    input += parts.uncached + parts.cached;
  }
  return {
    tips: tips.slice(0, RULES.maxTips),
    models: modelMix(groups, catalog, on),
    groups: groupsOf(facts),
    cacheHitRate: input > 0 ? cached / input : null,
    monthCostUSD,
    truncated,
  };
}

export function insightLang(raw: string | null | undefined): "cs" | "en" {
  const first = (raw ?? "").toLowerCase().split(",")[0]?.trim() ?? "";
  return first.startsWith("cs") ? "cs" : "en";
}

function rateText(n: number): string {
  const rounded = round4(n);
  return Number.isInteger(rounded) ? String(rounded) : String(rounded);
}

function moneyOf(usd: number, isPro: boolean, rate: number | null): Money {
  const value = finite(usd);
  if (isPro) return { kind: "exact", usd: round4(value), czk: rate == null ? null : round2(value * rate) };
  const band = savingsBand(value);
  return {
    kind: "range",
    low_usd: band.low_usd,
    high_usd: band.high_usd,
    low_czk: rate == null ? null : Math.floor(band.low_usd * rate * 100) / 100,
    high_czk: band.high_usd == null || rate == null ? null : Math.ceil(band.high_usd * rate * 100) / 100,
  };
}

function sourceSentence(lang: "cs" | "en", price: ModelPrice | null): string {
  if (!price) return "";
  return lang === "cs"
    ? ` Ceník: ${price.source} (ověřeno ${price.checked}).`
    : ` Price list: ${price.source} (checked ${price.checked}).`;
}

function explain(tip: RawTip, lang: "cs" | "en"): string {
  const period = tip.periodNote
    ? (lang === "cs" ? " Každý den používá ceník platný v ten den." : " Each day uses the list price valid that day.")
    : "";
  const note = tip.price?.contextNote
    ? (lang === "cs" ? ` Poznámka k ceníku: ${tip.price.contextNote}.` : ` Price note: ${tip.price.contextNote}.`)
    : "";
  const source = sourceSentence(lang, tip.price);
  if (tip.kind === "cheaperModel" && tip.price && tip.alt) {
    const rates = `${rateText(tip.price.input)} / ${rateText(tip.price.output)} vs ${rateText(tip.alt.input)} / ${rateText(tip.alt.output)}`;
    if (lang === "cs") {
      const how = tip.basis === "billed"
        ? "Odhad násobí zaznamenanou útratu za tento model poměrem těch dvou ceníkových cen."
        : "V okně nejsou zaznamenané dolary za tyto tokeny, takže odhad porovnává jen ceník.";
      return `${tip.model} na ${tip.alternative}. Ceník ${rates} USD za milion tokenů (vstup / výstup). ${how}${note}${period}${source}`;
    }
    const how = tip.basis === "billed"
      ? "The estimate scales this model's recorded spend by the ratio of those two list prices."
      : "This window has no recorded dollars for these tokens, so the estimate compares list prices only.";
    return `${tip.model} to ${tip.alternative}. List price ${rates} USD per million tokens (input / output). ${how}${note}${period}${source}`;
  }
  if (tip.kind === "promptCache" && tip.price && tip.price.cached != null) {
    const share = Math.round((tip.assumedShare ?? RULES.cacheAssumedShare) * 100);
    if (lang === "cs") {
      return `Z necacheovaného vstupu u ${tip.model} pravidlo oceňuje ${share} % jako čtení z cache (${rateText(tip.price.cached)} místo ${rateText(tip.price.input)} USD za milion). Ten podíl je předpoklad pravidla, ne změřené opakování promptů. První zápis do cache se neodečítá.${note}${period}${source}`;
    }
    return `Of the uncached input on ${tip.model}, this rule prices ${share}% as a cache read (${rateText(tip.price.cached)} instead of ${rateText(tip.price.input)} USD per million). That share is the rule's assumption, not a measurement of repeated prompts. The first cache write is not subtracted.${note}${period}${source}`;
  }
  if (tip.kind === "batch" && tip.price && tip.price.batchFraction != null) {
    const pct = Math.round(tip.price.batchFraction * 100);
    if (lang === "cs") {
      return `Publikovaná batch cena ${tip.model} je ${pct} % standardního ceníku. Odhad aplikuje tu slevu na podíl okna, který ještě není označený jako batch. Řádky s neznámým tarifem se nepočítají.${source}`;
    }
    return `The published batch price for ${tip.model} is ${pct}% of the standard list price. The estimate applies that discount to the share of this window that is not already marked batch. Rows whose tier is unknown are left out.${source}`;
  }
  if (tip.kind === "spike" && tip.day) {
    return lang === "cs"
      ? `${tip.day} je aspoň 2,5× medián ostatních dní v tomto okně a aspoň o 1 USD nad ním. Obě čísla jsou zaznamenané útraty.`
      : `${tip.day} is at least 2.5× the median of the other days in this window, and at least $1 above that median. Both figures are recorded spend.`;
  }
  return lang === "cs"
    ? "V tomto okně jsou zaznamenané útraty a není nastavený měsíční rozpočet nad nulu."
    : "This window has recorded spend and no monthly budget above zero is set.";
}

function shareOf(part: number, total: number): number | null {
  if (!(total > 0)) return null;
  return round4(part / total);
}

/** Apply plan gating and write the explanation. Exact savings stay off the Free payload. */
export function presentInsights(
  report: InsightReport,
  opts: { isPro: boolean; usdToCzk: number | null; lang: "cs" | "en" },
): PublicInsights {
  const rate = opts.usdToCzk != null && opts.usdToCzk > 0 ? opts.usdToCzk : null;
  const amounts = insightAmounts(opts.isPro);
  const model_mix: PublicModel[] = report.models.map((m) => {
    const billed = m.billedUSD > 0;
    const basis = billed ? "billed" as const : m.listUSD != null && m.listUSD > 0 ? "list" as const : null;
    const usd = billed ? m.billedUSD : basis === "list" ? m.listUSD : null;
    return {
      model: m.model,
      provider: m.provider,
      share: m.share,
      requests: m.requests,
      tokens: m.tokens,
      cache_hit_rate: m.cacheHitRate == null ? null : round4(m.cacheHitRate),
      cost: usd == null ? null : moneyOf(usd, opts.isPro, rate),
      cost_basis: basis,
      price_source: basis === "list" ? m.price?.source ?? null : null,
      price_checked: basis === "list" ? m.price?.checked ?? null : null,
    };
  });
  const presentGroups = (kind: RawGroup["kind"]): PublicGroup[] => {
    const rows = report.groups.filter((g) => g.kind === kind);
    const billed = rows.reduce((sum, g) => sum + Math.max(0, g.billedUSD), 0);
    const tokens = rows.reduce((sum, g) => sum + g.tokens, 0);
    return rows.map((g) => ({
      kind: g.kind,
      label: g.label,
      share: billed > 0 ? shareOf(Math.max(0, g.billedUSD), billed) : shareOf(g.tokens, tokens),
      requests: g.requests,
      tokens: g.tokens,
      cost: g.billedUSD > 0 ? moneyOf(g.billedUSD, opts.isPro, rate) : null,
    }));
  };
  const groups = [...presentGroups("api_key"), ...presentGroups("project")];
  const tips: PublicTip[] = report.tips.map((tip) => ({
    id: tip.id,
    kind: tip.kind,
    model: tip.model,
    alternative: tip.alternative,
    explanation: explain(tip, opts.lang),
    saving: tip.savingUSD == null ? null : moneyOf(tip.savingUSD, opts.isPro, rate),
    observed: tip.costUSD == null || tip.medianUSD == null ? null : {
      cost: moneyOf(tip.costUSD, opts.isPro, rate),
      median: moneyOf(tip.medianUSD, opts.isPro, rate),
    },
    price_source: tip.price?.source ?? null,
    price_checked: tip.price?.checked ?? null,
    context_note: tip.price?.contextNote ?? null,
    basis: tip.basis,
    assumed_share: tip.assumedShare,
    requests: tip.requests,
    tokens: tip.tokens,
  }));
  return {
    version: 1,
    plan: opts.isPro ? "pro" : "free",
    amounts,
    cache_hit_rate: report.cacheHitRate == null ? null : round4(report.cacheHitRate),
    model_mix,
    groups,
    tips,
    truncated: report.truncated,
  };
}

export function loadInsights(facts: InsightFact[], on: string, hasBudget: boolean, present: { isPro: boolean; usdToCzk: number | null; lang: "cs" | "en" }, truncated = false): PublicInsights {
  return presentInsights(buildInsights(facts, bundledCatalog(), on, hasBudget, truncated), present);
}
