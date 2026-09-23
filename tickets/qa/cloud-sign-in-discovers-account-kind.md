---
id: cloud-sign-in-discovers-account-kind
status: qa
priority: high
area: "modo-nube, onboarding, groups"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» §7 — el bloque [I]"
updated: 2026-09-23
---

# Un solo bloque de identidad en la nube: todo sign-in descubre si la cuenta es nueva, completa o solo grupos, y rutea

## El problema, en lenguaje de usuario

Tengo una cuenta de Yala completa en la nube. Cambio de móvil y, como lo que quiero es ver un grupo,
entro por «Vengo por un grupo». Yala me trata como si solo tuviera grupos: sin Panel, sin mis cuentas,
sin avisarme de que mi cuenta tiene todo eso. Al revés también: entro por «Ya tengo cuenta → Google»
con una cuenta que solo usé para grupos y Yala me adopta como completa. Y si no tengo cuenta, «Ya tengo
cuenta» me dice «No encontramos una cuenta» y me deja mirando un botón de volver.

## Lo medido (2026-09-09, árbol `3a94604e`)

- El único sitio que pregunta al backend si la cuenta existe es `WelcomeCloudSignInView.runSignInFlow`
  (`Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift:730-800`): `CloudAccountClient().exists` en
  `:743`, fase `.notFound` en `:764` con copy «Este Apple ID aún no tiene una cuenta Yala en la nube» y
  solo «volver» (`messageContent`, `:634-651`, sin acción).
- La rama «Vengo por un grupo» firma con `GroupsSignInView` (`Yala/App/Views/Groups/GroupsSignInView.swift`,
  192 líneas: botones Apple/Google → `CloudAuthService.signIn`, nada más) y sigue por
  `GroupsGateLogic.nextStep` (`Yala/App/Logic/GroupsGateLogic.swift`): consentimiento → nombre → grupo.
  Ninguna consulta al backend sobre la cuenta.
- El alta born-cloud (`runBornCloudFlow`, `:697-726`) ya distingue «existía» (`.continueAsReturningUser`)
  de «nueva» (`.activateStorageAndRelaunch`) — es la mitad del bloque que ya está.

## Lo que se espera (ADR §7)

**[I]** = Apple/Google → `¿existe? + kind` → uno de tres resultados **excluyentes**: *nueva* /
*completa* / *solo grupos*. **Todo** sign-in en la nube pasa por [I], y cada puerta declara qué hace
con cada resultado:

| Puerta | nueva | completa | solo grupos |
|---|---|---|---|
| Primera vez → nube | crear (`kind=complete`) → [P] | = «Ya tengo cuenta» (adopta) | entra solo-grupos y ofrece «Activar Yala completo» |
| Ya tengo cuenta → Apple/Google | «No hay cuenta» **con botón** a «Primera vez → nube» | adopta y entra | entra solo-grupos |
| Vengo por un grupo (crear / invitación) | crear (`kind=groups_only`) → [G] → grupo / unirse | entra completa y abre Grupos (y la invitación, si la había) | entra y sigue a [G] o a unirse |
| Privada + asociar grupos (desde Grupos **o al llegar una invitación**) | crear (`groups_only`) → [G] → asociada (→ unirme) | **bloquea**: «esa cuenta ya tiene Yala completo» + dos salidas: «Ya tengo cuenta» / «asociar otra cuenta» | [G] si falta → asociada (→ unirme) |
| Privada → Ajustes «migrar a la nube» | cutover existente → nube completa | **bloquea** (sería una fusión): salidas «Ya tengo cuenta» (reemplaza lo privado) / cancelar | es mi asociada → **promover** + cutover; otra → bloquear (una cuenta a la vez) |

## Alcance

1. Extraer de `WelcomeCloudSignInView` la parte «firmar → exists+kind → guard cross-cuenta» a un
   componente reusable (vista + `CloudWelcomeSignInFlow` ampliado con `kind`), y que `GroupsSignInView`
   lo use en vez de firmar a pelo. El consentimiento y el resto del recorrido de grupos no cambian.
2. La tabla de arriba como lógica pura testeable (`enum`, entrada: puerta × resultado × ¿hay sesión
   privada? → destino).
