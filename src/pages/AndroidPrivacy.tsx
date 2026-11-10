import { Helmet } from "react-helmet-async";
import { Link } from "react-router-dom";
import { ShieldCheck } from "lucide-react";
import { PublicHeader } from "@/components/PublicHeader";

/**
 * Privacy policy for the Android app only. The website and Apple apps stay on /privacy.
 * Facts below match android/app/src/main/AndroidManifest.xml and SpendViewModel.
 */

const UPDATED = { cs: "10. 11. 2026", en: "10 November 2026" };
const OPERATOR = "Bc. Martin Pohl";
const ICO = "17256712";
const SEAT = "Hrnčířská 221, Zdiměřice, 252 42 Jesenice";
const EMAIL = "hello@martinpohl.cz";

type Block = { h: string; p?: string[]; ul?: string[] };

const CS: { title: string; updated: string; intro: string; blocks: Block[] } = {
  title: "Ochrana osobních údajů aplikace Tokeny pro Android",
  updated: `Poslední aktualizace: ${UPDATED.cs}`,
  intro:
    "Tahle stránka platí jen pro aplikaci Tokeny pro Android (balíček cz.martinpohl.tokeny, verze 0.2.0). Web a aplikace pro Apple mají vlastní zásady.",
  blocks: [
    {
      h: "1. Kdo aplikaci vydává",
      p: [
        `Aplikaci vydává ${OPERATOR}, IČO ${ICO}, se sídlem ${SEAT}. Kontakt: ${EMAIL}.`,
      ],
    },
    {
      h: "2. Účet, síť a analytika",
      ul: [
        "Aplikace nemá účet, přihlášení ani heslo.",
        "Manifest žádá jen oprávnění ACCESS_NETWORK_STATE. Oprávnění INTERNET v něm není. Stav sítě se čte jen na telefonu, aby šla ukázka označit jako offline. Nikam se neposílá.",
        "Aplikace neobsahuje analytiku ani reklamy.",
      ],
    },
    {
      h: "3. Co zůstane v telefonu",
      p: [
        "CSV, které vyberete a potvrdíte, se převede do souboru files/local-ledger.json v soukromém úložišti aplikace. Jsou v něm identifikátor řádku, časy, den v pásmu Europe/Prague, částka v USD, počty tokenů, model, poskytovatel a případné označení účtování. Není v něm jméno, e-mail, heslo ani číslo karty.",
        "Původní soubor se čte přes systémový výběr souborů. Aplikace si nenechává jeho druhou kopii.",
        "Ukázková data jsou součást aplikace a nejsou to vaše údaje.",
      ],
    },
    {
      h: "4. Záloha a výmaz",
      ul: [
        "Záloha a přenos na jiné zařízení jsou vypnuté (allowBackup je false).",
        "Uložený import smažete v aplikaci. Tím se smaže local-ledger.json.",
        "Odinstalace smaže soukromé úložiště aplikace. Na serveru není účet, který by bylo potřeba mazat.",
      ],
    },
    {
      h: "5. Šifrování při přenosu",
      p: [
        "Aplikace data nikam neposílá, takže šifrování při přenosu se jí netýká. Nešifrovaný provoz (cleartext) je v konfiguraci zakázaný.",
      ],
    },
  ],
};

const EN: { title: string; updated: string; intro: string; blocks: Block[] } = {
  title: "Privacy policy for the Tokeny Android app",
  updated: `Last updated: ${UPDATED.en}`,
  intro:
    "This page covers only the Tokeny Android app (package cz.martinpohl.tokeny, version 0.2.0). The website and the Apple apps have their own policy.",
  blocks: [
    {
      h: "1. Who publishes the app",
      p: [
        `${OPERATOR}, IČO ${ICO}, registered at ${SEAT}, publishes the app. Contact: ${EMAIL}.`,
      ],
    },
    {
      h: "2. Account, network, and analytics",
      ul: [
        "The app has no account, no sign-in, and no password.",
        "The manifest asks only for ACCESS_NETWORK_STATE. It does not request INTERNET. The network state is read on the phone so the sample can be labeled offline. It is not sent anywhere.",
        "The app has no analytics and no advertising.",
      ],
    },
    {
      h: "3. What stays on the phone",
      p: [
        "A CSV you pick and confirm is written to files/local-ledger.json in the app's private storage. A row holds its id, timestamps, the Europe/Prague day, the USD amount, token counts, the model, the provider, and an optional billing label. It does not hold a name, an email, a password, or a card number.",
        "The original file is read through the system document picker. The app does not keep a second copy.",
        "Sample data is part of the app and is not your data.",
      ],
    },
    {
      h: "4. Backup and deletion",
      ul: [
        "Backup and device transfer are off (allowBackup is false).",
        "You delete a saved import in the app. That deletes local-ledger.json.",
        "Uninstalling the app deletes its private storage. There is no account on a server to delete.",
      ],
    },
    {
      h: "5. Encryption in transit",
      p: [
        "The app does not send data anywhere, so encryption in transit does not apply. Cleartext traffic is disabled in the network security config.",
      ],
    },
  ],
};

function Section({ copy, lang }: { copy: typeof CS; lang: "cs" | "en" }) {
  return (
    <section lang={lang} id={lang} className="scroll-mt-20">
      <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-2">{copy.title}</h1>
      <p className="text-sm text-muted-foreground mb-6">{copy.updated}</p>
      <p className="text-[17px] leading-relaxed mb-8">{copy.intro}</p>
      {copy.blocks.map((b) => (
        <div key={b.h} className="mb-8">
          <h2 className="text-xl font-semibold tracking-tight mb-3">{b.h}</h2>
          {b.p?.map((t) => (
            <p key={t} className="leading-relaxed text-muted-foreground mb-3">{t}</p>
          ))}
          {b.ul && (
            <ul className="list-disc pl-5 space-y-2 leading-relaxed text-muted-foreground">
              {b.ul.map((t) => <li key={t}>{t}</li>)}
            </ul>
          )}
        </div>
      ))}
    </section>
  );
}

export default function AndroidPrivacy() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Helmet>
        <title>Android privacy / Ochrana údajů aplikace | Tokeny</title>
        <meta
          name="description"
          content="The Tokeny Android app is offline, has no account, and keeps an imported CSV only in app-private storage."
        />
        <link rel="canonical" href="https://tokeny.martinpohl.cz/android/privacy" />
        <meta property="og:url" content="https://tokeny.martinpohl.cz/android/privacy" />
        <meta property="og:type" content="website" />
      </Helmet>
      <PublicHeader />
      <article id="main" className="container mx-auto px-4 py-16 max-w-3xl">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 text-primary text-xs">
            <ShieldCheck className="h-3 w-3" aria-hidden /> Android
          </div>
          <nav aria-label="Language" className="text-sm flex gap-3">
            <a href="#cs" className="text-primary hover:underline">Česky</a>
            <a href="#en" className="text-primary hover:underline">English</a>
          </nav>
        </div>
        <Section copy={CS} lang="cs" />
        <hr className="my-14 border-border" />
        <Section copy={EN} lang="en" />
      </article>
      <footer className="border-t border-border/40 py-8 text-center text-sm text-muted-foreground">
        <p>
          <Link to="/android" className="hover:text-foreground">Android</Link>
          {" · "}
          <Link to="/privacy" className="hover:text-foreground">Web a Apple / Website and Apple</Link>
        </p>
      </footer>
    </div>
  );
}
