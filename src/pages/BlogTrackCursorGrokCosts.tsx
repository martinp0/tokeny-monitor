import { Link } from "react-router-dom";
import BlogPostLayout from "@/components/BlogPostLayout";

const SOURCES = [
  { tool: "Cursor", what: "CSV export využití z přehledu účtu (usage)", granularity: "jednotlivá volání, model, tokeny, cena" },
  { tool: "Grok Bot", what: "CSV export využití", granularity: "jednotlivá volání, produkt, tokeny, cena" },
  { tool: "OpenRouter", what: "CSV z openrouter.ai/activity nebo API klíč", granularity: "jednotlivá volání, model, aplikace, cena" },
];

export default function BlogTrackCursorGrokCosts() {
  return (
    <BlogPostLayout
      title="Jak sledovat náklady na Cursor, Grok Bot a OpenRouter (a nepřeplácet)"
      description="Praktický návod pro každého, kdo platí za Cursor, Grok Bot nebo OpenRouter: kde vzít data o útratě, co v nich sledovat, jak nastavit kontrolu a jak to celé dostat do jednoho přehledu v korunách."
      slug="jak-sledovat-naklady-cursor-a-grok-bot"
      date="2026-11-05"
      dateLabel="5. 11. 2026"
      tag="Návod"
      keywords="cursor cena, cursor náklady, grok bot cena, openrouter náklady, sledování nákladů ai, on-demand cursor, usage export csv, tokeny"
    >
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
      <div className="not-prose glass rounded-2xl overflow-x-auto my-6">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-muted-foreground border-b border-border/50">
              <th className="px-4 py-3 font-medium">Nástroj</th>
              <th className="px-4 py-3 font-medium">Zdroj dat</th>
              <th className="px-4 py-3 font-medium">Co v nich je</th>
            </tr>
          </thead>
          <tbody>
            {SOURCES.map((r) => (
              <tr key={r.tool} className="border-b border-border/30 last:border-0">
                <td className="px-4 py-3 font-medium">{r.tool}</td>
                <td className="px-4 py-3">{r.what}</td>
                <td className="px-4 py-3">{r.granularity}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

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
        z Cursoru, Grok Bota nebo OpenRouteru a uvidíte denní útratu, rozpad podle modelu, tokeny z mezipaměti
        oproti novým a útratu v tarifu oproti té nad ním, v dolarech i v korunách. Soubor se zpracuje
        v prohlížeči, opakované nahrání stejného exportu nic nezdvojí a e-maily ani ID uživatelů z exportu
        se neukládají.
      </p>
      <p>
        <Link to="/auth">Vyzkoušej Tokeny zdarma</Link>, nebo si nejdřív udělej odhad
        v <Link to="/llm-cost-calculator">kalkulačce nákladů na LLM</Link>.
      </p>
    </BlogPostLayout>
  );
}
