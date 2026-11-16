/**
 * `[env.production]` de wrangler.toml (escrito el 2026-11-15; KV, cliente OAuth y widget de Turnstile reales desde el 2026-11-16). Se lee el fichero tal cual: así un cambio
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

  it("tal como está escrito, con sus dos secretos, el Worker atiende: no queda nada PENDIENTE", () => {
    expect(PROD).not.toContain("PENDIENTE");
    expect(prodVars.TURNSTILE_SITE_KEY).toMatch(/^0x4/);
    const env = makeEnv({
      ...prodVars,
      SUPABASE_OAUTH_CLIENT_SECRET: "secreto",
      TURNSTILE_SECRET_KEY: "0x4AAAAAAA-secreto-real",
      RL_AUTH: new FakeLimiter(),
      RL_API: new FakeLimiter(),
      RL_QR: new FakeLimiter(),
    });
    expect(configProblems(env)).toEqual([]);
  });

  it("sin el secreto de Turnstile, la misma configuración no atiende (falla cerrado)", () => {
    const env = makeEnv({
      ...prodVars,
      SUPABASE_OAUTH_CLIENT_SECRET: "secreto",
      TURNSTILE_SECRET_KEY: "",
      RL_AUTH: new FakeLimiter(),
      RL_API: new FakeLimiter(),
      RL_QR: new FakeLimiter(),
    });
    expect(configProblems(env)).not.toEqual([]);
  });

  it("el cliente OAuth es el registrado en Supabase producción y el KV es el suyo, no el de staging", () => {
    expect(prodVars.SUPABASE_OAUTH_CLIENT_ID).toBe("79c7e38e-409e-470f-9151-81784a02760c");
    expect(prodVars.SUPABASE_OAUTH_CLIENT_ID).not.toBe(table(TOP, "vars").SUPABASE_OAUTH_CLIENT_ID);
    const kv = (src: string) => /binding = "WEB_KV"\nid = "([0-9a-f]{32})"|binding = "WEB_KV"\n#[^\n]*\nid = "([0-9a-f]{32})"/.exec(src);
    const prodKv = kv(PROD);
    expect(prodKv).not.toBeNull();
    expect(prodKv?.[1] ?? prodKv?.[2]).not.toBe("aaee191d09924a7bbbdaa912cd1bcf05");
  });
});
