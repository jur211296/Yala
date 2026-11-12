---
name: project-5xj4-espera-la-nocturna-con-marcador
description: Por qué la card 5xj4 (formulario a medias vuelve vacío en el CI) sigue en in-progress tras el PR #724 (2026-11-01)
metadata:
  type: project
---

La card `tablero-un-nuevo-registro-a-medias-vuelve-vacio-5xj4` queda en `in progress` (frank) esperando la primera
nocturna roja con el marcador `uitest_lifecycle` del PR #724 dentro.

**Why:** su «hecha cuando» pide la causa medida en el CI y tres noches verdes; en local solo cayó 1 de 27 (mismo pid,
misma escena, formulario rehecho 1→3, el contenido de la hoja nace de nuevo sin cerrarse) y la carga de CPU no lo
reproduce. Se descartó lanzar la nocturna por dispatch: ~3,5 h de los macOS del CI.

**How to apply:** al retomarla, `gh run list --workflow qa.yml --event schedule` y leer en la tanda que lleve
`ExternalEntryForeignSheetUITests` el mensaje «Ciclo de vida — al arrancar: …; al volver: …» (trae la traza de pestaña,
fase y hoja). No reabrir hipótesis de proceso/escena si el marcador dice que no cambiaron. Ticket:
`tickets/in-progress/half-filled-form-loses-its-amount-after-an-external-entry-on-ci.md`.
