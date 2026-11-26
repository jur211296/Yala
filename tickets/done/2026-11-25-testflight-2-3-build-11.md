---
id: 2026-11-25-testflight-2-3-build-11
status: done
priority: high
area: "release, testflight"
created: 2026-11-26
updated: 2026-11-26
source: "Encargo de Jürgen (25-nov, 21:51 Lima): otra subida a TestFlight después del barrido de la build 11"
---

# Yala 2.3 (11) a TestFlight

## Resultado (26-nov, Lima)

- **Yala 2.3 (11) en TestFlight**: archivada en la Max sobre `2.3` con el PR de la oferta Pro y el mazo centrado dentro
  (el árbol de la app es idéntico al de `2.3` tras su merge, comprobado con `git diff`). Subida con `xcodebuild
  -exportArchive` y la llave de `asc`, procesada `VALID` a las 03:19 y en `IN_BETA_TESTING` para «Test interno». No se
  envió a revisión. Notas «Qué probar» (es-MX) desde `docs/qa/testflight-2-3-11/notas-que-probar.txt`, verificadas
  literal (App Store Connect borra lo que va entre `<` y `>`: las notas no llevan ángulos).
- **Preflight** en verde; **dSYM a Sentry** por el post-action (3 ficheros; el aviso de commits sin asociar es el de
  siempre).
- **iCloud**: `yala` y `yala_dev` de Producción idénticos al repo (`cktool export-schema`, 26-nov, 02:18).
- **Guía de novedades** al día con la build 11 en una URL nueva: https://claude.ai/artifact/NqVZFcKkUpXLP6p44QFtzJ
  (pública con enlace). 16 ítems nuevos, 3 cambios, 7 capturas nuevas.

## Paso 0 — decisiones

| # | Decisión | Quién | Por qué |
|---|---|---|---|
| 1 | La build espera al PR de la oferta Pro y el mazo centrado. Estaba en conflicto y sin sesión: se mezcló `2.3` en su rama (solo chocaba el índice de tickets, resuelto por el merge driver) y se dejó entrar con su CI. | Encargo | «La build tiene que llevar todo lo de 2.3»; es lo que Jürgen va a probar. |
| 2 | Número de build: 11. App Store Connect tenía la 2.3 (10) como la última. | Medido | — |
| 3 | iCloud: no hay alta pendiente. `yala` y `yala_dev` de Producción son idénticos al repo. `groups` y `groups_dev` de Producción no tienen `SplitMember.clientCapability` ni `clientCapabilityAt`, que sí están en el repo; ningún código los usa desde que se retiró la migración de grupos vivos a la nube (julio). | Frank | El encargo pide los campos del modelo de hoy, y la app no escribe esos dos. No se re-exporta: el esquema del repo no lo lee ninguna prueba ni el preflight. |
| 4 | La guía de novedades se publica en una URL nueva, desde la Max. | Frank | Las dos URL anteriores son de otra cuenta (la de la Mini y la de la Max del 23-nov) y esta sesión solo puede leerlas. La colección `notas` de la guía de la build 10 estaba vacía: no se pierden notas. |
| 5 | Capturas nuevas de la guía: las de las sesiones del 25 y 26-nov (lotes 2 y 3, y el barrido de la oferta y el mazo), del mismo código que la build. | Frank | Son del simulador con el código que lleva la build; repetirlas no aporta y ocupa el simulador. |
| 6 | No se limpia la base de desarrollo ni se reinstala Yala Dev. | Encargo | Jürgen no lo pidió. |

## Lo que va al iPhone de Jürgen

La lista del barrido (`docs/qa/barrido-2-3-antes-build-11/lista.md`): el mes gratis real con una cuenta de Sandbox sin
prueba usada, y Primeros pasos desde cero con cuenta nueva en «Solo gastos» y en «Gastos e ingresos».
