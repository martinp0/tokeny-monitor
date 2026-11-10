import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ExternalLink } from "lucide-react";
import { Button } from "@/components/ui/button";
import { csCopy } from "@/lib/cs-typography";
import { hrefFor } from "@/content/blog/catalog";

export interface ImportSource {
  id: string;
  title: string;
  body: string;
  href?: string;
  link?: string;
}

interface Props {
  /** Account CTA. Omitted on the dashboard, where the drop zone is the action. */
  ctaHref?: string;
  ctaLabel?: string;
  /** Landing copy points at the preview above. The empty dashboard has no preview above it. */
  context?: "landing" | "dashboard";
}

/** Where a first CSV actually comes from. Shared by the landing preview and the empty dashboard. */
export function ImportSourceCards({ ctaHref, ctaLabel, context = "landing" }: Props) {
  const { t, i18n } = useTranslation();
  const cs = i18n.language?.startsWith("cs") ?? true;
  const text = (s: string) => (cs ? csCopy(s) : s);
  const leadKey = context === "dashboard" ? "importSources.leadDashboard" : "importSources.lead";
  const sources = t("importSources.items", { returnObjects: true }) as ImportSource[];
  const list = Array.isArray(sources) ? sources : [];

  return (
    <div className="space-y-4">
      <div className="text-center space-y-2">
        <h2 className="text-xl md:text-2xl font-semibold tracking-tight">{text(t("importSources.title"))}</h2>
        <p className="text-sm md:text-[15px] text-muted-foreground leading-relaxed max-w-2xl mx-auto">{text(t(leadKey))}</p>
      </div>
      <ul className="grid gap-3 md:grid-cols-3">
        {list.map((source) => (
          <li key={source.id} className="surface rounded-3xl p-5 text-left">
            <h3 className="text-[15px] font-semibold mb-1.5">{source.title}</h3>
            <p className="text-sm text-muted-foreground leading-relaxed">{text(source.body)}</p>
            {source.href && source.link && (
              <a
                href={source.href}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-3 inline-flex items-center gap-1 min-h-11 text-sm text-primary hover:underline"
              >
                {source.link}
                <ExternalLink className="h-3.5 w-3.5" aria-hidden />
              </a>
            )}
          </li>
        ))}
      </ul>
      <div className="surface rounded-3xl p-5 space-y-2 text-sm text-muted-foreground leading-relaxed">
        <p>{text(t("importSources.window"))}</p>
        <p>{text(t("importSources.privacyCursor"))}</p>
        <p>{text(t("importSources.privacyOpenRouter"))}</p>
        <p>{text(t("importSources.proBridge"))}</p>
        <p>
          <Link to={hrefFor("track-cursor", cs ? "cs" : "en")} className="text-primary hover:underline min-h-11 inline-flex items-center">
            {text(t("importSources.guide"))}
          </Link>
        </p>
      </div>
      {ctaHref && ctaLabel && (
        <div className="flex justify-center">
          <Button asChild>
            <Link to={ctaHref}>{ctaLabel}</Link>
          </Button>
        </div>
      )}
    </div>
  );
}
