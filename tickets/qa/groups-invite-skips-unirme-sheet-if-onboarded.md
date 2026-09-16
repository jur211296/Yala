---
id: groups-invite-skips-unirme-sheet-if-onboarded
status: qa
priority: high
area: groups
created: 2026-08-28
updated: 2026-09-16
---

# Al invitado que ya tiene cuenta no le aparece la hoja de «Unirme»: entra al grupo solo

## Reporte del owner (device, 2026-08-28, Lima, TF 2.1 build 12)

Dos teléfonos. **B = cuenta de prueba ya creada** (no install limpia: su onboarding estaba hecho, o sea
`hasCompletedOnboarding` en `true`). B abre el enlace de invitación y **la hoja de «Unirme» /
`GroupInviteOnboardingView` no aparece**: el alta en el grupo se hace sola, sin que B confirme nada.

Veredicto del owner, literal en lo que pide: **la hoja debe aparecer siempre** — venga de primer plano,
de segundo plano o estando ya dentro de la app.

## El síntoma, en lenguaje de usuario

Me pasan un enlace de un grupo. Lo toco. Yala no me pregunta nada: no me enseña de qué grupo se trata,
no me deja elegir con qué nombre me van a ver los demás, no me pide confirmar. En algún momento
descubro que ya estoy dentro (o esperando aprobación). El paso donde yo decía «sí, únanme» no existió.

## Lo medido en este árbol (`2.1` @ `2175e53e`)

Todas las coordenadas de abajo se midieron en ESTE commit. Si al retomarlo el árbol es otro, re-medir
antes de obedecerlas: cuesta un grep y en este repo la documentación envejece más rápido que el código.

### 1 · La tabla que decide, y el corte exacto

El terminal del invitado sale de **una sola tabla pura**,
`GroupsGateLogic.nextStep(entry: .invite, …)` — `Yala/App/Logic/GroupsGateLogic.swift:120-121`:

```swift
// GroupsGateLogic.swift:120-121
        case .invite:
            return (!hasCompletedSetup && canPresentInviteOnboarding) ? .presentInviteOnboarding : .join
```

`hasCompletedSetup` **es** `hasCompletedOnboarding`: `GroupBackendInviteEntryLogic.nextStep`
(`Yala/App/Logic/GroupBackendInviteEntryLogic.swift:40-64`) lo pasa tal cual en su línea `:53`, y su
propio parámetro trae **default `true`** (`:43`). El handler lo lee de `UserDefaults` en
`GroupBackendInviteEntryHandler.hasCompletedOnboardingProvider` (`:43-45`, clave
`AppPreferences.Keys.hasCompletedOnboarding`) y lo inyecta en `drive` (`:213`).

⇒ con el onboarding hecho, el camino del invite **puede devolver `.join` y saltarse
`.presentInviteOnboarding`**. Ese paso, según su propio docblock (`GroupBackendInviteEntryLogic:16-19`
y `:23-25`), existe para un usuario **FRESCO**: capturar su nombre ANTES del join (regla R1).

### 2 · Cuidado: hay DOS puertas con el mismo corte, no una

Aunque se arregle la tabla, el drenaje del router repite la decisión por su cuenta —
`Yala/App/ContentView.swift:956-967`:

```swift
// ContentView.swift:960-967
            if !hasCompletedOnboarding {
                pendingInviteMetadata = nil  // backend: sin CKShare metadata — visual genérico
                showGroupInviteOnboarding = true
            } else {
                Task { @MainActor in
                    await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
                }
            }
```

Con la tabla corregida y esto sin tocar, el intent llegaría al drain y el `else` lo mandaría a
`continueFlow` → `drive` → join. **Las dos puertas tienen que cambiar juntas.** La regla del repo pide
barrer todas las instancias del patrón antes de declarar un fix completo: hoy las que deciden por
`hasCompletedOnboarding` en este recorrido son `GroupsGateLogic:121` y `ContentView:960`.

### 3 · El origen del tap NO participa en la decisión — y eso es bueno para lo que el owner pide

`drive` solo distingue **un** origen: `canPresentOnboarding: source != .userAction`
(`GroupBackendInviteEntryHandler.swift:214`). Los demás (`.universalLink` = tap con la app viva,
`.boot`, `.foreground`, `.remoteInsert`, `.continuation`) deciden **idéntico**.

- Cold start: `AppBootstrapper.enterBackendInvite:2051-2062` persiste el intent y retorna; lo completa
  el reconciler en boot/foreground (`GroupJoinReconciler:153-157` → `drive` con `mapTrigger:188-197`).
- `GroupJoinReconcileLogic.decideBackend:66-77` **no tiene caso de invite-onboarding**: delega en
  `drive`. O sea que el único sitio donde se decide «hoja sí / hoja no» es la tabla del punto 1.

⇒ el «siempre, venga de donde venga» del owner **no necesita ramas por origen**; necesita cambiar el
predicado en un sitio (dos con el drain). Y `.userAction` debe seguir sin presentar: son el CTA de la
propia hoja (`GroupInviteOnboardingView.handleJoinTap:170-180` → `reconcile(trigger: .acceptShare)` →
`.userAction`) y el retry del banner (`GroupJoinIntentTracker:124`). Sin ese discriminador, el tap de
«Unirme al grupo» re-presentaría la vista que lo emitió.

### 4 · Lo que el invitado ve hoy en vez de la hoja: nada en primer plano

`attemptJoin` → `handleJoinSuccess` (`GroupBackendInviteEntryHandler.swift:277-287`) **no submitea
ningún intent de router**: ni hoja, ni alerta, ni navegación. La única superficie que informa del alta
es el chip del tab Grupos (`GroupsContainerView.joinIntentBanner:564-622`), que exige que el usuario
**esté en ese tab**. Nada lo lleva ahí.

