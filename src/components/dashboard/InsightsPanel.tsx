import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Lightbulb, Sparkles } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useCurrency } from "@/hooks/useCurrency";
import { api } from "@/lib/api";
import { fmtCost, shortModel } from "@/lib/format";

interface MoneyExact {
  kind: "exact";
  usd: number;
  czk: number | null;
}
interface MoneyRange {
  kind: "range";
  low_usd: number;
  high_usd: number | null;
  low_czk: number | null;
  high_czk: number | null;
}
type Money = MoneyExact | MoneyRange;

interface Tip {
  id: string;
  kind: string;
  explanation: string;
  saving: Money | null;
  observed: { cost: Money; median: Money } | null;
  price_source: string | null;
  price_checked: string | null;
  basis: string;
}

interface MixRow {
  model: string;
  provider: string;
  share: number | null;
  requests: number;
  tokens: number;
  cache_hit_rate: number | null;
  cost: Money | null;
  cost_basis: "billed" | "list" | null;
  price_source: string | null;
}

interface GroupRow {
  kind: "api_key" | "project";
  label: string;
  share: number | null;
  requests: number;
  cost: Money | null;
}

interface InsightsResponse {
  plan: "free" | "pro";
  amounts: "exact" | "range";
  cache_hit_rate: number | null;
  model_mix: MixRow[];
  groups: GroupRow[];
  tips: Tip[];
  truncated: boolean;
  window: { from: string; to: string };
}

function pct(n: number): string {
  return `${Math.round(n * 1000) / 10}%`;
}

/** Same-origin insights for the signed-in account. Hidden during the sample preview. */
export function InsightsPanel() {
  const { t, i18n } = useTranslation();
  const [data, setData] = useState<InsightsResponse | null>(null);
  const [failed, setFailed] = useState(false);
  const lang = i18n.language?.toLowerCase().startsWith("cs") ? "cs" : "en";

  useEffect(() => {
    const ac = new AbortController();
    setFailed(false);
    api<InsightsResponse>(`/insights?tz=Europe/Prague&lang=${lang}`, { signal: ac.signal })
      .then((body) => { if (!ac.signal.aborted) setData(body); })
      .catch((err: unknown) => {
        if (err instanceof DOMException && err.name === "AbortError") return;
        if (!ac.signal.aborted) setFailed(true);
      });
    return () => ac.abort();
  }, [lang]);

  return (
    <Card className="glass border-border">
      <CardHeader className="pb-3">
        <CardTitle className="text-base font-semibold flex items-center gap-2">
          <Lightbulb className="h-4 w-4 text-primary" aria-hidden />
          {t("insights.title")}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {failed ? (
          <p className="text-sm text-muted-foreground">{t("insights.loadError")}</p>
        ) : !data ? (
          <div className="h-16 animate-pulse rounded-xl bg-muted/40" aria-hidden />
        ) : (
          <InsightsBody data={data} />
        )}
      </CardContent>
    </Card>
  );
}

