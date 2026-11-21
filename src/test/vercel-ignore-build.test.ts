import { describe, expect, it } from "vitest";
import { decide, hasSkipToken, isAppPath, isIgnorable } from "../../scripts/vercel-ignore-build.mjs";

const APP_FILES = [
  "src/App.tsx",
  "src/test/plan.test.ts",
  "public/favicon.png",
  "api/index.ts",
  "server/app.ts",
  "shared/pricing/model-prices.json",
  "db/schema.sql",
  "package.json",
  "bun.lock",
  "package-lock.json",
  "vite.config.ts",
  "vite.config.mjs",
  "vercel.json",
];

const IGNORE_FILES = [
  "ci/github-actions-ci.yml",
  "ci/vercel-redirect-pohl-uk.json",
  "apple/iOS/DashboardView.swift",
  "apple/README.md",
  "docs/insights.md",
  "docs/screenshots/after-landing-desktop-light.jpg",
  "docs",
  "README.md",
  "CLAUDE.md",
  "shared/pricing/model-prices.sources.md",
  "android/README.md",
];

describe("vercel ignore build paths", () => {
  it("builds when an app path changes", () => {
    for (const file of APP_FILES) {
      expect(isAppPath(file), file).toBe(true);
      expect(isIgnorable(file), file).toBe(false);
    }
  });

  it("ignores only ci, apple, docs, and markdown", () => {
    for (const file of IGNORE_FILES) {
      expect(isIgnorable(file), file).toBe(true);
      expect(isAppPath(file), file).toBe(false);
    }
  });

  it("fails open for other paths", () => {
    for (const file of ["index.html", "tailwind.config.ts", "android/app/build.gradle.kts", "scripts/prerender.mjs", "eslint.config.js"]) {
      expect(isIgnorable(file), file).toBe(false);
      expect(isAppPath(file), file).toBe(false);
    }
  });
});

describe("vercel ignore build decision", () => {
  it("always builds production on main, including docs-only and skip tokens", () => {
    for (const files of [["docs/insights.md"], ["src/App.tsx"], [] as string[], null]) {
      expect(decide({ env: "production", ref: "main", message: "docs [skip vercel]", files }).skip).toBe(false);
      expect(decide({ env: "production", ref: "main", message: "docs [skip vercel]", files }).reason).toBe(
        "Building production on main",
      );
    }
    expect(decide({ env: "production", ref: "", message: "", files: ["apple/README.md"] }).skip).toBe(false);
    expect(decide({ env: "production", ref: "cursor/foo-fd65", message: "[skip vercel]", files: ["README.md"] }).skip).toBe(
      false,
    );
  });

  it("builds main even when the environment is not production", () => {
    expect(decide({ env: "preview", ref: "main", message: "[skip vercel]", files: ["docs/ideas.md"] }).skip).toBe(false);
  });

  it("skips cursor and dependabot preview branches even when app files change", () => {
    const files = ["src/App.tsx", "vercel.json"];
    expect(decide({ env: "preview", ref: "cursor/vercel-ignore-build-fd65", message: "app change", files }).skip).toBe(true);
    expect(decide({ env: "preview", ref: "dependabot/npm_and_yarn/hono-4", message: "bump", files }).skip).toBe(true);
    expect(decide({ env: "preview", ref: "cursor", message: "app change", files }).skip).toBe(false);
  });

  it("skips a preview whose diff is only non-app paths", () => {
    const only = decide({
      env: "preview",
      ref: "feature/docs",
      message: "Document the cron",
      files: ["docs/insights.md", "apple/README.md", "ci/github-actions-ci.yml", "CLAUDE.md"],
    });
    expect(only.skip).toBe(true);

    const mixed = decide({
      env: "preview",
      ref: "feature/docs",
      message: "Document and ship",
      files: ["docs/insights.md", "server/app.ts"],
    });
    expect(mixed.skip).toBe(false);
  });

  it("builds a preview when the diff is unknown, empty, or includes an uncategorized file", () => {
    expect(decide({ env: "preview", ref: "feature/x", message: "work", files: null }).skip).toBe(false);
    expect(decide({ env: "preview", ref: "feature/x", message: "work", files: [] }).skip).toBe(false);
    expect(decide({ env: "preview", ref: "feature/x", message: "work", files: ["index.html"] }).skip).toBe(false);
  });

  it("skips other previews when the commit message has a skip token", () => {
    expect(hasSkipToken("Add the filter [skip vercel]")).toBe(true);
    expect(hasSkipToken("chore: deps [ci skip]")).toBe(true);
    expect(hasSkipToken("ship the dashboard")).toBe(false);
    expect(
      decide({ env: "preview", ref: "feature/x", message: "Add the filter [skip vercel]", files: ["vercel.json"] }).skip,
    ).toBe(true);
    expect(decide({ env: "preview", ref: "feature/x", message: "ship it", files: ["src/App.tsx"] }).skip).toBe(false);
  });
});
