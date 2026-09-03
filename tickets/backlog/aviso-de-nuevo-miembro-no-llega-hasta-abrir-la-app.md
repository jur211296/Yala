---
id: aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app
status: backlog
priority: high
area: grupos
created: 2026-09-02
updated: 2026-09-02
---

# Cuando alguien se une a tu grupo el aviso llega TARDE: no lo ves hasta que abres la app por tu cuenta

## Qué le pasa al usuario

Eres admin de un grupo. Mandas el enlace de invitación, la otra persona lo abre y pide entrar. **En tu
teléfono no pasa nada.** Ni banner, ni sonido, ni punto rojo. Puede quedarse así minutos, horas o días.

El aviso aparece **en el momento en que tú abres Yala por tu cuenta** — porque te acordaste, o porque
entraste a otra cosa. Entonces sí: sale «👋 X quiere unirse a [grupo]», intacto y bien traducido. Nunca
se pierde; simplemente **espera a que tú llegues**.

El efecto práctico es doble y va en cascada:

1. **Quien invita no se entera de que tiene que aprobar.** El aviso existe justamente para eso, y no
   cumple su función: no interrumpe, no recuerda, no llega. Aprobar deja de ser una reacción y pasa a
   ser algo que tienes que recordar hacer.
2. **Quien se une queda esperando sin saber cuánto.** Mientras está `pendingApproval` ve el grupo y el
   listado de gente, pero **cero contenido financiero** — y encima al admin nadie le ha avisado de que
   hay alguien esperando. La espera del invitado dura literalmente lo que el admin tarde en abrir la
   app por otro motivo.

**El aviso no está roto ni mal escrito. Lo que falta es el empujón que lo dispara en el momento en que
ocurre.** Es un problema de CUÁNDO, no de QUÉ.

## Confirmación de la hipótesis de partida

Este ticket nació de una sospecha de un tercero: *«la función que reparte los avisos de cambio de
miembros solo la llamaría el endpoint de push, no el de unirse»*. **Se verificó y se sostiene** — y
resultó ser más fuerte de lo que decía. No es solo que unirse no llame al reparto: es que un cambio de
miembros **no puede** llegar por el único canal que lo dispara. Ver la evidencia.

## Lo medido en este árbol (`2.1` @ `553b91c9`)

Todas las coordenadas de abajo se re-midieron en `553b91c9`, con `Yala/`, `gateway/` y
`supabase-groups-staging.ddl` limpios respecto a HEAD (`git status --porcelain` de esas rutas: vacío).
Si al retomar el árbol el commit ya no es ése, re-medir antes de obedecerlas.

### 1. El aviso es LOCAL y nace después del pull — no viaja por APNs

- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:2648` — al aplicar un `group_members` del pull,
  y **solo si la fila es nueva en local** (`if existing == nil`, `:2646`), se llama a
  `classifyNewMemberForNotification`.
- `GroupsSyncClient.swift:2171-2196` — esa función clasifica vía
  `MemberChangeNotificationLogic.classifyNewMember` (`:2179`) y acumula en `newPendingMembers` /
  `newMembers`.
- `GroupsSyncClient.swift:1937` — al cierre de la página aplicada: `if !changes.isEmpty {
  onRemoteChanges(changes) }`; el default de ese closure (`:244-245`) es
  `GroupNotificationService.shared.processRemoteChanges`.
- `Yala/Services/Groups/GroupNotificationService.swift:68` — `processRemoteChanges`;
  `:286-292` elige el texto (pendiente tiene prioridad sobre «se unió»); `:290` y `:327-337` lo componen.
- `Yala/Services/NotificationService.swift:222` — `sendNotification`, que agenda una notificación
  **local**.

⇒ **El aviso se fabrica en el teléfono del admin, y solo después de que un pull le haya bajado la fila
del nuevo miembro.** Es exactamente tan tardío como ese pull.

### 2. Los textos existen y están localizados (no hay nada que escribir)

- `Yala/Utils/L10n.swift:6279-6281` → `notifications.groups.newMember`;
  `Yala/Resources/es.lproj/Localizable.strings:2563` → `"🙌 %@ se unió al grupo"`.
- `Yala/Utils/L10n.swift:2231-2238` → `groups.notifications.newPendingRequest` + su body;
  `Yala/Resources/es.lproj/Localizable.strings:4050` → `"👋 %@ quiere unirse a %@"`.
- Comprobado que existen también en `de.lproj` (`:2379`, `:4060-4061`) y `zh-Hans.lproj` (`:2377`,
  `:4092-4093`).

### 3. Lo único que despierta el teléfono sin abrir la app es un silent push, y solo lo dispara `/groups/push`

- `gateway/src/groups/routes.ts:145` — `c.executionCtx.waitUntil(fanOutGroupPush(...))`, dentro de
  `handleGroupsPush` (`:89`).
- **`fanOutGroupPush` (`gateway/src/groups/routes.ts:167`) tiene UN solo call-site de producción en todo
  el gateway: esa línea 145.** Medido con `grep -rn "fanOutGroupPush" gateway/` — las demás
  apariciones son el propio `export`, dos comentarios (`gateway/src/metrics.ts:26`,
  `gateway/src/groups/killSwitch.ts:75`) y `gateway/test/push.fanout.unit.test.ts`.
- `gateway/src/groups/routes.ts:215` — el envío real (`sendPush`). Medido: en todo `gateway/src/` solo
  hay otro emisor, `gateway/src/push/routes.ts:42`, que es la ruta **DEBUG** del spike G0 y responde
  **404 fuera de dev** (`push/routes.ts:21`, gate `allowsDevBypass`).

### 4. Unirse NO pasa por `/groups/push`, y no puede pasar

- Unirse es una RPC: `gateway/src/index.ts:102` monta `POST /groups/rpc/:fn` →
  `handleGroupsRpc` (`gateway/src/groups/rpc.ts:110`), y `join_group` está en su allowlist
  (`rpc.ts:51`). **Leído el fichero entero: `rpc.ts` no importa ni llama `fanOutGroupPush` ni
  `sendPush`.** Termina en `callRpc` (`:165`) → passthrough del body (`:182`). Lo mismo vale para
  `approve_member` (`rpc.ts:52`), que es la otra mitad del flujo.
- Y no es que «se le haya olvidado» al endpoint de unirse: **`group_members` es PULL-ONLY**. El manifiesto
  lo declara (`gateway/group_capability_manifest.json`, entidad `group_members` con
  `pull_only: true` — la única de las cinco), `gateway/src/groups/manifest.ts:53-56` lo lee, y
  `gateway/src/groups/routes.ts:263-266` rechaza el delta **antes** de llamar a la RPC.
  ⇒ Una fila de miembros **jamás** puede viajar por `/groups/push`, que es lo único que dispara el
  fan-out.
- Tampoco hay notificación desde la base de datos: `join_group` (`supabase-groups-staging.ddl:425`)
  inserta el member `pendingApproval` (`:515-521`) y devuelve; **cero `pg_net` / `pg_notify` /
  `net.http` en todo el DDL** (grep sin resultados).

⇒ **Conclusión medida: para un cambio de miembros no se emite ningún push. No es un push que falla —
es un push que no existe.** Esto lo distingue del ticket hermano de gastos, donde el push sí se emite y
la duda es si llega.

### 5. Lo que sí acaba trayendo el aviso (por eso es «tarde» y no «nunca»)

- `Yala/App/AppBootstrapper.swift:339` — `startIfEligible` en arranque en frío.
- `Yala/App/AppBootstrapper.swift:1507` — `startIfEligible(context:trigger: "foreground")` al volver a
  activo. **Éste es el camino compatible con «aparece justo al abrir la app».**
- `GroupsSyncClient.swift:343` — con la app en marcha corre un loop de cadencia (`runLoop`), con
  `SyncCadencePolicy.pullInterval = 60` segundos (`Yala/Services/CloudSync/SyncCadencePolicy.swift:33`).
- `GroupsSyncClient.swift:487-488` — `syncNowFromUI`, el pull-to-refresh de la lista y del detalle de
  grupos (`GroupsViewModel.swift:205`, `GroupDetailViewModel.swift:137`).
- `GroupsSyncClient.swift:495` — ciclo tras un save local propio.
- Y de rebote: si **otro** compañero empuja un gasto a ese mismo grupo, ese `/groups/push` sí dispara el
  fan-out, el admin despierta, pulla y de paso se entera del miembro. Es un despertar **por casualidad**,
  no una garantía.
- `Yala/App/YalaAppDelegate.swift:76` — la rama que reacciona al silent push
  (`syncNowFromPush`) existe y funciona; simplemente **para este evento nadie la despierta**.
- Medido además que no hay red de fondo: `Yala/App/BackgroundTaskManager.swift` solo registra tareas de
  **refresco de widget** y **notificaciones de informes** (`:67-105`) — ninguna cicla el canal de grupos.

### 6. La otra mitad: quien espera aprobación tampoco recibiría el push aunque se emitiera

Ya estaba escrito y **se re-verificó**: `supabase-groups-staging.ddl:1614`, dentro de
`get_group_push_tokens` (`:1600`), filtra `gm.status = 'active'` — un `pendingApproval` no está en la
lista de destinatarios. Coincide con lo que `Yala/Utils/L10n.swift:2250-2258` documentó el 2026-08-12.
**No es el defecto de este ticket** (aquí el afectado es el admin), pero cualquier arreglo que se diseñe
tiene que decidir qué hace con este caso, o el invitado seguirá igual de a ciegas.

## Consecuencia secundaria — esto es INFERIDO, no medido en device

De dos hechos medidos —(a) la clasificación solo corre cuando la fila es nueva en local
(`GroupsSyncClient.swift:2647`), y (b) un `pendingApproval` visto por alguien que no es admin clasifica
como `.ignore` (`Yala/App/Logic/MemberChangeNotificationLogic.swift:98-99`)— **se infiere** que un
compañero que **no** es admin puede no recibir nunca el «🙌 X se unió al grupo»: si su teléfono pulla
durante la ventana en que X está pendiente, se guarda la fila en silencio, y cuando el admin aprueba, la
fila **ya existe** en local ⇒ no se vuelve a clasificar. Solo recibiría el aviso si su primer contacto
con esa fila fuera ya con el miembro `active`.

Y aquí está lo desagradable: **el defecto principal alarga justo la ventana que provoca este segundo**,
porque el admin tarda más en aprobar precisamente por no haber sido avisado. **No se afirma que ocurra
en producción: hace falta comprobarlo en device antes de darlo por bueno.**

## Lo que NO se pudo medir desde aquí

Se dice explícitamente para que nadie lo lea como verificado:

- **El gateway desplegado.** Todo lo del gateway se midió sobre el **código del repo**, no sobre lo que
  corre hoy en producción. No se comprobó `wrangler deployments`, ni secrets, ni logs. Es una lectura de
  fuente, y la fuente es concluyente por estructura (`group_members` pull-only ⇒ nunca hay fan-out),
  pero **la correspondencia fuente↔despliegue queda como supuesto**.
- **El DDL vivo.** `supabase-groups-staging.ddl` es el fichero del repo. No se consultó la base real.
- **Ninguna reproducción en device ni en simulador.** Este ticket **no tiene QA**: no se lanzó la app, no
  se hizo un join real, no se miró Console.app ni `wrangler tail`. El síntoma descrito arriba se deduce
  del camino medido en el código, y sigue **pendiente de confirmar con dos cuentas**.
- **Si el admin tiene el permiso de notificaciones concedido** en el caso reportado — es la premisa que
  cerró `tickets/done/notifications-not-delivered-testflight.md` y hay que descartarla en cualquier
  reproducción antes de culpar a nada.

## Esto NO es

| Ticket | De qué va | Por qué no es este |
|---|---|---|
| `tickets/backlog/groups-expense-notif-only-on-foreground.md` | Un **gasto** de grupo solo notifica al entrar en la app | Mismo síntoma, causa distinta y **estado de conocimiento distinto**. Allí el push **sí se emite** (un gasto va por `/groups/push`) y el ticket lista H1–H5 sin declarar causa. Aquí el push **no se emite en absoluto**, y eso está medido por estructura. Los dos comparten el final del camino (pull → notificación local); **arreglar uno no arregla el otro**. |
| `tickets/done/group-notif-credits-payer-not-editor.md` | A quién se atribuye y a quién se suprime el eco | Va de **qué dice** el aviso. Éste va de **cuándo** aparece. |
| `tickets/done/groups-approval-banner-stays.md` | El banner «esperando aprobación» se quedaba pegado | Es la UI **dentro** de la app del invitado, no el aviso al admin. |
| `tickets/backlog/groups-pending-member-can-open-group.md` | Qué puede abrir un pendiente | Permisos, no avisos. |
| `tickets/done/notifications-not-delivered-testflight.md` | «no llegan las notificaciones» en TF | Se cerró como permiso de iOS en OFF. Aquí el aviso **sí se muestra**, solo que tarde. |

## Causa: declarada del lado servidor, con el alcance justo

**Sí se declara** —contra la costumbre del ticket hermano— porque no depende de medir un despliegue: es
estructural y se lee en el repo. **No se toca código en este ticket.**

> No existe ningún emisor de push para un cambio de miembros. El único emisor de producción es
> `fanOutGroupPush`, con un solo call-site (`gateway/src/groups/routes.ts:145`, dentro de
> `POST /groups/push`), y `group_members` está declarada `pull_only` y se rechaza antes de llegar ahí
> (`routes.ts:263-266`). La RPC por la que sí ocurre el join (`join_group`) no reparte nada.

Lo que queda por decidir **no es la causa sino el remedio**, y son opciones incompatibles entre sí — por
eso este ticket no propone una: (a) que `handleGroupsRpc` dispare el fan-out para las RPC que cambian
membresía (`join_group`, `approve_member`, y valorar `remove_member` / `leave_group`); (b) que lo dispare
la base de datos; (c) tratarlo como un aviso distinto con su propio destinatario. Cada una arrastra
preguntas propias sobre a quién despertar, y la (a) además tiene que resolver el caso del §6.
**Eso es trabajo de `/spec`, no de este ticket.**

## Acceptance Criteria

- [ ] Con el permiso de iOS concedido y el toggle de grupos en ON, cuando alguien pide unirse a un grupo
      el admin recibe «👋 X quiere unirse a [grupo]» **sin haber abierto la app** — con la app en segundo
      plano.
- [ ] Ese aviso llega también cuando iOS ya había desalojado el proceso del admin (no solo con la app
      residente en background).
- [ ] Quien se une **no** recibe un aviso sobre sí mismo, y el resto del grupo no recibe avisos espurios
      durante el import inicial de una zona (no se reintroduce el bug «Jür se unió al grupo»).
- [ ] Al abrir la app, el aviso **no se duplica** con el que ya llegó estando fuera.
- [ ] Queda decidido y escrito qué ve quien está esperando aprobación (§6): o recibe algo, o se declara
      explícitamente que no y el copy no promete lo contrario.

**Verificación pendiente.** Ningún criterio está comprobado hoy. **No hay QA de este ticket y no se
inventa PASS.**

## HOLD

Cero Swift, cero gateway, cero SQL en este ticket. `status` sigue `backlog`. Sin TestFlight, sin tag, sin
App Store.

## Relacionado

- Hermano de síntoma, causa distinta: `tickets/backlog/groups-expense-notif-only-on-foreground.md`.
  Su mapa del camino de notificación y sus señales de diagnóstico (`wrangler tail`, `PushBreadcrumb` en
  Console.app) **sirven tal cual aquí** y ahorran trabajo.
- Por qué el copy de espera no promete aviso, ya medido el 2026-08-12: `Yala/Utils/L10n.swift:2250-2258`.
- Reconciliación de la fase del join en el cliente:
  `tickets/blocked/groups-join-intent-reconciler.md`.

---

## 2026-09-03 · Recomendación de arquitectura (encargo del owner: «lo más robusto, para TODO Grupos»)

Producida por un panel de 18 agentes: 5 lentes mapeando el sistema real (gateway, cliente iOS, lo que
ya funciona, infraestructura, tickets), 4 diseños independientes desde ángulos distintos
(fiabilidad · simplicidad · evolución · modos de fallo) y 2 refutaciones adversariales por diseño.
**Las cuatro propuestas fueron refutadas 2/2**; ninguna sobrevivió intacta, y la recomendación es una
síntesis, no una ganadora.

### 0 · ~~BLOQUEANTE: puede que el sistema sea un no-op~~ — **REFUTADO el 2026-09-03, MIDIENDO**

El panel afirmó que el fan-out podía ser un no-op silencioso por falta de secrets, apoyándose en el
comentario de `gateway/src/groups/routes.ts:174` («Prod arranca así hasta que el owner cargue
APNS_KEY_ID/APNS_AUTH_KEY»). **Es falso, y el propio repo lo desmentía dos ficheros más allá.**

Medido con `npx wrangler secret list --env production` (desde `gateway/`, que es donde vive el
`wrangler.toml` — correrlo desde la raíz da «No environment found», que fue el primer error):

| Requisito del fan-out | Estado real |
|---|---|
| `APNS_AUTH_KEY` | **secret PRESENTE** en producción |
| `PUSH_ROLE_JWT` | **secret PRESENTE** en producción |
| `APNS_KEY_ID` | `var` declarada en `wrangler.toml:104` (no es secret) |

Y `gateway/wrangler.toml:101-104` ya lo decía por escrito, con fecha: «APNs (G8-1, **encendido
2026-07-16**) … está subida como secret `APNS_AUTH_KEY` en **AMBOS** envs».

**La lección de método, que vale más que el hallazgo:** el comentario de `routes.ts` describía el
estado del día en que se escribió y nunca se actualizó al encender APNs. Un panel de cinco lentes lo
leyó y lo dio por vigente porque **ninguna cruzó el comentario del código con la configuración**. Es
la trampa de siempre de este repo, esta vez dentro del propio código y sobreviviendo a una revisión
adversarial. Los dos `console.log` de `routes.ts:175` y `:181` siguen siendo correctos como
salvaguarda; lo obsoleto es su comentario, que induce a creer que ése es el estado de producción.

### 1 · La arquitectura: «Alerta con eco silencioso»

Es el diseño de *simplicidad* con tres injertos, y **sin outbox**. Los dos diseños con outbox
puntuaron peor (3,5 y 3,0) porque su garantía transaccional **es falsa donde importa**:
`apply_group_delta` es `SECURITY INVOKER` (`ddl:932`), así que para GASTOS —el caso del ticket vivo—
el encolado sigue siendo una llamada de red posterior. Se pagaría una tabla, un cron y un reaper por
una garantía que no cubre el caso principal.

Los injertos, cada uno de un diseño distinto: **(a)** el payload lleva `alert` **y**
`content-available: 1`; **(b)** `apns-expiration` parametrizado, 24 h para alerta; **(c)** audiencia
por evento, con una RPC para admins y otra para el destinatario individual.

### 2 · Qué pasa, en lenguaje de usuario

Ana pide entrar al grupo. El teléfono del admin **suena y muestra un banner aunque la app esté
cerrada y el teléfono bloqueado**, con texto genérico («Novedades en un grupo»). Si el teléfono
estaba apagado, le llega al encenderlo, hasta 24 h después. En paralelo, si iOS lo permite, la app se
despierta por detrás, se trae los datos y **reemplaza** ese banner por el bueno («Ana quiere unirse a
Viaje a Cusco»). Si no puede, el aviso pobre ya cumplió su función.

La diferencia con hoy es esa: **el aviso deja de depender de que la app corra.**

### 3 · El cambio, pieza a pieza

| Pieza | Cambio | Coordenada |
|---|---|---|
| APNs | `apns-expiration` deja de ser `"0"` fijo · `collapse-id` · `pushType: "alert"` (ya soportado, cero callers) | `apns.ts:96`, `:23`, `:85` |
| Payload | `aps.alert{loc-key}` **+** `content-available: 1` + `deepLink` top-level con el UUID pelado (el `group_id` del servidor es `SplitGroup-<uuid>`) | `NotificationService.swift:45`, `SplitGroup.swift:102` |
| Emisor de membresía | `waitUntil(fanOutGroupPush(...))` tras el `callRpc` — hoy **no existe ningún emisor** ahí | `rpc.ts:165` |
| Audiencia | `get_group_admin_push_tokens` y `get_member_push_token` (**sin** el filtro `status='active'`); el switch de RPC hay que cablearlo: hoy el nombre y sus 3 args están hardcodeados | `routes.ts:190`, `ddl:1614` |
| Delegate | `UNUserNotificationCenter.delegate` pasa a `didFinishLaunching`; hoy se asigna en el `.task` de SwiftUI ⇒ **el tap desde app cerrada se pierde** | `AppBootstrapper.swift:140` |
| Token | `attemptUpload()` también en el seam de inicio de sesión — hoy sólo en boot, y **ése es el fallo dominante** | `PushTokenRegistrar.swift:91-93` |
| Poder ver algo | `writeDataPoint` a Analytics Engine: hoy el gateway **no escribe ni un punto** y los canarios son `console.log` que sólo existen con `wrangler tail` abierto | `metrics.ts:102` |

### 4 · Lo que NO cubre, honestamente

| Caso | Resultado |
|---|---|
| Permiso en OFF o `notDetermined` | **Cero avisos**, y APNs devuelve 200 con el canario en verde. Ninguna arquitectura lo arregla: sólo se puede *ver*, guardando `authorization_status` |
| Focus / Resumen programado | La alerta se retiene horas. Exige el entitlement `usernotifications.time-sensitive`, **que hoy no existe** |
| Sin token (instalación nueva, restore) | Inalcanzable hasta abrir la app |
| Offline >24 h, o ráfaga | APNs guarda **una** notificación por device: de 5 gastos se ve 1 |
| Idioma | `loc-key` lo resuelve iOS contra el idioma del SISTEMA e ignora el override in-app ⇒ iPhone en inglés + Yala en español da banner en inglés hasta que el pull lo reemplace |

**Y un dato que rompe tests: son 16 `.lproj`, no 7.** Cualquier paridad escrita con «7» nace rota.

### 5 · Fases

| Fase | Qué | Valor por sí sola |
|---|---|---|
| **0** | Medir secrets, deployment y permiso (30 min del owner) | Puede cerrar el caso entero |
| **1** | l10n de las claves en los 16 idiomas + delegate en `didFinishLaunching` + `attemptUpload` en sign-in | Sin esto, la F2 pinta la clave cruda en la pantalla de bloqueo |
| **2** | `apns-expiration` + alerta + `content-available` en el fan-out actual | **Arregla el caso de gastos.** Una jornada |
| **3** | Emisor de membresía + las dos RPC de audiencia | Cierra este ticket |
| **4** | `notif_prefs`, `unregister` en el wipe, datapoints a AE, entitlement Time-Sensitive | Hace el sistema operable |

**La F1 va ANTES que la F2, y las cuatro propuestas lo pusieron al revés**: las cuatro se comieron esa
refutación.

### 6 · Lo que el panel NO pudo cerrar

**Medido**: todo lo del repo en `2cbfae4b`. **Inferido**: que APNs acepte `content-available` dentro
de un `apns-push-type: alert` (si no, son dos pushes); que el `.task` de SwiftUI no corra en un launch
de background; el presupuesto de iOS para silent push. **No medido por nadie**: los secrets, el Worker
desplegado y el DDL vivo de producción (`supabase-groups-staging.ddl` se autodescribe como molde
*offline* de staging).

Nada de esto se verifica en simulador: App Attest en `enforce` obliga a TestFlight con dos teléfonos.

### 0-bis · La causa REAL, ya sin el falso bloqueante (medida el 2026-09-03)

Con los secrets descartados como problema, el diagnóstico queda limpio y son **dos cosas
independientes**, las dos verificadas en el árbol:

**(1) El push que existe es SILENCIOSO por diseño.** `gateway/src/groups/routes.ts:218`:

```ts
payload: { aps: { "content-available": 1 }, yala: { kind: "groups-sync" } },
```

No lleva `alert`. Un `content-available` **no pinta banner ni suena**: sólo despierta la app para que
sincronice, y el aviso que ve la persona lo fabrica la app **localmente** después. El propio
comentario de `:159` lo dice: «Despierta con un silent push a los co-members ACTIVOS».

⇒ El título de este ticket es literal, y aplica a TODO Grupos: el aviso **depende de que la app
corra**. Si iOS no entrega el silent push —presupuesto agotado, app force-quit, batería baja— no hay
notificación. Eso es también, y sin más misterio, el ticket `groups-expense-notif-only-on-foreground`.

**(2) Las RPC de membresía no emiten NADA, ni siquiera el silent push.** `fanOutGroupPush` tiene
**un único llamador** en todo el gateway: `routes.ts:145`, dentro de la ruta de deltas de grupo
(gastos). `gateway/src/groups/rpc.ts` —donde viven `join_group` y `approve_member`— no lo llama.

⇒ Para el caso de este ticket ni siquiera hay que discutir de entrega: **no hay emisor**.

**Qué significa para la recomendación de abajo:** el paso 0 cae, pero el diseño no. «Alerta con eco
silencioso» ataca exactamente estos dos puntos — añadir `alert` al payload para que el aviso lo pinte
el SISTEMA sin depender de la app (1), y cablear el emisor en las RPC de membresía (2). Lo que cambia
es el orden y la urgencia: la fase 2 pasa a ser la que arregla el problema de fondo de todo Grupos, y
la fase 3 la que cierra este ticket en concreto.

---

## 2026-09-03 · IMPLEMENTADO (gateway + BD de staging). Falta el deploy, que es del owner

Decisiones del owner: banner **directo**, los dos cambios **en un bloque**, **sin flag** de apagado, y
aceptar que `loc-key` resuelva por el idioma del sistema.

### Y una decisión que la medición obligó a cambiar

Se pidió banner «con nombre, concepto e importe». **No es implementable, y no por esfuerzo:**

- `split_groups.name`, `split_expenses.expense_description`, `.amount` y `group_members.display_name`
  son **`bytea` †** (G7, cifrado at-rest). El Worker no los puede leer, y descifrarlos en el borde
  rompería el motivo entero de que sean bytea.
- El «te toca %@» de las claves locales es **distinto para cada destinatario**, y el fan-out manda el
  MISMO payload a todos los tokens.
- Y un push **no corresponde a un gasto**: el fan-out agrega por `group_id` todos los deltas aplicados
  de una tanda.

⇒ El banner del servidor es genérico **por obligación**, pero **específico por evento**, que sí se
puede: el tipo de evento no es secreto. El texto rico lo sigue poniendo la app, que es la única que
puede descifrarlo, cuando el eco la despierta.

### Lo hecho

| Pieza | Qué |
|---|---|
| `qa/cloud/g8_03_membership_push_audiences.sql` | **Dos RPC nuevas.** `get_group_admin_push_tokens` (la existente no devuelve el rol ⇒ avisaría a todo el grupo) y `get_group_member_push_tokens` (la existente filtra `status='active'` ⇒ al rechazado **no se le puede avisar**). Mismos grants: `revoke` a public/anon/authenticated, `grant` sólo a `yala_push`. **Aplicada a STAGING y verificada**; producción es del owner |
| `gateway/src/push/apns.ts` | `apns-expiration` deja de ser el literal `"0"` («entrégalo ya o deséchalo»): 24 h para alerta. Con `0`, el aviso se perdía entero con el teléfono apagado |
| `gateway/src/groups/routes.ts` | `pushType: "alert"` + payload con `alert` **y** `content-available`. Y `fanOutGroupPush` gana audiencia y `locKey`, con el resolver de RPC dejando de estar hardcodeado |
| `gateway/src/groups/rpc.ts` | **El emisor que no existía.** `join_group` → admins; `approve_member`/`remove_member` → la persona afectada, por `member_key` |
| 16 `.lproj` | `remoteActivity`, `remotePendingRequest`, `remoteMembershipUpdate`. Paridad verde |

### Dos trampas que costaron una corrida cada una

1. **`c.executionCtx` LANZA sin ExecutionContext.** El cableado convertía en **500** un RPC que ya
   había tenido éxito, en cuanto un test llamaba `app.fetch(req, env)` sin 3er argumento. Rompió tres
   goldens. Se resuelve una vez en el emisor y se omite el aviso con log: un push best-effort jamás
   puede tumbar la operación que lo dispara.
2. **`es` y `pt` son ALIAS**, copia idéntica de `es-419`/`pt-BR`. Traducirlos a mano rompe
   `aliases_haveIdenticalValues_toTheirBase`, que lo cazó al instante.

### Verificación

`npm test` en `gateway/`: **321 pasan**, 1 falla (`account.goldens` nº 20, rojo preexistente con
ticket propio: `account-goldens-freeze-read-test-times-out`). Typecheck sin errores nuevos en `src/`.

**Cuatro mutantes a rojo**, y el primero es el que da valor a los tests del emisor: hasta escribirlos,
cambiar la audiencia de la solicitud de `admins` a `coMembers` —o sea, anunciar a todo el grupo que
alguien pidió entrar— **dejaba la batería entera en verde**.

| Mutante | Cazado por |
|---|---|
| Quitar el eco `content-available` | el golden y el unit del payload |
| Volver `apns-expiration` al literal `"0"` | el golden |
| Solicitud a `coMembers` en vez de `admins` | el test del emisor (**antes sobrevivía**) |
| Avisar también del re-tap del enlace | el test del emisor |

### Lo que NO está hecho, y es del owner

1. **Deploy.** `npm run deploy:production` en `gateway/` y aplicar `g8_03` a la BD de **producción**.
2. **Verificación real.** Nada de esto prueba que Apple entregue el banner: App Attest en `enforce`
   exige TestFlight con dos teléfonos. Lo medido es que el gateway compone y envía lo correcto.
3. **El cliente no distingue tipos de push.** `YalaAppDelegate` lee `yala.kind` sólo para un
   breadcrumb y dispara un sync para cualquier payload; no hay `switch`, ni se propaga `deepLink`, así
   que tocar el banner no lleva al grupo. Es trabajo aparte y **no** bloquea a este.
