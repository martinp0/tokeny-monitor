import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import cs from "./cs.json";
import en from "./en.json";

const isBrowser = typeof window !== "undefined";

/**
 * Prerendered URLs choose the language so the HTML matches the path.
 * /en/… is English. /blog and /support stay Czech. Everywhere else still uses ?lang= and localStorage.
 */
function blogPathLanguage(): "cs" | "en" | undefined {
  if (!isBrowser) return undefined;
  const path = window.location.pathname.replace(/\/+$/, "") || "/";
  if (path === "/en" || path.startsWith("/en/")) return "en";
  if (path === "/blog" || path.startsWith("/blog/")) return "cs";
  if (path === "/support") return "cs";
  return undefined;
}

const pathLanguage = blogPathLanguage();

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      cs: { translation: cs },
      en: { translation: en },
    },
    fallbackLng: "cs",
    // Pin prerender (Czech unless entry-server switches) and URLs that choose a language (/blog, /en/…, /support).
    // Elsewhere the browser still detects ?lang=, localStorage and <html lang>.
    ...(pathLanguage ? { lng: pathLanguage } : isBrowser ? {} : { lng: "cs" }),
    interpolation: {
      escapeValue: false,
    },
    react: { useSuspense: false },
    detection: {
      order: ["querystring", "localStorage", "htmlTag"],
      lookupQuerystring: "lang",
      lookupLocalStorage: "tokeny_lang",
      caches: isBrowser ? ["localStorage"] : [],
    },
  });

export default i18n;
