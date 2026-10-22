---
id: groups-invite-on-a-mirrored-store-crosses-data
status: done
priority: high
area: "modo-nube, groups"
created: 2026-09-11
source: "mitad 2 de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` (2026-09-11): la rama de CREAR quedó cerrada; la de INVITACIÓN necesita dos piezas que ni ese ticket ni el paso 9 dejan hechas"
updated: 2026-09-16
qa-status: absorbed
qa-date: 2026-09-16
qa-notes: Absorbido por device-qa-groups-invite-neutral-return - su recorrido 2 cubre el iCloud del dueno intacto y los recorridos 1, 3 y 4 cubren AC1, AC4 y AC3. Fix 5bb3b4ea en HEAD
---

# Aceptar una invitación sobre un teléfono que ya espeja iCloud manda los gastos del invitado al iCloud del dueño

## El síntoma, en lenguaje de usuario

Presto el móvil, o lo compro de segunda mano, o simplemente entré antes por «privado» y no terminé. El
teléfono ya bajó datos de iCloud. Ahora alguien me pasa un enlace de invitación a un grupo, lo acepto y
empiezo a anotar gastos compartidos. **Esos gastos acaban en el iCloud de la otra persona**, porque el
espejo del store personal sigue adjunto y el bridge de Grupos escribe en él.

Nadie ve nada raro: no hay pantalla de error, ni aviso, ni bloqueo. Se ve en el otro dispositivo del
dueño, días después.

## Por qué no se cerró con la rama de CREAR (medido el 2026-09-11)

