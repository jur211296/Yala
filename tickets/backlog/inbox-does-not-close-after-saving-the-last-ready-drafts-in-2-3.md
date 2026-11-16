---
id: inbox-does-not-close-after-saving-the-last-ready-drafts-in-2-3
status: backlog
priority: medium
area: "bandeja, 2.3"
created: 2026-11-11
updated: 2026-11-11
source: "gate del merge corto de 2.2 en 2.3 (lote 2.3 de Grupos «no tirar el gasto a medias»), 2026-11-11"
---

# En 2.3, la Bandeja ya no se cierra sola al guardar los últimos borradores con «Guardar los listos»

## El problema, en lenguaje de usuario

Con dos borradores completos en la Bandeja, «Guardar los listos» los guarda y enseña la pantalla final. Al volver, la
Bandeja debería cerrarse sola porque ya no queda nada pendiente (como en 1.0 y en 2.2). En 2.3 se queda abierta.

## Lo medido

- `InboxCrudUITests.test_saveReadyButton_savesEveryCompleteDraftAfterConfirming` cae en `InboxCrudUITests.swift:345`
  («Sin borradores pendientes, la Bandeja no se cerró sola al volver de la pantalla final»).
- **En `origin/2.3` sin el merge de 2.2** (árbol aparte, `9cbd645691`): rojo, 1 de 1. **Sobre el merge**: rojo, 3 de 3.
  Las corridas se hicieron con el simulador libre (el centinela confirmó que no hubo nadie más).
- **En 2.2** pasa: nocturna del 11-nov sobre `d1c480b3b9` (`gh run view 43055522639`, tanda 8, 36 s).
- El merge no toca lo que decide el cierre (`InboxView.dismissIfNoPendingDrafts` → `viewModel.hasPendingDrafts`).

## Por dónde mirar (inferido, sin medir)

Los cambios de 2.3 en la Bandeja que no están en 2.2: `e8fa1fc7ec` (lote 03 de mejoras necesarias: «Guardar los N
listos» revisa posibles duplicados; pendientes viejos) y `40aef65d10` (texto grande). El primero toca el flujo de
«Guardar los listos» y su pantalla final.

## Criterio de terminado

El XCUITest de arriba en verde sobre 2.3, sin tocar su aserción.
