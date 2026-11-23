/**
 * La web del conector con la marca de Yala (encargo «Conecta tu IA»): logo y logos dentro de la página, nada de fuera
 * (la CSP sigue en `default-src 'none'`), botones oficiales en claro y oscuro, cabe en un teléfono, y sin «Listo».
 */
import type { AuthRequest, ClientInfo } from "@cloudflare/workers-oauth-provider";
import { describe, expect, it } from "vitest";
import { consentPage, errorPage, loginPage } from "../../src/pages";

const client = (redirectUris: string[], clientName = "Claude") => ({ clientId: "c", clientName, redirectUris }) as unknown as ClientInfo;
const req = (redirectUri: string) => ({ redirectUri }) as unknown as AuthRequest;

function consent(redirect: string, name = "Claude") {
  return consentPage(client([redirect], name), req(redirect), "h", new Headers(), false, true);
}

describe("marca y seguridad de las páginas", () => {
  it("las tres pantallas llevan el logo SVG dentro, sin recursos de fuera, y la CSP de siempre", async () => {
    for (const res of [consent("https://claude.ai/api/mcp/auth_callback"), loginPage("auth_123", { staging: false }), errorPage("x")]) {
      expect(res.headers.get("Content-Security-Policy")).toBe(
        "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'",
      );
      const html = await res.text();
      expect(html).toContain('aria-label="Yala"');
      expect(html).toContain("#00F3FF");
      expect(html).toContain("#FF0080");
      expect(html).not.toMatch(/<script|<link|@import|url\(|src="http|href="http/);
    }
  });

  it("cabe en un teléfono: todo con box-sizing border-box y el dominio largo se parte", async () => {
    const html = await consent("https://claude.ai/api/mcp/auth_callback").text();
    expect(html).toContain("*,*::before,*::after{box-sizing:border-box}");
    expect(html).toContain('<meta name="viewport" content="width=device-width,initial-scale=1">');
    expect(html).toMatch(/\.dest code\{[^}]*overflow-wrap:anywhere/);
  });

  it("botones oficiales: Apple negro en claro y blanco en oscuro; Google con la G de color", async () => {
    const html = await loginPage("auth_123", { staging: false }).text();
    expect(html).toContain("button.apple{background:#000;border-color:#000;color:#fff}");
    expect(html).toContain("@media (prefers-color-scheme:dark){button.apple{background:#fff;border-color:#fff;color:#000}button.google{background:#131314");
    for (const color of ["#EA4335", "#4285F4", "#FBBC05", "#34A853"]) expect(html).toContain(color);
    expect(html).toMatch(/<button class="apple" type="submit"><svg[^>]*aria-hidden="true">.*<span>Continuar con Apple<\/span><\/button>/);
    expect(html).toMatch(/<button class="google" type="submit"><svg[^>]*aria-hidden="true">.*<span>Continuar con Google<\/span><\/button>/);
  });

  it("no hay página «Listo»: tras iniciar sesión se vuelve directo a la IA", async () => {
    for (const res of [consent("https://claude.ai/api/mcp/auth_callback"), loginPage("auth_123", { staging: false })]) {
      expect(await res.text()).not.toContain("Listo");
    }
  });
});

describe("«Yala × <IA>» sale de la vuelta, nunca del nombre que se puso el cliente", () => {
  it.each([
    ["https://claude.ai/api/mcp/auth_callback", "Claude"],
    ["https://chatgpt.com/connector_platform_oauth_redirect", "ChatGPT"],
    ["https://grok.com/oauth/callback", "Grok"],
  ])("%s → %s", async (redirect, ai) => {
    const html = await consent(redirect, "Nombre cualquiera").text();
    expect(html).toContain(`<span class="ai">${ai}</span>`);
  });

  it("un cliente que se llama «Claude» con otra vuelta no gana la marca", async () => {
    const html = await consent("https://evil.example/cb", "Claude").text();
    expect(html).not.toContain('<span class="ai">');
    expect(html).toContain("<code>evil.example</code>");
  });

  it("el nombre elegido sigue escapado", async () => {
    const html = await consent("https://evil.example/cb", "<b>x</b>").text();
    expect(html).toContain("&lt;b&gt;x&lt;/b&gt; quiere usar tus datos de Yala");
  });
});

describe("error", () => {
  it("enseña el mensaje escapado bajo un título fijo", async () => {
    const html = await errorPage("Falta <algo>", 400).text();
    expect(html).toContain("<h1>No se pudo continuar</h1>");
    expect(html).toContain("Falta &lt;algo&gt;");
  });
});
