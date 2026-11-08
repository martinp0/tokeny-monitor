import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { renderHook } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { readFileSync } from "node:fs";
import i18n from "@/i18n";
import cs from "@/i18n/cs.json";
import en from "@/i18n/en.json";
import { OnboardingEmptyState } from "@/components/dashboard/OnboardingEmptyState";
import { SamplePreviewBanner } from "@/components/dashboard/SamplePreviewBanner";
import { FirstImportPanel } from "@/components/dashboard/FirstImportPanel";
import { dashboardChrome } from "@/lib/sample-preview";
import { useDashboardData } from "@/hooks/useDashboardData";

vi.mock("@/hooks/useAuth", () => ({
  useAuth: () => ({ session: { user: { id: "user-1" } }, loading: false, signOut: async () => {} }),
}));

vi.mock("@/hooks/useSubscription", () => ({
  useSubscription: () => ({ isPro: false, loading: false, startCheckout: async () => {}, hasCustomer: false }),
}));

const fetches: string[] = [];

function leafKeys(value: unknown, prefix = ""): string[] {
  if (Array.isArray(value)) return value.flatMap((item, i) => leafKeys(item, `${prefix}.${i}`));
  if (value && typeof value === "object") {
    return Object.entries(value).flatMap(([key, child]) => leafKeys(child, prefix ? `${prefix}.${key}` : key));
  }
  return [prefix];
}

beforeAll(() => {
  // jsdom 20 Blobs have no Blob#text; browsers do, and the importer relies on it.
  if (typeof Blob.prototype.text !== "function") {
    Blob.prototype.text = function text() {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result ?? ""));
        reader.onerror = () => reject(reader.error);
        reader.readAsText(this);
      });
    };
  }
});

afterEach(async () => {
  cleanup();
  fetches.length = 0;
  vi.unstubAllGlobals();
  await i18n.changeLanguage("cs");
});

function stubFetch() {
  vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo, init?: RequestInit) => {
    const url = String(input);
    fetches.push(`${init?.method ?? (init?.body ? "POST" : "GET")} ${url}`);
    if (url.includes("/activity/import")) return new Response(JSON.stringify({ written: 1 }), { status: 200 });
    if (url.includes("/activity")) return new Response(JSON.stringify({ rows: [] }), { status: 200 });
    return new Response("{}", { status: 200 });
  }));
}

function csvFile(name: string, createdAt: string) {
  const csv = `generation_id,created_at,cost_total\nrow-1,${createdAt},1.25\n`;
  return new File([csv], name, { type: "text/csv" });
}

