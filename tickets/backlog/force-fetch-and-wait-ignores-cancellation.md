---
id: force-fetch-and-wait-ignores-cancellation
status: backlog
priority: medium
area: "icloud, sync, restore"
created: 2026-09-21
updated: 2026-09-21
source: "Paso 0 (D5) y review adversarial de `restore-back-and-reenter-closes-the-live-session-window`, 2026-09-21"
---

# La espera del import de iCloud no se entera de que la cancelaron

## El problema, en lenguaje de usuario

Salgo de una pantalla que está esperando a iCloud. Por debajo, esa espera sigue viva hasta minuto y
medio después: la app sigue contando mis movimientos cada seis décimas, con la pantalla ya cerrada
y yo en otro sitio. En un teléfono ocupado se nota.

## Medido (2026-09-21)

- `Yala/Services/iCloudSyncService.swift:545-571` — `forceFetchAndWait` resuelve su
  `withCheckedContinuation` solo por la notificación de CloudKit o por su `Task { sleep(timeout) }`
  interno: **no observa cancelación**. Un `Task` cancelado sigue clavado ahí hasta agotar el tope
  (15 s desde el arranque de la app, 90 s desde el restore), reteniendo un observer de
  `NotificationCenter` y un `Task` de sleep.
- `Yala/App/Views/Onboarding/RestoreProgressView.swift` — su `refresher` es un `Task {}` **no
  estructurado**, así que **no hereda la cancelación** de `runTask`: solo lo para el
  `refresher.cancel()` que va DESPUÉS de la espera. Con la vista desmontada sigue haciendo
  `modelContext.iCloudAccountSummary(...)` en el MainActor cada 0,6 s — unos 150 fetches sobre 5+
  entidades, escribiendo el `@State` de una vista muerta.

## Por qué NO se arregló en el ticket del que sale

Aquel ticket cerró el daño visible (un flujo abandonado ya no apaga la ventana de sesión de otro
vivo) con un token por intento, y además dejó de montar la espera en los caminos que no importan
nada. Lo que queda es coste, no corrupción. Y la primitiva la usa el ARRANQUE de la app
(`AppBootstrapper`, dos call-sites) además del restore y de `GroupsBridgeRestoreConvergence`: su
modo de fallo al reescribirla es **crash** (doble `resume` de una `CheckedContinuation`) o **cuelgue**
(ninguno), que es peor que el defecto. Merece su propio ciclo.

## Criterios de aceptación

- [ ] Cancelar el `Task` que espera corta la espera, sin doble `resume` y sin dejarla sin resolver.
      El caso del `Task` YA cancelado al entrar cuenta.
- [ ] El `refresher` de `RestoreProgressView` para cuando para su padre.
- [ ] Los llamadores de `forceFetchAndWait` y de `waitForImportQuiescence` siguen comportándose igual
      cuando nadie cancela — `AppBootstrapper` (×2), `RestoreProgressView`, `ContentView` (×2),
      `GroupsBridgeRestoreConvergence`.
- [ ] Un test que CUELGUE en vez de fallar es un rojo mal leído: el caso de la cancelación lleva tope.

## Relación con otros tickets

- `restore-back-and-reenter-closes-the-live-session-window` — de donde sale (Paso 0, D5).
- `restore-empty-state-resolution-cannot-be-cancelled` — el otro «la cancelación no cancela» de la
  misma pantalla, en otra función.
