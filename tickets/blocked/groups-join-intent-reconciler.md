---
id: groups-join-intent-reconciler
status: blocked
priority: high
area: "groups, sync, cloudkit, onboarding"
created: 2026-07-11
updated: 2026-09-02
source: YalaWiki/Bugs/qa_groups-join-intent-reconciler.md
---


> [!bug] Corrida real (Pia, 2026-07-11): aceptó un enlace de invitación de semanas y (1) al owner JAMÁS le llegó la solicitud de aprobación, (2) recibió la notif espuria "Jür se unió al grupo", (3) la UI le dijo "¡Todo listo!" sin member real. Root cause + fix en branch `2.0.5` (plan `~/.claude/plans/abundant-hatching-hippo.md`).

# Validar en TestFlight: join intent + reconciliador + baseline de notificaciones

## Qué lo desbloquea

**Dos teléfonos reales, los dos con la app instalada desde TestFlight, y una cuenta distinta en
cada uno.** No es una preferencia de comodidad: **desde el simulador esta prueba no se puede
correr**, y por eso el ticket está aquí y no en `qa/`.

La cadena, medida hoy (rama `2.1`, HEAD `553b91c9`):

1. App Attest —la prueba de que quien llama es la app auténtica en un aparato auténtico— **no
   existe en el simulador**: `DCAppAttestService.isSupported` devuelve `false` y el cliente se
   desvía a su bypass de desarrollo (`Yala/App/Services/AppAttestClient.swift:122`, que salta a
   `devTokenOrThrow()` en `:256`).
2. Ese bypass es `#if DEBUG` y viaja con un secreto compartido que **el gateway de producción no
   honra nunca** — es de staging por diseño (`gateway/wrangler.toml:85`; la ruta que lo atiende
   comprueba el secreto en `gateway/src/attest/routes.ts:171`).
3. Producción corre en modo estricto: `ENFORCE = "enforce"` (`gateway/wrangler.toml:91`; staging
   corre `"observe"` en `:32`). Sin sesión de attest la llamada se rechaza con **401
   `yala_attest_required`**, y las rutas que unirse a un grupo necesita —`/groups/rpc/:fn`,
   `/groups/push`, `/groups/pull`— están todas detrás de esa guard
   (`gateway/src/groups/rpc.ts:98`, `gateway/src/groups/routes.ts:77`).

⇒ **el servidor responde 401 y el invitado no llega a entrar.** Un build de Xcode tampoco vale
aunque lo corras en un iPhone enchufado: el AAGUID de desarrollo da 401 contra producción siempre
(`.claude/rules/gateway-attest.md`). De ahí que la condición sea *TestFlight*, no *device*.

Y hacen falta **dos** aparatos porque lo que se mide es literalmente lo que ocurre entre dos
personas: una invita y la otra entra. Con uno solo no se cierra ningún caso, ni a medias.

Lo que sí corre sin dispositivos ya corre, y no sustituye a esto: los estados de la pantalla de
bienvenida se ejercitan en XCUITest congelando la fase con `-uitest-join-phase`
(`Yala/App/UITestHooks.swift:185`, `YalaUITests/Flows/GroupInviteOnboardingUITests.swift`).

## Implementación

### 2026-07-12 — `dea3e61b` (branch 2.0.5)

**Resumen:** las 3 piezas del plan aterrizaron en un commit único (43 archivos +2731/−90): join intent persistente + reconciliador (bugs 1+3 de raíz), baseline de notifs del primer import + autoexclusión (bug 2), onboarding honesto con tracker observable + banner + l10n, hardening del enqueue silencioso.

**Archivos clave** (los que siguen vivos, re-medidos el 2026-09-02):

- `Yala/Services/Groups/PendingJoinStore.swift` (NUEVO) — intent multi-entry por zona, TTL 7d, cap 8.
- `Yala/Services/Groups/GroupJoinReconciler.swift` (NUEVO) — consume intents; inyectable para tests.
- `Yala/Services/Groups/GroupJoinIntentTracker.swift` (NUEVO) — @Observable, fases reales para UI; retry() por razón.
- `Yala/App/Logic/GroupJoinReconcileLogic.swift` + `GroupInviteOnboardingLogic.swift` (NUEVOS) — decisiones puras.
- `SplitGroup.swift` — `initialMemberImportStartedAt` LOCAL-only (sin translator ⇒ sin deploy CloudKit).
- `GroupInviteOnboardingView.swift` — reescrita sobre step computado; `detectFinalStep` eliminado.
- ~~`SplitSyncManager.swift` — acceptShare persiste intent + reporta al tracker; hook en processPendingRemoteChanges; handler `didFetchRecordZoneChanges` (antes no-op) cierra el baseline; clasificación con firma nueva; markPendingChange/Deletion con log+canario.~~ **D — el fichero no existe** (`find` por `SplitSyncManager*`: 0 resultados). Ver abajo dónde vive hoy cada mitad.

