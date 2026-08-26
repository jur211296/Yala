---
id: welcome-copy-blames-owner
status: in-progress
created: 2026-08-12
updated: 2026-08-26
source: YalaWiki/Bugs/qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos.md
---

> Sync 18 ago (Iris, Mac SSOT). Cola A A1 READY Mini 17 ago. Caso 2 = cola C, no corrida. No rename.


# «Este dispositivo tiene datos de otra cuenta» — dicho a la dueña de los datos

## El síntoma, en lenguaje de usuario

Llevo tiempo usando Yala en modo privado. Salgo de la app y, desde el Welcome, tapeo **«Vengo por un
grupo → Crear mi primer grupo»**. Yala me responde:

> **Este dispositivo tiene datos de otra cuenta**
> Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar
> cuando quiera.

Los datos son **míos**. No estoy conectando ninguna cuenta: estoy intentando crear un grupo.

## Lo medido

`GroupsOrganizerGateLogic.decide` (`:78-85`) devuelve `.blockedForeignData` en cuanto
`checkHasExistingData()` da `true`, y `WelcomeGroupsGateView.swift:75-83` pinta el copy **prestado del
guard de sign-in** (`welcome.cloud.blocked*`).

**El bloqueo es deliberado y correcto**: el docblock del gate nombra literalmente la ventana que protege
—«la ventana M1: Welcome visible tras un `.privateReset` con el corpus del dueño vivo»— porque la rama
reusa `GroupsSignInView`, que no consulta el guard cross-cuenta. Lo que está mal **no es bloquear, es lo
que se dice al bloquear**: el texto describe una acción que la persona no está haciendo y le atribuye sus
propios datos a otro dueño.

Los otros dos términos del mismo gate sí tienen copy propio: `blockedChannelOff` («ahora mismo no puedo
abrirte grupos») y `blockedSecondarySession` (`welcome.groups.secondary*`, añadido en C3 con este mismo
criterio escrito: *«el hecho es distinto —"estás de visita", no "hay datos de otro humano"— y la salida
también»*). El tercero se quedó sin la suya.

## Por qué pasa: el detector no puede distinguir de quién son los datos

`checkHasExistingData` (`ContentView.swift:1086`) cuenta cuentas, categorías, grupos y filas puenteadas
sobre el store montado. Responde «hay datos», no «hay datos de otro». La prueba de propiedad que sí
existe —`CloudClaimActionStore`— **no se consulta en esta puerta**, y además vive en `UserDefaults` y
desaparece con la reinstalación.

## El fix

Copy propio para `blockedForeignData` en la puerta del organizador, que diga el hecho real: **en este
dispositivo ya hay datos, y crear un grupo aquí exigiría una cuenta**. Con salida honesta (qué puede
hacer: entrar con su cuenta, o crear el grupo desde la app ya configurada).

Alternativa mayor, si se quiere afinar: consultar la prueba de propiedad y separar «datos míos» de «datos
de otro humano» — dos hechos distintos que hoy comparten pantalla. Cuesta más y hay que decidir qué pasa
cuando la prueba no existe (reinstalación), que es justo el caso que hoy falla abierto.

## Un segundo caso del mismo copy, en otro recorrido

El mismo texto le sale al **dueño que vuelve** si restaura de iCloud y luego toca «atrás» para entrar por
la card de la cuenta: `hasLocalDataNow` ya devuelve `true` por el import en curso y no hay claim que
reclame esas filas ⇒ `.blockedForeignData` (`CrossAccountEntryGuardLogic.swift:53-56`,
`WelcomeCloudSignInView.swift:709-713`). **Cadena derivada del código, NO reproducida** — y solo
alcanzable para quien migró, no para un born-cloud.

## Criterio de hecho

- Las tres razones de la puerta con copy distinto y verificable por l10n (hoy dos de tres).
- Un test de la tabla de decisión que asocie cada razón a SU key, para que no se vuelvan a prestar.

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — la rama que sí necesita puerta y no la tiene
- [[welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo]]

