import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  BLOG_POSTS,
  EN_LASTMOD,
  SITE_URL,
  blogIndexPath,
  blogPublicRoutes,
  hrefFor,
  postCanonical,
  postPath,
  postUrl,
  switchBlogPath,
} from "@/content/blog/catalog";
import { buildSitemap, PUBLIC_ROUTES } from "../../scripts/public-routes.mjs";

const ORIGIN = {
  "what-ai-costs": {
    cs: "https://martinpohl.cz/cs/blog/kolik-stoji-ai-tokeny-realne",
    en: "https://martinpohl.cz/en/blog/what-ai-actually-costs",
  },
  "local-models": {
    cs: "https://martinpohl.cz/cs/blog/ai-tokeny-vs-lokalni-modely-doma",
    en: "https://martinpohl.cz/en/blog/cloud-tokens-vs-local-ai-at-home",
  },
} as const;

describe("bilingual blog routes", () => {
  it("gives every article a Czech and an English URL, and lists both", () => {
    const paths = PUBLIC_ROUTES.map((route: { path: string }) => route.path);
    expect(paths).toContain("/blog");
    expect(paths).toContain("/en/blog");
    for (const post of BLOG_POSTS) {
      expect(paths).toContain(postPath(post, "cs"));
      expect(paths).toContain(postPath(post, "en"));
      expect(post.cs.slug.length).toBeGreaterThan(0);
      expect(post.en.slug.length).toBeGreaterThan(0);
    }
    expect(new Set(paths).size).toBe(paths.length);
  });

  it("keeps Tokeny as the canonical for native articles, including the agent-cost post", () => {
    for (const post of BLOG_POSTS) {
      if (post.id in ORIGIN) continue;
      expect(postCanonical(post, "cs")).toBe(postUrl(post, "cs"));
      expect(postCanonical(post, "en")).toBe(postUrl(post, "en"));
      expect(postCanonical(post, "cs")).toMatch(new RegExp(`^${SITE_URL}/blog/`));
      expect(postCanonical(post, "en")).toMatch(new RegExp(`^${SITE_URL}/en/blog/`));
    }
    const agents = BLOG_POSTS.find((post) => post.id === "ai-agents");
    expect(postCanonical(agents!, "cs")).toBe("https://tokeny.martinpohl.cz/blog/kolik-stoji-ai-agenti");
    expect(postCanonical(agents!, "en")).toBe("https://tokeny.martinpohl.cz/en/blog/kolik-stoji-ai-agenti");
  });

  it("points the two martinpohl.cz articles at the matching-language original", () => {
    for (const [id, urls] of Object.entries(ORIGIN)) {
      const post = BLOG_POSTS.find((item) => item.id === id);
      expect(postCanonical(post!, "cs")).toBe(urls.cs);
      expect(postCanonical(post!, "en")).toBe(urls.en);
    }
  });

  it("switches language without dropping the article", () => {
    expect(switchBlogPath("/blog", "en")).toBe("/en/blog");
    expect(switchBlogPath("/en/blog", "cs")).toBe("/blog");
    expect(switchBlogPath("/blog/kolik-stoji-ai-agenti", "en")).toBe("/en/blog/kolik-stoji-ai-agenti");
    expect(switchBlogPath("/blog/kolik-stoji-ai-tokeny-realne", "en")).toBe("/en/blog/what-ai-actually-costs");
    expect(switchBlogPath("/en/blog/cloud-tokens-vs-local-ai-at-home", "cs")).toBe(
      "/blog/ai-tokeny-vs-lokalni-modely-doma",
    );
    expect(switchBlogPath("/llm-cost-calculator", "en")).toBeNull();
    expect(blogIndexPath("en")).toBe("/en/blog");
    expect(hrefFor("track-cursor", "en")).toBe("/en/blog/jak-sledovat-naklady-cursor-a-grok-bot");
  });

  it("puts reciprocal hreflang on every blog URL in the sitemap", () => {
    const xml = buildSitemap();
    expect(readFileSync("public/sitemap.xml", "utf8")).toBe(xml);
    for (const route of blogPublicRoutes()) {
      expect(xml).toContain(`<loc>${SITE_URL}${route.path}</loc>`);
      expect(xml).toContain(`hreflang="cs" href="${route.hreflang.cs}"`);
      expect(xml).toContain(`hreflang="en" href="${route.hreflang.en}"`);
      expect(xml).toContain(`hreflang="x-default" href="${route.hreflang.xDefault}"`);
      expect(route.hreflang.xDefault).toBe(route.hreflang.cs);
      if (route.path.startsWith("/en/")) expect(route.lastmod).toBe(EN_LASTMOD);
    }
    expect(xml).not.toContain("hreflang=\"en\" href=\"https://tokeny.martinpohl.cz/blog?");
    expect(xml).toContain("hreflang=\"en\" href=\"https://tokeny.martinpohl.cz/?lang=en\"");
  });

  it("does not invent the local-model break-even figures in Czech, and keeps them in the English original", () => {
    const cs = readFileSync("src/pages/BlogLocalModels.tsx", "utf8").split("function English")[0];
    const en = readFileSync("src/pages/BlogLocalModels.tsx", "utf8").split("function English")[1];
    expect(cs).not.toMatch(/3,800|3800|18–24/);
    expect(en).toContain("3,800 USD");
    expect(en).toContain("18–24 months");
    expect(readFileSync("src/pages/BlogWhatAiCosts.tsx", "utf8")).toContain("47 espressos");
    expect(readFileSync("src/pages/BlogWhatAiCosts.tsx", "utf8")).toContain("47 espress");
    expect(readFileSync("src/pages/BlogAiAgentCosts.tsx", "utf8")).toContain("7.3 billion");
    expect(readFileSync("src/pages/BlogAiAgentCosts.tsx", "utf8")).toContain("859");
  });

  it("registers every catalogue id on the article route", () => {
    const router = readFileSync("src/pages/BlogArticle.tsx", "utf8");
    for (const post of BLOG_POSTS) expect(router).toContain(`"${post.id}"`);
  });
});
