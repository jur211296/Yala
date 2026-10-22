---
id: onboarding-purpose-drops-groups-card
status: done
priority: medium
area: onboarding
created: 2026-09-09
updated: 2026-09-10
implementation_date: 2026-09-10
source: "ADR 2026-09-09 «Sesiones — dos ejes» §7"
---

# La card «Grupos» del paso *propósito* del onboarding personal sobra: solo-grupos es una sesión, no un propósito

## Qué pasa

En el onboarding personal, el paso *«¿Qué te gustaría hacer?»* ofrece tres cards: control, gastos y
**grupos**. Elegir «grupos» convierte a la persona en solo-grupos desde DENTRO del onboarding privado
(`OnboardingPurposeCard.groups` → `OnboardingUsageMode.groupsOnly`,
`Yala/App/Logic/OnboardingPurposeSelectionLogic.swift`; el paso es `OnboardingStep.purpose`,
`Yala/App/Logic/OnboardingStepPlan.swift`).

En el modelo del ADR, «solo grupos» es una **celda** (sin sesión privada + nube solo grupos), no un
propósito de la sesión privada: quien llega a [P] ya eligió tener finanzas personales. La puerta a
solo-grupos es «Vengo por un grupo» en el Welcome, y solo ella.

## Lo que hay que hacer

- [x] Retirar la card `groups` del paso *propósito* (`OnboardingPurposeCard` pasa a dos casos, o la
      card se oculta y el caso se marca deprecated hasta `shell-derives-from-two-session-axes`).
- [x] `OnboardingUsageMode.groupsOnly` deja de ser alcanzable desde el onboarding; revisar
      `OnboardingStepPlan.skippedSteps` y `OnboardingNextEnablement` para que no queden ramas muertas
      que dependan de él.
- [x] Textos: retirar los strings de esa card en los 16 `.strings` (`onboarding.purpose.groups*` o el
      nombre que tengan; grep antes) — o dejarlos si `l10n-check` los sigue exigiendo por paridad.
- [x] Tests: `OnboardingPurposeSelectionLogicTests` y los XCUITest del onboarding que tapean la card.

## Criterios de aceptación

- [x] El paso *propósito* muestra dos cards y `groupsOnly` no se puede elegir desde [P]. — el caso ya no
      existe en el enum; lo fijan `OnboardingPurposeStepUITests` (cuenta las cards) y el pin de
      `OnboardingPurposeSelectionLogicTests`.
- [x] «Vengo por un grupo» sigue llevando a solo-grupos. — `WelcomeChooserUITests.testGroupsOrganizer_createCardWalksToTheGroupForm`
      en verde sobre el árbol final; la cadena tiene UNA entrada (`organizerBranchHasOneEntry`).
- [x] `l10n-check` en verde. — paridad de los 16 locales y cero literales nuevos sin localizar.

## Fuera de alcance

El resto del rediseño. Este ticket es pequeño a propósito para que pueda ir en cualquier momento.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

### Lo medido antes de decidir (2026-09-09, en este árbol)

- **`OnboardingUsageMode.groupsOnly` NO se persiste**: es `@State private var selectedUsageMode`
  (`OnboardingView.swift:39`), estado efímero del onboarding. Borrar el case **no rompe a ningún
  usuario** ni exige migración de preferencias.
- **La card ya está gateada** por `OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard(isInitialFlow:
  storageMode:)` (`OnboardingView.swift:566-569`): hoy ya desaparece en modo nube y en la reutilización
  de `FullModeActivation`.
- **`OnboardingUsageMode` y `UsageFocus` son DOS enums distintos con un case homónimo.** El docblock de
  `OnboardingGroupsPurposeGateLogic:15` dice que «las otras escrituras de ese valor son
  `GroupsRetentionView:64`» y **eso es falso**: esa vista escribe `appPreferences.usageFocus =
  .groupsOnly`, que es `UsageFocus` (`Yala/App/Models/UsageFocus.swift:22`, persistido en
  `AppPreferences:403`). ⇒ **borrar `OnboardingUsageMode.groupsOnly` no rompe `GroupsRetentionView`.**
  Corrige ese docblock de paso.

### Las decisiones

- **Se borra el caso `groupsOnly` de `OnboardingUsageMode` del todo**, y con él la card del paso
  *propósito*. Que el compilador señale cada uso; no dejar ramas muertas ni un caso «deprecated».
  Ojo a `OnboardingPurposeSelectionLogic.selectedCard(for:)`, que es **total** por invariante: al
  quitar el caso, sigue devolviendo una card para todos los modos restantes.
- **`OnboardingGroupsPurposeGateLogic` se borra con sus tests**, si al medirlo no le quedan llamadores
  vivos. Su docblock avisa de que ese gate **sí bloqueaba en producción**, así que compruébalo antes de
  borrar, no después.
