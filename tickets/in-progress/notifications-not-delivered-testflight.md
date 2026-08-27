---
id: notifications-not-delivered-testflight
status: in-progress
priority: high
area: notifications
created: 2026-08-27
updated: 2026-08-27
---

# Las notificaciones de Yala no llegan (TestFlight)

## El reporte del owner (Jurgen, 2026-08-27) — hechos suyos, sin añadir

- Las notificaciones de Yala **no llegan**.
- Los **toggles in-app están en ON**.
- El **Focus de iOS permite Yala**.
- **Empezó a fallar en una versión desconocida.** El owner no sabe cuál, y este ticket **no la nombra**.
- El binario que hay en campo es **TestFlight 2.1 build 12**.

No hay más hechos de campo. En particular **no consta medido**: el `UNAuthorizationStatus` real del
device, qué tipos concretos esperaba el owner, si la app estaba abierta o cerrada a la hora esperada,
ni el estado de los sub-ajustes de iOS (Alertas / Centro / Pantalla bloqueada).

## Esto NO es

Cuatro tickets vecinos tocan notificaciones y **ninguno es este**:

| Ticket | De qué va | Por qué no es este |
|---|---|---|
| `tickets/qa/scheduled-payments-notif-dedup.md` | dedup de notifs de pagos planificados | ahí el problema es **cuántas/cuáles** salen, no que no salga ninguna |
| `tickets/qa/group-notif-credits-payer-not-editor.md` | la notif de grupo atribuye al pagador y no al editor | es de **contenido** de una notif que **sí llega** |
| `tickets/backlog/orphan-alerts-behind-fullscreen-covers.md` | alerts in-app huérfanos detrás de covers | es UI **dentro** de la app, no entrega de `UNUserNotificationCenter` |
| `tickets/backlog/smart-ai-notifications.md` | notificaciones inteligentes con IA | es **feature nueva**, no una regresión |

## Causa: unknown

**No se pudo confirmar una causa en el código.** Se recorrió el mapa completo de rutas de
notificación (abajo) y ninguna explica, por sí sola y sin precondición externa, que caigan TODAS o
casi todas las notificaciones con los toggles en ON. Por regla de encargo **no se implementa fix sin
causa evidenciada**, así que este ticket entra a `in-progress` con el mapa medido, lo descartado y las
hipótesis vivas con su señal discriminante — no con un parche.

Ninguna medición de device se hizo en esta sesión: es una revisión de código sobre el árbol de `2.1`.
Tampoco se compiló ni se corrió la suite (el cambio de esta sesión es solo documentación).

## Lo medido — el mapa de rutas, con coordenadas de este árbol

### Solo TRES tipos se agendan de verdad en iOS. Los demás dependen de que la app corra

`NotificationItem.swift:128-136` — `requiresDynamicContent` es `true` para `dailyReport`,
`weeklyReport`, `monthlyReport`, `scheduledPayments` y `groups`. Y `NotificationService.swift:121-128`
**corta y cancela** para esos tipos antes de agendar nada:

```121:128:Yala/Services/NotificationService.swift
        if item.notificationType.requiresDynamicContent {
            // Cancel any previously scheduled static notifications for this type
            await cancelNotification(for: item)
            #if DEBUG
            print("NotificationService: Skipping iOS scheduling for dynamic type: \(item.notificationType.rawValue)")
            #endif
            return
        }
```

⇒ lo único con `UNCalendarNotificationTrigger` propio es `endOfDay`, `lunchTime` y `custom`. Todo lo
demás sale por `sendNotification` (trigger de 1 s) **cuando la app arranca o vuelve a foreground**
(`AppBootstrapper.swift:190`, `:258`, `:1589-1591`) o cuando corre un `BGAppRefreshTask`.

**Y los tres estáticos nacen en OFF**: `NotificationItem.swift:411` (`endOfDay`), `:420`
(`lunchTime`); el único `isActive: true` de fábrica es `scheduledPayments` (`:464`), que es dinámico.

La única excepción que sobrevive a cerrar la app es el canal AGENDADO de resúmenes de pagos
(`spDailySummary_<yyyyMMdd>`, `NotificationService.swift:298-374`), con horizonte de **14 días**
(`ScheduledPaymentSummaryPlanner.swift:52`) y solo si hay pagos activos con `notifyOnDueDate`.

