/**
 * Blog catalogue: one record per article, Czech and English.
 * scripts/public-routes.mjs imports this for the sitemap and the prerender,
 * so slugs, canonicals and hreflang stay in one place.
 *
 * Syndicated posts (canonical set) were first published on martinpohl.cz.
 * Tokeny-native posts canonicalise to tokeny.martinpohl.cz.
 */

export type BlogLocale = "cs" | "en";

export const SITE_URL = "https://tokeny.martinpohl.cz";

export type BlogCopy = {
  slug: string;
  /** Page <title> and <h1>. */
  title: string;
  /** Meta description and the standfirst under the title. */
  description: string;
  /** Index card title. Defaults to `title`. */
  listTitle?: string;
  excerpt: string;
  tag: string;
  keywords: string;
  dateLabel: string;
};

export type BlogPost = {
  id: string;
  /** ISO date shown as the publication date. */
  date: string;
  /** lastmod of the existing Czech URL. English URLs are new and use EN_LASTMOD. */
  lastmod: string;
  priority: string;
  cs: BlogCopy;
  en: BlogCopy;
  /**
   * Absolute canonical URL when this copy is a republication.
   * Missing locale means the Tokeny URL is the original.
   */
  canonical?: Partial<Record<BlogLocale, string>>;
};

/** When the English pages were added. */
export const EN_LASTMOD = "2026-11-10";

