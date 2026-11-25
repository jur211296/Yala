---
id: 2026-11-24-barrido-y-testflight-2-3-build-9
status: blocked
priority: high
area: "qa, release, testflight"
created: 2026-11-25
updated: 2026-11-25
source: "Encargo de Jürgen (24-nov, 19:32 Lima): barrido de QA y subida a TestFlight de la 2.3 con lo de hoy (build 9)"
---

# Barrido de QA y Yala 2.3 (9) a TestFlight

## Estado (25-nov, 04:40 Lima)

- **Barrido hecho**: `docs/qa/barrido-2-3-antes-build-9/lista.md`. Lo nuevo desde la build 8 funciona en el iPhone 14 y
  en el simulador; 11 pruebas de interfaz de lo nuevo en verde; Panel = Flujo de caja = widget.
- **Subida parada**: la build escribe `CD_InboxDraft.CD_joinRecordRaw` (lote 2 de la Bandeja sin duplicados) y el
  esquema de iCloud de Producción no lo tiene (medido con `cktool export-schema --environment production`, 03:34). Sigue
  en `PersonalCloudKitSchemaParityTests.pendingProductionDeploy` y `scripts/asc-preflight.sh` lo frena. Desplegarlo
  es de Dan con el OK de Jürgen (CloudKit Console → Deploy Schema Changes, solo altas).
- **Preparado en la rama**: número de build 9 (versión 2.3), notas de prueba (`docs/qa/testflight-2-3-9/`) y el delta
  de la guía de novedades (`docs/guias/novedades-2-3/delta_2026_11_25.json`, sin aplicar: la guía se pone al día
  cuando la build 9 exista).

## Para continuar, cuando el campo esté en Producción

1. Re-exportar `Cloudkit Schemas/yala-production.ckdb` y `yala_dev-production.ckdb` (`cktool export-schema`) y vaciar
   `pendingProductionDeploy` (molde: el PR que re-exportó los esquemas tras el límite de la tarjeta).
2. `git fetch` + rebase sobre `origin/2.3`; si entró algo nuevo de la app, barrido corto de eso.
3. Archivar `Yala` (Release) en la Mini dentro del tmux de la sesión, `scripts/asc-preflight.sh`, subir con `asc`,
   sondear `asc builds uploads list` hasta `COMPLETE`, dSYM a Sentry (`scripts/sentry-subir-dsym.sh`), notas «Qué
   probar» y grupo interno.
4. Aplicar el delta a la guía de novedades y publicarla en su URL de la Mini.
