---
id: cloud-tab-does-not-say-this-phone-cannot-sync-personal-data
status: done
priority: low
area: "nube, attest, copy"
created: 2026-09-15
updated: 2026-09-15
source: "hallazgo de `groups-tab-does-not-say-this-phone-cannot-sync-groups` (2026-09-15): Grupos ya tiene su aviso fijo, lo personal no"
---

# Con la cuenta en la nube, un teléfono sin App Attest no se entera de que sus movimientos no suben

## El problema, en lenguaje de usuario

Mis datos viven en la nube. Apunto gastos desde este teléfono y no llegan a mis otros dispositivos. La app no me dice
nada: solo me entero si intento cerrar sesión.

## Lo medido (2026-09-15)

- Desde `groups-tab-does-not-say-this-phone-cannot-sync-groups`, la pestaña **Grupos** sí enseña un aviso fijo mientras
  el veredicto de App Attest es terminal, y el store avisa cuando la racha cambia
  (`GroupsAttestStreakStore.didChangeNotification`). La mitad personal no tiene nada equivalente.
- El veredicto terminal del canal personal solo emite el canario `cloudSyncBlockedByAttestUnavailable`
  (`CloudSyncRuntime.performCycle`) y para el runtime, sin nada visible. `SyncStatusBanner` es el de iCloud, no el de
  la nube.
- Lo único que hoy se lo dice a esa persona es el cierre de sesión en Ajustes
  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, #175), que además le ofrece exportar. Igual
  que en Grupos antes de este ticket: el aviso llega cuando la persona intenta un gesto que puede perder algo.
- **La racha es la misma para los dos canales** y la escribe también el motor personal, así que el dato para decidirlo
  ya está: no hay que medir nada nuevo.

## Lo que hay que decidir (Jürgen)

1. **Un aviso fijo, espejo del de Grupos**, en la superficie que corresponda a lo personal (¿el Panel? ¿Ajustes?), con
   el copy del cierre: «Este teléfono no puede sincronizar tus datos» (`settings.signOutAttestTitle`, ya existe) más
   qué puede hacer. En Grupos el «qué hacer» es usar otro teléfono; aquí hay uno más: **exportar**, que el #175 ya tiene
   construido.
2. **Dónde.** Grupos tenía una pestaña propia. Lo personal no: un aviso fijo en el Panel es mucho más visible y mucho
   más intrusivo.
3. **Dejarlo**: el cierre de sesión ya lo dice, y el canario dirá cuánta gente está así.

## Relación con otros tickets

- `groups-tab-does-not-say-this-phone-cannot-sync-groups` — el hermano de Grupos, hecho. Su
  `GroupsAttestTabNoticeLogic` y el aviso del store son el molde.
- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — el cierre honesto y la exportación.
- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale el veredicto terminal.

---

## Lo hecho (2026-09-15)

**Quien tiene sus datos en la nube y este teléfono no consigue App Attest ya se entera solo.** Mientras el veredicto
sea terminal, encima del Panel hay un aviso fijo con el **mismo título** que el cierre de sesión —«Este teléfono no
puede sincronizar tus datos»— y un cuerpo que dice las tres cosas que importan: qué pasa, que lo apuntado **sigue
guardado en este teléfono**, y qué hacer (usar otro). Sin X y sin botón: describe un estado que sigue ahí después de
leerlo, y reintentar es justo lo que lleva un día fallando.

### Son DOS superficies, y la segunda no es un extra: **mentía**

La decisión 2 del ticket («¿el Panel? ¿Ajustes?») resultó tener una respuesta medida. La superficie de Ajustes que
habría sido la elección menos intrusiva —`StorageSettingsView.syncStatusSection`, el estado de sync de «Dónde viven
tus datos»— **pintaba un check verde «Todo al día» con el motor parado**: `CloudMigrationController.refreshSyncBanner`
solo pone `syncNeedsSignIn` con el runtime en `.stoppedUntilSignIn`, y el attest terminal lo deja en
`.stoppedUntilRelaunch`, que caía al `else`. El `else` fallaba **abierto**: daba por bueno todo estado que nadie
enumeró.

