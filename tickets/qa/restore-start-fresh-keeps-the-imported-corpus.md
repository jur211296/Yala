---
id: restore-start-fresh-keeps-the-imported-corpus
status: qa
priority: high
area: "onboarding, modo-nube"
created: 2026-09-11
source: "medido leyendo el código durante el paso 8 del rediseño de sesiones; NO reproducido en device"
---

# «Empezar desde cero» en Restaurar promete «sin tus datos previos» y los deja bajando

## El síntoma, en lenguaje de usuario

Welcome → «Ya tengo una cuenta» → «Restaurar desde iCloud» → la app encuentra mis datos → toco «Empezar
desde cero» → «Esto creará una cuenta nueva sin tus datos previos. ¿Continuar?» → «Sí». Me sale el
onboarding… y mis datos de antes siguen bajando por debajo, porque el espejo de iCloud ya estaba puesto.

## Lo medido (árbol del paso 8, 2026-09-11)

- `ContentView.welcomeRestoreCover` → `onStartFresh`: limpia nombre y divisa y enciende `showOnboarding`.
  **No borra nada**, ni la zona de iCloud ni lo que el espejo ya importó.
- `WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud) == true`: esa pantalla solo existe con el
  espejo adjunto, así que el corpus sigue importándose mientras la persona hace su onboarding «de cero».
- Es la misma familia que el bug del paso 4 (`welcome-private-fresh-start-skips-icloud-check`), por otra
  puerta. `welcome-start-fresh-wipes-before-ask` habla de este mismo botón, pero de otra cosa: de las
  preferencias que borra antes de preguntar.
- **La activación de Yala completo (paso 8) lo hereda a propósito**: «Restaurar» ahí es el mismo recorrido
  de «Ya tengo cuenta → iCloud» (decisión de Jürgen), y su «empezar de cero» lleva al mismo onboarding. En
  ese contexto el arreglo tiene una restricción más: el borrado local (`DataWipeService.wipeAllUserData`)
  resetea `hasCompletedOnboarding`, el modo y el nombre, y mandaría al Welcome a un solo-grupos.

## Qué se espera

Lo mismo que la puerta del paso 4: si hay corpus, «empezar de cero» es **borrar** (con segunda
confirmación, zona de iCloud + lo importado) — o no ofrecerlo desde aquí y devolver a la puerta.

## Criterios de aceptación

- [ ] **DEVICE** · Restaurar → encontrado → «Empezar desde cero» → tras terminar el onboarding y esperar a
      que iCloud sincronice, no aparece ningún dato previo.
- [ ] El mismo recorrido desde «Activar Yala completo → privado → Restaurar» deja la sesión de grupos
      intacta.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir código (2026-09-14)

Todo lo de abajo está medido en el árbol de esta sesión (`799e01a3`). **Las coordenadas del cuerpo del
ticket envejecieron** y se re-greppearon: `welcomeRestoreCover.onStartFresh` está en
`ContentView.swift:664-671` (el ticket no daba línea), y el botón que lo dispara vive en **cinco**
sitios de `WelcomeRestoreView.swift`, no en uno: `.found` vía `confirmationDialog` (`:228-232` +
`:110-121`), `.notFound` (`:341-342`), `.iCloudDisabled` (`:354-355`), `.cloudPaused` (`:385-390`,
el otro que pasa por el diálogo) y `.wiped` (`:404-405`). El bug se confirma tal cual: el callback
limpia residuales, borra el prefill, cierra el cover y enciende el onboarding — **no borra nada**.

### Lo que el ticket no sabía, y cambia el alcance

- **El resumen de «Restaurar» cuenta FILAS DEL STORE LOCAL, no CloudKit.**
  `ModelContext.iCloudAccountSummary` (`iCloudSyncService.swift:780-813`) hace cuatro `fetchCount`
  sobre el store que ya tiene el espejo adjunto. O sea: la pantalla enseña **lo que ya bajó**, no lo
  que hay arriba.
