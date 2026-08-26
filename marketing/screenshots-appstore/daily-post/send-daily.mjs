// Orquestador del post diario de Yala para Instagram.
// Rota el pool de tips, renderiza el del día y lo envía por Telegram con caption sugerido.
// Lee el token del bot desde ~/.claude/channels/telegram/.env (NO lo duplica).
// Solo avanza el índice si el envío fue exitoso (reintenta el mismo tip si falla la red).
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const DIR = dirname(fileURLToPath(import.meta.url));
const STATE = join(DIR, "state.json");
const ENV = join(homedir(), ".claude", "channels", "telegram", ".env");
const CHAT_ID = "8778292009";

// 1) token del bot (desde el .env del plugin de Telegram)
if (!existsSync(ENV)) { console.error(`No existe ${ENV}`); process.exit(1); }
const tokenMatch = readFileSync(ENV, "utf8").match(/TELEGRAM_BOT_TOKEN\s*=\s*(.+)/);
if (!tokenMatch) { console.error("No se encontró TELEGRAM_BOT_TOKEN en el .env"); process.exit(1); }
const TOKEN = tokenMatch[1].trim().replace(/^["']|["']$/g, "");

// 2) estado (qué tip toca)
let lastIndex = -1;
if (existsSync(STATE)) { try { lastIndex = JSON.parse(readFileSync(STATE, "utf8")).lastIndex ?? -1; } catch { /* estado corrupto → empieza de cero */ } }

// 3) renderizar el siguiente tip
const total = JSON.parse(readFileSync(join(DIR, "content.json"), "utf8")).length;
const next = (lastIndex + 1) % total;
const out = execSync(`node ${JSON.stringify(join(DIR, "render-post.mjs"))} ${next}`, { encoding: "utf8" });
const info = JSON.parse(out.trim().split("\n").pop());

// 4) enviar por Telegram (sendPhoto con caption)
const resp = execSync(
  `curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendPhoto" ` +
  `-F chat_id=${CHAT_ID} ` +
  `-F photo=@${JSON.stringify(info.png)} ` +
  `--form-string caption=${JSON.stringify(info.caption)}`,
  { encoding: "utf8" }
);
let ok = false;
try { ok = JSON.parse(resp).ok === true; } catch { /* respuesta no-JSON */ }

// 5) avanzar el índice SOLO si se envió bien
if (ok) {
  writeFileSync(STATE, JSON.stringify({ lastIndex: next, lastId: info.id, sentAt: new Date().toISOString() }, null, 2));
  console.log(`OK · enviado tip ${next + 1}/${total} (${info.id})`);
} else {
  console.error(`FALLO al enviar (índice no avanza, reintenta luego). Respuesta: ${resp.slice(0, 300)}`);
  process.exit(1);
}
