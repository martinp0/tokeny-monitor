import { BlogArticleFrame } from "@/components/BlogPostLayout";
import type { BlogLocale } from "@/content/blog/catalog";

/**
 * Republication of https://martinpohl.cz/cs/blog/kolik-stoji-ai-tokeny-realne
 * and https://martinpohl.cz/en/blog/what-ai-actually-costs.
 * Canonical points at those originals. The wording follows the source.
 */
function Czech() {
  return (
    <>
      <p>
        Před pár měsíci jsem si všiml, že moje OpenRouter faktura roste rychleji, než jsem čekal.
        Otevřel jsem activity export, hodil ho do Excelu — a po hodině jsem to vzdal. Tabulky nejsou
        navržené pro vizuální analýzu utrácení.
      </p>

      <h2>Tak vznikly Tokeny</h2>
      <p>
        <a href="https://tokeny.martinpohl.cz/">tokeny.pohl.uk</a> je dashboard, který stáhne tvůj CSV
        export z OpenRouter a ukáže ti spotřebu v reálném čase. Grafy podle modelů, providerů, latence,
        a real-life srovnání: 'tvoje API faktura = 47 espress'.
      </p>

      <h2>Co mě nejvíc překvapilo</h2>
      <ol>
        <li>80 % nákladů jde na 20 % requestů — ty velké context windows tě zruinují.</li>
        <li>Claude Opus je ~100× dražší než Gemini Flash, ale ne vždy 100× lepší.</li>
        <li>Free modely (Z.AI, Arcee, Nvidia Nemotron) zvládnou víc než si myslíš.</li>
        <li>Tool-calling requesty mají často víc tokenů než klasické chat completions.</li>
      </ol>

      <h2>Komu to pomůže</h2>
      <p>
        Komukoliv, kdo používá OpenRouter na víc než hraní. Indie makers, agentury, AI startupy. Stačí
        pár kliknutí — žádná kreditka, žádná instalace.
      </p>
      <p>
        Vyzkoušej demo na <a href="https://tokeny.martinpohl.cz/">tokeny.pohl.uk</a> — má načtená moje
        vlastní data, takže si můžeš proklikat reálné grafy bez registrace.
      </p>
    </>
  );
}

function English() {
  return (
    <>
      <p>
        A few months ago I noticed my OpenRouter invoice growing faster than I expected. I downloaded
        the activity export, dropped it into a spreadsheet, and gave up after an hour. Spreadsheets are
        a poor way to see where the money goes.
      </p>

      <h2>That is how Tokeny started</h2>
      <p>
        <a href="https://tokeny.martinpohl.cz/">tokeny.pohl.uk</a> is a dashboard that reads your
        OpenRouter CSV export and shows the spend as it actually happened. Charts by model, provider and
        latency, and a plain comparison: your API invoice equals 47 espressos.
      </p>

      <h2>What surprised me most</h2>
      <ol>
        <li>About 80 percent of the cost sits in 20 percent of the requests. Large context windows are what hurt.</li>
        <li>Claude Opus is roughly 100 times more expensive than Gemini Flash, and it is not always 100 times better.</li>
        <li>Free models (Z.AI, Arcee, Nvidia Nemotron) handle more than people assume.</li>
        <li>Tool-calling requests often use more tokens than a normal chat completion.</li>
      </ol>

      <h2>Who it is for</h2>
      <p>
        Anyone using OpenRouter for more than a weekend experiment. Indie makers, agencies, AI startups.
        A few clicks, no card, nothing to install.
      </p>
      <p>
        Try the demo at <a href="https://tokeny.martinpohl.cz/">tokeny.pohl.uk</a>. It is loaded with my
        own data, so you can click through real charts without creating an account.
      </p>
    </>
  );
}

export default function BlogWhatAiCosts({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="what-ai-costs" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