- **Y su `.notFound` puede ser un falso negativo.** `RestoreProgressView.startFlow`
  (`:150`) espera `waitForImportQuiescence(timeout: 90)` y **sale igual al agotar el tope**
  (`phase = settled ? .completed : .partial`, `:157`); el propio copy lo dice
  («Seguiremos sincronizando mientras usas la app»). Un corpus grande sale de esa pantalla con las
  cifras en cero y el import en vuelo.
- **La puerta del paso 4 ya hace todo lo que este ticket pide.** `WelcomePrivateICloudGateView`
  pregunta a CloudKit (no al store), enseña cifras, ofrece tres salidas —borrar con **doble
  confirmación**, restaurar, cancelar—, arma el borrado para sobrevivir a un kill, y ya está
  parametrizada para los dos consumidores (Welcome / activación de Yala completo).

### D1 · Devolver a la puerta, no construir fases nuevas en `WelcomeRestoreView`

El ticket ofrece las dos («borrar con segunda confirmación **o** no ofrecerlo desde aquí y devolver a
la puerta»). Se elige la segunda, y no por economía:

- Fases nuevas en la pantalla de restaurar duplicarían cinco mecanismos que ya existen y están
  probados (sonda, cifras, doble confirmación, arm kill-safe, testigo del espejo tardío) más su copy
  en 16 locales. Es exactamente cómo divergen dos pantallas que hablan de lo mismo.
- **Y la puerta mide algo que la pantalla de restaurar NO puede medir**: `ICloudPersonalCorpusProbe`
  pregunta a la zona de CloudKit, así que contesta también en el caso del `.notFound` falso — donde
  el store está vacío porque el import no terminó, y el botón de hoy promete «sin tus datos previos»
  justo cuando más mentira es.

Entrada: `returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .privateICloudGate)`, el
helper que ya usa el `onBack` de esta misma vista. El step ya es alcanzable como inicial
(`ContentView.swift:1599` lo usa para retomar un borrado armado).

### D2 · El `confirmationDialog` de la vista se QUEDA

No se toca ni su copy ni sus cuatro claves. Razones medidas:

- La vista tiene **dos** consumidores y el segundo (`FullModeActivationView`, D4) no cambia en este
  PR: quitar el diálogo le dejaría el gesto destructivo sin ninguna confirmación.
- En el camino del Welcome deja de ser la última palabra: detrás viene la puerta, que **vuelve a
  preguntar con cifras** y exige un segundo gesto. Se suman confirmaciones, no se restan.

### D3 · La limpieza de residuales SALE del callback

`OnboardingResetHelper.clearResidualPreferencesForFreshStart()` se quita de `onStartFresh`. Es la
regla que `welcome-start-fresh-wipes-before-ask` dejó escrita —**«se limpia cuando se BORRA, no
cuando se pregunta»**— y su decisión nº2 exceptuó este call-site con un motivo que **este PR
invalida**: decía que aquí el fresh-start «ya estaba confirmado y no hay alert que cancelar». Ahora
sí lo hay: la puerta puede cancelar y volver al chooser.

No se pierde en ninguna salida: si la puerta borra, limpia ella
(`clearsResidualPreferencesOnWipe: true`); y si sale por `proceed`, limpia el portal
(`ContentView.swift:1849`, rama del relanzamiento) o `startFreshPrivateOnboarding` (`:2090`).

### D4 · `deviceCorpusGate` NO se toca, y estuve a punto de romperlo

El primer diseño quitaba el guard `shouldRelaunch(.privateOnboarding, …)` de
`WelcomeFlowContainer.swift:409-415` para que la puerta preguntara también por el corpus del
teléfono al entrar desde Restaurar (donde el mount siempre espeja, así que hoy llega `nil`).
**Es un daño grave, y lo tenía escrito el propio repo**
(`WelcomePrivateICloudGateTests.swift:744`): con el espejo montado, el borrado por filas de
`performDeviceCorpusWipe` **exporta los deletes** ⇒ el iCloud de la persona vaciado en todos sus
dispositivos, bajo un copy que promete que iCloud no se toca.

Y no hace falta: con el espejo puesto, el corpus local **vino de iCloud**, así que el aviso remoto ya
lo cubre y su borrado se lleva las filas por delante (`includingLocalRows: true`). Cuando la sonda no
puede medir, las dos salidas de la puerta (`noICloud`, `unreachable`) escriben
`markPrivateChoseWithoutICloud`, y el aviso del espejo tardío lo retoma en el arranque siguiente. El
aviso se aplaza, no se pierde.

