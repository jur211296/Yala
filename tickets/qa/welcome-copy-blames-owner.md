---
id: welcome-copy-blames-owner
status: qa
created: 2026-08-12
updated: 2026-09-02
source: YalaWiki/Bugs/qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos.md
---

# «Este dispositivo tiene datos de otra cuenta» — dicho a la dueña de los datos

**El síntoma titular está ARREGLADO** (2026-08-12, `c14fbfc1`). La puerta de «Crear mi primer grupo»
ya no le dice a la dueña de los datos que son de otra cuenta: tiene copy propio, traducido en los 16
`.strings`, y una red en simulador anclada a su identifier.

**Lo que mantiene este ticket abierto es UNA pregunta, y es tuya.** Va justo debajo, sin enterrar.
Después está el residual —que hoy es más ancho de lo que este ticket declaraba— y luego el historial.

---

## ⛔ La pregunta para Jürgen — es lo único que bloquea

### El caso, en lenguaje de usuario

Cambio de móvil. Entro por «Restaurar desde iCloud» y, **mientras mis datos están bajando**, voy a
«Vengo por un grupo → Crear mi primer grupo». Yala me para y me dice:

> **Aquí ya hay datos guardados**
> Crear un grupo desde esta pantalla conectaría una cuenta encima de ellos, y preferimos no
> mezclarlos. Vuelve atrás: siguen intactos. Si son tuyos, crea el grupo desde la app que ya usas.

La app que ya uso **es ésta**. Se está montando delante de mí. La salida que me ofrece no existe.

### La pregunta (sí o no)

**¿La puerta de Grupos hereda la señal de «hay una restauración en curso»?**

El guard del sign-in de nube ya la tiene desde el 2026-08-13. Esta puerta no, y bloquea por el mismo
motivo, con el mismo detector.

- **A favor:** es literalmente el mismo hecho mal clasificado — el detector cuenta filas y no puede
  saber que las está bajando el propio dueño. Y mientras se restaura, la salida que ofrece el copy
  («crea el grupo desde la app que ya usas») es imposible de seguir.
- **En contra:** aquí el bloqueo no impide entrar a ninguna cuenta, solo aplaza crear un grupo, y eso
  puede esperar a que termine la restauración. Y cada puerta que hereda la señal es una superficie
  más donde un fallo de la señal sale caro — ya salió caro una vez (`579e9d0b`, en el historial).

No se ha tocado porque cambia el **veredicto** de una puerta, no un texto.

### Evidencia, medida el 2026-09-02 sobre `553b91c9`

- `GroupsOrganizerGateLogic.decide` toma **tres** términos y ninguno es la señal:
  `Yala/App/Logic/GroupsOrganizerGateLogic.swift:78-85` — firma en `:78-80`, los tres `guard` en
  `:81-83`.
- Su call-site le pasa el detector crudo: `WelcomeGroupsGateView.swift:163-169`, con
  `hasExistingData: hasLocalDataNow()` en `:169`.
- El otro consumidor del **mismo** detector sí la recibe: `CrossAccountEntryGuardLogic.decide` toma
  `restoreInProgress` (firma `:52-58`) y lo consume en `:66`.
- El detector es el mismo objeto en ambos casos: `ContentView.checkHasExistingData()` (`:1100`),
  cableado al Welcome como `hasLocalDataNow: { checkHasExistingData() }` (`ContentView.swift:315`).
- El copy citado arriba es `welcome.groups.existingDataTitle` / `welcome.groups.existingDataBody`
  (`Yala/Resources/es.lproj/Localizable.strings`; presente en los 16 `.lproj`).

---

## Residual abierto — es más ancho de lo que este ticket declaraba

Hasta hoy el residual decía una sola cosa: «quien espera a que el restore termine del todo y solo
entonces toca atrás sigue viendo la pantalla de bloqueo». **Eso se queda corto por dos lados.**

### En lenguaje de usuario

