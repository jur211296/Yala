---
id: activation-restore-start-fresh-keeps-the-imported-rows
status: done
priority: high
area: "onboarding, modo-nube, grupos"
created: 2026-09-14
source: "medido cerrando `restore-start-fresh-keeps-the-imported-corpus` (2026-09-14); NO reproducido en device"
---

# «Activar Yala completo → Restaurar → Empezar desde cero» borra la zona de iCloud y la vuelve a llenar

## El síntoma, en lenguaje de usuario

Uso Yala solo para grupos y decido activar Yala completo. Elijo «mi iCloud privado», la app me dice que
encontró mis datos de antes y toco «Traer mis datos». Los veo, cambio de opinión y toco «Empezar desde
cero». Termino el onboarding… y **mis datos viejos siguen ahí**.

Y si además tengo Yala en otro teléfono, allí también: lo que se borró arriba vuelve a subir desde aquí.

## Lo medido (2026-09-14, árbol `799e01a3` + el PR de `restore-start-fresh-keeps-the-imported-corpus`)

- El botón lo cablea `FullModeActivationView.swift`, `case .restore` → `onStartFresh: { go(to:
  .onboarding(.freshPrivate)) }`. **No borra nada**, igual que el del Welcome antes de ese PR.
- Y el arreglo del Welcome —mandar el botón a la puerta de iCloud— **aquí no sirve tal cual**. La puerta
  de la activación borra SOLO la zona (`performICloudZoneWipe` → `performICloudCorpusWipe(includingLocalRows:
  false)`), y eso es una restricción del paso 8 que sigue viva: `DataWipeService.wipeAllUserData` resetea
  `hasCompletedOnboarding`, el modo y el nombre, así que borrar lo local mandaría al Welcome a quien está
  activando —y con `FullModeActivationResumeStore` a medias.
- Pero para llegar a `.restore` por este flujo **hubo relanzamiento** (`WelcomeMirrorRelaunchLogic
  .requiresMirror(.fullActivationRestore) == true`), así que el store personal **espeja**: tras el
  relanzamiento `personalStoreDecision` cae en `iCloudAvailable ? .iCloudMirror : .localNoMirror`, y los
  dos adjuntan el mirror (`attachesCloudKitMirror`).
- ⇒ borrar solo la zona deja las filas importadas en el store, y `NSPersistentCloudKitContainer`
  **re-exporta** a la zona recién creada. Un borrado que no borra, bajo un copy que promete lo contrario.

## Por qué no se cerró con su hermano

Cerrarlo pide un borrador que **no existe**: filas personales sin tocar preferencias.
`wipeAllUserData` hace las dos cosas en un solo gesto, y su `resetAllUserPreferences`
(`DataWipeService.swift:553`) va mucho más allá de quitar keys — resetea `AppRouter`, `ProTourManager`,
`SetupChecklistManager` y los espejos del App Group. Partirlo es un objeto propio, con su propio riesgo
sobre un método destructivo que comparten «Vaciar datos» y el wipe remoto.

## Qué hay que decidir antes de escribir

1. **¿Se parte `wipeAllUserData`** (un `resetPreferences: Bool = true`, default que preserva el
   comportamiento de hoy) **o se escribe un borrador nuevo** que solo enumere los modelos? Lo primero es
   menos código y más superficie compartida; lo segundo, al revés.
2. **¿Qué pasa con el dominio de Grupos?** Aquí NO se purga: los grupos son de la misma persona que está
   activando y la activación existe para conservarlos (ADR §6). Eso lo separa del «empiezo de cero» del
   Welcome, que sí es un handover.
3. **¿Y las preferencias residuales?** La puerta de la activación pasa `clearsResidualPreferencesOnWipe:
   false` a propósito: ahí el nombre y la divisa son el prefill de quien activa. Tras un «empezar de
   cero» desde Restaurar, ¿siguen siendo suyos, o son los que acaba de descartar?

## Criterios de aceptación

- [ ] **DEVICE** · Solo-grupos → «Activar Yala completo» → privado → la puerta encuentra corpus →
      «Traer mis datos» → Restaurar → «Empezar desde cero» → tras el onboarding y esperar a que iCloud
      sincronice, **no aparece ningún dato previo**, ni aquí ni en un segundo dispositivo con el mismo
      Apple ID.