## Implementación

**2026-08-12 · `c14fbfc1`** (branch `2.0.5`). Coordenadas re-medidas: `GroupsOrganizerGateLogic.decide`
(hoy `:78-85`, tres términos en el orden que el ticket describe) y `WelcomeGroupsGateView.swift:75-83`
**exactas**.

### Qué cambia

| Archivo | Qué |
|---|---|
| `Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift` | La rama `.blockedForeignData` pinta copy propio, con icono propio (`square.stack.3d.up.slash` en vez del `lock.shield` del guard de sign-in). El `identifier` NO cambia (`welcome_groups_gate_foreign_data`), así que el XCUITest que lo busca sigue valiendo |
| `Yala/Utils/L10n.swift` + 16 `.strings` | `welcome.groups.existingDataTitle` / `existingDataBody` |
| `YalaTests/Groups/GroupsOrganizerBranchTests.swift` | `eachBlockReasonHasItsOwnCopy` en el suite de source-scan que ya existía |

### Decisiones

1. **El copy nombra el hecho que el detector puede sostener**, no la propiedad de los datos.
   `checkHasExistingData` cuenta filas: dice «hay datos», nunca «hay datos de otro». Por eso el texto
   habla de lo que pasaría (conectar una cuenta encima) y no de quién es dueño de qué.
2. **No se implementa la alternativa mayor** (consultar `CloudClaimActionStore` para separar «datos
   míos» de «datos de otro humano»). Sigue abierta y es decisión de producto — ver la pregunta.
3. **El escáner es por CONTENIDO, no por conteo de casos.** Lo que hay que impedir es que dos ramas
   compartan key; que existan tres ramas ya lo cubre la tabla de `Gate.decide`.
4. **`welcome.cloud.blocked*` se conserva**: `WelcomeCloudSignInView:252` es su caso legítimo, donde
   la persona sí está conectando una cuenta. Verificado que no queda huérfano.

### Gate

Build `Yala` ✓ · `Yala Dev` ✓ · unit 21/21 en 2 suites (incl. `LocalizationParityTests`) · XCUITest
6/6 (`SecondarySessionGateUITests`, `OnboardingFlowUITests`) · índice OK.

### Nota de método

La primera corrida del pin salió **`Executed 0 tests` con exit 0**: el filtro
`-only-testing:YalaTests/GroupsOrganizerBranchTests` usa el nombre del FICHERO y el suite se llama
`GroupsOrganizerWiringTests`. Es el modo de fallo que `.claude/rules/testing.md` describe — verde que
no ejecutó nada. Se detectó porque el gate exige leer la línea `Test run with N tests`.

## Pregunta abierta (§«Un segundo caso del mismo copy»)

El ticket describe un segundo camino: el **dueño que vuelve**, restaura de iCloud y toca «atrás» para
entrar por la card de la cuenta — `hasLocalDataNow` ya da `true` por el import en curso, no hay claim
que reclame esas filas ⇒ `.blockedForeignData` en `CrossAccountEntryGuardLogic`.

**Re-medido**: la cadena existe (`CrossAccountEntryGuardLogic.decide` cierra con
`return .blockedForeignData` tras `hasLocalData && !sameAccountClaimExists`), y ahí el copy
`welcome.cloud.blocked*` **es el correcto para el hecho**: en esa pantalla la persona SÍ está
conectando una cuenta. Lo que falla no es el texto sino el veredicto: el guard clasifica como ajenos
unos datos que acaba de bajar el propio dueño.

**La pregunta**: ¿se ataca ese caso, y con qué criterio? Las opciones que veo:

- (a) **Que el guard sepa que hay un import en curso** y no cuente esas filas como corpus preexistente
  — es el fix más ajustado al caso, pero necesita una señal de «estas filas las estoy bajando yo
  ahora» que hoy no se consulta ahí.
