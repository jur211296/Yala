import { describe, expect, it } from "vitest";
import { BASE, CONNECTOR_CLIENT, FakeLimiter, SB_URL, WEB_CLIENT, world } from "./fakes";
import { SESSION_COOKIE } from "../src/worker/session";

describe("entrar con Apple o Google", () => {
  it("/auth/start verifica Turnstile y manda al login social de Supabase con PKCE y la vuelta de la web", async () => {
    const w = await world();
    const res = await w.browser.request("/auth/start", { form: { provider: "google", "cf-turnstile-response": "token-humano" } });
    expect(res.status).toBe(303);
    const to = new URL(res.headers.get("Location")!);
    expect(`${to.origin}${to.pathname}`).toBe(`${SB_URL}/auth/v1/authorize`);
    expect(to.searchParams.get("provider")).toBe("google");
    expect(to.searchParams.get("redirect_to")).toBe(`${BASE}/auth/callback`);
    expect(to.searchParams.get("code_challenge_method")).toBe("s256");
    expect(to.searchParams.get("code_challenge")).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const login = res.headers.getSetCookie().find((c) => c.startsWith("__Host-yala-web-login="))!;
    expect(login).toContain("Path=/;"); // `__Host-` exige Path=/ o el navegador la descarta
    expect(w.browser.jar.has("__Host-yala-web-login")).toBe(true);
    expect(login).toContain("HttpOnly");
    expect(login).toContain("Secure");
    expect(login).toContain("SameSite=Lax");
    expect(login).toContain("Max-Age=600");
  });

  it("entra: deja una cookie que la página no lee, la sesión normal queda cerrada y solo vive la de lectura", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test", name: "Ana Pérez" });
    const res = await w.socialLogin(ana);
    expect(res.status).toBe(303);
    expect(res.headers.get("Location")).toBe("/");
    const cookie = res.headers.getSetCookie().find((c) => c.startsWith(`${SESSION_COOKIE}=`))!;
    expect(cookie).toMatch(/; Path=\/; Secure; HttpOnly; SameSite=Lax; Max-Age=2592000$/);

    const me = await w.browser.request("/api/me");
    expect(me.status).toBe(200);
    expect(await me.json()).toEqual({ nombre: "Ana Pérez", correo: "ana@yala.test", equipoCompartido: false });
    expect(w.supabase.openSessions(ana.id)).toEqual({ normal: 0, web: 1 });
  });

  it("en el KV no hay ningún token en claro ni el valor de la cookie", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const cookieValue = w.browser.jar.get(SESSION_COOKIE)!.value;
    const web = [...w.supabase.sessions.values()].find((s) => s.clientId === WEB_CLIENT)!;
    expect(w.kv.data.size).toBe(1);
    for (const [key, { value }] of w.kv.data) {
      expect(key).not.toContain(cookieValue);
      expect(value).not.toContain(cookieValue);
      expect(value).not.toContain(web.refresh);
      expect(value).not.toContain("eyJ"); // ningún JWT
    }
  });

  it("sin nombre de Apple o Google, enseña el correo", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    expect(await (await w.browser.request("/api/me")).json()).toMatchObject({ nombre: "ana@yala.test" });
  });

  it("si Supabase dice que el permiso ya estaba dado, entra igual (sin volver a aprobar)", async () => {
    const w = await world();
    w.supabase.alreadyConsented = true;
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    expect((await w.socialLogin(ana)).headers.get("Location")).toBe("/");
    expect(w.supabase.calls.some((c) => c.path.endsWith("/consent"))).toBe(false);
    expect((await w.browser.request("/api/me")).status).toBe(200);
  });

  it("el permiso lo pide el servidor con el cliente de la web, no sigue el salto a la Site URL", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const authorize = w.supabase.calls.find((c) => c.path === "/auth/v1/oauth/authorize")!;
    const q = new URLSearchParams(authorize.search);
    expect(q.get("client_id")).toBe(WEB_CLIENT);
    expect(q.get("redirect_uri")).toBe(`${BASE}/auth/supabase/callback`);
    expect(q.get("code_challenge_method")).toBe("S256");
    expect(w.supabase.calls.some((c) => c.path.includes("conector"))).toBe(false);
  });
});

