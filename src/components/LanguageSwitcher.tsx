import { useTranslation } from "react-i18next";
import { useLocation, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Globe } from "lucide-react";
import { cn } from "@/lib/utils";
import { isBlogPath, switchBlogPath, type BlogLocale } from "@/content/blog/catalog";

export function LanguageSwitcher({ size = "sm", className }: { size?: "sm" | "default"; className?: string }) {
  const { i18n, t } = useTranslation();
  const location = useLocation();
  const navigate = useNavigate();
  const toEnglish = !i18n.language?.startsWith("en");

  const toggle = () => {
    const next: BlogLocale = toEnglish ? "en" : "cs";
    const target = isBlogPath(location.pathname) ? switchBlogPath(location.pathname, next) : null;
    void i18n.changeLanguage(next);
    if (target && target !== location.pathname) navigate(target);
  };

  return (
    <Button
      variant="ghost"
      size={size}
      onClick={toggle}
      className={cn("gap-1.5 tabular-nums text-xs text-muted-foreground hover:text-foreground", className)}
      title={toEnglish ? "Switch to English" : "Přepnout do češtiny"}
      aria-label={toEnglish ? "Switch to English" : "Přepnout do češtiny"}
    >
      <Globe className="h-3.5 w-3.5" aria-hidden />
      {t("lang.switch")}
    </Button>
  );
}