3. `.notFound` en «Ya tengo cuenta» gana un botón primario que lleva a «Primera vez → nube» con el
   proveedor ya elegido (no un callejón).
4. El bloqueo del flujo «privada + asociar → completa» con copy propio y sus dos salidas.
5. «Completa» entrando por grupos: adopta como en «Ya tengo cuenta» (mismo `CrossAccountEntryGuardLogic`)
   y aterriza en la pestaña Grupos con la invitación pendiente re-emitida (`reEmitInviteAfterRestore`
   ya existe para el restore de iCloud).

## Criterios de aceptación

- [ ] Las 15 celdas de la tabla tienen test unitario sobre la lógica pura.
- [ ] Invitación (link) con sesión privada y sin cuenta asociada → [I] → asociada → hoja «unirme»; con
      una cuenta completa → bloqueo, la invitación sigue pendiente en `PendingJoinStore`.
- [ ] En staging: cuenta completa entrando por «Vengo por un grupo» → app completa, pestaña Grupos.
- [ ] Cuenta solo-grupos entrando por «Ya tengo cuenta → Google» → solo-grupos (no adopción).
- [ ] Cuenta inexistente por «Ya tengo cuenta» → pantalla con botón que lleva al alta; el alta crea.
- [ ] Sesión privada + asociar una cuenta completa → bloqueo con las dos salidas; ninguna escritura.
- [ ] `WelcomeCloudSignInView` conserva byte-idéntico el guard cross-cuenta y el provider-mismatch (sus
      tests actuales siguen verdes).

## Cómo se prueba

Unit (lógica pura + `CloudWelcomeSignInFlowTests`), XCUITest del chooser con el seam
`-uitest-cloud-chooser`, y device-QA contra staging para los cuatro recorridos con cuentas reales.

## Depende de

`backend-account-kind-complete-or-groups-only`.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **La adopción de una cuenta completa entrando por «Vengo por un grupo» es SILENCIOSA.** Sin aviso, sin
  banner y sin preguntar: entra completa y aterriza en Grupos, tal cual dice el ADR §7. No añadas
  ceremonia «por prudencia» — es una decisión tomada con el riesgo delante (alguien que solo quería ver
  un grupo se encuentra sus finanzas en ese móvil); el guard cross-cuenta sigue siendo la única red.
- **`.notFound` en «Ya tengo cuenta» lleva DIRECTO AL CONSENTIMIENTO** de nube con el proveedor ya
  firmado; no repite el chooser de proveedor. El consentimiento **no se salta** (es el único paso que no
  se recorta). Si el usuario quiere otro proveedor, retrocede.
- **`GroupsSignInView` cambia de motor, no de aspecto.** Por dentro usa el componente [I]; por fuera la
  puerta de Grupos se sigue viendo como hoy, con su tono de mini-app. Si algún día debe unificarse
  visualmente, eso es del ticket 12, no de éste.
- **Tests: las 15 celdas de la tabla + los bordes donde «hay sesión privada» cambia el destino**
  (asociar, migrar a la nube, los dos bloqueos). No hace falta escribir las 30 combinaciones ni afirmar
  las imposibles; sí hace falta que el eje «sesión privada sí/no» quede cubierto donde decide algo.

---

## Analisis tecnico

> Medido el **2026-09-10** sobre `8964c734`. Las líneas del cuerpo de arriba son de `3a94604e` y varias
> han envejecido: se re-greppearon todas. Lo que cambió respecto a lo escrito arriba se marca **⚠️**.

### Lo que el paso 2 ya dejó hecho, y cambia el alcance

El ticket se escribió antes del paso 2. Hoy ya existen en el cliente:

| Pieza | Dónde | Qué hace |
|---|---|---|
| `AccountKind` (`complete` / `groupsOnly`) | `Yala/App/Logic/AccountKindLogic.swift:23` | el dato |
| `AccountKindLogic.resolve` / `.snapshotToPersist` | `:57`, `:72` | qué creerse cuando el servidor calla |
| `AccountKindSnapshot` sellado con `userID` | `:35` | la caché |
| `AccountKindStore` / `AccountKindService` | `Yala/Services/CloudSync/AccountKindService.swift:32`, `:71` | persistencia + refresco |
| `CloudAccountClient.ExistsOutcome.exists(Bool, kind:)` | `Yala/Services/CloudSync/CloudAccountClient.swift:44`, `:268` | el `kind` en el wire |
| `CloudWelcomeSignInFlow.ExistsRoute.accountFound(kind:)` | `Yala/App/Logic/CloudWelcomeSignInFlow.swift:105` | el `kind` transportado |
| La escritura de la caché en el Welcome | `WelcomeCloudSignInView.swift:772-776` | ya cachea |

⇒ **el alcance 1 se reduce**: `CloudWelcomeSignInFlow` **ya está ampliado con `kind`**. Lo que falta es
exactamente lo que sus tres docblocks declaran pendiente de este ticket: **quién lo usa para rutear**
(`AccountKindLogic.swift:13-15`, `AccountKindService.swift:21-22`, `WelcomeCloudSignInView.swift:769-771`).

### ⚠️ Tres premisas del ticket que la medición corrige

1. **`reEmitInviteAfterRestore` no re-emite nada.** Su cuerpo (`ContentView.swift:1344-1347`) es una sola
   llamada a `GroupJoinReconciler.reconcile(trigger: .foreground)`; el docblock lo dice: el nombre se
   conserva por sus call-sites, no por su función. Lo que sostiene «la invitación sigue pendiente» es
   `PendingJoinStore` (`UserDefaults`, TTL 7 d, sobrevive al relanzamiento **y** a XCUITest) más el
   reconciler en el boot. ⇒ el alcance 5 **no necesita re-emitir**: necesita aterrizar en Grupos.
2. **El XCUITest de [I] es inalcanzable hoy.** `-uitest-cloud-chooser` existe (`UITestHooks.swift:53`),
   pero no hay seam que stubee `/account/exists` ni el SIWA real, y `WelcomeChooserUITests` declara que el
   botón de sign-in jamás se tapea. La decisión de Jürgen acota los tests a «15 celdas + bordes de sesión
   privada» ⇒ **unit**, y eso deroga el «XCUITest del chooser» de «Cómo se prueba».
3. **La celda «grupos + nueva» no necesita backend.** `profiles.kind` es `not null default 'groups_only'`
   (`qa/cloud/g15_01_account_kind.sql:106`) y la fila la crean `create_group`/`join_group` (verificado en
   sandbox, `:41`). `CloudAccountClient.claim` **no** tiene parámetro `kind` (`:192`) y la puerta de grupos
   **no** llama al claim. ⇒ la cuenta nace del tipo correcto sola; **el claim no se toca**.

### El estado del Worker, medido — y por qué decide el diseño

**Ninguno de los dos entornos sirve `kind` hoy.** Staging: último deploy `2026-08-12T13:05:19Z`.
Producción: `2026-09-10T06:12:16Z`, **anterior** al commit `675aadec` (`08:31 UTC`) que escribió el campo.
⇒ `GET /account/exists` contesta `{exists:true}` sin `kind`, y por eso **`kind == nil` rutea al
comportamiento de HOY en cada puerta** (Paso 0 · D1 del encargo). Sin el dato nuevo, el sistema se
comporta como antes del dato nuevo: eso es lo que hace este PR seguro de mergear antes del deploy.

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---|---|---|
| `Yala/App/Logic/CloudIdentityRoutingLogic.swift` | Crear | Alto — la tabla del ADR §7 como lógica pura |
| `YalaTests/CloudIdentityRoutingLogicTests.swift` | Crear | Alto — 15 celdas + bordes del eje privado |
| `Yala/Services/CloudSync/CloudIdentityDiscovery.swift` | Crear | Alto — el motor [I] compartido |
| `YalaTests/CloudSync/CloudIdentityDiscoveryTests.swift` | Crear | Medio |
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | Modificar | Alto — ruteo por tabla, `.notFound` con salida |
| `Yala/App/Views/Groups/GroupsSignInView.swift` | Modificar | Alto — motor nuevo, **aspecto intacto** |
| `Yala/App/Views/Shared/GroupsBackendInviteModifier.swift` | Modificar | Alto — rutea el destino y hospeda el bloqueo |
| `Yala/App/ContentView.swift` | Modificar | Medio — reencamina al cover y aterriza en Grupos |
| `Yala/Utils/L10n.swift` + 16 × `Localizable.strings` | Modificar | Medio — copy del bloqueo y del botón |
| `qa/coverage-index.json` | Modificar | Bajo — contrato anti-drift |

