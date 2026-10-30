---
id: import-failure-leaves-unsaved-inserts-in-the-main-context
status: backlog
priority: low
area: "import"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H6 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Si el import falla al final, lo insertado se queda sin deshacer

**Versión propuesta: 2.2.** Baja, pero es una línea por rama: barata, 2.2. La decide Jürgen. Card: `a27x`.

## Qué ve el usuario

Raro: si el guardado falla, las categorías, etiquetas o movimientos que el import ya había insertado se quedan en memoria y los guarda la siguiente pantalla que guarde.

## Evidencia

`ImportIntroSheet.swift:684-707` y `:797-821` insertan y guardan en el contexto principal; los `catch` (`:760-777`, `:870-887`) cierran la hoja sin `rollback()`. La vista previa sí lo hace (`ImportPreviewService.swift:90`).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H6.

## Propuesta

`modelContext.rollback()` en los dos `catch`.

## Criterio de hecho

- [ ] Test con un guardado que falla: tras el error, el contexto no tiene cambios pendientes.
