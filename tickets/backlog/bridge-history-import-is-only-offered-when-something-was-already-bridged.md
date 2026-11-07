---
id: bridge-history-import-is-only-offered-when-something-was-already-bridged
status: backlog
priority: medium
area: groups, bridge
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# «Importar todo el historial» solo se ofrece si ya había movimientos reflejados

Leído en el código, **no probado**: en Ajustes de Grupos, al activar «Reflejar en tus cuentas», la hoja que ofrece
importar el historial solo se abre si `hasBridgedTransactions()` es verdad (`GroupsGlobalSettingsView.swift:218-224`). La
primera vez que alguien lo activa no hay nada reflejado, así que justo entonces no se le ofrece. Por grupo pasa igual
(`GroupSettingsView.swift:565-578`). Parece la condición al revés.

Cómo verificarlo: un grupo con gastos y el puente nunca activado; activarlo y ver si sale «Importar todo el historial».