Cambio de móvil, pido «Restaurar desde iCloud» y vuelvo atrás para entrar por la card de mi cuenta.
Si la ventana de «estoy restaurando» ya se cerró, Yala vuelve a leer mis propias filas como corpus de
otra persona. Y lo que pasa entonces **no es una cosa, son dos**, según un flag remoto:

- **Con la entrada secundaria APAGADA** (producción hoy): veo la pantalla de bloqueo. Es el residual
  que el ticket ya declaraba, y para eso se escribió la salida honesta de la pieza 2 — «¿Y si son
  tuyos? Si acabas de pedir una restauración desde iCloud, espera a que termine y vuelve a entrar»,
  más un botón de volver que no está escondido en la esquina.
- **Con la entrada secundaria ENCENDIDA** (staging al 100 %, y por tanto cualquier `Yala Dev` que
  apunte a staging): **no veo ningún bloqueo, y es peor.** Yala me ofrece «Entrar con tu cuenta»
  explicándome que «este dispositivo tiene datos de otra persona» —que son míos— y que entraré «en un
  espacio separado». Si acepto, entro **como visita en mi propio teléfono**: una app vacía, con mis
  datos reales al lado, en el store principal, que desde ahí no veo. La pantalla no me dice que no
  pueda entrar: me dice que la visita soy yo.

Y la ventana no se cierra solo cuando el restore «termina»: también **caduca** — 60 s sin un solo
evento de import, o 600 s pase lo que pase, aunque la bajada siga viva. Quien se aburre de un restore
lento y vuelve atrás cae exactamente en el mismo sitio.

Un consuelo, y conviene decirlo porque acota el daño: **los datos del dueño no se tocan**. La sesión
secundaria monta un store propio por archivo (`YalaModel-Secondary`) y el corpus principal ni se lee.
Lo que se rompe es el recorrido y la confianza, no las filas.

### Qué está MEDIDO y qué está INFERIDO

**Medido el 2026-09-02 (`553b91c9`):**

- El término que decide entre bloqueo y visita es el flag: `CrossAccountEntryGuardLogic.swift:66-69`
  — con `restoreInProgress == false`, `hasLocalData == true`, sin claim y `accountExists == true`, la
  celda la resuelve `secondarySessionEnabled` en `:68` (`.proceedSecondarySession`) y solo cae a
  `.blockedForeignData` (`:69`) si está apagado.
- Ese flag es `CloudSyncFlags.secondarySessionEntryAvailable` (`:315-318`), que compone la capacidad
  compilada —`true` desde el chip M2, `:296`— con el percent remoto. En `gateway/wrangler.toml`:
  staging `SECONDARY_SESSION_ROLLOUT_PERCENT = "100"` (`:56`), producción `= "0"` (`:176`).
- La rama `.proceedSecondarySession` del call-site lleva a la pantalla de confirmación:
  `WelcomeCloudSignInView.swift:747-759` (`phase = .secondaryConfirm` en `:759`), cuyo copy es
  `welcome.cloud.secondaryConfirmTitle` / `…Body` / `…Cta` — el que dice «Este dispositivo tiene datos
  de otra persona… Entrarás con tu propia cuenta en un espacio separado».
- El claim que reclamaría esas filas como suyas vive en `UserDefaults.standard`
  (`CloudClaimActionStore.swift:34`) y muere con la reinstalación, que es la mitad del escenario.
- La caducidad de la ventana: `ICloudRestoreInProgressLogic.isRestoringNow` — tope duro en `:77`,
  «el import asentó» en `:83`, «no hay nada que importar» pasada la gracia en `:93`; los valores por
  defecto (60 s y 600 s) en `:68-69`.
- El store separado de la secundaria: `SecondarySessionStore.swift` (`YalaModel-Secondary`, `:7`).

