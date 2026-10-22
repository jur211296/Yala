---
id: device-handover-groups-leak
status: discarded
priority: high
area: groups
created: 2026-07-27
updated: 2026-08-26
source: YalaWiki/Backlog/qa_handover-dispositivo-grupos-fuga.md
---


# Handover de dispositivo: el usuario nuevo heredaba los grupos y los gastos del anterior

Why: Discarded 2026-08-26. Residual CloudKit 404. Wipe verified in simulator. No remaining written AC.

Origen: [[MODO-NUBE-AUDITORIA-ESCENARIOS]] §4 fila 1 y §7 (`E2-04` · `NEW-E2-01` · `NEW-E2-03`) — el **único hallazgo ALTA que estaba ACTIVO en producción** hoy, sin depender de ningún flag. Referenciado en [[MODO-NUBE-DECISIONES-ESCENARIOS]] §9.

## Problema

En el MISMO dispositivo y con el MISMO Apple ID: A hace «Cerrar sesión» (`.privateReset`, no borra nada) y B elige «Soy nuevo» en el Welcome.

**Reproducido en simulador** (perfil `grupos`: 2 grupos, 11 gastos + 1 gasto creado a mano con cuenta real ⇒ 2 TX bridgeadas + 1 draft):

| | Store personal | Dominio Grupos | Prefs |
|---|---|---|---|
| A, antes | 36 TX (2 bridgeadas), 3 drafts, 3 cuentas | 2 grupos · 5 miembros · 12 gastos · 34 shares | `groupsBetaUnlocked=true` |
| B, tras «Borrar todo y continuar» | **0** | **intacto** | **`true`** |

Y con el dominio heredado: B entró a Grupos **sin el código beta**, vio los grupos de A con sus saldos («Te deben S/ 530,00 + $ 46,67») y el detalle atribuyéndole los gastos de A («Cena secreta de A — **Pagaste** S/ 300,00»). Al editar uno, el bridge le materializó **-300 / +200 en su cuenta + 1 draft en su Inbox**: el Panel de B pasó de «S/ 1.000 en 1 cuenta» a «S/ 900 en 2 cuentas», con S/ 100 de gastos del mes que no eran suyos.

### Las tres piezas

1. **El wipe excluye el dominio Grupos por diseño** (`DataWipeService.swift:280-284`, con test que lo pinnea) y también `groupsBetaUnlocked` (`:270`).
2. **El bridge no comprueba identidad** (`GroupTransactionBridge.swift`, cero referencias a identidad): resuelve el member por `groupZoneID + isCurrentUser` y decide «ya bridgeado» por `TransactionItem.splitExpenseID` — que el wipe acaba de borrar, así que todo gasto de A parece no bridgeado y se recrea.
3. **`checkHasExistingData` no veía la fuga** (`ContentView.swift:875`): contaba solo `Account` no-sistema y `Category` no-sistema, justo lo que el bridge NO crea. Un A que venía de «Solo Grupos» daba `false` ⇒ el alert no se mostraba y «Soy nuevo» **no corría wipe alguno** (`NEW-E2-03`).

### Por qué la identidad de CloudKit no puede resolverlo

A y B comparten Apple ID, así que **toda** señal disponible coincide: `userRecordID` (`GroupUserIdentityService.swift:57`), `SplitMember.cloudKitUserRecordID`, y `refreshCurrentUserFlags` (`GroupService.swift:1077`) incluso **re-afirma** `isCurrentUser` en el member de A. `runIdentityBootGuard` compara `cached != fresh` ⇒ `.none`. Y `grep corpusID|installID|corpusOwner` = 0 hits: no existe noción de «dueño del corpus». La única señal disponible es de **intención**, no de identidad.

## Solución (implementada)

Frontera por CAMINO, no por función: «Vaciar datos» de Ajustes sigue conservando Grupos —su copy lo promete— y `wipeAllUserData` no cambia. Lo que cambia es el camino que declara **otro usuario**.

