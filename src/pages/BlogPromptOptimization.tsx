import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        Dobrý prompt je krátký, jasný a deterministický. Špatný prompt je dlouhý, vágní a drahý.
        Tady je 6 technik, jak prompty zkrátit <strong>o 30–60 %</strong> a často při tom zlepšit i kvalitu.
      </p>

      <h2>1. Instrukce dopředu, kontext potom</h2>
      <p>
        Modely platí pozornost hlavně začátku a konci promptu. Umísti hlavní instrukci na začátek,
        pak data, pak shrnutí úkolu. Lepší follow rate, méně retry, nižší cost.
      </p>

      <h2>2. Few-shot pruning</h2>
      <p>
        Začni s 5 příklady, postupně ubírej a měř kvalitu. Často zjistíš, že <strong>2 příklady stačí</strong>.
        Ušetříš tisíce tokenů per request.
      </p>

      <p><strong>Před:</strong> 5 příkladů × 200 tokenů = 1000 tokenů</p>
      <p><strong>Po:</strong> 2 příklady × 200 tokenů = 400 tokenů → <strong>−60 % input</strong></p>

      <h2>3. Strukturovaný JSON output</h2>
      <p>
        Místo "vysvětli a vrať odpověď" požaduj striktní schema. Použij{" "}
        <code>response_format: json_schema</code>. Méně output tokenů, parsovatelný výsledek,
        deterministický behavior.
      </p>

      <h2>4. Zkratky a symboly</h2>
      <p>
        Modely rozumí "Q:" a "A:", "USR:" a "AST:", "→" místo "results in". V system promptu nebo
        few-shot příkladech to ušetří desítky tokenů.
      </p>

      <h2>5. Prompt compression nástroje</h2>
      <p>
        Knihovny jako <strong>LLMLingua</strong> umí promptu zredukovat na 30–50 % původní délky
        s minimální ztrátou kvality. Pro velké RAG kontexty nezbytné.
      </p>

      <h2>6. Eliminuj "buďte zdvořilí, prosím"</h2>
      <p>
        "You are a helpful assistant. Please carefully consider..." — tohle nic nezlepší a stojí to
        tokeny. Buď přímý: <em>"Classify the text as one of: A, B, C. Output only the letter."</em>
      </p>

      <h2>Měřitelnost: nehádej, testuj</h2>
      <p>
        Každou změnu promptu prožeň testovacím setem (50–200 příkladů) a porovnej:
      </p>
      <ul>
        <li><strong>Accuracy</strong> — drží kvalita?</li>
        <li><strong>Avg tokens in/out</strong> — kolik jsi reálně ušetřil?</li>
        <li><strong>Cost per request</strong> — výsledek obou výše</li>
      </ul>

      <p>
        Bez měření je prompt engineering jen pověra. Skutečné náklady na model napříč experimenty
        sleduj v <Link to="/auth">Tokenech</Link> nebo si je předem spočítej v{" "}
        <Link to="/llm-cost-calculator">kalkulačce</Link>.
      </p>

      <h2>Reálný příklad</h2>
      <p>
        Klasifikace 50k support ticketů měsíčně:
      </p>
      <ul>
        <li>Před optimalizací: GPT-4o, 1200 in / 150 out, $0.18/request → <strong>$9 000/měs</strong></li>
        <li>Po: GPT-4o mini + strukturovaný JSON + 2 few-shot, 400 in / 5 out → <strong>$0.062/měs… per 1000 ticketů</strong> = $3.1/měs</li>
      </ul>
      <p>
        <strong>2900× levnější.</strong> Žádná magie — jen menší model + kratší prompt + striktní output.
      </p>

      <p>
        Související: <Link to="/blog/ai-cost-saving">10 způsobů, jak ušetřit na AI</Link> ·{" "}
        <Link to="/blog/token-window">Token window strategie</Link>
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        A good prompt is short, clear and deterministic. A bad prompt is long, vague and expensive.
        Here are 6 ways to shorten prompts <strong>by 30–60%</strong> and often improve the quality at the same time.
      </p>

      <h2>1. Instructions first, context after</h2>
      <p>
        Models pay attention mostly to the start and the end of a prompt. Put the main instruction first,
        then the data, then a restatement of the task. Better follow rate, fewer retries, lower cost.
      </p>

      <h2>2. Few-shot pruning</h2>
      <p>
        Start with 5 examples, remove them one by one and measure quality. You often find that{" "}
        <strong>2 examples are enough</strong>. That saves thousands of tokens per request.
      </p>

      <p><strong>Before:</strong> 5 examples × 200 tokens = 1000 tokens</p>
      <p><strong>After:</strong> 2 examples × 200 tokens = 400 tokens → <strong>−60% input</strong></p>

      <h2>3. Structured JSON output</h2>
      <p>
        Instead of “explain and return the answer”, require a strict schema. Use{" "}
        <code>response_format: json_schema</code>. Fewer output tokens, a parseable result, deterministic
        behavior.
      </p>

      <h2>4. Abbreviations and symbols</h2>
      <p>
        Models understand "Q:" and "A:", "USR:" and "AST:", "→" instead of "results in". In a system prompt
        or in few-shot examples that saves tens of tokens.
      </p>

      <h2>5. Prompt compression tools</h2>
      <p>
        Libraries such as <strong>LLMLingua</strong> can reduce a prompt to 30–50% of its original length
        with little quality loss. For large RAG contexts they are hard to skip.
      </p>

      <h2>6. Drop “please be polite”</h2>
      <p>
        "You are a helpful assistant. Please carefully consider..." does not improve anything, and it costs
        tokens. Be direct: <em>"Classify the text as one of: A, B, C. Output only the letter."</em>
      </p>

      <h2>Make it measurable: test, do not guess</h2>
      <p>Run every prompt change through a test set (50–200 examples) and compare:</p>
      <ul>
        <li><strong>Accuracy</strong> — does quality hold?</li>
        <li><strong>Avg tokens in/out</strong> — what did you actually save?</li>
        <li><strong>Cost per request</strong> — the product of the two above</li>
      </ul>

      <p>
        Without measurement, prompt engineering is superstition. Watch the real model cost across
        experiments in <Link to="/auth">Tokeny</Link>, or estimate it first in the{" "}
        <Link to="/llm-cost-calculator">calculator</Link>.
      </p>

      <h2>A real example</h2>
      <p>Classifying 50k support tickets a month:</p>
      <ul>
        <li>Before: GPT-4o, 1200 in / 150 out, $0.18/request → <strong>$9,000/month</strong></li>
        <li>After: GPT-4o mini + structured JSON + 2 few-shot, 400 in / 5 out → <strong>$0.062 per 1,000 tickets</strong> = $3.1/month</li>
      </ul>
      <p>
        <strong>2,900× cheaper.</strong> No magic. A smaller model, a shorter prompt and a strict output.
      </p>

      <p>
        Related: <Link to={hrefFor("ai-cost-saving", "en")}>10 ways to cut AI costs</Link> ·{" "}
        <Link to={hrefFor("token-window", "en")}>Token window strategy</Link>
      </p>
    </>
  );
}

export default function BlogPromptOptimization({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="prompt-optimization" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
