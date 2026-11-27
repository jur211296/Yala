#!/usr/bin/env node
// check-groups-columns-applied.mjs — guard de `predeploy:*`: no deja desplegar un Worker cuyo manifest de Grupos declara
// columnas que la base de ese entorno todavía no tiene. El orden de una columna nueva es DDL → Worker → app, y hasta
// aquí nada lo hacía cumplir (la decisión y su porqué, en `groups-columns-guard.mjs`).
//
// Uso:   node scripts/check-groups-columns-applied.mjs <staging|production>
// Lee:   ./group_capability_manifest.json (la copia que `sync:manifest` acaba de hacer) y las columnas de las tablas de
//        Grupos por la Management API de Supabase, con el PAT de ~/Secrets/yala-supabase-mgmt/pat (o SUPABASE_MGMT_PAT).
// Salida: 0 si todas las columnas existen; 1 si falta alguna o no se pudo leer la base.
// Forzar: ALLOW_MISSING_GROUP_COLUMNS=1 (solo si sabes que ningún teléfono habla aún esa versión de Grupos).
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { missingGroupColumns } from "./groups-columns-guard.mjs";

const REFS = { staging: "fostjbbwstyuunmmefuk", production: "kefvaiymtgytemwbltlz" };
const env = process.argv[2];
const ref = REFS[env];
const allow = process.env.ALLOW_MISSING_GROUP_COLUMNS === "1";
const bail = (message) => {
  if (allow) {
    console.warn(`check-groups-columns-applied: ${message}; sigo por ALLOW_MISSING_GROUP_COLUMNS=1`);
    process.exit(0);
  }
  console.error(`check-groups-columns-applied: ${message}`);
  console.error("  Si de verdad hay que desplegar sin esta comprobación: ALLOW_MISSING_GROUP_COLUMNS=1 npm run deploy:…");
  process.exit(1);
};
if (!ref) bail(`entorno desconocido «${env}» (staging | production)`);

const manifest = JSON.parse(readFileSync(new URL("../group_capability_manifest.json", import.meta.url), "utf8"));
const tables = [...new Set(Object.values(manifest.entities).map((e) => e.table))];

const patFile = join(homedir(), "Secrets", "yala-supabase-mgmt", "pat");
const pat = process.env.SUPABASE_MGMT_PAT ?? (existsSync(patFile) ? readFileSync(patFile, "utf8").trim() : "");
if (!pat) bail(`sin PAT de la Management API (${patFile} o SUPABASE_MGMT_PAT): no puedo comprobar la base de ${env}`);

const query = `select table_name, column_name from information_schema.columns where table_schema = 'public' and table_name in (${tables
  .map((t) => `'${t}'`)
  .join(", ")})`;
let rows;
try {
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${pat}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  rows = await res.json();
  if (!Array.isArray(rows)) throw new Error("respuesta sin filas");
} catch (e) {
  bail(`no pude leer las columnas de ${env} (${e.message}). No despliego a ciegas`);
}

const decision = missingGroupColumns(manifest, rows);
if (!decision.ok) {
  bail(`el manifest de Grupos v${manifest.manifest_version} declara columnas que la base de ${env} no tiene: ` +
    `${decision.missing.join(", ")}. Aplica antes su migración (qa/cloud/)`);
}
console.log(`check-groups-columns-applied: ${env} tiene todas las columnas del manifest de Grupos v${manifest.manifest_version}`);