1. **`DataWipeService.wipeLocalGroupsDomain(in:defaults:resetSyncState:)`** — nueva, invocada solo desde los DOS caminos de «empiezo de cero» del Welcome (`ContentView.swift`: alert de fresh-start y «Empezar de cero» de la oferta de restore). Purga LOCAL: los 5 `Split*` + `GroupBridgePreference` + prefs (`groupPrefs_*`, `GroupNotifications.lastNotified.*`, `groupsBetaUnlocked`) + reset del estado del motor.
2. **`SplitSyncManager.resetLocalGroupsSyncState()`** — extraído de `performAccountSwitchCleanup`. Emparejado SIEMPRE con el borrado de filas: borrar filas dejando los change tokens intactos deja a CloudKit convencido de que el dispositivo está al día ⇒ esos records no se reenvían nunca ⇒ **pérdida local permanente** con los datos vivos en la nube. No usar `clearAllLocalGroupData` aquí: borra vía el delegate y se auto-difiere en la ventana export-only (en un camino de usuario, diferir = no borrar).
3. **Gate de dominio en el bridge** (`GroupsBetaGateLogic.isBridgeAllowed`): que el corpus se re-descargue es deliberado (es lo que evita la pérdida); quien lo mantiene fuera de la vida personal del nuevo usuario es este gate. Con el **sello** puesto y la puerta de Grupos cerrada, ni `bridgeExpense` ni `bridgeSettlement` escriben, y `retryPendingBridges` no toca la cola ni quema intentos.
4. **`checkHasExistingData`** cuenta ahora `SplitGroup` y las TX con `splitExpenseID != nil`.

### El sello, y por qué no un gate general

Primera versión: bloquear el bridge siempre que el dominio estuviera cerrado. **Puso 14 tests del bridge en rojo** (`GroupBridgeCaseBPreserveTests` ×10, `GroupBridgeCloudSyncIntegrationTests` ×4) y con razón: `groupsBetaUnlocked` es `false` en cualquier entorno limpio, incluido el de todo usuario que aún no abrió Grupos ⇒ el fix se habría convertido en «mis gastos de grupo no aparecen», en silencio y sin quién avisara.

Versión final: `AppPreferences.Keys.groupsDomainSealedForFreshStart`, que escribe la purga. El default es **permitir**; solo el dispositivo que declaró el relevo queda cerrado, hasta que su nuevo dueño adopte Grupos con un acto deliberado (código beta, invitación aceptada u onboarding «Solo Grupos»). El predicado NEUTRALIZA el sello en cuanto eso pasa, así que no hay que cablear su limpieza en los 5 sitios que desbloquean el tab. Excluido del barrido del wipe normal (borrarlo reabriría el bridge en un dispositivo sellado).

### El seam de runner, y por qué no es cosmético

Con el sello puesto, los 14 tests del bridge **volvieron a fallar**. La causa no era contaminación entre tests: el host de los unit tests es la propia app, así que comparte el `UserDefaults.standard` del simulador — y la verificación manual del handover había dejado ahí el sello. Verificado a posteriori: el contenedor del host tenía `groupsDomainSealedForFreshStart = true` y `groupsBetaUnlocked` ausente, exactamente la combinación que cierra el bridge. Sin un seam, **hacer QA manual del handover deja la suite roja de forma permanente** hasta que alguien borre el simulador.

Por eso `isDomainOpenForBridge` exceptúa `SwiftDataConfiguration.isRunningTests` — y NADA más ancho: `isUITesting` dejaría el sello inerte en los XCUITest (que sí deben poder ejercitarlo) y un `#if DEBUG` lo mataría en release, que es justo donde el fix actúa. Pinneado en los dos sentidos (`bridgeGate_runnerSeam_isNarrow`, `isDomainOpenForBridge_underTestRunner_ignoresTheSeal`). La rama sellada del adaptador no se cubre por comportamiento en unit test por construcción: la cubren el pure logic, el source-scan y el simulador.