- (b) **Consultar `CloudClaimActionStore`** (la prueba de propiedad) y separar «datos míos» de «datos
  de otro humano». Es la alternativa mayor del ticket. Hay que decidir **qué pasa cuando la prueba no
  existe** —vive en `UserDefaults` y desaparece con la reinstalación—, que es justo el caso que hoy
  falla abierto.
- (c) **Dejarlo**: la cadena está derivada del código y **NO reproducida**, y solo alcanza a quien
  migró (no a un born-cloud).

No lo he tocado porque las tres cambian el VEREDICTO de un guard de frontera de cuenta, no un texto,
y equivocarse ahí abre la puerta que el guard existe para cerrar.


---

# Decisión del owner (2026-08-13) · el segundo caso

**Opción (a): que el guard sepa que hay una restauración en curso**, con la señal ACOTADA. Más una
mejora de copy que no depende de esa decisión y se puede hacer antes.

## Lo que hay que arreglar, en lenguaje de usuario

Cambias de móvil o reinstalas. Entras por «Restaurar desde iCloud» y, **mientras tus datos están
bajando**, tocas «atrás» y entras por la card de tu cuenta. Yala te bloquea la entrada a tu propia
cuenta diciéndote que este dispositivo tiene datos **de otra cuenta** — que son los tuyos, que acabas
de bajar tú— y te ofrece una salida absurda: «su dueño puede volver a entrar cuando quiera».

## El criterio, y por qué NO es un cambio de copy

Aquí el texto **es correcto para el hecho**: en esa pantalla sí estás conectando una cuenta. Lo que
falla es el VEREDICTO — `CrossAccountEntryGuardLogic` clasifica como ajenas unas filas que el propio
dueño acaba de bajar. Maquillar el copy taparía una decisión equivocada.

## Las dos piezas

**1 · La señal acotada (el fix).** No vale un «hay import en curso» genérico: tiene que ser «esta
sesión pidió restaurar de iCloud y ese import no ha terminado», que es un estado que la propia app
arma. Si la señal se enciende cuando no debe, se abre exactamente la puerta que el guard existe para
cerrar (alguien conectando su cuenta encima de los datos de otra persona) ⇒ **el sesgo del fix tiene
que ser fail-closed**: ante la duda, bloquear.

**Por qué NO la alternativa (b)** —consultar `CloudClaimActionStore`, la prueba de propiedad—: esa
prueba vive en `UserDefaults` y **desaparece con la reinstalación**, que es justo el escenario que
falla. En el caso roto la prueba no existe, así que «sin prueba = bloqueo» no arregla nada y «sin
prueba = paso» desarma el guard.

**2 · La salida honesta (independiente, y barata).** Aunque el veredicto siga igual, esa pantalla
puede dejar de ser un callejón: decir «si estos datos son tuyos, espera a que termine la restauración»
y ofrecer el botón que devuelve a la card correcta. Se puede hacer sin tocar el guard.

## Lo que sigue sin estar medido (y hay que medir al abrirlo)

- La cadena está **derivada del código, NO reproducida**. Antes de escribir el fix, reproducirla:
  restaurar de iCloud y tocar «atrás» con el import a medias.
- Solo alcanza a quien **migró**, no a un born-cloud.

---

# Sesión 2026-08-13 · re-medición y las dos piezas

## Re-medición de las coordenadas (una envejeció)

| Ticket decía | Árbol de hoy (`83c4e22c`) |
|---|---|
| `CrossAccountEntryGuardLogic.swift:53-56` | **exacta** — `guard hasLocalData` en `:53`, `return .blockedForeignData` en `:56` |
| `WelcomeCloudSignInView.swift:709-713` | **exacta** — la llamada a `decide(` con sus cuatro argumentos |
| `checkHasExistingData` (`ContentView.swift:1086`) | **`:1100`** — 14 líneas más abajo |

