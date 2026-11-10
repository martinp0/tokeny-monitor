import { Helmet } from "react-helmet-async";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ArrowLeft, ArrowRight, BookOpen, Calculator, Calendar, FileText } from "lucide-react";
import { ReactNode } from "react";
import { useTranslation } from "react-i18next";
import ShareButtons from "@/components/ShareButtons";
import { PublicHeader } from "@/components/PublicHeader";
import { csCopy } from "@/lib/cs-typography";
import { isNativeAppSurface, supportHref } from "@/lib/support";
import {
  blogIndexPath,
  findPost,
  findPostBySlug,
  hrefFor,
  isSyndicated,
  postCanonical,
  postUrl,
  SITE_URL,
  type BlogLocale,
} from "@/content/blog/catalog";
import { useBlogLocale } from "@/content/blog/locale";

interface BlogPostLayoutProps {
  title: string;
  description: string;
  slug: string;
  date: string;
  /** Human-readable date shown on the page (defaults to the ISO date). */
  dateLabel?: string;
  tag: string;
  keywords: string;
  /** Defaults to the language of the URL, then the UI language. */
  locale?: BlogLocale;
  children: ReactNode;
}

const UI = {
  cs: {
    back: "Zpět na blog",
    related: "Související návody a ceníky",
    home: "Domů",
    blog: "Blog",
    calc: "Odhad nákladů na 11 modelů",
    gpt: "Per-token ceník OpenAI modelů",
    claude: "Haiku, Sonnet, Opus pricing",
    how: "Krok za krokem — vzorec a tipy",
    howTitle: "Jak spočítat LLM cost",
    save: "10 způsobů úspor",
    saveBlurb: "Caching, routing, batch API",
    prompt: "Optimalizace promptů",
    promptBlurb: "Zkrátit tokeny o 30–60 %",
    window: "Token window strategie",
    windowBlurb: "RAG, sliding window, pruning",
    ctaTitle: "Sleduj reálné AI náklady, ne jen odhady",
    ctaBody:
      "Nahraj CSV z Cursoru, Grok Bota nebo OpenRouteru a uvidíš denní útratu v USD i v korunách. Účet je zdarma a kartu nechce.",
    ctaPrimary: "Začít zdarma",
    ctaSecondary: "Otevřít kalkulačku",
    origin:
      "Tento text původně vyšel na martinpohl.cz. Tady je přetištěný a odkazuje na originál.",
    originLink: "Původní článek",
  },
  en: {
    back: "Back to the blog",
    related: "Related guides and price pages",
    home: "Home",
    blog: "Blog",
    calc: "Estimate across 11 models",
    gpt: "Per-token prices for OpenAI models",
    claude: "Haiku, Sonnet, Opus pricing",
    how: "The formula, step by step",
    howTitle: "How to calculate LLM cost",
    save: "10 ways to save",
    saveBlurb: "Caching, routing, batch APIs",
    prompt: "Prompt optimization",
    promptBlurb: "Cut tokens by 30–60%",
    window: "Token window strategy",
    windowBlurb: "RAG, sliding window, pruning",
    ctaTitle: "Track real AI spend, not just estimates",
    ctaBody:
      "Upload a CSV from Cursor, Grok Bot or OpenRouter and see daily spend in USD and CZK. The account is free and does not ask for a card.",
    ctaPrimary: "Start for free",
    ctaSecondary: "Open the calculator",
    origin: "This piece was first published on martinpohl.cz. This page is a copy and points at the original.",
    originLink: "Original article",
  },
} as const;

/** Shared head/chrome for a catalogue article. The page supplies only the body. */
export function BlogArticleFrame({ id, locale, children }: { id: string; locale: BlogLocale; children: ReactNode }) {
  const post = findPost(id);
  const copy = post[locale];
  return (
    <BlogPostLayout
      title={copy.title}
      description={copy.description}
      slug={copy.slug}
      date={post.date}
      dateLabel={copy.dateLabel}
      tag={copy.tag}
      keywords={copy.keywords}
      locale={locale}
    >
      {children}
    </BlogPostLayout>
  );
}