## Verificación

**Simulador** (iPhone 17 Pro, `Yala Dev` / Debug-Dev, conteos por `sqlite3` sobre `YalaGroups-UITest.store` y `YalaModel-UITest.store`):

- Dispositivo normal (sin sello): gasto de grupo creado ⇒ **2 TX bridgeadas + 1 draft**. Sin regresión.
- Tras «Soy nuevo»: Grupos `0/0/0/0/0`, personal `0`, **sello `true`**, `groupsBetaUnlocked` ausente, y B aterriza con el gate «Función en beta» cerrado.

**Tests**: 5070 en 475 suites, verdes en dos corridas consecutivas (el fallo previo era determinista, no de orden). Nuevos en `YalaTests/HandoverGroupsDomainTests.swift`:
purga de los 5 modelos + `GroupBridgePreference` · emparejamiento obligatorio purga↔reset de tokens · corpus personal intacto · barrido de prefs en ambas direcciones · sello escrito por la purga · `isBridgeAllowed` sin sello permite SIEMPRE (el test que impide el falso negativo) · con sello obedece a la puerta · el wipe normal preserva el sello · adaptador runtime. Y `HandoverGroupsWiringTests` (source-scan, porque el pipeline del bridge está en la Lista Negra R8): los 2 caminos de fresh-start purgan, el wipe de Ajustes JAMÁS, los 2 puntos de creación del bridge están gateados, `checkHasExistingData` cuenta grupos y bridgeadas.

**Sin tocar**: `DataWipePreservesGroupsTests` y `GroupsSignOutFlowTests.personalWipe_doesNotTouchGroups` siguen verdes tal cual — el alcance de `wipeAllUserData` no cambió.

## Sobre el invariante (a) — no aplica al dominio Grupos

«Borrar filas con el mirror montado exporta los deletes a iCloud» habla del store **personal**. El de grupos monta `cloudKitDatabase: .none` (`SwiftDataConfiguration.swift:749`, con el racional en `:733-741`) ⇒ SwiftData no puede exportar nada, y el único camino de export es el enqueue EXPLÍCITO (`SplitSyncManager.markPendingDeletion:1096`, alcanzado solo desde acciones de usuario en `GroupExpenseService`). Prueba viva: `deleteGroupCache` borra los 5 tipos con cero enqueue y es la primitiva del sign-out de iCloud. El drenaje por History que SÍ convertiría deletes en tombstones (`GroupsSyncClient.performDrain`) está doblemente amurallado por `groupsBackendEnabled` (false en release) y por `isBackendGroup`.

**Condición crítica respetada**: la purga NO usa `GroupService.leaveGroup` / `performLocalCleanupAndDelete` como primitiva — esos llaman `leaveShare`, que sacaría al usuario del grupo de otro owner DE VERDAD.

## Device QA pendiente

1. **Re-fetch tras el reset de tokens** (el sim no tiene CloudKit): tras «Soy nuevo», relanzar y confirmar que las zonas del Apple ID vuelven a bajar (no debe haber pérdida) y que NADA de eso aparece en Panel/Inbox/presupuestos/reportes/widgets mientras el gate esté cerrado.
2. **A legítimo que vuelve**: mismo humano tras «Soy nuevo» → mete el código beta → sus grupos están completos otra vez (vinieron de CloudKit). Comprobar qué NO vuelve: `groupPrefs_*` (cuenta de liquidación por moneda) y los overrides del bridge, que no viven en la nube.
3. **Miembro de un grupo de otro owner**: su espejo local se purga y se re-baja de la shared DB; el grupo remoto queda intacto y él sigue siendo miembro.
4. **Grupo owner nunca subido** (`ckSystemFieldsData == nil`, ventana export-only): se pierde al purgar. Es el precio del «borrar todo» que el usuario confirmó, y el mismo que ya asume `performAccountSwitchCleanup` — verificar que no deja zona huérfana visible para otros.

