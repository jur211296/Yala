/**
 * «Conecta tu IA»: la app lista y quita sus IA conectadas (`src/connections.ts`), con su sesión normal de la nube.
 * Lo que se fija: solo la app entra (nunca el token de una IA, ni uno de Supabase con `client_id`), cada usuario ve y
 * borra solo lo suyo, y desconectar deja a la IA sin acceso al momento.
 */
import type { GrantSummary, OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import { describe, expect, it } from "vitest";
import { checkAppClaims, describeGrant } from "../../src/connections";
import { ipBucketFor } from "../../src/ratelimit";
import { BASE, connect, grantCount, INIT, refresh, rpc, world, type World } from "../helpers";
import { USER_A, USER_B } from "../supabase-fake";

/** El token de la app: el que Supabase da a un inicio de sesión normal (sin cliente OAuth). */
function appToken(w: World, sub = USER_A.id, extra: Record<string, unknown> = {}) {
  return w.supabase.sign({ sub, aud: "authenticated", role: "authenticated", session_id: "ses_app", ...extra });
}

function list(w: World, token: string | null) {
  return w.call(`${BASE}/connections`, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
}

function remove(w: World, token: string | null, id: string) {
  return w.call(`${BASE}/connections/${id}`, { method: "DELETE", headers: token ? { Authorization: `Bearer ${token}` } : {} });
}

interface Row {
  id: string;
  ia: string | null;
  vuelta: string | null;
  local: boolean;
  conectadaEl: number;
}

describe("GET /connections", () => {
  it("lista la IA conectada con su nombre, su vuelta y la fecha, sin tokens", async () => {
    const w = await world();
    await connect(w);
    const res = await list(w, await appToken(w));
    expect(res.status).toBe(200);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    const raw = await res.text();
    const { conexiones } = JSON.parse(raw) as { conexiones: Row[] };
    expect(conexiones).toHaveLength(1);
    expect(conexiones[0]).toMatchObject({ ia: "Claude", vuelta: "localhost", local: true });
    expect(conexiones[0]!.conectadaEl).toBeGreaterThan(1_700_000_000);
    expect(Object.keys(conexiones[0]!).sort()).toEqual(["conectadaEl", "ia", "id", "local", "vuelta"]);
    // Ni el nombre que eligió el cliente ni nada que parezca un token.
    expect(raw).not.toContain("yala-staging");
    expect(raw).not.toMatch(/eyJ|rt_|ses_/);
  });

  it("sin conexiones, lista vacía", async () => {
    const w = await world();
    const res = await list(w, await appToken(w));
    expect(await res.json()).toEqual({ conexiones: [] });
  });

  it("cada usuario ve solo las suyas", async () => {
    const w = await world();
    await connect(w, USER_A);
    await connect(w, USER_B);
    const a = (await (await list(w, await appToken(w, USER_A.id))).json()) as { conexiones: Row[] };
    const b = (await (await list(w, await appToken(w, USER_B.id))).json()) as { conexiones: Row[] };
    expect(a.conexiones).toHaveLength(1);
    expect(b.conexiones).toHaveLength(1);
    expect(a.conexiones[0]!.id).not.toBe(b.conexiones[0]!.id);
  });
});

describe("quién puede llamar", () => {
  it("sin token, 401", async () => {
    const w = await world();
    const res = await list(w, null);
    expect(res.status).toBe(401);
    expect(res.headers.get("WWW-Authenticate")).toContain("Bearer");
  });

  it("el token que el Worker le da a la IA no sirve", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    expect((await list(w, tokens.access_token)).status).toBe(401);
    expect((await list(w, tokens.refresh_token)).status).toBe(401);
  });

  it("un token de Supabase con client_id (el del conector) no sirve, tenga el rol que tenga", async () => {
    const w = await world();
    for (const role of ["yala_mcp_reader", "authenticated"]) {
      const t = await appToken(w, USER_A.id, { role, client_id: "cliente-del-worker" });
      expect((await list(w, t)).status, role).toBe(401);
    }
  });

  it("un token de la app con otro rol, otra audiencia o sin sesión no sirve", async () => {
    const w = await world();
    expect((await list(w, await appToken(w, USER_A.id, { role: "anon" }))).status).toBe(401);
    expect((await list(w, await appToken(w, USER_A.id, { aud: "otra" }))).status).toBe(401);
    expect((await list(w, await appToken(w, USER_A.id, { session_id: "" }))).status).toBe(401);
  });

  it("un token caducado no sirve", async () => {
    const w = await world();
    const t = await w.supabase.sign({ sub: USER_A.id, aud: "authenticated", role: "authenticated", session_id: "s" }, Math.floor(Date.now() / 1000) - 60);
    expect((await list(w, t)).status).toBe(401);
  });

  it("si las claves de Supabase no responden, 503 y no 401 (la app reintenta, no cierra la sesión)", async () => {
    const w = await world();
    const t = await appToken(w);
    w.supabase.jwksThrows = Object.assign(new Error("timeout"), { code: "ERR_JWKS_TIMEOUT" });
    const res = await list(w, t);
    expect(res.status).toBe(503);
    expect(res.headers.get("Retry-After")).toBe("30");
  });

  it("checkAppClaims exige role authenticated, session_id y sin client_id", () => {
    const base = { sub: "u", exp: 9_999_999_999, role: "authenticated", session_id: "s" };
    expect(checkAppClaims(base)).toEqual({ ok: true, sub: "u" });
    expect(checkAppClaims({ ...base, client_id: "x" })).toMatchObject({ ok: false, reason: "not_app" });
    expect(checkAppClaims({ ...base, role: "yala_mcp_reader" })).toMatchObject({ ok: false, reason: "not_app" });
    expect(checkAppClaims({ ...base, session_id: undefined })).toMatchObject({ ok: false, reason: "invalid" });
    expect(checkAppClaims({ ...base, sub: undefined })).toMatchObject({ ok: false, reason: "invalid" });
  });

  it("los métodos que no son del servicio responden 405", async () => {
    const w = await world();
    const t = await appToken(w);
    expect((await w.call(`${BASE}/connections`, { method: "POST", headers: { Authorization: `Bearer ${t}` } })).status).toBe(405);
    expect((await w.call(`${BASE}/connections/abc`, { method: "GET", headers: { Authorization: `Bearer ${t}` } })).status).toBe(405);
  });

  it("va al cubo de límites por IP de las rutas OAuth", () => {
    expect(ipBucketFor("/connections")).toBe("RL_OAUTH");
    expect(ipBucketFor("/connections/abc")).toBe("RL_OAUTH");
  });
});

describe("DELETE /connections/<id>", () => {
  it("desconecta: la IA deja de leer al momento y no puede refrescar", async () => {
    const w = await world();
    const { clientId, tokens } = await connect(w);
    expect((await rpc(w, tokens.access_token, INIT)).status).toBe(200);
    const t = await appToken(w);
    const { conexiones } = (await (await list(w, t)).json()) as { conexiones: Row[] };

    const res = await remove(w, t, conexiones[0]!.id);
    expect(res.status).toBe(204);
    expect(grantCount(w)).toBe(0);
    expect((await rpc(w, tokens.access_token, INIT)).status).toBe(401);
    const r = await refresh(w, clientId, tokens.refresh_token);
    expect(r.res.status).toBe(400);
    expect(r.body.error).toBe("invalid_grant");
    expect(await (await list(w, t)).json()).toEqual({ conexiones: [] });
  });

  it("no borra la conexión de otro usuario aunque sepa su id", async () => {
    const w = await world();
    await connect(w, USER_A);
    const tA = await appToken(w, USER_A.id);
    const { conexiones } = (await (await list(w, tA)).json()) as { conexiones: Row[] };
    const res = await remove(w, await appToken(w, USER_B.id), conexiones[0]!.id);
    expect(res.status).toBe(404);
    expect(grantCount(w)).toBe(1);
  });

  it("un id inexistente o con caracteres raros es 404, y sin sesión es 401 aunque exista", async () => {
    const w = await world();
    await connect(w);
    const t = await appToken(w);
    expect((await remove(w, t, "no-existe")).status).toBe(404);
    expect((await remove(w, t, "a:b")).status).toBe(404);
    const { conexiones } = (await (await list(w, t)).json()) as { conexiones: Row[] };
    expect((await remove(w, null, conexiones[0]!.id)).status).toBe(401);
    expect(grantCount(w)).toBe(1);
  });

  it("la IA con su propio token no puede desconectarse ni desconectar a otra", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    const { conexiones } = (await (await list(w, await appToken(w))).json()) as { conexiones: Row[] };
    expect((await remove(w, tokens.access_token, conexiones[0]!.id)).status).toBe(401);
    expect(grantCount(w)).toBe(1);
  });
});