La mitad 2 de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` cerró «Crear mi primer grupo»:
la puerta del Welcome vuelve al neutro antes de dejar pasar. La invitación **no pasa por esa puerta** y
cubrirla exige dos piezas de infraestructura, no cableado:

1. **No hay punto de interposición con una persona delante.** Las dos entradas —el universal link
   (`AppBootstrapper.handleInviteLink`) y la card «Tengo una invitación», que empalma en el mismo método
   desde `ContentView`— convergen en `GroupBackendInviteEntryHandler.drive`, y **a ése también lo llama
   el reconciler en el trigger `.boot`** (`GroupJoinReconciler`). Interponer ahí la vuelta al neutro
   sería borrar el corpus de alguien **en el arranque y sin pantalla**, que es justo lo que el ADR
   2026-09-09 prohíbe. Hacerlo con pantalla pide un `RouterIntent` nuevo que atraviese la matriz de
   readiness (regla 3 de Presentaciones).
2. **El intent de la invitación NO sobrevive al borrado.** `PendingJoinStore` guarda una sola key,
   `"yala.groups.pendingJoins"`, que el barrido de `DataWipeService.removeUserPreferenceKeys` **no
   toca** —comprobado— pero que muere igual por la cadena `resetForSignOutWipe` → `resetAllUserPreferences`
   → `AppRouter.resetAll()` → `PendingJoinStore.clearAll()`. Sin una superficie durable nueva, el
   invitado reabre la app **sin su invitación**: el camino muerto, movido un paso más adelante.

## Lo que sí está medido a favor de tratarlo aparte

La rama de invitación **no tiene ningún término de corpus** —ni `GroupsGateLogic.nextStep`, ni
`GroupBackendInviteEntryLogic.nextStep`, ni `InviteRecoveryView`—, así que **nunca bloqueó a nadie**: el
síntoma del ticket padre (el dueño atrapado) no la toca. Lo que queda abierto es solo el cruce de datos,
y es **preexistente**: el PR de la mitad 2 no lo agrava.

## Criterios de aceptación

- [x] Enlace de invitación aceptado sobre un store con espejo → antes de entrar al grupo, el dispositivo
      vuelve al neutro (espera el export, borra lo local, iCloud intacto) y **la invitación sobrevive** al
      relanzamiento: al reabrir, la hoja «unirme» sale sola.
- [x] La vuelta al neutro **nunca** se dispara sin pantalla: el trigger `.boot` del reconciler no puede
      borrar nada por su cuenta.
- [x] Un invitado en un teléfono neutro (instalación fresca) no paga ninguna pantalla de más.
- [x] Lo que el dueño escribió y no llegó a subir no se pierde.

## Por dónde va

Reusar lo que la rama de CREAR ya dejó: `GroupsOrganizerGateLogic.decide` (con `.returnsToNeutral`), el
step `.groupsGate` del Welcome y `CloudSessionSignOut.signOut(confirmedPath: .privateSignOut, …)`. Lo que
hay que construir es (a) el encaminamiento con pantalla desde `drive`, y (b) la durabilidad del intent a
través del wipe. Para (b), la superficie mínima es una key propia one-shot con `{groupID, token}` —sin
PII— que el arranque reponga en `PendingJoinStore` **después** del boot-wipe, como
`WelcomePendingDestinationStore` hace con el destino.

## Cómo se prueba

- Unit: la decisión y el cableado del encaminamiento; la durabilidad del intent a través de un wipe
  simulado.
- Device-QA (CloudKit): que el iCloud del dueño no reciba nada. Dos Apple IDs.

---

## Paso 0 · el árbol de decisiones, resuelto antes de escribir (2026-09-11)

Cinco decisiones. Las tres primeras salen de MEDIR el árbol y contradicen en parte lo que el propio
ticket daba por hecho.

### D1 · El término que el ticket NO nombra: «el onboarding personal no está completado»

La puerta de CREAR vive DENTRO del Welcome, así que por construcción solo corre con
`hasCompletedOnboarding == false`. La de INVITACIÓN corre en **cualquier** estado, y aplicar
`GroupsOrganizerGateLogic.decide` tal cual le borraría el corpus a quien tiene **sesión privada viva**
(estado C de la matriz) — que es justo lo contrario de lo que el ADR manda para esa celda:

> `C · llega una invitación (link)` → «misma regla que asociar: [I] → asociar → unirme»
> (`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`)

⇒ la vuelta al neutro se interpone **solo en A/B/G** (Welcome visible = sin sesión privada viva). En
C/D/E/F la invitación sigue su camino actual. Por eso la decisión es una lógica PROPIA
(`GroupInviteNeutralGateLogic`) y no una llamada a la del organizador.

### D2 · Aquí se PREGUNTA, al revés que en la rama CREAR

«Se informa, no se pregunta» (decisión de Jürgen en el ticket padre) se sostenía sobre un hecho que
aquí no existe: allí la persona **acaba de tapear** «Crear mi primer grupo» y la pantalla es la
respuesta a su gesto. La puerta del invitado puede llegar por `GroupJoinReconciler` en `.boot`, sin que
nadie haya tocado nada en este proceso ⇒ informar-y-borrar sería borrar sin gesto, que es lo que el ADR
2026-09-09 prohíbe. El criterio de aceptación nº 2 se cumple entonces **por construcción**, no por un
término sobre el `Source`.

### D3 · La puerta va ANTES del sign-in, no antes del join

Medido en `GroupsGateLogic.nextStep`: el orden es sign-in → consent → hoja del invitado, así que el
«sí» de la hoja llega DESPUÉS de firmar. Interponer ahí dejaría que el cierre privado —que en esa celda
ya es `.groupsOnlySignOut` / `.privateWithGroupsSignOut`— **deshiciera la sesión recién creada**, y tras
el relanzamiento el invitado repetiría sign-in y consent. Antes del switch no se escribe nada que el
cierre vaya a tirar. Es además el molde de la rama CREAR («bloquear ANTES de pedir nombre e identidad,
y sin escribir»).

### D4 · La pantalla es el step `.groupsGate` que ya existe, con un PROPÓSITO

No una vista nueva: el motor de `WelcomeGroupsGateView` (fases, celda de cierre, `privateCopyChannel`,
espera agotada, bloqueo por grupos sin subir) es exactamente el que hace falta, y duplicarlo crearía dos
verdades sobre el mismo borrado. El propósito decide **dos cosas**: qué pinta la entrada
(`.createGroup` informa y arranca · `.acceptInvite` pregunta) y a dónde va el `.proceed`.

### D5 · La durabilidad: destino pendiente + key one-shot, las dos

`hasShownWelcomeChooser` **sí** está en `DataWipeService.removeUserPreferenceKeys` (medido, línea 781),
así que tras el relanzamiento el Welcome vuelve al hero y el intent quedaría esperando detrás de él.
Por eso hacen falta las dos piezas: `WelcomeMirrorRelaunchLogic.Destination.groupsInvite` (añadido **al
final** del enum — su orden se ve fuera) para retomar la puerta, y `GroupInviteResumeStore` con
`{groupID, token}` sin PII para que el intent sobreviva a `AppRouter.resetAll()`.

### Ficheros

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Logic/GroupInviteNeutralGateLogic.swift` | **nuevo** · la decisión pura + el almacén one-shot del intent |
| `Yala/App/Services/GroupBackendInviteEntryHandler.swift` | el término nuevo en `drive`, antes del switch |
| `Yala/App/Models/RouterIntent.swift` | `case presentGroupsInviteNeutralGate(pendingJoin:)` |
| `Yala/App/ContentView.swift` | su consumidor + el destino pendiente `.groupsInvite` |
| `Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift` | `Destination.groupsInvite` (al final) |
| `Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift` | `Purpose` + la pantalla que pregunta |
| `Yala/App/Views/Onboarding/WelcomeFlowContainer.swift` | reenvía el propósito y el `.proceed` del invitado |
| `Yala/Utils/SwiftDataConfiguration.swift` | repone el intent DESPUÉS de `resetPrefs()` |
| `Yala/Utils/L10n.swift` + 16 `Localizable.strings` | 3 keys del aviso que pregunta |

