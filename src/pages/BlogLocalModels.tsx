import { BlogArticleFrame } from "@/components/BlogPostLayout";
import type { BlogLocale } from "@/content/blog/catalog";

/**
 * Republication of https://martinpohl.cz/cs/blog/ai-tokeny-vs-lokalni-modely-doma
 * and https://martinpohl.cz/en/blog/cloud-tokens-vs-local-ai-at-home.
 * The English original includes a break-even section the Czech page does not.
 * Canonical points at the matching martinpohl.cz URL.
 */

const CS_FAQ = [
  {
    q: "Jaký model si mám lokálně stáhnout jako první?",
    a: "Pro obecné použití doporučuji Qwen 2.5 14B nebo Llama 3.3 70B v 4bit kvantizaci. Qwen 14B běží plynule i na 16 GB unified memory, Llama 70B vyžaduje 48+ GB VRAM nebo 64+ GB unified memory. Pro kód je aktuálně nejsilnější Qwen 2.5 Coder 32B.",
  },
  {
    q: "Můžu lokální modely provozovat přímo na Synology NAS?",
    a: "Technicky ano přes Docker a llama.cpp CPU inference, ale reálně to má smysl jen pro malé modely (do 7B) a pomalé odpovědi. Rozumnější je NAS použít jako storage pro modely a inference dělat na druhém boxu s GPU nebo Apple Silicon.",
  },
  {
    q: "Co je lepší pro domov — Mac mini M4 nebo PC s RTX 5090?",
    a: "Mac mini M4 Pro/Max je tišší, úspornější a jednodušší na správu — ideál pro domácnost. PC s RTX 5090 dá víc tokenů za sekundu a lepší poměr cena/výkon u dlouhodobého vytížení, ale hlučí a topí. Pro většinu lidí je Mac mini rozumnější volba.",
  },
  {
    q: "Musím kvůli lokální AI zrušit Claude a GPT?",
    a: "Ne. Nejlepší je hybrid: lokální model na běžné úkoly (RAG, kód, klasifikace, přepisy), cloud na to, co lokál neutáhne. Přes OpenRouter nebo LiteLLM se to dá propojit tak, že aplikace o rozdílu ani neví.",
  },
  {
    q: "Jak řešit bezpečnost a přístup do lokálního modelu z venku?",
    a: "Nevystavuj endpoint přímo na internet. Používej Tailscale nebo WireGuard VPN, ať se ke svému AI serveru dostaneš odkudkoli, ale svět ho nevidí. Auth řeš na úrovni proxy (Caddy, Nginx) s API klíčem nebo mTLS.",
  },
];

const EN_FAQ = [
  {
    q: "Which local model should I download first?",
    a: "For general use, start with Qwen 2.5 14B or Llama 3.3 70B in 4-bit quantization. Qwen 14B runs smoothly even on 16 GB unified memory, Llama 70B needs 48+ GB VRAM or 64+ GB unified memory. For code, Qwen 2.5 Coder 32B is currently the strongest option.",
  },
  {
    q: "Can I run local models directly on a Synology NAS?",
    a: "Technically yes via Docker and llama.cpp CPU inference, but realistically only for small models (up to 7B) and slow responses. It's smarter to use the NAS as model storage and run inference on a second box with a GPU or Apple Silicon.",
  },
  {
    q: "Which is better for home — a Mac mini M4 or a PC with RTX 5090?",
    a: "The Mac mini M4 Pro/Max is quieter, more efficient and easier to manage — ideal for a household. A PC with RTX 5090 gives more tokens per second and better cost/perf under heavy load, but it's louder and hotter. For most people the Mac mini is the more sensible choice.",
  },
  {
    q: "Do I have to drop Claude and GPT to go local?",
    a: "No. The best pattern is hybrid: local model for everyday tasks (RAG, code, classification, transcripts), cloud for what local can't handle. Through OpenRouter or LiteLLM you can wire it up so the app doesn't even know the difference.",
  },
  {
    q: "How do I secure remote access to a local model?",
    a: "Don't expose the endpoint straight to the internet. Use Tailscale or a WireGuard VPN so you can reach your AI server from anywhere while it stays invisible to the world. Handle auth at the proxy layer (Caddy, Nginx) with an API key or mTLS.",
  },
];

