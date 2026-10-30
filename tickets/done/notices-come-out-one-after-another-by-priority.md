---
id: notices-come-out-one-after-another-by-priority
status: done
priority: high
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: tablero tablero-notificaciones-y-avisos-in-app-que-salte-usxd (pedido de Jürgen, 2026-10-29 05:36 Lima)
---
# Notificaciones y avisos in-app: uno tras otro, con una regla de prioridad, sin solaparse ni duplicarse

Pedido: que las notificaciones y los pop-ups salgan como se espera, uno tras otro y con prioridades. Sesión autónoma de
noche (S27f): las decisiones abiertas se tomaron por la opción conservadora y están en el Paso 0 del encargo
`encargos/lanzados/2026-10-30-notificaciones-orden-prioridades.md` y en el PR.

## Qué cambia para quien usa Yala

- Cuando la app tiene dos avisos que enseñar a la vez —el aviso de la Bandeja, la oferta de prueba, Novedades, «Tu prueba
  terminó», el hito de registros, el fin de Pro…— salen **uno detrás de otro y en orden de importancia**. Antes, si eran
  de dos «sitios» distintos de la app, salía el que mirase primero: Novedades podía salir antes que «Tu prueba terminó».
- El aviso de nuevos borradores de la Bandeja ya no sale **dos veces seguidas** («2 nuevos» y luego «3 nuevos») cuando
  llegan borradores mientras espera su turno: sale uno, con la cifra de ahora.
- El recordatorio de un pago planificado (vence hoy, en N días, vencido) y el de la tarjeta de crédito ya no pueden salir
  **dos veces** al abrir la app en frío.
- En Grupos, cuando el servidor manda su aviso genérico («Novedades en tus grupos», «Alguien quiere unirse…») y la app
  despierta y compone el aviso con detalle del mismo grupo, el genérico se retira: queda uno, no dos.

## La regla de prioridad (escrita en `docs/entry-points.md`, sección «Orden: qué sale primero»)

1. **Una sola cola** (`RouterEntryGate.submit` → `AppRouter`) ordena por prioridad y, dentro de la misma, por llegada:
   `critical` (datos y cuenta; respuesta a un enlace tocado) › `high` (lo pedido desde fuera, Bandeja, espejo de iCloud,
   prueba terminada, fin de Pro) › `normal` (navegar, formularios, oferta, hito, unirse a un grupo) › `low` (Novedades,
   reseña).
2. **Nunca dos a la vez**: la matriz de readiness y el candado de cada consumidor retienen la cola mientras algo esté
   encima (ya existía).
3. **Entre consumidores manda la cola** (nuevo): en una ventana, una hoja de MainTab cede ante lo de `ContentView` que va
   delante; un aviso diferible de `ContentView` cede ante una hoja de MainTab que va delante. Críticos y respuestas a un
   toque no ceden. Solo se cede ante un consumidor listo. `NoticeOrderLogic` + `AppRouter.shellNoticeAhead(of:in:)`.
4. **Qué se descarta por duplicado**: un aviso con el mismo `id` sustituye al que esperaba (en su sitio, con la carga
   nueva); las reglas de `IntentSupersessionLogic` (abrir la Bandeja tira su aviso, «prueba terminada» tira la oferta,
   un vaciado remoto tira todo lo no crítico, el cambio de Apple ID tira el aviso de iCloud) y `MonetizationDedupLogic`
   (nada de oferta ni hito con «prueba terminada» en cola). Nuevo: el aviso de la Bandeja lleva `id` fijo.
5. **Notificaciones del sistema**: identificador fijo donde la notificación se reprograma (recordatorios, resumen diario);
   tracker de «ya avisado» donde es inmediata, con una pasada a la vez (nuevo en pagos y tarjeta); el aviso rico de un
   grupo retira el genérico del servidor de ese grupo (nuevo para actividad y solicitudes; ya existía para membresía).

### Alternativas documentadas (no elegidas)