## Residuales y diferidos

- **Adoptar Grupos adopta el dominio del Apple ID.** Si B teclea el código beta, verá los grupos que ese Apple ID tenga: los grupos viven en el iCloud del dispositivo, como las Fotos. El cierre real es identidad por CUENTA (Grupos→backend v1) o un **sello de corpus** (`groupsCorpusID` como fila del store personal + campo device-local en `SplitGroup` + pantalla «estos grupos son de una sesión anterior → recuperar / borrar»), que da aislamiento sin destruir nada. Evaluado y descartado para este fix por coste (modelo nuevo + migración + UI) y por solaparse con [[groups-backend-v1]].
- **Camino de la oferta de restore**: ahí la invitación abre el dominio en cuanto se acepta el enlace, así que el gate queda abierto y un re-fetch puede devolver los grupos del anterior. Sin sello de corpus no hay cierre para ese camino.
- **`SplitSyncManager.initialize()` sigue sin gate** (`AppBootstrapper.swift:308` — hallazgo `INV-03` de la auditoría): el motor arranca y crea/baja zonas sin acción del usuario, incluso con el tab cerrado. Gatearlo cerraría el re-fetch de raíz y serviría a la meta «no seguir generando container de grupos en iCloud», pero toca `acceptShare` (necesita el `container` que crea `initialize`) y el flujo de unión ya tuvo bugs (caso Pia). Fuera del alcance de este fix.

## Implementación

**2026-07-27 · commit `31dded30`** (branch `2.0.5`) — 10 archivos, 647 inserciones. Gate verde: build ×2 sin warnings nuevos, 5070 unit tests, 10 XCUITest de las áreas tocadas, índice de QA validado.

Decisiones técnicas y su porqué (lo que el código no cuenta solo):

1. **Frontera por CAMINO, no por función.** Se descartó tocar `wipeAllUserData`: su alcance está prometido en el copy («Vaciar datos… tus grupos se conservan») y pinneado por dos tests. La purga cuelga solo de los dos «empiezo de cero» del Welcome, que es donde el usuario declara que aquí empieza otra persona. Los dos tests que fijan la exclusión siguen verdes sin tocarlos.
2. **Sello en vez de gate general.** La primera versión cerraba el bridge siempre que Grupos estuviera cerrado, y puso 14 tests del bridge en rojo: `groupsBetaUnlocked` es `false` por defecto en toda la cohorte que aún no abrió Grupos, así que el fix se habría convertido en «mis gastos de grupo no aparecen», en silencio. El sello invierte el default: permitir salvo relevo declarado.
3. **Reset de tokens emparejado con el borrado de filas.** Borrar filas dejando los change tokens intactos deja a CloudKit convencido de que el dispositivo está al día ⇒ esos records no se reenvían nunca. El emparejamiento es lo que separa «purga» de «pérdida de datos permanente», y tiene su propio test.
4. **Seam `isRunningTests` en el gate.** El host de los unit tests comparte el `UserDefaults` del simulador: sin el seam, hacer QA manual del handover deja la suite roja hasta que alguien borre el simulador. Verificado: el contenedor del host tenía el sello escrito.
5. **`checkHasExistingData` pasa a fallar CERRADO** (cierra `E1-N4` de la auditoría). Ante un fetch fallido, asumir que hay datos cuesta una confirmación de más; asumir que no los hay se los deja al usuario siguiente.

## Archivos

