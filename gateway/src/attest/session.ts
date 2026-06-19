import { SignJWT, jwtVerify } from "jose";
import type { Env } from "../env";

/** Token de sesión corto: el cliente lo adjunta como Bearer en cada request al proxy. */
const SESSION_TTL_SECONDS = 15 * 60;

export type Tier = "pro" | "free";

export interface SessionClaims {
  keyId: string;
  tier: Tier;
}

function signingKey(env: Env): Uint8Array {
  return new TextEncoder().encode(env.JWT_SIGNING_SECRET);
}

export async function issueSessionToken(env: Env, claims: SessionClaims): Promise<{ token: string; expMs: number }> {
  const nowSec = Math.floor(Date.now() / 1000);
  const token = await new SignJWT({ tier: claims.tier })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.keyId)
    .setIssuedAt(nowSec)
    .setExpirationTime(nowSec + SESSION_TTL_SECONDS)
    .sign(signingKey(env));
  return { token, expMs: (nowSec + SESSION_TTL_SECONDS) * 1000 };
}

export async function verifySessionToken(env: Env, token: string): Promise<SessionClaims | null> {
  try {
    const { payload } = await jwtVerify(token, signingKey(env));
    const keyId = typeof payload.sub === "string" ? payload.sub : "";
    if (!keyId) return null;
    return { keyId, tier: payload.tier === "pro" ? "pro" : "free" };
  } catch {
    return null;
  }
}