**Dónde vive hoy el contador de notificaciones del primer import** (re-medido el 2026-09-02, no
heredado del texto anterior). Ambos extremos están en
`Yala/Services/CloudSync/Groups/GroupsSyncClient.swift`:

- **Lo abre** `:2531` — `model.initialMemberImportStartedAt = now()`, en el brazo `isBorn` del apply
  del pull: un `SplitGroup` que NACE del pull implica que sus miembros preexistentes vienen detrás,
  así que se silencian sus avisos de «X se unió» hasta que el pull se agote o venza la ventana de
  15 min. El grupo que crea el propio usuario no pasa por ahí, así que el creador no sufre la
  supresión.
- **Lo cierra** `:2261-2264` — dentro de `completeInitialMemberImport(context:)` (la función arranca
  en `:2257`): recoge los grupos backend con la marca puesta y la borra de golpe. El pull backend es
  global, así que agotarlo las cierra todas; es el gemelo del cierre por zona que hacía el canal
  CloudKit.
- **Lo lee** `zoneBaseline(_:context:cache:)`, que arranca en `:2200` y toma la marca **más reciente**
  de la zona (`:2221`), con sesgo a callar antes que a notificar de más.

**Decisiones técnicas:** store separado de `PendingInviteStore` (ciclos de vida incompatibles — aquel se limpia al presentar, este solo con member asegurado); supresión también de pending en initialImport; el tracker reemplaza el alert de error que quedaba TAPADO por el cover.

**Tests:** 78 nuevos/extendidos + XCUI `GroupInviteOnboardingUITests` (cifras del commit original; no se han re-corrido en esta revisión).

## Qué se arregló (resumen)

1. **Member del invitado jamás nacía** si la zona compartida no había bajado al momento del accept (ventana export-only ≥60s; `acceptShare` lo saltaba EN SILENCIO y nadie lo reintentaba). → El accept persiste un **join intent** (`PendingJoinStore`, TTL 7d) que `GroupJoinReconciler` consume hasta crear el `SplitMember` (pendingApproval).
2. **Notif espuria "X se unió"** en el primer import de una zona recién unida (members preexistentes clasificaban como nuevos). → Autoexclusión por identidad + baseline `SplitGroup.initialMemberImportStartedAt`, hoy abierto y cerrado por `GroupsSyncClient` (coordenadas arriba).
3. **Onboarding honesto**: el "¡Todo listo!" solo aparece con member confirmado (`GroupJoinIntentTracker.phase == .active`); estados nuevos joining / "está tardando" (salida a los 20s, `GroupInviteOnboardingLogic.softTimeout`) / error; banner de continuidad en el tab Grupos.

## Los triggers del reconciliador son TRES, no cuatro

`GroupJoinReconciler.Trigger` declara cuatro casos (`Yala/Services/Groups/GroupJoinReconciler.swift:28`:
`acceptShare`, `remoteInsert`, `boot`, `foreground`), pero **`remoteInsert` no lo invoca nadie.**
Medido con `grep` sobre todo el árbol: sus únicas apariciones son la propia declaración, la
traducción a `Source` en `:195`, el case espejo de
`Yala/App/Services/GroupBackendInviteEntryHandler.swift:28` y comentarios. Cero llamadas a
`reconcile(trigger: .remoteInsert)`. Era el trigger «post-fetch remoto», y se quedó sin llamador
cuando desapareció el canal que hacía ese fetch.

Los tres que sí tienen call-site de producción:

| Trigger | Quién lo llama | Cuándo |
|---|---|---|
| `acceptShare` | `Yala/App/Views/Groups/GroupInviteOnboardingView.swift:177` · `Yala/Services/Groups/GroupJoinIntentTracker.swift:124` | tap de "Unirme" en el onboarding · el reintento del tracker |
| `boot` | `Yala/App/AppBootstrapper.swift:497` | al arrancar la app, tras esperar a que el import personal esté quieto |
| `foreground` | `Yala/App/ContentView.swift:502` y `:1328` | al volver a primer plano · tras restaurar/onboarding |

