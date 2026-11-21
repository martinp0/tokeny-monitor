// GET /api/insights. Reads one user's rows and runs the pure engine in server/lib/insights.ts.
import type { Db } from "./db.js";
import { addDays, localDay, localMidnight } from "./lib/forecast.js";
import { insightLang, loadInsights, type InsightFact } from "./lib/insights.js";
import { freeHistoryFloor } from "./lib/plan.js";
import { getBudgetAlert, getExchangeRate, insightFacts, utcHourToLocalDay } from "./repo.js";
import { validTz } from "./usage-summary.js";

const FACT_CAP = 20_000;

export async function userInsights(
  db: Db,
  userId: string,
  isPro: boolean,
  tzParam: string | null,
  langParam: string | null,
  now = new Date(),
) {
  const tz = validTz(tzParam);
  const today = localDay(now, tz);
  const monthStart = `${today.slice(0, 7)}-01`;
  const floor = isPro ? null : freeHistoryFloor(now);
  const fromDay = floor && floor > monthStart ? floor : monthStart;
  // One day of slack so a Prague day that starts the previous UTC evening is included, then filtered.
  const since = new Date(localMidnight(addDays(fromDay, -1), tz)).toISOString();
  const [rows, budget, rate] = await Promise.all([
    insightFacts(db, userId, since, FACT_CAP),
    getBudgetAlert(db, userId),
    getExchangeRate(db),
  ]);
  const truncated = rows.length > FACT_CAP;
  const facts: InsightFact[] = [];
  for (const row of truncated ? rows.slice(0, FACT_CAP) : rows) {
    const day = utcHourToLocalDay(row.hour, tz);
    if (!day || day < fromDay || day > today) continue;
    facts.push({
      model: row.model_permaslug ?? "",
      providerSource: row.provider_source || "openrouter",
      apiKeyName: row.api_key_name ?? "",
      appName: row.app_name ?? "",
      project: row.project_ref ?? "",
      variant: row.variant ?? "",
      day,
      costUSD: Number(row.cost_total) || 0,
      tokensPrompt: Number(row.tokens_prompt) || 0,
      tokensCached: Number(row.tokens_cached) || 0,
      tokensCacheWrite: Number(row.tokens_cache_write) || 0,
      tokensCompletion: Number(row.tokens_completion) || 0,
      requestCount: Number(row.request_count) || 0,
    });
  }
  const usdToCzk = rate && Number(rate.rate) > 0 ? Number(rate.rate) : null;
  const hasBudget = !!budget && Number(budget.monthly_budget_usd) > 0;
  const body = loadInsights(facts, today, hasBudget, { isPro, usdToCzk, lang: insightLang(langParam) }, truncated);
  return {
    ...body,
    tz,
    window: { from: fromDay, to: today },
    usd_to_czk: usdToCzk,
    rate_date: rate?.source_date ?? null,
  };
}