### Modelo de datos
Ninguno. Cero migraciones SwiftData y cero cambios de backend (Paso 0 · D6).

### Dependencias
- **No se extrae el guard cross-cuenta** de `WelcomeCloudSignInView`: `CrossAccountEntryGuardLogicTests:235-248`
  hace source-scan de su rama `.blockedForeignData` **dentro de ese fichero** (Paso 0 · D3).
- **Tests que deben seguir verdes sin tocarlos:** `CloudWelcomeSignInFlowTests`, `CrossAccountEntryGuardLogicTests`,
  `AccountKindLogicTests`, `GroupsGateLogicTests`, `WelcomeSignInVerbTests` (su
  `groups_usesTheSignUpVerb` exige `purpose: .signUp` y prohíbe `.signIn`/`.continue` en `GroupsSignInView`).
- **Dos docblocks quedan mintiendo si no se corrigen** (su test sigue verde, la prosa no): la regla dura
  «NO `CrossAccountEntryGuardLogic`» de `GroupsSignInView.swift:6-9` y el «nadie alcanza este sheet con una
  sesión viva ⇒ las dos entradas son altas» de `WelcomeSignInVerbTests.swift:88-92`.
- Puerta 5 (Ajustes → migrar): **tabla sí, cableado no** (Paso 0 · D4). Necesita el ticket 10.

## Plan de implementacion

### La tabla, como queda

Cuatro puertas **físicas**; la de Grupos cubre dos filas del ADR según el segundo eje, y ahí es donde
«hay sesión privada» **cambia el destino** — que es justo el borde que Jürgen pidió cubrir:

| Puerta física | nueva | completa | solo grupos |
|---|---|---|---|
| Welcome «Primera vez → nube» | crear `complete` → [P] | adopta (= «Ya tengo cuenta») | entra solo-grupos + ofrece Yala completo |
| Welcome «Ya tengo cuenta» | «No hay cuenta» **+ botón al alta** | adopta y entra | entra solo-grupos |
| Grupos, **sin** sesión privada | sigue [G] (nace `groups_only`) | **adopta y abre Grupos** | entra y sigue a [G] / unirse |
| Grupos, **con** sesión privada | sigue [G] → asociada | **bloqueo** + 2 salidas | asocia → [G] / unirse |
| Ajustes «migrar a la nube» | cutover existente | **bloqueo** (sería fusión) | mi asociada → promover + cutover; otra → bloqueo |

### Incrementos (orden de ejecucion)

1. **La tabla pura** — `CloudIdentityRoutingLogic`: `Gate` × `Discovery` × `hasPrivateSession` → `Destination`.
   - Archivos: `Yala/App/Logic/CloudIdentityRoutingLogic.swift`, `YalaTests/CloudIdentityRoutingLogicTests.swift`
   - Tests: las **15 celdas**; el eje privado en las cuatro celdas donde decide; que las puertas del
     Welcome sean **insensibles** al eje (y por qué); mutante por celda.

2. **El motor [I]** — `CloudIdentityDiscovery`: firma si hace falta → `exists`+`kind` → cachea el snapshot
   → devuelve `Discovery`. Inyectable (cliente, sesión, store) para test sin red.
   - Archivos: `Yala/Services/CloudSync/CloudIdentityDiscovery.swift`, su test
   - Tests: `exists:false` → `.newAccount`; `exists:true,kind:complete` → `.complete`; `kind` **ausente** →
     `.unknown` (y que **no** borre lo cacheado); red caída → `.unavailable`; que el snapshot se escriba.