function InsightsBody({ data }: { data: InsightsResponse }) {
  const { t } = useTranslation();
  const { currency, exchangeRate } = useCurrency();
  const fmt = (usd: number, digits = 2) => fmtCost(usd, digits, currency, exchangeRate);
  const money = (m: Money | null) => {
    if (!m) return null;
    if (m.kind === "exact") return fmt(m.usd);
    const low = fmt(m.low_usd, 0);
    if (m.high_usd == null) return t("insights.over", { amount: low });
    return `${low} – ${fmt(m.high_usd, 0)}`;
  };
  const empty = data.tips.length === 0 && data.model_mix.length === 0 && data.groups.length === 0;
  const keys = data.groups.filter((g) => g.kind === "api_key");
  const projects = data.groups.filter((g) => g.kind === "project");

  if (empty) return <p className="text-sm text-muted-foreground">{t("insights.empty")}</p>;

  return (
    <div className="space-y-4">
      {data.cache_hit_rate != null && (
        <p className="text-[11px] text-muted-foreground tabular-nums">
          {t("insights.cacheHit")}: {pct(data.cache_hit_rate)}
          <span className="mx-1.5">·</span>
          {data.window.from} – {data.window.to}
        </p>
      )}
      {data.tips.length > 0 && (
        <ul className="space-y-2">
          {data.tips.map((tip) => (
            <li key={tip.id} className="rounded-xl border border-border/60 bg-background/40 px-3 py-2.5">
              <div className="flex items-start justify-between gap-3">
                <p className="text-sm leading-snug">{tip.explanation}</p>
                {tip.saving && (
                  <div className="shrink-0 text-right">
                    <div className="text-[10px] uppercase tracking-wide text-muted-foreground">{t("insights.estimate")}</div>
                    <div className="text-sm font-semibold tabular-nums text-primary">{money(tip.saving)}</div>
                  </div>
                )}
              </div>
              {tip.observed && (
                <p className="mt-1.5 text-xs text-muted-foreground tabular-nums">
                  {t("insights.recorded")} {money(tip.observed.cost)}
                  <span className="mx-1.5">·</span>
                  {t("insights.typicalDay")} {money(tip.observed.median)}
                </p>
              )}
              {tip.price_source && (
                <a href={tip.price_source} className="mt-1 inline-flex items-center gap-1 text-[11px] text-muted-foreground underline-offset-2 hover:underline" target="_blank" rel="noreferrer">
                  <Sparkles className="h-3 w-3" aria-hidden />
                  {tip.price_checked}
                </a>
              )}
            </li>
          ))}
        </ul>
      )}
      {data.model_mix.length > 0 && (
        <div>
          <h3 className="text-xs font-medium text-muted-foreground mb-1.5">{t("insights.models")}</h3>
          <ul className="space-y-1.5">
            {data.model_mix.map((row) => (
              <li key={`${row.provider}:${row.model}`}>
                <div className="flex items-baseline justify-between gap-3 text-xs">
                  <span className="truncate">{shortModel(row.model)}</span>
                  <span className="shrink-0 tabular-nums text-muted-foreground">
                    {row.share != null && <span className="mr-2">{pct(row.share)}</span>}
                    {money(row.cost)}
                    {row.cost_basis === "list" && <span className="ml-1">{t("insights.listPrice")}</span>}
                  </span>
                </div>
                <div className="mt-1 h-1 rounded-full bg-muted overflow-hidden" aria-hidden>
                  <div className="h-full bg-primary/80" style={{ width: `${Math.min(100, Math.max(0, (row.share ?? 0) * 100))}%` }} />
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
      {(keys.length > 0 || projects.length > 0) && (
        <div className="grid gap-3 sm:grid-cols-2">
          {keys.length > 0 && <GroupList title={t("insights.keys")} rows={keys} money={money} />}
          {projects.length > 0 && <GroupList title={t("insights.projects")} rows={projects} money={money} />}
        </div>
      )}
      <p className="text-[11px] text-muted-foreground leading-relaxed">
        {t("insights.footnote")}
        {data.amounts === "range" && <> {t("insights.freeNote")}</>}
        {data.truncated && <> {t("insights.truncated")}</>}
      </p>
    </div>
  );
}

function GroupList({ title, rows, money }: { title: string; rows: GroupRow[]; money: (m: Money | null) => string | null }) {
  return (
    <div>
      <h3 className="text-xs font-medium text-muted-foreground mb-1.5">{title}</h3>
      <ul className="space-y-1">
        {rows.map((row) => (
          <li key={`${row.kind}:${row.label}`} className="flex items-baseline justify-between gap-3 text-xs">
            <span className="truncate font-mono">{row.label}</span>
            <span className="shrink-0 tabular-nums text-muted-foreground">
              {row.share != null && <span className="mr-2">{pct(row.share)}</span>}
              {money(row.cost)}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
