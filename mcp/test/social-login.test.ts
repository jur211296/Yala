/**
 * Iniciar sesión con Apple o Google en la pantalla de permiso (`authorize.ts`, paso 4): el botón manda al login social
 * de Supabase en PKCE, y la vuelta canjea el código con el `verifier` que guardó ESTE navegador.
 */
import { describe, expect, it } from "vitest";
import { randB64url, sha256b64url } from "./b64";
import { authorizeUrl, BASE, Browser, grantCount, productionEnv, register, REDIRECT, RESOURCE, world, type World } from "./helpers";
import { USER_A, type TestUser } from "./supabase-fake";

const pkce = async () => {
  const verifier = randB64url(32);
  return { verifier, challenge: await sha256b64url(verifier) };
};

/** Hasta la pantalla de login (tras «Continuar» en el permiso). */
async function toLogin(w: World) {
  const { body } = await register(w);
  const clientId = body.client_id!;
  const b = new Browser(w);
  const claude = await pkce();
  const consent = await b.fetch(authorizeUrl(clientId, claude.challenge, "st-social"));
  const consentHtml = await consent.text();
  const handle = /name="handle" value="([^"]+)"/.exec(consentHtml)?.[1] ?? "";
  const approve = await b.form(`${BASE}/authorize`, { handle, decision: "approve" });
  const consentUrl = w.supabase.visitAuthorize(approve.headers.get("Location")!, BASE);
  const authorizationId = new URL(consentUrl).searchParams.get("authorization_id")!;
  return { b, clientId, claude, consentHtml, consentUrl, authorizationId };
}

function pressSocial(b: Browser, authorizationId: string, provider: string) {
  return b.form(`${BASE}/oauth/consent/social`, { authorization_id: authorizationId, provider });
}

function socialPendings(w: World) {
  return [...w.kv.store.entries()].filter(([k]) => k.startsWith("yala:social:"));
}