describe("el nombre de cada IA sale de su vuelta, no del nombre que se puso", () => {
  const grant = (redirectUri?: string): GrantSummary => ({
    id: "g1",
    clientId: "c1",
    userId: "u",
    scope: ["lectura"],
    metadata: {},
    createdAt: 1_800_000_000,
    ...(redirectUri ? { redirectUri } : {}),
  });
  const helpers = (redirectUris: string[], clientName = "Claude") =>
    ({ lookupClient: async () => ({ clientId: "c1", redirectUris, clientName }) }) as unknown as OAuthHelpers;

  it.each([
    ["https://claude.ai/api/mcp/auth_callback", "Claude", "claude.ai", false],
    ["https://chatgpt.com/connector_platform_oauth_redirect", "ChatGPT", "chatgpt.com", false],
    ["https://grok.com/oauth/callback", "Grok", "grok.com", false],
    ["http://127.0.0.1:6274/oauth/callback", "Claude", "127.0.0.1", true],
  ])("%s → %s", async (uri, ia, vuelta, local) => {
    expect(await describeGrant(helpers([uri]), grant(uri))).toMatchObject({ ia, vuelta, local });
  });

  it("Grok Bot: aunque el grant vuelva a Cursor o al loopback, la fila dice Grok", async () => {
    const grokBot = [
      "https://www.cursor.com/agents/mcp/oauth/callback",
      "https://www.cursor.com/bot/mcp/oauth/callback",
      "https://grok.com/connectors-oauth-exchange-code/",
      "cursor://anysphere.cursor-mcp/oauth/callback",
      "http://localhost:8787/callback",
      "http://127.0.0.1:8787/callback",
    ];
    expect(await describeGrant(helpers(grokBot, "Grok"), grant("https://www.cursor.com/bot/mcp/oauth/callback"))).toMatchObject({
      ia: "Grok",
      vuelta: "www.cursor.com",
      local: false,
    });
    expect(await describeGrant(helpers(grokBot, "Grok"), grant("http://localhost:8787/callback"))).toMatchObject({ ia: "Grok", local: true });
    expect(await describeGrant(helpers(grokBot.filter((u) => !u.includes("grok.com")), "Grok"), grant())).toMatchObject({ ia: "Cursor" });
  });

  it("una vuelta desconocida es null aunque el cliente se llame «Claude»", async () => {
    const row = await describeGrant(helpers(["https://evil.example/cb"], "Claude"), grant("https://evil.example/cb"));
    expect(row).toMatchObject({ ia: null, vuelta: "evil.example", local: false });
  });

  it("sin la vuelta en el grant (grants viejos), usa la del cliente", async () => {
    expect(await describeGrant(helpers(["https://claude.ai/api/mcp/auth_callback"]), grant())).toMatchObject({ ia: "Claude", vuelta: "claude.ai" });
  });

  it("si el cliente no se puede leer, la fila sale igual, sin nombre", async () => {
    const broken = { lookupClient: async () => { throw new Error("kv"); } } as unknown as OAuthHelpers;
    expect(await describeGrant(broken, grant())).toMatchObject({ id: "g1", ia: null, vuelta: null });
  });
});

