import { describe, expect, it } from "vitest";
import { invalidTokenChallenge, makeUpstreamVerifier } from "../src/auth";
import { makeEnv } from "./helpers";
import { FakeSupabase, USER_A, USER_B, WORKER_SB_CLIENT } from "./supabase-fake";

const READER = { sub: USER_A.id, role: "yala_mcp_reader", aud: "authenticated", client_id: WORKER_SB_CLIENT, session_id: "ses-1" };

describe("verificación del token de Supabase que guarda el Worker", async () => {
  const sb = await FakeSupabase.create();
  const env = makeEnv();
  const verify = makeUpstreamVerifier(env, sb.jwks);

  it("acepta un token de solo lectura del cliente del Worker, bien firmado", async () => {
    const r = await verify(await sb.sign(READER));
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.claims).toMatchObject({ sub: USER_A.id, sessionId: "ses-1" });
  });

  it("rechaza un token de la app (sin client_id) aunque la firma sea buena", async () => {
    const { client_id: _, ...app } = READER;
    expect(await verify(await sb.sign({ ...app, role: "authenticated" }))).toEqual({ ok: false, reason: "not_worker_client" });
  });

  it("rechaza un token de OTRO cliente OAuth, aunque sea de solo lectura (p. ej. un cliente de la fase 0)", async () => {
    expect(await verify(await sb.sign({ ...READER, client_id: "f5a0fc94-f924-447d-a735-0cefbe085b00" }))).toEqual({
      ok: false,
      reason: "not_worker_client",
    });
  });

  it("falla cerrado si el hook no cambió el rol: role=authenticated puede escribir", async () => {
    expect(await verify(await sb.sign({ ...READER, role: "authenticated" }))).toEqual({ ok: false, reason: "not_read_only" });
  });

  it("sin session_id no se podría comprobar que sigue viva: fuera", async () => {
    const { session_id: _, ...sinSesion } = READER;
    expect(await verify(await sb.sign(sinSesion))).toEqual({ ok: false, reason: "no_session" });
  });

  it("un refresh no puede cambiar de usuario", async () => {
    expect(await verify(await sb.sign(READER), USER_B.id)).toEqual({ ok: false, reason: "wrong_user" });
    expect((await verify(await sb.sign(READER), USER_A.id)).ok).toBe(true);
  });

  it("rechaza emisor ajeno, token caducado, firma ajena y basura", async () => {
    const other = await FakeSupabase.create();
    expect((await verify(await sb.sign(READER, Math.floor(Date.now() / 1000) - 60))).ok).toBe(false);
    expect((await verify(await other.sign(READER))).ok).toBe(false);
    expect(await verify("no.es.jwt")).toEqual({ ok: false, reason: "invalid" });
    const foreignIssuer = makeUpstreamVerifier(makeEnv({ SUPABASE_URL: "https://otro.supabase.co" }), sb.jwks);
    expect((await foreignIssuer(await sb.sign(READER))).ok).toBe(false);
  });

  it("sin cliente configurado no acepta nada (falla cerrado)", async () => {
    const sinCliente = makeUpstreamVerifier(makeEnv({ SUPABASE_OAUTH_CLIENT_ID: "" }), sb.jwks);
    expect(await sinCliente(await sb.sign({ ...READER, client_id: "" }))).toEqual({ ok: false, reason: "not_worker_client" });
  });

  it("el reto del 401 apunta a los metadatos del recurso y solo lleva ASCII", () => {
    const h = invalidTokenChallenge(env, 'El acceso a Yala se retiró "ya"');
    expect(h).toContain('resource_metadata="https://mcp.yala.test/.well-known/oauth-protected-resource/mcp"');
    expect(h).toContain('error="invalid_token"');
    expect(h).toContain('error_description="El acceso a Yala se retir ya"');
    expect(/^[\x20-\x7e]*$/.test(h)).toBe(true);
  });
});
