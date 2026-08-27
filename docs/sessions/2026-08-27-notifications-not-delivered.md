# Sesión 2026-08-27 — «las notificaciones no llegan» (TestFlight)

Sesión VIVA. Solo hechos. Sin PASS, sin estado de build, sin versión-que-rompió inventada.

## Encargo

Owner (Jurgen, urgente): las notificaciones de Yala no llegan; toggles in-app en ON; el Focus de iOS
permite Yala; empezó a fallar en una versión **desconocida**; el binario en campo es **TF 2.1 build
12**. Implementar **solo** si se confirma la causa en el código.

Ticket: `tickets/in-progress/notifications-not-delivered-testflight.md` (slug asignado por Frank:
`notifications-not-delivered-testflight`).

## Resultado

**Causa: unknown.** No se confirmó en el código ninguna causa que tire TODAS o casi todas las
notificaciones con los toggles en ON sin depender de una precondición que no se puede verificar leyendo
el árbol. ⇒ **no se implementó fix** (regla del encargo). El ticket queda con el mapa medido, la lista
de descartes y cuatro hipótesis vivas, cada una con la señal de device que la confirma o la mata.

Alcance real de la sesión: revisión de código sobre `2.1`. **No se compiló ni se corrió la suite** —
el cambio es solo documentación. No se subió nada a TestFlight, no se tocó ningún tag, no se movió
`A7`/`M5`.

## Lo medido (resumen; las coordenadas completas están en el ticket)

1. **Solo `endOfDay`, `lunchTime` y `custom` se agendan de verdad en iOS.**
   `requiresDynamicContent` (`NotificationItem.swift:128-136`) es `true` para reportes,
   `scheduledPayments` y `groups`, y `NotificationService.swift:121-128` corta antes de agendar.
   Los tres estáticos **nacen en OFF** (`:411`, `:420`); el único `isActive: true` de fábrica es
   `scheduledPayments` (`:464`), que es dinámico. Lo demás sale con la app viva (bootstrap /
   foreground) o por `BGAppRefreshTask`. Excepción que sobrevive a cerrar la app: el canal agendado
   `spDailySummary_*`, horizonte 14 días.
2. **Existe UN solo gate común a los tres productores**: `isPersonalWipeArmed`
   (`NotificationService.swift:397-399`), evaluado en `:134`, `:231` y `:332`, **después** del check
   de permiso. Es el único predicado cuyo `true` apaga el 100 % de las entregas dejando la app con
   aspecto normal.
3. **El boot-hook que lo desarma puede abortar antes de desarmar** (`SwiftDataConfiguration.swift:616-620`,
   desarme en `:731-732`; gemelo secundario en `:841-846` / `:893`). Estado auto-perpetuante.
4. **El onboarding nunca pide el permiso** (`OnboardingView.swift:1937-1967`); solo 4 call-sites lo
   piden. El primer contextual **quema su flag antes** de decidir si se muestra
   (`NewTransactionViewModel.swift:954` antes de `:955`).
5. **Hallazgo lateral, no causa probada:** la heurística del reconciler
   (`AppBootstrapper.swift:2490`, `pending.count < activeItems.count`) compara magnitudes que cuentan
   cosas distintas — `pending` incluye hasta 14 summaries y las variantes por día de semana;
   `activeItems` incluye tipos dinámicos que nunca producen pending. El propio árbol ya la documenta
   como frágil en `SwiftDataConfiguration.swift:805-810`.

## Descartado con medición

`aps-environment` (production en Release) · `interruptionLevel` (**no existe** en el árbol) ·
categorías/threads (`categoryIdentifier`, `threadIdentifier`, `setNotificationCategories`,
`relevanceScore`: cero ocurrencias) · extensión Notification Service/Content (**no hay** target de
notificaciones: son `Yala`, `YalaTests`, `YalaUITests`, `YalaShare`, `YalaWidgetsExtension`) · gate de
Pro (cero referencias en el pipeline) · seam de UI test filtrado (`UITestHooks.isActive` es `false`
constante en Release) · bundle/App Group cruzado TF↔Dev · IDs de `BGTask` desalineados con
`Info.plist` · delegate no registrado · caché de autorización que miente (**no existe** ninguna key
de ese tipo; los cuatro consumidores leen `notificationSettings()` en vivo).

**Sobre la versión:** entre el bump de build 11 y el de build 12 hay **un** commit funcional
(`74ddaf01`, StoreKit/Pro + `Localizable.strings`), sin relación con notificaciones. Eso dice que
**build 12 no la introdujo** — no dice en qué build empezó. No se nombra ninguna.

## Lo que falta para poder decidir (device, minutos)

Cuatro señales que discriminan entre las hipótesis **sin escribir código**:

1. ¿El **widget** está congelado? Usa el mismo predicado que las notificaciones
   (`WidgetDataCache.swift:212`, `:230-231`) ⇒ congelado = `isPersonalWipeArmed` puesto.
2. ¿Aparece en el log del device (subsystem `com.yala`, categoría `CloudSync`) alguna de
   `CloudSignOut wipe ABORTED reason=store file deletion failed` o
   `CloudSecondary wipe ABORTED reason=store file deletion failed`? Ambas emiten fuera de `#if DEBUG`
   (`CloudSyncEngine.swift:400-402`, `:470-472`).
3. En Ajustes → Notificaciones → **Yala**: ¿están activos el estilo de alerta, el Centro y la Pantalla
   bloqueada? El código gatea solo por `authorizationStatus` y **no** mira esos sub-ajustes
   (`NotificationService.swift:223-228`). «Focus permite Yala» es otra cosa.
4. ¿Qué tipo exacto esperaba el owner, a qué hora, y con la app abierta o cerrada?

Si alguna confirma la causa, el ticket recibe su sección `Causa (código)` con `fichero:línea` y
entonces —y solo entonces— el fix mínimo con tests (Swift Testing).

## Estado al cerrar la sesión

- Ticket creado en `tickets/in-progress/`.
- `docs/TICKETS.md`: fila añadida, índice 61 → 62 y línea de counts corregida a los valores medidos
  (decía 60 con 61 ficheros en disco; índice y disco sí coincidían).
- Esta nota.
- **Sin cambios bajo `Yala/`** ⇒ no aplica actualizar `qa/coverage-index.json`.
- Sin fix, sin tests nuevos, sin QA, sin upload.
