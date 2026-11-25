---
id: 2026-11-25-barrido-testflight-2-3-build-10-dev-limpio
status: done
priority: high
area: "qa, release, testflight, nube-dev"
created: 2026-11-25
updated: 2026-11-25
source: "Encargo de Jürgen (25-nov, 12:27 Lima): barrido de QA, Yala 2.3 a TestFlight, dev limpio y Yala Dev desde cero en el iPhone 14"
---

# Barrido QA, Yala 2.3 a TestFlight y dev limpio en el iPhone 14

## Resultado (25-nov, 16:30 Lima)

- **Yala 2.3 (10) en TestFlight**: archivada en la Mini sobre 2.3 con los cuatro PR dentro (build 9, bugs de cuenta,
  «Esto leí», Estadísticas), árbol del commit del número de build. Subida con `asc`, `uploads list` en `COMPLETE`, build
  `VALID` y `IN_BETA_TESTING` para «Test interno». No se envió a revisión. Notas «Qué probar» (es-MX) desde
  `docs/qa/testflight-2-3-10/notas-que-probar.txt`. Preflight en verde; dSYM a Sentry por el post-action (3 ficheros; el
  aviso de commits sin asociar es el de siempre).
- **iCloud**: el esquema vivo de Producción coincide con el repo; `pendingProductionDeploy` vacío. Nada que desplegar.
- **Barrido**: `docs/qa/barrido-2-3-antes-build-10/lista.md`. 22/22 de interfaz y 92/92 unitarias de lo nuevo; suite
  unitaria completa 16.331 en verde (los 16 restantes, pruebas de cableado corridas contra un árbol sin los PR: 99/99 sobre
  el commit final). Hallazgo de texto grande en «Esto leí» a una card del tablero.
- **Dev limpio**: `docs/qa/dev-limpio-2-3-10/README.md`. Supabase staging sin cuentas de Google ni Apple (quedan los 4
  sintéticos), restos huérfanos de D1/KV de staging fuera, entorno Development de los dos contenedores dev reseteado.
- **iPhone 14**: Yala Dev 2.3 (10) del mismo árbol, desinstalada e instalada de cero con `devicectl`; abre en la bienvenida.
- **Guía de novedades** al día con la build 10 en su URL de siempre.

## Paso 0 — decisiones

| # | Decisión | Quién | Por qué |
|---|---|---|---|
| 1 | **No se sube hasta que entren a 2.3 los cuatro PR abiertos** (build 9, bugs de cuenta, «Esto leí», Estadísticas). Se compila sobre 2.3 al día. | Jürgen, 12:33 | Los arreglos de cuenta son lo que va a probar en la bienvenida. |
| 2 | El barrido corre sobre una rama **local** con 2.3 + los cuatro PR (`barrido-integrado-local`, no se empuja). | Frank | Probar ya lo que va a llevar la build, sin esperar a los merges. |
| 3 | En Supabase de desarrollo se borran **las cuentas de Google y Apple**; los **4 usuarios sintéticos** de las pruebas del servidor (`…@test.yala`) **se quedan**. `auth.users` queda en 4, no en 0. | Frank (repite la decisión de Jürgen del 16-nov) | Son los de las pruebas del gateway contra staging; uno entró hoy mismo. Borrarlos rompe esas pruebas hasta recrearlos. No son cuentas de la app. |
| 4 | Las 116 llaves de App Attest de la D1 de staging se quedan. | Frank | Son de dispositivo, no de usuario, y ninguna tiene Pro de prueba. Una instalación nueva genera la suya. |
| 5 | iCloud dev: **reset del entorno Development** de `iCloud.com.jurgenschmidt.yala.dev` y `…groups.dev`. | Frank | Medido antes: el esquema Development era idéntico al de Producción en los dos, así que no había nada que reimportar. |
| 6 | El faro de iCloud clave-valor de Yala Dev (en el Apple ID del iPhone 14) no se puede borrar desde fuera. | Frank | La app lo limpia sola cuando comprueba que la cuenta ya no existe (regla del faro). Se avisa en los flujos a probar. |
| 7 | Número de build: el siguiente al último de App Store Connect (se mide al subir). | Encargo | — |