## Guion device cross-device (2 devices / 2 usuarios, SOLO TestFlight)

Device A = owner (cuenta full), device B = invitado FRESH (install limpia, cuenta distinta).

### ~~Caso 1 — el timing exacto del bug (aceptar dentro de los primeros 60s)~~

**D — escrito contra el canal CloudKit, que ya no une a nadie.** No hay «ventana export-only»: el
enlace de una invitación viaja hoy por el canal backend. Un enlace de CKShare ni siquiera lo
intenta — informa y para (`Yala/App/AppBootstrapper.swift:1975-1990`). No lo corras; si quieres
cubrir lo mismo en el canal vivo, hay que reescribirlo, y eso todavía no está hecho.

- [ ] ~~A: crear grupo nuevo + generar enlace. Enviarlo a B.~~
- [ ] ~~B (install fresh): abrir el enlace e ir RÁPIDO — tap "Unirme" en cuanto aparezca el onboarding (dentro de la ventana export-only).~~
- [ ] ~~B: la UI muestra "Conectando con tu grupo…" (spinner) — NUNCA "¡Todo listo!" inmediato. Si tarda >20s, aparece "Está tardando un poco más de lo normal" con CTA "Seguir a la app".~~
- [ ] ~~B: al materializar la zona (~1-2 min máx), la pantalla avanza SOLA a "Esperando aprobación" (o el banner del tab Grupos pasa de "Conectando…" a "Esperando aprobación" si cerró el cover).~~
- [ ] ~~A: llega la notificación "X quiere unirse" y el badge de solicitudes en el detalle del grupo.~~ Ojo: el aviso **sí** llega, pero tarde — ver «Lo nuevo» abajo.
- [ ] ~~A: aprobar → B pasa a activo (cover abierto avanza solo; si cerrado, el grupo funciona al abrirlo).~~
- [ ] ~~B: NO recibió ninguna notif "Jür se unió al grupo" durante su primer import.~~

### Caso 2 — kill-app durante la unión (VIVO)

El único de los tres que sigue en pie: el reconciliador retoma el intent en `boot` y en
`foreground`, y esos dos triggers están vivos.

- [ ] B: abrir el enlace, tap "Unirme" y MATAR la app antes de que el grupo aparezca.
- [ ] B: relanzar → el join se completa solo; A recibe la solicitud sin que B toque nada.

### ~~Caso 3 — regresión del owner~~

**D en su lectura CloudKit** (baseline `didFetchRecordZoneChanges`, flood de notifs del private
engine): ese motor ya no interviene. **No se afirma** que el baseline del canal backend —el de
`GroupsSyncClient` descrito arriba— esté cerrado ni que haya que reescribirlo aquí; simplemente
este guion no lo prueba.

- [ ] ~~A: sus notifs "X quiere unirse" siguen llegando normal (el baseline NO aplica a grupos creados localmente).~~
- [ ] ~~A: reinstalar la app → durante el re-import inicial NO llega un flood de notifs "se unió" por los members históricos (baseline en el private engine).~~

### ~~Console.app (device B, categoría SplitSync)~~

**D — ninguno de los tres se puede emitir en un binario de producción de hoy.** Medido: el único
sitio que crea intents es `Yala/App/Services/GroupBackendInviteEntryHandler.swift:96`, y siempre
rellena `inviteToken` ⇒ toda entry es `isBackendJoin` ⇒ el reconciliador nunca recorre su rama
CloudKit, que es donde viven los dos primeros rastros. El tercero no existe en el árbol.
*(Inferido, no medido: un intent CKShare que un build antiguo hubiera dejado guardado sí entraría
por esa rama; el TTL de 7 días de `PendingJoinStore` lo cierra solo, así que a estas alturas no
queda ninguno.)*

- ~~`JoinReconcile[acceptShare]: zone ... not local yet — waiting`~~ — la línea existe
  (`GroupJoinReconciler.swift:89`) pero cuelga de la rama muerta.
- ~~`JoinReconcile[remoteInsert|boot|foreground]: member ensured for zone ... status=pendingApproval`~~
  — ídem (`GroupJoinReconciler.swift:231`), y además `remoteInsert` no tiene llamador.