describe("quién no entra", () => {
  it("sin Turnstile válido no se manda a nadie al login social", async () => {
    const w = await world();
    const res = await w.browser.request("/auth/start", { form: { provider: "apple", "cf-turnstile-response": "bot" } });
    expect(res.headers.get("Location")).toBe("/?aviso=verificacion");
    expect(w.kv.data.size).toBe(0);
    const sinToken = await w.browser.request("/auth/start", { form: { provider: "apple" } });
    expect(sinToken.headers.get("Location")).toBe("/?aviso=verificacion");
  });

  it("un formulario de otro sitio no puede hacer entrar ni salir a nadie", async () => {
    const w = await world();
    const form = { provider: "apple", "cf-turnstile-response": "token-humano" };
    expect((await w.browser.request("/auth/start", { form, headers: { Origin: "https://malo.test" } })).status).toBe(403);
    expect((await w.browser.request("/auth/logout", { form: {}, headers: { Origin: "https://malo.test" } })).status).toBe(403);
    // Sin cabecera Origin tampoco: falla cerrado.
    const sinOrigen = await w.call(
      new Request(`${BASE}/auth/start`, { method: "POST", body: new URLSearchParams(form), headers: { "Content-Type": "application/x-www-form-urlencoded" } }),
    );
    expect(sinOrigen.status).toBe(403);
  });

  it("quien no activó la nube no entra, y su sesión de Supabase queda cerrada", async () => {
    const w = await world();
    const nuevo = w.supabase.addUser({ email: "nuevo@yala.test", kind: null });
    const res = await w.socialLogin(nuevo);
    expect(res.headers.get("Location")).toBe("/?aviso=sin-nube");
    expect(w.browser.jar.has(SESSION_COOKIE)).toBe(false);
    expect(w.supabase.openSessions(nuevo.id)).toEqual({ normal: 0, web: 0 });
  });

  it("una cuenta solo de Grupos no entra hasta el lote 3", async () => {
    const w = await world();
    const grupos = w.supabase.addUser({ email: "grupos@yala.test", kind: "groups_only" });
    expect((await w.socialLogin(grupos)).headers.get("Location")).toBe("/?aviso=solo-grupos");
    expect(w.supabase.openSessions(grupos.id)).toEqual({ normal: 0, web: 0 });
  });

  it("si el hook no marca el token como de solo lectura, no se guarda nada y la sesión se cierra", async () => {
    const w = await world();
    w.supabase.hookOff = true;
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    expect((await w.socialLogin(ana)).headers.get("Location")).toBe("/?aviso=error");
    expect(w.kv.data.size).toBe(0);
    expect(w.supabase.openSessions(ana.id)).toEqual({ normal: 0, web: 0 });
  });

  it("si el hook no conoce a la web, Supabase no da token y no se entra", async () => {
    const w = await world();
    w.supabase.hookAllow.delete(WEB_CLIENT);
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    expect((await w.socialLogin(ana)).headers.get("Location")).toBe("/?aviso=error");
    expect(w.supabase.openSessions(ana.id).normal).toBe(0);
  });

  it("un token de lectura de OTRO cliente (el conector) no sirve aquí", async () => {
    const w = await world({ SUPABASE_OAUTH_CLIENT_ID: CONNECTOR_CLIENT });
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    // El secreto es el de la web y el id el del conector: Supabase no canjea. Ningún camino guarda una sesión.
    expect((await w.socialLogin(ana)).headers.get("Location")).toBe("/?aviso=error");
    expect(w.kv.data.size).toBe(0);
  });

  it("la vuelta sin la cookie de ESTE navegador, o repetida, no entra", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    const start = await w.browser.request("/auth/start", { form: { provider: "apple", "cf-turnstile-response": "token-humano" } });
    const to = new URL(start.headers.get("Location")!);
    const back = `${BASE}/auth/callback?code=${w.supabase.socialCode(ana, to.searchParams.get("code_challenge")!)}`;
    const otro = await w.call(new Request(back));
    expect(otro.headers.get("Location")).toBe("/?aviso=caducada");
    expect((await w.browser.request(back)).headers.get("Location")).toBe("/");
    expect((await w.browser.request(back)).headers.get("Location")).toBe("/?aviso=caducada");
  });

  it("si la persona cancela en Apple, vuelve al inicio con el aviso", async () => {
    const w = await world();
    await w.browser.request("/auth/start", { form: { provider: "apple", "cf-turnstile-response": "token-humano" } });
    const res = await w.browser.request("/auth/callback?error=access_denied&error_description=cancelado");
    expect(res.headers.get("Location")).toBe("/?aviso=cancelado");
  });

  it("demasiados intentos desde la misma IP se cortan", async () => {
    const w = await world({ RL_AUTH: new FakeLimiter(2) });
    const form = { provider: "apple", "cf-turnstile-response": "token-humano" };
    await w.browser.request("/auth/start", { form });
    await w.browser.request("/auth/start", { form });
    expect((await w.browser.request("/auth/start", { form })).status).toBe(429);
    expect((await w.browser.request("/auth/callback?code=x")).headers.get("Location")).toBe("/?aviso=limite");
  });
});

describe("volver a entrar sin salir", () => {
  it("cierra la sesión anterior de ese navegador: la cookie vieja deja de valer", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const old = w.browser.jar.get(SESSION_COOKIE)!.value;
    await w.socialLogin(ana);
    expect(w.browser.jar.get(SESSION_COOKIE)!.value).not.toBe(old);
    expect(w.kv.data.size).toBe(1);
    expect(w.supabase.openSessions(ana.id)).toEqual({ normal: 0, web: 1 });
    expect((await w.call(new Request(`${BASE}/api/me`, { headers: { Cookie: `${SESSION_COOKIE}=${old}` } }))).status).toBe(401);
  });
});

describe("salir", () => {
  it("cierra la sesión web y la de Supabase, y borra la cookie", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const res = await w.browser.request("/auth/logout", { form: {} });
    expect(res.status).toBe(303);
    expect(res.headers.get("Location")).toBe("/?aviso=salida");
    expect(res.headers.getSetCookie().some((c) => c.startsWith(`${SESSION_COOKIE}=;`) && c.includes("Max-Age=0"))).toBe(true);
    expect(w.kv.data.size).toBe(0);
    expect(w.supabase.openSessions(ana.id)).toEqual({ normal: 0, web: 0 });
    expect((await w.browser.request("/api/me")).status).toBe(401);
  });

  it("con el acceso caducado, refresca para poder cerrar también la sesión de Supabase", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now += 7200;
    await w.browser.request("/auth/logout", { form: {} });
    expect(w.supabase.openSessions(ana.id).web).toBe(0);
  });
});
