import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { Link } from "react-router-dom";
import { GrokPricingTable } from "@/components/GrokPricingTable";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

function Czech() {
  return (
    <>
      <p>
        Grok od xAI je oblíbený pro chatboty i agenty, ale účet za tokeny dokáže
        rychle narůst. Dobrá zpráva: většinu nákladů řídí pár páček, které máš
        pod kontrolou. Tady je 7 nejúčinnějších.
      </p>

      <h2>1. Hlídej výstup – je nejdražší</h2>
      <p>
        Výstupní tokeny jsou u Grok modelů dražší než vstupní. Nastav
        <code> max_tokens</code>, žádej stručný formát (odrážky, JSON) a zakaž
        modelu opakovat zadání před odpovědí.
      </p>

      <h2>2. Nepřeposílej celou historii chatu</h2>
      <p>
        Každá další zpráva posílá celou dosavadní konverzaci znovu jako vstup.
        U padesáti tahů tak první zprávy platíš padesátkrát. Řešení: posílej jen
        posledních N zpráv a starší část průběžně shrnuj do krátkého souhrnu.
      </p>

      <h2>3. Využij prompt caching</h2>
      <p>
        Stejný systémový prompt nebo velký dokument posílaný opakovaně se vyplatí
        cachovat – čtení z cache je výrazně levnější. Statický obsah dej na
        začátek a drž ho bajt po bajtu stejný; i změna mezery cache rozbije.
        Cache je krátkodobá, takže u dlouhých pauz mezi requesty se úspora ztrácí.
      </p>

      <h2>4. Ořež RAG kontext</h2>
      <p>
        Dvacet vložených úryvků místo pěti násobí cenu vstupu, ale kvalitu
        odpovědi obvykle nezlepší. Výsledky seřaď podle relevance a pošli jen to,
        co prokazatelně pomáhá.
      </p>

      <h2>5. Vyber model podle úlohy</h2>
      <p>
        Reasoning modely účtují i své „přemýšlení“ jako výstupní tokeny, i když
        uživatel vidí dvě věty. Pro jednoduché úlohy (klasifikace, extrakce,
        krátké odpovědi) použij rychlejší a levnější variantu Groku a silný model
        nech na složité dotazy.
      </p>

      <h2>6. Měř skutečnou spotřebu</h2>
      <p>
        Odhad podle počtu slov je nepřesný. Čti pole <code>usage</code> z každé
        odpovědi (prompt, completion, total tokens) a ukládej ho spolu s modelem
        a funkcí aplikace – jen tak zjistíš, co tě reálně stojí peníze.
      </p>

      <h2>7. Počítej s limity podle tokenů</h2>
      <p>
        Rate limity xAI se řídí hlavně počtem tokenů za minutu, ne počtem
        requestů. Pár dlouhých dotazů tak může skončit chybou 429. Při nastavení
        limitů výdajů počítej s tím, že je API odmítne – aplikace by na to měla
        reagovat slušně, ne spadnout.
      </p>

      <h2>Aktuální ceník Grok API</h2>
      <p>
        Cached input je u Groku 4–7× levnější než běžný vstup, proto se prompt
        caching vyplatí hned. Pozor na hranici 200k tokenů: nad ní se celý
        request účtuje dvojnásobnou sazbou.
      </p>
      <GrokPricingTable locale="cs" />
      <p>
        Pro srovnání s OpenAI viz{" "}
        <Link to="/gpt-api-cost">ceník GPT API</Link>.
      </p>

      <h2>Další krok</h2>
      <p>
        Spočítej si, kolik by tě stál tvůj provoz, v{" "}
        <Link to="/llm-cost-calculator">LLM kalkulačce nákladů</Link>, projdi si{" "}
        <Link to="/blog/prompt-optimization">optimalizaci promptů</Link> a{" "}
        <Link to="/blog/token-window">práci s token window</Link>. Pokud
        kombinuješ Grok s dalšími providery, sleduj vše na jednom místě – viz{" "}
        <Link to="/blog/multi-provider-monitoring">multi-provider monitoring</Link>.
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        xAI’s Grok is popular for chatbots and agents, but the token bill can grow quickly.
        The useful part: most of the cost sits on a few levers you control. Here are the seven
        that matter most.
      </p>

      <h2>1. Watch the output. It is the expensive part</h2>
      <p>
        On Grok models, output tokens cost more than input tokens. Set <code>max_tokens</code>,
        ask for a short format (bullets, JSON) and tell the model not to repeat the task before
        the answer.
      </p>

      <h2>2. Do not resend the whole chat history</h2>
      <p>
        Every new message sends the conversation so far as input again. After fifty turns you
        have paid for the first messages fifty times. Send only the last N messages and fold the
        older part into a short summary as you go.
      </p>

      <h2>3. Use prompt caching</h2>
      <p>
        The same system prompt, or a large document sent over and over, is worth caching. A cache
        read is much cheaper. Put static content at the start and keep it byte-for-byte identical.
        Even a changed space breaks the cache. The cache is short-lived, so a long pause between
        requests loses the saving.
      </p>

      <h2>4. Trim the RAG context</h2>
      <p>
        Twenty pasted snippets instead of five multiplies the input price and usually does not
        improve the answer. Rank the results by relevance and send only what clearly helps.
      </p>

      <h2>5. Pick the model for the job</h2>
      <p>
        Reasoning models bill their “thinking” as output tokens, even when the user sees two
        sentences. For simple jobs (classification, extraction, short answers) use a faster and
        cheaper Grok variant, and keep the strong model for hard questions.
      </p>

      <h2>6. Measure real usage</h2>
      <p>
        A word-count estimate is inaccurate. Read the <code>usage</code> field on every response
        (prompt, completion, total tokens) and store it with the model and the feature. That is
        the only way to see what actually costs money.
      </p>

      <h2>7. Expect limits that count tokens</h2>
      <p>
        xAI rate limits are driven mainly by tokens per minute, not by the number of requests. A
        few long prompts can end in a 429. When you set spend limits, assume the API will refuse
        some calls. The app should handle that cleanly, not crash.
      </p>

      <h2>Current Grok API prices</h2>
      <p>
        Cached input on Grok is 4–7× cheaper than ordinary input, so prompt caching pays off
        immediately. Watch the 200k-token line: above it the whole request is billed at double the rate.
      </p>
      <GrokPricingTable locale="en" />
      <p>
        For a comparison with OpenAI, see the <Link to="/gpt-api-cost">GPT API prices</Link>.
      </p>

      <h2>Next step</h2>
      <p>
        Estimate what your own traffic would cost in the{" "}
        <Link to="/llm-cost-calculator">LLM cost calculator</Link>, then read{" "}
        <Link to={hrefFor("prompt-optimization", "en")}>prompt optimization</Link> and{" "}
        <Link to={hrefFor("token-window", "en")}>working with a token window</Link>. If you combine
        Grok with other providers, watch them in one place:{" "}
        <Link to={hrefFor("multi-provider", "en")}>multi-provider monitoring</Link>.
      </p>
    </>
  );
}

export default function BlogGrokTokens({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="grok-tokens" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