- ~~Ausencia de `SplitSync markPendingChange DROPPED`~~ — `grep` de `markPendingChange`/`DROPPED`
  sobre todo el `.swift`: cero, salvo una mención en un comentario.

## Telemetría (Cloudflare Analytics Engine)

La telemetría de Yala va por `POST /metrics` del gateway a Workers Analytics Engine
(`Yala/Services/Metrics/MetricsService.swift:12`, `gateway/src/index.ts:45`). **TelemetryDeck se
eliminó entero el 2026-07-17**; no hay panel suyo que mirar.

Con emisor real, y por tanto útiles como criterio:

- `groupJoinIntentPersisted` — `Yala/App/AppBootstrapper.swift:2047`, `GroupBackendInviteEntryHandler.swift:80`.
- `groupJoinIntentReconciled` — `GroupBackendInviteEntryHandler.swift:283`, `GroupJoinReconciler.swift:150`, `GroupsSyncClient.swift:2118`.
- `groupJoinIntentDeferred` — `AppBootstrapper.swift:1987` (`ckShareChannelRemoved`) y `:2020` (`backendChannelOff`), `GroupBackendInviteEntryHandler.swift:308`, `GroupJoinReconciler.swift:55` (`importNotQuiescent`).
- `groupJoinFailed` — `GroupBackendInviteEntryHandler.swift:315`.
- **`groupJoinIntentExpired` debe ser 0** (>0 = un invitado quedó fuera pese a aceptar — CANARIO).
  Este sigue en pie: lo emite `Yala/Services/Groups/PendingJoinStore.swift:119` al caducar un intent.

Retirado como criterio de aceptación:

- ~~`cloudkitGroupEnqueueDroppedNoEngine` debe ser 0~~ — **quitado a propósito.** Ese canario está
  declarado (`Yala/Services/Metrics/MetricsService.swift:76`) y **no lo emite nadie**: es su único
  hit en todo el árbol. Siempre valdrá 0, así que era un verde imposible de romper — el peor tipo
  de criterio, porque parece que comprueba algo. El inventario de canarios sin emisor y qué hacer
  con ellos vive en `tickets/backlog/canarios-y-breadcrumbs-sin-emisor.md`.

## Lo nuevo, medido el 2026-09-02

### El dueño del grupo no se entera hasta que abre la app

Cuando alguien acepta la invitación, **al admin no le llega nada en el momento**: ni banner, ni
sonido, ni punto rojo. El aviso «X quiere unirse» aparece intacto, pero solo cuando el admin abre
Yala por su cuenta — pueden pasar minutos, horas o días. Mientras tanto el invitado se queda
esperando sin saber cuánto, viendo el grupo y la lista de gente pero cero contenido financiero.

Tiene ticket propio y ahí está la evidencia: **`tickets/backlog/aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app.md`**.
No se duplica aquí. Importa para este guion por una razón práctica: al correr el caso 2 en dos
teléfonos, **no interpretes «al admin no le sonó nada» como que el join falló** — abre la app del
admin antes de dar nada por roto.

### El botón «Reintentar» del error no lo ve nadie; lo que se ve es una X

Cuando la unión falla de verdad, el usuario se queda con un aviso **sin salida útil**: el chip de
error del tab Grupos dice «No pudimos conectar con el grupo. Pídele al admin un enlace nuevo» y su
único control es una **X** que lo cierra. La variante con botón **«Reintentar»** existe en el
código y **ningún camino de producción la puede pintar**.

Medido, en dos pasos:

- El chip con «Reintentar» (`Yala/App/Views/Groups/GroupsContainerView.swift:596`) exige
  `.acceptFailed(recoverable: true)` o `.memberSaveFailed`. El chip con la X (`:607`) cubre
  `.acceptFailed(recoverable: false)` y `.expired`.
- **Ninguna de las dos razones «con retry» ocurre en producción.** El único escritor de
  `noteAcceptFailed` pasa `recoverable: false`
  (`Yala/App/Services/GroupBackendInviteEntryHandler.swift:320`, en el brazo de fallo permanente);
  y `noteMemberSaveFailed` solo se escribe desde `Yala/Services/Groups/GroupJoinReconciler.swift:235`,
  dentro de la rama CloudKit, a la que se llega únicamente si `engineIsReady` es `true` — y ese
  valor es `engineReady?(group) ?? false` (`:75-77`) con `engineReady` inyectado **solo por los
  tests**, así que en producción es `false` siempre. El propio comentario del fichero (`:69-74`) lo
  dice: en producción esa rama sale por `.waitForEngines`.