- **`GroupsRetentionView` NO es de este ticket**: escribe el otro enum. Se mira en el **ticket 12**, que
  ya barre las 19 vistas y los tres flags de modo. Anótalo allí como hallazgo de esta pasada.
- **Los textos de la card se retiran de los 16 `.strings`**, con `l10n-check` en verde.

## Implementación (2026-09-10)

**Para el usuario:** el paso «¿Qué te gustaría hacer?» del onboarding personal ofrece dos opciones —«Llevar
el control de mi dinero» y «Solo anotar gastos»— y ya no «Dividir gastos con amigos». A una sesión
solo-grupos se entra por «Vengo por un grupo» en el Welcome, que no cambia.

**Commit:** `403d3057` (rama `encargo/2026-09-10-onboarding-purpose-drops-groups-card`). Las
decisiones de alcance están en el Paso 0 del encargo (`encargos/lanzados/2026-09-10-onboarding-purpose-drops-groups-card.md`).

Qué cambió, por pieza:

- **El paso Propósito** (`OnboardingView`): dos cards; fuera la card, su aviso de «activa iCloud» y las ramas
  solo-grupos de los pasos de moneda y resumen.
- **El modo**: `OnboardingUsageMode.groupsOnly` y `OnboardingPurposeCard.groups` borrados. No se persistían
  (`@State`), así que no hubo migración.
- **Su gate**: `OnboardingGroupsPurposeGateLogic` borrado con sus dos suites. Medido antes: sus dos únicos
  llamadores eran las dos líneas de la card.
- **La puerta B entera** (decisión D1 del Paso 0): la cesión de la card a la cadena de Grupos
  (`onGroupsOnlyComplete`, `startGroupsOnlyBranch`, `pendingGroupsOnlyPayload`, `GroupsOnlyOnboardingPayload`,
  `GroupsGateLogic.Entry.onboardingCard` y el parámetro `explicitCurrencyCode` del alta). La puerta A es
  byte-idéntica: con el payload nulo ya tomaba estas ramas.
- **`OnboardingStepPlan` y `OnboardingNextEnablement`** pierden `groupsOnly` y sus ramas.
- **Textos**: 7 keys de los 16 `.strings`, con sus accessors de `L10n`.
- **Tests**: selección con 3 modos y 2 cards, más un pin del tipo (`allCases`) y un source-scan que cuenta
  las cards del cuerpo de `purposeStep`; `GroupsGateLogicTests` a 3 puertas y 48 celdas, con el alta en UN
  call-site y la rama del organizador con UNA entrada (red nueva); el XCUITest de la card se reescribió como
  `OnboardingPurposeStepUITests`, que además cuenta las cards; se borró el caso de secundaria que afirmaba
  que la card no se pintaba.

**Lo que costó ver, y por qué:** el ticket decía «pequeño a propósito», pero borrar el caso del enum sin dejar
ramas muertas llegaba hasta la cadena de alta de Grupos: la card no terminaba en el onboarding, cedía a la
misma cadena que «Vengo por un grupo». La review adversarial (una lente) no encontró nada roto en esa puerta,
y sí siete cosas del cambio: un validador de documentación que las keys retiradas rompían, dos tests que
prometían más de lo que cazaban, un comentario que prometía una red inexistente —que ahora existe— y
docblocks que seguían describiendo la card como viva.

## Verificación

Todo sobre el árbol final, sin mutantes:

- **Build:** `Yala` y `Yala Dev` en verde. Cero warnings nuevos; el único en un fichero tocado
  (`ContentView.swift:1777`) es de julio y solo se desplazó una línea.
- **Unit:** la suite **entera**, como pide el runbook cuando un paso borra código. 6751 tests en 689 suites,
  0 fallos.
- **XCUITest:** la suite **entera**, en 11 lotes. 61 de 61 clases, 136 casos, 0 fallos, 0 reinicios.
- **l10n:** paridad en verde. Las 16 `.strings` pierden las mismas 7 keys, y `es`/`pt` siguen idénticos a
  `es-419`/`pt-BR`.
- **Mutantes:** cada red nueva o cambiada cae donde tiene que caer:
  - una tercera card en la vista;
  - `OnboardingPurposeCard.groups` de vuelta;
  - un segundo call-site del alta;
  - una segunda entrada a la rama del organizador;
  - una card con otro prefijo de id.
- **Sin device-QA:** nada depende de CloudKit ni de una sesión real.

## Hallazgos que salieron de camino

- `flows-atlas-predates-session-redesign` (nuevo, low): el Atlas de flujos de Modo Nube sigue enseñando la card
  y su validador pasa de 4 a 13 fallos.
- En `shell-derives-from-two-session-axes` (ticket 12): el guard de sesión secundaria de
  `advanceGroupsOrganizerFlow` ya solo es defensa en profundidad; cae con M1.