export const BLOG_POSTS: BlogPost[] = [
  {
    id: "track-cursor",
    date: "2026-11-05",
    lastmod: "2026-11-05",
    priority: "0.8",
    cs: {
      slug: "jak-sledovat-naklady-cursor-a-grok-bot",
      title: "Jak sledovat náklady na Cursor, Grok Bot a OpenRouter (a nepřeplácet)",
      description:
        "Praktický návod pro každého, kdo platí za Cursor, Grok Bot nebo OpenRouter: kde vzít data o útratě, co v nich sledovat, jak nastavit kontrolu a jak to celé dostat do jednoho přehledu v korunách.",
      excerpt:
        "Kde vzít data o útratě, která čtyři čísla sledovat, jak nastavit kontrolu a jak to dostat do jednoho přehledu v korunách.",
      tag: "Návod",
      keywords:
        "cursor cena, cursor náklady, grok bot cena, openrouter náklady, sledování nákladů ai, on-demand cursor, usage export csv, tokeny",
      dateLabel: "5. 11. 2026",
    },
    en: {
      slug: "jak-sledovat-naklady-cursor-a-grok-bot",
      title: "How to track spend on Cursor, Grok Bot and OpenRouter (without overpaying)",
      description:
        "A practical guide for anyone paying for Cursor, Grok Bot or OpenRouter: where the usage data comes from, which numbers to watch, how to set a check, and how to put it in one overview in Czech crowns.",
      excerpt:
        "Where the spend data comes from, the four numbers worth watching, how to set a check, and how to get it into one overview in crowns.",
      tag: "Guide",
      keywords:
        "cursor cost, cursor spend, grok bot cost, openrouter spend, ai cost tracking, cursor on-demand, usage export csv, tokens",
      dateLabel: "5 Nov 2026",
    },
  },
  {
    id: "ai-agents",
    date: "2026-10-30",
    lastmod: "2026-10-30",
    priority: "0.8",
    cs: {
      slug: "kolik-stoji-ai-agenti",
      title: "Kolik doopravdy stojí AI agenti: měsíc dat, 7,3 miliardy tokenů a 859 dolarů",
      description:
        "Měsíc reálných dat z Grok Botu a Cursoru: 85 179 volání modelu, přes 7,3 miliardy tokenů, 95 % z mezipaměti a 859 USD nad rámec tarifu. Co z toho plyne.",
      excerpt:
        "Říjen 2026 z Grok Botu a Cursoru: 85 179 volání, 95 % tokenů z mezipaměti a útrata, která přichází ve skocích.",
      tag: "Reálná data",
      keywords: "kolik stojí ai agenti, náklady na ai agenty, grok bot cena, cursor cena, prompt caching, tokeny, on-demand",
      dateLabel: "30. 10. 2026",
    },
    en: {
      slug: "kolik-stoji-ai-agenti",
      title: "What AI agents actually cost: a month of data, 7.3 billion tokens and $859",
      description:
        "A month of real data from Grok Bot and Cursor: 85,179 model calls, over 7.3 billion tokens, 95% served from cache, and $859 above the plan. What that implies.",
      excerpt:
        "October 2026 from Grok Bot and Cursor: 85,179 calls, 95% of tokens from cache, and spend that arrives in jumps.",
      tag: "Measured data",
      keywords: "ai agent cost, grok bot price, cursor price, prompt caching, tokens, on-demand",
      dateLabel: "30 Oct 2026",
    },
  },
  {
    id: "grok-tokens",
    date: "2026-10-07",
    lastmod: "2026-10-07",
    priority: "0.8",
    cs: {
      slug: "grok-token-optimization",
      title: "Jak optimalizovat tokeny u Grok API (xAI): 7 praktických tipů",
      description:
        "Jak snížit spotřebu tokenů a náklady při používání Grok bota přes xAI API: kratší výstupy, správa historie, prompt caching, výběr modelu a měření.",
      excerpt: "Kratší výstupy, správa historie, prompt caching, výběr modelu a měření. Jak snížit účet za Grok.",
      tag: "Cost optimization",
      keywords: "grok api cost, xai grok tokeny, grok token optimization, grok pricing, snížení nákladů grok",
      dateLabel: "7. 10. 2026",
    },
    en: {
      slug: "grok-token-optimization",
      title: "How to optimize tokens on the Grok API (xAI): 7 practical tips",
      description:
        "How to cut token use and cost when running a Grok bot through the xAI API: shorter outputs, history management, prompt caching, model choice and measurement.",
      excerpt: "Shorter outputs, history management, prompt caching, model choice and measurement. How to lower a Grok bill.",
      tag: "Cost optimization",
      keywords: "grok api cost, xai grok tokens, grok token optimization, grok pricing, reduce grok cost",
      dateLabel: "7 Oct 2026",
    },
  },
  {
    id: "local-models",
    date: "2026-07-19",
    lastmod: "2026-07-19",
    priority: "0.7",
    canonical: {
      cs: "https://martinpohl.cz/cs/blog/ai-tokeny-vs-lokalni-modely-doma",
      en: "https://martinpohl.cz/en/blog/cloud-tokens-vs-local-ai-at-home",
    },
    cs: {
      slug: "ai-tokeny-vs-lokalni-modely-doma",
      title: "AI tokeny vs. lokální modely doma: kdy se vyplatí GPU vedle NASky",
      description:
        "Kolik reálně stojí Claude, GPT a Gemini po tokenech — a od kdy se vyplatí koupit si vlastní hardware na lokální AI, který postavíte vedle Synology NAS.",
      excerpt:
        "Ceny cloudových tokenů v červenci 2026 a tři úrovně domácího hardware vedle Synology NAS. Originál je na martinpohl.cz.",
      tag: "AI",
      keywords:
        "lokální AI, self-hosted LLM, cena AI tokenů, Ollama, LM Studio, vLLM, Synology NAS, Mac mini M4, RTX 5090, domácí AI server",
      dateLabel: "19. 7. 2026",
    },
    en: {
      slug: "cloud-tokens-vs-local-ai-at-home",
      title: "Cloud AI tokens vs. local models at home: when a GPU next to your NAS pays off",
      description:
        "What Claude, GPT and Gemini actually cost per token — and when it makes sense to buy your own hardware and run local AI right next to your Synology NAS.",
      excerpt:
        "July 2026 cloud token prices and three tiers of home hardware next to a Synology NAS. The original is on martinpohl.cz.",
      tag: "AI",
      keywords:
        "local AI, self-hosted LLM, AI token pricing, Ollama, LM Studio, vLLM, Synology NAS, Mac mini M4, RTX 5090, home AI server",
      dateLabel: "19 July 2026",
    },
  },
  {
    id: "multi-provider",
    date: "2026-06-30",
    lastmod: "2026-10-30",
    priority: "0.8",
    cs: {
      slug: "multi-provider-monitoring",
      title: "Multi-provider monitoring: OpenRouter, Anthropic a OpenAI v jednom dashboardu",
      listTitle: "Multi-provider monitoring: 7 AI providerů v jednom dashboardu",
      description:
        "Tokeny spojí útratu z OpenRouteru, Anthropicu a OpenAI do jednoho přehledu. Gemini, Mistral, Groq i Grok uvidíš přes OpenRouter. Proč to dává smysl a jak začít.",
      excerpt:
        "OpenRouter, Anthropic, OpenAI, Gemini, Mistral, Groq a xAI (Grok) v jednom přehledu. Proč to dává smysl a jak začít.",
      tag: "Product update",
      keywords: "multi-provider AI, OpenRouter, Anthropic, OpenAI, Gemini, Mistral, Groq, xAI, Grok, monitoring AI nákladů",
      dateLabel: "30. 6. 2026",
    },
    en: {
      slug: "multi-provider-monitoring",
      title: "Multi-provider monitoring: OpenRouter, Anthropic and OpenAI in one dashboard",
      listTitle: "Multi-provider monitoring: seven AI providers in one dashboard",
      description:
        "Tokeny puts spend from OpenRouter, Anthropic and OpenAI in one view. Gemini, Mistral, Groq and Grok show up when you call them through OpenRouter. Why that helps, and how to start.",
      excerpt:
        "OpenRouter, Anthropic, OpenAI, Gemini, Mistral, Groq and xAI (Grok) in one view. Why it helps, and how to start.",
      tag: "Product update",
      keywords: "multi-provider AI, OpenRouter, Anthropic, OpenAI, Gemini, Mistral, Groq, xAI, Grok, AI cost monitoring",
      dateLabel: "30 June 2026",
    },
  },
  {
    id: "model-comparison",
    date: "2026-05-25",
    lastmod: "2026-05-25",
    priority: "0.7",
    cs: {
      slug: "gpt-vs-claude-vs-gemini",
      title: "GPT-5 vs Claude vs Gemini: srovnání 2026 (cena, rychlost, kvalita)",
      description:
        "Detailní srovnání flagship modelů OpenAI, Anthropic a Google v roce 2026. Ceny per 1M tokenů, latence, context window, silné a slabé stránky — s doporučením, kdy který zvolit.",
      excerpt: "Přímé srovnání flagship modelů — ceny per 1M tokenů, context window, silné a slabé stránky. Kdy který zvolit.",
      tag: "Model comparison",
      keywords:
        "gpt-5 vs claude, claude vs gemini, gpt vs claude vs gemini, llm comparison 2026, best llm 2026, openai vs anthropic vs google, llm pricing comparison",
      dateLabel: "25. 5. 2026",
    },
    en: {
      slug: "gpt-vs-claude-vs-gemini",
      title: "GPT-5 vs Claude vs Gemini: a 2026 comparison (price, speed, quality)",
      description:
        "A direct comparison of the 2026 flagship models from OpenAI, Anthropic and Google. Price per 1M tokens, latency, context window, strengths and weaknesses, and when to pick which.",
      excerpt: "A direct comparison of the flagships: price per 1M tokens, context window, strengths and weaknesses. When to pick which.",
      tag: "Model comparison",
      keywords:
        "gpt-5 vs claude, claude vs gemini, gpt vs claude vs gemini, llm comparison 2026, best llm 2026, openai vs anthropic vs google, llm pricing comparison",
      dateLabel: "25 May 2026",
    },
  },
  {
    id: "monitoring",
    date: "2026-05-25",
    lastmod: "2026-05-25",
    priority: "0.7",
    cs: {
      slug: "monitoring-ai-costs",
      title: "Monitoring AI nákladů: co měřit, jaké alerty nastavit a proč",
      description:
        "Praktický návod, jaké KPI sledovat u LLM API — od daily spend přes anomálie po runaway agenty. S příklady alertů, dashboardů a typických red flagů.",
      excerpt: "5 KPI, smysluplné alerty, red flagy v dashboardu a setup za 10 minut. FinOps pro LLM API.",
      tag: "Monitoring & FinOps",
      keywords:
        "ai cost monitoring, llm monitoring, openai usage tracking, anthropic cost tracking, ai finops, llm observability, ai budget alerts, runaway agent detection",
      dateLabel: "25. 5. 2026",
    },
    en: {
      slug: "monitoring-ai-costs",
      title: "Monitoring AI costs: what to measure, which alerts to set, and why",
      description:
        "A practical guide to the KPIs worth watching on an LLM API, from daily spend through anomalies to runaway agents. With example alerts and the usual red flags.",
      excerpt: "Five KPIs, alerts that mean something, red flags on the dashboard, and a 10-minute setup. FinOps for LLM APIs.",
      tag: "Monitoring & FinOps",
      keywords:
        "ai cost monitoring, llm monitoring, openai usage tracking, anthropic cost tracking, ai finops, llm observability, ai budget alerts, runaway agent detection",
      dateLabel: "25 May 2026",
    },
  },
  {
    id: "ai-cost-saving",
    date: "2026-05-19",
    lastmod: "2026-05-19",
    priority: "0.7",
    cs: {
      slug: "ai-cost-saving",
      title: "10 způsobů, jak ušetřit na AI API nákladech v roce 2026",
      description:
        "Praktický playbook pro snížení LLM nákladů o 40–80 % bez ztráty kvality. Caching, model routing, batch API, prompt komprese a další taktiky s reálnými čísly.",
      excerpt: "Praktický playbook pro snížení LLM nákladů o 40–80 % bez ztráty kvality. Caching, routing, batch API a další taktiky.",
      tag: "Cost optimization",
      keywords: "ai cost saving, llm cost optimization, openai cost reduction, claude cost saving, prompt caching, ai api savings",
      dateLabel: "19. 5. 2026",
    },
    en: {
      slug: "ai-cost-saving",
      title: "10 ways to cut AI API costs in 2026",
      description:
        "A practical playbook for cutting LLM costs by 40–80% without giving up quality. Caching, model routing, batch APIs, prompt compression and other tactics, with the figures attached.",
      excerpt: "A practical playbook for cutting LLM costs by 40–80% without losing quality. Caching, routing, batch APIs and other tactics.",
      tag: "Cost optimization",
      keywords: "ai cost saving, llm cost optimization, openai cost reduction, claude cost saving, prompt caching, ai api savings",
      dateLabel: "19 May 2026",
    },
  },
  {
    id: "prompt-optimization",
    date: "2026-05-19",
    lastmod: "2026-05-19",
    priority: "0.7",
    cs: {
      slug: "prompt-optimization",
      title: "Optimalizace promptů: jak zkrátit tokeny a zlepšit výsledky",
      description:
        "Konkrétní techniky prompt optimization — strukturované prompty, few-shot pruning, prompt compression. S příklady před/po a měřitelným dopadem na cenu i kvalitu.",
      excerpt: "Konkrétní techniky — od strukturovaných promptů přes few-shot pruning po prompt compression. S příklady před/po.",
      tag: "Prompt engineering",
      keywords: "prompt optimization, prompt engineering, prompt compression, few-shot pruning, token reduction, llm prompt cost",
      dateLabel: "19. 5. 2026",
    },
    en: {
      slug: "prompt-optimization",
      title: "Prompt optimization: how to shorten tokens and improve the result",
      description:
        "Concrete prompt-optimization techniques: structured prompts, few-shot pruning, prompt compression. With before/after examples and a measurable effect on price and quality.",
      excerpt: "Concrete techniques, from structured prompts through few-shot pruning to prompt compression. With before/after examples.",
      tag: "Prompt engineering",
      keywords: "prompt optimization, prompt engineering, prompt compression, few-shot pruning, token reduction, llm prompt cost",
      dateLabel: "19 May 2026",
    },
  },
  {
    id: "token-window",
    date: "2026-05-19",
    lastmod: "2026-05-19",
    priority: "0.7",
    cs: {
      slug: "token-window",
      title: "Token window: jak pracovat s dlouhým kontextem chytře",
      description:
        "Sliding window, RAG, summary chains a context pruning. Kdy se vyplatí 1M token context window a kdy je to drahý overkill.",
      excerpt: "Sliding window, RAG, summary chains a context pruning. Kdy se vyplatí 1M context a kdy je to drahý overkill.",
      tag: "Context management",
      keywords: "token window, context window, long context llm, sliding window, rag, summary chain, context pruning, gemini 1m tokens",
      dateLabel: "19. 5. 2026",
    },
    en: {
      slug: "token-window",
      title: "Token window: how to work with a long context without wasting it",
      description:
        "Sliding windows, RAG, summary chains and context pruning. When a 1M-token context window earns its price, and when it is an expensive overkill.",
      excerpt: "Sliding windows, RAG, summary chains and context pruning. When a 1M context earns its keep, and when it is expensive overkill.",
      tag: "Context management",
      keywords: "token window, context window, long context llm, sliding window, rag, summary chain, context pruning, gemini 1m tokens",
      dateLabel: "19 May 2026",
    },
  },
  {
    id: "what-ai-costs",
    date: "2026-03-20",
    lastmod: "2026-03-20",
    priority: "0.7",
    canonical: {
      cs: "https://martinpohl.cz/cs/blog/kolik-stoji-ai-tokeny-realne",
      en: "https://martinpohl.cz/en/blog/what-ai-actually-costs",
    },
    cs: {
      slug: "kolik-stoji-ai-tokeny-realne",
      title: "Kolik tě reálně stojí AI? Příběh za projektem tokeny.pohl.uk",
      description:
        "Postavil jsem dashboard, který sleduje moje OpenRouter náklady. Tady je, co mě překvapilo a proč to možná potřebuješ taky.",
      excerpt:
        "OpenRouter faktura, export do tabulky a dashboard, který z toho umí udělat graf. Originál je na martinpohl.cz.",
      tag: "Indie projekty",
      keywords: "openrouter náklady, ai tokeny cena, tokeny dashboard, kolik stojí ai",
      dateLabel: "20. 3. 2026",
    },
    en: {
      slug: "what-ai-actually-costs",
      title: "What AI actually costs: the story behind tokeny.pohl.uk",
      description:
        "I built a dashboard that tracks my OpenRouter spend. Here is what surprised me, and why you might want the same view.",
      excerpt: "An OpenRouter invoice, a spreadsheet export, and a dashboard that turns it into charts. The original is on martinpohl.cz.",
      tag: "Indie projects",
      keywords: "openrouter spend, ai token cost, tokeny dashboard, what ai costs",
      dateLabel: "20 March 2026",
    },
  },
];

