---
id: groups-expense-notif-only-on-foreground
status: qa
priority: high
area: groups
created: 2026-08-28
updated: 2026-09-03
---

# La notificación de un gasto de grupo solo aparece cuando el receptor ENTRA en la app, no mientras está fuera

## Reporte del owner (Jurgen, 2026-08-28, Lima) — hechos suyos, sin añadir

TestFlight **2.1 build 12**. Dos cuentas del owner en dos devices: **A** = personal, **B** = de prueba.
**El mismo grupo de la sesión de QA de hoy.**

- **A** creó / editó un gasto de grupo.
- **B** tenía Yala en **segundo plano** desde antes. **Mientras B estaba fuera de la app no vio ningún
  banner.**
- La notificación **SÍ llegó a B — pero solo al ENTRAR en la app**.
- **A no la recibió.** A era el actor.

Lo que se reporta aquí es **la entrega a B únicamente en foreground**. El «A no la recibió» queda
apuntado porque se preguntó, no porque sea el defecto de este ticket: la autoexclusión del eco al autor
es el comportamiento vigente y su ticket es otro (ver «Esto NO es»).

**No consta medido en este reporte** —y hace falta para decidir, así que se pide explícitamente en el
guion de abajo—: si el proceso de B seguía vivo en background o iOS ya lo había desalojado; los
sub-ajustes de notificaciones de iOS en B (Alertas / Centro / Pantalla bloqueada); **quién pagaba** el
gasto; cuántos cambios hizo A y en qué ventana de tiempo (el rate-limit por grupo es de 5 min, ver
abajo); ni las horas exactas del cambio de A y de la apertura de B.

## Esto NO es

| Ticket | De qué va | Por qué no es este |
|---|---|---|
| `tickets/done/notifications-not-delivered-testflight.md` | «las notificaciones de Yala no llegan» en TF | Se cerró como **no-es-bug-de-entrega**: el permiso de notificaciones de iOS estaba en **OFF** tras muchas reinstalaciones y la app no volvió a pedirlo. Aquí la notificación **existe y se muestra**, y el permiso está concedido lo bastante como para mostrarla — solo **espera al foreground**. |
| `tickets/qa/group-notif-credits-payer-not-editor.md` | atribución («X actualizó» nombraba al pagador) + eco al autor | Va de **qué dice** la notificación y de **a quién** se le suprime. Este va de **CUÁNDO** aparece. **Ese ticket no se cierra aquí** y sigue en `qa/`. |
| `tickets/qa/scheduled-payments-notif-dedup.md` | dedup de notifs de pagos planificados | Otro productor y otro canal; ahí el problema es cuántas salen. |
| `tickets/backlog/smart-ai-notifications.md` | notificaciones inteligentes con IA | Feature nueva. |

## Causa: NO declarada

**No se declara causa raíz y no se toca código.** Lo que sigue es el mapa **medido** del camino en este
árbol y las hipótesis vivas con su señal discriminante. En particular **NO se afirma que el silent push
esté roto**: eso solo se puede sostener con una medición de device/servidor que hoy no existe (ver
«Cómo se verifica»).

## Lo medido en este árbol (`2.1` @ `2175e53e`)

Todas las coordenadas de esta sección se midieron en `2175e53e`. Si al retomar el árbol ya no es ese
commit, re-medir antes de obedecerlas: en este repo la documentación envejece más rápido que el código.

### 1. La notificación de grupo es LOCAL y nace DESPUÉS de que el gasto aterriza en el receptor

El canal backend es hoy el que emite las notificaciones de grupo (la Fase 3 se llevó el transporte
CloudKit: `Yala/Services/Groups/SplitSyncManager.swift` **ya no existe** en el árbol, aunque varios
comentarios lo sigan nombrando).

- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:1937` — al cierre de `applyPulledPage`
  (`:1820`), **post-save**: `if !changes.isEmpty { onRemoteChanges(changes) }`.
- `GroupsSyncClient.swift:244-245` — el default de ese closure es
  `{ GroupNotificationService.shared.processRemoteChanges($0) }`.
- `Yala/Services/Groups/GroupNotificationService.swift:68` — `processRemoteChanges`, que filtra por
  participación y termina en `NotificationService.sendNotification` (`:124-128`).
- `Yala/Services/NotificationService.swift:222-262` — `sendNotification` agenda una **local** con
  trigger de **1 s** (`:243`).

⇒ **La notificación no viaja por APNs: se fabrica en el device del receptor justo después de que el pull
aplique el gasto.** Es decir, **es exactamente tan tardía como el pull**. Esto está medido en el árbol;
lo que **no** está medido es que sea lo que ocurrió en la sesión de A y B (ver «Cómo se verifica»).

### 2. En el camino de la notificación NO hay ningún gate de foreground

Ni `processRemoteChanges` ni `sendNotification` consultan `applicationState` ni nada equivalente.
`sendNotification` gatea solo por permiso (`:228`) y por el wipe personal armado (`:231`). Y en el otro
extremo, el delegate presenta banner **también con la app abierta**
(`NotificationService.swift:28-35`, `completionHandler([.banner, .sound, .badge])`) — que es por qué el
aviso se ve como un banner al entrar, y no como algo que aparece callado en el Centro de notificaciones.

⇒ Si el pull hubiera corrido con B en background, el banner habría salido con B fuera de la app. **El
síntoma «solo en foreground» apunta al PULL que no ocurre en background, no a una notificación
suprimida.** (Y esto es lo que hay que confirmar en device, no dar por hecho.)

### 3. Sí existe un camino de silent push, con un residual documentado en el propio código

- `gateway/src/groups/routes.ts:123-146` — por cada delta con status `applied`, el `/groups/push` del
  autor dispara `fanOutGroupPush` en un `waitUntil` (`:145`); nunca bloquea la respuesta.
- `gateway/src/groups/routes.ts:167-235` — el fan-out resuelve tokens con `get_group_push_tokens`
  (`:190-194`, excluyendo al autor por `p_exclude_user_id` y su device emisor por
  `p_exclude_device_token`) y manda `{ aps: { "content-available": 1 }, yala: { kind: "groups-sync" } }`
  (`:218`).
- `Yala/App/YalaAppDelegate.swift:54-84` — el handler clasifica: CloudKit primero (`:61-65`), y la rama
  `yala` (`:67-80`) llama `GroupsSyncClient.shared.syncNowFromPush(timeout: .seconds(20))` (`:76`).
- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:456-477` — `syncNowFromPush`. Gates **sin
  red** (`:458-459`): flag del canal, sesión, `!stoppedUntilRelaunch` y **`context != nil`**.
- **El residual ya está escrito en ese docblock** (`GroupsSyncClient.swift:453-455`): *un launch
  puramente en BACKGROUND por silent push puede no ejecutar el `.task` del bootstrap ⇒ el canal no
  arranca en ese proceso, `context` es nil y esto devuelve `false` (`.noData`); el pull real ocurre al
  próximo foreground (consistencia eventual v1).* Ese residual, tal cual, describe el síntoma
  reportado. **Que sea lo que pasó aquí no está medido.**

### 4. Lo que sí despierta el pull de B, medido

- `Yala/App/AppBootstrapper.swift:339` — `startIfEligible` en cold boot.
- `Yala/App/AppBootstrapper.swift:1505-1508` — `startIfEligible(context:trigger: "foreground")` al
  volver a activo. **Este es el camino compatible con «llegó al entrar en la app».**
- `GroupsSyncClient.swift:487-489` — `syncNowFromUI` (pull-to-refresh) reusa `syncNowFromPush` tal cual.
- `Yala/Services/CloudSync/Groups/GroupsSaveSyncTrigger.swift:5-11` — tras un save, el AUTOR pide tiempo
  de fondo y dispara un ciclo pasado el debounce. Su propio header dice para qué existe: «el loop de 60 s
  se suspende y el silent push despierta al receptor». O sea, el diseño **cuenta con** el silent push
  para el receptor en background; no hay una segunda red para ese caso.

