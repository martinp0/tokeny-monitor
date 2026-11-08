import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import { FlaskConical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CsvUpload } from "@/components/dashboard/CsvUpload";
import { csCopy } from "@/lib/cs-typography";
import type { CsvImportResult } from "@/hooks/useDashboardData";

interface Props {
  rows: number;
  onExit: () => void;
  onUpload: (file: File, onProgress: (fraction: number) => void) => Promise<unknown> | void;
  notice?: CsvImportResult | null;
}

/** Persistent label for the bundled sample. Budget, export and sharing stay unmounted beside it. */
export function SamplePreviewBanner({ rows, onExit, onUpload, notice }: Props) {
  const { t, i18n } = useTranslation();
  const cs = i18n.language?.startsWith("cs") ?? true;
  const text = (s: string) => (cs ? csCopy(s) : s);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    ref.current?.focus();
  }, []);

  return (
    <div
      ref={ref}
      tabIndex={-1}
      role="status"
      className="glass-panel rounded-3xl p-4 md:p-5 space-y-3 outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <div className="flex items-start gap-3">
        <span className="mt-0.5 inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
          <FlaskConical className="h-4 w-4" aria-hidden />
        </span>
        <div className="min-w-0 space-y-1">
          <p className="text-[15px] font-semibold">{text(t("sample.bannerTitle"))}</p>
          <p className="text-sm text-muted-foreground leading-relaxed">{text(t("sample.bannerBody", { count: rows }))}</p>
          <p className="text-sm text-muted-foreground leading-relaxed">{text(t("sample.bannerHidden"))}</p>
        </div>
      </div>
      {notice?.error === "free_window" && (
        <p className="text-sm leading-relaxed">{text(t("onboarding.noneInWindow", { skipped: notice.skippedTooOld ?? notice.parsed, days: 30 }))}</p>
      )}
      <div className="flex flex-col sm:flex-row sm:items-center gap-2">
        <CsvUpload onUpload={onUpload} />
        <Button type="button" variant="outline" onClick={onExit}>
          {text(t("sample.back"))}
        </Button>
      </div>
    </div>
  );
}
