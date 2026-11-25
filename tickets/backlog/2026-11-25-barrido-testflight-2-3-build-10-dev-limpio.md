---
id: 2026-11-25-barrido-testflight-2-3-build-10-dev-limpio
status: in-progress
priority: high
area: "qa, release, testflight, nube-dev"
created: 2026-11-25
updated: 2026-11-25
source: "Encargo de Jürgen (25-nov, 12:27 Lima): barrido de QA, Yala 2.3 a TestFlight, dev limpio y Yala Dev desde cero en el iPhone 14"
---

# Barrido QA, Yala 2.3 a TestFlight y dev limpio en el iPhone 14

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