### D5 · El alert espurio de fresh-start, que este cambio hace frecuente

Medido: `performICloudCorpusWipe` **no baja** `hasExistingData` / `hasPersonalData` (son `@State`, y
`wipeAllUserData` no llama a `incrementDataVersion`, así que el `.onChange(of: dataVersion)` no
dispara). Sus otros dos consumidores lo compensan fuera (`ContentView.swift:337-338` y `:1354-1355`);
**la puerta no**.

Hoy casi no se ve porque la puerta se alcanza con el mount neutro ⇒ `onProceed` relanza y el proceso
muere. **Desde Restaurar el mount siempre es `.iCloudMirror`**, así que `shouldRelaunch` da `false`,
`startFreshPrivateOnboarding` lee un `true` viejo y levanta «Detectamos datos previos. ¿Borrar todo?»
sobre un store recién vaciado — a alguien que acaba de confirmar el borrado dos veces, y cuyo
«Cancelar» lo deja plantado en el Welcome.

Se cierra envolviendo el `performICloudCorpusWipe` que `ContentView` le pasa al `WelcomeFlowModifier`
(`:364`): tras un borrado con éxito baja los dos flags, cancelando antes la gracia del wipe remoto
—si no, el `true → false` de `hasPersonalData` se lee como «te borraron los datos en otro
dispositivo» (`.onChange`, `:282`)—. Es el mismo molde que el `onWiped` del aviso tardío.
`hasCompletedOnboarding` **no** se toca aquí: lo borra `wipeAllUserData` y forzarlo dispararía el
encaminamiento que `onboardingReset_doesNotHijackTheWelcome` vigila.

### D6 · La activación de Yala completo queda FUERA, con ticket propio

`FullModeActivationView.swift:143` es el otro consumidor del botón, y **su recorrido no se puede
cerrar con las piezas de hoy**. Allí el borrado es de ZONA
(`performICloudCorpusWipe(includingLocalRows: false)`) porque `wipeAllUserData` resetea
`hasCompletedOnboarding`, el modo y el nombre, y mandaría al Welcome a quien está activando
(restricción del paso 8). Pero para llegar a `.restore` en ese flujo hubo relanzamiento, así que el
store **espeja**: borrar solo la zona deja las filas importadas, que se **re-exportan** a la zona
recién creada. Un borrado que no borra.

Cerrarlo pide un borrador que no existe —filas personales sin tocar preferencias—, y
`resetAllUserPreferences` (`DataWipeService.swift:553`) hace mucho más que quitar keys (router,
ProTour, checklist, espejos del App Group). Otro objeto: ticket
`activation-restore-start-fresh-keeps-the-imported-rows`. Aquí solo se actualiza el comentario, que
si no queda apuntando a un ticket cerrado.

> **CERRADO el 2026-09-14**, en el PR de ese ticket. El borrador existe
> (`DataWipeService.wipeAllUserData(resetsPreferences:)` + `ICloudWipeScope.importedRows`) y la
> activación tiene su propia puerta, `.restoreDiscardGate`. Lo que este párrafo daba por imposible
> resultó costar un flag y un enum; lo que de verdad faltaba medir era otra cosa —que sin reabrir el
> centinela del seed la persona termina sin ninguna categoría— y eso no estaba escrito en ningún sitio.

**El AC nº2 se cumple igual**: al no tocar ese cableado, la sesión de grupos sigue intacta.

### Lo que se prueba, y por qué es source-scan

El botón no tiene **ni un test** hoy (medido sobre `YalaTests/` + `YalaUITests/`: cero menciones a
`onStartFresh`, `showStartFreshConfirm` o `welcome.restore.startFresh*`), y los dos lados del cambio
viven en vistas SwiftUI no invocables desde un unit test. El molde es
`WelcomePrivateICloudGateWiringTests`: escanear el CUERPO entero del callback, exigir el destino
nuevo y **prohibir el viejo**, que es lo único que impide que el bug vuelva sin ningún otro rojo.

---