export type BlogHreflang = { cs: string; en: string; xDefault: string };

export type BlogPublicRoute = {
  path: string;
  lastmod: string;
  changefreq: "weekly" | "monthly";
  priority: string;
  canonical: string;
  hreflang: BlogHreflang;
};

export function normalizePath(pathname: string): string {
  const path = pathname.split("?")[0].split("#")[0].replace(/\/+$/, "");
  return path || "/";
}

export function blogIndexPath(locale: BlogLocale): string {
  return locale === "en" ? "/en/blog" : "/blog";
}

export function absoluteUrl(path: string): string {
  return `${SITE_URL}${path === "/" ? "/" : path}`;
}

export function findPost(id: string): BlogPost {
  const post = BLOG_POSTS.find((item) => item.id === id);
  if (!post) throw new Error(`Unknown blog post: ${id}`);
  return post;
}

export function findPostBySlug(locale: BlogLocale, slug: string): BlogPost | null {
  return BLOG_POSTS.find((item) => item[locale].slug === slug) ?? null;
}

export function postPath(post: BlogPost, locale: BlogLocale): string {
  return `${blogIndexPath(locale)}/${post[locale].slug}`;
}

export function postUrl(post: BlogPost, locale: BlogLocale): string {
  return absoluteUrl(postPath(post, locale));
}