Así que van las dos, con una sola decisión y un solo copy: el Panel, porque el criterio de éxito era «que lo vea sin
tener que ir a cerrar sesión» y esa sección de Ajustes está aún más lejos que el propio botón de cerrar sesión; y la
sección de Ajustes, porque dejarla diciendo lo contrario a tres toques sería la app contradiciéndose. La rama del
attest va **antes** que la de `syncNeedsSignIn`: re-firmar no arregla un attest roto.

### Son CUATRO condiciones, no «mientras el veredicto sea terminal»

La racha describe al TELÉFONO y la escriben los dos motores, así que el enunciado literal del ticket le mentiría a
tres poblaciones. Cada una se excluye con su término (`CloudAttestNoticeLogic`):

| Término | A quién excluye |
|---|---|
| `verdictIsTerminal` | — (el hecho) |
| `storageMode == .cloud` | **la mayoría de la gente**: con los datos en su iCloud privado, la racha puede ser entera de Grupos |
| `uiState == .cloudActive` | quien está **en mitad de una reversa, un cutover o un relanzamiento pendiente** |
| `hasSession` | quien no tiene cuenta en la nube |

El segundo va por `storageMode` y **no** por `CloudRemoteFlags.cloudModeEnabled`, por lo mismo que el aviso de Grupos
lee la capacidad compilada: el flag remoto es fail-closed ante un snapshot ausente, y `storageMode` es testigo directo
del corpus de este teléfono.

### La review adversarial cazó tres cosas mías, y dos cambiaron el producto

1. **El copy mandaba a un paywall.** Decía «en Perfil puedes exportar tus datos», y el wizard de exportación **capa los
   períodos largos a quien no es Pro** (`DetailPeriod.isProExportPeriod`: `.allTime` lleva candado, y el `onAppear`
   rebaja la selección a `.last30Days`). Como el Modo Nube es gratis para siempre, la población que ve este aviso
   incluye a no-Pros: el aviso les descubría un paywall justo al enterarse de que sus movimientos no suben. La
   exportación completa y **gratis** sí existe —`exportAllTransactionsBeforeLosingThem`, que el #175 construyó para
   esta misma avería— pero solo se alcanza intentando cerrar sesión. Decisión: **el copy no menciona exportar**. El
   aviso describe un estado, no una pérdida inminente —los movimientos están en el teléfono—, y la exportación se
   ofrece donde de verdad se pierden, que es el cierre de sesión. Queda ticket propio para si debe ofrecerse aquí.
2. **Faltaba la cuarta condición.** Sin `channelIsStable`, quien vuelve a iCloud **precisamente porque sus datos
   dejaron de subir** veía en Ajustes la barra «Volviendo a iCloud» y a la vez, en el Panel, «usa otro teléfono» — el
   consejo contrario a lo que estaba haciendo. Las dos superficies no tenían la misma puerta: Ajustes la tenía
   implícita en su `case .cloudActive`, el Panel no tenía ninguna.
3. **`hasSession` lee el Keychain, y se evaluaba siempre.** Es un ARGUMENTO de función, así que Swift lo evalúa antes
   de llamar y el `&&` de `showsNotice` no lo cortocircuitaba: cada re-evaluación del body pagaba un
   `SecItemCopyMatching` —también en el 100 % de teléfonos que nunca tendrán veredicto—, en el scroll del Panel y a
   ~1 Hz en «Dónde viven tus datos» por el tick del journal. El propio repo ya protege esa misma lectura con un
   `guard hasSession` en esa misma pantalla. Ahora hay un `guard verdictIsTerminal` delante.

