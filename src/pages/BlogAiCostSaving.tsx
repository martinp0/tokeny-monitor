import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        Účet za AI API roste rychleji než revenue? Nejsi sám. Většina týmů, kterým jsme se dívali pod ruku,
        utrácí o <strong>40–70 % víc, než musí</strong>. Tady je 10 taktik, které fungují v produkci.
      </p>

      <h2>1. Routing modelů podle složitosti</h2>
      <p>
        Nepoužívej GPT-5 na všechno. Klasifikace, krátké odpovědi a routing může dělat GPT-4o mini nebo
        Claude Haiku za <strong>10–20× nižší cenu</strong>. Komplexní reasoning nech na flagship modelu.
        Jednoduchý "router" prompt na malém modelu rozhodne, kam dotaz pošle.
      </p>

      <h2>2. Prompt caching</h2>
      <p>
        Anthropic, OpenAI i Gemini podporují cache opakovaných částí promptu (system prompt, RAG kontext,
        few-shot příklady). Cached tokeny stojí <strong>10–25 % normální ceny</strong>. U agentů s velkým
        system promptem to bývá největší jednorázová úspora.
      </p>

      <h2>3. Batch API místo realtime</h2>
      <p>
        Pokud nepotřebuješ odpověď do sekund (klasifikace logů, embedding, hromadné generování),
        použij batch endpoint. <strong>50% sleva</strong> oproti běžnému API u OpenAI i Anthropic.
      </p>

      <h2>4. Zkracuj system prompty</h2>
      <p>
        Každý request platí celý system prompt znovu (pokud necachuješ). 2 000 zbytečných tokenů × 100k requestů =
        200M tokenů měsíčně navíc. Audituj prompty, mažeš mrtvé instrukce.
      </p>

      <h2>5. max_tokens limit</h2>
      <p>
        Model rád generuje delší odpovědi než potřebuješ. Tvrdě limituj <code>max_tokens</code>.
        U JSON response formátu to dramaticky snižuje výstupní tokeny.
      </p>

      <h2>6. Strukturovaný output místo "vysvětli proč"</h2>
      <p>
        Když potřebuješ jen výsledek, nech model vrátit JSON. Free-form "step by step thinking" zní hezky,
        ale platíš za každý token. Pro reasoning modely (o1, GPT-5 thinking) je to často <strong>největší
        položka faktury</strong>.
      </p>

      <h2>7. Streaming a early termination</h2>
      <p>
        Streamuj odpovědi a zastav generování, jakmile máš co potřebuješ (např. první JSON blok). Šetří
        output tokeny v hraničních case-ech.
      </p>

      <h2>8. Cache výsledků (ne jen promptu)</h2>
      <p>
        Identický vstup = identický výstup? Cachuj. Redis nebo i jednoduchá tabulka v Postgresu. U FAQ
        bota nebo klasifikace se cache hit ratio běžně dostane nad <strong>30 %</strong>.
      </p>

      <h2>9. Embeddings + retrieval místo kontextu</h2>
      <p>
        Místo cpaní celé dokumentace do contextu udělej RAG. 5 relevantních chunků (500 tokenů) je
        levnější než 50k token dump a často přesnější.
      </p>

      <h2>10. Měř, nehádej</h2>
      <p>
        Bez monitoringu nezachytíš runaway loop, infinite agenta nebo bug, který strojí $200/den. Connect
        OpenAI/Anthropic přes <Link to="/auth">Tokeny</Link> a sleduj denní spend.
      </p>

      <h2>Kolik to celkově ušetří?</h2>
      <p>
        Realistický mix těchto taktik dává <strong>40–80 % snížení faktury</strong> u většiny use casů.
        Začni routingem a cachem — to jsou typicky největší rychlé výhry.
      </p>

      <p>
        Související: <Link to="/blog/prompt-optimization">Optimalizace promptů</Link> ·{" "}
        <Link to="/blog/token-window">Token window strategie</Link> ·{" "}
        <Link to="/llm-cost-calculator">Spočítej si reálné náklady</Link>
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        Is the AI API bill growing faster than revenue? You are not alone. Most teams we have looked
        at spend <strong>40–70% more than they need to</strong>. Here are 10 tactics that hold up in production.
      </p>

      <h2>1. Route models by difficulty</h2>
      <p>
        Do not send everything to GPT-5. Classification, short answers and routing can go to GPT-4o mini
        or Claude Haiku at a <strong>10–20× lower price</strong>. Leave complex reasoning on the flagship.
        A short “router” prompt on a small model decides where the request goes.
      </p>

      <h2>2. Prompt caching</h2>
      <p>
        Anthropic, OpenAI and Gemini can cache repeated parts of a prompt (the system prompt, RAG context,
        few-shot examples). Cached tokens cost <strong>10–25% of the normal price</strong>. For agents with
        a large system prompt this is often the biggest one-off saving.
      </p>

      <h2>3. Batch API instead of realtime</h2>
      <p>
        If you do not need an answer in seconds (log classification, embeddings, bulk generation), use
        the batch endpoint. That is a <strong>50% discount</strong> against the ordinary API at both OpenAI
        and Anthropic.
      </p>

      <h2>4. Shorten system prompts</h2>
      <p>
        Every request pays for the whole system prompt again (unless you cache it). 2,000 wasted tokens ×
        100k requests = 200M extra tokens a month. Audit the prompts and delete dead instructions.
      </p>

      <h2>5. A max_tokens limit</h2>
      <p>
        The model likes to write a longer answer than you need. Cap <code>max_tokens</code> hard. With a
        JSON response format that cuts output tokens sharply.
      </p>

      <h2>6. Structured output instead of “explain why”</h2>
      <p>
        When you only need the result, have the model return JSON. Free-form “step by step thinking”
        sounds nice, and you pay for every token. On reasoning models (o1, GPT-5 thinking) it is often
        the <strong>largest line on the invoice</strong>.
      </p>

      <h2>7. Streaming and early termination</h2>
      <p>
        Stream the answer and stop generation once you have what you need (for example the first JSON
        block). That saves output tokens in the edge cases.
      </p>

      <h2>8. Cache results, not only the prompt</h2>
      <p>
        Identical input, identical output? Cache it. Redis, or even a simple Postgres table. On an FAQ
        bot or a classifier the cache hit ratio commonly gets above <strong>30%</strong>.
      </p>

      <h2>9. Embeddings and retrieval instead of stuffing the context</h2>
      <p>
        Do not paste the whole docs into the context. Use RAG. Five relevant chunks (500 tokens) are
        cheaper than a 50k-token dump, and often more accurate.
      </p>

      <h2>10. Measure, do not guess</h2>
      <p>
        Without monitoring you will miss a runaway loop, an infinite agent or a bug that burns $200 a day.
        Connect OpenAI or Anthropic through <Link to="/auth">Tokeny</Link> and watch daily spend.
      </p>

      <h2>How much does it save in total?</h2>
      <p>
        A realistic mix of these tactics gives a <strong>40–80% lower invoice</strong> on most use cases.
        Start with routing and caching. Those are usually the fastest wins.
      </p>

      <p>
        Related: <Link to={hrefFor("prompt-optimization", "en")}>Prompt optimization</Link> ·{" "}
        <Link to={hrefFor("token-window", "en")}>Token window strategy</Link> ·{" "}
        <Link to="/llm-cost-calculator">Estimate the real cost</Link>
      </p>
    </>
  );
}

export default function BlogAiCostSaving({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="ai-cost-saving" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
