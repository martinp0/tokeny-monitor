import { DAILY_USD } from "./daily-spend-data";
import type { BlogLocale } from "@/content/blog/catalog";

export function DailySpendChart({ locale = "cs" }: { locale?: BlogLocale }) {
  const numberLocale = locale === "en" ? "en-GB" : "cs-CZ";
  const fmt = (n: number) => n.toLocaleString(numberLocale, { maximumFractionDigits: n < 10 ? 2 : 0 });
  const max = Math.max(...DAILY_USD.map((d) => d.grokBot + d.cursor));
  const dayLabel = (day: number) => (locale === "en" ? `${day} Oct` : `${day}. 10.`);
  const aria =
    locale === "en"
      ? "Bar chart of daily spend above the plan, 1–30 October 2026. Highest is 22 October at 258 USD."
      : "Sloupcový graf denní útraty nad rámec tarifu, 1.–30. října 2026. Nejvyšší 22. října 258 USD.";
  const caption =
    locale === "en"
      ? "Spend above the plan in USD per day (days in Europe/Prague). Peak on 22 Oct: 258 USD."
      : "Útrata nad rámec tarifu v USD za den (dny podle času v Praze). Max. 22. 10.: 258 USD.";
  return (
    <figure className="not-prose glass rounded-2xl p-4 sm:p-6 my-8">
      <div className="flex items-end gap-[3px] h-48" role="img" aria-label={aria}>
        {DAILY_USD.map((d) => {
          const total = d.grokBot + d.cursor;
          return (
            <div key={d.day} className="flex-1 h-full flex flex-col justify-end" title={`${dayLabel(d.day)}: ${fmt(total)} USD`}>
              <div className="bg-sky-400/80 rounded-t-sm" style={{ height: `${(d.cursor / max) * 100}%` }} />
              <div
                className={`bg-primary ${d.cursor === 0 ? "rounded-t-sm" : ""}`}
                style={{ height: `${(d.grokBot / max) * 100}%`, minHeight: total === 0 ? 1 : undefined }}
              />
            </div>
          );
        })}
      </div>
      <div className="flex justify-between text-[11px] tabular-nums text-muted-foreground mt-2">
        <span>{dayLabel(1)}</span>
        <span>{dayLabel(10)}</span>
        <span>{dayLabel(20)}</span>
        <span>{dayLabel(30)}</span>
      </div>
      <figcaption className="mt-4 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm bg-primary" aria-hidden /> Grok Bot</span>
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm bg-sky-400/80" aria-hidden /> Cursor</span>
        <span>{caption}</span>
      </figcaption>
    </figure>
  );
}
