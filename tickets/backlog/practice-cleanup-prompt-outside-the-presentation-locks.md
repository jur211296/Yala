---
id: practice-cleanup-prompt-outside-the-presentation-locks
status: backlog
priority: medium
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: inventario del ticket notices-come-out-one-after-another-by-priority (sesión S27f, leído en el código, sin medir en simulador)
---
# «¿Era de prueba?» se presenta fuera de los candados de presentación

Qué ve la persona: tras su primer registro, presupuesto o pago, la pregunta «¿Era de prueba?» puede salir a la vez que otro aviso, o no salir (dos prácticas seguidas pierden la primera).

Leído: en el Panel, `practiceCleanupItem` y `showPracticeAlert` no están en `PanelSheetState.hasActivePresentation` y la alerta se enciende un render después (`PanelSheetsModifier`), así que otro drenaje de `.panel` puede presentar en ese hueco. En Planificación, `PracticeCleanupPrompt.consume()` enciende la alerta en el `onDismiss` del editor sin router ni sonda: un aviso diferible retenido que vuelve a mirar cada 300 ms puede salir en el hueco. `SetupChecklistManager.markCompleted` pisa `pendingPracticeCleanup` (una sola casilla global con dos consumidores).

Hecho cuando: la pregunta cuenta como presentación en los dos sitios y no se pierde con dos prácticas seguidas; con XCUITest.
