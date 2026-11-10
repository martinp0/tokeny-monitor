import { useEffect, type ReactNode } from "react";
import { Helmet } from "react-helmet-async";
import { Link, useLocation } from "react-router-dom";
import { LifeBuoy } from "lucide-react";
import { PublicHeader } from "@/components/PublicHeader";
import { csCopy } from "@/lib/cs-typography";
import { SITE_URL } from "@/config/site";
import { PRICING, PRO_TRIAL_DAYS } from "@/config/pricing";
import i18n from "@/i18n";
import type { TFunction } from "i18next";
import { hrefFor } from "@/content/blog/catalog";
import type { ImportSource } from "@/components/import/ImportSourceCards";

/**
 * Support URL for the website, the App Store and the Android app.
 * Czech at /support, English at /en/support (same split as the blog).
 * Facts are the ones already published on /terms, /privacy and in the apps.
 * No phone number: the repo does not publish one.
 */

const UPDATED = { cs: "10. 11. 2026", en: "10 November 2026" };
const OPERATOR = "Bc. Martin Pohl";
const ICO = "17256712";
const SEAT = "Hrnčířská 221, Zdiměřice, 252 42 Jesenice";
const EMAIL = "hello@martinpohl.cz";

type SupportLocale = "cs" | "en";

function supportLocaleFromPath(pathname: string): SupportLocale {
  const path = pathname.split("?")[0].split("#")[0].replace(/\/+$/, "") || "/";
  return path === "/en/support" ? "en" : "cs";
}

const LINK_RE = /\[([^\]]+)\]\(([^)]+)\)/g;