export default function BlogPostLayout({
  title,
  description,
  slug,
  date,
  dateLabel,
  tag,
  keywords,
  locale: localeProp,
  children,
}: BlogPostLayoutProps) {
  const { t } = useTranslation();
  const fromUrl = useBlogLocale();
  const locale = localeProp ?? fromUrl;
  const copy = UI[locale];
  const post = findPostBySlug(locale, slug);
  const pageUrl = post ? postUrl(post, locale) : `${SITE_URL}${blogIndexPath(locale)}/${slug}`;
  const canonical = post ? postCanonical(post, locale) : pageUrl;
  const syndicated = post ? isSyndicated(post, locale) : false;
  const alternates = post
    ? { cs: postUrl(post, "cs"), en: postUrl(post, "en") }
    : null;
  const indexUrl = `${SITE_URL}${blogIndexPath(locale)}`;
  const lang = locale === "en" ? "en" : "cs";
  const showSupport = !isNativeAppSurface();
  const supportLead = locale === "cs" ? csCopy(t("blogSupport.lead")) : t("blogSupport.lead");
  const supportLink = locale === "cs" ? csCopy(t("blogSupport.link")) : t("blogSupport.link");

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Helmet htmlAttributes={{ lang }}>
        <title>{title} | Tokeny</title>
        <meta name="description" content={description} />
        <meta name="keywords" content={keywords} />
        <link rel="canonical" href={canonical} />
        {alternates && <link rel="alternate" hrefLang="cs" href={alternates.cs} />}
        {alternates && <link rel="alternate" hrefLang="en" href={alternates.en} />}
        {alternates && <link rel="alternate" hrefLang="x-default" href={alternates.cs} />}
        <meta property="og:title" content={title} />
        <meta property="og:description" content={description} />
        <meta property="og:url" content={pageUrl} />
        <meta property="og:type" content="article" />
        <meta property="og:locale" content={locale === "en" ? "en_US" : "cs_CZ"} />
        {alternates && (
          <meta property="og:locale:alternate" content={locale === "en" ? "cs_CZ" : "en_US"} />
        )}
        <meta property="article:published_time" content={date} />
        <meta property="article:author" content="Martin Pohl" />
        <meta name="twitter:card" content="summary_large_image" />
        <script type="application/ld+json">{JSON.stringify({
          "@context": "https://schema.org",
          "@type": "Article",
          headline: title,
          description,
          author: { "@type": "Person", name: "Martin Pohl", url: "https://martinpohl.cz" },
          publisher: {
            "@type": "Organization",
            name: "Tokeny",
            logo: { "@type": "ImageObject", url: "https://tokeny.martinpohl.cz/icon-512.png" },
          },
          datePublished: date,
          dateModified: date,
          inLanguage: locale === "en" ? "en" : "cs-CZ",
          image: "https://tokeny.martinpohl.cz/og-image.png",
          mainEntityOfPage: { "@type": "WebPage", "@id": canonical },
          url: canonical,
          isBasedOn: syndicated ? canonical : undefined,
        })}</script>
        <script type="application/ld+json">{JSON.stringify({
          "@context": "https://schema.org",
          "@type": "BreadcrumbList",
          itemListElement: [
            { "@type": "ListItem", position: 1, name: copy.home, item: `${SITE_URL}/` },
            { "@type": "ListItem", position: 2, name: copy.blog, item: indexUrl },
            { "@type": "ListItem", position: 3, name: title, item: pageUrl },
          ],
        })}</script>
      </Helmet>

      <PublicHeader />

      <article lang={lang} id="main" className="container mx-auto px-4 py-12 max-w-3xl">
        <Link to={blogIndexPath(locale)} className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-6 min-h-11">
          <ArrowLeft className="h-3 w-3" aria-hidden /> {copy.back}
        </Link>
        <div className="flex flex-wrap items-center gap-3 text-xs tabular-nums text-muted-foreground mb-4">
          <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary">{tag}</span>
          <span className="flex items-center gap-1"><Calendar className="h-3 w-3" aria-hidden /> <time dateTime={date}>{dateLabel ?? date}</time></span>
          <span>Martin Pohl</span>
        </div>
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight mb-6">{title}</h1>
        <p className="text-lg text-muted-foreground mb-6">{description}</p>
        {syndicated && (
          <p className="glass rounded-2xl px-4 py-3 mb-6 text-sm text-muted-foreground">
            {copy.origin}{" "}
            <a href={canonical} className="text-primary underline underline-offset-4" rel="noopener noreferrer">
              {copy.originLink}
            </a>
          </p>
        )}
        <div className="mb-10"><ShareButtons url={pageUrl} title={title} /></div>

        <div className="prose prose-invert max-w-none
          prose-headings:font-bold prose-headings:tracking-tight
          prose-h2:text-2xl prose-h2:mt-12 prose-h2:mb-4
          prose-h3:text-xl prose-h3:mt-8 prose-h3:mb-3
          prose-p:text-foreground/90 prose-p:leading-relaxed
          prose-a:text-primary prose-a:no-underline hover:prose-a:underline
          prose-strong:text-foreground
          prose-li:text-foreground/90 prose-li:my-1
          prose-code:text-primary prose-code:bg-primary/10 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:before:content-none prose-code:after:content-none">
          {children}
        </div>

        <div className="mt-12">
          <h2 className="text-lg font-bold mb-4">{copy.related}</h2>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <Calculator className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to="/llm-cost-calculator" className="text-sm font-semibold group-hover:text-primary transition-colors block">LLM Cost Calculator</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.calc}</p>
              </CardContent>
            </Card>
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <FileText className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to="/gpt-api-cost" className="text-sm font-semibold group-hover:text-primary transition-colors block">GPT API cost</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.gpt}</p>
              </CardContent>
            </Card>
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <FileText className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to="/claude-api-cost" className="text-sm font-semibold group-hover:text-primary transition-colors block">Claude API cost</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.claude}</p>
              </CardContent>
            </Card>
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <FileText className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to="/how-to-calculate-llm-cost" className="text-sm font-semibold group-hover:text-primary transition-colors block">{copy.howTitle}</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.how}</p>
              </CardContent>
            </Card>
          </div>
          <div className="grid sm:grid-cols-3 gap-3 mt-3">
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <BookOpen className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to={hrefFor("ai-cost-saving", locale)} className="text-sm font-semibold group-hover:text-primary transition-colors block">{copy.save}</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.saveBlurb}</p>
              </CardContent>
            </Card>
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <BookOpen className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to={hrefFor("prompt-optimization", locale)} className="text-sm font-semibold group-hover:text-primary transition-colors block">{copy.prompt}</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.promptBlurb}</p>
              </CardContent>
            </Card>
            <Card className="group hover:border-primary/50 transition-colors">
              <CardContent className="p-4">
                <BookOpen className="h-4 w-4 text-primary mb-2" aria-hidden />
                <Link to={hrefFor("token-window", locale)} className="text-sm font-semibold group-hover:text-primary transition-colors block">{copy.window}</Link>
                <p className="text-xs text-muted-foreground mt-1">{copy.windowBlurb}</p>
              </CardContent>
            </Card>
          </div>
        </div>

        <div className="mt-10 p-6 rounded-xl bg-primary/5 border border-primary/20 text-center">
          <h2 className="text-xl font-bold mb-2">{copy.ctaTitle}</h2>
          <p className="text-sm text-muted-foreground mb-4">{copy.ctaBody}</p>
          <div className="flex flex-wrap justify-center gap-3">
            <Button asChild><Link to="/auth">{copy.ctaPrimary} <ArrowRight className="ml-2 h-4 w-4" aria-hidden /></Link></Button>
            <Button asChild variant="outline"><Link to="/llm-cost-calculator">{copy.ctaSecondary}</Link></Button>
          </div>
        </div>

        <div className="mt-10 pt-6 border-t border-border/40 flex flex-col items-center">
          <ShareButtons url={pageUrl} title={title} />
          {showSupport && (
            <p data-testid="blog-support-line" className="mt-4 text-center text-sm leading-relaxed text-muted-foreground">
              {supportLead}{" "}
              <a
                href={supportHref("blog")}
                target="_blank"
                rel="noopener noreferrer"
                className="text-foreground underline decoration-border underline-offset-4 hover:decoration-foreground"
              >
                {supportLink}
              </a>
            </p>
          )}
        </div>
      </article>

      <footer className="border-t border-border/40 py-8 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} <Link to="/" className="hover:text-foreground">Tokeny</Link>
      </footer>
    </div>
  );
}