Dos consecuencias medidas, ambas del mismo salto:

- **El nombre lo elige el código, no la persona.** Sin hoja no hay nombre capturado, así que
  `resolveJoinDisplayName` (llamado en `GroupBackendInviteEntryHandler:255-259`) cae al nombre del
  perfil personal (`profileNameProvider:46-48`, `SessionDefaults` `userName`) y, si estuviera vacío, a
  `L10n.Profile.defaultName`. El invitado no tiene ocasión de decidir con qué nombre lo ven en el grupo.
- **Se salta la máquina de estados entera del alta.** La hoja no es solo captura de nombre: es
  `welcome / joining / takingLong / pendingApproval / active / failed` alimentada por
  `GroupJoinIntentTracker.phase` (`GroupInviteOnboardingView.swift:41-62`), con «Conectando…», «Esperando
  aprobación», «¡Todo listo!» y el reintento. Quien no la ve pierde también el progreso y el error.

La cadena que el owner citó como «Unirme» es `groups.invite.joinButton`, consumida en
`GroupInviteOnboardingView.swift:127-130` (a11y id `invite_join_button`). Su valor es **«Unirme al
grupo»** en `Yala/Resources/es-ES.lproj/Localizable.strings:371`, `es.lproj:3474` y `es-419.lproj:3474`,
y «Join group» en `en.lproj:3521`. **No se cambia ninguna cadena en este ticket.**

### 5 · El espejo del canal CKShare tiene el mismo corte, y está declarado huérfano

`AppBootstrapper.inviteRouteDecision:2097-2123` corta igual — `:2107`
`if !hasCompletedOnboarding && onboardingMode != .groupInvite` → `.acceptAndShowInviteOnboarding`, y si
no, `.showReconnect(mode: .standardReconnect)` (`:2122`). Su docblock (`:2074-2078`) dice que es
**huérfana en producción desde la Fase 3** (su consumidor `CKShareEntryHandler` murió con el
transporte) y que se conserva porque `ReconnectMode` sigue describiendo la UI de reconexión.

Se anota por dos razones opuestas y las dos útiles: para que un barrido del patrón **no la confunda con
un camino vivo** (tocarla no cambia nada que el usuario vea), y para que nadie la tome como prueba de
que el corte «ya está arreglado en otro sitio». Sus tests siguen verdes y siguen pinneando el corte
viejo (`YalaTests/AppBootstrapperTests.swift:78-85`).

## Esto no es una desviación del código respecto a su diseño: es un cambio de contrato

Importa para estimar y para no escribir un fix a ciegas. Lo que hay hoy **hace exactamente lo que su
documentación dice que hace**: la hoja es el educativo/captura del invitado FRESCO, y quien ya tiene
alta no la necesitaba porque su nombre ya existe. Está escrito en tres sitios independientes
(`GroupsGateLogic:80-81` y su tabla de cabecera `:22-33`, `GroupBackendInviteEntryLogic:16-19`,
`GroupsGateLogic:100-101`) y **pinneado por dos tests que hoy pasan**:

- `YalaTests/GroupBackendInviteEntryLogicTests.swift:59-63` — `nextStep_onboardingComplete_joinsDirect`.
- `YalaTests/GroupsGateLogicTests.swift:112`, dentro de `inviteTerminals:109-116` —
  `step(.invite, setup: true) == .join`.

⇒ el fix **tiene que actualizar esos dos a propósito**, y eso es correcto aquí (el contrato cambia por
decisión de producto), no un atajo. Lo que no vale es cambiar el código y dejar los tests «arreglados»
sin entender que documentaban una decisión.

**Medido también qué tests NO hay que tocar** (para que nadie los «arregle» de paso):

- `GroupsGateLogicTests.inviteEntryMirrorsTheTable:192-216` deriva su expectativa **de la propia tabla**,
  así que se re-alinea solo. Es la red que impide que `GroupBackendInviteEntryLogic` vuelva a decidir por
  su cuenta: hardcodearla mataría justo lo que protege.
- `GroupsGateLogicTests.fullDomain_isExhaustive_andNameRequiresIdentity:129-155` solo cuenta las celdas
  que llegan a `.presentName` (`nombres == 2`, que salen de `.organizer`/`.onboardingCard`). El terminal
  de `.invite` no entra en esa cuenta.

## El riesgo del fix ingenuo: presentar la MISMA hoja a quien ya tiene cuenta

Esto es lo que hay que leer antes de tocar nada. El CTA de la hoja ejecuta
`GroupInviteOnboardingView.performSilentSetup` (`:357-432`), que es un **alta de primer arranque**:

| Línea | Qué escribe |
|---|---|
| `:363` | `sessionState.onboardingMode = .groupInvite` |
| `:371` | `hasShownGroupsOnboarding = true` |
| `:374` | `userName` (vía `PreferenceSyncService`) |
| `:379` | `PendingJoinStore.updateDisplayName` |
| `:384-385` | `defaultCurrencyCode` y `defaultPeriod` |
| `:392-412` | seeds de categorías/notificaciones + `context.save()` |
| `:415` | `signalOnboardingCompleted` (avisa a los otros devices) |
| `:431` | `MetricsService.localRegistrationCompleted(mode: "groupInvite")` |

Sobre una cuenta que ya existe eso **pisa preferencias vivas**. Lo más caro, medido:

