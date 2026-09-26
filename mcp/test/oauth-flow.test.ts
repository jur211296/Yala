import { jwtPayload } from "./b64";
import { afterEach, describe, expect, it, vi } from "vitest";
import { isAllowedEgress } from "../src/egress";
import { GRANT_MAX_AGE_SECONDS } from "../src/tokens";
import { BASE, callTool, connect, INIT, looksLikeJwt, refresh, register, RESOURCE, rpc, world } from "./helpers";
import { USER_A, USER_B } from "./supabase-fake";

afterEach(() => {
  vi.useRealTimers();
});

describe("descubrimiento: el servidor OAuth de Claude es el Worker", () => {
  it("publica los metadatos del recurso y del servidor, con PKCE solo S256 y revocación", async () => {
    const w = await world();
    const prm = await w.call(`${BASE}/.well-known/oauth-protected-resource/mcp`);
    expect(prm.status).toBe(200);
    expect(await prm.json()).toMatchObject({ resource: RESOURCE, authorization_servers: [BASE], scopes_supported: ["lectura"] });

    const as = (await (await w.call(`${BASE}/.well-known/oauth-authorization-server`)).json()) as Record<string, unknown>;
    expect(as).toMatchObject({
      issuer: BASE,
      authorization_endpoint: `${BASE}/authorize`,
      token_endpoint: `${BASE}/oauth/token`,
      registration_endpoint: `${BASE}/oauth/register`,
      revocation_endpoint: `${BASE}/oauth/token`,
      code_challenge_methods_supported: ["S256"],
    });
    expect(as.client_id_metadata_document_supported).toBe(false);
  });

  it("sin token, /mcp responde 401 con WWW-Authenticate que apunta a los metadatos", async () => {
    const w = await world();
    const res = await rpc(w, null, INIT);
    expect(res.status).toBe(401);
    expect(res.headers.get("WWW-Authenticate")).toContain(`resource_metadata="${BASE}/.well-known/oauth-protected-resource/mcp"`);
  });

  it("un token de Supabase (el de la fase 0) ya no abre /mcp", async () => {
    const w = await world();
    const supabaseToken = await w.supabase.sign({ sub: USER_A.id, role: "yala_mcp_reader", client_id: "x", session_id: "s" });
    const res = await rpc(w, supabaseToken, INIT);
    expect(res.status).toBe(401);
    expect(w.supabase.calls).toEqual([]);
  });
});

describe("registro dinámico en el Worker", () => {
  it("acepta las vueltas de Claude y rechaza cualquier otra, aunque venga mezclada", async () => {
    const w = await world();
    expect((await register(w, ["http://localhost:1234/callback"])).res.status).toBe(201);
    expect((await register(w, ["https://claude.ai/api/mcp/auth_callback"])).res.status).toBe(201);
    for (const uris of [["https://evil.example/cb"], ["https://claude.ai/api/mcp/auth_callback", "https://evil.example/cb"]]) {
      const { res, body } = await register(w, uris);
      expect(res.status, JSON.stringify(uris)).toBe(400);
      expect(body.error).toBe("invalid_redirect_uri");
    }
    // Sin vueltas lo rechaza ya la librería, antes de la política.
    expect((await register(w, [])).res.status).toBe(400);
  });
});

describe("lo que recibe Claude no sirve fuera del Worker", () => {
  it("la respuesta de token no lleva nada de Supabase: ni JWTs ni el refresh", async () => {
    const w = await world();
    const { tokens, raw } = await connect(w);
    expect(Object.keys(tokens).sort()).toEqual(["access_token", "expires_in", "refresh_token", "resource", "scope", "token_type"]);
    expect(looksLikeJwt(tokens.access_token)).toBe(false);
    expect(looksLikeJwt(tokens.refresh_token)).toBe(false);
    expect(raw).not.toMatch(/eyJ[\w-]+\.[\w-]+\./);
    const upstream = w.supabase.oauthSessions(USER_A.id)[0]!;
    expect(raw).not.toContain(upstream.refresh);
    expect(tokens.resource).toBe(RESOURCE);
    expect(tokens.scope).toBe("lectura");
    // El access de Claude caduca un minuto antes que el de Supabase (1 h), menos lo que tardó el baile.
    expect(tokens.expires_in).toBeGreaterThanOrEqual(3530);
    expect(tokens.expires_in).toBeLessThanOrEqual(3540);
  });

  it("el KV no guarda ni el token de Claude ni el de Supabase en claro", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    const upstream = w.supabase.oauthSessions(USER_A.id)[0]!;
    const dump = JSON.stringify([...w.kv.store.entries()]);
    expect(dump).not.toContain(tokens.access_token.split(":")[2]);
    expect(dump).not.toContain(tokens.refresh_token.split(":")[2]);
    expect(dump).not.toContain(upstream.refresh);
    expect(dump).not.toMatch(/eyJ[\w-]+\.[\w-]+\./);
    expect(dump).not.toContain(USER_A.email);
  });

  it("todo lo que el Worker pidió a Supabase en el baile y al leer cabe en la lista cerrada", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    w.supabase.rows = { categories: [], subcategories: [] };
    await callTool(w, tokens.access_token, "listar_categorias");
    await refresh(w, (await register(w)).body.client_id!, tokens.refresh_token); // cliente equivocado: no sale nada
    for (const c of w.supabase.calls) {
      expect(isAllowedEgress(w.env, c.method, new URL(`https://proyecto.supabase.co${c.path}${c.search}`)), `${c.method} ${c.path}`).toBe(true);
      expect(c.method === "PUT" || c.method === "PATCH" || c.method === "DELETE").toBe(false);
    }
  });

  it("scope: Claude pide de más y solo recibe «lectura»", async () => {
    const w = await world();
    const { tokens } = await connect(w, USER_A, { scope: "lectura escritura admin" });
    expect(tokens.scope).toBe("lectura");
  });
});

