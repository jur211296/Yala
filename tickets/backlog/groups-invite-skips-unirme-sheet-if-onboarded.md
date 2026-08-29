---
id: groups-invite-skips-unirme-sheet-if-onboarded
status: backlog
priority: high
area: groups
created: 2026-08-28
updated: 2026-08-28
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

## HOLD

Sin implementación en este ticket: **cero Swift**. `status` sigue `backlog`. No inventar PASS. Sin App
Store, sin tag de release, sin TestFlight. A7/M5 sigue en HOLD.

## Acceptance Criteria

- [ ] Con `hasCompletedOnboarding == true`, abrir un enlace de invitación **presenta** la hoja del
      invitado antes de cualquier `join_group`, y el join solo ocurre tras el CTA.
- [ ] Ese comportamiento es idéntico por los cuatro orígenes: tap con la app viva (`.universalLink`),
      arranque en frío (`.boot`), vuelta a primer plano (`.foreground`) y `.remoteInsert`. El CTA de la
      propia hoja y el retry del banner (`.userAction`) **siguen** sin re-presentarla.
- [ ] Presentar la hoja a un usuario con cuenta **no** escribe `onboardingMode = .groupInvite`, ni
      cambia `defaultCurrencyCode` / `defaultPeriod` / `userName` del perfil, ni vuelve a contar el KPI
      de registro. (Criterio de no-regresión de las preferencias; el punto anterior no vale si esto se
      rompe.)
- [ ] El invitado fresco conserva su recorrido actual: hoja primero, nombre capturado antes del join.
- [ ] Los dos tests que hoy pinnean `.join` para un usuario con onboarding
      (`GroupBackendInviteEntryLogicTests:59-63` y `GroupsGateLogicTests:112`) quedan actualizados
      **explícitamente** al contrato nuevo, no borrados; el espejo `:192-216` sigue en pie sin
      hardcodear.

Verificación pendiente: los criterios se comprueban cuando se implemente el fix, y el primero exige
device (dos teléfonos) o un seam de XCUITest que hoy no existe. No se inventa PASS.