function rich(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  let last = 0;
  for (const m of text.matchAll(LINK_RE)) {
    const [all, label, href] = m;
    const i = m.index ?? 0;
    if (i > last) out.push(text.slice(last, i));
    out.push(
      href.startsWith("/") ? (
        <Link key={i} to={href} className="text-primary hover:underline">{label}</Link>
      ) : (
        <a
          key={i}
          href={href}
          className="text-primary hover:underline"
          {...(href.startsWith("http") ? { target: "_blank", rel: "noopener noreferrer" } : {})}
        >
          {label}
        </a>
      ),
    );
    last = i + all.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

function sourcesOf(t: TFunction): ImportSource[] {
  const raw = t("importSources.items", { returnObjects: true });
  return Array.isArray(raw) ? (raw as ImportSource[]) : [];
}

export default function Support() {
  const { pathname } = useLocation();
  const locale = supportLocaleFromPath(pathname);
  const t = i18n.getFixedT(locale);
  const text = (value: string) => (locale === "cs" ? csCopy(value) : value);
  const fmt = (value: string) => rich(text(value));
  const url = `${SITE_URL}${locale === "en" ? "/en/support" : "/support"}`;
  const vars = {
    email: EMAIL,
    name: OPERATOR,
    ico: ICO,
    seat: SEAT,
    monthly: PRICING.pro.monthly,
    yearly: PRICING.pro.yearly,
    days: PRO_TRIAL_DAYS,
    oneProvider: t("pricing.features.oneProvider"),
    history: t("pricing.features.history30"),
    csv: t("pricing.features.csvImport"),
  };
  const sources = sourcesOf(t);

  useEffect(() => {
    if (i18n.language?.startsWith(locale)) return;
    void i18n.changeLanguage(locale);
  }, [locale]);

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Helmet htmlAttributes={{ lang: locale }}>
        <title>{t("supportPage.metaTitle")}</title>
        <meta name="description" content={t("supportPage.metaDescription")} />
        <link rel="canonical" href={url} />
        <link rel="alternate" hrefLang="cs" href={`${SITE_URL}/support`} />
        <link rel="alternate" hrefLang="en" href={`${SITE_URL}/en/support`} />
        <link rel="alternate" hrefLang="x-default" href={`${SITE_URL}/support`} />
        <meta property="og:title" content={t("supportPage.metaTitle")} />
        <meta property="og:description" content={t("supportPage.metaDescription")} />
        <meta property="og:url" content={url} />
        <meta property="og:type" content="website" />
        <meta property="og:locale" content={locale === "en" ? "en_US" : "cs_CZ"} />
        <meta property="og:locale:alternate" content={locale === "en" ? "cs_CZ" : "en_US"} />
      </Helmet>

      <PublicHeader />

      <article className="container mx-auto px-4 py-16 max-w-3xl">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 text-primary text-xs">
            <LifeBuoy className="h-3 w-3" aria-hidden /> {EMAIL}
          </div>
          <nav aria-label="Language" className="text-sm flex gap-3">
            <Link to="/support" className={locale === "cs" ? "text-primary font-medium" : "text-primary hover:underline"} hrefLang="cs" aria-current={locale === "cs" ? "page" : undefined}>
              Česky
            </Link>
            <Link to="/en/support" className={locale === "en" ? "text-primary font-medium" : "text-primary hover:underline"} hrefLang="en" aria-current={locale === "en" ? "page" : undefined}>
              English
            </Link>
          </nav>
        </div>

        <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-2">{t("supportPage.title")}</h1>
        <p className="text-sm text-muted-foreground mb-6">{t("supportPage.updated", { date: UPDATED[locale] })}</p>
        <p className="text-[17px] leading-relaxed mb-8">{fmt(t("supportPage.intro"))}</p>

        <aside className="glass-panel rounded-3xl p-5 mb-10">
          <h2 className="text-xl font-semibold tracking-tight mb-2">{t("supportPage.contactTitle")}</h2>
          <p className="text-[17px] leading-relaxed mb-2">{fmt(t("supportPage.contact", vars))}</p>
          <p className="text-sm text-muted-foreground leading-relaxed">{fmt(t("supportPage.operator", vars))}</p>
        </aside>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.whatTitle")}</h2>
          <p className="leading-relaxed text-muted-foreground">{fmt(t("supportPage.whatBody"))}</p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.csvTitle")}</h2>
          <p className="leading-relaxed text-muted-foreground mb-4">{fmt(t("importSources.leadDashboard"))}</p>
          <ul className="grid gap-3 sm:grid-cols-3 mb-4">
            {sources.map((source) => (
              <li key={source.id} className="surface rounded-3xl p-5">
                <h3 className="text-[15px] font-semibold mb-1.5">{source.title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{text(source.body)}</p>
                {source.href && source.link && (
                  <a href={source.href} target="_blank" rel="noopener noreferrer" className="mt-3 inline-flex items-center gap-1 text-sm text-primary hover:underline">
                    {source.link}
                  </a>
                )}
              </li>
            ))}
          </ul>
          <div className="space-y-3 leading-relaxed text-muted-foreground">
            <p>{fmt(t("importSources.window"))}</p>
            <p>{fmt(t("importSources.privacyCursor"))}</p>
            <p>{fmt(t("importSources.privacyOpenRouter"))}</p>
            <p>
              <Link to={hrefFor("track-cursor", locale)} className="text-primary hover:underline">
                {text(t("importSources.guide"))}
              </Link>
            </p>
          </div>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.dataTitle")}</h2>
          <ul className="list-disc pl-5 space-y-2 leading-relaxed text-muted-foreground mb-3">
            {(t("supportPage.dataItems", { returnObjects: true }) as string[]).map((item) => (
              <li key={item}>{fmt(item)}</li>
            ))}
          </ul>
          <p className="leading-relaxed text-muted-foreground">{fmt(t("supportPage.dataMore"))}</p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.plansTitle")}</h2>
          <ul className="list-disc pl-5 space-y-2 leading-relaxed text-muted-foreground mb-3">
            <li>{fmt(t("supportPage.planFree", vars))}</li>
            <li>{fmt(t("supportPage.planPro", vars))}</li>
            <li>{fmt(t("supportPage.planVat"))}</li>
            {PRO_TRIAL_DAYS > 0 && <li>{fmt(t("supportPage.planTrial", vars))}</li>}
            <li>{fmt(t("supportPage.planCancel"))}</li>
            <li>{fmt(t("supportPage.planDeleteEnds"))}</li>
          </ul>
          <p className="leading-relaxed text-muted-foreground">{fmt(t("supportPage.planTerms"))}</p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.appsTitle")}</h2>
          <div className="space-y-3 leading-relaxed text-muted-foreground">
            <p>{fmt(t("supportPage.appsApple"))}</p>
            <p>{fmt(t("supportPage.appsAndroid"))}</p>
          </div>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{t("supportPage.deleteTitle")}</h2>
          <div className="space-y-3 leading-relaxed text-muted-foreground">
            <p>{fmt(t("supportPage.deleteAccount"))}</p>
            <p>{fmt(t("supportPage.deleteLocal"))}</p>
            <p>{fmt(t("supportPage.deleteEmail", vars))}</p>
          </div>
        </section>
      </article>

      <footer className="border-t border-border/40 py-8 text-center text-sm text-muted-foreground">
        <p>
          © {new Date().getFullYear()} <Link to="/" className="hover:text-foreground">Tokeny</Link>
          {" · "}
          <Link to="/privacy" className="hover:text-foreground">{t("landing.footer.privacy")}</Link>
          {" · "}
          <Link to="/terms" className="hover:text-foreground">{t("landing.footer.terms")}</Link>
        </p>
      </footer>
    </div>
  );
}
