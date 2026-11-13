import { describe, expect, it } from "vitest";
import { BASE, WEB_CLIENT, world } from "./fakes";
import { SESSION_COOKIE } from "../src/worker/session";

const DAY = 86_400;

describe("cuánto dura una sesión (D4)", () => {
  it("equipo propio: 30 días sin uso la cierran; usándola, se alarga", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now += 29 * DAY;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    w.clock.now += 29 * DAY;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    w.clock.now += 31 * DAY;
    const res = await w.browser.request("/api/me");
    expect(res.status).toBe(401);
    expect(w.kv.data.size).toBe(0);
  });

  it("equipo propio: aunque se use, a los 90 días hay que volver a entrar", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    for (let d = 0; d < 89; d += 20) {
      w.clock.now += 20 * DAY;
      if (d + 20 < 90) expect((await w.browser.request("/api/me")).status, `día ${d + 20}`).toBe(200);
    }
    w.clock.now += 10 * DAY;
    expect((await w.browser.request("/api/me")).status).toBe(401);
  });

  it("al usarla renueva el Max-Age de la cookie, como mucho una vez por minuto", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now += 30;
    expect((await w.browser.request("/api/me")).headers.getSetCookie()).toEqual([]);
    w.clock.now += 3600;
    const renewed = (await w.browser.request("/api/me")).headers.getSetCookie().find((c) => c.startsWith(SESSION_COOKIE))!;
    expect(renewed).toContain(`Max-Age=${30 * DAY}`);
  });

  it("equipo compartido: cookie del navegador (sin Max-Age) y 30 minutos sin uso la cierran", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    const res = await w.socialLogin(ana, { compartido: true });
    const cookie = res.headers.getSetCookie().find((c) => c.startsWith(`${SESSION_COOKIE}=`))!;
    expect(cookie).not.toContain("Max-Age");
    expect(await (await w.browser.request("/api/me")).json()).toMatchObject({ equipoCompartido: true });
    w.clock.now += 29 * 60;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    w.clock.now += 29 * 60;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    w.clock.now += 31 * 60;
    expect((await w.browser.request("/api/me")).status).toBe(401);
  });
});

describe("la sesión de Supabase que lleva dentro", () => {
  it("refresca el acceso cuando caduca y guarda el refresh rotado, sin perder la sesión", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const before = [...w.kv.data.values()][0]!.value;
    w.clock.now += 3600;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    expect([...w.kv.data.values()][0]!.value).not.toBe(before);
    w.clock.now += 3600;
    expect((await w.browser.request("/api/me")).status).toBe(200);
  });

  it("si Supabase retira la sesión (cerrada en otro sitio), la web la borra al momento", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    for (const [id, s] of w.supabase.sessions) if (s.clientId === WEB_CLIENT) w.supabase.sessions.delete(id);
    const res = await w.browser.request("/api/me");
    expect(res.status).toBe(401);
    expect(w.kv.data.size).toBe(0);
    expect(w.browser.jar.has(SESSION_COOKIE)).toBe(false);
  });

  it("un refresh rechazado para siempre borra la sesión; uno que no responde la conserva (503)", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now += 3600;
    w.supabase.failRefresh = { status: 500, code: "unexpected_failure" };
    expect((await w.browser.request("/api/me")).status).toBe(503);
    expect(w.kv.data.size).toBe(1);
    w.supabase.failRefresh = { status: 400, code: "refresh_token_already_used" };
    expect((await w.browser.request("/api/me")).status).toBe(401);
    expect(w.kv.data.size).toBe(0);
  });

  it("si al refrescar el token deja de ser de solo lectura, se cierra en vez de usarlo", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now += 3600;
    w.supabase.hookOff = true;
    expect((await w.browser.request("/api/me")).status).toBe(401);
    expect(w.kv.data.size).toBe(0);
    expect(w.supabase.openSessions(ana.id).web).toBe(0);
  });

  it("si Supabase no contesta, 503 sin borrar nada", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.supabase.userDown = true;
    expect((await w.browser.request("/api/me")).status).toBe(503);
    expect(w.kv.data.size).toBe(1);
  });
});

describe("cookies que no son de nadie", () => {
  it("sin cookie, una inventada o una de otra sesión manipulada: 401", async () => {
    const w = await world();
    expect((await w.browser.request("/api/me")).status).toBe(401);
    const fake = await w.call(new Request(`${BASE}/api/me`, { headers: { Cookie: `${SESSION_COOKIE}=${"A".repeat(43)}` } }));
    expect(fake.status).toBe(401);
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const real = w.browser.jar.get(SESSION_COOKIE)!.value;
    const tampered = real.slice(0, -1) + (real.endsWith("A") ? "B" : "A");
    expect((await w.call(new Request(`${BASE}/api/me`, { headers: { Cookie: `${SESSION_COOKIE}=${tampered}` } }))).status).toBe(401);
    expect((await w.browser.request("/api/me")).status).toBe(200);
  });
});