- **Cola global estricta con el Panel dentro**: las entradas que la persona acaba de pedir (foto compartida, dictar,
  nuevo registro) esperarían detrás de avisos como Novedades. Peor para el usuario; descartada.
- **Un solo consumidor para todos los avisos**: un anchor único en `ContentView`. Rehacer las hojas de MainTab y su
  candado; más riesgo que valor ahora. Si se rediseñan las notificaciones (card 2.4), es la opción a mirar.
- **Prioridad por gravedad pura**: que un `high` de MainTab adelante a un crítico de `ContentView` que llegó después no
  pasa (los críticos no ceden), y se mantiene así: un aviso que protege datos sale ya.

## Inventario

### Notificaciones del sistema (17 tipos, 4 `center.add`, todos en `NotificationService.swift`)

| Notificación | Identificador | Quién / cuándo | Dedupe |
|---|---|---|---|
| Recordatorio diario (fin del día, almuerzo, personalizado sin días) | `<item.id>` diario | Ajustes, `rescheduleAllNotifications` en arranque si faltan | Id fijo: iOS reemplaza |
| Recordatorio personalizado con días | `<item.id>-<1…7>` semanal | Igual | Id fijo |
| Resumen diario de pagos | `spDailySummary_<yyyyMMdd>` | `replanSummaries` en cada arranque/primer plano y tras cambiar pagos | Id fijo + retirada del prefijo |
| Pago vence hoy · en N días · vencido | `notification-<UUID>` | `checkAllPaymentNotifications` en arranque/primer plano | Tracker por pago y día; **una pasada a la vez (nuevo)** |
| Pago de tarjeta de crédito | `notification-<UUID>` | `checkAndNotifyCreditCardPayments` | Tracker por tarjeta y día; **una pasada a la vez (nuevo)** |
| Alerta de presupuesto personal | `notification-<UUID>` | `checkBudgetsAndNotify` (arranque, alta de movimiento, borrador, puente de grupo) | `isChecking` + tracker por umbral y período |
| Informe diario/semanal/mensual | `notification-<UUID>` | `sendDueReports` (arranque, primer plano, BGTask) | `isSendingReports` + `lastNotifiedDate` |
| Actividad de grupo (gastos, liquidaciones, miembros, solicitudes) | `notification-<UUID>` | `processRemoteChanges` tras cada página del pull | 1 por grupo cada 5 min; **retira el genérico del servidor del mismo grupo (nuevo)** |
| «Ya estás en X» | `notification-<UUID>` | Igual | Retira el genérico de membresía |
| Presupuesto de grupo | `notification-<UUID>` | Arranque/primer plano | `isChecking` + tracker |
| Recordatorio de liquidación | `notification-<UUID>` | Arranque/primer plano | `isChecking` + 7 días por deuda |
| Apple Pay / Siri / «Probar» del editor | `notification-<UUID>` | Cada ejecución o toque | Ninguno (uno por gesto) |
| Push remoto de Grupos (actividad, solicitud, membresía) | del sistema | `fanOutGroupPush` del gateway | Sin `collapse-id` |

Primer plano: `willPresent` devuelve `[.banner, .sound, .badge]` para todo, sin filtrar por tipo.

### Avisos in-app que pasan por la cola

Ver la tabla «Avisos con una hoja abierta en otra pestaña» de `docs/entry-points.md` (20 intents con su consumidor,
prioridad y si esperan) y la de «Avisos que la app saca sola al entrar».

### Avisos in-app que NO pasan por la cola (inventario del 2026-10-30, leído en el código)

