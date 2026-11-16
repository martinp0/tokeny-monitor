// Builds a private test certificate chain and StoreKit-shaped JWS. The chain is not Apple's.
// Production verification pins Apple Root CA - G3 and rejects these tokens.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { importPKCS8, SignJWT } from "jose";

export interface TestChain {
  rootPem: string;
  /** Sign a payload and return a compact JWS whose x5c chains to `rootPem`. */
  sign(payload: Record<string, unknown>, opts?: { omitOid?: boolean }): Promise<string>;
}

let cached: TestChain | null = null;

export async function testChain(): Promise<TestChain> {
  if (cached) return cached;
  const dir = mkdtempSync(join(tmpdir(), "tokeny-apple-"));
  writeChain(dir);
  const rootPem = readFileSync(join(dir, "root.pem"), "utf8");
  const x5c = ["leaf.pem", "mid.pem", "root.pem"].map((name) => derBase64(dir, name));
  const bareX5c = ["leaf-plain.pem", "mid.pem", "root.pem"].map((name) => derBase64(dir, name));
  const key = await importPKCS8(readFileSync(join(dir, "leaf.pkcs8.pem"), "utf8"), "ES256");
  const bareKey = await importPKCS8(readFileSync(join(dir, "leaf-plain.pkcs8.pem"), "utf8"), "ES256");

  cached = {
    rootPem,
    async sign(payload, opts) {
      const header = opts?.omitOid ? bareX5c : x5c;
      const signingKey = opts?.omitOid ? bareKey : key;
      return await new SignJWT(payload).setProtectedHeader({ alg: "ES256", x5c: header }).sign(signingKey);
    },
  };
  return cached;
}

/** A second root, used to prove a chain that does not match the injected root is rejected. */
export async function foreignRootPem(): Promise<string> {
  const dir = mkdtempSync(join(tmpdir(), "tokeny-apple-foreign-"));
  writeChain(dir);
  return readFileSync(join(dir, "root.pem"), "utf8");
}

function derBase64(dir: string, name: string): string {
  const der = execFileSync("openssl", ["x509", "-in", name, "-outform", "DER"], { cwd: dir });
  return der.toString("base64");
}

function writeChain(dir: string) {
  const cnf = `[req]
distinguished_name = dn
prompt = no
[dn]
CN = Test
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[v3_mid]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
[v3_leaf]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
1.2.840.113635.100.6.11.1 = ASN1:NULL
[v3_leaf_plain]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
`;
  execFileSync("openssl", ["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", "root.key"], { cwd: dir });
  writeFileSync(join(dir, "openssl.cnf"), cnf);
  execFileSync("openssl", ["req", "-new", "-x509", "-key", "root.key", "-sha256", "-days", "3650", "-subj", "/CN=Test Root", "-out", "root.pem", "-config", "openssl.cnf", "-extensions", "v3_ca"], { cwd: dir });
  execFileSync("openssl", ["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", "mid.key"], { cwd: dir });
  execFileSync("openssl", ["req", "-new", "-key", "mid.key", "-subj", "/CN=Test Intermediate", "-out", "mid.csr"], { cwd: dir });
  execFileSync("openssl", ["x509", "-req", "-in", "mid.csr", "-CA", "root.pem", "-CAkey", "root.key", "-sha256", "-days", "3650", "-out", "mid.pem", "-extfile", "openssl.cnf", "-extensions", "v3_mid"], { cwd: dir });
  execFileSync("openssl", ["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", "leaf.key"], { cwd: dir });
  execFileSync("openssl", ["req", "-new", "-key", "leaf.key", "-subj", "/CN=Test Leaf", "-out", "leaf.csr"], { cwd: dir });
  execFileSync("openssl", ["x509", "-req", "-in", "leaf.csr", "-CA", "mid.pem", "-CAkey", "mid.key", "-sha256", "-days", "3650", "-out", "leaf.pem", "-extfile", "openssl.cnf", "-extensions", "v3_leaf"], { cwd: dir });
  execFileSync("openssl", ["pkcs8", "-topk8", "-nocrypt", "-in", "leaf.key", "-out", "leaf.pkcs8.pem"], { cwd: dir });
  execFileSync("openssl", ["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", "leaf-plain.key"], { cwd: dir });
  execFileSync("openssl", ["req", "-new", "-key", "leaf-plain.key", "-subj", "/CN=Test Leaf Plain", "-out", "leaf-plain.csr"], { cwd: dir });
  execFileSync("openssl", ["x509", "-req", "-in", "leaf-plain.csr", "-CA", "mid.pem", "-CAkey", "mid.key", "-sha256", "-days", "3650", "-out", "leaf-plain.pem", "-extfile", "openssl.cnf", "-extensions", "v3_leaf_plain"], { cwd: dir });
  execFileSync("openssl", ["pkcs8", "-topk8", "-nocrypt", "-in", "leaf-plain.key", "-out", "leaf-plain.pkcs8.pem"], { cwd: dir });
}