describe("/mcp con el token del Worker", () => {
  it("lee con la sesión de SUPABASE de solo lectura, no con el token de Claude, y comprueba antes que sigue viva", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    w.supabase.rows = { categories: [{ sync_id: "c1", name: "Comida", is_income: false, is_visible: true, sort_order: 1 }], subcategories: [] };
    const before = w.supabase.calls.length;
    const { body } = await callTool(w, tokens.access_token, "listar_categorias");
    expect(body?.result.isError).toBeFalsy();
    const calls = w.supabase.calls.slice(before);
    expect(calls[0]).toMatchObject({ method: "GET", path: "/auth/v1/user" });
    const reads = calls.filter((c) => c.path.startsWith("/rest/v1/"));
    expect(reads.length).toBeGreaterThan(0);
    for (const c of calls) {
      expect(c.auth).not.toContain(tokens.access_token);
      expect(looksLikeJwt(c.auth!.replace("Bearer ", ""))).toBe(true);
    }
  });

  it("GET y DELETE en /mcp dan 405: sin estado no hay stream SSE que reabrir", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    for (const method of ["GET", "DELETE"]) {
      const res = await w.call(`${BASE}/mcp`, { method, headers: { Authorization: `Bearer ${tokens.access_token}`, Accept: "text/event-stream" } });
      expect(res.status).toBe(405);
    }
  });

  it("B no ve la conexión de A: cada token lleva la sesión de su usuario", async () => {
    const w = await world();
    const a = await connect(w, USER_A);
    const b = await connect(w, USER_B);
    w.supabase.rows = { categories: [], subcategories: [] };
    await callTool(w, b.tokens.access_token, "listar_categorias");
    const bRead = w.supabase.calls.filter((c) => c.path.startsWith("/rest/v1/")).at(-1)!;
    const bSession = w.supabase.oauthSessions(USER_B.id)[0]!;
    const payload = jwtPayload(bRead.auth!.replace("Bearer ", ""));
    expect(payload.sub).toBe(USER_B.id);
    expect(payload.session_id).toBe(bSession.id);
    expect(a.tokens.access_token.startsWith(USER_A.id)).toBe(true);
  });
});