⇒ **Consecuencia para el diagnóstico:** "no llegan" es compatible con el diseño actual si lo que el
owner espera son reportes/pagos con la app cerrada y los `BGAppRefreshTask` no corren. Eso no es una
regresión demostrada, pero condiciona qué se debe medir en device.

### Hay UN solo gate común a los tres productores

`NotificationService.swift:397-399`:

```397:399:Yala/Services/NotificationService.swift
    private var isPersonalWipeArmed: Bool {
        StorageModePersistence.isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()
    }
```

Se evalúa en los tres únicos caminos de entrega, **después** del check de permiso:

- `:134` en `scheduleNotification` (estáticas)
- `:231` en `sendNotification` (reportes, presupuestos, pagos, grupos, tarjeta de crédito)
- `:332` en `replaceScheduledPaymentSummaries` (canal agendado, por iteración)

Es el **único** predicado del código cuyo `true` apaga el 100 % de las entregas dejando intacto todo
lo demás: permiso concedido, filas `NotificationItem` con `isActive == true`, datos visibles.

### El permiso NUNCA se pide en el onboarding

`OnboardingView.swift:1937-1967` (`createDefaultNotifications`) siembra filas y **no llama a
`requestPermission`**. Los cuatro únicos call-sites que lo piden son
`NotificationsSettingsView.swift:112` y `:178`, `NotificationPrimerSheet.swift:94` y
`GroupsContainerView.swift:523`.

Y el primer contextual **quema su flag antes de decidir si se muestra** —
`NewTransactionViewModel.swift:950-958`, el `set(true, ...)` de `:954` va **antes** del
`if status == .notDetermined` de `:955` ⇒ hay caminos en que queda "ya visto" sin haber pedido nada.

⇒ Un usuario puede tener toggles en ON y el permiso en `.notDetermined` **si nunca abrió
Perfil → Notificaciones**. Pero abrir esa pantalla con permiso ya concedido **reprograma todo**
(`NotificationsSettingsView.swift:122-125`), así que si el owner vio los toggles ahí, esa pantalla ya
corrió su reschedule — lo que **debilita** esta hipótesis y **refuerza** la del gate de arriba.

### La heurística del reconciler es frágil (hallazgo lateral, no causa probada)

`AppBootstrapper.swift:2490` decide reprogramar con `pending.count < activeItems.count`. Los dos lados
cuentan cosas distintas: `pending` incluye las hasta 14 `spDailySummary_*` y las variantes por día de
semana, y `activeItems` incluye tipos **dinámicos que jamás producen un pending**. Con summaries vivas
la condición es falsa casi siempre ⇒ el caso "reinstalación/update" que este bloque existe para cubrir
queda enmascarado. El propio árbol ya lo documenta como frágil en
`SwiftDataConfiguration.swift:805-810`.

## Lo descartado, con la medición que lo descarta

