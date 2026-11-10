import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        Moderní modely nabízejí 200k (Claude), 400k (GPT-5) i 1M (Gemini) token context. Lákavé hodit
        do promptu celý codebase a "ať si poradí". Pak přijde faktura.
      </p>

      <p>
        Velký context window má dvě skryté daně: <strong>cost</strong> (input tokeny se sčítají rychle)
        a <strong>kvalita</strong> (modely zapomínají, co je uprostřed — "lost in the middle" efekt).
      </p>

      <h2>Kdy 1M context dává smysl</h2>
      <ul>
        <li>Jednorázová analýza dokumentu/repa (research, audit)</li>
        <li>Komplexní reasoning, kde potřebuješ vidět všechny souvislosti najednou</li>
        <li>Multimodal úlohy (video + text)</li>
      </ul>

      <h2>Kdy je 1M context drahý overkill</h2>
      <ul>
        <li>Chatbot s history starou týden — kdo si po týdnu pamatuje, co se řešilo?</li>
        <li>RAG nad dokumentací — 5 relevantních chunků překoná full dump v přesnosti i ceně</li>
        <li>Agentní workflow — každý krok znovu odešle 50k tokenů kontextu, který už nepotřebuje</li>
      </ul>

      <h2>4 strategie pro chytré context management</h2>

      <h3>1. Sliding window</h3>
      <p>
        Drž posledních N zpráv (typicky 10–20). Starší zahoď nebo summarizuj. Vhodné pro chat.
      </p>

      <h3>2. Summary chain</h3>
      <p>
        Každých M zpráv nech model udělat krátké shrnutí předchozího kontextu. Místo 50k history pošleš
        500 token summary + posledních 5 zpráv. Drží <strong>80 %+ kontextu</strong> za zlomek ceny.
      </p>

      <h3>3. RAG (Retrieval-Augmented Generation)</h3>
      <p>
        Embedduj dokumenty, retrievuj jen relevantní chunky. Pro většinu Q&A use casů poráží long-context
        v poměru cena/kvalita o řád.
      </p>

      <h3>4. Context pruning</h3>
      <p>
        Před každým requestem prober kontext: drop tool výstupy starší 3 krokůý, smaž duplicitní info,
        zkomprimuj failed attempty. Pro AI agenty kritické — bez pruningu utratíš $50/hod na jedno
        spuštění.
      </p>

      <h2>Konkrétní čísla</h2>
      <p>
        Agent řešící bug, 30 kroků, každý krok přidá tool output (~2k tokenů):
      </p>
      <ul>
        <li><strong>Naivně:</strong> krok 30 platí 60k input tokenů. Cumulative input: ~900k tokenů.</li>
        <li><strong>S pruningem (jen posledních 5 toolů + summary):</strong> ~10k tokenů/krok, cumulative ~300k.</li>
      </ul>
      <p>
        <strong>3× levnější</strong>, a navíc model líp drží pozornost na aktuální problém.
      </p>

      <h2>Long context není zdarma, ani když "jde"</h2>
      <p>
        Gemini 2.5 Pro je za $1.25/1M input. 500k token request = $0.625 jen na input. 1000 takových
        requestů denně = $625/den, $19k/měs. Většina týmů by stejný výsledek dostala za 10× míň přes
        RAG.
      </p>

      <h2>Praxe: měř input tokeny per request</h2>
      <p>
        V <Link to="/auth">Tokenech</Link> sleduj <em>avg input tokens per request</em> v čase.
        Pokud roste, máš v kontextu balast. Spočítej si dopad cenovky v{" "}
        <Link to="/llm-cost-calculator">LLM cost calculator</Link>.
      </p>

      <p>
        Související: <Link to="/blog/ai-cost-saving">10 způsobů, jak ušetřit na AI</Link> ·{" "}
        <Link to="/blog/prompt-optimization">Optimalizace promptů</Link>
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        Current models offer 200k tokens (Claude), 400k (GPT-5) and 1M (Gemini) of context. It is
        tempting to drop a whole codebase into the prompt and “let it figure it out”. Then the invoice arrives.
      </p>

      <p>
        A large context window has two hidden taxes: <strong>cost</strong> (input tokens add up fast)
        and <strong>quality</strong> (models forget what sits in the middle, the “lost in the middle” effect).
      </p>

      <h2>When a 1M context earns its place</h2>
      <ul>
        <li>A one-off analysis of a document or a repo (research, an audit)</li>
        <li>Complex reasoning where you need every connection visible at once</li>
        <li>Multimodal jobs (video plus text)</li>
      </ul>

      <h2>When a 1M context is expensive overkill</h2>
      <ul>
        <li>A chatbot whose history is a week old. Who remembers a week later what was being discussed?</li>
        <li>RAG over documentation. Five relevant chunks beat a full dump on accuracy and on price</li>
        <li>An agent workflow. Every step resends 50k tokens of context it no longer needs</li>
      </ul>

      <h2>4 strategies for context that stays useful</h2>

      <h3>1. Sliding window</h3>
      <p>Keep the last N messages (typically 10–20). Drop or summarize the older ones. A good fit for chat.</p>

      <h3>2. Summary chain</h3>
      <p>
        Every M messages, have the model write a short summary of the context so far. Instead of 50k of
        history you send a 500-token summary plus the last 5 messages. That keeps <strong>80%+ of the
        context</strong> for a fraction of the price.
      </p>

      <h3>3. RAG (retrieval-augmented generation)</h3>
      <p>
        Embed the documents and retrieve only the relevant chunks. For most Q&A use cases this beats
        long context on the price/quality ratio by an order of magnitude.
      </p>

      <h3>4. Context pruning</h3>
      <p>
        Before every request, go through the context: drop tool outputs older than 3 steps, delete
        duplicate info, compress failed attempts. This is critical for AI agents. Without pruning you
        can spend $50 an hour on a single run.
      </p>

      <h2>Concrete figures</h2>
      <p>An agent fixing a bug, 30 steps, each step adding a tool output (~2k tokens):</p>
      <ul>
        <li><strong>Naive:</strong> step 30 pays for 60k input tokens. Cumulative input: ~900k tokens.</li>
        <li><strong>With pruning (only the last 5 tools plus a summary):</strong> ~10k tokens per step, cumulative ~300k.</li>
      </ul>
      <p>
        <strong>3× cheaper</strong>, and the model keeps its attention on the current problem.
      </p>

      <h2>Long context is not free, even when it “works”</h2>
      <p>
        Gemini 2.5 Pro is $1.25 per 1M input tokens. A 500k-token request is $0.625 on input alone.
        1,000 such requests a day is $625 a day, $19k a month. Most teams would get the same result
        for 10× less with RAG.
      </p>

      <h2>In practice: measure input tokens per request</h2>
      <p>
        In <Link to="/auth">Tokeny</Link> watch <em>avg input tokens per request</em> over time.
        If it rises, the context is carrying ballast. Estimate the price impact in the{" "}
        <Link to="/llm-cost-calculator">LLM cost calculator</Link>.
      </p>

      <p>
        Related: <Link to={hrefFor("ai-cost-saving", "en")}>10 ways to cut AI costs</Link> ·{" "}
        <Link to={hrefFor("prompt-optimization", "en")}>Prompt optimization</Link>
      </p>
    </>
  );
}

export default function BlogTokenWindow({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="token-window" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
