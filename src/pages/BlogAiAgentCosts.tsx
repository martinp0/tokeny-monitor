import { Link } from "react-router-dom";
import { BlogArticleFrame } from "@/components/BlogPostLayout";
import { DailySpendChart } from "@/components/blog/DailySpendChart";
import { hrefFor, type BlogLocale } from "@/content/blog/catalog";

const TOKEN_ROWS = {
  cs: [
    { kind: "Čtení z mezipaměti (cached)", tokens: "6,96 mld.", share: "95 %" },
    { kind: "Zápis do mezipaměti (cache write)", tokens: "219 mil.", share: "3 %" },
    { kind: "Nový vstup (prompt)", tokens: "126 mil.", share: "2 %" },
    { kind: "Výstup (completion)", tokens: "52 mil.", share: "< 1 %" },
  ],
  en: [
    { kind: "Cache read", tokens: "6.96 billion", share: "95%" },
    { kind: "Cache write", tokens: "219 million", share: "3%" },
    { kind: "Fresh input (prompt)", tokens: "126 million", share: "2%" },
    { kind: "Output (completion)", tokens: "52 million", share: "< 1%" },
  ],
};

function Czech() {
  return (
    <>
      <p>
        Každý den pracuju s AI agenty, s Grok Botem a s Cursorem. Oba umí vyexportovat využití do CSV,
        a tak jsem si stáhl export za 1.–30. října 2026 a podíval se, kam tokeny a peníze doopravdy jdou.
        Žádné odhady, jen čísla z exportu.
      </p>

      <h2>Čísla za 1.–30. října</h2>
      <ul>
        <li><strong>85 179</strong> volání modelu (Grok Bot + Cursor).</li>
        <li>
          <strong>859 USD</strong> za využití nad rámec tarifu: Grok Bot <strong>482 USD</strong>, Cursor{" "}
          <strong>377 USD</strong>. Paušál samotného tarifu v tom není, export ukazuje jen využití.
        </li>
        <li>
          Přes <strong>7,3 miliardy tokenů</strong>: 6,96 mld. čtení z mezipaměti, 219 mil. zápisů do
          mezipaměti, 126 mil. nového vstupu a 52 mil. výstupu.
        </li>
      </ul>

      <h2>95 % tokenů jsou tokeny z mezipaměti</h2>
      <p>
        Agent při každém kroku posílá modelu znovu celý kontext: instrukce, nástroje, historii a soubory.
        Díky prompt cachingu se většina z toho nepočítá jako nový vstup, ale jako levné čtení z mezipaměti.
        U mě to bylo 95 % všech tokenů.
      </p>
      <TokenTable locale="cs" />
      <p>
        Bez mezipaměti by stejná práce znamenala platit plnou cenu vstupu za miliardy tokenů. Nový vstup
        a výstup, tedy to, co si člověk pod „tokeny“ obvykle představí, je dohromady jen pár procent.
      </p>

      <h2>Agenti neutrácí rovnoměrně</h2>
      <p>
        Nejdražší den byl <strong>22. 10. (258 USD)</strong>. Další špičky přišly hned 23. 10. (179 USD)
        a pak <strong>28. a 29. 10. (183 a 169 USD)</strong>. Klidné dny stojí centy nebo nic: první tři
        týdny měsíce pokryl tarif celé a nad jeho rámec jsem nezaplatil nic.
      </p>
      <DailySpendChart locale="cs" />
      <p>
        Útrata tedy neroste rovnoměrně s časem, ale ve skocích. Jediný drahý den stál víc, než kolik
        jsem nad rámec tarifu zaplatil za celé první tři týdny dohromady (tedy nula).
      </p>

      <h2>Co si z toho beru</h2>
      <ul>
        <li>
          <strong>Sledovat útratu denně, ne měsíčně.</strong> Měsíční faktura řekne jen součet. Špičku
          22. 10. bych na ní nepoznal, a právě tam se rozhoduje.
        </li>
        <li>
          <strong>Rozlišovat tarif a on-demand.</strong> Dokud vystačí tarif, další volání nic nestojí. Peníze
          navíc začnou téct až po jeho vyčerpání, takže stojí za to vědět, kdy k tomu dojde.
        </li>
        <li>
          <strong>Mezipaměť je nejlevnější optimalizace.</strong> Stabilní instrukce a kontext na začátku
          promptu znamenají, že se většina tokenů čte z cache. Víc v článku o{" "}
          <Link to="/blog/grok-token-optimization">optimalizaci tokenů u Groku</Link>.
        </li>
        <li>
          <strong>Bez dat se návratnost nedá posoudit.</strong> 859 USD za měsíc může být hodně, nebo málo.
          Záleží na tom, co za ně agenti udělali, a to člověk zjistí jen tehdy, když ví, kolik stál který den
          a která práce.
        </li>
      </ul>

      <h2>Proto stavím Tokeny</h2>
      <p>
        Tokeny jsou dashboard, který ukáže denní útratu za AI napříč poskytovateli v USD i v korunách.
        Nově umí nahrát i <strong>CSV export využití z Cursoru a Grok Bota</strong>. Rozliší tokeny
        z mezipaměti od nových a útratu v rámci tarifu od té nad jeho rámec. Soubor se zpracuje přímo
        v prohlížeči a e-maily ani ID uživatelů z exportu se neukládají.
      </p>
      <p>
        <Link to="/auth">Vyzkoušej Tokeny zdarma</Link> a nahraj svůj export. Nebo si nejdřív spočítej
        odhad v <Link to="/llm-cost-calculator">kalkulačce nákladů</Link>. Postup krok za krokem je v návodu{" "}
        <Link to="/blog/jak-sledovat-naklady-cursor-a-grok-bot">jak sledovat náklady na Cursor a Grok Bot</Link>.
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        I work with AI agents every day, with Grok Bot and with Cursor. Both can export usage to CSV,
        so I downloaded the export for 1–30 October 2026 and looked at where the tokens and the money
        actually go. No estimates, just the figures from the export.
      </p>

      <h2>The figures for 1–30 October</h2>
      <ul>
        <li><strong>85,179</strong> model calls (Grok Bot + Cursor).</li>
        <li>
          <strong>$859</strong> for usage above the plan: Grok Bot <strong>$482</strong>, Cursor{" "}
          <strong>$377</strong>. The plan fee itself is not in there. The export only shows usage.
        </li>
        <li>
          Over <strong>7.3 billion tokens</strong>: 6.96 billion cache reads, 219 million cache writes,
          126 million fresh input tokens and 52 million output tokens.
        </li>
      </ul>

      <h2>95% of the tokens are cache tokens</h2>
      <p>
        At every step the agent sends the model the whole context again: instructions, tools, history and
        files. With prompt caching most of that is not billed as fresh input. It is a cheap cache read.
        For me that was 95% of all tokens.
      </p>
      <TokenTable locale="en" />
      <p>
        Without the cache the same work would mean paying the full input price on billions of tokens.
        Fresh input and output, which is what people usually picture when they say “tokens”, are only a
        few percent together.
      </p>

      <h2>Agents do not spend evenly</h2>
      <p>
        The most expensive day was <strong>22 October ($258)</strong>. The next peaks came the following
        day, 23 October ($179), and then <strong>28 and 29 October ($183 and $169)</strong>. Quiet days
        cost cents, or nothing: the plan covered the first three weeks of the month and I paid nothing
        above it.
      </p>
      <DailySpendChart locale="en" />
      <p>
        Spend does not grow smoothly with time. It arrives in jumps. A single expensive day cost more
        than I paid above the plan for the entire first three weeks put together (that is, zero).
      </p>

      <h2>What I take from it</h2>
      <ul>
        <li>
          <strong>Watch spend by day, not by month.</strong> A monthly invoice only gives the sum. I would
          not have seen the 22 October peak on it, and that is where the decision sits.
        </li>
        <li>
          <strong>Separate the plan from on-demand.</strong> While the plan still covers the work, further
          calls cost nothing. Extra money starts only after it runs out, so it is worth knowing when that
          happens.
        </li>
        <li>
          <strong>The cache is the cheapest optimization.</strong> Stable instructions and context at the
          start of the prompt mean most tokens are read from cache. More in the article on{" "}
          <Link to={hrefFor("grok-tokens", "en")}>optimizing tokens on Grok</Link>.
        </li>
        <li>
          <strong>Without the data you cannot judge the return.</strong> $859 for a month can be a lot, or
          not much. It depends on what the agents did for it, and you only know that when you know what
          each day and each job cost.
        </li>
      </ul>

      <h2>That is why I am building Tokeny</h2>
      <p>
        Tokeny is a dashboard that shows daily AI spend across providers, in USD and in Czech crowns.
        It can also take a <strong>usage CSV from Cursor and Grok Bot</strong>. It separates cache tokens
        from fresh ones, and spend inside the plan from spend above it. The file is processed in the
        browser, and the emails and user ids in that export are not stored.
      </p>
      <p>
        <Link to="/auth">Try Tokeny for free</Link> and upload your export. Or estimate first in the{" "}
        <Link to="/llm-cost-calculator">cost calculator</Link>. The step-by-step is in{" "}
        <Link to={hrefFor("track-cursor", "en")}>how to track spend on Cursor and Grok Bot</Link>.
      </p>
    </>
  );
}

function TokenTable({ locale }: { locale: BlogLocale }) {
  const head = locale === "en"
    ? ["Token type", "Count", "Share"]
    : ["Druh tokenů", "Počet", "Podíl"];
  return (
    <div className="not-prose glass rounded-2xl overflow-x-auto my-6">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-muted-foreground border-b border-border/50">
            <th scope="col" className="px-4 py-3 font-medium">{head[0]}</th>
            <th scope="col" className="px-4 py-3 font-medium text-right">{head[1]}</th>
            <th scope="col" className="px-4 py-3 font-medium text-right">{head[2]}</th>
          </tr>
        </thead>
        <tbody>
          {TOKEN_ROWS[locale].map((row) => (
            <tr key={row.kind} className="border-b border-border/30 last:border-0">
              <td className="px-4 py-3">{row.kind}</td>
              <td className="px-4 py-3 text-right tabular-nums">{row.tokens}</td>
              <td className="px-4 py-3 text-right tabular-nums">{row.share}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function BlogAiAgentCosts({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="ai-agents" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
