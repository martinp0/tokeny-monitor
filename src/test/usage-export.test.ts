import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { isUsageExportHeader, mapUsageExportRow, streamUsageExport, usageBreakdown } from "@/lib/usage-export";
import type { ActivityRow } from "@/lib/csv-parser";

// Tiny anonymized fixture (made-up IDs, example.com email); the real export is never committed.
const fixture = readFileSync(join(__dirname, "fixtures/usage-export-sample.csv"), "utf8");

async function collect(input: string, batchSize = 2, chunkSize = 300) {
  const batches: ActivityRow[][] = [];
  const progress: number[] = [];
  const stats = await streamUsageExport(input, {
    batchSize,
    chunkSize,
    onBatch: async (rows) => {
      await new Promise((r) => setTimeout(r, 1));
      batches.push(rows);
    },
    onProgress: (f) => progress.push(f),
  });
  return { stats, batches, rows: batches.flat(), progress };
}

describe("usage export (Cursor / Grok Bot)", () => {
  it("detects the export header and not an OpenRouter one", () => {
    expect(isUsageExportHeader(fixture.slice(0, 400))).toBe(true);
    expect(isUsageExportHeader("\uFEFF" + fixture.split("\n")[0])).toBe(true);
    expect(isUsageExportHeader("generation_id,created_at,cost_total,model_permaslug")).toBe(false);
  });

  it("streams in chunks, dedupes Billing Item IDs and reports skips", async () => {
    const { stats, batches, rows, progress } = await collect(fixture);
    expect(stats.rows).toBe(10);
    expect(stats.mapped).toBe(6);
    expect(stats.duplicatesInFile).toBe(1);
    expect(stats.skipped).toEqual({ missing_id: 1, bad_time: 0, unknown_product: 1, currency: 1 });
    expect(new Set(rows.map((r) => r.generation_id)).size).toBe(6);
    expect(batches.every((b) => b.length <= 2)).toBe(true);
    expect(batches.length).toBeGreaterThan(1);
    expect(progress.at(-1)).toBe(1);
    expect(progress).toEqual([...progress].sort((a, b) => a - b));
  });

  it("gives the same rows regardless of chunk size", async () => {
    const a = await collect(fixture, 1000, 64);
    const b = await collect(fixture, 1000, 1 << 20);
    expect(a.rows).toEqual(b.rows);
  });

  it("maps provider, tokens and billing type", async () => {
    const { rows } = await collect(fixture);
    const byId = Object.fromEntries(rows.map((r) => [r.generation_id.slice(-1), r]));
    expect(byId["1"]).toMatchObject({
      provider_source: "grok-bot",
      provider_name: "Grok Bot",
      model_permaslug: "grok-bot",
      tokens_prompt: 32100,
      tokens_cached: 30000,
      tokens_cache_write: 2000,
      tokens_completion: 300,
      cost_total: 0,
      billing_type: "included",
      created_at: "2026-10-22T09:15:00.000Z",
      user: "",
    });
    expect(byId["4"]).toMatchObject({
      provider_source: "cursor",
      provider_name: "Cursor",
      model_permaslug: "claude-4.5-sonnet",
      cost_total: 0.125,
      billing_type: "on_demand",
    });
    expect(byId["5"]).toMatchObject({ billing_type: "credits", tokens_cached: 0, tokens_cache_write: 0, tokens_prompt: 900 });
    expect(byId["6"]).toMatchObject({ tokens_prompt: 0, tokens_completion: 0 }); // empty Usage JSON
    // No personal data from the export ends up in the row.
    expect(JSON.stringify(rows)).not.toMatch(/example\.com|user_demo/);
  });

  it("propagates a failing batch write", async () => {
    await expect(
      streamUsageExport(fixture, { batchSize: 1, onBatch: () => Promise.reject(new Error("db down")) }),
    ).rejects.toThrow("db down");
  });

  it("splits cached vs fresh tokens and included vs on-demand cost", async () => {
    const { rows } = await collect(fixture);
    const b = usageBreakdown(rows)!;
    expect(b.cachedRead).toBe(30000 + 80000 + 12000 + 60000);
    expect(b.cacheWrite).toBe(2000 + 1000 + 5000);
    expect(b.freshInput).toBe(100 + 2 + 1500 + 400 + 900);
    expect(b.output).toBe(300 + 500 + 800 + 1200 + 50);
    expect(b.onDemandCost).toBeCloseTo(0.16625, 10);
    expect(b.includedCost).toBe(0);
    expect([b.includedCalls, b.onDemandCalls, b.creditsCalls]).toEqual([3, 2, 1]);
    expect(usageBreakdown([{ ...rows[0], billing_type: null }])).toBeNull();
  });

  it("rejects malformed rows individually", () => {
    const base = { "Billing Item ID": "x", "Event Time": "2026-10-01T00:00:00Z", Product: "cursor", Usage: "not json" };
    expect(mapUsageExportRow({ ...base, "Event Time": "yesterday" })).toBe("bad_time");
    expect(mapUsageExportRow(base)).toMatchObject({ tokens_prompt: 0, billing_type: null });
  });
});

describe("robust column mapping", () => {
  it("accepts snake_case / renamed headers and separate token columns", async () => {
    const csv = [
      "billing_item_id,timestamp,product,usage_type,currency,cost,model,input_tokens,cached_tokens,cache_write_tokens,output_tokens,user_email",
      'a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,$0.50,grok-4.3,100,2000,30,40,x@example.com',
      'a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,$0.50,grok-4.3,100,2000,30,40,x@example.com',
      'a2,2026-10-22T10:00:00Z,cursor,included,USD,0,,10,0,0,5,x@example.com',
    ].join("\n");
    expect(isUsageExportHeader(csv)).toBe(true);
    const rows: ActivityRow[] = [];
    const stats = await streamUsageExport(csv, { onBatch: (b) => { rows.push(...b); } });
    expect(stats.duplicatesInFile).toBe(1);
    expect(rows).toHaveLength(2);
    const g = rows.find((r) => r.generation_id === "a1")!;
    expect(g.provider_source).toBe("grok-bot");
    expect(g.cost_total).toBeCloseTo(0.5);
    expect(g.tokens_prompt).toBe(2130);
    expect(g.tokens_cached).toBe(2000);
    expect(g.tokens_completion).toBe(40);
    expect(g.billing_type).toBe("on_demand");
    expect(JSON.stringify(rows)).not.toContain("x@example.com");
    expect(rows.find((r) => r.generation_id === "a2")!.provider_source).toBe("cursor");
  });
  it("tolerates underscore keys inside the Usage JSON", () => {
    const r = mapUsageExportRow({ "Billing Item ID": "b", "Event Time": "2026-10-22T09:15:00Z", Product: "grok_bot", Usage: '{"prompt_text_tokens":"7","completion_text_tokens":"3"}' });
    expect(typeof r).not.toBe("string");
    if (typeof r !== "string") { expect(r.tokens_prompt).toBe(7); expect(r.tokens_completion).toBe(3); }
  });
  it("does not mistake an OpenRouter export for a usage export", () => {
    expect(isUsageExportHeader("generation_id,created_at,cost_total,tokens_prompt,model_permaslug,provider_name")).toBe(false);
  });
});
