import { useCallback, useId, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { FileSpreadsheet, FlaskConical, Upload } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { ImportSourceCards } from "@/components/import/ImportSourceCards";
import { csCopy } from "@/lib/cs-typography";
import type { CsvImportResult } from "@/hooks/useDashboardData";
import { FREE_LIMITS } from "@/lib/plan";

interface Props {
  /** Imports the CSV and reports progress 0..1. The hook reports success and failure. */
  onUpload: (file: File, onProgress: (fraction: number) => void) => Promise<unknown> | void;
  /** Loads the bundled sample in this window only. Must not write to the account. */
  onShowSample: () => void;
  notice?: CsvImportResult | null;
}

export function OnboardingEmptyState({ onUpload, onShowSample, notice }: Props) {
  const { t, i18n } = useTranslation();
  const cs = i18n.language?.startsWith("cs") ?? true;
  const text = (s: string) => (cs ? csCopy(s) : s);
  const inputRef = useRef<HTMLInputElement>(null);
  const helpId = useId();
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);

  const handleFile = useCallback(async (file: File) => {
    if (!file.name.toLowerCase().endsWith(".csv")) {
      toast.error(t("onboarding.badType"));
      return;
    }
    setUploading(true);
    setProgress(0);
    try {
      await onUpload(file, setProgress);
    } catch (err) {
      toast.error(t("onboarding.failed"));
      console.error(err);
    } finally {
      setUploading(false);
      setProgress(0);
      if (inputRef.current) inputRef.current.value = "";
    }
  }, [onUpload, t]);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files[0];
    if (file && !uploading) void handleFile(file);
  }, [handleFile, uploading]);

  return (
    <div className="max-w-4xl mx-auto px-1 py-6 md:py-10 space-y-8">
      <div className="text-center space-y-3">
        <p className="eyebrow">{text(t("onboarding.badge"))}</p>
        <h2 className="text-3xl md:text-4xl font-semibold tracking-tight">{text(t("onboarding.title"))}</h2>
        <p className="text-muted-foreground max-w-xl mx-auto leading-relaxed">{text(t("onboarding.lead"))}</p>
      </div>

      <div
        onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={onDrop}
        className={`surface rounded-3xl p-6 md:p-10 border-2 border-dashed transition-colors ${
          dragging ? "border-primary bg-primary/5" : "border-border"
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept=".csv,text/csv"
          className="sr-only"
          tabIndex={-1}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void handleFile(file);
          }}
        />
        <div className="flex flex-col items-center text-center gap-4">
          <div className="h-14 w-14 rounded-2xl bg-primary-fill flex items-center justify-center">
            <Upload className="h-6 w-6 text-white" aria-hidden />
          </div>
          <div>
            <p className="text-lg font-semibold">{text(t("onboarding.dropTitle"))}</p>
            <p id={helpId} className="text-sm text-muted-foreground mt-1">{text(t("onboarding.dropHint"))}</p>
          </div>
          <Button
            type="button"
            size="lg"
            aria-describedby={helpId}
            onClick={() => inputRef.current?.click()}
            disabled={uploading}
            aria-busy={uploading}
            className="gap-2"
          >
            <FileSpreadsheet className="h-4 w-4" aria-hidden />
            {uploading ? t("onboarding.uploading", { pct: Math.round(progress * 100) }) : text(t("onboarding.choose"))}
          </Button>
          <p className="text-sm text-muted-foreground max-w-md leading-relaxed">
            {text(t("onboarding.windowNote", { days: FREE_LIMITS.historyDays }))}
          </p>
        </div>
      </div>

      {notice?.error === "free_window" && (
        <p role="status" className="surface rounded-2xl px-4 py-3 text-sm leading-relaxed">
          {text(t("onboarding.noneInWindow", { skipped: notice.skippedTooOld ?? notice.parsed, days: FREE_LIMITS.historyDays }))}
        </p>
      )}

      <div className="flex flex-col items-center gap-2 text-center">
        <Button type="button" variant="outline" onClick={onShowSample} className="gap-2">
          <FlaskConical className="h-4 w-4" aria-hidden />
          {text(t("onboarding.sampleCta"))}
        </Button>
        <p className="text-sm text-muted-foreground max-w-md leading-relaxed">{text(t("onboarding.sampleHint"))}</p>
      </div>

      <ImportSourceCards context="dashboard" />
    </div>
  );
}
