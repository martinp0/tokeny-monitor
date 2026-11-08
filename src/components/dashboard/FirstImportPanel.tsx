import { useTranslation } from "react-i18next";
import { Check } from "lucide-react";
import { Button } from "@/components/ui/button";
import { csCopy } from "@/lib/cs-typography";
import type { CsvImportResult } from "@/hooks/useDashboardData";

interface Props {
  result: CsvImportResult;
  isPro: boolean;
  onDismiss: () => void;
  onUpgrade: () => void;
}

/** Shown once, after the first rows are actually stored. Describes Pro without inventing usage. */
export function FirstImportPanel({ result, isPro, onDismiss, onUpgrade }: Props) {
  const { t, i18n } = useTranslation();
  const cs = i18n.language?.startsWith("cs") ?? true;
  const text = (s: string) => (cs ? csCopy(s) : s);
  const items = t("firstImport.proItems", { returnObjects: true }) as string[];
  const list = Array.isArray(items) ? items : [];

  return (
    <section className="surface rounded-3xl p-5 md:p-6 space-y-4" aria-labelledby="first-import-title">
      <div className="space-y-1">
        <h2 id="first-import-title" className="text-lg font-semibold tracking-tight">
          {text(t(isPro ? "firstImport.proUserTitle" : "firstImport.title"))}
        </h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          {text(t(isPro ? "firstImport.proUserBody" : "firstImport.body", { saved: result.saved }))}
        </p>
        {!isPro && (result.skippedTooOld ?? 0) > 0 && (
          <p className="text-sm leading-relaxed">{text(t("firstImport.skipped", { n: result.skippedTooOld }))}</p>
        )}
      </div>
      {!isPro && (
        <div className="space-y-2">
          <p className="text-sm font-medium">{text(t("firstImport.proTitle"))}</p>
          <ul className="space-y-1.5">
            {list.map((item) => (
              <li key={item} className="flex items-start gap-2 text-sm text-muted-foreground leading-relaxed">
                <Check className="h-4 w-4 mt-0.5 shrink-0 text-primary" aria-hidden />
                <span>{text(item)}</span>
              </li>
            ))}
          </ul>
          <p className="text-sm text-muted-foreground leading-relaxed">{text(t("firstImport.csvNote"))}</p>
          <p className="text-sm text-muted-foreground leading-relaxed">{text(t("firstImport.aiNote"))}</p>
        </div>
      )}
      <div className="flex flex-col sm:flex-row gap-2">
        {!isPro && (
          <Button type="button" onClick={onUpgrade}>
            {text(t("firstImport.cta"))}
          </Button>
        )}
        <Button type="button" variant="outline" onClick={onDismiss}>
          {text(t("firstImport.stay"))}
        </Button>
      </div>
    </section>
  );
}