---

## Implementación (2026-09-11)

### Qué cambia para quien usa la app

Aceptar una invitación en un teléfono que ya guarda datos de otra persona —prestado, de segunda mano, o
con un onboarding abandonado a medias— ya no manda tus gastos del grupo al iCloud de esa persona. Antes
de dejarte entrar, Yala te lo cuenta y te ofrece dejar el teléfono en blanco: espera a que lo último
suba a iCloud, borra lo de aquí, deja iCloud intacto y se reinicia. **Al reabrir, la hoja «Unirme al
grupo» sale sola** — la invitación cruza el borrado.

Quien llega con el teléfono limpio no ve nada de esto: ni una pantalla de más.

### Las cinco piezas

| Pieza | Qué hace |
|---|---|
| `GroupInviteNeutralGateLogic` | la decisión, con los DOS términos que la separan de la puerta del organizador |
| el desvío en `GroupBackendInviteEntryHandler.drive` | corta ANTES del sign-in y submitea la pantalla; no escribe nada |
| `RouterIntent.presentGroupsInviteNeutralGate` | la lleva al step `.groupsGate` del Welcome, con propósito de invitado |
| `WelcomeGroupsGateView.Purpose` | el mismo motor de borrado, con dos entradas y dos salidas |
| `GroupInviteResumeStore` | el sobre `{groupID, token}` que cruza el wipe, sin PII y con TTL de 7 días |

### Lo que costó la review adversarial (tres lentes + la regla de área)

**Veintitrés hallazgos, todos MÍOS, y cuatro de ellos dejaban el arreglo sin funcionar o peor que antes:**

1. **La pantalla no se renderizaba en su propio estado objetivo.** El drain baja `showWelcomeFlow` y el
   `case` lo sube en la MISMA vuelta síncrona: SwiftUI no renderiza entre dos escrituras de `@State`, así
   que el cover no se desmontaba y el `initialStep` se ignoraba. El invitado se quedaba en el Hero con su
   invitación viva. Lo arregla `.onChange(of: initialStep)` en el container — y **arregla de paso un
   agujero general**: hasta hoy, cualquier productor que escribiera el step con el cover montado era
   ignorado en silencio.
2. **El propósito era pegajoso.** Vivía en un `@State` al lado del step y **tres de los cinco productores
   no lo escribían**, contra lo que afirmaba mi propio comentario. Quien volvía atrás en una invitación y
   tapeaba «Crear mi primer grupo» acababa **uniéndose al grupo de otro**. Ahora viaja DENTRO del case
   (`.groupsGate(purpose:)`) y lo obliga el compilador.
