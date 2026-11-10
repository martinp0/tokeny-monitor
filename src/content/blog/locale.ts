import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import i18n from "@/i18n";
import { isBlogPath, localeFromPath, type BlogLocale } from "./catalog";

/**
 * Language of the blog URL. On /blog and /en/blog the path wins over the
 * saved UI language, so the prerender and a direct visit agree.
 * A full page load is pinned in src/i18n/index.ts; this effect covers in-app navigation.
 */
export function useBlogLocale(): BlogLocale {
  const { pathname } = useLocation();
  const fromPath = localeFromPath(pathname);
  const locale: BlogLocale = fromPath ?? (i18n.language?.startsWith("en") ? "en" : "cs");

  useEffect(() => {
    if (!fromPath || !isBlogPath(pathname)) return;
    if (i18n.language?.startsWith(fromPath)) return;
    void i18n.changeLanguage(fromPath);
  }, [fromPath, pathname]);

  return fromPath ?? locale;
}
