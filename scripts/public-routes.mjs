/**
 * Public, indexable routes. Single source for the prerender and sitemap.xml.
 * Blog URLs come from src/content/blog/catalog.ts (Czech paths plus /en/blog).
 * Keep the non-blog paths in sync with <AppRoutes /> in src/App.tsx.
 */
import { blogPublicRoutes } from "../src/content/blog/catalog.ts";

export const SITE_URL = "https://tokeny.martinpohl.cz";

export const PUBLIC_ROUTES = [
  { path: "/", lastmod: "2026-10-30", changefreq: "weekly", priority: "1.0", alternates: true },
  { path: "/llm-cost-calculator", lastmod: "2026-10-30", changefreq: "weekly", priority: "0.9" },
  { path: "/claude-api-cost", lastmod: "2026-10-30", changefreq: "monthly", priority: "0.8" },
  { path: "/gpt-api-cost", lastmod: "2026-10-30", changefreq: "monthly", priority: "0.8" },
  { path: "/how-to-calculate-llm-cost", lastmod: "2026-10-30", changefreq: "monthly", priority: "0.7" },
  ...blogPublicRoutes(),
  { path: "/privacy", lastmod: "2026-10-31", changefreq: "yearly", priority: "0.3" },
  { path: "/terms", lastmod: "2026-10-31", changefreq: "yearly", priority: "0.3" },
];

function hreflangLinks(route) {
  if (route.hreflang) {
    const { cs, en, xDefault } = route.hreflang;
    return (
      `\n    <xhtml:link rel="alternate" hreflang="cs" href="${cs}" />` +
      `\n    <xhtml:link rel="alternate" hreflang="en" href="${en}" />` +
      `\n    <xhtml:link rel="alternate" hreflang="x-default" href="${xDefault}" />`
    );
  }
  if (route.alternates) {
    const loc = `${SITE_URL}${route.path}`;
    return (
      `\n    <xhtml:link rel="alternate" hreflang="cs" href="${loc}" />` +
      `\n    <xhtml:link rel="alternate" hreflang="en" href="${loc}?lang=en" />` +
      `\n    <xhtml:link rel="alternate" hreflang="x-default" href="${loc}" />`
    );
  }
  return "";
}

export function buildSitemap() {
  const urls = PUBLIC_ROUTES.map((r) => {
    const loc = `${SITE_URL}${r.path}`;
    return `  <url>\n    <loc>${loc}</loc>\n    <lastmod>${r.lastmod}</lastmod>\n    <changefreq>${r.changefreq}</changefreq>\n    <priority>${r.priority}</priority>${hreflangLinks(r)}\n  </url>`;
  });
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${urls.join("\n")}\n</urlset>\n`;
}