## Implementación · 2026-09-14

### Archivos

| Archivo | Qué cambia |
|---|---|
| `Yala/App/ContentView.swift` | `welcomeRestoreCover.onStartFresh` entra al step `.privateICloudGate` en vez de encender `showOnboarding`; se le quita la limpieza de residuales y baja `hasShownWelcomeChooser`. El `performICloudCorpusWipe` que recibe el `WelcomeFlowModifier` baja las dos señales de «hay datos» tras un borrado con éxito, y cancela la gracia del wipe remoto ANTES del borrado. `startFreshPrivateOnboarding` pasa al fetch VIVO |
| `Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift` | `discardPendingWipe()` nuevo: `.proceed` y `continueWithoutValidating` retiran el arm del borrado |
| `Yala/App/Views/Onboarding/WelcomeFlowContainer.swift` | `onRestore` de la puerta retira el arm antes de salir |
| `Yala/App/Views/Groups/FullModeActivationView.swift` | Solo el comentario del `onStartFresh`: la asimetría y su ticket |
| `YalaTests/CloudSync/RestoreStartFreshGateTests.swift` (nuevo, 6 casos) | El pin del bug + el envoltorio del borrado + las salidas del arm + el helper de navegación + las dos confirmaciones |
| `YalaTests/FreshStartWipeAlertTests.swift` · `YalaTests/Groups/GroupsOrganizerBranchTests.swift` | Los dos tests ajenos que el cambio toca (predicado nuevo; `onBack` acotado) |
| `qa/coverage-index.json` | `onboarding-flow`, `welcome-flow-visual` y `onboarding-groups-only` al 2026-09-14 |

### La review adversarial, y lo que cambió del arreglo

Tres lentes sobre el diff (flujo y kill-safety · presentaciones SwiftUI leyendo `swiftui-ds.md` CONTRA
el diff · tests y cobertura con `testing.md`). **Once hallazgos, y los once eran de diseño propio.** El
primer arreglo compilaba, tenía 6 tests en verde, 5 mutantes que caían, y el recorrido verificado en
simulador — y aun así llevaba dentro tres defectos ALTA.

**Los tres graves, y el primero es que el arreglo no arreglaba.**

1. **El envoltorio del borrado no apagaba el alert que decía apagar.** `WelcomeFlowModifier` recibe
   `hasExistingData` **por valor**, no por binding, y entre la escritura del `@State` y la lectura no hay
   ningún punto de suspensión que obligue a re-evaluar el `body`. Así que tras el borrado seguía
   valiendo el `true` de antes: a quien acababa de confirmar dos veces le salía un tercer alert
   pidiéndole borrar lo que ya no existía, y su «Cancelar» lo dejaba plantado en el Welcome. **Y el
   source-scan que lo daba por cerrado comprobaba que las líneas estaban, no que el valor llegara.** La
   defensa pasa a ser el fetch vivo (`hasLocalDataNow()`), que es lo que el docblock del propio modifier
   lleva pidiendo desde el review S5.
2. **El arm del borrado se quedaba huérfano, y el daño era pérdida total.** Mientras está puesto,
   `runLateICloudMirrorCheck` lo **reanuda a ciegas**. Con el mount neutro eso no mordía porque toda
   salida de la puerta relanza y `presentNextOnboardingScreen` retira el arm con el destino pendiente;
   **desde Restaurar no se relanza**, así que esa red no existe. Recorrido medido: borrado fallido →
   «Traer mis datos» → restaurar el histórico → terminar → **el arranque siguiente lo borra entero, sin
   una sola pregunta**. Ahora las tres salidas que no dejan un borrado a medias lo retiran.
3. **El neutro durable del borrado era inerte en este camino, y un kill se saltaba la puerta.**
   `armICloudCorpusWipe` arma también `armNeutralMount`, cuyo predicado es
   `armado && !hasShownWelcomeChooser` — y a Restaurar se llega con ese flag YA marcado. Las dos mitades
   se cierran bajándolo en el callback: un kill durante el borrado deja de re-importar lo que se estaba
   borrando, y un kill tras cancelar vuelve al Hero en vez de abrir el onboarding privado directo (que
   es este mismo bug por detrás).