| Hipótesis del encargo | Medición |
|---|---|
| **Falta entitlement / `aps-environment` mal** | `Yala/App/Yala-Release.entitlements` tiene `aps-environment = production` (con el aviso de la regresión de 1.2.6 escrito encima). Release firma con ese fichero (`project.pbxproj:588`). Además las locales no necesitan entitlement. |
| **`interruptionLevel` passive** | `interruptionLevel` **no aparece en ningún fichero** del proyecto. Nunca se toca: queda en el default `.active`. |
| **Mute por categoría / thread** | `categoryIdentifier`, `threadIdentifier`, `setNotificationCategories`, `UNNotificationCategory` y `relevanceScore`: **cero ocurrencias** en todo el árbol. |
| **Extensión Notification Service/Content mal configurada** | El proyecto tiene 5 targets y **ninguno** es de notificaciones: `Yala`, `YalaTests`, `YalaUITests`, `YalaShare`, `YalaWidgetsExtension` (`project.pbxproj:266-357`). No hay nada que pueda descartar un push. |
| **Gate de Pro / entitlement de suscripción** | Cero referencias a Pro/paywall/entitlement en `NotificationService`, `ReportNotificationService`, `ScheduledPaymentNotificationService`, `BudgetAlertService`, `GroupNotificationService` ni en `ensureNotificationsScheduled`. |
| **Un seam de UI test filtrado a release** | `UITestHooks.swift:24-30`: `isActive` es `return false` bajo `#else` de `#if DEBUG` ⇒ constante falsa en Release, y `hasArg` (`:276-282`) igual. El `guard !UITestHooks.isActive` de `NotificationsSettingsView.swift:106` no puede disparar en TestFlight. |
| **Bundle equivocado TF vs Dev** | `com.jurgenschmidt.yala` + `group.com.jurgenschmidt.yala` en Debug/Release; `.dev` solo en `Debug-Dev`/`Release-Dev` (`project.pbxproj:535-610`, `846-920`). Sin cruce. |
| **Identificadores de BGTask desalineados** | Los tres IDs de `BackgroundTaskManager.swift:24-31` casan literalmente con `BGTaskSchedulerPermittedIdentifiers` de `Info.plist:29-34`; `UIBackgroundModes` tiene `fetch` + `remote-notification` (`:103-107`). |
| **Delegate no registrado** | `AppBootstrapper.swift:140` (`_ = NotificationService.shared`) y `NotificationService.swift:22` (`notificationCenter.delegate = self` en el `init`). Además el delegate no condiciona la ENTREGA, solo la presentación en foreground. |
| **Caché de autorización que miente** | **No existe** ninguna key tipo `notificationsAuthorized` / `notificationsEnabled`. Los cuatro consumidores consultan `notificationSettings()` en vivo. |
| **"Lo rompió el build 12"** | Entre el bump a build 11 y el de build 12 hay **un** commit funcional, `74ddaf01`, y toca StoreKit/Pro + `Localizable.strings`. Ninguna notificación. **Esto NO significa que la causa esté en otro build**: significa que build 12 no la introdujo. |

## Hipótesis vivas, en orden, con su precondición y su señal discriminante

Ninguna está confirmada. Cada una lleva **qué habría que ver en el device** para confirmarla o
matarla, porque desde el código no se puede.

### H1 — `isPersonalWipeArmed` pegado en `true`

**Mecanismo (medido).** El boot-hook que desarma aborta ANTES de desarmar si el borrado del archivo
BASE falla:

```616:620:Yala/Utils/SwiftDataConfiguration.swift
        guard deleteFiles(databaseName, personalSchema),
              deleteFiles(syncMetaDatabaseName, syncMetaSchema) else {
            CloudSyncBreadcrumb.signOutWipeAborted(reason: "store file deletion failed")
            return
        }
```

El desarme vive al final (`:731-732`), inalcanzable tras ese `return`. El gemelo secundario tiene el
mismo patrón (`:841-846` aborta, `:893` desarma). En ese estado el store **sobrevive** ⇒ la app se ve
normal, los toggles siguen en ON, y los tres `add` mueren en silencio. Es **auto-perpetuante**: cada
arranque vuelve a abortar.

**Precondición NO verificable desde el código:** que el owner haya cerrado sesión en Modo Nube (o
salido de una sesión secundaria) **y** que el borrado del archivo base haya fallado. `armSignOutWipe`
solo lo escriben caminos de sign-out explícito (`CloudSessionSignOut.swift:306`, `:551`) más
`SecondarySessionStore.armWipe` (`:391`).

**Señal que decide, ya en el binario de build 12:**
1. **El widget.** `WidgetDataCache.swift:212` + `:230-231` usan el **mismo predicado**. Si el snapshot
   del widget está congelado (no refleja transacciones nuevas), el flag está puesto.
2. **El log del device.** Los dos breadcrumbs de abort emiten con `logger.error` y `privacy: .public`
   **fuera de `#if DEBUG`** (`CloudSyncEngine.swift:400-402` y `:470-472`, logger de `:55`). En
   Console.app / sysdiagnose, subsystem `com.yala`, categoría `CloudSync`, las cadenas literales son:
   `CloudSignOut wipe ABORTED reason=store file deletion failed` (brazo `.cloud`) y
   `CloudSecondary wipe ABORTED reason=store file deletion failed` (brazo secundario M1).
   Una sola aparición en cualquier arranque prueba el escenario completo.

Si el widget se actualiza con normalidad y no hay esa línea en el log, **H1 queda refutada**.

### H2 — El permiso del sistema no está realmente concedido para alertas

