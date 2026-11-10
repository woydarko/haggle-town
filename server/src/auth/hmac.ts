import { createHmac, timingSafeEqual } from "node:crypto";

const MAX_SKEW_MS = 60_000;

/** Hex HMAC-SHA256 of `${timestamp}.${body}`. The Roblox server signs every request this way. */
export function signHmac(secret: string, timestamp: string, body: string): string {
  return createHmac("sha256", secret).update(`${timestamp}.${body}`).digest("hex");
}

export function verifyHmac(secret: string, timestamp: string, body: string, signature: string, nowMs: number): boolean {
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(nowMs - ts) > MAX_SKEW_MS) return false;
  const want = Buffer.from(signHmac(secret, timestamp, body), "hex");
  const got = Buffer.from(signature, "hex");
  return got.length === want.length && timingSafeEqual(got, want);
}
