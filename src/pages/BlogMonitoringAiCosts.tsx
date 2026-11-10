import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        AI náklady umí přes noc utrojit. Bug v agentovi, infinite loop, nový endpoint v produkci,
        marketing kampaň — a najednou faktura $5 000 místo $500. Bez monitoringu to zjistíš až
        z karty.
      </p>

      <h2>5 KPI, které musíš sledovat</h2>

      <h3>1. Daily spend (USD)</h3>
      <p>
        Základ. Sleduj denní útratu napříč providery. Alert pokud denní spend překročí <strong>1.5×
        7-day rolling average</strong> — to zachytí runaway loopy během hodin, ne dní.
      </p>

      <h3>2. Cost per request (avg)</h3>
      <p>
        Roste? Pravděpodobně se ti rozrostl prompt nebo kontext. Klesá? Dobrá zpráva, nebo někdo
        přepnul na levnější model — ověř kvalitu.
      </p>

      <h3>3. Input vs output token ratio</h3>
      <p>
        Output tokeny jsou typicky <strong>4–5× dražší</strong> než input. Vysoký output podíl signalizuje
        nezalimitované <code>max_tokens</code> nebo zbytečné "vysvětli proč" v promptech. Viz{" "}
        <Link to="/blog/prompt-optimization">prompt optimization</Link>.
      </p>

      <h3>4. Model mix</h3>
      <p>
        Kolik % requestů jede přes flagship vs mini? Pokud flagship dělá &gt;30 % a nejde o
        reasoning-heavy workload, máš prostor pro routing. Detail v{" "}
        <Link to="/blog/gpt-vs-claude-vs-gemini">srovnání modelů</Link>.
      </p>

      <h3>5. Latence per model</h3>
      <p>
        Nejen UX metrika — pomalé responses znamenají taky drahé streamy a často indikují problém
        u providera (před fakturací). Sleduj p50 a p95.
      </p>

      <h2>Alerty, které dávají smysl</h2>
      <ul>
        <li><strong>Budget threshold</strong> — 50 %, 80 %, 100 % měsíčního budgetu</li>
        <li><strong>Spike detection</strong> — hourly spend &gt; 3× medián posledních 24h</li>
        <li><strong>New model usage</strong> — někdo nasadil nový model, který v rozpočtu nebyl</li>
        <li><strong>Failed requests &gt; 5 %</strong> — platíš za chyby (často ano u rate limitů)</li>
        <li><strong>Single request &gt; $X</strong> — typicky runaway agent nebo špatný RAG</li>
      </ul>

      <h2>Red flags v dashboardu</h2>
      <ul>
        <li><strong>Plochá křivka, pak skok</strong> — nasazení / bug</li>
        <li><strong>Postupný drift nahoru</strong> — prompty rostou, kontext narůstá</li>
        <li><strong>Sinusoida přes noc</strong> — cron job nebo batch processing běží 24/7</li>
        <li><strong>Náhle nulová útrata</strong> — API key revoked nebo provider outage</li>
      </ul>

      <h2>Setup za 10 minut</h2>
      <p>Postup, který funguje pro malý/střední tým:</p>
      <ol>
        <li>Connect OpenAI/Anthropic/OpenRouter do <Link to="/auth">Tokenech</Link></li>
        <li>Nastav měsíční budget alert (email na 80 %)</li>
        <li>Týdně 5 minut review: cost per request, model mix, top 5 nejdražších requestů</li>
        <li>Spočítej si očekávané náklady na nové featury v <Link to="/llm-cost-calculator">kalkulačce</Link> před nasazením</li>
      </ol>

      <h2>Pokročilé: per-feature attribution</h2>
      <p>
        U větších produktů přidej do každého requestu metadata (<code>user_id</code>, <code>feature</code>,
        <code>endpoint</code>). Pak víš, že 60 % nákladů jde na 5 % uživatelů, nebo že "experimentální"
        endpoint žere víc než hlavní produkt. Bez per-feature tagů je optimalizace hádání.
      </p>

      <h2>Co měřit nemá smysl</h2>
      <ul>
        <li><strong>Token count bez kontextu ceny</strong> — různé modely, různé ceny. Sleduj USD.</li>
        <li><strong>Total requests</strong> — bez cost / latence ti to neřekne nic</li>
        <li><strong>Daily spend bez 7-day average</strong> — víkendové výkyvy = false alerty</li>
      </ul>

      <p>
        Související: <Link to="/blog/ai-cost-saving">10 způsobů, jak ušetřit na AI</Link> ·{" "}
        <Link to="/blog/gpt-vs-claude-vs-gemini">Srovnání modelů 2026</Link> ·{" "}
        <Link to="/blog/token-window">Token window strategie</Link>
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        AI costs can triple overnight. A bug in an agent, an infinite loop, a new endpoint in
        production, a marketing campaign, and suddenly the invoice is $5,000 instead of $500. Without
        monitoring you find out from the card statement.
      </p>

      <h2>5 KPIs you should watch</h2>

      <h3>1. Daily spend (USD)</h3>
      <p>
        The baseline. Watch daily spend across providers. Alert when a day’s spend exceeds{" "}
        <strong>1.5× the 7-day rolling average</strong>. That catches runaway loops in hours, not days.
      </p>

      <h3>2. Cost per request (average)</h3>
      <p>
        Rising? The prompt or the context probably grew. Falling? Good news, or someone switched to a
        cheaper model. Check the quality.
      </p>

      <h3>3. Input vs output token ratio</h3>
      <p>
        Output tokens are typically <strong>4–5× more expensive</strong> than input. A high output share
        points at an uncapped <code>max_tokens</code> or a needless “explain why” in the prompt. See{" "}
        <Link to={hrefFor("prompt-optimization", "en")}>prompt optimization</Link>.
      </p>

      <h3>4. Model mix</h3>
      <p>
        What share of requests goes through a flagship versus a mini? If the flagship does more than 30%
        and the workload is not reasoning-heavy, there is room to route. Detail in the{" "}
        <Link to={hrefFor("model-comparison", "en")}>model comparison</Link>.
      </p>

      <h3>5. Latency per model</h3>
      <p>
        Not only a UX metric. Slow responses also mean expensive streams, and they often signal a problem
        at the provider before it shows up on the invoice. Watch p50 and p95.
      </p>

      <h2>Alerts that mean something</h2>
      <ul>
        <li><strong>Budget threshold</strong> — 50%, 80%, 100% of the monthly budget</li>
        <li><strong>Spike detection</strong> — hourly spend above 3× the median of the last 24 hours</li>
        <li><strong>New model usage</strong> — someone shipped a model that was not in the budget</li>
        <li><strong>Failed requests above 5%</strong> — you pay for errors (often yes, on rate limits)</li>
        <li><strong>A single request above $X</strong> — typically a runaway agent or a bad RAG setup</li>
      </ul>

      <h2>Red flags on the dashboard</h2>
      <ul>
        <li><strong>A flat line, then a jump</strong> — a deploy, or a bug</li>
        <li><strong>A slow drift upward</strong> — prompts are growing, context is accumulating</li>
        <li><strong>A wave through the night</strong> — a cron job or batch processing running 24/7</li>
        <li><strong>Spend suddenly at zero</strong> — the API key was revoked, or the provider is down</li>
      </ul>

      <h2>A 10-minute setup</h2>
      <p>A sequence that works for a small or mid-size team:</p>
      <ol>
        <li>Connect OpenAI, Anthropic or OpenRouter in <Link to="/auth">Tokeny</Link></li>
        <li>Set a monthly budget alert (an email at 80%)</li>
        <li>Five minutes a week: cost per request, model mix, the five most expensive requests</li>
        <li>Estimate a new feature in the <Link to="/llm-cost-calculator">calculator</Link> before you ship it</li>
      </ol>

      <h2>Advanced: per-feature attribution</h2>
      <p>
        On a larger product, add metadata to every request (<code>user_id</code>, <code>feature</code>,{" "}
        <code>endpoint</code>). Then you know that 60% of the cost sits on 5% of users, or that an
        “experimental” endpoint eats more than the main product. Without per-feature tags, optimization
        is guessing.
      </p>

      <h2>What is not worth measuring</h2>
      <ul>
        <li><strong>Token count without the price</strong> — different models, different prices. Watch USD.</li>
        <li><strong>Total requests</strong> — without cost or latency it tells you nothing</li>
        <li><strong>Daily spend without a 7-day average</strong> — weekend swings become false alerts</li>
      </ul>

      <p>
        Related: <Link to={hrefFor("ai-cost-saving", "en")}>10 ways to cut AI costs</Link> ·{" "}
        <Link to={hrefFor("model-comparison", "en")}>2026 model comparison</Link> ·{" "}
        <Link to={hrefFor("token-window", "en")}>Token window strategy</Link>
      </p>
    </>
  );
}

export default function BlogMonitoringAiCosts({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="monitoring" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