### Ficheros

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Logic/CloudAttestNoticeLogic.swift` | **Nuevo.** La decisión, pura: las cuatro condiciones. |
| `Yala/App/Views/Shared/CloudAttestNoticeBanner.swift` | **Nuevo.** El contenido, la decisión con el entorno vivo y el cableado reactivo — un solo sitio cada uno, porque hay dos superficies. |
| `Yala/App/Views/Panel/PanelView.swift` | El aviso, primero de la pila de banners (antes del hero), y su `@State` + watcher. |
| `Yala/App/Views/Settings/StorageSettingsView.swift` | La tercera rama de `syncStatusSection`, delante de `syncNeedsSignIn`. |
| `Yala/Utils/L10n.swift` + 16 `.lproj` | `settings.attestTerminalBanner`, el cuerpo. El título se reusa. es-AR en voseo. |
| `YalaTests/CloudAttestNoticeTests.swift` | **Nuevo.** La tabla + el source-scan del cableado y de las dos superficies. |
| `YalaUITests/Flows/CloudAttestPanelBannerUITests.swift` | **Nuevo.** El negativo sobre la población `.icloud`. |
| `qa/coverage-index.json`, `.claude/rules/gateway-attest.md` | Áreas `cloud-sync-runtime` y `cloud-migration-ui`, y la regla durable — que decía «el canal personal no tiene banner». |

## Cómo se verificó

- **Unit** — `CloudAttestNoticeTests`: las 16 combinaciones de las cuatro condiciones, más un source-scan que la tabla
  NO ve (de dónde salen los argumentos, los tres momentos del recálculo, el `guard` del Keychain, y que las **dos**
  superficies pintan el mismo componente gateado por la misma decisión).
- **XCUITest** — `CloudAttestPanelBannerUITests`: con la racha terminal sembrada **por el camino de producción** y
  sesión viva, un teléfono en `.icloud` NO ve el aviso.
- **12 mutantes, 12 muertos**, y dos de ellos son mediciones, no confirmaciones: (a) el que fija `personalDataLivesInCloud: true`
  hace **salir** el aviso y pone rojo el XCUI ⇒ el camino positivo está verificado aunque no haya caso positivo; (b) tras
  añadir la cuarta condición, tumbar **solo** `storageMode` deja el XCUI en **verde** —lo cumple el término nuevo—, así
  que ese caso protege el canal entero y no fija un término concreto. Está escrito en su docblock, medido y no supuesto.
- **Visual**: capturado en el simulador con el mutante puesto — el aviso sale arriba del todo, en glass, sin solapar.
- **Gate**: build ×2 sin warnings nuevos · unit **7019 en 724 suites** · XCUITest **8 clases, 20 casos**, centinela «estuviste
  solo» (96 muestreos) · audit limpio · índice OK.

## Residuales aceptados

- **El agujero que el aviso NO cubre, y es el más caro**: el canal personal **nunca enruta su propio 401 de attest a
  la racha** (`SyncPushClient`/`SyncPullClient` mapean todo 401 a `.sessionExpired`, sin la rama
  `isAttestRequired` que sí tiene Grupos), y además `resolveAttest` borra la racha en cada ciclo que consigue un token
  —incluido uno cacheado—. A quien el gateway le rechaza el token de sesión aunque el teléfono lo acuñe bien, la app
  le sigue diciendo «vuelve a iniciar sesión». Ticket propio.
- **El spinner «Descargando tus datos…» puede convivir con el aviso**, girando para siempre: `CloudHydrationLogic`
  no mira el attest y el primer pull no completa nunca con el runtime parado. Preexistente. Ticket propio.
- **Hereda los dos del aviso de Grupos**: va sin el testigo del ciclo (`lastCycleStoppedAtAttestGate`) —exigirlo lo
  dejaría mudo justo en el caso del ticket— y el cruce de las 24 h con la app abierta espera al siguiente gesto.
- **Con `syncNeedsSignIn` a la vez**, en Ajustes gana la rama del attest y desaparece el CTA de volver a entrar. Es la
  elección correcta (re-firmar no arregla un attest roto) pero deja a esa persona sin botón; población estrecha.
- **`storage.status.cloudBody`** («…y se sincronizan en todos tus dispositivos») sigue dos tarjetas encima del aviso.
  No se toca: junto con «este teléfono no puede», la frase da la información completa — y es justo lo que el aviso
  recomienda, usar otro.
- **Sin device-QA**: el aviso es visual y determinista, y verlo de verdad exige un teléfono en modo nube con el attest
  roto más de un día, que no se monta aquí.
