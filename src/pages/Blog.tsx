import { Helmet } from "react-helmet-async";
import { Link } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import { ArrowRight, BookOpen, Calendar } from "lucide-react";
import { PublicHeader } from "@/components/PublicHeader";
import {
  BLOG_POSTS,
  blogIndexPath,
  postPath,
  SITE_URL,
  type BlogLocale,
} from "@/content/blog/catalog";
import { useBlogLocale } from "@/content/blog/locale";

const INDEX = {
  cs: {
    title: "Blog — náklady na AI, prompty a tokeny | Tokeny",
    description: "Praktické články o snižování nákladů na LLM, optimalizaci promptů a práci s token window. Návody, příklady, čísla.",
    eyebrow: "Blog",
    h1Lead: "Náklady na AI",
    h1Rest: "prompty a tokeny",
    standfirst: "Praktické články o tom, jak snížit náklady na LLM API, psát efektivnější prompty a chytře pracovat s token window.",
    articles: "Články",
    read: "Číst článek",
    tools: "Nástroje a ceníky",
    calc: "Odhad nákladů na 11 modelů napříč providery",
    gpt: "Per-token ceník GPT-5, GPT-4o, mini",
    claude: "Haiku, Sonnet, Opus pricing a příklady",
  },
  en: {
    title: "Blog — AI costs, prompts and tokens | Tokeny",
    description: "Practical articles on cutting LLM costs, tightening prompts and working with a token window. Guides, examples, figures.",
    eyebrow: "Blog",
    h1Lead: "AI costs",
    h1Rest: "prompts and tokens",
    standfirst: "Practical articles on cutting LLM API costs, writing tighter prompts and using a token window on purpose.",
    articles: "Articles",
    read: "Read the article",
    tools: "Tools and price pages",
    calc: "Estimate cost across 11 models and providers",
    gpt: "Per-token prices for GPT-5, GPT-4o, mini",
    claude: "Haiku, Sonnet and Opus pricing, with examples",
  },
} as const;

export default function Blog() {
  const locale: BlogLocale = useBlogLocale();
  const copy = INDEX[locale];
  const indexPath = blogIndexPath(locale);
  const indexUrl = `${SITE_URL}${indexPath}`;
  const other = locale === "en" ? "cs" : "en";

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Helmet htmlAttributes={{ lang: locale }}>
        <title>{copy.title}</title>
        <meta name="description" content={copy.description} />
        <link rel="canonical" href={indexUrl} />
        <link rel="alternate" hrefLang="cs" href={`${SITE_URL}/blog`} />
        <link rel="alternate" hrefLang="en" href={`${SITE_URL}/en/blog`} />
        <link rel="alternate" hrefLang="x-default" href={`${SITE_URL}/blog`} />
        <meta property="og:title" content={copy.title} />
        <meta property="og:description" content={copy.description} />
        <meta property="og:url" content={indexUrl} />
        <meta property="og:type" content="website" />
        <meta property="og:locale" content={locale === "en" ? "en_US" : "cs_CZ"} />
        <meta property="og:locale:alternate" content={other === "en" ? "en_US" : "cs_CZ"} />
      </Helmet>

      <PublicHeader />

      <main id="main">
        <section className="container mx-auto px-4 pt-16 pb-10 max-w-4xl">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 text-primary text-xs tabular-nums mb-6">
            <BookOpen className="h-3 w-3" aria-hidden /> {copy.eyebrow}
          </div>
          <h1 className="text-4xl md:text-5xl font-bold tracking-tight mb-4">
            <span className="text-primary">{copy.h1Lead}</span> {copy.h1Rest}
          </h1>
          <p className="text-lg text-muted-foreground max-w-2xl">{copy.standfirst}</p>
        </section>

        <section className="container mx-auto px-4 pb-16 max-w-4xl" aria-label={copy.articles}>
          <div className="grid gap-4">
            {BLOG_POSTS.map((post) => {
              const item = post[locale];
              return (
                <Link to={postPath(post, locale)} key={post.id} className="block group">
                  <Card className="transition-colors hover:border-primary/50">
                    <CardContent className="p-6">
                      <div className="flex items-center gap-3 text-xs tabular-nums text-muted-foreground mb-3">
                        <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary">{item.tag}</span>
                        <span className="flex items-center gap-1"><Calendar className="h-3 w-3" aria-hidden /> <time dateTime={post.date}>{item.dateLabel}</time></span>
                      </div>
                      <h2 className="text-xl md:text-2xl font-bold mb-2 group-hover:text-primary transition-colors">
                        {item.listTitle ?? item.title}
                      </h2>
                      <p className="text-muted-foreground">{item.excerpt}</p>
                      <div className="mt-4 text-sm text-primary flex items-center gap-1">
                        {copy.read} <ArrowRight className="h-3 w-3" aria-hidden />
                      </div>
                    </CardContent>
                  </Card>
                </Link>
              );
            })}
          </div>
        </section>

        <section className="container mx-auto px-4 pb-16 max-w-4xl">
          <h2 className="text-xl font-bold mb-4">{copy.tools}</h2>
          <div className="grid sm:grid-cols-3 gap-4">
            <Link to="/llm-cost-calculator" className="block group">
              <Card className="transition-colors hover:border-primary/50 h-full">
                <CardContent className="p-5">
                  <h3 className="font-semibold group-hover:text-primary transition-colors mb-1">LLM Cost Calculator</h3>
                  <p className="text-sm text-muted-foreground">{copy.calc}</p>
                </CardContent>
              </Card>
            </Link>
            <Link to="/gpt-api-cost" className="block group">
              <Card className="transition-colors hover:border-primary/50 h-full">
                <CardContent className="p-5">
                  <h3 className="font-semibold group-hover:text-primary transition-colors mb-1">GPT API cost</h3>
                  <p className="text-sm text-muted-foreground">{copy.gpt}</p>
                </CardContent>
              </Card>
            </Link>
            <Link to="/claude-api-cost" className="block group">
              <Card className="transition-colors hover:border-primary/50 h-full">
                <CardContent className="p-5">
                  <h3 className="font-semibold group-hover:text-primary transition-colors mb-1">Claude API cost</h3>
                  <p className="text-sm text-muted-foreground">{copy.claude}</p>
                </CardContent>
              </Card>
            </Link>
          </div>
        </section>
      </main>

      <footer className="border-t border-border/40 py-8 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} <Link to="/" className="hover:text-foreground">Tokeny</Link>
      </footer>
    </div>
  );
}