3. **El Welcome usa la tabla** — la rama `.accountFound` consulta `CloudIdentityRoutingLogic` en vez de ir
   siempre al guard; `.notFound` gana su botón primario al alta con el proveedor ya elegido
   (`entryOverride` + `chosenProvider` + consent, sin repetir el chooser de proveedor).
   - Archivos: `WelcomeCloudSignInView.swift`, `L10n.swift`, 16 `.strings`
   - Tests: los suyos siguen verdes **sin tocarlos**; source-scan de que la rama del guard sigue intacta.

4. **La puerta de Grupos cambia de motor** — `GroupsSignInView` firma y **descubre** dentro de su propio
   `Task` (mismo spinner, mismo aspecto), y entrega el destino; el modifier lo consume en su `onDismiss`
   con el molde one-shot que ya usa. `.enterGroupsOnly` es **byte-idéntico a hoy**.
   - Archivos: `GroupsSignInView.swift`, `GroupsBackendInviteModifier.swift`
   - Tests: `WelcomeSignInVerbTests` verde; source-scan del orden de los efectos post-sign-in.

5. **Los dos destinos nuevos de Grupos** — «completa» reencamina al cover del Welcome en `.reentry(provider)`
   con la sesión viva (`runSignInFlow` salta el sign-in: es el patrón `continueAsReturningUser` que ya
   existe, sin anchor nuevo), y al terminar sin relanzamiento selecciona la pestaña Grupos. «Completa con
   sesión privada» presenta el **bloqueo** con sus dos salidas y **sin escribir nada**.
   - Archivos: `ContentView.swift`, `GroupsBackendInviteModifier.swift`, `L10n.swift`, 16 `.strings`
   - Tests: que el bloqueo no escriba ninguna de las keys de la puerta (molde `GroupsOrganizerBranchTests`
     con control positivo).

6. **Cierre** — `qa/coverage-index.json`, las filas de la matriz, los dos docblocks que quedarían
   mintiendo, y ticket por cada hallazgo que no entra.

### Riesgos

- **Regresión en producción por `kind` ausente.** Mitigado por diseño: `kind == nil` ⇒ comportamiento de
  hoy por puerta (D1). Es el riesgo principal y la razón del diseño entero.
- **Dos anchors ante el mismo flujo** (regla 4 de Presentaciones): mitigado reusando el cover del Welcome
  en vez de duplicar la pantalla de adopt, que es lo que su docblock prohíbe.
- **Adopción silenciosa desde Grupos**: es decisión de Jürgen tomada con el riesgo delante; el guard
  cross-cuenta sigue siendo la única red, y se conserva intacto.
- **Carrera sign-in → descubrimiento → `onDismiss`**: mitigada haciendo el descubrimiento **dentro** del
  `Task` de la vista, antes de avisar al modifier.
- **Fallo de red del `exists` tras firmar**: degrada a `.enterGroupsOnly` (lo de hoy) en vez de bloquear la
  entrada al grupo; la matriz pide «error reintentable, sin crear ni borrar nada».

### Estimacion
- Incrementos: **6**
- Complejidad: **alta** (identidad + sync + dos puertas que hoy no se hablan)

---

## Lo que la review adversarial cambió (2026-09-10)

Tres lentes independientes sobre el diff, más la lectura de las rules de área contra él. **Cazaron nueve
defectos de la primera implementación**, y dos eran graves. Se arreglaron todos; lo que no entra queda con
ticket. Se registra porque la lección se repite: *la review adversarial caza lo mío*.

### Los dos graves

1. **El bloqueo se deshacía solo.** Solo «usar otra cuenta» soltaba la sesión rechazada; «Entendido», la
   «X» y el swipe la dejaban viva — y **toda** la cadena de Grupos decide por `hasSession`
   (`GroupsGateLogic:145`). Al volver a foreground, el reconciler saltaba el sign-in y unía a la persona al
   grupo **con la cuenta que la app acababa de rechazar**, sin que tocara nada. Arreglado moviendo el
   `signOut()` al `onDismiss` del sheet, que es el único punto por el que pasan las cuatro salidas.