## La cadena: CONFIRMADA eslabón a eslabón, y NO reproducible desde aquí

Los siete eslabones existen y encajan; lo que no existe es forma de ejercitarlos sin un device:

1. Elegir «Restaurar desde iCloud» (`WelcomeExistingChooserView` → `.restoreICloud`). Con el mount
   neutro esto **relanza la app** (`WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud) == true`)
   y el destino sobrevive en `WelcomePendingDestinationStore` ⇒ el relanzamiento **no rompe la cadena**,
   solo la mueve de proceso. Era la primera vía por la que podía haberse caído y no se cae.
2. El import de CloudKit puebla el store personal (`RestoreProgressView` cuenta filas EN VIVO
   mientras baja — su `liveCounts` es literalmente eso).
3. El «atrás» está disponible **durante** `.searching`: el `ToolbarItem` de `WelcomeRestoreView:71-75`
   no está gateado por estado. Sale a `.chooser`.
4. `.chooser` → «Ya tengo una cuenta» → `.existingChooser` → card de cuenta nube. `.cloudSignIn`
   **no** requiere mirror ⇒ no hay segundo relanzamiento que interrumpa nada.
5. `GET /account/exists == true` (migró).
6. `hasLocalDataNow()` = `true` por las filas del paso 2.
7. `sameAccountClaimExists` = `false`: `CloudClaimActionStore` vive en `UserDefaults.standard`
   (`:33`), que **muere con la reinstalación** — que es la mitad del escenario.

⇒ `.blockedForeignData`. **Y un caso que el ticket no nombraba**: con la sesión secundaria ENCENDIDA
(staging y `Yala Dev` al 100 %) la misma celda da `.proceedSecondarySession` ⇒ el dueño entraría
**como visita en su propio teléfono**. Es peor que el bloqueo y sale por la misma puerta.

**Por qué no se reproduce, y no es una excusa: son tres bloqueos independientes.** (a) la fase exige
un sign-in REAL con SIWA/Google y **el simulador no firma** —lo dice el propio código en
`WelcomeCloudSignInView:254-260`, escrito al declarar que esa fase no tiene XCUITest—; (b) exige que
el backend responda `exists == true`; (c) exige una cuenta iCloud CON datos para que haya import.
Y aunque se juntaran, un build de Xcode contra producción muere antes por AAGUID
(`.claude/rules/gateway-attest.md`). ⇒ **el e2e es device-QA del owner. Lo que sí está en el repo es
la decisión, y ahí sí hay pin.**

## Pieza 2 — la salida honesta · `6812941e` · HECHA

| Archivo | Qué |
|---|---|
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | la rama `.blockedForeignData` pasa de un `messageContent` suelto a un `VStack` con hint + `YalaPrimaryButton` de vuelta (`welcome_cloud_blocked_back`) |
| `Yala/Utils/L10n.swift` + 16 `.strings` | `welcome.cloud.blockedRestoreHint` · `welcome.cloud.blockedBack` |
| `YalaTests/CrossAccountEntryGuardLogicTests.swift` | suite `WelcomeCloudBlockedExitTests` (source-scan) |

**Decisiones.** (1) El copy NO se toca: para el hecho dominante —datos de otro humano— es correcto,
y el ticket ya lo dice. Lo que se añade es el SEGUNDO mundo de la misma pantalla, porque el detector
no puede separarlos: `checkHasExistingData` cuenta filas, así que dice «hay datos», nunca «hay datos
de otro». (2) El botón se añade **aunque `canGoBack` ya incluya esta fase**: la flecha de la toolbar
existía, y esconder la única salida de una pantalla de bloqueo en una esquina de 44 pt no es
ofrecerla. (3) El escáner corta la rama de su `case` al siguiente y no lee el fichero entero —el
`onBack()` de otra fase lo cumpliría—. (4) `pt` se alineó con `pt-BR`: son alias por contrato y la
paridad lo cazó en la primera corrida.

