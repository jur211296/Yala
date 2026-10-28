#!/usr/bin/env node
// check-manifest-not-older.mjs — guard de `predeploy:*`: no deja desplegar un Worker cuyo capability_manifest sea
// MÁS VIEJO que el del Worker que ya está desplegado en ese entorno.
//
// Por qué (review del 2026-10-18, tarjeta con varias divisas): desde `manifest_version: 2` los teléfonos 2.2 hablan la
// versión que el Worker anuncia y, con `v2`, toda alta de cuenta lleva `parent_account_id`. Un Worker desplegado
// desde una rama con el manifest viejo (2.1, o un `wrangler rollback`) rechaza esas filas ENTERAS con `unknown_column`
// y el teléfono las aparta para siempre. Los cambios del gateway entran a menudo por 2.1, así que esto pasa sin querer.
//
// Desde la card u8cl (2026-10-28) mira también el manifest de GRUPOS (`group_capability_manifest.json`, publicado en
// `/config` como `sync.groupsManifestVersion`): un Worker con el de Grupos más viejo poda o rechaza columnas que los
// teléfonos de la versión nueva ya mandan. La decisión vive en `manifest-guard.mjs`, con su test.
//
// Uso:   node scripts/check-manifest-not-older.mjs <url del Worker>   (lo llaman predeploy:staging y :production)
// Lee:   ./capability_manifest.json y ./group_capability_manifest.json (las copias que `sync:manifest` acaba de hacer) y
//        GET <url>/config → sync.manifestVersion (ausente = 1) y sync.groupsManifestVersion (ausente = 2).
// Salida: 0 si se puede desplegar; 1 si el local es más viejo o no se pudo leer el desplegado.
// Forzar: ALLOW_MANIFEST_DOWNGRADE=1 (solo si sabes que ningún teléfono habla aún la versión del desplegado).
import { readFileSync } from "node:fs";
import { decideManifestGuard } from "./manifest-guard.mjs";

const url = process.argv[2];
if (!url) {
  console.error("check-manifest-not-older: falta la URL del Worker");
  process.exit(1);
}
const readVersion = (file) => JSON.parse(readFileSync(new URL(`../${file}`, import.meta.url), "utf8")).manifest_version;
const localPersonal = readVersion("capability_manifest.json");
const localGroups = readVersion("group_capability_manifest.json");

let config;
try {
  // Cloudflare corta el User-Agent por defecto de algunos clientes (error 1010) antes de llegar al Worker.
  const res = await fetch(`${url.replace(/\/$/, "")}/config`, { headers: { "User-Agent": "yala-deploy-guard" } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  config = await res.json();
} catch (e) {
  if (process.env.ALLOW_MANIFEST_DOWNGRADE === "1") {
    console.warn(`check-manifest-not-older: no pude leer ${url}/config (${e.message}); sigo por ALLOW_MANIFEST_DOWNGRADE=1`);
    process.exit(0);
  }
  console.error(`check-manifest-not-older: no pude leer ${url}/config (${e.message}). No despliego a ciegas.`);
  console.error("  Si de verdad hay que desplegar sin esta comprobación: ALLOW_MANIFEST_DOWNGRADE=1 npm run deploy:…");
  process.exit(1);
}

const decision = decideManifestGuard({ localPersonal, localGroups, config });
if (!decision.ok) {
  const detail = decision.downgrades.map((d) => `${d.channel} v${d.deployed} → v${d.local}`).join(", ");
  if (process.env.ALLOW_MANIFEST_DOWNGRADE === "1") {
    console.warn(`check-manifest-not-older: BAJAS el manifest (${detail}) (ALLOW_MANIFEST_DOWNGRADE=1).`);
    process.exit(0);
  }
  console.error(`check-manifest-not-older: este árbol trae un manifest más viejo que el desplegado (${detail}).`);
  console.error("  Los teléfonos en la versión nueva verían rechazadas o podadas sus filas. Despliega desde una");
  console.error("  rama con los manifests al día. Ver gateway/RUNBOOK.md, «manifest_version».");
  process.exit(1);
}
console.log(
  `check-manifest-not-older: OK (personal desplegado v${decision.deployed.personal}, este árbol v${localPersonal}; ` +
    `grupos desplegado v${decision.deployed.groups}, este árbol v${localGroups}).`,
);
