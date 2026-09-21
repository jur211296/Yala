---
id: restore-back-and-reenter-closes-the-live-session-window
status: backlog
priority: high
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-20
source: "review adversarial (lente de concurrencia y ciclo de vida) de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-20"
---

# Salir de Restaurar y volver a entrar apaga la ventana del intento que sigue vivo

## El problema, en lenguaje de usuario

Toco «Restaurar desde iCloud», veo la barra unos segundos, me lo pienso y toco atrás. Vuelvo a
entrar y la búsqueda empieza otra vez. Minuto y medio después, mientras mi histórico está bajando,
la app vuelve a comportarse como si no hubiera ningún restore en marcha — y el guard de frontera de
cuenta se cierra sobre el dueño legítimo con su propio import a medias.

## Medido (2026-09-20)

El latch de la sesión de restauración es **asimétrico**:

- `Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift:39` — el encendido es idempotente:
  `guard restoreStartedAt == nil else { return }`. La segunda entrada NO reabre la ventana, hereda
  la de la primera.
- `:51` — el apagado es **incondicional**: `restoreStartedAt = nil`. Lo llama cualquier flujo que
  termine, incluido uno abandonado.
- `Yala/Services/iCloudSyncService.swift:538-560` — `forceFetchAndWait` resuelve su
  `withCheckedContinuation` solo por la notificación o por su `Task { sleep(timeout) }` interno:
  **no observa cancelación**. Un `runTask` cancelado sigue clavado ahí hasta agotar el tope.
- `Yala/App/Views/Onboarding/RestoreProgressView.swift` — `noteRestoreFinished()` va antes del
  `guard !Task.isCancelled`, a propósito y con su test
  (`ICloudRestoreSignalWiringTests`): así un desmontaje no se lleva el apagado por delante. Esa
  decisión es correcta para UN flujo y es justo la que produce este defecto con DOS.

Secuencia: entrar (t=0, ventana abierta) → atrás a los 5 s (el `runTask` queda cancelado pero
dentro de la continuation) → volver a entrar a los 10 s (`noteRestoreStarted` es no-op) → a t≈90 s
el `runTask` abandonado despierta y apaga la ventana del flujo vivo.
`ICloudRestoreInProgressLogic.swift:71` la lee `false` en el acto.

## Por qué sube de prioridad ahora

Es anterior al ticket del que sale, pero ese cambio **empuja justo ese gesto**: el estado nuevo
`.importIncomplete` dice «vuelve a buscar en un momento», y salir y volver a entrar en esa pantalla
es gratis.

## Criterios de aceptación

- [ ] Un flujo abandonado no apaga la ventana de otro que sigue vivo.
- [ ] La simetría queda declarada: o el encendido cuenta entradas, o el apagado se acota al flujo
      que lo encendió (un token por flujo es el molde barato).
- [ ] La garantía que `ICloudRestoreSignalWiringTests` ya protege —el apagado antes del guard de
      cancelación— sigue en pie por su motivo.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale.
- `restore-empty-state-resolution-cannot-be-cancelled` — el otro «la cancelación no cancela» de la
  misma pantalla.