**Mutación:** los 2 tests nacieron ROJOS (3 aserciones) contra el árbol previo al fix.
**Gate:** build ×2 ✓ · unit 5818/565 suites ✓ · XCUITest 6/6 (WelcomeChooser + OnboardingFlow) ✓ ·
índice OK.

## Pieza 1 — la señal acotada · `d3c14350` · HECHA

| Archivo | Qué |
|---|---|
| `Yala/App/Logic/ICloudRestoreInProgressLogic.swift` | **nuevo** · los dos términos de la señal |
| `Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift` | **nuevo** · el latch de sesión + el adaptador que lee `iCloudSyncService` |
| `Yala/App/Logic/CrossAccountEntryGuardLogic.swift` | `decide` gana `restoreInProgress` y el `guard` pasa a `hasLocalData, !restoreInProgress` |
| `Yala/App/Views/Onboarding/WelcomeRestoreView.swift` | enciende la señal en `startSearch`, **después** de los dos `return` |
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | el call-site del guard lee la señal viva |
| `YalaTests/…GuardLogicTests` · `…/ICloudRestoreSignalTests` | 3 celdas nuevas + 9 tests en 3 suites |

**Decisiones, con su porqué.**

1. **`restoreInProgress` SIN valor por defecto.** Un default sería `false` y cualquier puerta nueva
   heredaría el bug en silencio — la familia exacta del `attestProvider: { nil }`. Sin él lo comprueba
   el **compilador**, que es mejor red que un escáner.
2. **El término va DELANTE del `guard hasLocalData`, no como cuarta rama.** Lo que la señal corrige es
   el TÉRMINO de los datos, no el veredicto; todo lo demás del guard sigue mandando.
3. **El latch en MEMORIA.** Es el sesgo fail-closed hecho estructura: persistido, un kill a mitad del
   restore dejaría la puerta entornada en el arranque siguiente, cuando ya no hay import que la
   justifique. En memoria, ese mismo kill la cierra.
4. **No se apaga al volver atrás.** Salir de la pantalla no para el import — y «tocar atrás» ES el
   escenario. La cierra que el import ASIENTE.
5. **Un solo encendedor, y detrás de los dos `return`.** `.wiped` e `.iCloudDisabled` no importan
   nada; encender ahí abriría la ventana sin corpus que la justifique. El conteo de call-sites es lo
   que carga el peso del suite: un segundo encendedor desarma el guard entero con todo en verde.

**Mutación: 4 mutantes a exit 65.** (a) quitar el término del guard — los 2 tests del escenario
nacieron rojos contra el árbol previo, con la matriz de 16 combos y el contrapeso en verde; (b)
descablear la lectura del call-site, que cae **SOLO en el source-scan con los 8 del guard en VERDE** —
la demostración de por qué ese escáner existe; (c) mover el encendido por delante de los
early-returns; (d) el conteo de encendedores.

**Gate:** build ×2 ✓ · unit **5830** tests / 568 suites ✓ (+12 y +3 sobre el árbol previo, conteo
verificado) · XCUITest 10/10 (WelcomeChooser, OnboardingFlow, SecondarySessionGate) ✓ · índice OK.

### Corrección de la pieza 1 · `579e9d0b` · la señal no caducaba

La revisión de la sesión hermana encontró, y se **midió y confirmó**, una regresión que la pieza 1
introdujo: **la señal podía quedarse encendida toda la sesión y con ella el guard cross-cuenta
DESARMADO.**

`restoreRequestedThisSession` era un latch que no se apagaba nunca dentro del proceso, así que toda la
ventana dependía del segundo término. Y `hasCompletedFirstImport` se enciende **solo en la rama de
import EXITOSO** (`iCloudSyncService.swift:265-272`, dentro del `else if let endDate`): con un backup
ausente o un import que falla **no llega jamás** — lo dice el propio docblock de
`waitForImportQuiescence` («un store que NADA importa nunca dispara `.importEvent`»).

