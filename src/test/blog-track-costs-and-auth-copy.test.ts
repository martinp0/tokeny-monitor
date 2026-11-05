import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import cs from "@/i18n/cs.json";
import en from "@/i18n/en.json";
import { PUBLIC_ROUTES } from "../../scripts/public-routes.mjs";

const SLUG = "/blog/jak-sledovat-naklady-cursor-a-grok-bot";

describe("blog: jak sledovat náklady na Cursor a Grok Bot", () => {
  it("is prerendered and in the sitemap", () => {
    expect(PUBLIC_ROUTES.some((r: { path: string }) => r.path === SLUG)).toBe(true);
    expect(readFileSync("public/sitemap.xml", "utf8")).toContain(`https://tokeny.martinpohl.cz${SLUG}`);
  });

  it("links CSV import (dashboard), Tokeny and the real-data post; the old post links back", () => {
    const src = readFileSync("src/pages/BlogTrackCursorGrokCosts.tsx", "utf8");
    for (const to of ["/dashboard", "/auth", "/blog/kolik-stoji-ai-agenti"]) expect(src).toContain(`to="${to}"`);
    expect(readFileSync("src/pages/BlogAiAgentCosts.tsx", "utf8")).toContain(SLUG);
    expect(readFileSync("src/App.tsx", "utf8")).toContain(`path="${SLUG}"`);
  });
});

describe("auth copy honesty", () => {
  it("default onboarding copy does not promise Apple", () => {
    expect(cs.landing.how.s1d).not.toMatch(/Apple/);
    expect(en.landing.how.s1d).not.toMatch(/Apple/);
    expect(cs.landing.how.s1dApple).toMatch(/Apple/);
  });

  it("Apple copy and button are gated by VITE_AUTH_APPLE_ENABLED", () => {
    expect(readFileSync("src/lib/auth-providers.ts", "utf8")).toContain('VITE_AUTH_APPLE_ENABLED === "true"');
    expect(readFileSync("src/pages/Landing.tsx", "utf8")).toContain("APPLE_SIGNIN_ENABLED ?");
    expect(readFileSync("src/pages/Auth.tsx", "utf8")).toContain("{APPLE_ENABLED && (");
  });
});