- [ ] La sesión de grupos queda **intacta**: los grupos, sus gastos y el modo siguen donde estaban, y la
      persona no acaba en el Welcome.
- [ ] El recorrido del Welcome (`restore-start-fresh-keeps-the-imported-corpus`) sigue verde.

## Relacionados

- [[restore-start-fresh-keeps-the-imported-corpus]] — el mismo botón por la puerta del Welcome, cerrado
  el 2026-09-14. Su test `activationKeepsItsOwnExit` **pinnea la asimetría** y se pondrá rojo cuando este
  ticket se ataque: es su aviso de que hace falta el borrador nuevo, no un obstáculo.
- [[late-icloud-wipe-can-re-export-between-its-two-halves]] — la misma re-exportación, pero por un kill
  entre las dos mitades del borrado. Aquí la segunda mitad no corre nunca, por diseño.
- [[full-mode-activation-must-ask-where-personal-data-lives]] — el paso 8, de donde sale la restricción.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir código (2026-09-14)

Todo lo de abajo está **medido en el árbol de esta sesión** (`3bf024a8`). Las decisiones 2.1A / 2.2A /
2.3A vienen de Jürgen; lo que sigue es lo que la medición añade encima, incluidas **dos cosas que ninguna
de las tres anticipaba y que dejaban la app rota**.

### Lo que el cuerpo del ticket decía y NO es cierto

- **«borra la zona de iCloud y la vuelve a llenar»** (el título) y «el botón sigue sin borrar de verdad»
  (el encargo): el botón **no borra nada**. `FullModeActivationView.swift:152` es
  `onStartFresh: { go(to: .onboarding(.freshPrivate)) }` — ni zona ni filas. El que borra la zona es la
  puerta (`case .privateGate`, `:119`), que es **otro** camino y ni siquiera está en este recorrido.
- **«`wipeAllUserData` resetea `hasCompletedOnboarding`, el modo y el nombre»**: *el modo NO*.
  `PrivateSessionMark.userDefaultsKey == "cloudSync.hasPrivateSession"`
  (`PrivateSessionMark.swift:79`), y `removeUserPreferenceKeys` excluye el prefijo `cloudSync.*`
  **a propósito y con test** (`DataWipeService.swift:594-597`; el propio `PrivateSessionMark.swift:63-65`
  dice que sobrevive «a Vaciar datos, local o remoto»). El eje 1 no está en juego. Lo que sí rompe son
  `hasCompletedOnboarding` (`:725`) y `hasShownWelcomeChooser` (`:726`).

### Lo que la medición añade, y es lo que decide el diseño

**H1 · Sin limpiar el centinela del seed, la persona acaba SIN CATEGORÍAS.** Un alta solo-grupos deja
`seedCategoriesExecuted == true` en el 100 % de los casos normales
(`GroupsOrganizerOnboarding.swift:194`, `GroupInviteOnboardingView.swift:558`; el centinela se escribe en
`CategorySeed.swift:414` y `:419`). `seedCategoriesIfNeeded` sale por su flag guard antes de mirar la base
(`:381-386`), así que el `seedCategoriesIfNeeded` del final del onboarding
(`OnboardingView.swift:1723`) **no siembra nada**. Y con él se va «Ajuste de saldo», sin el cual
`setInitialBalance` falla en silencio (lo dice el propio `CategorySeed.swift:389-392`). ⇒ el flag de 2.1A
**no basta solo**: hay que reabrir las puertas del seed.

**H2 · El prefill salta el paso de categorías, y eso está BIEN — pero solo con H1 resuelto.**
`OnboardingStepPlan.skippedSteps` hace `if prefilledCategoriesCount > 0 { skip.insert(.categories) }`
(`OnboardingStepPlan.swift:76`), y `prefilledSummary` se construye UNA vez en el `.onAppear`
(`FullModeActivationView.swift:96-98`) con el conteo de **antes** del borrado. El paso se salta,
`loadSeedCategories` se queda en su default `true` (`OnboardingView.swift:32`) y el seed se llama igual.
Con el centinela puesto, ese seed es un no-op y nadie se entera.

