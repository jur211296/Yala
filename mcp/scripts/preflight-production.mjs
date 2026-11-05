#!/usr/bin/env node
/**
 * Antes de `wrangler deploy --env production`: lo corre `npm run deploy:production`, y si algo falla NO despliega.
 *
 * 1. `[env.production]` de wrangler.toml sin nada PENDIENTE, con el id del cliente como uuid y el KV como id real.
 * 2. El secreto SUPABASE_OAUTH_CLIENT_SECRET ya está subido a producción (`wrangler secret list --env production`).
 * 3. typecheck y la suite unitaria en verde (entre ellos, que las variables de producción del toml pasen `config.ts`).
 *
 * Lo que este script no ve (el hook de Supabase, el servidor OAuth, el proveedor de email) está en el runbook:
 * mcp/RUNBOOK-produccion.md. Sin salida a la red salvo `wrangler secret list`.
 */
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Todo lo que va desde `[env.production]` hasta el final: en este toml, producción es lo último. */
export function productionSection(toml) {
  const start = toml.search(/^\[env\.production\]\s*$/m);
  return start === -1 ? "" : toml.slice(start);
}

/** Qué impide desplegar producción, mirando solo el texto del toml. Vacío = puede seguir. */
export function tomlProblems(toml) {
  const section = productionSection(toml);
  if (!section) return ["no hay [env.production] en wrangler.toml"];
  const problems = [];
  // Solo las líneas con valor: los comentarios pueden nombrar PENDIENTE para explicarlo.
  const pending = section.split("\n").filter((l) => !l.trim().startsWith("#") && /PENDIENTE/.test(l));
  for (const line of pending) problems.push(`sigue PENDIENTE: ${line.trim().split("=")[0].trim()}`);
  const clientId = /^SUPABASE_OAUTH_CLIENT_ID\s*=\s*"([^"]*)"/m.exec(section)?.[1];
  if (!clientId || !UUID_RE.test(clientId)) problems.push("SUPABASE_OAUTH_CLIENT_ID no es un uuid");
  const kv = /\[\[env\.production\.kv_namespaces\]\][^[]*?\bid\s*=\s*"([^"]*)"/s.exec(section)?.[1];
  if (!kv || !/^[0-9a-f]{32}$/.test(kv)) problems.push("el id del KV OAUTH_KV de producción no es un id de Cloudflare (32 hex)");
  for (const name of ["RL_BROWSER", "RL_OAUTH", "RL_MCP"]) {
    if (!new RegExp(`\\[\\[env\\.production\\.ratelimits\\]\\]\\s*name\\s*=\\s*"${name}"`).test(section)) {
      problems.push(`falta el límite ${name} en [env.production]`);
    }
  }
  return problems;
}

function capture(cmd, args, cwd) {
  return execFileSync(cmd, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
}

/** Con la salida a la vista: si falla, `execFileSync` lanza y el proceso sale con error sin desplegar. */
function check(cmd, args, cwd) {
  execFileSync(cmd, args, { cwd, stdio: "inherit" });
}

function main() {
  const root = join(dirname(fileURLToPath(import.meta.url)), "..");
  const problems = tomlProblems(readFileSync(join(root, "wrangler.toml"), "utf8"));
  if (problems.length === 0) {
    let secrets = "";
    try {
      secrets = capture("npx", ["wrangler", "secret", "list", "--env", "production"], root);
    } catch {
      problems.push("no se pudo leer `wrangler secret list --env production` (¿sesión de wrangler? ¿existe ya el Worker?)");
    }
    // Por nombre y como palabra entera: vale tanto si wrangler imprime JSON como una tabla.
    if (secrets && !/\bSUPABASE_OAUTH_CLIENT_SECRET\b/.test(secrets)) {
      problems.push("falta el secreto SUPABASE_OAUTH_CLIENT_SECRET en producción (runbook, paso 4)");
    }
  }
  if (problems.length) {
    console.error("NO se despliega producción:\n" + problems.map((p) => `  - ${p}`).join("\n"));
    console.error("Runbook: mcp/RUNBOOK-produccion.md");
    process.exit(1);
  }
  check("npm", ["run", "typecheck"], root);
  check("npm", ["test"], root);
  console.log("Preflight de producción en verde.");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