**Y los que no eran graves pero cambiaban el resultado**

- **La gracia del wipe remoto se cancelaba solo en la rama de ÉXITO**, que es justo al revés de donde
  hace falta: `wipeAllUserData` guarda por lotes, así que un borrado que lanza a media lista deja el
  `hasPersonalData` cayendo igual, y ese `true → false` levanta un alert que **desmonta el cover del
  Welcome**. La corrección ya estaba escrita tres funciones más abajo, en su hermana.
- **El primer diseño quitaba el guard de mount de `deviceCorpusGate`**, y el repo tenía medido que eso
  vacía el iCloud de la persona en todos sus dispositivos (con el espejo puesto, el borrado por filas
  exporta los deletes). Se descartó: con el espejo adjunto el corpus local vino de iCloud, así que el
  aviso remoto ya lo cubre, y cuando la sonda no puede medir el testigo del espejo tardío lo retoma.
- **Cuatro aserciones del source-scan no podían fallar como decían**: el envoltorio pasaba cambiando el
  borrado por el del teléfono; el `guard` del fallo se afirmaba por presencia donde importaba el orden;
  y el estado `.found` —el camino principal del ticket— tenía su confirmación cubierta solo por una
  aserción sobre el fichero entero que cumplía el vecino.
- **Un test ajeno se DEBILITABA sin romperse**: `WelcomeBackDestinationTests` afirma el destino del
  «Atrás» con un `contains` sobre `ContentView.swift` entero, y este PR añade una segunda llamada al
  mismo helper con el mismo binding. Ya va acotada al `onBack:`.
- **El fichero declaraba dos `@Suite`**, así que `-only-testing` por el nombre del fichero corría **cero
  casos con exit 0**. Una sola suite, con el nombre del fichero.

**Once mutantes verificados** (compilados y corridos, no razonados), listados en la cabecera del fichero
de tests. El del árbol de ANTES mata tres aserciones; el que devuelve el gate del alert al snapshot lo
canta `FreshStartWipeAlertTests`, que es donde vive ese invariante.

### Lo que se verificó en simulador, y lo que no se puede

**VISTO** (iPhone 17 Pro, iOS 26.5, instalación fresca): Welcome → «Ya tengo una cuenta» → «Restaurar
desde iCloud» → reabrir → «Empezar desde cero» → **la puerta**, con «No pudimos revisar tu iCloud» (el
estado K, correcto sin cuenta iCloud) y sus dos salidas. Con «Seguir así» aterriza en un onboarding con
el campo de nombre **vacío**. Con el chevron, en el sub-chooser de «Es mi primera vez» — lo que abrió el
ticket `private-icloud-gate-back-lands-on-the-wrong-branch`.

**NO se puede ver aquí** el estado `.found` con corpus real: CloudKit no existe en simulador. Eso es el
device-QA de abajo.

### Gate

Build `Yala` ✓ (0 warnings nuevos; los 4 de `GroupsSaveSyncTrigger` son preexistentes) · unit
**6803/6803** en 692 suites · XCUITest **10/10** (`OnboardingFlowUITests`, `WelcomeChooserUITests`,
`WelcomeFreshStartAlertUITests`, con cola del simulador y centinela en 0) · `validate-coverage.sh` OK.

### Residual conocido, sin ticket propio

Con un corpus grande, el borrado puede salir `importNotQuiescent`: `performICloudCorpusWipe` espera 30 s
de quiescencia y el import puede seguir en vuelo (la pantalla de Restaurar sale al agotar su propio tope
de 90 s). No es un callejón — la pantalla de fallo de la puerta ofrece **«Reintentar»** sin salir de
ella—, pero es un camino que este PR vuelve más frecuente. Se anota aquí en vez de en un ticket porque
es el comportamiento diseñado del gate de quiescencia, que existe para evitar el SIGTRAP.

## Device-QA · lo que solo se puede verificar en un iPhone

CloudKit no existe en simulador, así que el criterio nº1 del ticket lo tiene que correr Jürgen. Ficha
completa en `tickets/qa/`.

### Antes de empezar