### 5. Config de producción, medida en el repo (no en el servidor)

- `gateway/wrangler.toml:166` — `GROUPS_BACKEND_ROLLOUT_PERCENT = "100"` en el bloque de producción: el
  canal backend de Grupos está **encendido**, no DARK.
- `gateway/wrangler.toml:104` — `APNS_KEY_ID = "7H6BUZWKKS"` en producción, con la nota `:101-103` de que
  la `.p8` «está subida como secret `APNS_AUTH_KEY` en AMBOS envs».
- `gateway/wrangler.toml:14-17` — el fan-out además necesita `PUSH_ROLE_JWT` (credencial de máquina);
  **ausente o revocado ⇒ el fan-out es un no-op silencioso**. Es un secret: **desde el repo no se puede
  medir si está puesto hoy**, solo desde `wrangler secret list --env production` o el log.
- `gateway/src/groups/routes.ts:175-178` y `:181-184` — los dos short-circuits (APNs sin configurar /
  sin `PUSH_ROLE_JWT`) salen con **un log y nada más**: `[groups-fanout] APNs no configurado …` y
  `[groups-fanout] PUSH_ROLE_JWT ausente …`. Y el fan-out entero es best-effort: un fallo de APNs se
  traga con `[groups-fanout] get_group_push_tokens upstream <status>` o
  `[canary] groupApnsSendFailed …`. **Todo esto es visible en `wrangler tail`** — es la señal más barata
  que hay para este ticket.
- `gateway/src/push/apns.ts:94-96` — el push va con `apns-push-type: background`, `apns-priority: 5` y
  **`apns-expiration: 0`**, que el propio comentario traduce: «no reintentar si offline». Un device
  inalcanzable en ese instante **pierde** el despertar; no hay reintento.
- `Yala/Services/CloudSync/Groups/PushTokenRegistrar.swift:83-97` — el token de B solo se sube con
  `groupsBackendEnabled && hasSession()` y token no vacío; `:76-79` captura y sube al recibirlo del OS;
  `:56-62` reporta `ios-prod` en Release (TestFlight) y `ios-sandbox` en DEBUG. Sin token subido de B,
  el fan-out no tiene a quién despertar.
- `Yala/Utils/L10n.swift:2253-2257` — medido el 2026-08-12 y sigue en pie: **el único push del gateway es
  este silent de fan-out, y solo lo dispara `/groups/push`**; `get_group_push_tokens` excluye a los
  `pendingApproval`.

### 6. Dos filtros del consumidor que hay que tener presentes al reproducir

- **Rate-limit de 5 min por grupo**, y **persiste entre arranques**
  (`GroupNotificationService.swift:44-59` + `:253-257`, guard en `:108`, key
  `GroupNotifications.lastNotified.<groupID>` en `UserDefaults`). Si A crea y luego edita dentro de la
  misma ventana, B recibe **una** notificación, no dos — y una repetición del guion a los 2 minutos
  parecerá «no llegó» cuando lo que hubo es un colapso por diseño.
- **Autoexclusión del eco al autor** (`GroupNotificationService.swift:188-193` →
  `GroupNotificationRecipientLogic.expenseDecision`, con `lastEditedByMemberID` y fallback al pagador).
  Es lo que explica que **A no reciba nada**, y es el comportamiento vigente desde el fix de
  `group-notif-credits-payer-not-editor`.

## Hipótesis vivas, con su señal discriminante

Ninguna está confirmada. Cada una lleva **qué habría que ver** para confirmarla o matarla; ninguna se
puede decidir leyendo más código.

**H1 — el silent push llegó, pero el ciclo no pudo correr en ese proceso.** Mecanismo medido en
`GroupsSyncClient.swift:453-459`: `context == nil` (el canal no arrancó en ese proceso) ⇒
`syncNowFromPush` devuelve `false` sin tocar la red. **Señal, y es barata:** el log del device de B.
`PushBreadcrumb` loguea **fuera de `#if DEBUG`, con `privacy: .public`**
(`Yala/App/Logic/PushBreadcrumb.swift:10-13`, `:41-43`), así que se lee en Console.app sobre el binario
de TestFlight — subsystem `com.yala`, categoría `Push`, cadena literal
`PUSH RECEIVED kind=yala(groups-sync)` (el `kind` del fan-out es `groups-sync`,
`gateway/src/groups/routes.ts:218`). Si esa línea aparece a la hora del cambio de A y aun así no hubo
banner, **el push llegó y el ciclo no corrió** ⇒ H1 sube y H2/H3 caen.