export function hrefFor(id: string, locale: BlogLocale): string {
  return postPath(findPost(id), locale);
}

/** Canonical URL for this language. Syndicated posts point at martinpohl.cz. */
export function postCanonical(post: BlogPost, locale: BlogLocale): string {
  return post.canonical?.[locale] ?? postUrl(post, locale);
}

export function isSyndicated(post: BlogPost, locale: BlogLocale): boolean {
  return postCanonical(post, locale) !== postUrl(post, locale);
}

export function localeFromPath(pathname: string): BlogLocale | null {
  const path = normalizePath(pathname);
  if (path === "/en" || path.startsWith("/en/")) return "en";
  if (path === "/blog" || path.startsWith("/blog/")) return "cs";
  return null;
}

export function isBlogPath(pathname: string): boolean {
  const path = normalizePath(pathname);
  return path === "/blog" || path.startsWith("/blog/") || path === "/en/blog" || path.startsWith("/en/blog/");
}

/** The other language's URL for a blog index or article. Unknown slugs fall back to the index. */
export function switchBlogPath(pathname: string, next: BlogLocale): string | null {
  const path = normalizePath(pathname);
  if (!isBlogPath(path)) return null;
  if (path === "/blog" || path === "/en/blog") return blogIndexPath(next);
  const locale = localeFromPath(path);
  if (!locale) return blogIndexPath(next);
  const slug = path.slice(blogIndexPath(locale).length + 1);
  const post = findPostBySlug(locale, slug);
  return post ? postPath(post, next) : blogIndexPath(next);
}

