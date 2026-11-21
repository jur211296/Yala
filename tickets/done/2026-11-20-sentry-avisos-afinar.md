---
id: 2026-11-20-sentry-avisos-afinar
status: done
priority: medium
area: stability
created: 2026-11-20
updated: 2026-11-21
source: decisión de Jürgen del 2026-11-20 17:19 («Sí, encola la sesión para afinar Sentry al final»)
---

# Afinar los avisos de Sentry: segundos, cuelgues agrupados, usuario anónimo, TestFlight y alertas

Jürgen preguntó si los avisos de Sentry llegan completos y son útiles. Medido el 2026-11-20 sobre YALA-IOS-16 y los
issues recientes: el stack, la pantalla (`screen`), la versión, el aparato y la memoria llegan bien. Fallaban cinco
cosas: los segundos de un cuelgue salían como «[monto]»; unos diez App Hang de un evento cada uno eran el mismo
problema; «usuarios afectados» era siempre 0; TestFlight figuraba como `production`; y no había commits por release.
De alertas, solo la regla por defecto «Send a notification for high priority issues».

## Qué quedó (2026-11-21)

1. **Segundos visibles.** `ErrorReportScrubLogic`: la regla de importes no tapa la cifra a la que siguen «seconds» o
   «and <cifra> seconds». Un importe al lado se sigue tapando. Cierra `sentry-scrub-turns-hang-durations-into-amounts`.
2. **Usuario anónimo.** UUID aleatorio por instalación (`ErrorReportContextLogic.installID`, clave
   `sentry.anonymousInstallID` de `UserDefaults.standard`), con `SentrySDK.setUser`. `beforeSend` deja del usuario
   solo ese id. No sale de la cuenta, ni de iCloud, ni del correo; una reinstalación da otro.
3. **TestFlight aparte.** `environment` = `testflight` si el recibo se llama `sandboxReceipt` (la misma comprobación
   que el SDK usa para su `build_type`), `production` si no. Cuelgues y watchdog se vigilan en los dos.
4. **Cuelgues agrupados**, con reglas de fingerprint del proyecto `yala-ios` (abajo).
5. **Commits por release.** `scripts/sentry-subir-dsym.sh` corre `sentry-cli releases set-commits --local` con el
   nombre de release del archivado. No pide credenciales nuevas. El «commit sospechoso» necesita además conectar
   GitHub en Sentry: queda como acción de Jürgen.
6. **IP fuera** en el proyecto (`scrubIPAddresses`).

## Fingerprint: criterio

Va en el servidor y no en `beforeSend`: la app de la App Store va sin símbolos y en el teléfono los frames no tienen
nombre de función; Sentry los pone al procesar con los dSYM.

Huella = `app-hang` + tipo de cuelgue (bloqueo total, parcial o fatal) + el trabajo que bloqueó el hilo principal. El
getter de la punta (`date`, `amountInPreferredCurrency`, `excludeFromStatistics`…) cambia según el milisegundo de la
muestra y no es la causa. La pantalla no entra: el recálculo del Panel salió con `screen: records` (YALA-IOS-15) y
`panel`. Gana la primera regla que casa:

```
error.type:"*App Hang*" stack.function:"*ErrorReportingService.blockMainThreadForSentryTest*" -> app-hang, {{ error.type }}, prueba-de-sentry
error.type:"*App Hang*" stack.function:"*CashFlowPlanViewModel.recalculate*" -> app-hang, {{ error.type }}, flujo-de-caja-recalculo
error.type:"*App Hang*" stack.function:"*PanelViewModel.scheduleRecalculation*" -> app-hang, {{ error.type }}, panel-recalculo
error.type:"*App Hang*" stack.function:"*TrendsTabView.*" -> app-hang, {{ error.type }}, estadisticas-recalculo
error.type:"*App Hang*" stack.function:"*WidgetDataCache.*" -> app-hang, {{ error.type }}, widgets-cache
error.type:"*App Hang*" stack.function:"*CloudSyncEngine.reresolveDanglingRefs*" -> app-hang, {{ error.type }}, nube-refs-colgadas
error.type:"*App Hang*" stack.function:"*CloudSyncEngine.applyPage*" -> app-hang, {{ error.type }}, nube-aplicar-pagina
```

Cómo quedarían los issues de hoy (las reglas solo valen para eventos nuevos; los issues viejos no se funden solos):

| Grupo nuevo | Issues de hoy |
|---|---|
| Panel recalculando (parcial) | YALA-IOS-K, N, T, X, Z, 10, 12, 14, 15 |
| Flujo de caja recalculando (parcial) | YALA-IOS-P, R, W, 11 |
| Estadísticas recalculando (parcial) | YALA-IOS-S, V |
| Caché de widgets (parcial) | YALA-IOS-M, 16 |
| Nube aplicando una página (total) | YALA-IOS-6, 7, 8, J |
| Nube aplicando una página (parcial) | YALA-IOS-5 |
| Nube, refs colgadas (total) | YALA-IOS-13 |
| Sin regla: siguen por stack | YALA-IOS-2, 4, 9, A, D, G, Q, Y |

Los ocho sin regla no traen un trabajo propio reconocible (`YalaApp.$main`, solo frames del sistema, `mach_msg`) o
son el único de su clase (`ProfileView`, la hoja de detalle del Flujo de caja).

## Alertas aplicadas (workflows de Sentry, detector «Issue Stream» de `yala-ios`)

| Nombre | Dispara | Filtro | Cada cuánto, como mucho |
|---|---|---|---|
| [App Store] Crash o error nuevo: aviso al momento | issue nuevo | entorno `production`, tipo que no empieza por «App Hang» | 5 min |
| [App Store] Cuelgue frecuente: 5 eventos o 2 usuarios en 24 h | cada evento | `production`, «App Hang…», >4 eventos en 1 d **o** >1 usuario en 1 d | 24 h |
| [App Store] Vuelve tras resolverse (regresión) | regresión | `production` | 60 min |
| [TestFlight] (las tres) | igual | atributo `environment = testflight` | igual |

Un «Fatal App Hang» (la app murió colgada) cuenta como crash, no como cuelgue. Los de TestFlight filtran por atributo
porque el entorno `testflight` no existe en Sentry hasta su primer evento. La regla por defecto de `yala-ios` quedó
**desactivada** (no borrada); la «copia» era la del gateway, que no se toca.

## Verificado

Cuelgue de prueba con `-sentry-test-hang` (Yala Dev, simulador): YALA-IOS-17, «App Hang Fully Blocked: App hanging
between 4.5 and 5.3 seconds.», `environment: development`, usuario `411FFE60-…` (1 usuario afectado), huella
`app-hang · App Hang Fully Blocked · prueba-de-sentry` según `grouping-info`. `testflight` se verifica con la próxima
build de TestFlight.