**Mecanismo (medido).** `sendNotification` (`:223-228`) y `isAuthorized` (`:103-106`) gatean **solo**
por `authorizationStatus`. Los sub-ajustes (`alertSetting`, `notificationCenterSetting`,
`lockScreenSetting`) se **loguean** en DEBUG (`:226`) y **no se miran**. Un `.authorized` con
"Alertas" desactivado en Ajustes → iOS deja el `add` aceptado y sin banner visible, y la app lo
contaría como entregado (`return true`).

**Señal:** Ajustes → Notificaciones → Yala en el device: ¿estilo de alerta, Centro y Pantalla
bloqueada están activos? El reporte dice "Focus permite Yala", que es **otra** cosa.

### H3 — Lo esperado son tipos dinámicos y la app no corrió

**Mecanismo (medido):** ver arriba — reportes, pagos, presupuestos y grupos solo salen con la app
viva o con un BGTask. Y `BackgroundTaskManager.registerTasks()` se llama en
`AppBootstrapper.swift:246`, **dentro del `bootstrap()` async** que arranca desde el `.task` de
`ContentView.swift:226`, es decir DESPUÉS de que el lanzamiento termine y solo si la UI se monta. Un
lanzamiento puramente en background puede no ejecutar ese `.task` — residual que el propio repo ya
dejó escrito en el mensaje de `fa7cb4cd`.

**Señal:** ¿qué tipo exacto esperaba el owner y a qué hora? ¿La app estaba cerrada? Con `endOfDay` o
`lunchTime` en ON, ésos **sí** deberían llegar con la app cerrada; si tampoco llegan, H3 no explica
el caso y H1/H2 suben.

### H4 — El primer/permiso nunca se pidió

Ya descrito en «Lo medido». **Señal:** si al abrir Perfil → Notificaciones aparece el prompt nativo
del sistema, el permiso estaba en `.notDetermined` y ésta era la causa.

## Criterio de hecho (AC)

Con **permiso del sistema concedido** (incluidas Alertas), **toggle in-app en ON** y **Focus
permitiendo Yala**, llegan las notificaciones que la app realmente agenda:

1. **Locales estáticas** — `endOfDay`, `lunchTime` y una `custom` (incluida una con días de semana
   concretos) llegan a su hora **con la app cerrada**.
2. **Pagos planificados** — el resumen diario agendado (`spDailySummary_*`) llega a su hora con la app
   cerrada; y las oportunistas (vencido / vence hoy / próximo) llegan al abrir la app pasada la hora
   configurada, sin duplicar el resumen del día.
3. **Reportes** (diario / semanal / mensual) — llegan al abrir la app pasada su hora, y no se repiten
   el mismo período.
4. **Alertas de presupuesto** — con `budgetAlertsEnabled` en ON y un umbral cruzado, llega el aviso.
5. **Grupos / push** — un gasto o liquidación de otro miembro notifica a quien participa y no al autor.
6. **Recordatorio de tarjeta de crédito** — llega el día configurado.
7. Ningún canal queda suprimido por una marca de dedup que se puso **sin entrega confirmada**.

Además, como red del hallazgo lateral: la decisión de reprogramar del reconciler no debe depender de
comparar un `pending.count` que mezcla summaries y variantes por día de semana con un
`activeItems.count` que incluye tipos que nunca producen pending.

## Cómo se verifica

**Device-QA en TestFlight, sobre una subida POSTERIOR a este ticket.** No se sube nada en esta sesión:
no hay TestFlight, ni store, ni tag. Mientras no exista ese build en el device del owner, este ticket
**no puede pasar a `qa`** y **no hay PASS** que anotar.

Primero conviene drenar las cuatro señales de arriba (widget congelado, línea de log, sub-ajustes de
iOS, tipo/hora esperados): son minutos y **discriminan entre H1–H4 sin escribir una línea de código**.
Si alguna confirma la causa, este ticket recibe su sección `Causa (código)` con `fichero:línea` y
entonces —y solo entonces— el fix mínimo con sus tests.

## Relacionado

- Canal agendado de pagos y su contrato de dedup: `tickets/qa/scheduled-payments-notif-dedup.md`.
- El predicado gemelo del widget y por qué se copió del de notificaciones:
  `.claude/rules/swiftdata-cloudkit.md` y `Yala/App/Logic/Helpers/WidgetSessionSeal.swift:48-53`.
- Sesión de esta investigación: `docs/sessions/2026-08-27-notifications-not-delivered.md`.