2. **El eje era un `Bool` y «no hay sesión privada» era cierto por tres motivos distintos.** La puerta de
   Grupos los trataba a los tres como «móvil limpio, adopta», así que a quien ya estaba en la nube completa
   y volvía a firmar por caducidad de sesión se le montaba **la migración de su propia cuenta**,
   re-adoptando un dispositivo ya adoptado; y si su claim local no estaba, el guard cross-cuenta le decía
   «estos datos no son tuyos» **al dueño de los datos**. El eje pasó a ser
   `DeviceSessionState` con los cuatro estados de la matriz, y sus dos estados de nube tienen su borde con
   test y con mutante verificado.

### Los otros siete

3. **`onEnterGroupsOnly` se saltaba `GroupsOrganizerGateLogic`** —el guard de datos ajenos— porque llamaba
   a la cadena y no a la puerta. Ahora va a la puerta.
4. **…y colisionaba con el `onDismiss` de respaldo del cover**, que reabría el chooser encima y dejaba la
   cadena de Grupos retenida por el blocker `welcomeFlow`. El guard del respaldo gana su término.
5. **La adopción desde Grupos no era silenciosa**: pedía un «Iniciar sesión» que la persona acababa de
   hacer, más el consentimiento. La decisión de Jürgen prohíbe la ceremonia, así que el cover arranca en el
   consentimiento — un gesto, y es el que él protegió explícitamente.
6. **El camino nuevo del Welcome no desarmaba el boot-wipe de grupos**, así que quien recuperaba sus grupos
   tras un «Salir de Yala» los perdía en el siguiente arranque en frío.
7. **El belt de `onAppear` dejaba los botones tapeables durante el viaje de red** — un frame se convirtió en
   un round-trip y la regla dura «jamás re-ofrecer sign-in con sesión» quedaba abierta. Lleva su spinner.
8. **El sheet del bloqueo no estaba en la matriz de readiness** (regla 3 de Presentaciones), y es el que más
   lo necesita: lo presenta el `onDismiss` del sheet anterior, el instante exacto en que el drain busca a
   quién montar.
9. **Un lector de `UserDefaults.standard` con `Keys.hasCompletedOnboarding`** habría roto
   `SessionPreferenceKeysTests.spellingCountsMatch`, que tiene sus 26 sitios clavados. Pasó al espejo
   observable, que es además lo que piden las rules de área.

### Cinco afirmaciones falsas en mis propios comentarios

Todas comprobables con un grep, y todas escritas por mí: `.adoptAsComplete` etiquetado «inalcanzable»
cuando es el destino más frecuente de su puerta y su propio test lo permite · «el motor compartido» con un
solo llamador mientras el Welcome conservaba su copia de la secuencia (arreglado: ahora lo usa de verdad) ·
«el belt la cierra de inmediato» cuando ya hacía un viaje de red · el `hasPrivateSession: false` justificado
con «esta pantalla solo se alcanza desde el Welcome», premisa que el propio cambio rompió · «tiene ticket
propio» sin ticket (creado). Y un docblock de `L10n` que quedó documentando la pantalla equivocada.

### Lo que se decidió NO arreglar aquí, con ticket

- `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` — bug vivo medido: esa puerta adopta en
  silencio tras dos confirmaciones destructivas. Sus tres celdas están en la tabla; el cableado necesita el
  paso 10.
- `borncloud-consent-epoch-written-before-the-guard-decides` — preexistente; [I] ensancha la vía.
- `groups-block-has-no-route-to-storage-settings` — la segunda salida del bloqueo es texto porque no hay
  intent de router a esa fila de Ajustes.
- `groups-organizer-intent-is-lost-on-relaunch` — el intent del organizador no es durable.
- `no-test-seam-for-account-exists-blocks-xcuitest-of-identity` — sin seam para stubear `exists`, [I] no es
  alcanzable por XCUITest.

---

## Device-QA · el montaje, y su trampa

**NO es simulable**, y la razón es doble: el simulador no tiene sesión de nube (SIWA/Google reales) y, sobre
todo, **hoy `kind` no se sirve**. Medido el 2026-09-10: staging con su último deploy del `2026-08-12` y
producción con el del `2026-09-10T06:12Z`, anterior al commit `675aadec` que escribió el campo.

### ✅ DESBLOQUEADO: el Worker se desplegó el 2026-09-10 (con el OK de Jürgen)