function pair(post: BlogPost): BlogHreflang {
  return { cs: postUrl(post, "cs"), en: postUrl(post, "en"), xDefault: postUrl(post, "cs") };
}

/** Indexable blog URLs. Czech keeps the historical paths; English lives under /en/blog. */
export function blogPublicRoutes(): BlogPublicRoute[] {
  const indexHreflang: BlogHreflang = {
    cs: absoluteUrl("/blog"),
    en: absoluteUrl("/en/blog"),
    xDefault: absoluteUrl("/blog"),
  };
  const indexes: BlogPublicRoute[] = (["cs", "en"] as const).map((locale) => ({
    path: blogIndexPath(locale),
    lastmod: EN_LASTMOD,
    changefreq: "weekly",
    priority: "0.7",
    canonical: absoluteUrl(blogIndexPath(locale)),
    hreflang: indexHreflang,
  }));
  const articles = BLOG_POSTS.flatMap((post) =>
    (["cs", "en"] as const).map((locale): BlogPublicRoute => ({
      path: postPath(post, locale),
      // English URLs and the two newly imported Czech URLs are new. Existing Czech URLs keep their lastmod.
      lastmod: locale === "en" || post.canonical ? EN_LASTMOD : post.lastmod,
      changefreq: "monthly",
      priority: post.priority,
      canonical: postCanonical(post, locale),
      hreflang: pair(post),
    })),
  );
  return [...indexes, ...articles];
}
