import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        OpenAI, Anthropic a Google v roce 2026 nabízejí tři velmi odlišné flagship modely.
        Cena, rychlost i silné stránky se liší o řády — a volba špatného modelu může utrojit
        fakturu. Tady je přímé srovnání.
      </p>

      <h2>Ceník flagship modelů (USD / 1M tokenů)</h2>
      <ul>
        <li><strong>GPT-5</strong> — input <code>$1.25</code> / output <code>$10.00</code></li>
        <li><strong>Claude Sonnet 4.5</strong> — input <code>$3.00</code> / output <code>$15.00</code></li>
        <li><strong>Claude Opus 4</strong> — input <code>$15.00</code> / output <code>$75.00</code></li>
        <li><strong>Gemini 2.5 Pro</strong> — input <code>$1.25</code> / output <code>$10.00</code></li>
      </ul>
      <p>
        Spočítej si konkrétní use case v <Link to="/llm-cost-calculator">LLM cost calculator</Link>{" "}
        nebo se podívej na <Link to="/gpt-api-cost">detailní GPT ceník</Link> a{" "}
        <Link to="/claude-api-cost">Claude ceník</Link>.
      </p>

      <h2>Context window</h2>
      <ul>
        <li><strong>GPT-5</strong> — 400k tokenů</li>
        <li><strong>Claude Sonnet 4.5</strong> — 200k tokenů (1M v beta)</li>
        <li><strong>Gemini 2.5 Pro</strong> — 1M tokenů, plánováno 2M</li>
      </ul>
      <p>
        Velký context není zdarma — viz <Link to="/blog/token-window">token window strategie</Link>.
      </p>

      <h2>Silné stránky</h2>

      <h3>GPT-5</h3>
      <p>
        Nejvyrovnanější. Skvělý reasoning, dobré coding, solidní multimodalita. Thinking mode
        (extended reasoning) zvládá komplexní úlohy, ale platíš za thinking tokeny — pozor na cenu.
        Nejlepší volba, když nevíš co zvolit.
      </p>

      <h3>Claude Sonnet 4.5 / Opus 4</h3>
      <p>
        Krátí coding a agentní workflow. Vynikající instruction following, nejlepší tone of voice
        pro psaný obsah. Sonnet je sweet spot cena/výkon, Opus jen pro nejtěžší úlohy (a hluboké
        kapsy).
      </p>

      <h3>Gemini 2.5 Pro</h3>
      <p>
        Nejlepší multimodalita (video, audio, image), 1M context bez kompromisů v ceně inputu.
        Skvělý na analýzu velkých dokumentů a multimedia. Reasoning někdy zaostává za GPT-5.
      </p>

      <h2>Kdy který zvolit</h2>
      <ul>
        <li><strong>Chatbot / FAQ</strong> — GPT-5 mini nebo Claude Haiku. Žádný flagship.</li>
        <li><strong>Coding agent</strong> — Claude Sonnet 4.5. Nejvyšší tool-use accuracy.</li>
        <li><strong>Analýza velkých PDF / video</strong> — Gemini 2.5 Pro. Žádná konkurence.</li>
        <li><strong>Komplexní reasoning</strong> — GPT-5 thinking nebo Claude Opus.</li>
        <li><strong>Generování textu pro lidi</strong> — Claude Sonnet. Nejpřirozenější výstup.</li>
        <li><strong>High-volume klasifikace</strong> — GPT-5 nano nebo Gemini 2.5 Flash-Lite.</li>
      </ul>

      <h2>Rychlý cost příklad</h2>
      <p>
        10 000 requestů měsíčně, 2 000 in / 500 out:
      </p>
      <ul>
        <li><strong>GPT-5</strong>: $25 + $50 = <strong>$75/měs</strong></li>
        <li><strong>Claude Sonnet 4.5</strong>: $60 + $75 = <strong>$135/měs</strong></li>
        <li><strong>Gemini 2.5 Pro</strong>: $25 + $50 = <strong>$75/měs</strong></li>
        <li><strong>Claude Opus 4</strong>: $300 + $375 = <strong>$675/měs</strong></li>
      </ul>

      <h2>Doporučení</h2>
      <p>
        Nevol jeden model na všechno. Multi-model setup (router + flagship + nano) typicky ušetří
        <strong> 40–70 %</strong> oproti naivnímu "všechno přes GPT-5". Detail v článku{" "}
        <Link to="/blog/ai-cost-saving">10 způsobů, jak ušetřit na AI</Link>.
      </p>

      <p>
        Související: <Link to="/blog/monitoring-ai-costs">Monitoring AI nákladů</Link> ·{" "}
        <Link to="/blog/prompt-optimization">Optimalizace promptů</Link> ·{" "}
        <Link to="/how-to-calculate-llm-cost">Jak spočítat LLM cost</Link>
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        In 2026 OpenAI, Anthropic and Google offer three very different flagship models. Price, speed
        and strengths differ by orders of magnitude, and picking the wrong model can triple the invoice.
        Here is a direct comparison.
      </p>

      <h2>Flagship prices (USD / 1M tokens)</h2>
      <ul>
        <li><strong>GPT-5</strong> — input <code>$1.25</code> / output <code>$10.00</code></li>
        <li><strong>Claude Sonnet 4.5</strong> — input <code>$3.00</code> / output <code>$15.00</code></li>
        <li><strong>Claude Opus 4</strong> — input <code>$15.00</code> / output <code>$75.00</code></li>
        <li><strong>Gemini 2.5 Pro</strong> — input <code>$1.25</code> / output <code>$10.00</code></li>
      </ul>
      <p>
        Run a specific use case through the <Link to="/llm-cost-calculator">LLM cost calculator</Link>,
        or see the detailed <Link to="/gpt-api-cost">GPT price list</Link> and the{" "}
        <Link to="/claude-api-cost">Claude price list</Link>.
      </p>

      <h2>Context window</h2>
      <ul>
        <li><strong>GPT-5</strong> — 400k tokens</li>
        <li><strong>Claude Sonnet 4.5</strong> — 200k tokens (1M in beta)</li>
        <li><strong>Gemini 2.5 Pro</strong> — 1M tokens, with 2M planned</li>
      </ul>
      <p>
        A large context is not free. See <Link to={hrefFor("token-window", "en")}>token window strategy</Link>.
      </p>

      <h2>Strengths</h2>

      <h3>GPT-5</h3>
      <p>
        The most even. Strong reasoning, good coding, solid multimodality. Thinking mode (extended
        reasoning) handles complex tasks, and you pay for the thinking tokens, so watch the price.
        The best choice when you do not yet know what to pick.
      </p>

      <h3>Claude Sonnet 4.5 / Opus 4</h3>
      <p>
        A strong fit for coding and agent workflows. Excellent instruction following, and the best tone of
        voice for writing people will read. Sonnet is the price/performance sweet spot. Opus is for the
        hardest jobs (and deep pockets).
      </p>

      <h3>Gemini 2.5 Pro</h3>
      <p>
        The best multimodality (video, audio, image), and a 1M context without a compromise on the input
        price. Excellent for large documents and media. Reasoning sometimes lags GPT-5.
      </p>

      <h2>When to pick which</h2>
      <ul>
        <li><strong>Chatbot / FAQ</strong> — GPT-5 mini or Claude Haiku. Not a flagship.</li>
        <li><strong>Coding agent</strong> — Claude Sonnet 4.5. The highest tool-use accuracy.</li>
        <li><strong>Large PDF or video analysis</strong> — Gemini 2.5 Pro. Nothing else is close.</li>
        <li><strong>Complex reasoning</strong> — GPT-5 thinking or Claude Opus.</li>
        <li><strong>Prose for people</strong> — Claude Sonnet. The most natural output.</li>
        <li><strong>High-volume classification</strong> — GPT-5 nano or Gemini 2.5 Flash-Lite.</li>
      </ul>

      <h2>A quick cost example</h2>
      <p>10,000 requests a month, 2,000 in / 500 out:</p>
      <ul>
        <li><strong>GPT-5</strong>: $25 + $50 = <strong>$75/month</strong></li>
        <li><strong>Claude Sonnet 4.5</strong>: $60 + $75 = <strong>$135/month</strong></li>
        <li><strong>Gemini 2.5 Pro</strong>: $25 + $50 = <strong>$75/month</strong></li>
        <li><strong>Claude Opus 4</strong>: $300 + $375 = <strong>$675/month</strong></li>
      </ul>

      <h2>Recommendation</h2>
      <p>
        Do not pick one model for everything. A multi-model setup (router + flagship + nano) typically
        saves <strong>40–70%</strong> against a naive “everything through GPT-5”. Detail is in{" "}
        <Link to={hrefFor("ai-cost-saving", "en")}>10 ways to cut AI costs</Link>.
      </p>

      <p>
        Related: <Link to={hrefFor("monitoring", "en")}>Monitoring AI costs</Link> ·{" "}
        <Link to={hrefFor("prompt-optimization", "en")}>Prompt optimization</Link> ·{" "}
        <Link to="/how-to-calculate-llm-cost">How to calculate LLM cost</Link>
      </p>
    </>
  );
}

export default function BlogModelComparison({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="model-comparison" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
