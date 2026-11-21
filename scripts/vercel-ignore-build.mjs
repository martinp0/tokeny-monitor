/**
 * Vercel ignored build step (`ignoreCommand` in vercel.json).
 * Exit 0 skips the build. Exit 1 continues it.
 * https://vercel.com/docs/project-configuration/vercel-json#ignorecommand
 *
 * Same approach as martinp0/svj-monitor and martinp0/profispravcesvj-web.
 *
 * Always builds production and `main`.
 * Skips preview branches under `cursor/` and `dependabot/`.
 * Skips a preview whose diff touches only non-app paths:
 *   ci/, apple/, docs/, and *.md
 * App paths build when changed:
 *   src/, public/, api/, server/, shared/, db/,
 *   package.json and lockfiles, vite.config.*, vercel.json
 * Anything else fails open and builds. A missing diff fails open too.
 * Preview commits whose message contains [skip ci], [ci skip],
 * [skip vercel], or [vercel skip] are skipped.
 */
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const SKIP_TOKEN_RE = /\[skip ci\]|\[ci skip\]|\[skip vercel\]|\[vercel skip\]/i;

const IGNORE_PREFIXES = ["ci/", "apple/", "docs/"];

const APP_PREFIXES = ["src/", "public/", "api/", "server/", "shared/", "db/"];

const PACKAGE_FILES = new Set([
  "package.json",
  "package-lock.json",
  "bun.lock",
  "bun.lockb",
  "pnpm-lock.yaml",
  "yarn.lock",
  "npm-shrinkwrap.json",
]);

export function hasSkipToken(message) {
  return SKIP_TOKEN_RE.test(message ?? "");
}

function normalize(file) {
  return String(file ?? "")
    .replaceAll("\\", "/")
    .replace(/^\.\//, "");
}

/** Paths that never affect the deployed web app. */
export function isIgnoreOnly(file) {
  const f = normalize(file);
  if (!f) return false;
  if (f === "docs" || IGNORE_PREFIXES.some((prefix) => f.startsWith(prefix))) return true;
  return /\.md$/i.test(f);
}

/** Paths that must build when they change. */
export function isAppPath(file) {
  const f = normalize(file);
  if (!f || isIgnoreOnly(f)) return false;
  if (APP_PREFIXES.some((prefix) => f.startsWith(prefix))) return true;
  const base = f.split("/").pop() ?? "";
  if (PACKAGE_FILES.has(base)) return true;
  if (base === "vercel.json" || /^vite\.config\./.test(base)) return true;
  return false;
}

/**
 * True only for the ignore-only set. Other paths, including every app path,
 * are not ignorable: an unknown file fails open and the build runs.
 */
export function isIgnorable(file) {
  return isIgnoreOnly(file);
}

/**
 * @param {{ env: string, ref: string, message: string, files: string[] | null }} input
 * @returns {{ skip: boolean, reason: string }}
 */
export function decide({ env, ref, message, files }) {
  const branch = ref ?? "";
  const environment = env ?? "";

  if (environment === "production" && (branch === "main" || branch === "")) {
    return { skip: false, reason: "Building production on main" };
  }
  if (environment === "production") {
    return { skip: false, reason: `Building production (${branch || "no branch"})` };
  }
  if (branch === "main") {
    return { skip: false, reason: "Building main" };
  }

  if (branch.startsWith("cursor/") || branch.startsWith("dependabot/")) {
    return {
      skip: true,
      reason: `Skipping Vercel preview for ${branch}`,
    };
  }

  if (Array.isArray(files) && files.length > 0 && files.every(isIgnorable)) {
    return {
      skip: true,
      reason: `Skipping Vercel build: only non-app files changed (${files.join(", ")})`,
    };
  }

  if (hasSkipToken(message)) {
    return {
      skip: true,
      reason: "Skipping preview build: commit message contains a skip token",
    };
  }

  return {
    skip: false,
    reason: `Vercel build will run for ${branch || "(no branch)"} (${environment || "unknown env"})`,
  };
}

function isUsableSha(value) {
  return typeof value === "string" && /^[0-9a-f]{7,40}$/i.test(value) && !/^0+$/.test(value);
}

function diffNames(fromRev, toRev) {
  const out = execFileSync("git", ["diff", "--name-only", fromRev, toRev], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
  return out === "" ? [] : out.split("\n");
}

export function listChangedFiles() {
  const sha = (process.env.VERCEL_GIT_COMMIT_SHA ?? "").trim();
  const prev = (process.env.VERCEL_GIT_PREVIOUS_SHA ?? "").trim();
  const attempts = [];
  if (isUsableSha(prev) && isUsableSha(sha) && prev !== sha) {
    attempts.push([prev, sha]);
  }
  attempts.push(["HEAD^", "HEAD"]);

  for (const [fromRev, toRev] of attempts) {
    try {
      return diffNames(fromRev, toRev);
    } catch {
      // Shallow clones may not contain the previous commit. Fail open.
    }
  }
  return null;
}

function isMainModule() {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    return import.meta.url === pathToFileURL(resolve(entry)).href;
  } catch {
    return true;
  }
}

function main() {
  const result = decide({
    env: process.env.VERCEL_ENV ?? "",
    ref: process.env.VERCEL_GIT_COMMIT_REF ?? "",
    message: process.env.VERCEL_GIT_COMMIT_MESSAGE ?? "",
    files: listChangedFiles(),
  });
  console.log(result.reason);
  process.exit(result.skip ? 0 : 1);
}

if (isMainModule()) {
  main();
}