describe("revocar corta al momento", () => {
  it("desde Supabase (el permiso de la cuenta): la siguiente llamada da 401 y la conexión desaparece", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    w.supabase.revokeOAuthSessions(USER_A.id);
    const { res } = await callTool(w, tokens.access_token, "listar_categorias");
    expect(res.status).toBe(401);
    expect(res.headers.get("WWW-Authenticate")).toContain('error="invalid_token"');
    expect(w.supabase.calls.some((c) => c.path.startsWith("/rest/v1/"))).toBe(false);
    // Y no se puede refrescar: el grant ya no existe.
    const r = await refresh(w, clientId, tokens.refresh_token);
    expect(r.res.status).toBe(400);
    expect(r.body.error).toBe("invalid_grant");
  });

  it("desde Claude (RFC 7009 con el refresh): el access token deja de servir", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    const rev = await w.call(`${BASE}/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ token: tokens.refresh_token, token_type_hint: "refresh_token", client_id: clientId }),
    });
    expect(rev.status).toBe(200);
    expect((await rpc(w, tokens.access_token, INIT)).status).toBe(401);
  });

  it("si GoTrue no reconoce el JWT (p. ej. caducó), 401 pero la conexión sigue: el refresh decide", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    w.supabase.userEndpoint = { status: 403, code: "bad_jwt" };
    expect((await callTool(w, tokens.access_token, "listar_categorias")).res.status).toBe(401);
    w.supabase.userEndpoint = undefined;
    expect((await refresh(w, clientId, tokens.refresh_token)).res.status).toBe(200);
  });

  it("si no se puede preguntar a Supabase, 503 sin leer nada y sin borrar la conexión", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    w.supabase.userEndpoint = { status: 500 };
    const { res } = await callTool(w, tokens.access_token, "listar_categorias");
    expect(res.status).toBe(503);
    expect(res.headers.get("Retry-After")).toBe("30");
    expect(w.supabase.calls.some((c) => c.path.startsWith("/rest/v1/"))).toBe(false);
    w.supabase.userEndpoint = undefined;
    w.supabase.rows = { categories: [], subcategories: [] };
    expect((await callTool(w, tokens.access_token, "listar_categorias")).res.status).toBe(200);
  });
});

describe("rotación y caducidad", () => {
  it("el refresh de Claude rota también el de Supabase, en la misma escritura, y lee con el access nuevo", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    const s = w.supabase.oauthSessions(USER_A.id)[0]!;
    const firstRefresh = s.refresh;
    const r = await refresh(w, clientId, tokens.refresh_token);
    expect(r.res.status).toBe(200);
    expect(r.body.refresh_token).not.toBe(tokens.refresh_token);
    expect(s.previousRefresh).toBe(firstRefresh);
    const refreshCall = w.supabase.calls.filter((c) => c.path === "/auth/v1/oauth/token").at(-1)!;
    expect(new URLSearchParams(refreshCall.body).get("refresh_token")).toBe(firstRefresh);
    expect(refreshCall.auth).toMatch(/^Basic /);

    w.supabase.rows = { categories: [], subcategories: [] };
    await callTool(w, r.body.access_token!, "listar_categorias");
    // Un segundo refresh usa el refresh de Supabase NUEVO: si usara el viejo, Supabase revocaría la sesión (reúso).
    const r2 = await refresh(w, clientId, r.body.refresh_token!);
    expect(r2.res.status).toBe(200);
    expect(w.supabase.oauthSessions(USER_A.id)).toHaveLength(1);
  });

  it("reintentar con el refresh anterior (respuesta perdida) usa el refresh de Supabase actual, no el gastado", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    const r1 = await refresh(w, clientId, tokens.refresh_token);
    expect(r1.res.status).toBe(200);
    const retry = await refresh(w, clientId, tokens.refresh_token);
    expect(retry.res.status).toBe(200);
    expect(w.supabase.oauthSessions(USER_A.id)).toHaveLength(1);
  });

  it("Supabase rechaza el refresh (revocado o reusado): invalid_grant y la conexión se borra", async () => {
    const w = await world();
    const { tokens, clientId } = await connect(w);
    w.supabase.failRefresh = { status: 400, code: "refresh_token_not_found" };
    const r = await refresh(w, clientId, tokens.refresh_token);
    expect(r.res.status).toBe(400);
    expect(r.body.error).toBe("invalid_grant");
    w.supabase.failRefresh = undefined;
    expect((await refresh(w, clientId, tokens.refresh_token)).body.error).toBe("invalid_grant");
    expect((await rpc(w, tokens.access_token, INIT)).status).toBe(401);
  });

  it("Supabase caído o el Worker mal configurado: temporarily_unavailable y la conexión se conserva", async () => {
    for (const fail of [
      { status: 503, code: "http_503" },
      { status: 400, code: "invalid_client" },
    ]) {
      const w = await world();
      const { tokens, clientId } = await connect(w);
      w.supabase.failRefresh = fail;
      const r = await refresh(w, clientId, tokens.refresh_token);
      expect(r.res.status, JSON.stringify(fail)).toBe(503);
      expect(r.body.error).toBe("temporarily_unavailable");
      w.supabase.failRefresh = undefined;
      expect((await refresh(w, clientId, tokens.refresh_token)).res.status).toBe(200);
    }
  });

  it("si al refrescar el token vuelve de otro rol o de otro cliente, se borra la conexión (falla cerrado)", async () => {
    for (const tweak of [
      (w: Awaited<ReturnType<typeof world>>) => (w.supabase.roleForOAuth = "authenticated"),
      (w: Awaited<ReturnType<typeof world>>) => (w.supabase.clientIdInToken = "otro"),
    ]) {
      const w = await world();
      const { tokens, clientId } = await connect(w);
      tweak(w);
      const r = await refresh(w, clientId, tokens.refresh_token);
      expect(r.body.error).toBe("invalid_grant");
      expect((await rpc(w, tokens.access_token, INIT)).status).toBe(401);
    }
  });

  it("a los 90 días de autorizar hay que volver a conectar, aunque se use cada día", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const t0 = new Date("2026-10-01T12:00:00Z");
    vi.setSystemTime(t0);
    const w = await world();
    const { tokens, clientId } = await connect(w);
    let rt = tokens.refresh_token;
    for (const day of [29, 58, 87]) {
      vi.setSystemTime(new Date(t0.getTime() + day * 86_400_000));
      const r = await refresh(w, clientId, rt);
      expect(r.res.status, `día ${day}`).toBe(200);
      rt = r.body.refresh_token!;
    }
    // 30 s antes de los 90 días: le quedan < 60 s, así que se corta.
    vi.setSystemTime(new Date(t0.getTime() + (GRANT_MAX_AGE_SECONDS - 30) * 1000));
    const late = await refresh(w, clientId, rt);
    expect(late.body.error).toBe("invalid_grant");
  });

  it("sin usarla 30 días, la conexión caduca sola", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const t0 = new Date("2026-10-01T12:00:00Z");
    vi.setSystemTime(t0);
    const w = await world();
    const { tokens, clientId } = await connect(w);
    vi.setSystemTime(new Date(t0.getTime() + 31 * 86_400_000));
    expect((await refresh(w, clientId, tokens.refresh_token)).body.error).toBe("invalid_grant");
  });
});
