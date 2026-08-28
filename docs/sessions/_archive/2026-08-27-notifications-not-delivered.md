# Sesión 2026-08-27 — «las notificaciones no llegan» (TestFlight)

Sesión VIVA. Solo hechos. Sin PASS, sin estado de build, sin versión-que-rompió inventada.

## Encargo

Owner (Jurgen, urgente): las notificaciones de Yala no llegan; toggles in-app en ON; el Focus de iOS
permite Yala; empezó a fallar en una versión **desconocida**; el binario en campo es **TF 2.1 build
12**. Implementar **solo** si se confirma la causa en el código.

Ticket: `tickets/done/notifications-not-delivered-testflight.md` (slug asignado por Frank:
`notifications-not-delivered-testflight`; abierto en `in-progress/` y cerrado el mismo día — ver
«Cierre del owner» al final).

## Resultado

> Leer con el cierre del final: el owner comprobó después que **el permiso de iOS estaba en OFF**, así
> que la premisa del reporte («no llegan con todo concedido») no se sostiene.

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

## Estado al cerrar la investigación

- Ticket creado en `tickets/in-progress/` (movido a `tickets/done/` en el cierre de más abajo).
- `docs/TICKETS.md`: fila añadida, índice 61 → 62 y línea de counts corregida a los valores medidos
  (decía 60 con 61 ficheros en disco; índice y disco sí coincidían).
- Esta nota.
- **Sin cambios bajo `Yala/`** ⇒ no aplica actualizar `qa/coverage-index.json`.
- Sin fix, sin tests nuevos, sin QA, sin upload.

## Cierre del owner (2026-08-27, Lima) — no es bug de entrega

El owner revisó su device después de la investigación: tras **muchas reinstalaciones** de la app, las
notificaciones de Yala estaban en **OFF a nivel de iOS** y **la app no volvió a pedir permiso**. Los
toggles in-app y el Focus —los dos hechos con los que se abrió el encargo— eran un **red herring**: no
gobiernan la entrega mientras el permiso del sistema no esté concedido. Veredicto del owner:
**aparentemente no hay bug**. Del lado de ingeniería, la revisión de código no encontró ningún fallo de
agendado ni de entrega que apague TODAS las entregas con el permiso de iOS en ON.

⇒ **Cerrado como no-es-bug-de-entrega**, no por QA. **No hay PASS** y no hay nada que verificar: no se
escribió código, no se compiló, no se subió nada.

Lo medido arriba **no cambia**: solo `endOfDay`, `lunchTime` y `custom` se agendan de verdad, y los tres
**nacen en OFF**. Y **H1 (`isPersonalWipeArmed` pegado en `true`) sigue siendo hipótesis, no causa
confirmada** — este cierre no drenó sus señales (widget congelado, línea `wipe ABORTED` en el log), así
que ni la confirma ni la refuta.

Queda vivo el **hueco de producto** ya medido: el onboarding nunca pide el permiso
(`OnboardingView.swift:1937-1967`) y el primer contextual quema su flag antes de decidir si se muestra
(`NewTransactionViewModel.swift:954` antes de `:955`) — coherente con «la app no volvió a pedir
permiso». **Aquí no se implementa y no se abre ticket nuevo**: medido en este árbol, ningún ticket de
`tickets/` lo cubre hoy, y este cierre no inventa uno.

Qué cambió en disco con este cierre: el ticket a `tickets/done/` con `status: done` y su sección de
cierre, la fila y los counts de `docs/TICKETS.md` (in-progress 11 → 10, done 2 → 3, total 62) y esta
nota. Nada bajo `Yala/` ⇒ `qa/coverage-index.json` sigue sin aplicar.