| Aviso | Dónde | Quién lo enciende | Coordinación |
|---|---|---|---|
| Toast verde («Datos vaciados», «De vuelta a Yala completo»…) | `ContentView` capa raíz | `showPositiveToast` | Ninguna: queda debajo de las hojas |
| Pastilla de sincronización / «Descargando tus datos…» | `ContentView` / `MainTabView` arriba | Estado de iCloud / tick de 1 s | Estado, sin orden con el toast |
| Tarjetas del Panel en carrusel (oferta de nube, guía, Pro, nudge, Siri…) | `PanelView` | `onAppear` | `PanelNoticeQueueLogic` |
| Nudge en Grupos | `GroupsContainerView` | `onAppear` | Compartido con el Panel |
| «¿Era de prueba?» (Panel y Planificación) | `PanelSheetsModifier`, `PracticeCleanupPrompt` | Fin del primer registro/presupuesto/pago | Panel: su candado; Planificación: ninguno |
| «Activa las notificaciones» | Dentro del editor | `NotificationPrimerMoments.claim` | Dentro de la hoja |
| Permiso de micrófono | Sistema | Al abrir la hoja de voz | Dentro de la hoja |
| Tours Pro / Ajustes / Observaciones, pista Today FX, guía del flujo de caja | Overlays | `.task` con retraso | Persistidos |
| TipKit de comparación | Estadísticas | Regla TipKit | TipKit |
| Hoja educativa de Grupos | `GroupsContainerView` | `onAppear` | Ninguna |
| «Solicitud pendiente de aprobación» | `GroupsContainerView` | Abrir un grupo pendiente | Ninguna |
| Tarjeta «Avisos de grupo» | Lista de Grupos | `.task` al montarse | `listMountsCard` |

Son superficies dentro de una pantalla o respuestas a un gesto, no avisos que compitan por el anchor del shell; no se
han metido en la cola en este ticket. Los riesgos que se vieron al leerlos van abajo, en «Encontrado».

## Hecho

- `NoticeOrderLogic` (nuevo) + `AppRouter.shellNoticeAhead(of:in:)`; lo consultan `drainContentViewIntents` y
  `drainMainTabIntents` (`ContentView.swift`).
- `RouterIntent.id` de `.showInboxAlert` fijo.
- `ScheduledPaymentNotificationService`: guardas de reentrada en los dos chequeos.
- `GroupNotificationService` + `GroupServerNoticeReplacementLogic` (nuevo): retira el genérico del servidor del grupo.
- Seam `-uitest-milestone <n>` y `milestone_not_now` en la hoja del hito.
- Tests: `NoticeOrderTests` (regla, cola, retirada del genérico), `AppRouterTests` (aviso de la Bandeja sustituye en su
  sitio; el test anterior fijaba el duplicado como contrato), `ScheduledPaymentNotificationServiceTests` (dos pasadas
  solapadas, un envío), `NoticeOrderUITests` (dos avisos de consumidores distintos: orden de prioridad y de llegada).
- Regla durable: `.claude/rules/swiftui-ds.md`, «El orden ENTRE consumidores lo da la cola».

### Review adversarial (2026-10-30) — cinco hallazgos, los cinco arreglados

1. La retirada del genérico de Grupos borraba uno que el aviso rico no sustituía (el que llegó durante el límite de 5 min).
   Ahora solo se retira el genérico **reciente** (≤ 120 s, `freshWindow`) del mismo grupo, y **después** de que el rico
   salga (si iOS no lo acepta, el genérico se queda).
2. La cadena de una invitación cierra el Welcome para drenar (B4-04) y luego podía ceder ante «Tu prueba terminó». Lo que
   responde a un enlace tocado (`bringsLeaderForward`) no cede.
3. Ningún test fijaba el cableado de los dos drenajes: source-scan en `NoticeOrderTests`.
4. El test de reentrada no probaba que la guarda se soltara: ahora siembra otro pago y espera dos envíos.
5. La pasada pedida durante otra (el borrado parcial la pide) se tiraba: ahora se repite al terminar.

### Verificación

- Unit: 231 tests en 14 suites, verdes. Mutantes (todos caen): sin la cesión de ContentView, sin la de MainTab, `id`
  por cifras, sin la excepción de las invitaciones, sin la guarda, sin la repetición.
