// mint-stats-role-jwt.mjs
//
// Acuña el JWT de MÁQUINA del rol `yala_stats` (qa/cloud/tel01_stats_counts.sql): el panel lo usa como
// `STATS_ROLE_JWT` (secret del Worker) para llamar a `yala_stats_counts()`, la única función que ese rol puede
// ejecutar, que devuelve conteos. Molde: gateway/scripts/mint-push-role-jwt.mjs.
//
// Firma HS256 con el LEGACY JWT secret del proyecto de Supabase de PRODUCCIÓN. El claim `role: yala_stats` hace que
// PostgREST ejecute `SET ROLE yala_stats`. Caduca en 10 años.
//
// ⚠️ El secret de firma JAMÁS va a stdout ni al repo: se lee de un PATH. Este script imprime SOLO el JWT, para pipe:
//
//   node scripts/mint-stats-role-jwt.mjs /ruta/al/legacy-jwt-secret.txt | npx wrangler secret put STATS_ROLE_JWT
//
// Si se revoca el legacy secret, el conteo deja de llegar (el panel lo dice al pie): re-acuñar y re-subir.

import { readFileSync } from "node:fs";
import { SignJWT } from "jose";

const secretPath = process.argv[2];
if (!secretPath) {
  process.stderr.write("uso: node scripts/mint-stats-role-jwt.mjs <path-al-legacy-jwt-secret>\n");
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
const now = Math.floor(Date.now() / 1000);
const jwt = await new SignJWT({ role: "yala_stats" })
  .setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setIssuer("yala-panel")
  .setIssuedAt(now)
  .setExpirationTime(now + 10 * 365 * 24 * 60 * 60)
  .sign(new TextEncoder().encode(secretRaw));
process.stdout.write(jwt);