Matiz que conviene no perder: en la **pantalla completa** de bienvenida el botón «Reintentar» sí se
dibuja para el caso alcanzable (`GroupInviteOnboardingView.swift:307-314`, que solo lo esconde
cuando la razón es `.expired`), pero **no reintenta nada**: `GroupJoinIntentTracker.retry()`
convierte `.acceptFailed` en `.expired` (`:125-126`), o sea que pulsarlo solo cambia el texto por
«Este enlace ya no es válido o expiró. Pídele al admin que regenere uno» y hace desaparecer el
botón. Y el cuerpo que se lee antes de pulsarlo es «Revisa tu conexión a internet e inténtalo de
nuevo», que para un fallo permanente de permisos manda al usuario a mirar donde no está el
problema.

**Inferido, no medido:** que esto haya que arreglarlo en este ticket. Es un defecto de UI
independiente del e2e; si se quiere cerrar por separado, merece ticket propio.

## Remediación del caso de Pia (sin release)

Que reabra un enlace de invitación **nuevo** —del canal backend, no el de CloudKit de entonces—:
el flujo actual crea su membresía en el servidor y al owner le llega la solicitud (con el retraso
de la sección anterior).

## Referencias

- Commit del fix: `dea3e61b` (2026-07-12), verificado presente en el repo.
- Coverage: `qa/coverage-index.json`, áreas `groups-pending-approval-reconnect`
  (`agentic`, `lastVerified` 2026-08-06), `groups-notifications-deeplinks` (`manual`, 2026-07-28) y
  `groups-cross-device-sync` (`manual`, 2026-08-11). **Re-medidas hoy**: el ticket decía
  «lastVerified 2026-07-11» para las tres y ninguna lo tiene ya.
- Ticket hermano del aviso tardío: `tickets/backlog/aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app.md`.
- Canarios declarados y sin emisor: `tickets/backlog/canarios-y-breadcrumbs-sin-emisor.md`.
- Gotcha en CLAUDE.md: acciones post-accept = intents persistentes reconciliables, nunca one-shot.
- App Attest y la asimetría observe/enforce: `.claude/rules/gateway-attest.md`.

## Historial de re-mediciones

### 2026-08-17 — contra `2.0.5` (HEAD `012cabe0`)

**No se ejecutó QA.** Premisa declarada FALSE/obsoleta: el escenario CKShare / export-only ≥60 s /
`acceptShare` que materializa la zona. `SplitSyncManager.swift` → 404.
`AppBootstrapper.handleInviteLink` case `.ckShare`: «este canal ya no existe» → `showInviteError` +
canario `ckShareChannelRemoved`. El **transporte** ya no une. Cayeron con él el caso 1, el caso 3 en
su lectura CloudKit, los rastros de Console y el canario `cloudkitGroupEnqueueDroppedNoEngine`.
Siguen vivos `PendingJoinStore`, `GroupJoinReconciler` y `GroupJoinIntentTracker`.

**REMAINS:** e2e backend cross-device — la solicitud llega al owner, onboarding honesto, sin notif
espuria «se unió». 2 devices + APNs.

No buscar ventana export-only. No cerrar el ticket. Joan revisa el nombre.

### 2026-09-02 — contra `2.1` (HEAD `553b91c9`)

**No se ejecutó QA ni se corrió build ni tests.** Todo lo de esta pasada es lectura del árbol.
Lo que cambió respecto al 17-ago: se escribió qué desbloquea el ticket (dos devices con TestFlight,
con la cadena de App Attest medida), se tacharon los casos y rastros que el addendum anterior ya
había declarado muertos pero seguían con casilla sin marcar, se corrigió «4 triggers» → 3 con el
call-site de cada uno, se re-ancló el baseline de notificaciones a `GroupsSyncClient`, se cambió
TelemetryDeck por Analytics Engine, se retiró el criterio del canario sin emisor y se añadieron los
dos hallazgos nuevos (aviso tardío al admin, y el «Reintentar» inalcanzable).

migrated from YalaWiki Bugs/qa_groups-join-intent-reconciler.md @ 1934e8ad