- XCUITest: 24 tests en 8 suites (`NoticeOrderUITests`, `PaywallInboxAlertRoutingUITests`, `InboxNewItemsModalUITests`,
  `ExternalEntryForeignSheetUITests`, `RemoteWipeNoticeRoutingUITests`, `DeeplinkRoutingUITests`,
  `WhatsNewLaunchUITests`, `TrialOfferMomentUITests`), corrida sola. Con el mutante, el caso de prioridad cae (el hito
  salía antes que el aviso de la Bandeja: el bug reproducido); el de llegada sigue verde porque en iOS 27.0 MainTab drena
  primero, y esa dirección la fija el unit.

## QA en iPhone (no bloquea el merge)

Lo único que el simulador no puede probar: el push real de Grupos. Necesita dos iPhone con la misma cuenta de grupos (o
el tuyo y el de prueba en un grupo compartido), con la app de Yala Dev o TestFlight con este cambio en el que RECIBE.

1. En el iPhone que recibe, cierra Yala (deslizar hacia arriba desde el selector de apps) y deja la pantalla bloqueada.
2. Desde el otro iPhone, añade un gasto al grupo compartido.
3. En el que recibe: llega «Novedades en tus grupos» (el genérico). Espera unos segundos sin tocar nada.
4. Si iOS despierta a Yala, el genérico desaparece del Centro de notificaciones y queda el aviso con quién y cuánto.
   Esperado: **uno**, no dos. Si iOS no la despierta, queda solo el genérico (también vale).
5. Repite el paso 2 dos veces en menos de 5 minutos: el segundo genérico debe **quedarse** (el aviso con detalle está
   limitado a uno cada 5 min y no lo sustituye).

## Para S27g (apertura desde una notificación tocada) — anotado, sin tocar

- `NotificationService.routeTap` → `.navigate(destino)`; los destinos los parsea `parseDestination`. `accounts/<uuid>` y
  `scheduledPayments/<uuid>` ya se reconocen (ticket `notification-deeplink-accounts-not-parsed`, en `done/`; la sección
  «Huecos conocidos» de `docs/entry-points.md` lo daba por abierto y se corrigió en este PR).
- El push de varios grupos lleva `deepLink: "groups"` (sin barra): `clearDeliveredGroupNotifications` filtra por
  `hasPrefix("groups/")` y no lo retira.
- `.navigate(.groups)` sin id saca la hoja educativa de Grupos en el `onAppear`, sin candado: si un aviso crítico de
  `ContentView` drena en esa vuelta, son dos presentaciones a la vez (inferido, sin medir).
- El delegado se instala en `YalaAppDelegate.didFinishLaunching` (`installAsCenterDelegate`), así que el toque que abre la
  app cerrada llega.
- `willPresent` enseña todo en primer plano sin filtrar: con la app delante, un push genérico de Grupos y el aviso rico
  pueden verse los dos como banner (este ticket retira el genérico ENTREGADO, no el banner que ya pasó).

## Encontrado (fuera de alcance, con ticket)

- `practice-cleanup-prompt-outside-the-presentation-locks`: «¿Era de prueba?» no cuenta como hoja abierta en el Panel y
  en Planificación no tiene candado; la casilla es global y dos prácticas seguidas pierden la primera.
- `positive-toast-and-top-banners-are-not-coordinated`: toast, pastilla de sync y «Descargando…» van arriba sin orden, y
  el toast caduca debajo de una hoja sin que nadie lo vea.
- `group-push-has-no-collapse-id-and-multi-device-duplicates`: el gateway manda cada tanda sin `apns-collapse-id` ni
  `thread-id`; los trackers son locales, así que con dos dispositivos cada aviso sale en los dos.
- `one-shot-prompts-burned-before-they-are-seen`: la hoja de permiso de notificaciones y la tarjeta de avisos de grupo se
  dan por vistas antes de presentarse.
- Sin ticket, por ser producto: la hoja educativa de Grupos cerrada con la X vuelve en cada entrada a Grupos (la X no
  guarda la marca a propósito: es la puerta del consentimiento).

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