**Inferido, y NO reproducido:** que la celda se alcanza está derivado del código, eslabón a eslabón
(ya se hizo el 2026-08-13 y sigue encajando); que la pantalla se ve así es inferencia de leer el copy
y la fase. **Nadie lo ha ejercitado en un aparato**, y no por pereza: llegar ahí exige un sign-in real
con SIWA/Google —el simulador no firma, y lo dice el propio código en la rama `.blockedForeignData`
de `WelcomeCloudSignInView` (`:261-267`)—, un backend que responda `exists == true` y una cuenta
iCloud con datos que importar. **El e2e es device-QA del owner.** Hoy no se ha corrido ningún build
ni ningún test: lo de arriba es lectura del árbol.

---

## Historial

### 2026-08-12 · el copy de la puerta de Grupos · `c14fbfc1` (branch `2.0.5`)

**El síntoma que se arregló.** Llevo tiempo usando Yala en modo privado. Salgo de la app y, desde el
Welcome, tapeo «Vengo por un grupo → Crear mi primer grupo». Yala me respondía: «Este dispositivo
tiene datos de otra cuenta. Para proteger esos datos, no podemos conectar una cuenta distinta aquí.
Su dueño puede volver a entrar cuando quiera». Los datos eran **míos**, y yo no estaba conectando
ninguna cuenta: estaba intentando crear un grupo.

**El bloqueo era deliberado y correcto** —protege la ventana M1: Welcome visible tras un
`.privateReset` con el corpus del dueño vivo, porque esa rama reusa `GroupsSignInView`, que no
consulta el guard cross-cuenta—. Lo que estaba mal no era bloquear, sino lo que se decía al bloquear:
el texto era el prestado del guard de sign-in (`welcome.cloud.blocked*`) y describía una acción que la
persona no estaba haciendo. Los otros dos términos del mismo gate ya tenían copy propio
(`blockedChannelOff` y `blockedSecondarySession`); el tercero se había quedado sin la suya.

| Archivo | Qué |
|---|---|
| `Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift` | la rama `.blockedForeignData` pinta copy propio, con icono propio (`square.stack.3d.up.slash` en vez del `lock.shield` del guard de sign-in). El `identifier` NO cambia (`welcome_groups_gate_foreign_data`), así que el XCUITest que lo busca siguió valiendo |
| `Yala/Utils/L10n.swift` + 16 `.strings` | `welcome.groups.existingDataTitle` / `existingDataBody` |
| `YalaTests/Groups/GroupsOrganizerBranchTests.swift` | `eachBlockReasonHasItsOwnCopy`, en el suite de source-scan que ya existía |

**Decisiones.** (1) El copy nombra el hecho que el detector **puede sostener**: `checkHasExistingData`
cuenta filas, así que dice «hay datos», nunca «hay datos de otro»; por eso el texto habla de lo que
pasaría (conectar una cuenta encima) y no de quién es dueño de qué. (2) No se implementa la
alternativa mayor —consultar `CloudClaimActionStore` para separar «datos míos» de «datos de otro
humano»—: sigue abierta y es decisión de producto. (3) El escáner es por CONTENIDO, no por conteo de
casos: lo que hay que impedir es que dos ramas compartan key. (4) `welcome.cloud.blocked*` se
conserva porque tiene su caso legítimo, donde la persona sí está conectando una cuenta.

**Gate de aquel commit, tal como se registró:** build `Yala` ✓ · `Yala Dev` ✓ · unit 21/21 en 2 suites
(incl. `LocalizationParityTests`) · XCUITest 6/6 (`SecondarySessionGateUITests`,
`OnboardingFlowUITests`) · índice OK. **No consta QA visual**, y hoy no se ha vuelto a correr nada:
lo comprobado el 2026-09-02 es que el copy propio sigue en el árbol, traducido en los 16 `.lproj`, y
que la red en simulador existe (`YalaUITests/Flows/SecondarySessionGateUITests.swift:124` busca
`welcome_groups_gate_foreign_data`).

