---
id: 2026-11-24-barrido-y-testflight-2-3-build-9
status: done
priority: high
area: "qa, release, testflight"
created: 2026-11-25
updated: 2026-11-25
source: "Encargo de Jürgen (24-nov, 19:32 Lima): barrido de QA y subida a TestFlight de la 2.3 con lo de hoy (build 9)"
---

# Barrido de QA y Yala 2.3 (9) a TestFlight

## Resultado (25-nov, 06:55 Lima)

- **Yala 2.3 (9) en TestFlight**: archivada en la Mini desde `2.3` en `ed09674d0` (CI de 2.3 en verde), subida con `asc`,
  procesada `VALID` (06:37) y en `IN_BETA_TESTING` para el grupo «Test interno», que recibe todas las builds. No se envió
  a revisión ni al grupo externo. Notas «Qué probar» (es-MX) cargadas desde `docs/qa/testflight-2-3-9/notas-que-probar.txt`.
- **iCloud**: Dan desplegó `CD_InboxDraft.CD_joinRecordRaw` en Producción en los dos contenedores; medido con `cktool`
  a las 06:24. Los dos `*-production.ckdb` se re-exportaron (solo entra ese campo) y `pendingProductionDeploy` quedó
  vacío; `scripts/asc-preflight.sh` en verde sobre el archivado.
- **dSYM en Sentry** por el post-action del scheme (3 ficheros). El aviso de commits sin asociar es el mismo de la build 8.
- **Smoke en el iPhone 14** (Yala Dev): abre, Panel y Bandeja bien. Sin cambios de la app desde el barrido: no hizo falta
  barrido corto.
- **Guía de novedades** al día con la build 9, en su URL de siempre (`docs/guias/novedades-2-3/README.md`).
- **Yala Dev en el iPhone personal de Jürgen** (pedido en la sesión): instalada desde el mismo código, para probar Dev y
  TestFlight en paralelo.

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