- **`onboardingMode = .groupInvite` viaja al iKV del Apple ID y su merge es never-downgrade por rank**
  (`OnboardingMode.rank:23-29` → `full` 0, `groupInvite` 1, `completed` 2;
  `SessionState.swift:393-397` embudo → `OnboardingMode.setCurrent`;
  `PreferenceMergeLogic.swift:239-243`). Para un usuario en `.full` (rank 0 — el estado normal tras el
  onboarding de 8 pasos) escribir `.groupInvite` es una **escalada de rank que el merge remoto no
  deshace**. El header de `GroupsGateLogic:14-20` ya lo nombra como el daño que esa tabla existe para
  impedir: los otros dispositivos de esa cuenta ven una app recortada a Grupos y **no vuelve**; su
  única recuperación es restaurar por iCloud.

  > **⛔️ REFUTADO el 2026-09-05, y el ticket cita el embudo correcto para concluir mal.**
  > `SessionState.swift:393-397` sí embuda en `OnboardingMode.setCurrent` — y esa función escribe
  > `UserDefaults.standard` **a secas**, sin iKV; su propio docblock dice que «los tres escritores que van
  > por `PreferenceSyncService` **no pasan por aquí**». Los dos que empujan esa key al canal sincronizado
  > son `GroupsOrganizerOnboarding` (`writer.setSynced`) y `FullModeActivationView`. ⇒ por el camino de la
  > hoja, `onboardingMode` es **local a ese device y recuperable** con `FullModeActivationView`.
  >
  > **El daño de correr el alta sobre una cuenta existente sigue en pie, y en un aspecto es peor de lo que
  > este párrafo decía**: `userName`, `defaultCurrencyCode` y `defaultPeriod` sí van por
  > `PreferenceSyncService.set(string:)` ⇒ **sí viajan al iKV**, así que unirse a un grupo te renombraría
  > el perfil y te cambiaría la moneda en TODOS tus dispositivos. La conclusión del ticket —no correr el
  > alta— era correcta; su titular, no.
- **La moneda preferida y el período** se recalculan desde el grupo o la región
  (`detectCurrencyFromGroup:434-438` → `CurrencyDefaults.detectCurrencyFromRegion`) y sobrescriben las
  que el usuario ya tenía.
- **El KPI de registros** contaría un alta nueva por alguien que ya estaba registrado.

⇒ «que la hoja aparezca siempre» **no es** «quitar el `!` del predicado». Es separar lo que la hoja
*muestra* (contexto del grupo + confirmación + progreso) de lo que su CTA *escribe* (el alta), y que
para un usuario ya dado de alta el CTA **solo** haga el join (+ el nombre para ESE grupo, si se decide
ofrecerlo). El campo de nombre de la hoja (`GroupInviteOnboardingView:111`) tampoco viene prellenado con
el del perfil (`@State private var userName: String = ""`, `:21`): tal cual, a un usuario con cuenta le
pediría el nombre en blanco.

## Preguntas de producto abiertas (decidir con el owner ANTES de escribir código)

No se inventan en el AC. Son las que el reporte no responde y que cambian el diseño:

1. **Qué muestra la hoja a quien ya tiene nombre.** ¿Campo prellenado y editable (nombre por grupo)?
   ¿Sin campo, solo «te invitaron a X · Unirme»? Hoy el copy y el visual son los del alta
   (`welcomeTitle:454-459`, subtítulo, placeholder de nombre).
2. **Si el nombre editado ahí debe cambiar el del perfil personal.** Hoy `performSilentSetup:374`
   escribe `userName` global. La corrección R1 ya sabe corregir solo el nombre del member
   (`GroupBackendInviteEntryLogic.shouldCorrectMemberDisplayName:101-111` +
   `correctDisplayNameIfNeeded:334-351`), así que existe el camino para NO tocar el perfil.
3. **Qué pasa si el invitado cierra la hoja sin unirse.** Hoy el único outcome del cover
   (`ContentView.swift:2056-2069`) marca `hasCompletedOnboarding = true` y no cancela el intent — para
   un fresco tiene sentido; para un usuario con cuenta hay que decidir si «X» = «no me uno» (y entonces
   limpiar el intent) o «luego» (y entonces el banner del tab es la salida).
4. **Si además debe navegar al tab Grupos** al terminar. Hoy nada lo lleva (punto 4 de lo medido).

## Distinto de (ya existen; no duplicar)

- `tickets/qa/groups-join-intent-reconciler.md` — el **contrario**: el member NO nacía, «¡Todo listo!»
  falso y la solicitud no llegaba al owner; su fix es el intent persistente + reconciler y su REMAINS
  es el e2e cross-device. Aquí el alta **sí** se materializa; lo que falta es la hoja que la confirme.
- `tickets/in-progress/invite-link-five-causes-one-message.md` — copy de enlace **inválido/expirado**
  (cinco causas, un mensaje) y la marca del grupo que no viaja. Ahí el enlace no funciona; aquí
  funciona demasiado bien y en silencio. Nota de solape útil, no de duplicado: su pieza 2 (cablear
  `branded`) es justo lo que le daría a esta hoja el nombre del grupo, que es la mitad del valor de
  presentarla.
