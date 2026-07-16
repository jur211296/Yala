// mint-push-role-jwt.mjs
//
// Acuña el JWT de MÁQUINA de la credencial `yala_push` (Grupos→backend G8-3). El fan-out de silent push lo
// usa como `PUSH_ROLE_JWT` (secret del Worker) para llamar get_group_push_tokens / prune_push_token — los
// únicos RPCs que el rol `yala_push` puede EXECUTE (revocados de authenticated en la migración g8_02).
//
// Firma HS256 con el LEGACY JWT secret del proyecto Supabase (el simétrico histórico, verificado válido). El
// claim `role: yala_push` hace que PostgREST/authenticator ejecute `SET ROLE yala_push`. exp = 10 años.
//
// ⚠️ El secret de firma JAMÁS va a stdout ni al repo: se lee de un PATH pasado por argv (p.ej. un archivo del
// keychain exportado, o `~/Secrets/...`). Este script imprime SOLO el JWT resultante a stdout, para pipe
// directo:
//
//   node scripts/mint-push-role-jwt.mjs /ruta/al/legacy-jwt-secret.txt | npx wrangler secret put PUSH_ROLE_JWT
//   # prod:  ... | npx wrangler secret put PUSH_ROLE_JWT --env production   (mismo o distinto legacy secret)
//
// Rotación: si el owner revoca el legacy secret, re-acuñar con el signing key vigente y re-subir el secret.
// (El canario del fan-out es el `console.log "upstream 401"` recurrente — ver g8_02_push_machine_role.sql.)

import { readFileSync } from "node:fs";
import { SignJWT } from "jose";

const secretPath = process.argv[2];
if (!secretPath) {
  process.stderr.write("uso: node scripts/mint-push-role-jwt.mjs <path-al-legacy-jwt-secret>\n");
  process.exit(1);
}

let secretRaw;
try {
  secretRaw = readFileSync(secretPath, "utf8").trim();
} catch (err) {
  process.stderr.write(`error leyendo el secret de ${secretPath}: ${err.message}\n`);
  process.exit(1);
}
if (!secretRaw) {
  process.stderr.write(`el archivo ${secretPath} está vacío\n`);
  process.exit(1);
}

const secret = new TextEncoder().encode(secretRaw);
const now = Math.floor(Date.now() / 1000);
const exp = now + 10 * 365 * 24 * 60 * 60; // 10 años

const jwt = await new SignJWT({ role: "yala_push" })
  .setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setIssuer("yala-gateway")
  .setIssuedAt(now)
  .setExpirationTime(exp)
  .sign(secret);

// SOLO el JWT, sin salto de línea final (para que el pipe a `wrangler secret put` no incluya un \n en el valor).
process.stdout.write(jwt);
