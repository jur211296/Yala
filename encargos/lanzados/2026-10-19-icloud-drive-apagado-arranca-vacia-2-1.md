# Con iCloud Drive apagado antes de abrir Yala, que la app avise en vez de arrancar vacía y muda (2.1)

## Contexto
Card `tablero-con-icloud-drive-apagado-antes-de-abrir-n5zw` (2.1, high, cierra sola). Hallada en el QA guiado del 19-oct (prueba A · i1o5, iPhone de QA, Yala Dev desde 3e59c0689, 2.1 con el PR #515). Jürgen pidió encolarla como PRIORIDAD.

MEDIDO en el iPhone: store con 37 movimientos y 4 cuentas; Jürgen cierra Yala y apaga iCloud Drive; al abrir Yala, iCloudSync da `noAccount`, setup OK, UserSegmentService «pre-import tx=0», store con 0 movimientos y 1 cuenta. Ningún aviso en pantalla (ni «iCloud no está disponible» ni «Tus datos fueron eliminados»), tampoco al relanzar. Guards del aviso en UserDefaults: hasPrivateSession=true, storageMode=icloud, hasCompletedOnboarding=true (pasan).

MEDIDO en código: el único productor del aviso es la gracia de 5 s de ContentView, que arranca en la transición hasPersonalData true→false (`RemoteWipeGraceLogic.personalDataChanged`). `@State hasPersonalData` nace en false, así que si el arranque ya ve el store vacío no hay caída, no hay gracia y no hay aviso.
INFERIDO (verifícalo): el 15-oct el vaciado ocurrió con el proceso vivo (por eso salió el aviso); hoy iOS vació antes de la primera medida.
Lo bueno: ya no aparece la oferta destructiva «Empezar de cero» (PR #515, que solo avisa en caliente; esta card no lo duplica). Lo que ve el usuario hoy: su app vacía, sin explicación, hasta que encienda iCloud.

## Qué se pide
1. Disparar también el aviso «iCloud no está disponible en este dispositivo» (con «Entendido») en el ARRANQUE en frío cuando: la sesión es privada con iCloud, el onboarding está hecho, el store está vacío y la cuenta de iCloud no está disponible, sin depender de la caída true→false.
2. Que siga sin salir «Empezar de cero» ni el aviso de datos borrados en ese caso.
3. Que al encender Drive los datos vuelvan solos y no salga ningún aviso de borrado.
4. Test de la decisión en frío (lógica pura) + XCUITest con seam (`#if DEBUG`, solo con `-uitest`) que simule la cuenta no disponible al arrancar con store vacío, con su control: el estado en que NO debe salir (cuenta disponible, onboarding sin hacer, sesión de nube, store con datos).
5. Ticket y docs al día; card con `hechaCuando` y guion corto de device-QA para Jürgen: repetir A · i1o5 con Yala cerrada al apagar Drive.

## Qué NO hay que tocar
- No rediseñar el flujo de borrado remoto legítimo ni la gracia en caliente del PR #515 más allá de lo necesario.
- No tocar los iPhone ni el iPad de Jürgen: los está usando el QA guiado (sesión `Yala--qa-guiado-2-1-tf17`). Todo en simulador.
- Nada de 2.2. Ojo: `ShellDataAlertsModifier.swift` cambió en 2.2 con el PR #560; si tocas ese archivo, deja anotado en el PR qué habrá que mirar al traer 2.1 a 2.2.
- No pedir OK a Jürgen: cierra sola con /cerrar-total.

## Dependencias
La sesión arranca ya sobre `origin/2.1`, sin esperar CI ni merge de ningún PR anterior. Justo antes de abrir el PR: `git fetch` + un solo rebase sobre `origin/2.1`, y build y simulador una vez después. PR contra 2.1. No esperes el CI para cerrar: el PR entra cuando el CI sale en verde.

## Mini (pipeline serial, sin preguntar)
1) Limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees ya cerrados. 2) Build con `xcodebuild -jobs 2` sin simulador encendido. 3) Bootear un solo simulador (antes, `xcrun simctl list devices booted`). 4) Tests. 5) Apagar y borrar ese simulador. Prohibido solapar build, simulador y UITests.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo (el del QA guiado). Si un borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- Con Yala cerrada al apagar iCloud Drive, al abrirla sale «iCloud no está disponible en este dispositivo» con «Entendido»; sigue sin salir «Empezar de cero»; al encender Drive vuelven los datos sin aviso de borrado.
- Tests nuevos en verde, cada uno con su control; `/gate` en verde en lo tocado; capturas antes y después del arranque en `capturas/`.
- PR a 2.1 abierto y en cola de merge; card en in qa a nombre de jurgen con el guion de device-QA (o done si no hace falta su iPhone).
- En el resumen de cierre, indica que la sesión del QA guiado debe volver a probar A · i1o5.
- CIERRE: cierra sola, /cerrar-total sin esperar a Jürgen.

