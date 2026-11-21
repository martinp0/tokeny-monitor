import { describe, expect, it } from "vitest";
import { bundledCatalog, priceForModel } from "../../server/lib/model-catalog";
import {
  buildInsights,
  groupLabel,
  presentInsights,
  savingsBand,
  type InsightFact,
  type InsightReport,
} from "../../server/lib/insights";
import { insightAmounts } from "../../server/lib/plan";

const DAY = "2026-11-17";
const catalog = bundledCatalog();

function fact(partial: Partial<InsightFact> & Pick<InsightFact, "model">): InsightFact {
  return {
    providerSource: "anthropic",
    apiKeyName: "",
    appName: "",
    project: "",
    variant: "standard",
    day: DAY,
    costUSD: 0,
    tokensPrompt: 0,
    tokensCached: 0,
    tokensCacheWrite: 0,
    tokensCompletion: 0,
    requestCount: 1,
    ...partial,
  };
}

function presented(report: InsightReport, isPro: boolean, lang: "cs" | "en" = "en") {
  return presentInsights(report, { isPro, usdToCzk: 23.5, lang });
}

describe("price catalog", () => {
  it("uses the shared file and refuses a price the page does not publish", () => {
    expect(catalog.models.length).toBeGreaterThan(0);
    expect(priceForModel(catalog, "gpt-5.6-sol", "2026-11-30")?.batchFraction).toBe(0.5);
    expect(priceForModel(catalog, "gpt-5.6-sol", "2026-12-01")).toBeNull();
    expect(priceForModel(catalog, "gpt-5.4", DAY)?.batchFraction).toBeNull();
    expect(priceForModel(catalog, "totally-unknown-model", DAY)).toBeNull();
    expect(catalog.unverified.some((row) => row.id === "gpt-5.6-sol")).toBe(true);
  });
});

