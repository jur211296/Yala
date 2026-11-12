---
id: can-run-domain-reads-the-filler-phase-before-the-journal-connects
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-10-25
updated: 2026-10-25
source: "review adversarial del lote 12.2 (card jbjj), inferido leyendo el código"
---

# Antes de conectar el journal, el candado del motor lee la fase de relleno `notStarted`

## Qué pasa

`MigrationPhaseStore.currentPhaseRead` devuelve `.phase(.notStarted)` mientras no hay journal (`configure` corre en el paso
11 del arranque). El primer `.active` llega antes, y `GroupsSyncClient.startIfEligible` pregunta a
`CloudSyncRuntime.canRunDomain()`. Con `.cloud`, el espejo apagado y una fase transitoria de verdad (una vuelta a iCloud a
mitad, por ejemplo), el candado contesta «sí» por la fase de relleno: Grupos decide ir a caballo del motor personal y no
levanta su loop, y el motor personal, ya con el journal, no arranca. Grupos se queda sin sincronizar hasta el siguiente
primer plano o hasta abrir su pestaña.

La card jbjj solo calló el canario en esa ventana (`MigrationRuntimeGate.isStorageModePairViolation` exige
`isJournalConnected`). La decisión del candado no se tocó a propósito: devolver `false` sin journal haría que Grupos levante
su loop en el arranque normal y que después el motor personal lo lleve también (dos loops).

## Qué haría falta

Un tercer valor («sin journal todavía») que Grupos lea como «decide luego», o re-evaluar el modo de Grupos cuando el
journal se conecta. Medir antes en el simulador con una fase transitoria sembrada.
