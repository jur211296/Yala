import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWTPayload } from "jose";
import type { Env } from "../src/env";
import { makeVerifier } from "../src/auth";

export const ENV: Env = {
  ENVIRONMENT: "staging",
  SUPABASE_URL: "https://proyecto.supabase.co",
  SUPABASE_ANON_KEY: "anon-publica",
  DEFAULT_TIMEZONE: "America/Lima",
};

export const ISSUER = "https://proyecto.supabase.co/auth/v1";
export const USER_A = "11111111-1111-4111-8111-111111111111";

export async function keys() {
  const { publicKey, privateKey } = await generateKeyPair("ES256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "ES256" };
  const jwks = createLocalJWKSet({ keys: [jwk] });
  const sign = (claims: JWTPayload, opts: { issuer?: string; expiresIn?: string } = {}) =>
    new SignJWT(claims)
      .setProtectedHeader({ alg: "ES256", kid: "k1" })
      .setIssuer(opts.issuer ?? ISSUER)
      .setIssuedAt()
      .setExpirationTime(opts.expiresIn ?? "1h")
      .sign(privateKey);
  return { verifier: makeVerifier(ENV, jwks), sign };
}

export const READER_CLAIMS = {
  sub: USER_A,
  role: "yala_mcp_reader",
  aud: "authenticated",
  client_id: "cliente-claude",
  session_id: "sesion-1",
};
