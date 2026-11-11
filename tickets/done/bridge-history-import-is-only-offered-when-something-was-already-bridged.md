---
id: bridge-history-import-is-only-offered-when-something-was-already-bridged
status: done
priority: medium
area: groups, bridge
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
qa-status: passed
qa-date: 2026-11-10
qa-notes: xcuitest: GroupsBridgeHistoryImportUITests
---

# «Importar todo el historial» solo se ofrece si ya había movimientos reflejados

Leído en el código, **no probado**: en Ajustes de Grupos, al activar «Reflejar en tus cuentas», la hoja que ofrece
importar el historial solo se abre si `hasBridgedTransactions()` es verdad (`GroupsGlobalSettingsView.swift:218-224`). La
primera vez que alguien lo activa no hay nada reflejado, así que justo entonces no se le ofrece. Por grupo pasa igual
(`GroupSettingsView.swift:565-578`). Parece la condición al revés.

Cómo verificarlo: un grupo con gastos y el puente nunca activado; activarlo y ver si sale «Importar todo el historial».

## Resuelto (2026-11-10, lote 01 de las mejoras necesarias 2.3)

Medido en el simulador: con gastos de grupo y nada reflejado, encender el puente en Ajustes de Grupos no ofrecía importar
el historial. Ahora la hoja sale si hay gastos que importar (`BridgeToggleSheetLogic`), en Ajustes de Grupos y en los de
cada grupo (antes, por grupo, no salía nunca; cancelarla deja el grupo apagado otra vez). La hoja de desactivar no cambia.
Lo fija `GroupsBridgeHistoryImportUITests` (sin el arreglo no sale la hoja). Evidencia: `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/antes-5-puente-sin-hoja.png`,
`~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/despues-5-puente-importar-historial.png`.
