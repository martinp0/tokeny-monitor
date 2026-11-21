import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import i18n from "@/i18n";
import { api } from "@/lib/api";
import { InsightsPanel } from "@/components/dashboard/InsightsPanel";

vi.mock("@/lib/api", () => ({ api: vi.fn() }));

const priced = {
  plan: "free" as const,
  amounts: "range" as const,
  cache_hit_rate: 0.04,
  window: { from: "2026-11-01", to: "2026-11-17" },
  truncated: false,
  model_mix: [{
    model: "anthropic/claude-opus-4-6", provider: "anthropic", share: 1, requests: 40, tokens: 2_020_000,
    cache_hit_rate: 0, cost: { kind: "range", low_usd: 20, high_usd: 100, low_czk: 470, high_czk: 2350 },
    cost_basis: "billed", price_source: null,
  }],
  groups: [{ kind: "api_key" as const, label: "key_…abcd", share: 1, requests: 40, cost: null }],
  tips: [{
    id: "cheaper-1",
    kind: "cheaperModel",
    explanation: "claude-opus-4-6 to claude-sonnet-5-5. List price 5 / 25 vs 2 / 10 USD per million tokens (input / output).",
    saving: { kind: "range", low_usd: 20, high_usd: 100, low_czk: 470, high_czk: 2350 },
    observed: null,
    price_source: "https://platform.claude.com/docs/en/about-claude/pricing",
    price_checked: "2026-11-17",
    basis: "billed",
  }],
};

afterEach(() => {
  cleanup();
  vi.mocked(api).mockReset();
});

describe("InsightsPanel", () => {
  it("shows the server explanation and a savings range, not an exact dollar figure", async () => {
    await i18n.changeLanguage("en");
    vi.mocked(api).mockResolvedValue(priced);
    render(<InsightsPanel />);
    expect(await screen.findByText(/claude-opus-4-6 to claude-sonnet-5-5/)).toBeTruthy();
    expect(screen.getByText("Ways to spend less")).toBeTruthy();
    const text = document.body.textContent ?? "";
    expect(text).toContain("470");
    expect(text).toMatch(/2[\s\u00a0\u202f]?350/);
    expect(text).not.toContain("$24");
    expect(screen.getByText("key_…abcd")).toBeTruthy();
    expect(screen.getByRole("link", { name: "2026-11-17" }).getAttribute("href")).toContain("platform.claude.com");
    expect(vi.mocked(api).mock.calls[0][0]).toContain("/insights?tz=Europe/Prague&lang=en");
  });

  it("shows an error when the request fails", async () => {
    await i18n.changeLanguage("en");
    vi.mocked(api).mockRejectedValue(new Error("nope"));
    render(<InsightsPanel />);
    expect(await screen.findByText("Could not load insights.")).toBeTruthy();
  });
});
