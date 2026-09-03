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
