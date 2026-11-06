---
id: groups-no-session-loss-exit-test-fails-in-the-full-suite
status: backlog
priority: low
area: "tests, cierre de sesión"
created: 2026-11-05
updated: 2026-11-05
source: "gate del lote «Cerrar sesión con cambios» (card 7e60), 2026-11-05"
---

# Un test del cierre sin sesión falla a veces en la suite completa y nunca a solas

## Lo medido

- `GroupsNoSessionLossExitTests` («MUTACIÓN: sin sesión, el aviso cuenta las filas vivas y ofrece perderlas; el camino
  por defecto no pierde nada», `YalaTests/CloudSync/GroupsOutboxOwnershipTests.swift`) cayó 1 de 3 corridas completas de
  `YalaTests` en el simulador iPhone 17 Pro (iOS 27.2), sobre la rama del lote.
- El fallo: `Expectation failed: !StorageModePersistence.isSignOutWipeArmed()` con el valor `false` en la impresión. El
  flag estaba armado al evaluarse y desarmado al imprimirse: algo lo escribe en `UserDefaults.standard` a la vez.
- A solas: 3 de 3 en verde. Las otras dos corridas completas: verde.

## Inferido (sin medir)

Otra suite deja un cierre en vuelo (una `Task` del coordinador) que arma o desarma el borrado en `UserDefaults.standard`
mientras corre esta. No lo introduce el lote: no toca el flag del arm.

## Siguiente

Medir qué suite corre justo antes en la corrida roja (orden del `.xcresult`) y aislar el flag en el test
(`UserDefaults` propio o esperar a que el coordinador vuelva a reposo antes de leerlo).