**Nota de método que sigue valiendo.** La primera corrida del pin salió `Executed 0 tests` con exit 0:
el filtro `-only-testing:YalaTests/GroupsOrganizerBranchTests` usa el nombre del FICHERO y el suite se
llama `GroupsOrganizerWiringTests`. Es el modo de fallo que `.claude/rules/testing.md` describe —verde
que no ejecutó nada— y se detectó porque el gate exige leer la línea `Test run with N tests`.

**Cabo suelto que dejó este fix (medido hoy, es solo un comentario, no cambia comportamiento):** el
docblock de la rama `.blockedForeignData` en `WelcomeCloudSignInView` (`:264`) sigue diciendo que
su gemela de Grupos tiene «mismo hecho y mismo copy». El hecho sí; el copy ya no, desde este commit.

### 2026-08-13 · decisión del owner sobre el segundo caso

El ticket describía un segundo camino con el mismo copy: el **dueño que vuelve**, restaura de iCloud y
toca «atrás» para entrar por la card de su cuenta — `hasLocalDataNow` ya da `true` por el import en
curso, no hay claim que reclame esas filas ⇒ `.blockedForeignData`. En lenguaje de usuario: Yala le
bloqueaba la entrada a su propia cuenta diciéndole que este dispositivo tiene datos **de otra cuenta**
—que son los suyos, que acababa de bajar él— y le ofrecía una salida absurda: «su dueño puede volver a
entrar cuando quiera».

**Y ahí el texto era correcto para el hecho**: en esa pantalla sí estás conectando una cuenta. Lo que
fallaba era el VEREDICTO. Maquillar el copy habría tapado una decisión equivocada.

**Decisión: opción (a), que el guard sepa que hay una restauración en curso, con la señal ACOTADA.**
No vale un «hay import en curso» genérico: tiene que ser «esta sesión pidió restaurar de iCloud y ese
import no ha terminado». Si la señal se enciende cuando no debe, se abre exactamente la puerta que el
guard existe para cerrar ⇒ **sesgo fail-closed: ante la duda, bloquear.** Se descartó la opción (b)
—consultar `CloudClaimActionStore`— porque esa prueba vive en `UserDefaults` y desaparece con la
reinstalación, que es justo el escenario roto: sin prueba, «bloqueo» no arregla nada y «paso» desarma
el guard. Más una segunda pieza independiente y barata: que esa pantalla deje de ser un callejón.

### 2026-08-13 · pieza 2, la salida honesta · `6812941e` · HECHA

| Archivo | Qué |
|---|---|
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | la rama `.blockedForeignData` pasa de un `messageContent` suelto a un `VStack` con hint + `YalaPrimaryButton` de vuelta (`welcome_cloud_blocked_back`) |
| `Yala/Utils/L10n.swift` + 16 `.strings` | `welcome.cloud.blockedRestoreHint` · `welcome.cloud.blockedBack` |
| `YalaTests/CrossAccountEntryGuardLogicTests.swift` | suite `WelcomeCloudBlockedExitTests` (source-scan) |

**Decisiones.** (1) El copy no se toca: para el hecho dominante —datos de otro humano— es correcto.
Lo que se añade es el SEGUNDO mundo de la misma pantalla, porque el detector no puede separarlos.
(2) El botón se añade **aunque `canGoBack` ya incluya esta fase**: esconder la única salida de una
pantalla de bloqueo en una esquina de 44 pt no es ofrecerla. (3) El escáner corta la rama de su `case`
al siguiente y no lee el fichero entero. (4) `pt` se alineó con `pt-BR`: son alias por contrato y la
paridad lo cazó en la primera corrida.

**Mutación:** los 2 tests nacieron ROJOS (3 aserciones) contra el árbol previo al fix.
**Gate:** build ×2 ✓ · unit 5818 / 565 suites ✓ · XCUITest 6/6 ✓ · índice OK.

### 2026-08-13 · pieza 1, la señal acotada · `d3c14350` · HECHA

