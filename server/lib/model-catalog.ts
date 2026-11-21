// List prices for labeled estimates. The file is shared/pricing/model-prices.json
// (sources in model-prices.sources.md). Unknown models have no price, so a tip cannot invent one.
// The matching rules are the same as apple/TokenyKit/Sources/TokenyCore/ModelPrices.swift.
import catalogFile from "../../shared/pricing/model-prices.json" with { type: "json" };

export interface ModelPrice {
  id: string;
  provider: string;
  input: number;
  output: number;
  cached: number | null;
  cacheWrite: number | null;
  /** Share of the list price charged for batch. 0.5 means the batch tier costs half. */
  batchFraction: number | null;
  alternative: string | null;
  contextNote: string | null;
  source: string;
  checked: string;
  validFrom: string | null;
  validThrough: string | null;
  verified: boolean;
  match: string[];
}

export interface UnverifiedModelPrice {
  id: string;
  reason: string;
  source: string;
  checked: string;
  validFrom: string | null;
}

export interface ModelCatalog {
  models: ModelPrice[];
  unverified: UnverifiedModelPrice[];
}

export function listCost(price: ModelPrice, parts: { uncached: number; cached: number; write: number; output: number }): number {
  const cachedRate = price.cached ?? price.input;
  const writeRate = price.cacheWrite ?? price.input;
  const tokens = parts.uncached * price.input + parts.cached * cachedRate + parts.write * writeRate + parts.output * price.output;
  return tokens / 1_000_000;
}

export function isCurrent(price: ModelPrice, day: string): boolean {
  if (!price.verified) return false;
  if (price.validFrom && day < price.validFrom) return false;
  if (price.validThrough && day > price.validThrough) return false;
  return true;
}

/** A dated suffix (`-20250514`) still matches. A different SKU (`-pro`, `-mini`) does not. */
export function modelMatches(model: string, pattern: string): boolean {
  const haystack = model.toLowerCase();
  const needle = pattern.toLowerCase();
  const at = haystack.indexOf(needle);
  if (at < 0) return false;
  const after = haystack.slice(at + needle.length);
  if (!after) return true;
  const first = after[0];
  if (first !== "-" && first !== ".") return true;
  const token = /^[A-Za-z0-9]+/.exec(after.slice(1))?.[0] ?? "";
  return token.length > 0 && /^[0-9]+$/.test(token);
}

/** Longest matching list row that is still valid on `day` (yyyy-mm-dd). No default price. */
export function priceForModel(catalog: ModelCatalog, model: string, day: string): ModelPrice | null {
  const haystack = model.toLowerCase();
  let best: { length: number; price: ModelPrice } | null = null;
  for (const price of catalog.models) {
    if (!isCurrent(price, day)) continue;
    for (const pattern of [price.id, ...price.match]) {
      if (!modelMatches(haystack, pattern)) continue;
      if (!best || pattern.length > best.length) best = { length: pattern.length, price };
    }
  }
  return best?.price ?? null;
}

export function priceById(catalog: ModelCatalog, id: string, day: string): ModelPrice | null {
  return catalog.models.find((price) => price.id === id && isCurrent(price, day)) ?? null;
}

function num(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value : null;
}

/** Parse the shared catalog. Rows that are missing a price or a source are dropped. */
export function parseModelCatalog(raw: unknown): ModelCatalog {
  const file = raw && typeof raw === "object" ? raw as { models?: unknown; unverified?: unknown } : {};
  const models: ModelPrice[] = [];
  for (const row of Array.isArray(file.models) ? file.models : []) {
    if (!row || typeof row !== "object") continue;
    const r = row as Record<string, unknown>;
    const id = str(r.id);
    const provider = str(r.provider);
    const input = num(r.input);
    const output = num(r.output);
    const source = str(r.source);
    const checked = str(r.checked);
    if (!id || !provider || input == null || output == null || !source || !checked) continue;
    models.push({
      id,
      provider,
      input,
      output,
      cached: num(r.cached),
      cacheWrite: num(r.cacheWrite),
      batchFraction: num(r.batchFraction),
      alternative: str(r.alternative),
      contextNote: str(r.contextNote),
      source,
      checked,
      validFrom: str(r.validFrom),
      validThrough: str(r.validThrough),
      verified: r.verified === false ? false : true,
      match: Array.isArray(r.match) ? r.match.filter((m): m is string => typeof m === "string") : [],
    });
  }
  const unverified: UnverifiedModelPrice[] = [];
  for (const row of Array.isArray(file.unverified) ? file.unverified : []) {
    if (!row || typeof row !== "object") continue;
    const r = row as Record<string, unknown>;
    const id = str(r.id);
    const reason = str(r.reason);
    const source = str(r.source);
    const checked = str(r.checked);
    if (!id || !reason || !source || !checked) continue;
    unverified.push({ id, reason, source, checked, validFrom: str(r.validFrom) });
  }
  return { models, unverified };
}

let bundled: ModelCatalog | null = null;

/** The catalog shipped with the server. Loaded once from the shared JSON. */
export function bundledCatalog(): ModelCatalog {
  if (!bundled) bundled = parseModelCatalog(catalogFile);
  return bundled;
}