**H3 · `ProfileImageStorage.shared.delete()` vive FUERA de `resetAllUserPreferences()`**
(`DataWipeService.swift:204` vs `:209`). Un flag que solo salte el reset **seguiría borrando la foto de
perfil**, mientras conserva `userName`, `userAlias` y `userProfileIcon` — las cuatro son la misma sección
de `removeUserPreferenceKeys` (`:632-635`). La foto es un archivo local que **no sincroniza**
(`ProfileImageStorage.swift:17-23`), así que no es corpus que vuelva a bajar: es identidad de quien
activa, igual que el nombre. El flag la cubre también.

**H4 · Grupos ya está protegido por `wipeAllUserData`, y no hace falta hacer nada por 2.2A.** Los seis
modelos del dominio (`SplitGroup`/`SplitMember`/`SplitExpense`/`SplitShare`/`SplitSettlement` +
`GroupBridgePreference`) **no los nombra** ese wipe — lo dice su propio docblock
(`DataWipeService.swift:232-234`, `:411-414`). Quien los purga es `wipeLocalGroupsDomain`, y aquí **no se
llama**. Lo que sí se lleva por delante son las `Category` de sistema de Grupos (el borrado de `Category`
no filtra, `:183-189`) y las cuentas: las primeras las repone la defensa secundaria de
`seedSystemGroupCategoriesIfNeeded` (`CategorySeed.swift:594-606`, que re-siembra cuando el flag miente)
en cuanto el bridge pida una subcategoría (`GroupBridgeSystemEntities.swift:319`), y lo segundo es
**exactamente lo que «Vaciar datos» de Ajustes ya hace hoy en producción** conservando Grupos. Precedente
vivo, no diseño nuevo.

**H5 · El destino tras el borrado NO relanza, y por eso no se cae al Welcome.** A `.restore` solo se llega
como pantalla inicial **después** de un relanzamiento (`initialScreen`, `:79`), y ahí
`personalStoreMountedDecision != .neutralNoMirror` ⇒ `shouldRelaunch == false`
(`WelcomeMirrorRelaunchLogic.swift:117-122`), así que `proceed(to:otherwise:)` cae siempre por su
`otherwise`. Medido en la cadena completa: `proceed` escribió `hasShownWelcomeChooser = true`
(`FullModeActivationView.swift:263`) y desarmó el neutro (`:266`), y eso rompe los dos términos de
`shouldMountNeutralDurable` (`SwiftDataConfiguration.swift:317-326`).

### D1 · «Empezar desde cero» va a la PUERTA, igual que en el Welcome — con un case propio

Se elige la misma salida que su hermano (D1 de `restore-start-fresh-keeps-the-imported-corpus`) y por las
mismas razones, que aquí siguen siendo ciertas una a una: la puerta **mide contra CloudKit** (el resumen
de Restaurar cuenta filas del store, así que su `.notFound` puede ser falso y desde ahí también se ofrece
este botón), enseña cifras, exige un segundo gesto, sobrevive a un kill y su copy ya vive en 16 locales.
Construir fases nuevas en `WelcomeRestoreView` duplicaría cinco mecanismos probados.

**Pero no reusa `.privateGate`, y eso es la decisión:** las dos entradas necesitan **borrados opuestos**.
En `.privateGate` (antes del relanzamiento) lo local es de quien activa y nunca vino de iCloud — borrarlo
sería el daño contrario. Tras el relanzamiento, lo local **es** lo que bajó el espejo, y es justo lo que
hay que quitar. Un `Bool` al lado del step lo heredaría en silencio: el case nuevo
(`.restoreDiscardGate`) hace que el compilador obligue a cada transición a decir con cuál trabaja.

Su cableado se separa del de `.privateGate` en tres puntos, y los tres tienen motivo medido:

| | `.privateGate` | `.restoreDiscardGate` |
|---|---|---|
| `performWipe` | zona sola | zona **+ las filas que el espejo importó** |
| `onBack` | `backFromBranch()` (al chooser, o cancelar) | `go(to: .restore)` — de ahí vino, y `backFromRestore` tras relanzar es **cancelar** (`screenBeforeRestore(hasResume: true) == nil`) |
| `onRestore` | sale sin más | retira el arm antes de salir (el hallazgo nº2 del hermano) |

`deviceCorpus: nil` y `clearsResidualPreferencesOnWipe: false` **no cambian**: el primero porque aquí lo
que hay en el teléfono vino de iCloud y se lo lleva el mismo borrado (el razonamiento de D4 del hermano),
el segundo porque es 2.3A.