`kind` **ya viaja** en los dos entornos, así que los cuatro recorridos se pueden distinguir.

| Entorno | Versión | Delta que subió |
|---|---|---|
| producción | `034e1074-929c-495b-b91b-579a0b4b0875` | 1 commit (el del `kind`) |
| staging | `53e181d4-58ec-42b5-8197-a83bab78b15a` | 12 commits — llevaba sin desplegar desde el 2026-08-12 |

La base se verificó en los dos ANTES de desplegar (columna, default, trigger, check, una sola sobrecarga
de `claim_account`); el detalle y el smoke están en el ticket del paso 2. **Queda una sola condición
previa: recrear los grupos de prueba en el iPhone**, que sigue apuntando a la cuenta que el fresh start
borró — mientras el JWT viva, cada llamada da 409/502.

> Para futuros deploys: `npm run deploy:staging` / `npm run deploy:production` desde `gateway/`, **nunca
> `wrangler` a pelo** — y ahora se sabe por qué: el `predeploy` corre `sync:manifest`, que copia los dos
> `*_capability_manifest.json` de la raíz a `gateway/`. Sin ese paso el Worker se empaqueta con el
> manifest viejo.

**Lo que el deploy de staging arrastró, y conviene tener presente al leer un rojo de goldens:** doce
commits de un mes, entre ellos `f84620b5` («los goldens de Grupos seguían pidiendo el canon viejo»), que
era un fix **sin desplegar**. Si algún golden de Grupos cambia de veredicto respecto a mediciones previas
al 2026-09-10, ésa es la causa probable.

### Los cuatro recorridos

| # | Montaje | Qué tiene que pasar |
|---|---|---|
| 1 | iPhone limpio · «Ya tengo cuenta → Google» con una cuenta **solo-grupos** | **No adopta.** Aterriza en la puerta de Grupos, no en el Panel |
| 2 | iPhone limpio · «Ya tengo cuenta» con un Apple ID **sin cuenta** | Pantalla «No encontramos una cuenta» **con botón**; el botón abre el consentimiento con ese mismo proveedor y el alta crea |
| 3 | iPhone limpio · «Vengo por un grupo» con una cuenta **completa** | Entra completa y aterriza en **Grupos** (sin aviso ni banner: la adopción es silenciosa a propósito) |
| 4 | iPhone con **sesión privada** viva · abrir una invitación con una cuenta **completa** | **Bloqueo** «esa cuenta ya tiene Yala completo», con «Usar otra cuenta». Al cerrarlo por cualquier salida, la sesión queda cerrada; la invitación sigue pendiente y se retoma con otra cuenta |

### Qué mirar además de la pantalla

- **En el 4, que no se escriba nada**: tras el bloqueo, el tab Grupos debe seguir ofreciendo «crea tu
  cuenta» y no el empty state de re-entrada (eso probaría que el latch de historial se armó).
- **En el 4, la salida por swipe y por «Entendido»**, no solo por el botón: son las que se saltaban el
  cierre de sesión y hacían que el bloqueo se deshiciera solo.
- **En el 1, tras un «Salir de Yala en este dispositivo» previo**: recuperar los grupos y **forzar el cierre
  de la app**. Al reabrir deben seguir ahí (es el boot-wipe que el camino nuevo desarma).
- **En el 3, con y sin relanzamiento**: en un móvil recién instalado el adopt termina sin relanzar y la
  pestaña queda en Grupos. Si pide relanzar, la invitación se retoma sola pero quien venía a **crear** un
  grupo aterriza en el Panel — es conocido y tiene ticket (`groups-organizer-intent-is-lost-on-relaunch`).

## Corrección al guion · 2026-09-16 (barrido de QA)

**«Qué mirar», el 1 (:357)** — «Salir de Yala en este dispositivo» ya no existe en la app: su texto no
está en `Localizable.strings` (solo quedan comentarios huérfanos). El verbo de hoy es **«Cerrar sesión»**
(`settings.signOut`). El resto de esa comprobación no cambia.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con los recorridos 1 y 2. El 3 y el 4 quedan cubiertos por `CloudIdentityRoutingLogicTests`.