3. **La reposición del sobre no era idempotente.** Consumía la key, y el boot-hook declara que una
   re-entrada tras un kill re-ejecuta el borrado ENTERO — incluido el `resetPrefs()` que vacía el intent.
   El destructor se re-ejecutaba y el reparador no: la invitación moría en la segunda pasada. La key se
   retira ahora pegada al desarme, que es donde el hook pone todo lo one-shot.
4. **El sobre quedaba huérfano si el borrado abortaba**, sin TTL y sin nadie que lo retirara, y un cierre
   de sesión posterior —de OTRA persona— lo repondría **con el tap armado**: una solicitud de entrada a
   un grupo viejo bajo una cuenta que nunca la pidió.

Y tres decisiones de producto que la review obligó a tomar:

- **El invitado NO puede descartar lo que el dueño no llegó a subir.** «Continuar igualmente» tras
  agotarse la espera del export existe para el dueño de los datos; por esta rama lo tocaría otra persona.
  Sin este corte, el criterio nº 4 dependía de a quién le dejaran el móvil.
- **Sin copia en iCloud se pide un segundo gesto**, igual que en la rama del organizador: colapsarlo en
  uno era ahorrarse justo la pantalla que protege el caso irreversible.
- **El sobre se escribe en el GESTO y no al armar**: en el camino del swap in-process la jerarquía se
  desmonta en la misma vuelta del arm, así que escribirlo en el callback lo dejaba fuera de la ventana.

### Verificado

- **Unit 6954 / 714 suites en verde** (baseline `2.1`: 6923 / 710; +31 casos en 4 suites nuevas).
- Los dos builds con `clean` y **cero warnings nuevos** (14 = 14 contra un árbol limpio de `2.1`).
- XCUITest de las áreas tocadas: `GroupInviteOnboardingUITests` (5), `OnboardingPurposeStepUITests` (2),
  `SessionExitsPerCellUITests`, `OnboardingFlowUITests`, `WelcomeFreshStartAlertUITests` en verde.
  **Siete rojos son PREEXISTENTES** y están bisecados contra un worktree limpio de `2.1` — ticket propio
  (`welcome-chooser-uitests-cannot-reach-the-chooser`, `high`).

  > **Corrección del 2026-09-11: esos siete rojos no eran preexistentes ni eran rojos.** Se midieron
  > 11/11 verdes en `2.1` de hoy, 11/11 en `1a9cbb83` —la revisión contra la que se «bisecó»— y los
  > once verdes en la nocturna de CI del 11-sep sobre los 149 casos, con las dos suites byte-idénticas
  > entre ambas revisiones. El rojo venía de la máquina: esta corrida y la de la bisección compartían
  > el único simulador, y la que llega segunda **instala su `.app` sobre el mismo bundle id**, así que
  > la primera acaba tapeando un binario ajeno y falla con línea de aserto. El ticket quedó
  > `discarded` con la medición; la contención vive en `diez-worktrees-comparten-un-simulador`.

### Lo que queda fuera y por qué

- **Device-QA (CloudKit): NO es simulable.** Que el iCloud del dueño no reciba nada pide dos Apple IDs y
  un tercer dispositivo testigo. Guion en `tickets/qa/device-qa-groups-invite-neutral-return.md`.
- Un residual con ticket: cuando la celda de cierre de este dispositivo no puede borrar por archivos, la
  pantalla dice «ahora no se puede» y la invitación se queda sin superficie
  (`groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe`).
- El sobre repuesto no lleva `legacyMemberKey` ni la marca del grupo: no son reconstruibles pre-mount y
  ninguno hace falta tras el wipe (las filas del grupo se fueron con los archivos).

## QA · 2026-09-16 — cerrado como absorbido

Lo único pendiente era el device-QA con CloudKit, y la propia implementación lo mandó entero a
`device-qa-groups-invite-neutral-return` (:214-217). Allí, el **recorrido 2** es literalmente esta prueba
(el iCloud del dueño no recibe nada), y los recorridos 1, 3 y 4 cubren los criterios 1, 4 y 3. El 2 va por
construcción y por unit. Ese ticket sigue en la cola de device.