function Faq({ items, title }: { items: { q: string; a: string }[]; title: string }) {
  return (
    <section className="not-prose mt-10">
      <h2 className="text-2xl font-bold tracking-tight mb-4">{title}</h2>
      <div className="space-y-3">
        {items.map((item) => (
          <details key={item.q} className="glass rounded-2xl px-4 py-3">
            <summary className="cursor-pointer font-semibold min-h-11 flex items-center">{item.q}</summary>
            <p className="mt-2 text-foreground/90 leading-relaxed">{item.a}</p>
          </details>
        ))}
      </div>
    </section>
  );
}

function Czech() {
  return (
    <>
      <p>
        Poslední rok se dvě čísla přibližují rychleji, než jsem čekal — cena za milion tokenů u
        Claude/GPT/Gemini a cena za watt výkonu u malých inferenčních strojů, které si člověk klidně
        postaví vedle své Synology NAS. Otázka „mám platit OpenRouter, nebo si koupit vlastní krabičku?“
        přestává být hračkou pro nadšence a začíná dávat smysl i pro solidní domácí i menší firemní setup.
      </p>

      <h2>Kolik dnes stojí cloudové tokeny (červenec 2026)</h2>
      <p>
        Ceníky se za rok posunuly, ale řádově platí: Claude Sonnet 4.5 kolem 3 USD za milion vstupních a
        15 USD za milion výstupních tokenů, GPT-5 v podobném pásmu, Gemini 2.5 Pro o něco levněji.
        Free-tier a Flash/Haiku modely jsou skoro zdarma, ale nezvládnou to samé. Jakmile začnete tahat
        kontexty přes 100k tokenů nebo dělat agenty s desítkami tool-callů denně, faktura za měsíc snadno
        vyletí přes 100 USD i u jednoho uživatele — a to je zlom, kdy má smysl počítat break-even proti
        vlastnímu hardware.
      </p>

      <h2>Kdy uvažovat o lokální AI</h2>
      <ul>
        <li>Máte citlivá data (klientské maily, HR, právní dokumenty), která nechcete posílat mimo LAN.</li>
        <li>Řešíte offline scénáře — chalupa, laboratoř, edge zařízení bez stabilního připojení.</li>
        <li>Točíte hodně tokenů denně (RAG nad Obsidianem, code assist, dávkové zpracování) a cloudová faktura roste.</li>
        <li>Chcete si osahat fine-tuning, LoRA, kvantizaci nebo vlastní speech-to-text bez rate limitů.</li>
        <li>Máte doma NAS a chuť si postavit malé „AI patro“ vedle něj — Synology jako storage, druhý box jako inference.</li>
      </ul>

      <h2>Hardware, který dává v roce 2026 smysl</h2>
      <p>
        Pro domácí použití vedle Synology NAS se dnes reálně bavíme o třech úrovních. 1) Mac mini M4 Pro /
        M4 Max se sjednocenou pamětí 48–64 GB — tichý, úsporný, přes MLX a Ollama zvládne 30–70B modely v
        kvantizované podobě. 2) Mini-PC nebo malý tower s RTX 4090 / 5090 (24–32 GB VRAM) — nejvíc tokenů
        za korunu, ale hlučnější a topí. 3) Framework Desktop nebo AMD Strix Halo s 128 GB unified memory —
        nová kategorie „AI appliance“, která umí 70B+ modely bez extrémní ceny. Všechny tři se dají postavit
        tak, aby vedle NASky vypadaly rozumně a braly méně než 200 W v idle.
      </p>

      <h2>Softwarový stack, který funguje bez bolesti</h2>
      <ul>
        <li>Ollama nebo LM Studio pro rychlý start a lokální OpenAI-kompatibilní API.</li>
        <li>vLLM nebo llama.cpp server pro produkční průchodnost a batching.</li>
        <li>Open WebUI nebo LibreChat jako čisté rozhraní pro celou domácnost.</li>
        <li>Continue.dev / Zed jako IDE integrace, která volá lokální endpoint místo cloudu.</li>
        <li>Synology jako NFS/SMB storage pro modely (Qwen, Llama, Mistral, DeepSeek) a RAG index.</li>
      </ul>

      <h2>Kde má cloud pořád navrch</h2>
      <p>
        Frontier úlohy (dlouhý reasoning, náročný tool-use, generování obrázků a videa, mnohonásobně-modální
        kontext) na domácím hardware zatím nedáte v porovnatelné kvalitě. Rozumný hybrid v roce 2026: 70–80 %
        denního objemu (kód, zápisky, RAG, klasifikace mailů) běží lokálně, top 20 % (těžké analýzy, generace
        obrázků, komplexní agent) jde do cloudu přes fallback vrstvu (OpenRouter, LiteLLM). Tím zkrotíte
        faktury a zároveň nepřijdete o kvalitu tam, kde ji potřebujete.
      </p>

      <h2>Praktický postup, když si chcete jen sáhnout</h2>
      <p>
        Začněte na tom, co doma máte — Mac s 16+ GB pamětí nebo starší PC s RTX 3090. Nainstalujte Ollama,
        stáhněte Qwen 2.5 14B nebo Llama 3.3 70B v kvantizované podobě, nastavte si Open WebUI, propojte s
        NAS přes SMB pro modely. Dva týdny sledujte, kolik tokenů reálně přesunete z cloudu. Teprve pak
        řešte, jestli má smysl investovat do dedikovaného boxu.
      </p>

      <blockquote>
        <p>
          Lokální AI dnes není o tom, že by byla vždy levnější. Je o tom, že přesouvá kontrolu — nad daty,
          latencí i faktury — zpátky k vám.
        </p>
      </blockquote>

      <h2>Závěr a jak pomohu</h2>
      <p>
        Pokud vážně přemýšlíte o vlastním setupu — výběr hardware, quantizace, RAG přes NAS, integrace s
        Google Workspace nebo interním nástrojem — ozvěte se. Rád pomohu s návrhem, nákupním listem a
        prvním nasazením, ať doma nebo v menší firmě.
      </p>
      <Faq items={CS_FAQ} title="Časté otázky" />
    </>
  );
}

