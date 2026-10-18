#!/usr/bin/env node
// check-manifest-not-older.mjs — guard de `predeploy:*`: no deja desplegar un Worker cuyo capability_manifest sea
// MÁS VIEJO que el del Worker que ya está desplegado en ese entorno.
//
// Por qué (review del 2026-10-18, tarjeta con varias divisas): desde `manifest_version: 2` los teléfonos 2.2 hablan la
// versión que el Worker anuncia y, con `v2`, toda alta de cuenta lleva `parent_account_id`. Un Worker desplegado
// desde una rama con el manifest viejo (2.1, o un `wrangler rollback`) rechaza esas filas ENTERAS con `unknown_column`
// y el teléfono las aparta para siempre. Los cambios del gateway entran a menudo por 2.1, así que esto pasa sin querer.
//
// Uso:   node scripts/check-manifest-not-older.mjs <url del Worker>   (lo llaman predeploy:staging y :production)
// Lee:   ./capability_manifest.json (la copia que `sync:manifest` acaba de hacer) y GET <url>/config → sync.manifestVersion
//        (ausente = 1: un Worker anterior a esto).
// Salida: 0 si se puede desplegar; 1 si el local es más viejo o no se pudo leer el desplegado.
// Forzar: ALLOW_MANIFEST_DOWNGRADE=1 (solo si sabes que ningún teléfono habla aún la versión del desplegado).
import { readFileSync } from "node:fs";

const url = process.argv[2];
if (!url) {
  console.error("check-manifest-not-older: falta la URL del Worker");
  process.exit(1);
}
const local = JSON.parse(readFileSync(new URL("../capability_manifest.json", import.meta.url), "utf8")).manifest_version;

let deployed;
try {
  // Cloudflare corta el User-Agent por defecto de algunos clientes (error 1010) antes de llegar al Worker.
  const res = await fetch(`${url.replace(/\/$/, "")}/config`, { headers: { "User-Agent": "yala-deploy-guard" } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const body = await res.json();
  deployed = body?.sync?.manifestVersion ?? 1;
} catch (e) {
  if (process.env.ALLOW_MANIFEST_DOWNGRADE === "1") {
    console.warn(`check-manifest-not-older: no pude leer ${url}/config (${e.message}); sigo por ALLOW_MANIFEST_DOWNGRADE=1`);
    process.exit(0);
  }
  console.error(`check-manifest-not-older: no pude leer ${url}/config (${e.message}). No despliego a ciegas.`);
  console.error("  Si de verdad hay que desplegar sin esta comprobación: ALLOW_MANIFEST_DOWNGRADE=1 npm run deploy:…");
  process.exit(1);
}

if (local < deployed) {
  if (process.env.ALLOW_MANIFEST_DOWNGRADE === "1") {
    console.warn(`check-manifest-not-older: BAJAS el manifest de v${deployed} a v${local} (ALLOW_MANIFEST_DOWNGRADE=1).`);
    process.exit(0);
  }
  console.error(`check-manifest-not-older: el Worker desplegado habla v${deployed} y este árbol trae v${local}.`);
  console.error("  Los teléfonos en la versión nueva verían rechazadas sus filas (unknown_column). Despliega desde una");
  console.error("  rama con el manifest al día. Ver gateway/RUNBOOK.md, «manifest_version».");
  process.exit(1);
}
console.log(`check-manifest-not-older: OK (desplegado v${deployed}, este árbol v${local}).`);