describe("insights engine", () => {
  it("scales a cheaper-model tip from billed spend and the list-price ratio", () => {
    const report = buildInsights([
      fact({
        model: "claude-opus-4-6", costUSD: 40, tokensPrompt: 2_000_000, tokensCompletion: 20_000, requestCount: 40,
      }),
    ], catalog, DAY, false);
    const tip = report.tips.find((t) => t.kind === "cheaperModel");
    // List: 2e6*5/1e6 + 2e4*25/1e6 = 10.5, alternative 4 + 0.2 = 4.2. Saving = 40 * (1 - 4.2/10.5) = 24.
    expect(tip?.alternative).toBe("claude-sonnet-5-5");
    expect(tip?.basis).toBe("billed");
    expect(tip?.savingUSD).toBeCloseTo(24, 6);
    expect(tip?.price?.source).toContain("https://platform.claude.com/");
    expect(report.tips.some((t) => t.kind === "spendLimit")).toBe(true);
    const mix = report.models[0];
    expect(mix.share).toBe(1);
    expect(mix.billedUSD).toBe(40);
  });

  it("does not invent a price for an unknown model", () => {
    const report = buildInsights([
      fact({
        model: "secret-model", providerSource: "openai", costUSD: 80, tokensPrompt: 5_000_000,
        tokensCompletion: 1000, requestCount: 100, variant: "",
      }),
    ], catalog, DAY, true);
    expect(report.tips.some((t) => t.kind === "cheaperModel" || t.kind === "promptCache" || t.kind === "batch")).toBe(false);
    expect(report.models[0].listUSD).toBeNull();
    const pub = presented(report, true);
    expect(pub.model_mix[0].cost_basis).toBe("billed");
    expect(pub.model_mix[0].price_source).toBeNull();
    expect(pub.model_mix[0].cost).toMatchObject({ kind: "exact", usd: 80 });
  });

  it("prices cache, batch and a spend spike from the same rows", () => {
    const days = ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04"];
    const costs = [1, 1, 1, 12];
    const facts = days.map((day, i) => fact({
      model: "claude-sonnet-5-5",
      day,
      costUSD: i === 3 ? 17 : costs[i],
      tokensPrompt: i === 3 ? 2_000_000 : 0,
      tokensCompletion: i === 3 ? 10_000 : 0,
      requestCount: i === 3 ? 30 : 1,
    }));
    const report = buildInsights(facts, catalog, DAY, true);
    const cache = report.tips.find((t) => t.kind === "promptCache");
    // 2e6 uncached * 0.5 * (2 - 0.1) / 1e6 = 1.9
    expect(cache?.assumedShare).toBe(0.5);
    expect(cache?.savingUSD).toBeCloseTo(1.9, 6);
    const batch = report.tips.find((t) => t.kind === "batch");
    // Days of $1 still have a list price, so the 50% batch discount applies to the whole $20.
    expect(batch?.savingUSD).toBeCloseTo(10, 6);
    expect(batch?.basis).toBe("billed");
    const spike = report.tips.find((t) => t.kind === "spike");
    expect(spike?.day).toBe("2026-11-04");
    expect(spike?.costUSD).toBe(17);
    expect(spike?.medianUSD).toBe(1);
    expect(report.cacheHitRate).toBe(0);
  });

  it("leaves batch off when the tier is unknown", () => {
    const report = buildInsights([
      fact({
        model: "claude-sonnet-5-5", providerSource: "openrouter", variant: "", costUSD: 20,
        tokensPrompt: 2_000_000, tokensCompletion: 10_000, requestCount: 30,
      }),
    ], catalog, DAY, true);
    expect(report.tips.some((t) => t.kind === "batch")).toBe(false);
  });

  it("shows a key and a project only when the row has one, and masks the id", () => {
    const key = "key_1234567890abcd";
    const report = buildInsights([
      fact({
        model: "claude-haiku-4-5", providerSource: "openai", variant: "", costUSD: 4,
        apiKeyName: key, project: "proj_abcdefghijklmn", appName: "openai-admin-sync (list_price_estimate)",
        tokensPrompt: 1000, tokensCompletion: 100, requestCount: 2,
      }),
      fact({
        model: "claude-haiku-4-5", providerSource: "openai", variant: "", costUSD: 0,
        apiKeyName: "", project: "main", appName: "openrouter-activity-sync",
      }),
    ], catalog, DAY, true);
    expect(report.groups.map((g) => g.label)).toEqual([groupLabel(key), groupLabel("proj_abcdefghijklmn")]);
    expect(report.groups.map((g) => g.kind)).toEqual(["api_key", "project"]);
    const pub = JSON.stringify(presented(report, true));
    expect(pub).not.toContain(key);
    expect(pub).not.toContain("proj_abcdefghijklmn");
    expect(pub).toContain("key_…abcd");
  });
});

describe("plan gating", () => {
  const report = buildInsights([
    fact({
      model: "claude-opus-4-6", costUSD: 40, tokensPrompt: 2_000_000, tokensCompletion: 20_000, requestCount: 40,
    }),
  ], catalog, DAY, true);

  it("gives Pro the exact USD and the ČNB conversion", () => {
    expect(insightAmounts(true)).toBe("exact");
    const pub = presented(report, true, "cs");
    expect(pub.amounts).toBe("exact");
    expect(pub.plan).toBe("pro");
    const saving = pub.tips.find((t) => t.kind === "cheaperModel")?.saving;
    expect(saving).toMatchObject({ kind: "exact", usd: 24, czk: 564 });
    expect(pub.tips[0].explanation).toContain("platform.claude.com");
    expect(pub.tips[0].explanation).toContain("Ceník");
  });

  it("hides the exact saving from Free inside a band that still contains it", () => {
    expect(insightAmounts(false)).toBe("range");
    expect(savingsBand(24)).toEqual({ low_usd: 20, high_usd: 100 });
    const pub = presented(report, false);
    expect(pub.amounts).toBe("range");
    const tip = pub.tips.find((t) => t.kind === "cheaperModel")!;
    expect(tip.saving).toEqual({ kind: "range", low_usd: 20, high_usd: 100, low_czk: 470, high_czk: 2350 });
    expect(JSON.stringify(tip)).not.toContain('"usd":24');
    expect(tip.explanation).not.toMatch(/\b24\b/);
    expect(tip.price_source).toContain("https://");
  });
});