function English() {
  return (
    <>
      <p>
        Two numbers have been converging faster than I expected over the last year — the per-token price
        of Claude/GPT/Gemini and the per-watt cost of small inference boxes you can happily park next to
        your Synology NAS. The question "should I keep paying OpenRouter, or buy my own box?" is no longer
        a hobbyist's toy; it's becoming reasonable for solid home setups and small businesses.
      </p>

      <h2>What cloud tokens cost today (July 2026)</h2>
      <p>
        Prices have moved, but the ballpark: Claude Sonnet 4.5 sits around 3 USD per million input and 15
        USD per million output tokens, GPT-5 in a similar band, Gemini 2.5 Pro a bit cheaper. Free-tier
        and Flash/Haiku models are nearly free but not equivalent. Once you start pulling 100k+ context
        windows or running agents with dozens of tool calls per day, a single user's monthly bill can
        easily cross 100 USD — and that's the inflection point where doing break-even math against your
        own hardware starts to make sense.
      </p>

      <h2>When local AI is worth considering</h2>
      <ul>
        <li>You handle sensitive data (client email, HR, legal) you don't want leaving your LAN.</li>
        <li>You have offline needs — cabin, lab, edge — without reliable connectivity.</li>
        <li>You burn a lot of tokens daily (RAG over Obsidian, code assist, batch processing) and the cloud bill is growing.</li>
        <li>You want to play with fine-tuning, LoRA, quantization or your own STT without rate limits.</li>
        <li>You already have a NAS at home and like the idea of a small "AI shelf" next to it — Synology for storage, a second box for inference.</li>
      </ul>

      <h2>Hardware that makes sense in 2026</h2>
      <p>
        For home use next to a Synology NAS there are roughly three tiers. 1) Mac mini M4 Pro / M4 Max with
        48–64 GB unified memory — quiet, efficient, runs 30–70B quantized models via MLX and Ollama. 2) A
        mini-PC or small tower with an RTX 4090 / 5090 (24–32 GB VRAM) — most tokens per dollar, but louder
        and hotter. 3) Framework Desktop or AMD Strix Halo with 128 GB unified memory — a new "AI appliance"
        class that handles 70B+ models without breaking the bank. All three can sit next to the NAS looking
        sensible and idle under 200 W.
      </p>

      <h2>A software stack that just works</h2>
      <ul>
        <li>Ollama or LM Studio for a fast start and an OpenAI-compatible local endpoint.</li>
        <li>vLLM or llama.cpp server for production throughput and batching.</li>
        <li>Open WebUI or LibreChat as a clean interface for the whole household.</li>
        <li>Continue.dev / Zed as IDE integration that hits the local endpoint instead of the cloud.</li>
        <li>Synology as NFS/SMB storage for models (Qwen, Llama, Mistral, DeepSeek) and the RAG index.</li>
      </ul>

      <h2>Break-even in numbers</h2>
      <p>
        A simplified example: an RTX 5090 build at ~3,800 USD, drawing ~250 W on average (0.25 USD/kWh) is
        roughly 45 USD/month in electricity. If you spend 150–250 USD/month on cloud tokens today, payback
        lands around 18–24 months — and that ignores the value of keeping data at home. A Mac mini M4 Pro
        is cheaper up front, idles at 10–20 W, so it pays back in under a year, at the cost of a lower
        ceiling on model size.
      </p>

      <h2>Where the cloud still wins</h2>
      <p>
        Frontier workloads (long-horizon reasoning, heavy tool use, image/video generation, multi-modal
        contexts) still beat a home rig on quality. A sensible 2026 hybrid: 70–80 % of daily volume (code,
        notes, RAG, email triage) runs locally, the top 20 % (deep analysis, image generation, complex
        agents) is routed to the cloud through a fallback layer (OpenRouter, LiteLLM). You tame the bill
        without giving up quality where it matters.
      </p>

      <h2>How to try it without committing</h2>
      <p>
        Start with what you already own — a Mac with 16+ GB or an older PC with an RTX 3090. Install
        Ollama, pull Qwen 2.5 14B or Llama 3.3 70B quantized, set up Open WebUI, mount the NAS over SMB for
        model storage. Watch for two weeks how many tokens you actually shift off the cloud. Only then
        decide whether a dedicated box is worth buying.
      </p>

      <blockquote>
        <p>
          Local AI in 2026 isn't always cheaper. It's about moving control — of your data, latency and
          bills — back to you.
        </p>
      </blockquote>

      <h2>Wrap-up and how I can help</h2>
      <p>
        If you're seriously thinking about a home or small-office setup — hardware picks, quantization, RAG
        over your NAS, integration with Google Workspace or an internal tool — get in touch. I'm happy to
        help with the design, a purchase list and the first deployment.
      </p>
      <Faq items={EN_FAQ} title="Common questions" />
    </>
  );
}

export default function BlogLocalModels({ locale = "cs" }: { locale?: BlogLocale }) {
  return (
    <BlogArticleFrame id="local-models" locale={locale}>
      {locale === "en" ? <English /> : <Czech />}
    </BlogArticleFrame>
  );
}