## Paso 0

Modo: autónomo (encargo «cierra sola»). Worktree → rama + PR en cola de auto-merge.

**Ficheros (nota, no pregunta):**
- `Yala/App/Logic/RemoteWipeGraceLogic.swift` — decisión pura del arranque en frío (`coldStartRequestsICloudNotice`) y del drenaje de esa petición (`coldStartDrainPresents`); el predicado «iCloud no disponible» compartido con `noticeDecision`.
- `Yala/App/ContentView.swift` — pide el aviso desde `checkInitialSyncState` (rama de onboarding hecho), marca la petición como «de arranque» y, en el drenaje, una petición de arranque solo enseña «iCloud no está disponible»: si iCloud volvió, se retira sin aviso.
- `Yala/App/UITestHooks.swift` + `YalaUITests/Support/XCUIApplication+Yala.swift` — seam `-uitest-cold-start-icloud-check`.
- `YalaTests/RemoteWipeGraceLogicTests.swift`, `YalaTests/RemoteWipeSignalWiringTests.swift` — tests de la decisión y del cableado (el escáner que contaba dos productores pasa a tres).
- `YalaUITests/Flows/ColdStartICloudUnavailableUITests.swift` — XCUITest nuevo con sus controles.
- `qa/coverage-index.json`, `tickets/qa/<ticket>.md`, `docs/TICKETS.md`.

**Decisiones (auto-contestadas):**
1. *¿Dónde se mide?* Al final de la tarea del arranque, DESPUÉS de esperar al bootstrap y re-midiendo el store. La primera versión decidía en `checkInitialSyncState` (splash) y el XCUITest midió que el eje de sesión aún no estaba: lo escribe el backfill del bootstrap, en paralelo.
2. *¿Encender el alert directo o por la cola?* Por la cola (`.presentRemoteWipeNotice`), igual que la gracia: el arranque es asíncrono y el anchor puede estar ocupado (regla de Presentaciones). El drenaje re-mide sus condiciones vivas.
3. *¿Qué pasa si al drenar iCloud ya está disponible?* La petición de arranque NO cae al camino de espera/«datos borrados»: se retira sin aviso. Nunca hubo caída que justifique «tus datos fueron eliminados», y los datos vuelven solos con la importación (pedido 2 y 3).
4. *¿Una vez por arranque o una vez para siempre?* Una vez por arranque en frío mientras se cumplan las condiciones: es verdad cada vez que se abre, y es lo que el usuario necesita saber.
5. *XCUITest: el simulador nunca tiene token de iCloud*, así que el chequeo en frío dispararía en los ~37 UITests que arrancan sin seed y con onboarding hecho. ⇒ Bajo `-uitest` el chequeo está apagado salvo con el seam `-uitest-cold-start-icloud-check`, que declara «este simulador es un iPhone con Drive apagado». El seam habilita al PRODUCTOR; la decisión, el eje, la cola y el drenaje son los de producción. Los controles corren con el seam puesto para que la ausencia del aviso la decida la lógica, no el seam.
6. *Mismo predicado de sesión que la gracia* (`wipeSignalObeyedByThisSession` con `confirmedPrivateSession()`): solo-grupos y nube no ven el aviso.
7. *`ShellDataAlertsModifier.swift` no se toca* (cambió en 2.2 con #560): el alert ya existe y se reusa.

**Residual asumido:** quien tenga el onboarding hecho, sesión privada, iCloud apagado y haya borrado a mano todas sus cuentas y categorías verá el aviso en cada arranque. Es cierto (iCloud no está) e inofensivo (un botón, «Entendido»).

**INFERIDO a verificar donde se pueda:** la «1 cuenta» del store vacío del iPhone es la cuenta de sistema de Grupos (`GroupBridgeSystemEntities`, la única que se crea fuera del formulario); `checkHasPersonalData` la excluye, así que el store cuenta como vacío.