**H2 — el fan-out del servidor no salió.** Mecanismo medido: los short-circuits de
`gateway/src/groups/routes.ts:175-184` y el best-effort de `:195-233`. **Señal:** `wrangler tail --env
production` durante el guion, buscando `[groups-fanout]` y `[canary] groupApnsSendFailed`; y
`wrangler secret list --env production` para `PUSH_ROLE_JWT`. Silencio total de `[groups-fanout]` con un
`/groups/push` que devolvió `applied` = el fan-out ni se intentó.

**H3 — el push se emitió y APNs lo descartó.** Mecanismo medido: `apns-expiration: 0` +
`apns-priority: 5` (`gateway/src/push/apns.ts:94-96`), más el presupuesto que iOS aplica a los
`content-available` de una app poco usada. **Señal:** el fan-out no loguea fallo (APNs respondió 200) y
el device de B **no** registra ninguna línea `PUSH RECEIVED` a esa hora.

**H4 — B nunca tuvo token registrado.** Mecanismo medido: los gates de
`PushTokenRegistrar.attemptUpload` (`:83-97`) y el par `(user, token)` que el sign-out borra
server-side. **Señal:** `get_group_push_tokens` devuelve 0 filas para el grupo excluyendo a A; o, del
lado del device, el canario `groupPushTokenRegisterFailed` (`PushTokenRegistrar.swift:106`).

**H5 — no fue el push sino el rate-limit / los sub-ajustes de iOS.** **Señal:** la key
`GroupNotifications.lastNotified.<groupID>` y las horas exactas; y Ajustes → Notificaciones → Yala en B
(Alertas / Centro / Pantalla bloqueada), que es exactamente la señal que cerró
`notifications-not-delivered-testflight`.

## Cómo se verifica (device-QA, 2 devices; NO se sube nada en este ticket)

Hace falta el par de cuentas del owner y el grupo de la sesión de hoy. **Antes de cada intento**: esperar
>5 min desde la última notificación de ese grupo (o el rate-limit lo colapsa), y anotar las horas.

1. **B fuera de la app, proceso vivo.** B abre Yala, la manda a background (sin matarla) y **deja la
   pantalla encendida**. A crea un gasto **pagado por A**. → ¿banner en B con B fuera de la app?
2. **B fuera de la app, proceso desalojado.** Igual, pero B mata Yala (swipe) antes. → ¿banner?
   Es el caso que el residual de `GroupsSyncClient.swift:453-455` predice que falla.
3. **Foreground.** B abre la app. → si el banner aparece **ahí**, queda reproducido el síntoma exacto
   del reporte.
4. **En paralelo, dos observadores** (los dos existen ya en el binario de build 12):
   - servidor, `wrangler tail --env production`: si hubo `[groups-fanout]` y con qué resultado, y si el
     `/groups/push` de A trajo `applied`;
   - device de B, Console.app filtrando `subsystem:com.yala category:Push`: si aparece
     `PUSH RECEIVED kind=yala(groups-sync)` y a qué hora.
5. **Sub-ajustes de iOS en B** antes de sacar conclusiones (Alertas / Centro / Pantalla bloqueada).

Con los pasos 1–4 se decide entre H1–H4 **sin escribir una línea de código**. Solo entonces este ticket
recibe su sección `Causa (código)` con `fichero:línea`, y solo entonces el fix mínimo con sus tests.

## Acceptance Criteria

- [ ] Con permiso de iOS concedido en B (incluidas Alertas) y el toggle de grupos en ON, un gasto creado
      por A **notifica a B mientras B está fuera de la app** — sin que B tenga que abrirla.