describe("el listado de KV va atrasado (medido en staging)", () => {
  it("quitar una conexión que el listado todavía no trae funciona igual", async () => {
    const w = await world();
    await connect(w);
    const t = await appToken(w);
    const { conexiones } = (await (await list(w, t)).json()) as { conexiones: Row[] };
    // El listado de KV aún no la ve: como en Cloudflare, segundos después de conectar.
    const kv = w.kv as unknown as { list: (o: unknown) => Promise<unknown> };
    kv.list = async () => ({ keys: [], list_complete: true, cacheStatus: null });
    expect((await remove(w, t, conexiones[0]!.id)).status).toBe(204);
    expect(grantCount(w)).toBe(0);
  });
});

describe("quitar corta también el token que el listado no alcanzó a borrar", () => {
  it("con el listado de tokens atrasado, la IA queda fuera igual", async () => {
    const w = await world();
    const { tokens } = await connect(w);
    const t = await appToken(w);
    const { conexiones } = (await (await list(w, t)).json()) as { conexiones: Row[] };
    // El listado no ve los tokens (como en Cloudflare segundos después de emitirlos): `revokeGrant` borra solo el grant.
    const kv = w.kv as unknown as { list: (o: { prefix?: string }) => Promise<unknown> };
    const realList = kv.list.bind(w.kv);
    kv.list = async (o) => (o.prefix?.startsWith("token:") ? { keys: [], list_complete: true, cacheStatus: null } : realList(o));
    expect((await remove(w, t, conexiones[0]!.id)).status).toBe(204);
    expect([...w.kv.store.keys()].some((k) => k.startsWith("token:"))).toBe(true);
    const res = await rpc(w, tokens.access_token, INIT);
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("La conexion se quito");
  });
});
