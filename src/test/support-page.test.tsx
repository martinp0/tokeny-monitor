import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { HelmetProvider } from "react-helmet-async";
import { MemoryRouter } from "react-router-dom";
import { readFileSync } from "node:fs";
import i18n from "@/i18n";
import cs from "@/i18n/cs.json";
import en from "@/i18n/en.json";
import Support from "@/pages/Support";
import { PRICING, PRO_TRIAL_DAYS } from "@/config/pricing";
import { buildSitemap, PUBLIC_ROUTES } from "../../scripts/public-routes.mjs";

const SITE = "https://tokeny.martinpohl.cz";

beforeEach(() => {
  vi.stubGlobal("requestAnimationFrame", (cb: FrameRequestCallback) => {
    cb(0);
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function renderAt(path: string) {
  render(
    <HelmetProvider>
      <MemoryRouter initialEntries={[path]}>
        <Support />
      </MemoryRouter>
    </HelmetProvider>,
  );
}

function headHtml() {
  return `${document.documentElement.outerHTML.match(/^<html[^>]*>/)?.[0] ?? ""}\n${document.head.innerHTML}`;
}

describe("support page routes", () => {
  it("prerenders /support and /en/support with reciprocal hreflang", () => {
    const paths = PUBLIC_ROUTES.map((route: { path: string }) => route.path);
    expect(paths).toContain("/support");
    expect(paths).toContain("/en/support");
    expect(paths.filter((path: string) => path.endsWith("/support"))).toEqual(["/support", "/en/support"]);

    const xml = buildSitemap();
    expect(readFileSync("public/sitemap.xml", "utf8")).toBe(xml);
    for (const path of ["/support", "/en/support"]) {
      expect(xml).toContain(`<loc>${SITE}${path}</loc>`);
      expect(xml).toContain(`hreflang="cs" href="${SITE}/support"`);
      expect(xml).toContain(`hreflang="en" href="${SITE}/en/support"`);
      expect(xml).toContain(`hreflang="x-default" href="${SITE}/support"`);
    }
    expect(readFileSync("src/App.tsx", "utf8")).toContain('path="/support"');
    expect(readFileSync("src/App.tsx", "utf8")).toContain('path="/en/support"');
    expect(readFileSync("src/pages/Landing.tsx", "utf8")).toContain('"/en/support" : "/support"');
  });

  it("renders Czech at /support with the published contact and no phone number", () => {
    renderAt("/support");
    const head = headHtml();
    expect(document.title).toBe("Podpora | Tokeny");
    expect(head).toContain('lang="cs"');
    expect(head).toContain(`rel="canonical" href="${SITE}/support"`);
    expect(head).toContain(`hreflang="cs" href="${SITE}/support"`);
    expect(head).toContain(`hreflang="en" href="${SITE}/en/support"`);
    expect(head).toContain(`hreflang="x-default" href="${SITE}/support"`);
    expect(head).toContain(`property="og:url" content="${SITE}/support"`);

    const terms = readFileSync("src/pages/Terms.tsx", "utf8");
    const email = terms.match(/const EMAIL = "([^"]+)"/)?.[1];
    expect(email).toBe("hello@martinpohl.cz");
    const mail = screen.getAllByRole("link", { name: email! });
    expect(mail.length).toBeGreaterThan(0);
    expect(mail[0]).toHaveAttribute("href", `mailto:${email}`);
    expect(screen.getByText(/IČO 17256712/)).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: "Podpora" })).toBeInTheDocument();
    expect(screen.getByText(cs.importSources.items[0].body)).toBeInTheDocument();
    expect(screen.getByText(/bude brzy/)).toBeInTheDocument();
    expect(screen.getByText(/Smazat účet/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "zásadách ochrany osobních údajů" })).toHaveAttribute("href", "/privacy");
    expect(screen.getByText(new RegExp(`${PRICING.pro.monthly} Kč`))).toBeInTheDocument();
    expect(screen.getByText(new RegExp(`${PRICING.pro.yearly} Kč`))).toBeInTheDocument();
    if (PRO_TRIAL_DAYS > 0) expect(screen.getByText(new RegExp(`${PRO_TRIAL_DAYS} dní`))).toBeInTheDocument();
    expect(screen.getByText(/zákaznický portál Stripe/)).toBeInTheDocument();
    expect(document.body.textContent ?? "").not.toMatch(/\+420|217\s*217\s*482/);
    expect(document.body.innerHTML).not.toMatch(/\.apk/i);
  });

  it("renders English at /en/support, including coming soon for the APK", () => {
    renderAt("/en/support");
    const head = headHtml();
    expect(document.title).toBe("Support | Tokeny");
    expect(head).toContain('lang="en"');
    expect(head).toContain(`rel="canonical" href="${SITE}/en/support"`);
    expect(head).toContain(`hreflang="en" href="${SITE}/en/support"`);
    expect(screen.getByRole("heading", { level: 1, name: "Support" })).toBeInTheDocument();
    expect(screen.getByText(en.importSources.items[0].body)).toBeInTheDocument();
    expect(screen.getByText(/coming soon/)).toBeInTheDocument();
    expect(screen.getByText(/Delete account/)).toBeInTheDocument();
    expect(screen.getByText(/Open a usage CSV/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "privacy policy" })).toHaveAttribute("href", "/privacy");
    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Česky" })).toHaveAttribute("href", "/support");
    expect(document.body.textContent ?? "").not.toMatch(/\+420|217\s*217\s*482/);
  });
});
