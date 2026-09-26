import { describe, expect, it } from "vitest";
import { isAllowedRedirect } from "../src/authorize";
import { escapeHtml } from "../src/pages";
import { randB64url, sha256b64url } from "./b64";
import { authorizeUrl, BASE, Browser, register, REDIRECT, world, type World } from "./helpers";
import { USER_A, WORKER_SB_CLIENT } from "./supabase-fake";

const pkce = async () => {
  const verifier = randB64url(32);
  return { verifier, challenge: await sha256b64url(verifier) };
};

/** Hasta la pantalla de permiso: devuelve el navegador, el `handle` y el HTML. */
async function toConsent(w: World, name = "Claude <script>alert(1)</script>") {
  const { body } = await register(w, [REDIRECT], name);
  const b = new Browser(w);
  const { challenge } = await pkce();
  const res = await b.fetch(authorizeUrl(body.client_id!, challenge, "st-1"));
  const html = await res.text();
  return { b, res, html, clientId: body.client_id!, handle: /name="handle" value="([^"]+)"/.exec(html)?.[1] ?? "" };
}

/** Hasta el formulario de login de Supabase (tras «Continuar»). */
async function toLogin(w: World) {
  const c = await toConsent(w);
  const approve = await c.b.form(`${BASE}/authorize`, { handle: c.handle, decision: "approve" });
  const consentUrl = w.supabase.visitAuthorize(approve.headers.get("Location")!, BASE);
  return { ...c, approve, consentUrl, authorizationId: new URL(consentUrl).searchParams.get("authorization_id")! };
}