describe("first-import copy", () => {
  it("keeps Czech and English keys in step, and does not promise alerts on the free hero", () => {
    const roots = ["importSources", "onboarding", "sample", "firstImport"] as const;
    for (const root of roots) {
      expect(leafKeys(cs[root])).toEqual(leafKeys(en[root]));
    }
    expect(cs.landing.hero.subtitle).toMatch(/Cursor/);
    expect(cs.landing.hero.subtitle).toMatch(/Grok Bot/);
    expect(cs.landing.hero.subtitle).not.toMatch(/upozorněn/);
    expect(en.landing.hero.subtitle).not.toMatch(/heads-up|alert/i);
    expect(cs.landing.demo.subtitle).toMatch(/není to útrata zákazníka/i);
    expect(en.landing.demo.subtitle).toMatch(/Not a customer's spend/);
    expect(cs.landing.how.s2d).toMatch(/Cursoru/);
    expect(en.landing.features.items.providers.desc).toMatch(/Cursor, Grok Bot and OpenRouter/);
  });

  it("separates Cursor/Grok privacy from OpenRouter, and keeps Pro claims on Pro", () => {
    expect(cs.importSources.privacyCursor).toMatch(/neukládají/);
    expect(cs.importSources.privacyCursor).toMatch(/Cursoru a Grok Bota/);
    expect(cs.importSources.privacyOpenRouter).toMatch(/user id/);
    expect(cs.importSources.privacyOpenRouter).toMatch(/To neplatí pro Cursor a Grok Bot/);
    expect(en.importSources.privacyOpenRouter).toMatch(/does not apply to Cursor or Grok Bot/);
    expect(cs.onboarding.sampleHint).toMatch(/rozpočtu, fakturaci ani sdílení/);
    expect(cs.firstImport.proItems.join(" ")).toMatch(/Europe\/Prague/);
    expect(cs.firstImport.proItems.join(" ")).toMatch(/E-mail neposíláme/);
    expect(cs.firstImport.csvNote).toMatch(/samo neaktualizuje/);
    expect(cs.firstImport.aiNote).toMatch(/Free/);
    expect(cs.onboarding.title).not.toMatch(/PDF|predikce/);
  });
});

describe("empty state and sample banner", () => {
  it("offers a labelled sample and the three real sources, in Czech and English", async () => {
    const onUpload = vi.fn();
    const onShowSample = vi.fn();
    const ui = (
      <MemoryRouter>
        <OnboardingEmptyState onUpload={onUpload} onShowSample={onShowSample} />
      </MemoryRouter>
    );
    const { rerender } = render(ui);
    expect(screen.getByRole("button", { name: "Prohlédnout ukázková data" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Vybrat CSV" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Cursor" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Grok Bot" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /openrouter.ai\/activity/ })).toHaveAttribute("href", "https://openrouter.ai/activity");
    expect(screen.getByText(/Soubor bereš z jednoho z těchto tří exportů/)).toBeInTheDocument();
    expect(screen.queryByText(/Ukázka nahoře/)).not.toBeInTheDocument();
    expect(screen.getByText(/E-mail a ID uživatele/)).toBeInTheDocument();
    expect(screen.queryByText(/AI agent & predikce/)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Prohlédnout ukázková data" }));
    expect(onShowSample).toHaveBeenCalledOnce();
    expect(onUpload).not.toHaveBeenCalled();

    await act(async () => {
      await i18n.changeLanguage("en");
    });
    rerender(ui);
    expect(screen.getByRole("button", { name: "Preview sample data" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Choose CSV" })).toBeInTheDocument();
    expect(screen.getByText(/not saved to your spend, budget, billing or sharing/)).toBeInTheDocument();
  });

  it("labels the sample and says budget, billing and sharing are out of it", () => {
    render(<SamplePreviewBanner rows={12} onExit={vi.fn()} onUpload={vi.fn()} />);
    const status = screen.getByRole("status");
    expect(status).toHaveTextContent("Ukázková data, ne tvoje útrata");
    expect(status).toHaveTextContent("12");
    expect(status).toHaveTextContent(/rozpočtu, fakturace ani sdílených dashboardů/);
    expect(screen.getByRole("button", { name: "Zpět bez ukázky" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Nahrát CSV" })).toBeInTheDocument();
  });

  it("explains real Pro value after a stored import, including for an English visitor", async () => {
    const onUpgrade = vi.fn();
    const ui = (
      <FirstImportPanel
        result={{ parsed: 6, saved: 2, failed: 0, skippedTooOld: 4 }}
        isPro={false}
        onDismiss={vi.fn()}
        onUpgrade={onUpgrade}
      />
    );
    const { rerender } = render(ui);
    expect(screen.getByRole("heading", { name: /Import je v\s+účtu/ })).toBeInTheDocument();
    expect(screen.getByText(/Uloženo 2 nových řádků/)).toBeInTheDocument();
    expect(screen.getByText(/4 starších řádků/)).toBeInTheDocument();
    expect(screen.getByText(/Europe\/Prague/)).toBeInTheDocument();
    expect(screen.getByText(/E-mail neposíláme/)).toBeInTheDocument();
    expect(screen.getByText(/CSV se samo neaktualizuje/)).toBeInTheDocument();
    expect(screen.getByText(/vlastním klíči/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Podívat se na Pro" }));
    expect(onUpgrade).toHaveBeenCalledOnce();

    await act(async () => {
      await i18n.changeLanguage("en");
    });
    rerender(ui);
    expect(screen.getByRole("heading", { name: /The import is in your account/ })).toBeInTheDocument();
    expect(screen.getByText(/We do not send email/)).toBeInTheDocument();
    expect(screen.getByText(/does not update itself/)).toBeInTheDocument();
  });
});

describe("sample preview isolation", () => {
  it("hides budget, alerts, exports, sharing and the assistant", () => {
    expect(dashboardChrome(true)).toEqual({
      budget: false,
      alerts: false,
      exports: false,
      sharing: false,
      ai: false,
      planNote: false,
    });
    expect(dashboardChrome(false).budget).toBe(true);
    const index = readFileSync("src/pages/Index.tsx", "utf8");
    for (const gate of ["chrome.budget", "chrome.alerts", "chrome.exports", "chrome.sharing", "chrome.ai", "chrome.planNote"]) {
      expect(index).toContain(gate);
    }
    expect(index).toContain("SamplePreviewBanner");
    expect(index).toContain("FirstImportPanel");
  });

  it("loads the bundled sample without reading or writing the account", async () => {
    stubFetch();
    const { result } = renderHook(() => useDashboardData({ demoMode: true }));
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.samplePreview).toBe(true);
    expect(result.current.data.length).toBeGreaterThan(10);
    expect(fetches.filter((call) => call.includes("/activity"))).toEqual([]);

    let imported: { error?: string; saved: number } = { saved: -1 };
    await act(async () => {
      imported = await result.current.importFile(csvFile("mine.csv", new Date().toISOString()));
    });
    expect(imported.error).toBe("sample_preview");
    expect(imported.saved).toBe(0);
    expect(fetches.filter((call) => call.includes("/activity"))).toEqual([]);
  });

  it("does not import the sample, and drops a file that is entirely outside the free window", async () => {
    stubFetch();
    const { result } = renderHook(() => useDashboardData());
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.hasUserData).toBe(false);
    const reads = fetches.filter((call) => call.includes("/activity"));
    expect(reads.some((call) => call.includes("/activity/import"))).toBe(false);

    act(() => result.current.showSamplePreview());
    expect(result.current.samplePreview).toBe(true);
    expect(result.current.data.length).toBeGreaterThan(10);
    expect(fetches.filter((call) => call.includes("/activity/import"))).toEqual([]);

    const old = new Date(Date.now() - 400 * 86_400_000).toISOString();
    let skipped: { error?: string; saved: number; skippedTooOld?: number } = { saved: -1 };
    await act(async () => {
      skipped = await result.current.importFile(csvFile("old.csv", old));
    });
    expect(skipped.error).toBe("free_window");
    expect(skipped.saved).toBe(0);
    expect(skipped.skippedTooOld).toBe(1);
    expect(result.current.samplePreview).toBe(true);
    expect(fetches.filter((call) => call.includes("/activity/import"))).toEqual([]);

    const recent = new Date(Date.now() - 86_400_000).toISOString();
    let saved: { saved: number; firstRealImport?: boolean; error?: string } = { saved: -1 };
    await act(async () => {
      saved = await result.current.importFile(csvFile("new.csv", recent));
    });
    expect(saved.error).toBeUndefined();
    expect(saved.saved).toBe(1);
    expect(saved.firstRealImport).toBe(true);
    expect(result.current.samplePreview).toBe(false);
    expect(fetches.some((call) => call.includes("/activity/import"))).toBe(true);
  });
});
