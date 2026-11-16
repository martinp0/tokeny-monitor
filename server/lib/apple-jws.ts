// StoreKit 2 and App Store Server Notifications V2 signed payloads.
// Verified locally: ES256 over the JWS, x5c chain up to a pinned root (production: Apple Root CA - G3).
// No App Store Server API call and no ASC API key. Tests inject a different root; this file never reads one from the environment.
import { X509Certificate } from "node:crypto";
import { compactVerify, importX509 } from "jose";

/** Leaf certificate extension Apple puts on App Store signed-data certificates. */
export const APPLE_APP_STORE_OID = "1.2.840.113635.100.6.11.1";

const APPLE_APP_STORE_OID_BYTES = oidBytes(APPLE_APP_STORE_OID);

export type AppleJwsCode =
  | "malformed"
  | "alg"
  | "x5c"
  | "chain"
  | "root"
  | "validity"
  | "oid"
  | "signature"
  | "payload";

export class AppleJwsError extends Error {
  constructor(readonly code: AppleJwsCode) {
    super(code);
    this.name = "AppleJwsError";
  }
}

export interface AppleVerifyConfig {
  /** PEM trust anchors. Production passes Apple Root CA - G3 only. */
  roots: readonly string[];
  /** Certificate validity is checked against this instant. Claim dates are not. */
  now?: Date;
}

/** Verify a StoreKit 2 / ASSN V2 JWS and return the JSON payload. Throws AppleJwsError. */
export async function verifyAppleJws(jws: string, config: AppleVerifyConfig): Promise<Record<string, unknown>> {
  const parts = jws.split(".");
  if (parts.length !== 3 || parts.some((p) => p.length === 0)) throw new AppleJwsError("malformed");
  let header: { alg?: unknown; x5c?: unknown };
  try {
    header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
  } catch {
    throw new AppleJwsError("malformed");
  }
  if (header.alg !== "ES256") throw new AppleJwsError("alg");
  if (!Array.isArray(header.x5c) || header.x5c.length < 2 || header.x5c.length > 3) throw new AppleJwsError("x5c");
  if (!header.x5c.every((c) => typeof c === "string" && c.length > 0 && c.length < 20_000)) throw new AppleJwsError("x5c");

  let certs: X509Certificate[];
  try {
    certs = header.x5c.map((b64) => new X509Certificate(Buffer.from(b64, "base64")));
  } catch {
    throw new AppleJwsError("x5c");
  }

  const now = config.now ?? new Date();
  for (const cert of certs) {
    if (!certCurrentlyValid(cert, now)) throw new AppleJwsError("validity");
  }
  for (let i = 0; i < certs.length - 1; i++) {
    if (!certs[i].verify(certs[i + 1].publicKey)) throw new AppleJwsError("chain");
  }

  let roots: X509Certificate[];
  try {
    roots = config.roots.map((pem) => new X509Certificate(pem));
  } catch {
    throw new AppleJwsError("root");
  }
  if (roots.length === 0 || !chainsToRoot(certs, roots)) throw new AppleJwsError("root");

  const leaf = certs[0];
  if (leaf.ca || !leafHasAppStoreOid(leaf)) throw new AppleJwsError("oid");

  try {
    const key = await importX509(leaf.toString(), "ES256");
    const { payload } = await compactVerify(jws, key);
    const parsed = JSON.parse(new TextDecoder().decode(payload));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new AppleJwsError("payload");
    return parsed as Record<string, unknown>;
  } catch (e) {
    if (e instanceof AppleJwsError) throw e;
    throw new AppleJwsError("signature");
  }
}

function certCurrentlyValid(cert: X509Certificate, now: Date): boolean {
  const from = Date.parse(cert.validFrom);
  const to = Date.parse(cert.validTo);
  const t = now.getTime();
  return !Number.isNaN(from) && !Number.isNaN(to) && from <= t && t <= to;
}

function chainsToRoot(certs: X509Certificate[], roots: X509Certificate[]): boolean {
  const last = certs[certs.length - 1];
  if (roots.some((root) => root.fingerprint256 === last.fingerprint256)) return true;
  return roots.some((root) => last.verify(root.publicKey));
}

/** True when the leaf's v3 extensions contain Apple's App Store signed-data OID. */
export function leafHasAppStoreOid(cert: X509Certificate): boolean {
  try {
    const raw = cert.raw;
    const certSeq = readDer(raw, 0);
    if (certSeq.tag !== 0x30) return false;
    const tbs = readDer(raw, certSeq.valueStart);
    if (tbs.tag !== 0x30) return false;
    let p = tbs.valueStart;
    while (p < tbs.end) {
      const child = readDer(raw, p);
      // extensions [3] EXPLICIT
      if (child.tag === 0xa3 && raw.subarray(child.valueStart, child.end).includes(APPLE_APP_STORE_OID_BYTES)) return true;
      p = child.end;
    }
    return false;
  } catch {
    return false;
  }
}

function readDer(buf: Buffer, offset: number): { tag: number; valueStart: number; end: number } {
  if (offset < 0 || offset >= buf.length) throw new AppleJwsError("x5c");
  const tag = buf[offset];
  let i = offset + 1;
  if (i >= buf.length) throw new AppleJwsError("x5c");
  let len = buf[i++];
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 3 || i + n > buf.length) throw new AppleJwsError("x5c");
    len = 0;
    for (let j = 0; j < n; j++) len = (len << 8) | buf[i++];
  }
  if (len < 0 || i + len > buf.length) throw new AppleJwsError("x5c");
  return { tag, valueStart: i, end: i + len };
}

function oidBytes(oid: string): Buffer {
  const parts = oid.split(".").map((p) => Number(p));
  const bytes = [parts[0] * 40 + parts[1]];
  for (const part of parts.slice(2)) {
    const stack = [part & 0x7f];
    let n = part >> 7;
    while (n > 0) {
      stack.unshift((n & 0x7f) | 0x80);
      n >>= 7;
    }
    bytes.push(...stack);
  }
  return Buffer.from(bytes);
}