async function finishWithClaude(w: World, l: Awaited<ReturnType<typeof toLogin>>, returned: Response) {
  expect(returned.status, await returned.clone().text()).toBe(303);
  const callback = await l.b.fetch(returned.headers.get("Location")!);
  expect(callback.status, await callback.clone().text()).toBe(302);
  const back = new URL(callback.headers.get("Location")!);
  expect(back.origin + back.pathname).toBe(REDIRECT);
  const tokenRes = await w.call(`${BASE}/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code: back.searchParams.get("code")!,
      redirect_uri: REDIRECT,
      client_id: l.clientId,
      code_verifier: l.claude.verifier,
      resource: RESOURCE,
    }),
  });
  expect(tokenRes.status, await tokenRes.clone().text()).toBe(200);
}

describe("la pantalla de login", () => {
  it("ofrece Apple y Google; en staging, la contraseña va plegada como cuenta de prueba", async () => {
    const w = await world();
    const l = await toLogin(w);
    const res = await l.b.fetch(l.consentUrl);
    const html = await res.text();
    expect(res.status).toBe(200);
    expect(html).toContain("Continuar con Apple");
    expect(html).toContain("Continuar con Google");
    expect(html).toContain('name="provider" value="apple"');
    expect(html).toContain('name="provider" value="google"');
    expect(html.match(/action="\/oauth\/consent\/social"/g)).toHaveLength(2);
    expect(html).toContain("<details><summary>Cuenta de prueba (solo staging)</summary>");
    expect(html).toContain('name="password"');
  });

  it("en producción no hay formulario de contraseña ni marca de staging", async () => {
    const w = await world({ env: productionEnv() });
    const l = await toLogin(w);
    const html = await (await l.b.fetch(l.consentUrl)).text();
    expect(html).toContain("Continuar con Apple");
    expect(html).toContain("Continuar con Google");
    expect(html).not.toContain('name="password"');
    expect(html).not.toContain("staging");
  });
});

describe("el aviso de iCloud privado (decisión del 2026-10-29)", () => {
  it("el permiso avisa de que solo lee la nube de Yala y dice cómo activarla, sin quitar «Continuar»", async () => {
    const w = await world();
    const l = await toLogin(w);
    expect(l.consentHtml).toContain("Solo funciona con la nube de Yala.");
    expect(l.consentHtml).toContain("Si tus datos viven en tu iCloud, Claude no podrá verlos.");
    expect(l.consentHtml).toContain("Ajustes → «Dónde viven tus datos» → «Activar la nube»");
    expect(l.consentHtml).toContain('name="decision" value="approve"');
  });
});

describe.each(["apple", "google"] as const)("conectar iniciando sesión con %s", (provider) => {
  it("el botón manda al login social de Supabase en PKCE, ligado a este navegador", async () => {
    const w = await world();
    const l = await toLogin(w);
    const res = await pressSocial(l.b, l.authorizationId, provider);
    expect(res.status).toBe(303);
    const to = new URL(res.headers.get("Location")!);
    expect(to.origin + to.pathname).toBe(`${new URL(w.env.SUPABASE_URL).origin}/auth/v1/authorize`);
    expect(to.searchParams.get("provider")).toBe(provider);
    expect(to.searchParams.get("redirect_to")).toBe(`${BASE}/oauth/consent/social`);
    expect(to.searchParams.get("code_challenge_method")).toBe("s256");
    expect(to.searchParams.get("code_challenge")).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const cookie = res.headers.getSetCookie().join("\n");
    expect(cookie).toMatch(/__Host-yala-social=[A-Za-z0-9_-]{43};/);
    for (const flag of ["HttpOnly", "Secure", "SameSite=Lax", "Path=/", "Max-Age=600"]) expect(cookie).toContain(flag);
    // El verifier no sale del Worker: ni en la URL ni en la cookie.
    const pend = socialPendings(w);
    expect(pend).toHaveLength(1);
    const verifier = (JSON.parse(pend[0]![1].value) as { verifier: string }).verifier;
    expect(await sha256b64url(verifier)).toBe(to.searchParams.get("code_challenge"));
    expect(res.headers.get("Location")).not.toContain(verifier);
    expect(cookie).not.toContain(verifier);
  });

  it("de punta a punta: Claude recibe su token, queda una conexión, y la sesión web se cierra", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, provider);
    const returned = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A));
    expect(returned.headers.getSetCookie().join("\n")).toMatch(/__Host-yala-social=;.*Max-Age=0/);
    expect(l.b.cookies.has("__Host-yala-social")).toBe(false);
    await finishWithClaude(w, l, returned);
    expect(grantCount(w)).toBe(1);
    expect(w.supabase.webSessions()).toEqual([]);
    expect(w.supabase.oauthSessions(USER_A.id)).toHaveLength(1);
    expect(socialPendings(w)).toHaveLength(0);
  });

  it("también en producción (el canje PKCE está permitido en todos los entornos)", async () => {
    const w = await world({ env: productionEnv() });
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, provider);
    const returned = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A));
    await finishWithClaude(w, l, returned);
    expect(w.supabase.webSessions()).toEqual([]);
  });
});

describe("la vuelta del login social, sin atajos", () => {
  it("cancelar en Apple vuelve a la pantalla de login, sin tocar Supabase", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "apple");
    const before = w.supabase.calls.length;
    const res = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A, { cancel: true }));
    expect(res.status).toBe(400);
    const html = await res.text();
    expect(html).toContain("No se completó el inicio de sesión");
    expect(html).toContain("Continuar con Apple");
    expect(html).toContain(`value="${l.authorizationId}"`);
    expect(w.supabase.calls.length).toBe(before);
    expect(l.b.cookies.has("__Host-yala-social")).toBe(false);
    // Volver a pulsar funciona.
    const again = await pressSocial(l.b, l.authorizationId, "apple");
    const returned = await l.b.fetch(w.supabase.visitSocialAuthorize(again.headers.get("Location")!, USER_A));
    await finishWithClaude(w, l, returned);
  });

  it("otro navegador con el código no entra: sin la cookie no hay verifier ni canje", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "google");
    const backUrl = w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A);
    const extraño = new Browser(w);
    for (const [k, v] of l.b.cookies) if (k !== "__Host-yala-social") extraño.cookies.set(k, v);
    const res = await extraño.fetch(backUrl);
    expect(res.status).toBe(400);
    expect(await res.text()).toContain("se abrió en otro navegador");
    expect(w.supabase.calls.some((c) => c.search.includes("grant_type=pkce"))).toBe(false);
    expect(grantCount(w)).toBe(0);
  });

  it("un código colado en otro login no se canjea: el verifier no casa", async () => {
    const w = await world();
    const l = await toLogin(w);
    const pressA = await pressSocial(l.b, l.authorizationId, "apple");
    const codeFromA = new URL(w.supabase.visitSocialAuthorize(pressA.headers.get("Location")!, USER_A)).searchParams.get("code")!;
    await pressSocial(l.b, l.authorizationId, "apple"); // otro login: otra cookie y otro verifier
    const res = await l.b.fetch(`${BASE}/oauth/consent/social?code=${codeFromA}`);
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("No se pudo iniciar sesión");
    expect(grantCount(w)).toBe(0);
    expect(w.supabase.calls.some((c) => c.path.endsWith("/consent"))).toBe(false);
  });

  it("la misma vuelta dos veces no aprueba dos veces", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "apple");
    const backUrl = w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A);
    const cookie = l.b.cookies.get("__Host-yala-social")!;
    expect((await l.b.fetch(backUrl)).status).toBe(303);
    l.b.cookies.set("__Host-yala-social", cookie);
    const second = await l.b.fetch(backUrl);
    expect(second.status).toBe(400);
    expect(await second.text()).toContain("caducó");
  });

  it("pasados diez minutos, la vuelta ya no vale", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "google");
    const backUrl = w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A);
    for (const [, e] of socialPendings(w)) e.expiration = Math.floor(Date.now() / 1000) - 1;
    const res = await l.b.fetch(backUrl);
    expect(res.status).toBe(400);
    expect(w.supabase.calls.some((c) => c.search.includes("grant_type=pkce"))).toBe(false);
  });

  it("sin haber empezado la conexión desde Claude, el botón no hace nada", async () => {
    const w = await world();
    const l = await toLogin(w);
    const res = await pressSocial(new Browser(w), l.authorizationId, "apple");
    expect(res.status).toBe(400);
    expect(res.headers.get("Location")).toBeNull();
    expect(socialPendings(w)).toHaveLength(0);
  });

  it("un proveedor que no es Apple ni Google se rechaza", async () => {
    const w = await world();
    const l = await toLogin(w);
    const res = await pressSocial(l.b, l.authorizationId, "github");
    expect(res.status).toBe(400);
    expect(res.headers.get("Location")).toBeNull();
    expect(socialPendings(w)).toHaveLength(0);
  });

  it("una cuenta recién creada (sin la nube de Yala) NO se conecta: se explica qué hacer y se puede elegir la otra cuenta", async () => {
    const w = await world();
    const l = await toLogin(w);
    const nueva: TestUser = { id: "33333333-3333-4333-8333-333333333333", email: "nueva@test.yala", password: "x" };
    const logs: string[] = [];
    const orig = console.log;
    console.log = (m: unknown) => void logs.push(String(m));
    let blocked: Response;
    try {
      const press = await pressSocial(l.b, l.authorizationId, "google");
      const logoutsBefore = w.supabase.calls.filter((c) => c.path === "/auth/v1/logout").length;
      blocked = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, nueva, { newUser: true }));
      // La sesión web de la cuenta nueva se cierra igual.
      expect(w.supabase.calls.filter((c) => c.path === "/auth/v1/logout").length).toBe(logoutsBefore + 1);
    } finally {
      console.log = orig;
    }
    const html = await blocked.text();
    expect(blocked.status).toBe(403);
    expect(blocked.headers.get("Location")).toBeNull();
    expect(html).toContain("todavía no usa la nube de Yala");
    expect(html).toContain("Activar la nube");
    expect(html).toContain("Continuar con Apple");
    expect(grantCount(w)).toBe(0);
    expect(w.supabase.oauthSessions(nueva.id)).toHaveLength(0);
    expect(logs.some((m) => m.includes('"resultado":"cuenta_nueva_google"'))).toBe(true);
    expect(logs.some((m) => m.includes('"resultado":"sin_nube"'))).toBe(true);
    expect(logs.join("\n")).not.toContain("nueva@test.yala");

    // Con su otra cuenta, que sí usa la nube, la MISMA solicitud termina bien.
    const again = await pressSocial(l.b, l.authorizationId, "apple");
    const returned = await l.b.fetch(w.supabase.visitSocialAuthorize(again.headers.get("Location")!, USER_A));
    await finishWithClaude(w, l, returned);
    expect(grantCount(w)).toBe(1);
  });

  it("una cuenta antigua que nunca activó la nube tampoco se conecta", async () => {
    const w = await world();
    w.supabase.withoutCloud.add(USER_A.id);
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "apple");
    const res = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A));
    expect(res.status).toBe(403);
    expect(await res.text()).toContain("todavía no usa la nube de Yala");
    expect(grantCount(w)).toBe(0);
  });

  it("quien acaba de activar la nube (cuenta de hace un minuto, con perfil) se conecta", async () => {
    const w = await world();
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "apple");
    const returnUrl = w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A, { newUser: true });
    w.supabase.withoutCloud.delete(USER_A.id); // la app creó su perfil al activar la nube
    await finishWithClaude(w, l, await l.b.fetch(returnUrl));
    expect(grantCount(w)).toBe(1);
  });

  it("si Supabase no dice si la cuenta usa la nube, no se conecta: se pide reintentar", async () => {
    const w = await world();
    w.supabase.profilesStatus = 500;
    const l = await toLogin(w);
    const press = await pressSocial(l.b, l.authorizationId, "google");
    const res = await l.b.fetch(w.supabase.visitSocialAuthorize(press.headers.get("Location")!, USER_A));
    expect(res.status).toBe(503);
    expect(res.headers.get("Location")).toBeNull();
    expect(grantCount(w)).toBe(0);
  });

  it("en staging, la cuenta de prueba sin la nube tampoco se conecta", async () => {
    const w = await world();
    w.supabase.withoutCloud.add(USER_A.id);
    const l = await toLogin(w);
    const res = await l.b.form(`${BASE}/oauth/consent`, { authorization_id: l.authorizationId, email: USER_A.email, password: USER_A.password });
    expect(res.status).toBe(403);
    expect(await res.text()).toContain("todavía no usa la nube de Yala");
    expect(grantCount(w)).toBe(0);
  });
});
