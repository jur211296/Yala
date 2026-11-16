/**
 * `[env.production]` de wrangler.toml (escrito el 2026-11-15, sin desplegar). Se lee el fichero tal cual: así un cambio
 * que apunte producción a staging, o que reuse los límites de staging, se pone rojo aquí y no en un despliegue.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { configProblems, STAGING_SUPABASE_REF } from "../src/worker/config";
import { FakeLimiter, makeEnv } from "./fakes";

const TOML = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");
const PROD = TOML.slice(TOML.indexOf("\n[env.production]"));
const TOP = TOML.slice(0, TOML.indexOf("\n[env.production]"));

/** Las `CLAVE = "valor"` de una tabla `[nombre]` (hasta la siguiente tabla). Basta para este fichero. */
function table(src: string, name: string): Record<string, string> {
  const start = src.indexOf(`\n[${name}]`);
  if (start < 0) return {};
  const body = src.slice(start + name.length + 3).split(/\n\[/)[0] ?? "";
  return Object.fromEntries([...body.matchAll(/^([A-Z_]+) = "([^"]*)"/gm)].map((m) => [m[1], m[2]]));
}

const prodVars = table(PROD, "env.production.vars");
const namespaceIds = (src: string) => [...src.matchAll(/namespace_id = "(\d+)"/g)].map((m) => m[1]);

describe("producción en wrangler.toml", () => {
  it("apunta a Supabase de producción, con su anon key, y no a staging", () => {
    expect(prodVars.ENVIRONMENT).toBe("production");
    expect(prodVars.SUPABASE_URL).toBe("https://kefvaiymtgytemwbltlz.supabase.co");
    expect(prodVars.SUPABASE_URL).not.toContain(STAGING_SUPABASE_REF);
    expect(PROD).not.toMatch(/yala-gateway-staging|fostjbbwstyuunmmefuk|1x0000/);
  });

  it("el dominio de PUBLIC_URL es el que sirve la ruta, y solo ese host (sin workers.dev)", () => {
    const host = /routes = \[\{ pattern = "([^"]+)", custom_domain = true \}\]/.exec(PROD)?.[1];
    expect(host).toBeDefined();
    expect(prodVars.PUBLIC_URL).toBe(`https://${host}`);
    expect(PROD).toMatch(/\nworkers_dev = false\n/);
  });

  it("la cola de borradores y Grupos van al gateway de PRODUCCIÓN", () => {
    expect(PROD).toContain('database_name = "yala-gateway-production"');
    expect([...PROD.matchAll(/service = "([^"]+)"/g)].map((m) => m[1])).toEqual([
      "yala-gateway-production",
      "yala-gateway-production",
    ]);
  });

  it("los límites de producción tienen su propio espacio, distinto de staging", () => {
    const prod = namespaceIds(PROD);
    expect(prod).toHaveLength(3);
    for (const id of prod) expect(namespaceIds(TOP)).not.toContain(id);
  });

  it("tal como está escrito, el Worker NO atiende: 503 por lo que sigue PENDIENTE", () => {
    const env = makeEnv({
      ...prodVars,
      SUPABASE_OAUTH_CLIENT_SECRET: "secreto",
      TURNSTILE_SECRET_KEY: "0x4AAAAAAA-secreto-real",
      RL_AUTH: new FakeLimiter(),
      RL_API: new FakeLimiter(),
      RL_QR: new FakeLimiter(),
    });
    expect(configProblems(env)).toEqual([
      "SUPABASE_OAUTH_CLIENT_ID no es un uuid (¿sigue PENDIENTE?)",
      "SUPABASE_OAUTH_CLIENT_ID sigue PENDIENTE",
      "TURNSTILE_SITE_KEY sigue PENDIENTE",
    ]);
  });

  it("con el cliente y el widget reales, la misma configuración atiende", () => {
    const env = makeEnv({
      ...prodVars,
      SUPABASE_OAUTH_CLIENT_ID: "6a1f0c5e-1b2c-4d3e-8f90-0a1b2c3d4e5f",
      SUPABASE_OAUTH_CLIENT_SECRET: "secreto",
      TURNSTILE_SITE_KEY: "0x4AAAAAAA-real",
      TURNSTILE_SECRET_KEY: "0x4AAAAAAA-secreto-real",
      RL_AUTH: new FakeLimiter(),
      RL_API: new FakeLimiter(),
      RL_QR: new FakeLimiter(),
    });
    expect(configProblems(env)).toEqual([]);
  });
});
