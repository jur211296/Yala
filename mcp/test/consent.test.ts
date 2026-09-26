import { describe, expect, it } from "vitest";
import { createApp } from "../src/index";
import { escapeHtml, isAllowedRedirect } from "../src/consent";
import { ENV } from "./helpers";

const BASE = "https://mcp.yala.test";
const AUTH_ID = "a1b2c3d4-e5f6-4a1b-8c9d-0123456789ab";

/** GoTrue falso: login con contraseña, detalles de la autorización, decisión y logout. */
function fakeGoTrue(opts: { details?: Record<string, unknown>; badPassword?: boolean } = {}) {
  const calls: { method: string; path: string; auth: string | null; body: unknown }[] = [];
  const fetcher = async (input: Request | string | URL, init?: RequestInit) => {
    const url = new URL(String(input instanceof Request ? input.url : input));
    const headers = new Headers(init?.headers);
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    calls.push({ method: init?.method ?? "GET", path: url.pathname + url.search, auth: headers.get("Authorization"), body });
    if (url.pathname === "/auth/v1/token") {
      return opts.badPassword ? new Response("{}", { status: 400 }) : Response.json({ access_token: "sesion-web", refresh_token: "r" });
    }
    if (url.pathname === `/auth/v1/oauth/authorizations/${AUTH_ID}`) {
      return Response.json(
        opts.details ?? {
          authorization_id: AUTH_ID,
          redirect_uri: "https://claude.ai/api/mcp/auth_callback",
          client: { name: "Claude <script>alert(1)</script>" },
          user: { email: "a@test.yala" },
          scope: "openid email",
        },
      );
    }
    if (url.pathname === `/auth/v1/oauth/authorizations/${AUTH_ID}/consent`) {
      return Response.json({ redirect_url: `https://claude.ai/api/mcp/auth_callback?code=xyz&state=s` });
    }
    if (url.pathname === "/auth/v1/logout") return new Response(null, { status: 204 });
    return new Response("?", { status: 404 });
  };
  return { fetcher, calls };
}

function form(path: string, fields: Record<string, string>, cookie?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/x-www-form-urlencoded" };
  if (cookie) headers.Cookie = cookie;
  return new Request(`${BASE}${path}`, { method: "POST", headers, body: new URLSearchParams(fields).toString() });
}

