/**
 * El `wrangler.toml` de verdad, no uno de test: las variables de cada entorno pasan `config.ts`, y el preflight de
 * `deploy:production` se niega mientras quede algo PENDIENTE.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { configProblems } from "../src/config";
import type { Env } from "../src/env";
import { productionSection, tomlProblems } from "../scripts/preflight-production.mjs";
import { FakeLimiter } from "./helpers";

const TOML = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");

/** Los `KEY = "valor"` de una tabla del toml (solo cadenas: es lo único que usan las vars de este fichero). */
function vars(table: string): Record<string, string> {
  const start = TOML.indexOf(`\n${table}\n`);
  expect(start, table).toBeGreaterThan(-1);
  const rest = TOML.slice(start + table.length + 2);
  const end = rest.search(/^\[/m);
  const out: Record<string, string> = {};
  for (const m of (end === -1 ? rest : rest.slice(0, end)).matchAll(/^([A-Z_]+)\s*=\s*"([^"]*)"/gm)) out[m[1]!] = m[2]!;
  return out;
}

/** Lo que no está en `vars`: el secreto, el KV y los límites (el toml los declara; aquí se dan por enlazados). */
const BOUND: Partial<Env> = {
  SUPABASE_OAUTH_CLIENT_SECRET: "secreto",
  OAUTH_KV: {} as KVNamespace,
  RL_BROWSER: new FakeLimiter(),
  RL_OAUTH: new FakeLimiter(),
  RL_MCP: new FakeLimiter(),
};

describe("wrangler.toml real", () => {
  it("staging pasa la comprobación de configuración", () => {
    expect(configProblems({ ...vars("[vars]"), ...BOUND })).toEqual([]);
  });

  // El toml real vive en dos estados: con el KV y el cliente PENDIENTE (hasta el runbook) y relleno (después). El
  // preflight corre esta suite antes de desplegar, así que los dos tienen que pasar: se comprueba el que toque.
  const PENDING = /PENDIENTE/.test(vars("[env.production.vars]")["SUPABASE_OAUTH_CLIENT_ID"] ?? "");

  it("producción: la configuración del toml es válida (salvo el id del cliente mientras siga PENDIENTE)", () => {
    const prod = vars("[env.production.vars]");
    expect(prod["ENVIRONMENT"]).toBe("production");
    if (PENDING) {
      expect(configProblems({ ...prod, ...BOUND })).toEqual(["SUPABASE_OAUTH_CLIENT_ID no es un uuid (¿sigue PENDIENTE?)"]);
      // Con un id de verdad, el resto (URL, anon key, zona, URL pública) es válido.
      expect(configProblems({ ...prod, ...BOUND, SUPABASE_OAUTH_CLIENT_ID: "0b6f1c5e-6a55-4e0b-9d9c-1f7a3d2e4c10" })).toEqual([]);
    } else {
      expect(configProblems({ ...prod, ...BOUND })).toEqual([]);
    }
  });

  it("producción declara los tres límites y su propio KV, distintos de los de staging", () => {
    const prod = productionSection(TOML);
    const staging = TOML.slice(0, TOML.indexOf(prod));
    for (const name of ["RL_BROWSER", "RL_OAUTH", "RL_MCP"]) {
      expect(prod).toContain(`name = "${name}"`);
      expect(staging).toContain(`name = "${name}"`);
    }
    const ids = (s: string) => [...s.matchAll(/namespace_id = "(\d+)"/g)].map((m) => m[1]);
    const all = [...ids(staging), ...ids(prod)];
    expect(all).toHaveLength(6);
    expect(new Set(all).size).toBe(6);
    expect(prod).toContain('binding = "OAUTH_KV"');
    expect(prod).not.toContain("9705886913ee4d1fb7217ef6e3ecdef7");
  });
});

describe("preflight de deploy:production", () => {
  it("con algo PENDIENTE se niega, y nombra cada cosa", () => {
    const prod = productionSection(TOML);
    const pending = TOML.slice(0, TOML.indexOf(prod)) + prod.replace(/^(SUPABASE_OAUTH_CLIENT_ID = )"[^"]*"/m, (_m, k: string) => `${k}"PENDIENTE-registrar-cliente-oauth-en-supabase-produccion"`)
      .replace(/(\[\[env\.production\.kv_namespaces\]\][^[]*?\bid = )"[^"]*"/s, (_m, k: string) => `${k}"PENDIENTE-crear-kv-yala-mcp-production-oauth"`);
    expect(tomlProblems(pending)).toEqual([
      "sigue PENDIENTE: id",
      "sigue PENDIENTE: SUPABASE_OAUTH_CLIENT_ID",
      "SUPABASE_OAUTH_CLIENT_ID no es un uuid",
      "el id del KV OAUTH_KV de producción no es un id de Cloudflare (32 hex)",
    ]);
  });

  it("con el KV y el cliente rellenos, deja pasar", () => {
    const filled = TOML.replace("PENDIENTE-crear-kv-yala-mcp-production-oauth", "0123456789abcdef0123456789abcdef").replace(
      "PENDIENTE-registrar-cliente-oauth-en-supabase-produccion",
      "0b6f1c5e-6a55-4e0b-9d9c-1f7a3d2e4c10",
    );
    expect(tomlProblems(filled)).toEqual([]);
  });

  it("sin producción, o sin un límite, se niega", () => {
    expect(tomlProblems(TOML.slice(0, TOML.indexOf("[env.production]")))).toEqual(["no hay [env.production] en wrangler.toml"]);
    const sinMcp = TOML.replace(/\[\[env\.production\.ratelimits\]\]\nname = "RL_MCP"/, '[[env.production.ratelimits]]\nname = "OTRO"');
    expect(tomlProblems(sinMcp)).toContain("falta el límite RL_MCP en [env.production]");
  });
});
