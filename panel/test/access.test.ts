import { describe, expect, it } from "vitest";
import { SignJWT, exportJWK, generateKeyPair, createLocalJWKSet, type KeyLike } from "jose";
import { checkAccess } from "../src/access";
import { handleFetch } from "../src/index";
import type { Env } from "../src/env";
import { fakeD1 } from "./fakeD1";

const TEAM = "yala.cloudflareaccess.com";
const AUD = "aud-del-panel";

async function keys() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256" };
  return { getKey: createLocalJWKSet({ keys: [jwk] }), privateKey };
}

async function token(privateKey: KeyLike, claims: { email?: string; aud?: string; iss?: string }) {
  return new SignJWT(claims.email ? { email: claims.email } : {})
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer(claims.iss ?? `https://${TEAM}`)
    .setAudience(claims.aud ?? AUD)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
}

const env = (over: Partial<Env> = {}) =>
  ({ ENVIRONMENT: "production", ACCESS_TEAM_DOMAIN: TEAM, ACCESS_AUD: AUD, ALLOWED_EMAILS: "admin@yala-app.pe", ...over }) as Env;
const req = (jwt?: string) => new Request("https://panel.yala-app.pe/", { headers: jwt ? { "Cf-Access-Jwt-Assertion": jwt } : {} });

describe("Cloudflare Access — el Worker verifica él mismo", () => {
  it("sin configurar Access: 503 a todo el mundo (falla cerrado)", async () => {
    expect(await checkAccess(req(), env({ ACCESS_AUD: "" }))).toMatchObject({ ok: false, status: 503 });
    expect(await checkAccess(req(), env({ ACCESS_TEAM_DOMAIN: undefined }))).toMatchObject({ ok: false, status: 503 });
  });

  it("sin el JWT de Access: 401", async () => {
    expect(await checkAccess(req(), env())).toMatchObject({ ok: false, status: 401 });
  });

  it("JWT válido del correo permitido: entra (mayúsculas no importan)", async () => {
    const k = await keys();
    expect(await checkAccess(req(await token(k.privateKey, { email: "Admin@Yala-App.pe" })), env(), k.getKey)).toEqual({ ok: true, email: "admin@yala-app.pe" });
  });

  it("otro correo: 403; otra audiencia u otro emisor: 401", async () => {
    const k = await keys();
    expect(await checkAccess(req(await token(k.privateKey, { email: "otra@persona.com" })), env(), k.getKey)).toMatchObject({ status: 403 });
    expect(await checkAccess(req(await token(k.privateKey, { email: "admin@yala-app.pe", aud: "otra" })), env(), k.getKey)).toMatchObject({ status: 401 });
    expect(await checkAccess(req(await token(k.privateKey, { email: "admin@yala-app.pe", iss: "https://otro.cloudflareaccess.com" })), env(), k.getKey)).toMatchObject({ status: 401 });
  });

  it("firmado con otra llave: 401", async () => {
    const k = await keys();
    const ajena = await keys();
    expect(await checkAccess(req(await token(ajena.privateKey, { email: "admin@yala-app.pe" })), env(), k.getKey)).toMatchObject({ status: 401 });
  });

  it("la página: sin Access configurado responde 503 y no lee la base; /healthz siempre", async () => {
    const e = env({ ACCESS_AUD: "", PANEL_DB: fakeD1() });
    const res = await handleFetch(req(), e);
    expect(res.status).toBe(503);
    expect(await res.text()).not.toContain("Panel de Yala");
    expect((await handleFetch(new Request("https://panel.yala-app.pe/healthz"), e)).status).toBe(200);
  });

  it("en local (wrangler dev) se sirve sin Access, con cabeceras que no cachean", async () => {
    const res = await handleFetch(req(), env({ ENVIRONMENT: "local", ACCESS_AUD: "", PANEL_DB: fakeD1() }));
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("private, no-store");
    expect(await res.text()).toContain("Todavía no hay ningún día resumido");
  });
});
