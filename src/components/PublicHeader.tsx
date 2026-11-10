import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Activity } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/ThemeToggle";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";
import { blogIndexPath, type BlogLocale } from "@/content/blog/catalog";

/** Sticky glass navigation bar shared by the public SEO pages (calculator, pricing guides, blog). */
export function PublicHeader() {
  const { t, i18n } = useTranslation();
  const locale: BlogLocale = i18n.language?.startsWith("en") ? "en" : "cs";
  return (
    <header className="sticky top-0 z-50 glass-bar pt-safe">
      <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-card focus:px-4 focus:py-2">
        {t("landing.nav.skip")}
      </a>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-14 flex items-center justify-between gap-2">
        <Link to="/" className="tap-target flex items-center gap-2" aria-label="Tokeny">
          <span className="h-7 w-7 rounded-lg bg-primary-fill flex items-center justify-center">
            <Activity className="h-4 w-4 text-white" aria-hidden />
          </span>
          <span className="text-[17px] font-semibold tracking-tight">Tokeny</span>
        </Link>
        <nav aria-label="Primary" className="flex items-center gap-0.5">
          <Button asChild variant="ghost" size="sm" className="hidden sm:inline-flex">
            <Link to="/llm-cost-calculator">{t("landing.footer.calculator")}</Link>
          </Button>
          <Button asChild variant="ghost" size="sm" className="hidden sm:inline-flex">
            <Link to={blogIndexPath(locale)}>{t("landing.footer.blog")}</Link>
          </Button>
          <LanguageSwitcher />
          <ThemeToggle />
          <Button asChild size="sm" className="ml-1">
            <Link to="/auth">{t("nav.startFree")}</Link>
          </Button>
        </nav>
      </div>
    </header>
  );
}