| Archivo | Qué |
|---|---|
| `Yala/App/Logic/ICloudRestoreInProgressLogic.swift` | **nuevo** · los términos de la señal |
| `Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift` | **nuevo** · el latch de sesión + el adaptador que lee `iCloudSyncService` |
| `Yala/App/Logic/CrossAccountEntryGuardLogic.swift` | `decide` gana `restoreInProgress` y el `guard` pasa a `hasLocalData, !restoreInProgress` |
| `Yala/App/Views/Onboarding/WelcomeRestoreView.swift` | enciende la señal en `startSearch`, **después** de los dos `return` |
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | el call-site del guard lee la señal viva |
| `YalaTests/…GuardLogicTests` · `YalaTests/CloudSync/ICloudRestoreSignalTests.swift` | 3 celdas nuevas + 9 tests en 3 suites |

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
   nada; encender ahí abriría la ventana sin corpus que la justifique.

**Mutación: 4 mutantes a exit 65.** (a) quitar el término del guard; (b) descablear la lectura del
call-site, que cae **SOLO en el source-scan con los 8 del guard en VERDE** —la demostración de por qué
ese escáner existe—; (c) mover el encendido por delante de los early-returns; (d) el conteo de
encendedores. **Gate:** build ×2 ✓ · unit 5830 / 568 suites ✓ · XCUITest 10/10 ✓ · índice OK.

#### Corrección · `579e9d0b` · la señal no caducaba

La revisión de la sesión hermana encontró —y se midió y confirmó— una regresión que la pieza 1
introdujo: **la señal podía quedarse encendida toda la sesión y con ella el guard cross-cuenta
DESARMADO.** `restoreRequestedThisSession` era un latch que no se apagaba nunca dentro del proceso, y
`hasCompletedFirstImport` se enciende **solo en la rama de import EXITOSO** (`iCloudSyncService.swift`,
dentro del `else if let endDate` — hoy `:266-272`): con un backup ausente o un import que falla no
llega jamás.

**Camino alcanzable:** tocar «Restaurar desde iCloud» (latch ON) → no hay backup → volver atrás →
firmar con OTRA cuenta sobre un device con corpus ajeno ⇒ `.proceed` y adopt sobre los datos del
dueño. Exactamente el incidente que el guard existe para impedir.

**La lección, que es lo que vale para el yo-futuro:** el sesgo **declarado** estaba invertido respecto
al **implementado**. El docblock decía «ante la duda, `false`», y `!(A && B)` con `A` desconocido
devuelve `true`, que es ABRIR. ⇒ **un sesgo fail-closed no se declara en prosa: se comprueba
enumerando qué devuelve la función con cada término en `unknown`.** Y lo más incómodo: el propio test
`settledImport_closesTheWindow` llevaba escrito el peligro y solo probaba el camino feliz.

**El fix:** la señal pasa de interruptor a **VENTANA** (`restoreStartedAt: Date?`) y se cierra por
cuatro caminos — los dos últimos sin depender de que corra ningún callback: (1) nunca se abrió;
(2) el flujo terminó (`noteRestoreFinished`, gane o pierda); (3) el import asentó; (4) **caducidad**,
sin un solo `.importEvent` pasada la gracia de 60 s (`hasObservedImportActivity` distingue «va lento»
de «no hay nada que importar») y tope duro de 600 s pase lo que pase. `noteRestoreStarted` no re-arma
si la ventana ya estaba abierta: el botón de reintentar la convertiría en extensible a voluntad.

**Mutación:** los 2 tests de caducidad nacieron ROJOS contra `d3c14350`; quitar el apagado explícito da
exit 65 **solo en el source-scan**. **Gate:** build ×2 ✓ · unit 5835 / 568 suites ✓ · XCUITest 6/6 ✓ ·
índice OK.

### La cadena del segundo caso: confirmada eslabón a eslabón (2026-08-13), no reproducida