- `groups-pending-member-can-open-group` — el pendiente de aprobación puede abrir el grupo. **Medido:
  ese ticket NO está en este árbol** (vive en la [PR 46](https://github.com/jur211296/Yala/pull/46),
  sin mergear a `2.1`), así que la ruta `tickets/backlog/…` aún no existe aquí; se nombra por su slug
  para que nadie lo re-abra. Es lo que pasa **después** del join; esto es lo que falta **antes**.
- `tickets/in-progress/guest-decline-has-no-screen.md` — la sala de espera del invitado: el rechazo no
  tiene superficie y el «¡Todo listo!» casi no se ve. Vecino, no el mismo defecto, y la frontera es
  nítida: ese ticket arranca **después** de unirse («toco el enlace, entro y veo *Solicitud
  enviada*» — o sea, describe el recorrido del invitado FRESCO, que sí ve la hoja); este es que el
  usuario con cuenta no llega nunca a ese punto de partida.
- `tickets/in-progress/guest-journey-dead-screens.md` — código muerto y docblocks caducados del
  recorrido del invitado. Solapa en ficheros, no en defecto.
- `tickets/qa/groups-consent-door-spec.md` — la spec que creó `GroupsGateLogic` y la tabla única. Es la
  **fuente** del contrato que este ticket propone cambiar, no un duplicado; conviene leerla antes de
  tocar la tabla para no reintroducir lo que C2 unificó (cuatro puertas, una tabla).

## Notas para quien implemente

- La tabla es la SSOT de las **cuatro** puertas (`.organizer`, `.onboardingCard`, `.invite`, `.tab`).
  Cambiar el terminal de `.invite` no debe alterar los otros tres: el test espejo de
  `GroupsGateLogicTests` existe justo para eso.
- **XCUITest: el seam actual no alcanza este caso.** `-uitest-invite-onboarding`
  (`Yala/App/UITestHooks.swift:180-183`) entra por `presentNextOnboardingScreen`
  (`ContentView.swift:1355-1360`), y `checkInitialSyncState:1287-1292` **retorna antes** cuando
  `hasCompletedOnboarding` es `true`. Para cubrir «usuario con cuenta ve la hoja» hay que extender el
  seam (o añadir uno) además de escribir el test.
- **Regla anti-drift del repo:** este ticket no toca código, así que hoy no hay nada que actualizar en
  `qa/coverage-index.json`. Cuando se implemente, las áreas cuyos `codeGlobs` cubren los ficheros
  candidatos son, medido en el índice actual: `groups-onboarding-tutorial-visual` (deterministic —
  incluye `Yala/App/Logic/GroupsGateLogic.swift`), `groups-backend-g4-invites` (manual — incluye
  `GroupBackendInviteEntryLogic.swift`, `GroupBackendInviteEntryHandler.swift`, `AppBootstrapper.swift`),
  `groups-pending-approval-reconnect` (agentic — incluye `GroupInviteOnboardingView.swift`) y
  `onboarding-flow` (deterministic — incluye `Yala/App/ContentView.swift`).
- El canal es DARK tras `CloudSyncFlags.groupsBackendEnabled`; el enrutado por forma del link vive en
  `GroupInviteChannelRoutingLogic.route` y el link CKShare hoy solo informa
  (`AppBootstrapper:1975-1990`). Nada de esto cambia aquí.

## Lo que NO se afirma

- **No hay captura de Console ni telemetría de la corrida**, así que el punto 1 es la rama que produce
  **exactamente** este resultado, no una prueba de que fuera la rama tomada ese día. Lo que la respalda:
  la otra única puerta a un `.join` silencioso es `canPresentOnboarding == false`, y eso solo lo produce
  `source == .userAction`, que en este árbol sale de dos superficies **iniciadas por el usuario** — el
  CTA de la propia hoja (`GroupInviteOnboardingView:177`) y el retry del banner
  (`GroupJoinIntentTracker:124`) — más el re-join del detalle de un grupo migrado
  (`GroupDetailView:501`). Ninguna es un primer tap de enlace. Al reproducir, mirar
  `BackendInvite[…]: fresh user → present invite onboarding` (`GroupBackendInviteEntryHandler:224`): su
  **ausencia** con el resto del flujo funcionando es la firma de este salto.
- **No se afirma** en qué estado quedó B (activo o pendiente de aprobación), ni por qué superficie se
  enteró del alta, ni qué idioma/locale corría: el reporte no lo dice.
- **No se afirma** que el fix sea solo iOS. Si se decide que la hoja tiene que enseñar el nombre del
  grupo, eso depende de la pieza 2 de `invite-link-five-causes-one-message` (la marca no tiene por
  dónde viajar hoy).

## HOLD (levantado el 2026-09-05)

El HOLD decía «cero Swift» porque las cuatro preguntas de producto de arriba estaban sin responder. El
owner las cerró con su encargo del 5-sep («la hoja debe aparecer siempre», alcance mínimo, autónomo hasta
el final), así que se implementó. Sigue en pie lo demás: sin App Store, sin tag de release, sin
TestFlight. A7/M5 sigue en HOLD.

## Acceptance Criteria

- [x] Con `hasCompletedOnboarding == true`, abrir un enlace de invitación **presenta** la hoja del
      invitado antes de cualquier `join_group`, y el join solo ocurre tras el CTA.
      → `GroupInviteSheetAlwaysShownTests.unconfirmedInvite_presentsSheetAndDoesNotJoinYet` (dos
      aserciones: presenta **y** `joinProvider` no se llamó — la segunda impide un fix que enseñe la hoja
      DESPUÉS de haber metido a la persona en el grupo). El término del alta ya no participa:
      `GroupsGateLogicTests.inviteTerminalIgnoresPriorSetup` lo barre en sus dos valores.
- [x] Ese comportamiento es idéntico por los cuatro orígenes. → `everyNonUserOrigin_presentsTheSheet`.
      **Corrección al AC**: el cuarto origen no es `.remoteInsert` —`GroupBackendInviteEntryHandler.Source`
      no tiene ese caso; es un trigger del reconciler CloudKit, no de este camino— sino `.continuation`, la
      vuelta desde los sheets de sign-in/consent. Se cubren los cuatro que existen. `.userAction` sigue sin
      re-presentarla: `userActionFromTheSheet_joinsWithoutRePresenting`.
- [x] Presentar la hoja a un usuario con cuenta **no** escribe `onboardingMode = .groupInvite`, ni cambia
      `defaultCurrencyCode` / `defaultPeriod` / `userName` del perfil, ni vuelve a contar el KPI de
      registro. → `joinOnlySetup_writesNothingOfTheRegistration` (source-scan con las nueve escrituras
      prohibidas nombradas) + `theCTAForksOnWhetherThePersonAlreadyHasAnAccount`, que es su gemelo: sin él,
      el primero pasa en verde con la rama muerta. Se añadió `updateCurrentUserDisplayName` a la lista, que
      el AC no nombraba y es DEVICE-WIDE — renombraría a la persona en todos sus grupos.
- [x] El invitado fresco conserva su recorrido actual: hoja primero, nombre capturado antes del join.
      → la rama `performSilentSetup` no se toca y el source-scan exige que siga cableada; el prellenado
      solo actúa sobre un campo vacío y su perfil lo está.
- [x] Los dos tests que pinneaban `.join` para un usuario con onboarding quedan actualizados
      **explícitamente**, no borrados; el espejo sigue en pie sin hardcodear (se re-alineó solo al iterar
      sobre el eje nuevo). Hubo un **tercero** que el ticket no había visto:
      `GroupJoinReconcilerTests.rejectedMember_withTap_requestsJoinExactlyOnce`, partido en dos.

**Verificado por MUTACIÓN, que es lo que decide si los cinco de arriba valen**: devuelto el corte por el
alta a la tabla y al drain, caen la reproducción, los cuatro orígenes, el drain, el terminal y el
reconciler. Sin ese paso, un test verde solo dice que el flujo corre.

**Verificación pendiente (no se inventa PASS)**: lo que los tests NO pueden ver es el device. Falta el
montaje de dos teléfonos —ver la sección de device-QA al final— y, en particular, el criterio de
no-regresión de preferencias observado en un teléfono real, no en un source-scan.

---

# IMPLEMENTADO · 2026-09-05 (PR a `2.1`)

## Lo que cambia para quien usa la app

Antes: te pasaban el enlace de un grupo, lo tocabas y Yala no te preguntaba nada. En algún momento
descubrías que ya estabas dentro. Ahora, toques el enlace con la app abierta, cerrada o de fondo, **siempre
te aparece la pantalla de bienvenida del grupo**: ves a qué grupo te invitaron, con qué nombre vas a entrar
—ya viene puesto el tuyo, y puedes cambiarlo— y no te unes hasta que tocas «Unirme al grupo». Desde ahí ves
el progreso: «Conectando…», «Esperando aprobación» o «¡Todo listo!».

Y lo que **no** cambia, que es la mitad importante: si ya tenías Yala configurado, unirte a un grupo no te
toca nada tuyo. Ni tu nombre de perfil, ni tu moneda, ni tu periodo, ni tu forma de ver la app en tus otros
dispositivos. El nombre que escribes ahí es para ESE grupo.

## Tres cosas que el diagnóstico de arriba daba por medidas y NO se cumplían en este árbol

Re-medidas antes de tocar nada, según la regla del repo:

1. **El punto 5 (el espejo huérfano de `AppBootstrapper`) está CADUCADO: ese código ya no existe.**
   `inviteRouteDecision`, `.acceptAndShowInviteOnboarding` y sus tests dan **cero** ocurrencias en todo el
   repo (`grep -rn --include="*.swift"`). Se retiraron después de escribirse el ticket. ⇒ el barrido del
   patrón cierra en **dos** puertas vivas, no tres.
2. **Las coordenadas se desplazaron**, como el propio ticket avisaba: `ContentView:956-967` → `:928-945`,
   el outcome del cover `:2056-2069` → `:2018`, `checkInitialSyncState:1287` → `:1269`. La única que aguantó
   exacta es `GroupsGateLogic:121`.
3. **Faltaba una tercera pieza que el ticket no nombra**, y es la que decide si el arreglo es correcto o un
   bucle: `GroupJoinReconciler` vuelve a `drive` en CADA boot y foreground mientras el intent viva (7 días).
   Quitar el `!` del predicado —el «fix ingenuo» que el ticket ya desaconsejaba por las preferencias—
   habría re-presentado la hoja en cada arranque incluso después de unirse. Eso obliga a que la señal no
   sea un booleano de la app, sino un hecho **de esa invitación**.

## Qué se hizo

**La señal cambia, el predicado no se invierte.** `hasCompletedOnboarding` era un PROXY: valía para el
invitado fresco solo porque la hoja marcaba su alta al terminar, así que «ya está dado de alta» acababa
significando «ya pasó por aquí». La pregunta real siempre fue la segunda. Ahora se pregunta directamente:

| Pieza | Qué |
|---|---|
| `PendingJoinEntry.inviteConfirmedAt` (`PendingJoinStore.swift`) | Campo nuevo, opcional ⇒ back-compat: un intent persistido por la versión anterior decodifica sin confirmar, o sea que ve la hoja. Muere con el intent, así que un enlace nuevo vuelve a pedir confirmación. |
| `GroupsGateLogic.nextStep` | El terminal de `.invite` decide por `hasConfirmedInvite`. Las otras tres puertas, intactas. |
| `GroupBackendInviteEntryLogic.nextStep` | `hasCompletedOnboarding` **sale de la firma** (no se deja mudo: un parámetro que ya no decide es una trampa). |
| `GroupBackendInviteEntryHandler.drive` | SELLA la confirmación cuando `source == .userAction` —el único origen que solo puede producir una persona— y lee el hecho vivo del intent en cada vuelta. `hasCompletedOnboardingProvider` retirado. |
| `GroupBackendInviteEntryHandler.persistIntent` | Un re-tap **no hereda** la confirmación anterior. Única excepción al patrón de preservación de esa función, y explícita. |
| `ContentView` (drain del router) | La segunda puerta pregunta LO MISMO y lo lee del mismo sitio. |
| `GroupInviteOnboardingView` | El campo de nombre se siembra con el del perfil; el CTA **bifurca**: alta completa solo para el fresco, `performJoinOnlySetup` para quien ya tiene cuenta. |

**El riesgo caro que el ticket señalaba está cerrado por construcción**: `performJoinOnlySetup` no escribe
`onboardingMode`, ni el `userName` del perfil, ni moneda/periodo, ni seeds, ni `signalOnboardingCompleted`,
ni `updateCurrentUserDisplayName` (que es DEVICE-WIDE y renombraría a la persona en TODOS sus grupos), ni
el KPI de registro. Sí escribe `hasShownGroupsOnboarding` (esta vista ES su educativo) y el nombre en el
join intent. Lo fija un source-scan con las nueve escrituras prohibidas nombradas una a una.

## Las cuatro preguntas de producto, respondidas

Se resolvieron por alcance mínimo, sin ampliar el diseño. Quedan escritas para que se vea que fueron
decisiones y no omisiones:

1. **Qué muestra la hoja a quien ya tiene nombre.** La misma hoja, con el campo **prellenado** con el
   nombre del perfil y editable. Sin prellenado se le pedía el nombre en blanco a quien ya tiene uno. **Cero
   cambios de copy**: «Te invitaron al grupo X», «Tu nombre», «Unirme al grupo» son ciertos para los dos
   casos, así que no se toca ninguna de las 16 traducciones.
2. **Si el nombre editado cambia el perfil personal.** No. Viaja en el intent → `resolveJoinDisplayName` lo
   prefiere en el `join_group`, y si el member ya existía lo corrige `correctDisplayNameIfNeeded` (R1). Es
   el camino que el propio ticket señalaba.
3. **Qué pasa si cierra la hoja sin unirse.** Primera respuesta: «no hace falta decidirlo, medido el paso
   `welcome` no tiene salida». **La medición era correcta y la conclusión, falsa** — la cazó la review
   adversarial y es el hallazgo 2 de abajo. Que no hubiera salida era inocuo mientras la hoja solo la viera
   quien llegaba sin app; al presentársela a todo el mundo, esa ausencia se convierte en una jaula que el
   reconciler remonta en cada arranque durante 7 días. **Decisión: hay salida** («Más tarde»), solo para
   quien tiene app detrás, y retira esa invitación. Lección de método: una medición sobre el código de ayer
   no responde una pregunta sobre el comportamiento de mañana.
4. **Si debe navegar al tab Grupos.** Fuera de alcance: ya lo hace `complete(_:)` al cerrar la hoja, y
   cambiar cuándo navega no es este defecto.

## Cómo se verificó

- **Reproducción y fijación**: `YalaTests/GroupInviteSheetAlwaysShownTests` (11 casos en tres mitades: la
  decisión, el sello de la señal y tres source-scan del cableado).
- **MUTACIÓN** (la parte que decide si los tests valen): devuelto el corte por `hasCompletedSetup` a la
  tabla y `!hasCompletedOnboarding` al drain, caen **la reproducción, los cuatro orígenes, el drain, el
  terminal de la tabla y el test del reconciler**. Restaurado con `cp` (nunca `git checkout --` en árbol
  sucio).
- 127 tests en 14 suites de las áreas tocadas, verdes.
- `qa/coverage-index.json`: cuatro áreas actualizadas (`groups-backend-g4-invites`,
  `groups-pending-approval-reconnect`, `groups-onboarding-tutorial-visual`, `onboarding-groups-only`).

## Tres tests que documentaban el contrato viejo, actualizados A PROPÓSITO

No se «arreglaron»: cambió una decisión de producto y ellos la fijaban.

- `GroupsGateLogicTests.inviteTerminals` — decía `step(.invite, setup: true) == .join`, que **es** el defecto.
- `GroupBackendInviteEntryLogicTests.nextStep_onboardingComplete_joinsDirect` → `…_confirmedInvite_joinsDirect`.
- `GroupJoinReconcilerTests.rejectedMember_withTap_requestsJoinExactlyOnce` — **partido en dos**, y merece
  leerse: afirmaba que tapear el enlace bastaba para que saliera el `join_group`. El destinatario de ese RPC
  es el admin del grupo, así que bajo el contrato nuevo mandarle una solicitud sin que el invitado haya
  visto de qué grupo se trata era media parte del defecto. Hoy el tap lleva a la hoja (`join == 0`) y el
  join sale al confirmar (`join == 1`).

Los que el ticket pedía NO tocar siguen intactos: `inviteEntryMirrorsTheTable` deriva su expectativa de la
tabla (se re-alineó solo al iterar sobre el eje nuevo) y `fullDomain_isExhaustive` sigue contando 2.

## Efecto lateral DECLARADO (no es alcance nuevo, es consecuencia del contrato)

A quien fue **rechazado** de un grupo y toca un enlace nuevo, ahora le aparece la hoja en vez de salir una
solicitud en silencio. Es coherente con lo que pidió el owner —nada ocurre sin confirmación— y le da por
primera vez una superficie donde ver qué pasa. No cierra `rejected-member-cold-tap-does-nothing`, que es
otro caso (tapear con la app cerrada, sin tap armado en ese arranque).

## La review adversarial, y por qué este ticket no estaría bien sin ella

Dos lentes independientes sobre el diff (máquina de estados · regresiones y preferencias). **Coincidieron, sin
verse, en los dos hallazgos gordos**, y una refutó una afirmación mía. Ninguno de los cinco se ve en un
grep, y tres eran defectos que introducía este mismo cambio:

### 1 · Confirmar UNA invitación sellaba TODAS las demás — el defecto del ticket, colado por la puerta de atrás

El CTA de la hoja llama a `GroupJoinReconciler.reconcile(trigger: .acceptShare)` **sin decir de qué grupo
habla**, y `reconcile` itera TODAS las entries vigentes (cap 8, TTL 7 días) mapeando `.acceptShare` a
`.userAction` para cada una. Con dos invitaciones vivas, tapear «Unirme» en la hoja de A sellaba B como
confirmada ⇒ **la hoja de B no se presentaría jamás**. Justo lo que el sello existe para impedir, y
contradiciendo por escrito el docblock de `markInviteConfirmed`.

Se arregla en el origen: `reconcile` gana `userConfirmedZone` y `mapTrigger` solo devuelve `.userAction`
para esa zona; las demás se procesan como `.foreground`, que es lo que son. Eso obligó a **cablear la zona
hasta la vista** (drain → modifier → `GroupInviteOnboardingView.pendingJoinZone`), que además es lo que
hacía falta para lo siguiente.

**Por qué el test que ya tenía no lo cazó, que es la lección:** `confirmationIsPerZone_andIdempotent`
llamaba a `markInviteConfirmed` **directamente**. Probaba el store, no el camino. Un test que monta el
estado a mano no puede ver un caller que lo monta mal.

### 2 · La hoja no tiene salida, y al ampliar su audiencia eso pasó de inocuo a jaula

`welcomeStep` tenía **un solo control**: «Unirme al grupo». Es un `fullScreenCover` (sin swipe), el único
sitio que lo cierra está dentro del `onComplete`, y ese solo se alcanza DESPUÉS de tapear el CTA. Y matar
la app no vale: el reconciler lo vuelve a montar en cada arranque y cada foreground mientras el intent viva
(**7 días**).

Para el invitado fresco eso era coherente —detrás no hay app a la que volver—. Para quien ya usa Yala, un
enlace tapeado por error le tapa su propia app hasta que se rinda y entre al grupo. **Una hoja de la que
solo se sale confirmando no captura un consentimiento: lo extrae**, que es lo contrario de lo que el owner
pidió.

Arreglo: botón **«Más tarde»** (`action.later`, ya en los 16 idiomas — cero copy nuevo) **solo visible para
quien tiene app detrás** (`canDecline == hasCompletedOnboarding`; al fresco se le dejaría en una app sin
alta, que es un brick, no una salida). Retira ESA invitación (`PendingJoinStore.clear`) y **no navega al tab
Grupos** — no se unió a nada. Volver a tocar el enlace la recrea entera: «ahora no» no es «nunca».

**Esto es una superficie de UI nueva y se marca como tal.** Revertirlo es un commit; el resto del PR no
depende de ello.

### 3 · Re-abrir el MISMO enlace mandaba a repetir un «sí» ya dado

La primera versión no preservaba la confirmación en un re-tap, a propósito. Pero `step(…)` no mira la fase
hasta que se tapea el CTA, así que reabrir el mensaje de WhatsApp para releerlo —estando ya en «esperando
aprobación»— pintaba `.welcome` y pedía el nombre otra vez, con el join en vuelo.

Corregido con la distinción que faltaba: **el TOKEN es la identidad de la invitación**. Mismo token ⇒ misma
invitación ⇒ el «sí» se conserva. Token distinto ⇒ invitación nueva ⇒ hay que confirmar.

### 4 · El drain trataba «no hay invitación» como «no la confirmó»

`?? false` sobre una entry ausente presentaba la hoja a quien **ya está dentro del grupo** (el intent puede
morir entre el submit y el drenaje: el pull baja el member y `.correctAndClear` lo limpia mientras un
blocker retiene la cola). Y su CTA no podía hacer nada — `reconcile` sale por su `guard !entries.isEmpty`.
Ahora son **tres estados**: sin entry no se presenta.

### 5 · Una afirmación MÍA era falsa, y estaba en el ticket antes que en el código

Escribí —en el código y arriba en este ticket— que `performSilentSetup` **escala `onboardingMode` al iKV**
con merge never-downgrade, dejando los otros dispositivos recortados a Grupos sin vuelta atrás. **Medido, es
falso por este camino**: el `didSet` de `SessionState.onboardingMode` embuda en `OnboardingMode.setCurrent`,
que escribe `UserDefaults.standard` a secas. Los dos que SÍ empujan esa key al iKV son
`GroupsOrganizerOnboarding` (`setSynced`) y `FullModeActivationView`.

La premisa venía del encabezado de `GroupsGateLogic`, donde **sí** es cierta —para el alta del
organizador—, y la arrastré a un camino donde no aplica. Es exactamente lo que el `CLAUDE.md` advierte:
distinguir lo medido de lo inferido. **La rama sigue siendo correcta**, y su daño real es peor de lo que yo
titulaba en un aspecto: `userName`, `defaultCurrencyCode` y `defaultPeriod` van por `PreferenceSyncService`
⇒ **sí viajan al iKV**, así que unirse a un grupo te renombraría el perfil y te cambiaría la moneda **en
todos tus dispositivos**. Lo que no viaja es el modo, que es local y recuperable con
`FullModeActivationView`. Corregido en los tres sitios donde lo había escrito mal.

### 6 · Y una escritura que la medición retiró

`performJoinOnlySetup` marcaba `hasShownGroupsOnboarding` («esta vista es su educativo»). Medido, eso
**APAGA el educativo de Grupos —tres pantallas— a quien nunca lo ha visto**, per-device y para siempre:
`hasSeenAnyGroupsEducational` es `hasShownOnboarding OR (onboardingMode == .groupInvite AND alta hecha)`, y
para un usuario `.full` de toda la vida el segundo término es falso ⇒ esa línea era la única que decidía.
Esta hoja es UNA pantalla de bienvenida: hace de educativo para quien llega sin app, no para quien ya usa
Yala y entra en Grupos por primera vez. **Retirada**, y añadida a la lista de escrituras prohibidas del
source-scan.

## Un hueco REAL que se deja abierto, declarado y no arreglado

`hasCompletedOnboarding` es una key **por device** (`PreferenceSyncService`: «NOT synced»), así que el
predicado que bifurca el CTA pregunta «¿este teléfono hizo el alta?», no «¿esta persona tiene cuenta?». Un
**segundo dispositivo** o una **reinstalación** de alguien con la cuenta consolidada responden `false` y
toman el alta completa, que le pisa nombre y moneda cross-device.

**No es una regresión de este PR**: esa misma condición era la puerta de la hoja antes del cambio, así que
quien la veía era exactamente quien tomaba esa rama. Cerrarlo pide una señal de CUENTA que este camino no
tiene hoy. Se declara aquí para que no se lea como cubierto.

## Lo que NO se hizo, y por qué

- **No se extendió el seam `-uitest-invite-onboarding`.** `checkInitialSyncState` (`ContentView:1269`)
  retorna antes cuando el onboarding está hecho, así que hoy no alcanza a este caso. Extenderlo pintaría la
  vista sin ejercitar la decisión —que es donde estaba el bug— y la decisión ya queda cubierta por tests
  deterministas. Se anota como residual en el índice, no como deuda silenciosa.
- **Cero cambios de l10n, de UI y del flujo de install limpia.**

## Contraste visual con la base `2.1` — hecho a medias, y la mitad que falta se midió

Capturado en simulador (iPhone 17 Pro, iOS 26.5, `Yala Dev`) con `-uitest -uitest-invite-onboarding`:

- **Recorrido del invitado FRESCO: idéntico a `2.1`.** Campo de nombre vacío (su perfil lo está, así que
  el prellenado no actúa), un solo botón «Unirme al grupo», **sin** «Más tarde». Es exactamente la
  acotación pretendida: al fresco no se le ofrece salir.
- **El caso NUEVO no se pudo capturar, y el intento vale como medición.** Se sembraron
  `hasCompletedOnboarding = true` y `userName` en el plist del contenedor antes de lanzar; la hoja salió
  igual (sin prellenado y sin salida). Confirma lo que este ticket declara como residual: el seam
  `-uitest-invite-onboarding` entra por `presentNextOnboardingScreen`, al que `checkInitialSyncState`
  (`ContentView:1269`) no llega con el onboarding hecho — y el propio `-uitest` monta el dominio efímero de
  `UITestEphemeralDefaults`, así que sembrar el plist tampoco alcanza.

⇒ **el aspecto de la hoja para quien ya tiene cuenta no está observado, solo razonado.** Lo que sí está
verificado es su DECISIÓN (15 casos deterministas, comprobados por mutación). Entra en el device-QA de
abajo, y ahí es donde se mira.

## Verificación pendiente (device-QA)

Entra en el montaje de dos teléfonos de `qa/guion-tanda.md`. **B = cuenta ya creada**: abre el enlace y
tiene que ver la hoja, con su nombre puesto, y no estar dentro del grupo hasta tocar «Unirme al grupo».
Repetirlo con la app en frío, en segundo plano y abierta. Y el criterio de no-regresión, que es el que
importa: después de unirse, **el nombre de perfil, la moneda y el periodo de B siguen como estaban**, y sus
otros dispositivos no se recortan a Grupos.

## QA Visual · 2026-09-16 — parcial (sigue en qa: cola de device)

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, usuario ya onboarded y enlace de invitación pasado con `-uitest-deeplink-url`.

**Lo que se vio:**
- En frío: sale la hoja con **«Unirme»** y **«Más tarde»**. «Más tarde» la cierra y deja al usuario en el Panel.
- En caliente (enlace abierto con la app viva): la hoja trae el **nombre del perfil ya puesto** y «Más tarde».
- «Unirme» → «Conectando…» → «Está tardando…» → «Conecta tu cuenta». Ahí se acaba el simulador: sin
  App Attest no hay sesión con el servidor.

Capturas: [en frío](../../qa/evidencia-barrido-20260916/26-invite-frio-nombre-icono-color-y-mas-tarde.jpg) · [en caliente](../../qa/evidencia-barrido-20260916/27-invite-caliente-onboarded-nombre-prellenado-mas-tarde.jpg).

**Lo que falta, en un iPhone con TestFlight:**
1. Onboarding completo con un nombre y una divisa reconocibles.
2. Tocar un enlace de invitación real a un grupo.
3. Debe salir la hoja con ese nombre puesto. Tocar «Unirme».
4. **PASS** si entra al grupo y Perfil conserva el nombre y la divisa de antes, sin repetir el onboarding.

Visto de paso, sin ticket: bajo `-uitest-fake-cloud-session`, cancelar «Conecta tu cuenta» vuelve a
presentar la hoja en bucle. Es un estado imposible fuera del simulador (sesión sin token).