- [ ] Ese aviso llega también cuando el proceso de B fue desalojado por iOS (no solo con la app
      residente en background).
- [ ] A, que es el actor, sigue **sin** recibir notificación (no se reintroduce el eco al autor).
- [ ] Cuando el aviso en background no sea posible, el foreground sigue siendo la red: al entrar en la
      app la notificación aparece **una sola vez** y no se duplica con la que ya llegó en background.

Verificación pendiente: los cuatro criterios se comprueban cuando exista causa y fix. **Hoy no hay
device-QA de este ticket y no se inventa PASS.**

## HOLD

Cero Swift y cero cambios en el gateway en este ticket. `status` sigue `backlog`. Sin TestFlight, sin
tag de release, sin App Store. A7 / M5 siguen en HOLD.

## Relacionado

- Atribución y eco al autor: `tickets/qa/group-notif-credits-payer-not-editor.md` (**abierto**; lleva
  una nota del mismo día con el «A no recibió / B solo al abrir»).
- Cierre de la premisa «no llegan las notificaciones»:
  `tickets/done/notifications-not-delivered-testflight.md` — su mapa de qué tipos se agendan de verdad
  en iOS sigue siendo válido y ahorra trabajo aquí.
- Notificaciones de aprobación y por qué el copy no promete aviso: `Yala/Utils/L10n.swift:2253-2257` y
  `tickets/qa/groups-approval-banner-stays.md`.

---

## Actualización 2026-09-03 — el mecanismo que mejor lo explicaba ya no existe

Medido en `59d76e6e` (este árbol), no inferido. El commit `eb6593ce` cambió el emisor **compartido**:
`fanOutGroupPush` es el único emisor de push del gateway (`grep` sobre `gateway/src`: dos llamadores,
`routes.ts:145` en la ruta de deltas —la de los gastos— y `rpc.ts:247/260` en las de membresía), y ahora
manda `pushType: "alert"` (`routes.ts:261`) con `apns-priority: 10` y `apns-expiration` de 24 h
(`apns.ts`, `ALERT_EXPIRATION_SECONDS`). El banner lo pinta **iOS**; el `content-available` viaja en el
mismo push para que la app, si despierta, lo reemplace por el texto rico.

**Qué le pasa a las hipótesis de arriba:**

| | Estado tras `eb6593ce` |
|---|---|
| **H1** (push llegó, el ciclo no corrió: `context == nil`) | **Ya no produce el síntoma.** El banner no depende de que el ciclo corra. El residual de `GroupsSyncClient.swift:453-455` sigue existiendo, pero ahora solo retrasa el texto rico, no el aviso. |
| **H3** (APNs lo descartó: `expiration 0` + presupuesto de silent) | **Atacada por los dos lados**: prioridad 10 y ventana de 24 h. |
| **H2** (el fan-out no salió: `PUSH_ROLE_JWT` ausente/revocado en producción) | **VIVA, sin cambios.** Sigue siendo un no-op silencioso con log. |
| **H4** (B nunca tuvo token registrado) | **VIVA, sin cambios.** |
| **H5** (rate-limit / sub-ajustes de iOS) | **Cambia de forma:** el banner del sistema **no** pasa por `GroupNotificationService`, así que el rate-limit de 5 min por grupo ya no lo filtra. Si A hace dos cambios seguidos, ahora B puede recibir **dos** banners genéricos donde antes recibía uno. Añadir eso al guion. |

**Por eso pasa a `qa` y no a `done`:** nada de esto está verificado en device. App Attest en `enforce`
exige TestFlight con dos teléfonos, así que lo único medido es que el gateway compone y envía lo
correcto. El guion de «Cómo se verifica» sigue vigente tal cual, con dos ajustes: el paso 2 (proceso
desalojado) es ahora el que más información da —es justo el que H1 predecía que fallaba—, y conviene
encadenar dos cambios de A dentro de 5 min para medir el punto de H5.

**Se comprueba en la misma pasada que `aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app`**: mismo
emisor, mismos dos teléfonos, mismo `wrangler tail`.