1. Elegir «Restaurar desde iCloud» relanza la app con el mount neutro
   (`WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud) == true`) y el destino sobrevive en
   `WelcomePendingDestinationStore` ⇒ el relanzamiento **no rompe la cadena**, solo la mueve de proceso.
2. El import de CloudKit puebla el store personal (`RestoreProgressView` cuenta filas EN VIVO).
3. El «atrás» está disponible **durante** la búsqueda: el `ToolbarItem` de `WelcomeRestoreView:71-75`
   (medido hoy: sigue exacto) no está gateado por estado.
4. `.chooser` → «Ya tengo una cuenta» → card de cuenta nube. `.cloudSignIn` no requiere mirror ⇒ no
   hay segundo relanzamiento que interrumpa nada.
5. `GET /account/exists == true` (migró) · 6. `hasLocalDataNow()` = `true` por las filas del paso 2 ·
   7. `sameAccountClaimExists` = `false`, porque el claim muere con la reinstalación.

## Criterio de hecho

- Las tres razones de la puerta de Grupos con copy distinto y verificable por l10n. **Cumplido**
  desde `c14fbfc1`.
- Un test de la tabla de decisión que asocie cada razón a SU key. **Cumplido**
  (`eachBlockReasonHasItsOwnCopy`).
- Lo que queda es la pregunta de arriba y el residual.

## Re-medición de coordenadas (2026-09-02, sobre `553b91c9`)

La tabla del 2026-08-13 daba dos filas por «exactas» que **el propio arreglo de esa misma sesión
invalidó**. Corregidas:

| Lo que decía el ticket | Medido hoy |
|---|---|
| `CrossAccountEntryGuardLogic.swift:53-56` — «exacta» (13-ago) | **derivó a `:66-69`.** La invalidó la pieza 1: `decide` ganó `restoreInProgress` y su docblock (`:47-51`), así que el `guard` bajó a `:66` y el `return .blockedForeignData` a `:69` |
| `WelcomeCloudSignInView.swift:709-713`, «la llamada a `decide(` con sus CUATRO argumentos» — «exacta» (13-ago) | **derivó a `:731-739`, y ya son CINCO argumentos**: el quinto es `restoreInProgress:` (`:739`). La fila envejeció el mismo día en que se escribió |
| `checkHasExistingData` — el ticket se contradecía a sí mismo (`ContentView.swift:1086` arriba, `:1100` abajo) | **`:1100`**, medido: `private func checkHasExistingData() -> Bool`. Queda **una sola** coordenada; la de `:1086` se borra |
| `GroupsOrganizerGateLogic.decide` `:78-85` (12-ago) | **exacta** |
| `WelcomeGroupsGateView.swift:75-83` — «exactas» (12-ago) | **la rama va hoy de `:75` a `:89`.** El `case .blockedForeignData` sigue en `:75`, pero el comentario que el propio fix añadió empujó el `blockedContent(` a `:85-89`: `:75-83` ya no cubre el copy que se pinta |
| `iCloudSyncService.swift:265-272` (citado en la corrección y también en el código) | **`:266-272`** — el `else if let endDate` está en `:266`; `:265` es el `surfaceOrSuppress(error)` de la rama de error. Vive en `Yala/Services/`, no en `Yala/Services/CloudSync/` |
| `CloudClaimActionStore` «vive en `UserDefaults` (`:33`)» | **`:34`** — `init(defaults: UserDefaults = .standard)` |
| `WelcomeRestoreView:71-75` (el «atrás» no gateado por estado) | **exacta** |
| `WelcomeCloudSignInView:252` (el caso legítimo de `welcome.cloud.blocked*`) y `:254-260` (el porqué de que no haya XCUITest) | **la rama entera es `:249-283`**: el `messageContent` con `welcome.cloud.blocked*` en `:257-260`, el docblock del «el simulador no firma» en `:261-267`, el hint de la pieza 2 en `:270-274` y el botón de volver en `:278-282` |

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — la rama que sí necesita puerta y no la tiene
- [[welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo]]