| Archivo | Cambio |
|---|---|
| `Yala/Utils/DataWipeService.swift` | `wipeLocalGroupsDomain` + `removeGroupsDomainPreferenceKeys` + sello; exclusión del sello documentada en `removeUserPreferenceKeys` |
| `Yala/Services/Groups/SplitSyncManager.swift` | `resetLocalGroupsSyncState()` extraído de `performAccountSwitchCleanup` |
| `Yala/App/Logic/GroupsBetaGateLogic.swift` | `isDomainOpen` + `isBridgeAllowed` (SSOT del predicado) |
| `Yala/Services/Groups/GroupTransactionBridge.swift` | `isDomainOpenForBridge` + guard en `bridgeExpense` y `bridgeSettlement` |
| `Yala/App/AppBootstrapper.swift` | guard en `retryPendingBridges` |
| `Yala/App/ContentView.swift` | `checkHasExistingData` cuenta grupos + bridgeadas; purga en los 2 caminos de fresh-start |
| `Yala/App/Services/AppPreferences.swift` | key `groupsDomainSealedForFreshStart` |
| `YalaTests/HandoverGroupsDomainTests.swift` | nuevo (14 tests: comportamiento + pure logic + source-scan; ninguno toca `UserDefaults.standard`) |
| `qa/coverage-index.json` | `session-sign-out`, `groups-bridge-personal`, `groups-cross-device-sync`, `onboarding-flow` |

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` se dejan (`needs-testing`: el ticket es mixto). **No rename.** YalaWiki no tiene `status: obsolete` (convención Backlog: open / backlog / in-progress / needs-testing / done / reopened / discarded). No se cierra el ticket entero.

**D por AC (no el ticket entero):**

| AC | Clase |
|---|---|
| Wipe local (`wipeLocalGroupsDomain` + sello) | **D** — ya verificado en sim (histórico; no re-corrido hoy) |
| Device QA 1: re-fetch CK tras reset de tokens | **D** — `SplitSyncManager` 404 |
| Device QA 2: A vuelve + código beta 1050 | **D** — gate 1050 retirado |
| Device QA 3: miembro / shared DB | **D** — transporte CK 404 |
| Device QA 4: grupo owner nunca subido / export-only | **D** — ventana CK 404 |

**Evidencia del wipe local (histórico):** el propio ticket declara e2e en simulador (iPhone 17 Pro, Yala Dev, seed `grupos`, conteos sqlite). Automatización viva: `YalaTests/HandoverGroupsDomainTests.swift` (`wipeLocalGroupsDomain_deletesAllFiveSplitModelsAndBridgePreference`, sello, `isBridgeAllowed`). Commit `31dded30` existe.

**Premisa FALSE / obsoleta (D) — residual CK:** «re-fetch de zonas CloudKit tras `SplitSyncManager.resetLocalGroupsSyncState`» / shared DB / ventana export-only / «meter el código beta 1050». `SplitSyncManager.swift` → **404**. `DataWipeService` ya no nombra ese tipo; `wipeLocalGroupsDomain` recibe `resetSyncState` como callback. El gate del código 1050 se retiró: `ContentView` (tab Grupos) monta `GroupsContainerView()` y en `onAppear` llama `GroupsDomainAdoptionMarker.recordEntry()`.

**Sigue TRUE (no es residual CK):** `DataWipeService.wipeLocalGroupsDomain` + sello `groupsDomainSealedForFreshStart`; `GroupsDomainAdoptionLogic.isBridgeAllowed`.

**REMAINS:** los AC **escritos** de device QA eran el re-fetch CK y el código beta. Eso es D. Un residual nuevo («rematerializar grupos **backend** tras empiezo de cero sin fugar al Panel») **no está** en la lista del ticket y no se añade. El leftover de producto ya escrito —«adoptar Grupos adopta el dominio»— ahora es entrar al tab, no el código beta; no se reabre como AC nuevo.

No tratar este ticket como cerrado. Detalle y cola: [[QA-TRIAGE-SIMULADOR-VS-DEVICE-2026-08-17]].

migrated from YalaWiki Backlog/qa_handover-dispositivo-grupos-fuga.md @ 1934e8ad
