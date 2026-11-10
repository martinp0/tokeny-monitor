import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

const SOURCES = {
  cs: [
    { tool: "Cursor", what: "CSV export využití z přehledu účtu (usage)", granularity: "jednotlivá volání, model, tokeny, cena" },
    { tool: "Grok Bot", what: "CSV export využití", granularity: "jednotlivá volání, produkt, tokeny, cena" },
    { tool: "OpenRouter", what: "CSV z openrouter.ai/activity nebo API klíč", granularity: "jednotlivá volání, model, aplikace, cena" },
  ],
  en: [
    { tool: "Cursor", what: "Usage CSV from the account usage view", granularity: "individual calls, model, tokens, price" },
    { tool: "Grok Bot", what: "Usage CSV export", granularity: "individual calls, product, tokens, price" },
    { tool: "OpenRouter", what: "CSV from openrouter.ai/activity, or an API key", granularity: "individual calls, model, app, price" },
  ],
};

function Czech() {
  return (
    <>
      <p>
        Cursor, Grok Bot i OpenRouter mají jedno společné: platíte paušál nebo kredit, a když agenti
        pracují naplno, přijde k tomu útrata za využití. Faktura vám ale řekne jen součet za měsíc.
        Kdy peníze odtekly, za který model a jestli to byla práce, která za to stála, z ní nepoznáte.
        Tady je postup, který používám sám.
      </p>

      <h2>1. Rozlišujte tarif a útratu nad jeho rámec</h2>
      <p>
        U nástrojů s předplatným (Cursor, Grok Bot) je potřeba oddělit dvě věci: využití, které pokryje
        tarif, a využití účtované navíc (on-demand). Dokud jste v tarifu, další volání vás nic nestojí.
        Rozhoduje tedy hlavně to, <strong>kdy</strong> tarif vyčerpáte a jak rychle pak útrata roste. U
        OpenRouteru je to jednodušší: každé volání se odečte z kreditu, takže sledujete přímo cenu volání.
      </p>

      <h2>2. Kde vzít data</h2>
      <p>
        Nejpřesnější zdroj je export využití po jednotlivých voláních, ne souhrn na faktuře. Přesné umístění
        tlačítka se v aplikacích občas mění, hledejte v přehledu využití (usage) nebo fakturace.
      </p>
      <SourceTable locale="cs" />

      <h2>3. Čtyři čísla, která stojí za sledování</h2>
      <ul>
        <li>
          <strong>Denní útrata.</strong> Agenti neutrácejí rovnoměrně. V mém říjnovém exportu stál
          nejdražší den 258 USD, zatímco první tři týdny pokryl tarif celé. Měsíční součet takovou špičku
          schová.
        </li>
        <li>
          <strong>Podíl tokenů z mezipaměti.</strong> Agent posílá při každém kroku znovu celý kontext.
          Když se čte z mezipaměti (prompt caching), je to výrazně levnější než nový vstup. U mě to bylo 95 %
          všech tokenů. Když podíl náhle klesne, platíte víc za stejnou práci.
        </li>
        <li>
          <strong>Útrata podle modelu.</strong> Dražší model na rutinní úkol je nejčastější zbytečný výdaj.
          Rozpad podle modelu ukáže, kde přepnout na levnější.
        </li>
        <li>
          <strong>Útrata v korunách.</strong> Účtuje se v dolarech, ale rozpočet máte nejspíš v korunách.
          Přepočet kurzem ČNB dá reálné číslo, se kterým se dá plánovat.
        </li>
      </ul>

      <h2>4. Nastavte si kontrolu dřív, než přijde faktura</h2>
      <ul>
        <li>
          <strong>Limit útraty v samotném nástroji.</strong> Cursor i OpenRouter umožňují omezit útratu
          nebo kredit. Je to nejtvrdší pojistka, i když ji nastavíte velkoryse.
        </li>
        <li>
          <strong>Týdenní kontrola exportu.</strong> Pět minut týdně stačí na to, abyste špičku viděli,
          dokud se dá něco změnit, ne až na konci měsíce.
        </li>
        <li>
          <strong>Stabilní začátek promptu.</strong> Instrukce a kontext, které se nemění, dávejte na začátek.
          Tak se nejvíc tokenů čte z mezipaměti. Víc tipů je v článku{" "}
          <Link to="/blog/grok-token-optimization">jak optimalizovat tokeny u Groku</Link>.
        </li>
        <li>
          <strong>Ptejte se, co za ty peníze vzniklo.</strong> Drahý den není problém, pokud agent udělal
          práci za týden. Problém je drahý den, kdy se agent točil v kruhu.
        </li>
      </ul>

      <h2>Reálný příklad</h2>
      <p>
        Jak to vypadá na skutečných číslech, jsem rozebral v článku{" "}
        <Link to="/blog/kolik-stoji-ai-agenti">Kolik doopravdy stojí AI agenti</Link>: měsíc dat z Grok Bota
        a Cursoru, 85 179 volání, přes 7,3 miliardy tokenů a 859 USD nad rámec tarifu.
      </p>

      <h2>Všechno v jednom přehledu: Tokeny</h2>
      <p>
        Ruční procházení tří různých exportů v tabulce rychle omrzí. Proto jsem udělal{" "}
        <Link to="/">Tokeny</Link>: na <Link to="/dashboard">dashboardu</Link> nahrajete CSV export
        z Cursoru, Grok Bota nebo OpenRouteru a uvidíte denní útratu a rozpad podle modelu, v dolarech
        i v korunách. U exportu z Cursoru a Grok Bota navíc tokeny z mezipaměti oproti novým a útratu
        v tarifu oproti té nad ním. Opakované nahrání stejného exportu nic nezdvojí. Export z Cursoru
        a Grok Bota se zpracuje v prohlížeči a e-maily ani ID uživatelů z něj se neukládají.
      </p>
      <p>
        <Link to="/auth">Vyzkoušej Tokeny zdarma</Link>, nebo si nejdřív udělej odhad
        v <Link to="/llm-cost-calculator">kalkulačce nákladů na LLM</Link>.
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        Cursor, Grok Bot and OpenRouter have one thing in common: you pay a plan or a credit balance,
        and when agents work flat out there is usage spend on top. The invoice only tells you the month’s
        total. It does not tell you when the money left, which model it paid for, or whether the work was
        worth it. This is the routine I use.
      </p>

      <h2>1. Separate the plan from spend above it</h2>
      <p>
        For tools with a subscription (Cursor, Grok Bot) split two things: usage the plan covers, and
        usage billed extra (on-demand). While you are inside the plan, further calls cost nothing. What
        matters is <strong>when</strong> you exhaust the plan and how fast spend grows after that. OpenRouter
        is simpler: every call comes off the credit, so you watch the price of the call itself.
      </p>

      <h2>2. Where the data comes from</h2>
      <p>
        The precise source is a per-call usage export, not the summary on the invoice. The button moves
        from time to time. Look in the usage view or in billing.
      </p>
      <SourceTable locale="en" />

      <h2>3. Four numbers worth watching</h2>
      <ul>
        <li>
          <strong>Daily spend.</strong> Agents do not spend evenly. In my October export the most expensive
          day was $258, while the plan covered the first three weeks. A monthly total hides that peak.
        </li>
        <li>
          <strong>Share of tokens from cache.</strong> At every step the agent sends the whole context
          again. A cache read (prompt caching) is much cheaper than fresh input. For me that was 95% of
          all tokens. When the share suddenly drops, you pay more for the same work.
        </li>
        <li>
          <strong>Spend by model.</strong> A more expensive model on a routine task is the most common
          wasted spend. A breakdown by model shows where to switch to a cheaper one.
        </li>
        <li>
          <strong>Spend in crowns.</strong> The bill is in dollars, but the budget is probably in Czech
          crowns. Converting at the Czech National Bank rate gives a number you can plan with.
        </li>
      </ul>

      <h2>4. Set a check before the invoice arrives</h2>
      <ul>
        <li>
          <strong>A spend cap in the tool itself.</strong> Cursor and OpenRouter both let you limit spend
          or credit. It is the hardest stop, even if you set it generously.
        </li>
        <li>
          <strong>A weekly look at the export.</strong> Five minutes a week is enough to see a peak while
          you can still change something, not at the end of the month.
        </li>
        <li>
          <strong>A stable start to the prompt.</strong> Put instructions and context that do not change
          at the beginning. That is how the most tokens get read from cache. More tips are in{" "}
          <Link to={hrefFor("grok-tokens", "en")}>how to optimize tokens on Grok</Link>.
        </li>
        <li>
          <strong>Ask what the money produced.</strong> An expensive day is not a problem if the agent did
          a week’s work. An expensive day is a problem when the agent went in circles.
        </li>
      </ul>

      <h2>A real example</h2>
      <p>
        I went through the actual figures in{" "}
        <Link to={hrefFor("ai-agents", "en")}>What AI agents actually cost</Link>: a month of data from
        Grok Bot and Cursor, 85,179 calls, over 7.3 billion tokens and $859 above the plan.
      </p>

      <h2>One overview: Tokeny</h2>
      <p>
        Walking three different exports in a spreadsheet gets old. That is why I built{" "}
        <Link to="/">Tokeny</Link>: on the <Link to="/dashboard">dashboard</Link> you upload a CSV from
        Cursor, Grok Bot or OpenRouter and see daily spend and a breakdown by model, in dollars and in
        crowns. A Cursor or Grok Bot export also separates cache tokens from fresh ones, and spend inside
        the plan from spend above it. Uploading the same export again does not double anything. A Cursor
        or Grok Bot export is processed in the browser, and the emails and user ids in it are not stored.
      </p>
      <p>
        <Link to="/auth">Try Tokeny for free</Link>, or estimate first in the{" "}
        <Link to="/llm-cost-calculator">LLM cost calculator</Link>.
      </p>
    </>
  );
}

function SourceTable({ locale }: { locale: BlogLocale }) {
  const head = locale === "en" ? ["Tool", "Source", "What is in it"] : ["Nástroj", "Zdroj dat", "Co v nich je"];
  return (
    <div className="not-prose glass rounded-2xl overflow-x-auto my-6">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-muted-foreground border-b border-border/50">
            <th scope="col" className="px-4 py-3 font-medium">{head[0]}</th>
            <th scope="col" className="px-4 py-3 font-medium">{head[1]}</th>
            <th scope="col" className="px-4 py-3 font-medium">{head[2]}</th>
          </tr>
        </thead>
        <tbody>
          {SOURCES[locale].map((row) => (
            <tr key={row.tool} className="border-b border-border/30 last:border-0">
              <td className="px-4 py-3 font-medium">{row.tool}</td>
              <td className="px-4 py-3">{row.what}</td>
              <td className="px-4 py-3">{row.granularity}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function BlogTrackCursorGrokCosts({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="track-cursor" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