> Sync 18 ago (Iris, Mac SSOT). Cola A A1 READY Mini 17 ago. Caso 2 = cola C, no corrida. No rename.

migrated from YalaWiki Bugs/qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos.md @ 1934e8ad

---

## 2026-09-02 (noche) · la pregunta está respondida y la pieza hecha

**Decisión del owner: SÍ, la puerta de Grupos hereda la señal de restauración.** Con eso deja de
estar bloqueado lo único que quedaba de este ticket.

### Qué cambia para quien usa la app

Cambias de móvil, restauras desde iCloud y —mientras tus datos van bajando— intentas crear tu primer
grupo. Antes Yala te paraba diciendo que este dispositivo tiene datos de **otra cuenta**, y te
ofrecía crear el grupo «desde la app que ya usas»: una salida imposible de seguir, porque esa app es
justo la que tienes delante montándose. Ahora la puerta distingue tus propias filas bajando de las de
otra persona, igual que ya lo distinguía la puerta gemela del sign-in.

### El cambio

| Archivo | Qué |
|---|---|
| `Yala/App/Logic/GroupsOrganizerGateLogic.swift` | `decide` gana `restoreInProgress` (**sin default**, como su gemelo) y el guard de datos ajenos pasa a `!(hasExistingData && !restoreInProgress)`. Docblock de cabecera al día: hablaba de «los tres términos» y ya son cuatro |
| `Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift` | El único call-site de producción pasa `ICloudRestoreSessionSignal.isRestoringNow` — la señal viva, leída en el momento de decidir y no capturada antes |
| `YalaTests/Groups/GroupsOrganizerBranchTests.swift` | 2 tests nuevos de tabla + el barrido exhaustivo de 3 → 4 dimensiones + 1 source-scan del cableado. Las 10 llamadas existentes pasan `restoreInProgress: false`, que es el mundo que ya describían |
| `qa/coverage-index.json` | `lastVerified` de `onboarding-flow` y `onboarding-groups-only` (las dos **deterministic**; las `agentic`/`manual` NO se tocan: no las he corrido) |

**Se siguieron las tres decisiones que la pieza 1 dejó escritas**, porque el problema es el mismo:
sin default (lo comprueba el compilador, no un escáner); el término corrige el TÉRMINO de los datos y
no el veredicto (va dentro de la condición, no como cuarta rama); y la señal se lee viva.

### Mutación: 2 mutantes a exit 65, cada uno en su mitad

| Mutante | Resultado | Muerto por |
|---|---|---|
| Descablear el call-site (`restoreInProgress: false` a pelo) | **exit 65**, 2 issues | el source-scan `MUTACIÓN (e)` — la tabla habría seguido VERDE |
| Quitar el término del guard (vuelve el bug) | **exit 65**, 2 issues | los dos tests de tabla — el source-scan habría seguido VERDE |

Que cada uno caiga sólo en su mitad es la prueba de que las dos redes no son redundantes. Es el mismo
reparto que la pieza 1 documentó con su mutante (b).

### Verificación

`Test run with 40 tests in 6 suites passed` — **6 suites pedidas, 6 arrancadas**, comprobado contra
`◇ Suite`. El denominador importa aquí más que de costumbre: la primera corrida de este cambio pidió
3 suites, arrancaron 2 y salió `TEST SUCCEEDED`, porque `-only-testing` resuelve por el nombre del
TIPO y `GroupsOrganizerBranchTests` es el nombre del FICHERO — ninguna de sus cinco suites se llama
así. La que no corrió era justo la del source-scan. Trampa nueva, anotada en
`docs/aprendizajes-tecnicos.md`.

### Lo que NO cierra este commit

El **residual de device-QA sigue abierto y es del owner**: exige SIWA con un Apple ID real, no
simulador, y el propio ticket lo marca como «Inferido, y NO reproducido». Por eso el ticket pasa a
`qa/` y no a `done`: el código está hecho y pinneado, la comprobación con cuenta real no.