- **Build de TestFlight**, no de Xcode: el contenedor que se va a **borrar** es el de producción.
- **Un iPhone con meses de datos en el iCloud privado**, con el corpus anotado antes de tocar nada
  (movimientos, cuentas, y el mes del más antiguo).
- El recorrido 2 borra de verdad. Si el Apple ID no es desechable, hacer antes el 1 y el 3.

### Los recorridos

#### 1 · Restaurar → encontrado → «Empezar desde cero» → la puerta, con CIFRAS

1. Desinstalar Yala. Instalar desde TestFlight.
2. «Ya tengo una cuenta» → «Restaurar desde iCloud» → reabrir cuando lo pida.
3. Sale «Encontramos tus datos en iCloud» con sus cifras → **«Empezar desde cero»** → confirmar.

**PASS** exige las tres:
- Sale **la puerta** («Revisando qué hay en tu iCloud…» y después el aviso), no el onboarding.
- Las cifras de la puerta casan con el corpus anotado. Pueden no ser idénticas a las de la pantalla
  anterior —aquélla cuenta filas que ya bajaron, ésta pregunta a la zona— y eso es correcto; lo que no
  puede es que la puerta diga que no hay nada.
- El aviso ofrece **tres** salidas: «Traer mis datos», «Empezar de cero» y el chevron.

**FAIL si**: sale el onboarding directo (el bug original), o la puerta dice que no hay datos.

#### 2 · Borrar → onboarding limpio, y iCloud a CERO

Desde el aviso: «Empezar de cero» → «¿Seguro? Esto es definitivo.» → «Borrar todos los datos».

- Sale «Borrando lo que había en iCloud…» y el chevron desaparece mientras dura.
- Al terminar, el onboarding arranca **de cero**: sin nombre y sin divisa preseleccionados.
- **Y NO sale ningún alert pidiendo borrar otra vez.** Ese tercer alert es el defecto que la review
  cazó; si aparece, el fetch vivo no está haciendo su trabajo.

**La verificación que de verdad cierra el AC no está en esta pantalla**: instalar Yala en OTRO
dispositivo con el mismo Apple ID, «Restaurar desde iCloud», y comprobar que **no encuentra nada**.

**Y la prueba que el ticket pide literalmente**: terminar el onboarding, dejar la app abierta un rato con
red, y comprobar que **no reaparece ningún dato previo**.

#### 3 · «Traer mis datos» → vuelve a Restaurar, y lo restaurado SE QUEDA

Repetir el 1 y tocar «Traer mis datos» → Restaurar → «Continuar» → terminar.

- Los datos vuelven, completos.
- **Y al día siguiente, o tras cerrar y reabrir la app un par de veces, siguen ahí.** Esta es la prueba
  del hallazgo nº2 de la review: con el arm huérfano, el arranque siguiente los borraba enteros.

#### 4 · Matar la app a mitad del borrado

En el recorrido 2, entre «Borrar todos los datos» y el final, forzar el cierre.

Al reabrir, **la puerta vuelve a MEDIR**: si la zona ya se borró, onboarding limpio; si no, el aviso otra
vez con las cifras. **FAIL si** arranca borrando sin decir nada, o si el onboarding se monta sobre datos
que siguen en iCloud.

#### 5 · Sin iCloud → «No pudimos revisar tu iCloud», y el aviso llega cuando iCloud vuelve

Apagar iCloud, instalación fresca, Restaurar → «Activa iCloud para continuar» → «Empezar desde cero».

- Sale «No pudimos revisar tu iCloud» → «Seguir así» → onboarding local. (**Verificado en simulador.**)
- Crear un par de movimientos, **activar iCloud** y reabrir: **tiene que salir el aviso del espejo
  tardío**, con las cifras del corpus viejo. Ésa es la mitad que impide que el bug vuelva por detrás, y
  antes de este PR quien entraba por aquí no quedaba vigilado.

### Lo que este device-QA NO cubre

El recorrido desde «Activar Yala completo → privado → Restaurar»: ahí el botón **no cambia** en este PR.
Su hueco lo cerró el suyo el 2026-09-14 (`activation-restore-start-fresh-keeps-the-imported-rows`), y su
device-QA vive aparte: `tickets/qa/device-qa-activation-restore-start-fresh.md`.