### D2 · `wipeAllUserData` gana `resetsPreferences: Bool = true` (2.1A), y el corte se define por escrito

El default preserva el comportamiento de hoy en sus tres consumidores actuales. Con `false`:

- **NO corre** `resetAllUserPreferences()` (las ~114 keys, `AppRouter.resetAll()`, `ProTourManager`,
  `SetupChecklistManager` y los espejos del App Group) **ni** `ProfileImageStorage.delete()` (H3).
- **SÍ corre** la reapertura de los seeds y la limpieza de los punteros a filas borradas, porque **eso no
  es preferencia: es estado que tiene que casar con las filas**. El criterio del corte, en una frase:
  *lo que describe a la persona se queda; lo que describe a las filas que acabo de borrar, se va.*
  Son tres keys, y las dos primeras son exactamente el par que el repo ya trata junto en
  `ShellDataAlertsModifier.swift:48-49`:
  `CategorySeedSentinel.allKeys` (H1) · `notificationsSeeded` · `lastUsedAccountID` del App Group (el
  `shortcutID` de una `Account` que ya no existe, `DataWipeService.swift:578`).

Para que las dos ramas no dupliquen la lista —que es como divergen— la reapertura vive en **un** helper
(`reopenSeedGates(in:)`) y `removeUserPreferenceKeys` la llama en lugar de enumerar esas keys por su
cuenta.

### D3 · `performICloudCorpusWipe` pasa de un `Bool` a un scope de tres, nombrado

`includingLocalRows: Bool` ya no alcanza: hay **tres** políticas y no dos, y la nueva no es «la mitad» de
ninguna. Un segundo y un tercer `Bool` permitirían combinaciones que no existen (purgar Grupos sin borrar
filas). El enum las nombra y el compilador obliga a los cinco call-sites a elegir:

| scope | zona | filas personales | preferencias | dominio Grupos | quién |
|---|---|---|---|---|---|
| `.zoneOnly` | sí | — | — | — | la puerta de la activación (`ContentView.swift:491`) |
| `.importedRows` | sí | **sí** | **no** | **no** | este ticket |
| `.handover` | sí | sí | sí | purga + sello | el Welcome y la reanudación del arm |

Cuesta reescribir cuatro aserciones de tres suites que pinnean la firma literal
(`FullModeActivationFlowLogicTests:595-599`, `WelcomePrivateICloudGateTests:1152`,
`HandoverGroupsDomainTests:469`, `RestoreStartFreshGateTests:197`). Se traducen 1:1 al scope, que es lo
que de verdad importaba en cada una, y se verifica con mutantes que siguen pudiendo fallar.

### D4 · El envoltorio del borrado RE-MIDE las señales, no las baja a `false`

`hasExistingData` cuenta también grupos y bridgeadas (`ContentView.swift:143-150`), y aquí los grupos
**siguen**: ponerlo a `false` sería mentir. Se recalculan las dos con su fetch vivo
(`checkHasExistingData()` / `checkHasPersonalData()`), que además es la lección del hallazgo nº1 de la
review del hermano. Y la gracia del wipe remoto se cancela **antes** de borrar: `wipeAllUserData` guarda
por lotes, y un `hasPersonalData` cayendo con la gracia viva levanta el alert de wipe remoto, que colgando
del anchor de `ContentView` **desmonta la sheet de la activación**.

### D5 · Lo que queda FUERA, y con ticket

- **El arm huérfano que sobrevive a la activación.** Si la persona cancela en `.restore`
  (`cancelEffect == .keepPending`, no deshace nada) con el arm puesto y más tarde `hasPrivateSession` pasa
  a `true` por el iCloud-KV de **otro** dispositivo, `runLateICloudMirrorCheck` reanuda a ciegas con el
  scope `.handover` — o sea, con preferencias y purga de Grupos. **Ya existe hoy** con `.privateGate`
  (que también arma), así que no lo introduce este PR; pero lo vuelve más alcanzable. Ticket propio.
- **Las preferencias derivadas de datos borrados que se quedan** (2.3A): `accountsSortOrderNames`,
  `transactionsSavedCount`, `processedInboxDraftSignatures`, `secondaryCurrencies` y compañía. Cosméticas
  o inertes, y 2.3A dice que se quedan.
- **El dominio de Grupos** (2.2A) y el **wipe de producción**, intactos.
