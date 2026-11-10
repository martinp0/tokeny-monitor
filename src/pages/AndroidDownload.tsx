import { Helmet } from "react-helmet-async";
import { Link } from "react-router-dom";
import { PublicHeader } from "@/components/PublicHeader";

/**
 * Direct APK download for the Android app (signed release, public/downloads).
 * Store listing copy matches android/fastlane/metadata/android.
 */

export const ANDROID_VERSION_NAME = "0.2.0";
export const ANDROID_VERSION_CODE = "2";
export const ANDROID_CERT_SHA256 =
  "92:BD:37:70:0B:21:01:1B:39:FA:C2:7D:8F:2D:4E:F9:9B:61:0A:D0:F9:E5:FD:97:C0:D7:2F:3A:5B:11:D6:2B";
export const ANDROID_APK_URL = "https://tokeny.martinpohl.cz/downloads/tokeny-0.2.0.apk";
export const ANDROID_APK_PATH = "/downloads/tokeny-0.2.0.apk";
export const ANDROID_APK_SHA256 = "9984ba84dd8e28b607e02297846b7a0ba221279448dc3444caa4c37c2a804ac7";
export const ANDROID_APK_SIZE_BYTES = 8738913;

const SHORT = {
  cs: "Útrata za AI z vlastního CSV. Bez účtu, bez sítě, data zůstanou v telefonu.",
  en: "AI spend from a CSV you choose. No account, no network; data stays on the phone.",
};