**Camino alcanzable:** tocar «Restaurar desde iCloud» (la búsqueda arranca ⇒ latch ON) → no hay backup
→ volver atrás → firmar con OTRA cuenta sobre un device con corpus ajeno ⇒ `.proceed` y adopt sobre
los datos del dueño. Es exactamente el incidente que el guard existe para impedir, y de paso anulaba
el enrutado a sesión secundaria.

**La lección, que es lo que vale para el yo-futuro:** el sesgo **declarado** estaba invertido respecto
al **implementado**. El docblock decía «ante la duda, `false`», y `!(A && B)` con `A` desconocido
devuelve `true`, que es ABRIR. ⇒ **un sesgo fail-closed no se declara en prosa: se comprueba
enumerando qué devuelve la función con cada término en `unknown`.** Y lo más incómodo: mi propio test
`settledImport_closesTheWindow` llevaba escrito el peligro («si la señal se quedara viva toda la
sesión, el guard quedaría desarmado») y solo probaba el camino feliz.

**El fix:** la señal pasa de interruptor a **VENTANA** (`restoreStartedAt: Date?`), y se cierra por
cuatro caminos — los dos últimos sin depender de que corra ningún callback:

1. nunca se abrió;
2. el flujo **terminó** (`noteRestoreFinished`, gane o pierda) — precisión, no red: quien toca «atrás»
   a mitad cancela ese `Task`;
3. el import asentó;
4. **caducidad**: sin ni un `.importEvent` pasada la gracia de 60 s (`hasObservedImportActivity`, la
   señal que distingue «va lento» de «no hay nada que importar») y tope duro de 600 s pase lo que pase.

`noteRestoreStarted` **no re-arma** si la ventana ya estaba abierta: el botón de reintentar la
convertiría en extensible a voluntad.

**Mutación:** los 2 tests de caducidad nacieron ROJOS contra `d3c14350`; y quitar el apagado explícito
da exit 65 **solo en el source-scan**, con los de comportamiento en verde —la caducidad los cubre
igual, solo que tarda—, que es exactamente por qué ese escáner existe.

**Gate:** build ×2 ✓ · unit **5835** / 568 suites ✓ · XCUITest 6/6 ✓ · índice OK.

### Residual DECLARADO

Quien espera a que el restore **termine del todo** y solo entonces toca «atrás» sigue viendo la
pantalla de bloqueo: la señal está apagada, y así tiene que ser —con el import asentado esas filas ya
son corpus como cualquier otro—. Para él la salida es el copy de la pieza 2, que es justo para lo que
se escribió.

### Segunda instancia del patrón: MEDIDA y NO tocada (necesita tu decisión)

`hasLocalDataNow` tiene **dos** consumidores, no uno. El otro es
`GroupsOrganizerGateLogic.decide(hasExistingData:)` — la puerta de «Crear mi primer grupo»—, que
durante una restauración bloquea por el mismo motivo y con el mismo detector.

**No lo he tocado**, y no por prudencia genérica: (a) su copy ya es honesto desde C1 y ofrece salida;
(b) ahí el bloqueo no impide entrar a ninguna cuenta, solo aplaza crear un grupo; (c) aplicarle la
señal cambia el veredicto de **otra** puerta, y eso es tuyo, no mío.

**La pregunta:** ¿la puerta de Grupos hereda la señal? A favor: es literalmente el mismo hecho mal
clasificado, y a quien está restaurando «créalo desde la app que ya usas» le suena raro porque su app
todavía no está montada. En contra: crear un grupo puede esperar noventa segundos, y cada puerta que
hereda la señal es una superficie más donde un fallo de la señal cuesta caro.

migrated from YalaWiki Bugs/qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos.md @ 1934e8ad