describe("1 · la pantalla de permiso (GET /authorize)", () => {
  it("enseña quién pide, a dónde vuelve, qué no podrá hacer, y escapa el nombre del cliente", async () => {
    const w = await world();
    const { res, html } = await toConsent(w);
    expect(res.status).toBe(200);
    expect(html).toContain("&lt;script&gt;");
    expect(html).not.toContain("<script>alert");
    expect(html).toMatch(/No podrá<\/strong> crear, cambiar ni borrar nada: ni tus finanzas ni los datos de tu cuenta/);
    expect(html).toContain("lo eligió la propia aplicación");
    // El loopback de Claude Code: aviso de aplicación local en vez de un dominio.
    expect(html).toContain("aplicación de tu computadora");
    expect(res.headers.get("X-Frame-Options")).toBe("DENY");
    expect(res.headers.get("Content-Security-Policy")).toContain("frame-ancestors 'none'");
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    const cookie = res.headers.getSetCookie().join("\n");
    expect(cookie).toMatch(/__Host-oauth-consent-[0-9a-f]+=/);
    for (const flag of ["HttpOnly", "Secure", "SameSite=Lax", "Path=/"]) expect(cookie).toContain(flag);
  });

  it("un cliente cuya vuelta no es de Claude no llega a pedir permiso, aunque se llame Claude", async () => {
    const w = await world();
    await w.call(`${BASE}/`); // la librería inyecta sus helpers en la primera petición
    const evil = await w.env.OAUTH_PROVIDER!.createClient({ clientName: "Claude", redirectUris: ["https://evil.example/cb"], tokenEndpointAuthMethod: "none" });
    const res = await w.call(
      `${BASE}/authorize?` +
        new URLSearchParams({ response_type: "code", client_id: evil.clientId, redirect_uri: "https://evil.example/cb", code_challenge: (await pkce()).challenge, code_challenge_method: "S256", state: "s" }),
    );
    expect(res.status).toBe(403);
    expect(res.headers.getSetCookie()).toEqual([]);
    expect(res.headers.get("Location")).toBeNull();
  });

  it("una petición rota se enseña aquí, sin redirigir a ningún sitio", async () => {
    const w = await world();
    const res = await w.call(`${BASE}/authorize?client_id=no-existe&redirect_uri=${encodeURIComponent(REDIRECT)}&response_type=code`);
    expect(res.status).toBe(400);
    expect(res.headers.get("Location")).toBeNull();
  });

  it("sin PKCE vuelve a Claude con el error (cliente y vuelta ya validados)", async () => {
    const w = await world();
    const { body } = await register(w);
    const res = await w.call(
      `${BASE}/authorize?` + new URLSearchParams({ response_type: "code", client_id: body.client_id!, redirect_uri: REDIRECT, state: "s9" }),
    );
    expect(res.status).toBe(302);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.origin + loc.pathname).toBe(REDIRECT);
    expect(loc.searchParams.get("error")).toBe("invalid_request");
    expect(loc.searchParams.get("state")).toBe("s9");
  });

  it("un POST con un cuerpo que no es formulario da 400, no 500", async () => {
    const w = await world();
    for (const path of ["/authorize", "/oauth/consent"]) {
      const res = await w.call(`${BASE}${path}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
      expect(res.status, path).toBe(400);
    }
  });
});

describe("2 · la decisión (POST /authorize)", () => {
  it("«No permitir» vuelve a Claude con access_denied y su state, sin pasar por Supabase", async () => {
    const w = await world();
    const c = await toConsent(w);
    const res = await c.b.form(`${BASE}/authorize`, { handle: c.handle, decision: "deny" });
    expect(res.status).toBe(302);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.searchParams.get("error")).toBe("access_denied");
    expect(loc.searchParams.get("state")).toBe("st-1");
    expect(w.supabase.calls).toEqual([]);
  });

  it("«Continuar» manda a Supabase como el cliente del Worker, con PKCE S256 y su propia vuelta", async () => {
    const w = await world();
    const c = await toConsent(w);
    const res = await c.b.form(`${BASE}/authorize`, { handle: c.handle, decision: "approve" });
    expect(res.status).toBe(302);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.origin + loc.pathname).toBe("https://proyecto.supabase.co/auth/v1/oauth/authorize");
    expect(loc.searchParams.get("client_id")).toBe(WORKER_SB_CLIENT);
    expect(loc.searchParams.get("redirect_uri")).toBe(`${BASE}/oauth/supabase/callback`);
    expect(loc.searchParams.get("code_challenge_method")).toBe("S256");
    expect(loc.searchParams.get("state")).toBeTruthy();
    // El state es el de la librería, no el de Claude.
    expect(loc.searchParams.get("state")).not.toBe("st-1");
    expect(res.headers.getSetCookie().join("\n")).toMatch(/__Host-oauth-upstream-[0-9a-f]+=/);
  });

  it("el formulario sirve UNA vez y solo en el navegador que lo abrió", async () => {
    const w = await world();
    const c = await toConsent(w);
    const otro = new Browser(w);
    expect((await otro.form(`${BASE}/authorize`, { handle: c.handle, decision: "approve" })).status).toBe(400);
    expect((await c.b.form(`${BASE}/authorize`, { handle: c.handle, decision: "approve" })).status).toBe(302);
    expect((await c.b.form(`${BASE}/authorize`, { handle: c.handle, decision: "approve" })).status).toBe(400);
  });
});

describe("3 y 4 · el login (/oauth/consent)", () => {
  it("sin haber pasado por el permiso en este navegador, no hay formulario ni login", async () => {
    const w = await world();
    const { authorizationId } = await toLogin(w);
    const extraño = new Browser(w);
    expect((await extraño.fetch(`${BASE}/oauth/consent?authorization_id=${authorizationId}`)).status).toBe(400);
    const post = await extraño.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: USER_A.email, password: USER_A.password });
    expect(post.status).toBe(400);
    expect(w.supabase.calls.some((c) => c.path === "/auth/v1/token")).toBe(false);
  });

  it("rechaza un authorization_id con forma rara", async () => {
    const w = await world();
    const { b } = await toLogin(w);
    expect((await b.fetch(`${BASE}/oauth/consent?authorization_id=../../x`)).status).toBe(400);
  });

  it("contraseña incorrecta vuelve al formulario con 401", async () => {
    const w = await world();
    const { b, authorizationId } = await toLogin(w);
    const res = await b.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: USER_A.email, password: "mal" });
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("incorrectos");
  });

  it("aprueba SOLO la autorización del cliente del Worker y cierra la sesión web en la misma petición", async () => {
    const w = await world();
    const { b, authorizationId } = await toLogin(w);
    const res = await b.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: USER_A.email, password: USER_A.password });
    expect(res.status).toBe(303);
    expect(new URL(res.headers.get("Location")!).pathname).toBe("/oauth/supabase/callback");
    // Ninguna sesión web viva, y ninguna cookie con un token de Supabase.
    expect(w.supabase.webSessions()).toEqual([]);
    expect(res.headers.getSetCookie()).toEqual([]);
    const web = w.supabase.calls.find((c) => c.path === "/auth/v1/logout");
    expect(web?.search).toBe("?scope=local");
  });

  it("si la autorización es de OTRO cliente o vuelve a otro sitio, no la aprueba y cierra la sesión web", async () => {
    for (const override of [
      (a: { id: string; redirectUri: string }) => ({ authorization_id: a.id, redirect_uri: a.redirectUri, client: { id: "otro-cliente" } }),
      (a: { id: string }) => ({ authorization_id: a.id, redirect_uri: "https://evil.example/cb", client: { id: WORKER_SB_CLIENT } }),
    ]) {
      const w = await world();
      const { b, authorizationId } = await toLogin(w);
      w.supabase.detailsOverride = override as never;
      const res = await b.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: USER_A.email, password: USER_A.password });
      expect(res.status).toBe(403);
      expect(w.supabase.calls.some((c) => c.path.endsWith("/consent"))).toBe(false);
      expect(w.supabase.webSessions()).toEqual([]);
    }
  });

  it("con permiso previo, Supabase aprueba solo: se sigue su vuelta, pero solo si es el callback del Worker", async () => {
    const ok = await world();
    ok.supabase.alreadyConsented = true;
    const a = await toLogin(ok);
    const res = await a.b.form(`${BASE}/oauth/consent`, { authorization_id: a.authorizationId, email: USER_A.email, password: USER_A.password });
    expect(res.status).toBe(303);
    expect(new URL(res.headers.get("Location")!).pathname).toBe("/oauth/supabase/callback");

    const mal = await world();
    mal.supabase.alreadyConsented = true;
    mal.supabase.consentRedirectOverride = "https://evil.example/cb?code=x";
    const m = await toLogin(mal);
    const res2 = await m.b.form(`${BASE}/oauth/consent`, { authorization_id: m.authorizationId, email: USER_A.email, password: USER_A.password });
    expect(res2.status).toBe(502);
    expect(res2.headers.get("Location")).toBeNull();
    expect(mal.supabase.webSessions()).toEqual([]);
  });

  it("fuera de staging no hay login con contraseña", async () => {
    const w = await world({ env: { ENVIRONMENT: "production" } });
    const { b, authorizationId } = await toLogin(w);
    const res = await b.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: USER_A.email, password: USER_A.password });
    expect(res.status).toBe(403);
    expect(w.supabase.calls.some((c) => c.path === "/auth/v1/token")).toBe(false);
  });
});

describe("5 · la vuelta de Supabase (GET /oauth/supabase/callback)", () => {
  async function toCallback(w: World) {
    const l = await toLogin(w);
    const login = await l.b.form(`${BASE}/oauth/consent`, { authorization_id: l.authorizationId, email: USER_A.email, password: USER_A.password });
    return { ...l, callbackUrl: login.headers.get("Location")! };
  }

  it("solo se acepta en el navegador que empezó la conexión", async () => {
    const w = await world();
    const { callbackUrl } = await toCallback(w);
    const res = await new Browser(w).fetch(callbackUrl);
    expect(res.status).toBe(400);
    expect(w.supabase.calls.some((c) => c.path === "/auth/v1/oauth/token")).toBe(false);
  });

  it("si Supabase vuelve con error, Claude recibe access_denied con su state", async () => {
    const w = await world();
    const { b, callbackUrl } = await toCallback(w);
    const u = new URL(callbackUrl);
    u.searchParams.delete("code");
    u.searchParams.set("error", "access_denied");
    const res = await b.fetch(u.toString());
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.searchParams.get("error")).toBe("access_denied");
    expect(loc.searchParams.get("state")).toBe("st-1");
  });

  it("canje rechazado → access_denied; Supabase caído → temporarily_unavailable", async () => {
    for (const [fail, expected] of [
      [{ status: 400, code: "invalid_grant" }, "access_denied"],
      [{ status: 503, code: "http_503" }, "temporarily_unavailable"],
    ] as const) {
      const w = await world();
      const { b, callbackUrl } = await toCallback(w);
      w.supabase.failExchange = fail;
      const res = await b.fetch(callbackUrl);
      expect(new URL(res.headers.get("Location")!).searchParams.get("error")).toBe(expected);
    }
  });

  it("si el hook está apagado (token que escribe) o el token es de otro cliente, no se entrega nada y se cierra", async () => {
    for (const tweak of [(w: World) => (w.supabase.roleForOAuth = "authenticated"), (w: World) => (w.supabase.clientIdInToken = "otro")]) {
      const w = await world();
      const { b, callbackUrl } = await toCallback(w);
      tweak(w);
      const res = await b.fetch(callbackUrl);
      const loc = new URL(res.headers.get("Location")!);
      expect(loc.searchParams.get("error")).toBe("server_error");
      expect(loc.searchParams.get("code")).toBeNull();
      expect(w.supabase.oauthSessions()).toEqual([]);
    }
  });
});

describe("piezas", () => {
  it("lista de vueltas EXACTA: el callback fijo de Claude y el loopback /callback; nada más", () => {
    // Lo que la doc de Claude declara.
    expect(isAllowedRedirect("https://claude.ai/api/mcp/auth_callback")).toBe(true);
    expect(isAllowedRedirect("https://claude.com/api/mcp/auth_callback")).toBe(true);
    expect(isAllowedRedirect("http://localhost:53682/callback")).toBe(true);
    expect(isAllowedRedirect("http://127.0.0.1:9/callback")).toBe(true);
    expect(isAllowedRedirect("http://[::1]:41000/callback")).toBe(true);
    for (const bad of [
      // Otra ruta o query en un dominio de Claude: aquí es donde vivía el agujero (open redirect en claude.ai).
      "https://claude.ai/x",
      "https://claude.ai/api/mcp/auth_callback?next=https://evil.example/",
      "https://claude.ai/api/mcp/auth_callback/extra",
      "https://claude.com/",
      // Loopback con otra ruta o con query.
      "http://localhost:53682/cb",
      "http://127.0.0.1:9/callback?x=1",
      "https://localhost:9/callback",
      // Formas no canónicas y trucos varios.
      "https:claude.ai/api/mcp/auth_callback",
      "http://claude.ai/api/mcp/auth_callback",
      "https://claude.ai.evil.example/api/mcp/auth_callback",
      "javascript:alert(1)",
      "https://u:p@claude.ai/api/mcp/auth_callback",
      undefined,
    ]) {
      expect(isAllowedRedirect(bad), String(bad)).toBe(false);
    }
  });

  it("escapeHtml cubre los cinco caracteres", () => {
    expect(escapeHtml(`<a href="x">'&'</a>`)).toBe("&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;");
  });
});
