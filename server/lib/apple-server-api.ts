/**
 * Optional App Store Server API credentials.
 *
 * Tokeny does not call that API. StoreKit JWS and App Store Server Notifications are verified
 * locally (server/lib/apple-jws.ts) and that path does not read these variables. They are
 * accepted only so a later Get Transaction Info call can be turned on without a new secret
 * shape. Leave them unset. Never commit the .p8.
 */
export interface AppleServerApiConfig {
  issuerId: string;
  keyId: string;
  /** PKCS#8 PEM of the App Store Connect API key. Never log this. */
  privateKey: string;
}

export function appleServerApiConfigFrom(env: NodeJS.ProcessEnv = process.env): AppleServerApiConfig | null {
  const issuerId = env.APPLE_ISSUER_ID?.trim() ?? "";
  const keyId = env.APPLE_KEY_ID?.trim() ?? "";
  const privateKey = env.APPLE_PRIVATE_KEY?.trim() ?? "";
  if (!issuerId || !keyId || !privateKey) return null;
  if (!privateKey.includes("BEGIN PRIVATE KEY") && !privateKey.includes("BEGIN EC PRIVATE KEY")) return null;
  return { issuerId, keyId, privateKey };
}