export default function AndroidDownload() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Helmet>
        <title>Tokeny pro Android {ANDROID_VERSION_NAME} | Tokeny</title>
        <meta
          name="description"
          content="Download the Tokeny Android app as an APK. Version 0.2.0 is a signed release APK. The app is offline and has no account."
        />
        <link rel="canonical" href="https://tokeny.martinpohl.cz/android" />
        <meta property="og:url" content="https://tokeny.martinpohl.cz/android" />
        <meta property="og:type" content="website" />
      </Helmet>
      <PublicHeader />
      <article id="main" className="container mx-auto px-4 py-16 max-w-3xl">
        <p className="text-sm text-muted-foreground mb-3">Android · {ANDROID_VERSION_NAME} ({ANDROID_VERSION_CODE})</p>
        <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-4">Tokeny pro Android</h1>
        <p className="text-[17px] leading-relaxed mb-8">
          Přímé stažení APK. Obchod Play ani Galaxy Store teď nejsou kanál, kterým se aplikace instaluje.
          Před instalací si ověřte otisk SHA-256 souboru níže.
        </p>

        <section className="mb-10 rounded-xl border border-border p-5" lang="cs">
          <h2 className="text-xl font-semibold mb-3">Soubor</h2>
          <dl className="space-y-3 text-sm leading-relaxed">
            <div>
              <dt className="font-medium">URL APK</dt>
              <dd className="break-all">
                <a href={ANDROID_APK_PATH} download className="text-primary hover:underline">{ANDROID_APK_URL}</a>
              </dd>
              <dd className="text-muted-foreground">Velikost {(ANDROID_APK_SIZE_BYTES / 1024 / 1024).toFixed(1)} MB ({ANDROID_APK_SIZE_BYTES} B)</dd>
            </div>
            <div>
              <dt className="font-medium">SHA-256 souboru</dt>
              <dd className="font-mono text-xs break-all">{ANDROID_APK_SHA256}</dd>
            </div>
            <div>
              <dt className="font-medium">SHA-256 podpisu (certifikát)</dt>
              <dd className="font-mono text-xs break-all">{ANDROID_CERT_SHA256}</dd>
            </div>
          </dl>
        </section>

        <section lang="cs" id="cs" className="mb-12 scroll-mt-20">
          <h2 className="text-xl font-semibold mb-3">Instalace</h2>
          <ol className="list-decimal pl-5 space-y-2 leading-relaxed text-muted-foreground">
            <li>Stáhněte APK z odkazu výše.</li>
            <li>
              Na počítači porovnejte otisk: <code className="text-foreground">sha256sum tokeny-0.2.0.apk</code>.
              Musí se shodovat s SHA-256 souboru na téhle stránce. Když se neshoduje, soubor neinstalujte.
            </li>
            <li>
              V telefonu otevřete Nastavení, Aplikace, Zvláštní přístup, Instalovat neznámé aplikace, a povolte to prohlížeči nebo aplikaci Soubory, ze které APK otevíráte.
            </li>
            <li>Otevřete stažený APK a instalaci potvrďte.</li>
            <li>
              Podpis ověříte na počítači příkazem <code className="text-foreground">apksigner verify --print-certs tokeny-0.2.0.apk</code>.
              SHA-256 certifikátu má být {ANDROID_CERT_SHA256}.
            </li>
            <li>
              Aktualizace je ruční. Stáhněte novější APK se stejným balíčkem, stejným podpisem a vyšším číslem verze. Android nabídne aktualizaci. Samo se to nestahuje.
            </li>
          </ol>
          <p className="mt-4 leading-relaxed">
            <Link to="/android/privacy" className="text-primary hover:underline">Ochrana osobních údajů aplikace</Link>
          </p>
        </section>

        <section lang="en" id="en" className="mb-12 scroll-mt-20">
          <h2 className="text-xl font-semibold mb-3">Install</h2>
          <ol className="list-decimal pl-5 space-y-2 leading-relaxed text-muted-foreground">
            <li>Download the APK from the URL above.</li>
            <li>
              On a computer, compare the digest: <code className="text-foreground">sha256sum tokeny-0.2.0.apk</code>.
              It has to match the file SHA-256 on this page. If it does not match, do not install the file.
            </li>
            <li>
              On the phone, open Settings, Apps, Special app access, Install unknown apps, and allow the browser or the Files app you use to open the APK.
            </li>
            <li>Open the downloaded APK and confirm the install.</li>
            <li>
              Check the signature on a computer with <code className="text-foreground">apksigner verify --print-certs tokeny-0.2.0.apk</code>.
              The certificate SHA-256 should be {ANDROID_CERT_SHA256}.
            </li>
            <li>
              Updates are manual. Download a newer APK with the same package, the same signature, and a higher version code. Android then offers an update. It does not download itself.
            </li>
          </ol>
          <p className="mt-4 leading-relaxed">
            <Link to="/android/privacy" className="text-primary hover:underline">Android app privacy policy</Link>
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold mb-3">Krátký a dlouhý popis</h2>
          <p className="text-sm text-muted-foreground mb-2">Česky · krátce</p>
          <p className="mb-4">{SHORT.cs}</p>
          <p className="text-sm text-muted-foreground mb-2">English · short</p>
          <p className="mb-4">{SHORT.en}</p>
          <div lang="cs" className="space-y-3 leading-relaxed text-muted-foreground mb-6">
            <p>Tokeny je přehled útraty za AI přímo v telefonu. Tahle aplikace neotevírá účet a nepřipojuje se k poskytovatelům.</p>
            <p>Importuje CSV, které si vyberete v systémovém výběru souborů. Zvládne výpis aktivity z OpenRouteru a export využití z Cursoru nebo Grok Botu. Než se řádky uloží, ukáže náhled: kolik jich přijme, které přeskočí a jaký je součet v dolarech. Dny seskupuje podle časového pásma Europe/Prague, včetně letního času. Částky nechává v USD a kurz do korun si nevymýšlí.</p>
            <p>Uložený import je jen ve soukromém úložišti aplikace. Smažete ho v aplikaci. Odinstalace smaže soukromé úložiště taky.</p>
            <p>Ukázková data jsou označená a oddělená od importu. Rozpočet a předpověď z připojeného účtu Pro tady nejsou. Aplikace je nemá z čeho spočítat a Pro neprodává.</p>
            <p>Aplikace nevolá internet. Jediné oprávnění, ACCESS_NETWORK_STATE, jen pozná, jestli je telefon offline, a tím označí ukázku. Nemá analytiku ani reklamy.</p>
            <p>Provozuje ji Bc. Martin Pohl, IČO 17256712.</p>
          </div>
          <div lang="en" className="space-y-3 leading-relaxed text-muted-foreground">
            <p>Tokeny is an AI spend overview that stays on the phone. This app does not open an account and does not connect to providers.</p>
            <p>It imports a CSV you pick in the system file picker. It reads an OpenRouter activity export and a Cursor or Grok Bot usage export. Before anything is saved, it shows a preview: how many rows it accepts, which ones it skips, and the total in dollars. Days are grouped in the Europe/Prague time zone, including daylight-saving time. Amounts stay in USD. The app does not invent a koruna exchange rate.</p>
            <p>The saved import lives only in the app&apos;s private storage. You can delete it in the app. Uninstalling the app deletes that private storage too.</p>
            <p>Sample data is labeled and kept apart from an import. A connected Pro budget and forecast are not here. The app has nothing to calculate them from, and it does not sell Pro.</p>
            <p>The app does not call the internet. Its only permission, ACCESS_NETWORK_STATE, checks whether the phone is offline so it can label the sample. There is no analytics and no advertising.</p>
            <p>Published by Bc. Martin Pohl, IČO 17256712.</p>
          </div>
        </section>
      </article>
    </div>
  );
}