describe("pantalla de consentimiento", () => {
  it("GET pide iniciar sesión y no deja enmarcar la página", async () => {
    const app = createApp({ fetcher: fakeGoTrue().fetcher });
    const res = await app.fetch(new Request(`${BASE}/oauth/consent?authorization_id=${AUTH_ID}`), ENV);
    expect(res.status).toBe(200);
    expect(await res.text()).toContain('name="password"');
    expect(res.headers.get("X-Frame-Options")).toBe("DENY");
    expect(res.headers.get("Content-Security-Policy")).toContain("frame-ancestors 'none'");
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });

  it("rechaza un authorization_id con forma rara", async () => {
    const app = createApp({ fetcher: fakeGoTrue().fetcher });
    const res = await app.fetch(new Request(`${BASE}/oauth/consent?authorization_id=../../x`), ENV);
    expect(res.status).toBe(400);
  });

  it("tras el login enseña quién pide acceso, a qué dominio vuelve, y escapa el nombre del cliente", async () => {
    const gt = fakeGoTrue();
    const app = createApp({ fetcher: gt.fetcher });
    const res = await app.fetch(form("/oauth/consent", { authorization_id: AUTH_ID, email: "a@test.yala", password: "x" }), ENV);
    const html = await res.text();
    expect(html).toContain("claude.ai");
    expect(html).toContain("&lt;script&gt;");
    expect(html).not.toContain("<script>alert");
    expect(html).toMatch(/No podrá<\/strong> crear, cambiar ni borrar/);
    const cookie = res.headers.get("Set-Cookie") ?? "";
    expect(cookie).toContain(`yala_mcp_consent=${AUTH_ID}.sesion-web`);
    for (const flag of ["HttpOnly", "Secure", "SameSite=Strict", "Path=/oauth", "Max-Age=300"]) expect(cookie).toContain(flag);
  });

  it("contraseña incorrecta vuelve al formulario con 401", async () => {
    const app = createApp({ fetcher: fakeGoTrue({ badPassword: true }).fetcher });
    const res = await app.fetch(form("/oauth/consent", { authorization_id: AUTH_ID, email: "a@test.yala", password: "mal" }), ENV);
    expect(res.status).toBe(401);
    expect(await res.text()).toContain("incorrectos");
  });

  it("aprobar manda la decisión con la sesión web, la CIERRA y redirige a Claude", async () => {
    const gt = fakeGoTrue();
    const app = createApp({ fetcher: gt.fetcher });
    const res = await app.fetch(
      form("/oauth/consent/decision", { authorization_id: AUTH_ID, decision: "approve" }, `yala_mcp_consent=${AUTH_ID}.sesion-web`),
      ENV,
    );
    expect(res.status).toBe(303);
    expect(res.headers.get("Location")).toBe("https://claude.ai/api/mcp/auth_callback?code=xyz&state=s");
    expect(res.headers.get("Set-Cookie")).toContain("Max-Age=0");
    const consent = gt.calls.find((c) => c.path.endsWith("/consent"))!;
    expect(consent.body).toEqual({ action: "approve" });
    expect(consent.auth).toBe("Bearer sesion-web");
    expect(gt.calls.some((c) => c.path.startsWith("/auth/v1/logout") && c.auth === "Bearer sesion-web")).toBe(true);
  });

  it("sin cookie, o con la cookie de OTRA autorización, no decide nada", async () => {
    const gt = fakeGoTrue();
    const app = createApp({ fetcher: gt.fetcher });
    const noCookie = await app.fetch(form("/oauth/consent/decision", { authorization_id: AUTH_ID, decision: "approve" }), ENV);
    expect(noCookie.status).toBe(400);
    const other = await app.fetch(
      form("/oauth/consent/decision", { authorization_id: AUTH_ID, decision: "approve" }, "yala_mcp_consent=otra-autorizacion-123.sesion-web"),
      ENV,
    );
    expect(other.status).toBe(400);
    expect(gt.calls.some((c) => c.path.endsWith("/consent"))).toBe(false);
  });

  it("un cliente registrado por DCR que vuelve a otro dominio no llega a pedir permiso, aunque se llame Claude", async () => {
    for (const redirect_uri of ["https://evil.example/cb", "http://claude.ai/cb", "https://claude.ai.evil.example/cb", undefined]) {
      const gt = fakeGoTrue({ details: { authorization_id: AUTH_ID, redirect_uri, client: { name: "Claude" }, user: { email: "a@test.yala" } } });
      const app = createApp({ fetcher: gt.fetcher });
      const res = await app.fetch(form("/oauth/consent", { authorization_id: AUTH_ID, email: "a@test.yala", password: "x" }), ENV);
      expect(res.status, String(redirect_uri)).toBe(403);
      expect(res.headers.get("Set-Cookie")).toContain("Max-Age=0");
      expect(gt.calls.some((c) => c.path.startsWith("/auth/v1/logout"))).toBe(true);
    }
  });

  it("acepta el loopback de Claude Code", () => {
    expect(isAllowedRedirect("http://localhost:53682/callback")).toBe(true);
    expect(isAllowedRedirect("http://127.0.0.1:9/cb")).toBe(true);
    expect(isAllowedRedirect("https://claude.ai/api/mcp/auth_callback")).toBe(true);
    expect(isAllowedRedirect("javascript:alert(1)")).toBe(false);
  });

  it("fuera de staging no hay login con contraseña", async () => {
    const app = createApp({ fetcher: fakeGoTrue().fetcher });
    const res = await app.fetch(
      form("/oauth/consent", { authorization_id: AUTH_ID, email: "a@test.yala", password: "x" }),
      { ...ENV, ENVIRONMENT: "production" },
    );
    expect(res.status).toBe(403);
  });

  it("escapeHtml cubre los cinco caracteres", () => {
    expect(escapeHtml(`<a href="x">'&'</a>`)).toBe("&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;");
  });
});
