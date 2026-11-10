import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import type { BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        Většina týmů dnes nepoužívá jen jednoho AI providera. Klasický setup:
        <strong> GPT-5 na produkční chat</strong>, <strong>Claude Sonnet na code review</strong>,
        <strong> Gemini Flash na masivní extraction</strong> a <strong>Groq nebo Mistral
        na cheap fallback</strong>. Každý provider má vlastní dashboard, vlastní
        ceník, vlastní formát exportu — a finance má z toho hlavu jako pivní bečku.
      </p>

      <p>
        Proto Tokeny spojí do jednoho přehledu <strong>OpenRouter, Anthropic
        a OpenAI</strong>. Modely od Googlu, Mistralu, Groqu nebo xAI uvidíš
        také — pokud je voláš přes OpenRouter.
      </p>

      <h2>Proč multi-provider strategie dává smysl</h2>
      <ul>
        <li><strong>Cena se liší 10–100×.</strong> Groq llama-3.3-70b je o řád
          levnější než GPT-5 a pro 80 % úloh stačí.</li>
        <li><strong>Latence.</strong> Groq zvládá 500+ tok/s, Gemini Flash má
          stabilní p99 pod sekundu. GPT-5 na thinking módu klidně 30 s.</li>
        <li><strong>Resilience.</strong> Když jeden provider spadne (a stane se
          to), routovat na záložního trvá vteřiny — pokud máš klíče připravené.</li>
        <li><strong>Vendor lock-in risk.</strong> Closed beta, EOL modelu,
          pricing change — diverzifikace chrání rozpočet.</li>
      </ul>

      <h2>Co která integrace umí</h2>

      <h3>Plnohodnotný sync (per-request data)</h3>
      <ul>
        <li><strong>OpenRouter</strong> — per-generation rows přes <code>/activity</code>
          endpoint. Vidíš každý request, model, latency, finish reason.</li>
        <li><strong>Anthropic</strong> — Admin API (<code>/v1/organizations/usage_report/messages</code>),
          time-bucketed aggregáty po dnech/hodinách. Vyžaduje admin key.</li>
        <li><strong>OpenAI</strong> — Usage API stejným způsobem, admin key
          z Organization settings.</li>
      </ul>

      <h3>Ostatní provideři přes OpenRouter</h3>
      <p>
        Google Gemini, Mistral, Groq ani xAI zatím nenabízejí veřejné usage API
        po jednotlivých klíčích, takže přímé napojení nemáme. Když je ale voláš
        přes OpenRouter, jejich náklady se v Tokenech objeví stejně jako ostatní
        modely — z CSV exportu nebo ze synchronizace OpenRouteru.
      </p>

      <h2>Jak to vypadá v dashboardu</h2>
      <p>
        Všechny providery se sčítají do jedněch KPI (<em>total spend, tokens,
        requests</em>), zároveň je můžeš filtrovat per provider. Cost chart
        ukazuje stack po providerech, model comparison drží spread napříč
        vendory. Costs jsou vždy v USD, převod do CZK počítá denní ČNB kurz.
      </p>

      <h2>Bezpečnost klíčů</h2>
      <p>
        API klíče se na serveru ukládají zašifrované (AES-256-GCM) — v tabulce
        zůstane jen šifrovaný text a náhled posledních 4 znaků. Browser
        klíč <strong>nikdy</strong> nedostane zpět ven; dešifruje ho jen server
        ve chvíli syncu. Pokud klíč smažeš, smaže se okamžitě a sync se zastaví.
      </p>

      <h2>Jak začít</h2>
      <ol>
        <li>Otevři <Link to="/dashboard">Dashboard</Link> a klikni na
          <em> API integrace → Přidat klíč</em>.</li>
        <li>Vyber providera, vlož klíč (u Anthropic/OpenAI <strong>admin key</strong>,
          ne běžný API key).</li>
        <li>Klikni <em>Sync</em>. U OpenRouter/Anthropic/OpenAI naběhnou data
          okamžitě, u OpenRouteru můžeš alternativně nahrát CSV export.</li>
        <li>Nastav <Link to="/settings">budget alert</Link>, ať tě každý měsíc
          neminul nečekaný billing shock.</li>
      </ol>

      <h2>Praktický playbook: routing podle ceny</h2>
      <p>
        Když máš všechny providery na jednom dashboardu, najednou je vidět,
        kde se reálně točí peníze. Nejčastější optimalizace, co u zákazníků
        vidíme:
      </p>
      <ul>
        <li><strong>Classifikace a routing → Groq llama-3.3-70b.</strong>
          0,59 $/1M output, latence pod 300 ms. Šetří 90 % nákladů oproti GPT-5.</li>
        <li><strong>Bulk extraction → Gemini 2.5 Flash.</strong> 1M context,
          extrémně levné, multimodální.</li>
        <li><strong>Production chat → Claude Sonnet 4.6 nebo GPT-5.</strong>
          Tam, kde kvalita opravdu rozhoduje.</li>
        <li><strong>Coding agents → Claude Sonnet + Anthropic prompt caching.</strong>
          Cache hit ratio 70%+ srazí cenu na desetinu.</li>
        <li><strong>Mistral / Grok jako fallback</strong> při výpadku primárního.</li>
      </ul>

      <p>
        Bez monitoringu jsou tyhle úspory jen teorie. <Link to="/llm-cost-calculator">
        Spočítej si potenciál</Link> nebo si rovnou <Link to="/auth">založ účet</Link>
        a začni sledovat realitu.
      </p>

      <h2>Co dál</h2>
      <p>
        Na řadě je: Together AI, Perplexity API, DeepSeek a OpenRouter
        BYOK detail tracking. Pokud používáš providera, který ti tu chybí,
        napiš — přidáváme rychle.
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        Most teams no longer use a single AI provider. A typical setup is{" "}
        <strong>GPT-5 for production chat</strong>, <strong>Claude Sonnet for code review</strong>,{" "}
        <strong>Gemini Flash for bulk extraction</strong> and <strong>Groq or Mistral as a cheap
        fallback</strong>. Each provider has its own dashboard, its own price list and its own export
        format, and whoever pays the bill ends up with a headache.
      </p>

      <p>
        Tokeny puts <strong>OpenRouter, Anthropic and OpenAI</strong> in one view. You also see models
        from Google, Mistral, Groq or xAI when you call them through OpenRouter.
      </p>

      <h2>Why a multi-provider setup helps</h2>
      <ul>
        <li><strong>Price differs by 10–100×.</strong> Groq llama-3.3-70b is an order of magnitude
          cheaper than GPT-5 and is enough for 80% of tasks.</li>
        <li><strong>Latency.</strong> Groq does 500+ tokens/s. Gemini Flash keeps a stable p99 under a
          second. GPT-5 in thinking mode can take 30 seconds.</li>
        <li><strong>Resilience.</strong> When one provider goes down (and it happens), routing to a
          backup takes seconds, if the keys are already there.</li>
        <li><strong>Vendor lock-in.</strong> A closed beta, a model EOL, a price change. Spreading the
          work protects the budget.</li>
      </ul>

      <h2>What each integration can do</h2>

      <h3>Full sync (per-request data)</h3>
      <ul>
        <li><strong>OpenRouter</strong> — per-generation rows through the <code>/activity</code> endpoint.
          You see each request, the model, latency and the finish reason.</li>
        <li><strong>Anthropic</strong> — the Admin API (<code>/v1/organizations/usage_report/messages</code>),
          time-bucketed aggregates by day or hour. It needs an admin key.</li>
        <li><strong>OpenAI</strong> — the Usage API the same way, with an admin key from Organization settings.</li>
      </ul>

      <h3>Other providers through OpenRouter</h3>
      <p>
        Google Gemini, Mistral, Groq and xAI do not yet offer a public per-key usage API, so there is no
        direct connection. When you call them through OpenRouter, their cost shows up in Tokeny like any
        other model, from a CSV export or from an OpenRouter sync.
      </p>

      <h2>What the dashboard shows</h2>
      <p>
        Every provider rolls into the same KPIs (<em>total spend, tokens, requests</em>), and you can
        filter by provider. The cost chart stacks providers. Model comparison keeps the spread across
        vendors. Costs are always stored in USD. The conversion to CZK uses the daily Czech National Bank rate.
      </p>

      <h2>Key security</h2>
      <p>
        API keys are stored encrypted on the server (AES-256-GCM). The table keeps only the ciphertext
        and a preview of the last 4 characters. The browser <strong>never</strong> receives the key back.
        Only the server decrypts it, at sync time. Delete the key and it is gone immediately, and sync stops.
      </p>

      <h2>How to start</h2>
      <ol>
        <li>Open the <Link to="/dashboard">dashboard</Link> and choose <em>API integrations → Add a key</em>.</li>
        <li>Pick the provider and paste the key. For Anthropic and OpenAI that is an <strong>admin key</strong>,
          not an ordinary API key.</li>
        <li>Click <em>Sync</em>. OpenRouter, Anthropic and OpenAI data shows up immediately. For OpenRouter
          you can upload a CSV export instead.</li>
        <li>Set a <Link to="/settings">budget alert</Link> so a surprise bill does not wait until the end of the month.</li>
      </ol>

      <h2>A practical playbook: route by price</h2>
      <p>
        Once every provider is on one dashboard, you can see where the money actually moves. The
        optimizations we see most often:
      </p>
      <ul>
        <li><strong>Classification and routing → Groq llama-3.3-70b.</strong> $0.59 per 1M output tokens,
          latency under 300 ms. It saves 90% of the cost against GPT-5.</li>
        <li><strong>Bulk extraction → Gemini 2.5 Flash.</strong> A 1M context, very cheap, multimodal.</li>
        <li><strong>Production chat → Claude Sonnet 4.6 or GPT-5.</strong> Where quality actually decides.</li>
        <li><strong>Coding agents → Claude Sonnet plus Anthropic prompt caching.</strong> A cache hit ratio
          of 70%+ cuts the price to a tenth.</li>
        <li><strong>Mistral or Grok as a fallback</strong> when the primary provider is down.</li>
      </ul>

      <p>
        Without monitoring those savings stay theoretical.{" "}
        <Link to="/llm-cost-calculator">Estimate the potential</Link> or{" "}
        <Link to="/auth">create an account</Link> and start watching the real numbers.
      </p>

      <h2>What is next</h2>
      <p>
        Next up: Together AI, the Perplexity API, DeepSeek and more detailed OpenRouter BYOK tracking.
        If you use a provider that is missing here, write. We add them quickly.
      </p>
    </>
  );
}

export default function BlogMultiProvider({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="multi-provider" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
