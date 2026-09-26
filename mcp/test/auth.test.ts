import { describe, expect, it } from "vitest";
import { bearer, wwwAuthenticate } from "../src/auth";
import { keys, READER_CLAIMS } from "./helpers";

describe("validación del token de Claude", async () => {
  const { verifier, sign } = await keys();

  it("acepta un token OAuth de solo lectura bien firmado", async () => {
    const r = await verifier(await sign(READER_CLAIMS));
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.token.clientId).toBe("cliente-claude");
      expect(r.token.sub).toBe(READER_CLAIMS.sub);
    }
  });

  it("rechaza un token de la app (sin client_id) aunque la firma sea buena", async () => {
    const { client_id: _, ...appClaims } = READER_CLAIMS;
    const r = await verifier(await sign({ ...appClaims, role: "authenticated" }));
    expect(r).toEqual({ ok: false, reason: "not_oauth_client" });
  });

  it("falla cerrado si el hook no cambió el rol: un token OAuth con role=authenticated puede escribir", async () => {
    const r = await verifier(await sign({ ...READER_CLAIMS, role: "authenticated" }));
    expect(r).toEqual({ ok: false, reason: "not_read_only" });
  });

  it("rechaza emisor ajeno, token caducado, firma ajena y basura", async () => {
    expect((await verifier(await sign(READER_CLAIMS, { issuer: "https://otro.supabase.co/auth/v1" }))).ok).toBe(false);
    expect((await verifier(await sign(READER_CLAIMS, { expiresIn: "-1m" }))).ok).toBe(false);
    const other = await keys();
    expect((await verifier(await other.sign(READER_CLAIMS))).ok).toBe(false);
    expect(await verifier("no.es.jwt")).toEqual({ ok: false, reason: "invalid" });
    expect(await verifier(null)).toEqual({ ok: false, reason: "missing" });
  });

  it("extrae el bearer y arma el WWW-Authenticate con resource_metadata", () => {
    expect(bearer("Bearer abc.def")).toBe("abc.def");
    expect(bearer("Basic x")).toBeNull();
    expect(wwwAuthenticate("https://mcp/.well-known/oauth-protected-resource", "missing")).toBe(
      'Bearer resource_metadata="https://mcp/.well-known/oauth-protected-resource"',
    );
    expect(wwwAuthenticate("https://m", "not_read_only")).toContain('error="invalid_token"');
  });
});
