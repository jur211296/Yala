---
id: welcome-private-fresh-start-skips-icloud-check
status: qa
priority: high
area: "onboarding, modo-nube"
created: 2026-09-09
source: "device-QA guiado por Jürgen (2026-09-09) · ADR 2026-09-09 «Sesiones — dos ejes» §9"
updated: 2026-09-23
---

# «Primera vez → privado» en una instalación fresca no valida iCloud: reinicia y hace el onboarding encima de los datos viejos

## El síntoma, en lenguaje de usuario

Tengo meses de datos en mi iCloud privado. Desinstalo Yala y la vuelvo a instalar. Toco «Es mi
primera vez en Yala» → «Tu cuenta en tu iCloud privado». La app me dice «Un último paso: reabre
Yala». La reabro y me mete **directo al onboarding completo, como si fuera nuevo** — sin preguntarme
nada — mientras por debajo iCloud va bajando todos mis datos viejos. Termino con un onboarding «de
cero» encima de un histórico intacto que nadie me dijo que existía.

## Lo que Jürgen espera (dictado el 2026-09-09, es la regla del ADR §9)

1. Apenas elijo *privado*, la app **valida si hay datos en el iCloud de este dispositivo**.
2. Si hay: alert con **doble confirmación**.
   - Borrar → **se borra** y **pide reinicio**. Tras el reinicio ya no existen datos de iCloud en el
     dispositivo y abre el **onboarding completo de cero**.
   - Cancelar → vuelve a la elección privado / nube.
3. Si no hay: sin alert, directo al onboarding completo.
4. **Nunca** se muestra la pantalla de reinicio sin haber hecho antes esa validación.

## Lo medido (2026-09-09, árbol `3a94604e`)

- La instalación fresca monta el store personal **neutro**, sin espejo de iCloud
  (`SwiftDataConfiguration.personalStoreDecision`, `Yala/Utils/SwiftDataConfiguration.swift:341`, vía
  `isFreshInstallForNeutralMount` `:266-277`). En ese store no hay filas, así que cualquier detector de
  «hay datos» que cuente filas locales (`ContentView.checkHasExistingData`, `Yala/App/ContentView.swift:1118-1141`)
  responde `false` por construcción.
- La rama privada sale del Welcome por el portal `leaveWelcome` de `WelcomeFlowContainer`
  (`Yala/App/Views/Onboarding/WelcomeFlowContainer.swift`, `handleNewOption` → `.privateAccount`):
  como `.privateOnboarding` **requiere espejo** (`WelcomeMirrorRelaunchLogic.requiresMirror`) y el mount
  es neutro, persiste el destino (`WelcomePendingDestinationStore.set`) y muestra «reabre Yala». **El
  callback `onSelectPrivateAccount` —el único que consulta `hasExistingData` y levanta el alert
  (`startFreshPrivateOnboarding`, `ContentView.swift:1662-1671`)— no llega a ejecutarse.**
- Al reabrir, `presentNextOnboardingScreen` consume el destino y abre el onboarding **sin volver a
  comprobar nada** (`ContentView.swift:1390-1393`: `case .privateOnboarding: showOnboarding = true`).
  Mientras tanto el espejo recién adjuntado importa el contenedor de iCloud por debajo.
- El alert «Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?» solo
  aparece cuando los datos ya estaban en el dispositivo al elegir (p. ej. tras cerrar sesión sin
  desinstalar). Los tickets `welcome-start-fresh-wipes-before-ask` y
  `welcome-fresh-start-alert-leaves-blank-screen` hablan de ESE alert; ninguno cubre este caso.

## Alcance

- La validación tiene que preguntar a **iCloud**, no al store local: es la misma búsqueda que ya hace
  «Restaurar desde iCloud» (`WelcomeRestoreView.startSearch` → `ICloudAccountSummary`; hoy corre
  DESPUÉS de reabrir porque también requiere espejo). Decidir en el diseño si la búsqueda se hace
  antes del relanzamiento con una consulta directa a CloudKit (sin adjuntar el espejo al store) o si
  el relanzamiento pasa a ser «reabrir para comprobar» y la validación + alert corren al reabrir,
  ANTES del onboarding. En ambos casos se cumple el punto 4: la pantalla de reinicio ya no es ciega.
- Borrar = el mismo `DataWipeService.wipeAllUserData` + `wipeLocalGroupsDomain` +
  `clearResidualPreferencesForFreshStart` del alert actual (`ShellDataAlertsModifier.swift:89-127`),
  y después el reinicio que pide el ADR. Al reabrir: onboarding completo, sin restos.
- Cancelar = volver al chooser privado/nube (el de dos cards, hoy visible en prod:
  `cloudOnboardingChoiceRolloutPercent: 100` medido por curl al `/config` de producción).
- Doble confirmación: el alert existente + una segunda («¿Seguro? Esto es definitivo.» ya existe
  para «Vaciar datos»: `settings.wipeDataSecondConfirmTitle`).

- **Sin iCloud disponible (K)**: no se puede validar; se informa (como «Restaurar» con `.iCloudDisabled`)
  y se sigue en local (`.localNoMirror`). Nunca se bloquea por no poder preguntar.
- **Kill-safety:** matar la app entre «borrar» y el reinicio no puede dejar datos a medio borrar ni un
  onboarding encima de ellos: armar el borrado y el destino como hace el boot-wipe del cierre de sesión
  (`SwiftDataConfiguration.swift:689`), y consumirlos al arrancar.

## Criterios de aceptación

- [ ] Instalación fresca + iCloud con datos → «Primera vez → privado» muestra el alert ANTES de
      cualquier pantalla de reinicio. Nunca onboarding directo.
- [ ] Borrar (doble confirmación) → reinicio → onboarding completo con CERO filas de usuario en el
      store y CERO registros en el contenedor de iCloud del Apple ID (verificable con «Restaurar desde
      iCloud» en otra instalación: `notFound`).
- [ ] Cancelar → chooser privado/nube, con los datos de iCloud intactos.
- [ ] Instalación fresca + iCloud vacío → onboarding directo (con el reinicio que haga falta), sin alert.
- [ ] Sin iCloud en el dispositivo → aviso + onboarding local; con iCloud activado después, el espejo se
      adjunta como hoy.
- [ ] Matar la app justo tras confirmar «borrar» → al reabrir, el borrado se completa y abre el onboarding
      limpio (breadcrumb del arm consumido).
- [ ] Los dos tickets del alert (`welcome-start-fresh-wipes-before-ask`,
      `welcome-fresh-start-alert-leaves-blank-screen`) siguen verdes en el recorrido nuevo.

## Cómo se prueba

- Lógica de decisión (¿validar dónde y cuándo?, ¿qué destino tras borrar?) → `nonisolated enum` puro con
  unit tests, como `WelcomeMirrorRelaunchLogic`.
- El recorrido entero es **device-QA** (CloudKit no existe en simulador): iPhone con datos en iCloud
  privado → desinstalar → instalar desde TestFlight → los cuatro casos de arriba.

## Fuera de alcance

- La elección nube (rama `.cloudAccount`) no cambia.
- Cambiar qué borra «Vaciar datos» (ADR §6) es de `session-exits-one-verb-per-session`.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba**, incluida la
disyuntiva que el alcance dejaba abierta.

- **La validación pregunta a CloudKit ANTES de relanzar**, con una consulta directa al contenedor y
  **sin adjuntar el espejo al store**. Queda descartado el camino «reabrir para comprobar»: el alert sale
  en el mismo gesto en que se elige *privado*, así que no hay pantalla de reinicio ciega ni datos bajando
  por debajo mientras el usuario decide. Es la opción con más código nuevo y se asume.
- **Copy propio, y tiene que nombrar iCloud.** No se reusa «Detectamos datos previos en tu dispositivo»:
  el texto debe decir que los datos están en **tu iCloud** y que borrarlos **los quita de iCloud**, no
  solo de este móvil. Es irreversible y el copy tiene que decirlo. Va a los 7 idiomas; leer `BRAND-VOICE.md`.
- **El alert enseña CIFRAS y ofrece restaurar.** Muestra qué hay («encontramos N movimientos desde
  <fecha>», del resumen que ya devuelve la búsqueda de «Restaurar») y añade una **tercera salida**:
  «esto es mío, restauralo» → «Restaurar desde iCloud». O sea, el alert tiene tres caminos: borrar (con
  segunda confirmación), restaurar, cancelar. Ese tercer camino hay que probarlo como los otros.
- **El caso «sin iCloud» se cubre AQUÍ, no en un ticket aparte.** Hueco encontrado en esta pasada: hoy,
  si no hay iCloud se sigue en local sin validar, y cuando el usuario activa iCloud más tarde el espejo
  se adjunta y **los datos viejos caen encima del onboarding recién hecho** — el mismo bug por la puerta
  de atrás. Decisión: **cuando el espejo se adjunte tarde y traiga datos previos, correr la misma
  validación y el mismo alert en ese momento**. Añádelo a los criterios de aceptación y a la matriz.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir código (2026-09-10)

Todo lo de abajo se midió en el árbol de esta sesión (`9a954c8f`). **Las coordenadas del cuerpo del
ticket envejecieron** y se re-greppearon: `checkHasExistingData` está en `ContentView.swift:1162-1185`
(el ticket decía `:1118-1141`), `startFreshPrivateOnboarding` en `:1766-1786` (decía `:1662-1671`) y el
consumo del destino pendiente en `:1434-1450` (decía `:1390-1393`). El bug se confirma tal cual está
descrito: `handleNewOption(.privateAccount)` → `leaveWelcome(.privateOnboarding)` → `shouldRelaunch` da
`true` con el mount neutro → persiste el destino y **nunca llama a `onSelectPrivateAccount`**, que es el
único callback que consulta `hasExistingData` y levanta el alert.

### D1 · Dónde vive la validación: un STEP del container, no un `.alert` de `ContentView`

**Decidido: step.** No es preferencia — es lo único que funciona. Dos hechos medidos lo cierran:

- **Un `.alert` desde el anchor de `ContentView` DESMONTA el cover del Welcome.** Está medido con traza
  en `ShellDataAlertsModifier.swift:63-88` (`DIAG gated.set: true -> false`), y ese fue el bug de la
  pantalla negra del 2026-09-03. Aquí sería peor: el alert tiene que poder volver al chooser, y el
  chooser ya no existiría.
- **`WelcomeHeroReentryTests` prohíbe `.alert(` en `WelcomeFlowContainer.swift` por source-scan**, y
  `GroupsOrganizerBranchTests.gateIsAScreenAndNeverAnAlert` lo pinnea otra vez.

El molde es `.groupsGate` / `WelcomeGroupsGateView`, que es exactamente esta forma: una puerta que mide
algo asíncrono, pinta «comprobando», y sale por el portal si abre. La **doble confirmación** va como
`.confirmationDialog` DENTRO de la vista del step (lo mismo que ya hace `WelcomeRestoreView` con
`showStartFreshConfirm`), así que el pin del container sigue verde.

### D2 · Cómo se pregunta a iCloud: `CKDatabase.recordZoneChanges`, y es el primero del repo

La decisión de Jürgen («consulta directa al contenedor, sin adjuntar el espejo») no tenía dónde
apoyarse: **en todo `Yala/` hay tres call-sites de CloudKit y ninguno lee registros** —
`allRecordZones()` como ping (`iCloudSyncService.swift:526`), `userRecordID()` para la identidad de
Grupos, y `CKNotification` para clasificar un push. Cero `CKQueryOperation`, cero
`CKFetchRecordZoneChangesOperation`.

- **No se usa `CKQueryOperation`**: consultar `CD_TransactionItem` por query exige que el esquema tenga
  el índice `queryable`, y eso no está garantizado para los tipos que crea
  `NSPersistentCloudKitContainer`. Un fallo ahí se vería solo en device.
- **Sí `recordZoneChanges(inZoneWith:since:desiredKeys:)`**: no depende de índices, pagina con
  `moreComing` y con `desiredKeys` acotado baja payloads mínimos.
- **La zona no se hardcodea.** Se enumera con `allRecordZones()` y se filtran las del mirror por
  prefijo. El literal `com.apple.coredata.cloudkit.zone` no aparece hoy en producción —`CKIdentityCapture`
  resuelve la zona por FK— y este ticket no lo introduce como verdad única.
- **`CKContainer.accountStatus()` NO se usa**, y no es un olvido: hay una decisión escrita dos veces
  (`ICloudCutoverGateLogic.swift:79-81`, `MigrationWorkExecutor.swift:172-175`) de no introducir una
  segunda verdad sobre iCloud. El predicado sigue siendo `SwiftDataConfiguration.isICloudAvailable()`.

### D3 · Qué significa «borrar»: la zona del mirror, no `wipeAllUserData`

**El cuerpo del ticket y su criterio de aceptación se contradicen, y manda el criterio.** El cuerpo dice
reusar `DataWipeService.wipeAllUserData`; el AC exige «CERO registros en el contenedor de iCloud».
Medido: en instalación fresca el store local está **vacío** y el mirror **no está adjunto**, así que
`wipeAllUserData` —que borra FILAS, `DataWipeService.swift:62-210`— no tiene nada que borrar y deja
iCloud intacto. Reusarlo cumpliría la letra del cuerpo y fallaría el AC.

Se borra la **zona del mirror en CloudKit** (`modifyRecordZones(saving:deleting:)`), que es lo único que
deja el contenedor a cero sin adjuntar el espejo. `NSPersistentCloudKitContainer` recrea la zona vacía
al arrancar con el mirror puesto — es el camino estándar. Sigue corriendo
`clearResidualPreferencesForFreshStart` (las prefs del iKV sobreviven al uninstall y son el otro resto),
y **no** se toca el dominio de Grupos: vive en otro contenedor
(`iCloud.com.jurgenschmidt.yala.groups`) y el ADR §6 dice que «Vaciar datos» nunca lo toca.

### D4 · Kill-safety: arm + neutro durable, con los mecanismos que ya existen

El molde es `performSignOutWipeIfArmed` (`SwiftDataConfiguration.swift:639-775`): **el arm se limpia al
final**, así que un kill a mitad reintenta y las operaciones son idempotentes (borrar una zona ausente
es un no-op).

Lo que este caso añade, y sin ello el arreglo tendría el mismo bug que arregla: el mount neutro **dura
un solo arranque** (`isFreshInstallForNeutralMount` exige que el archivo del store no exista, y el
primer arranque lo crea). Si matan la app durante el borrado, el arranque siguiente montaría
`.iCloudMirror` y el espejo importaría justo el corpus que se estaba borrando. Por eso el arm del
borrado arma **también** `armNeutralMount`, cuyo predicado
(`shouldMountNeutralDurable = armado && !hasShownWelcomeChooser`) encaja exacto: en el step del gate
nadie ha marcado el chooser todavía —lo marcan las salidas, no la puerta—, y en cuanto el usuario cruza
el portal la marca queda inerte sola. El anti-bucle es el término que ya tenía.

### D5 · El caso «sin iCloud» (K), y lo único que se le pregunta a Jürgen

- **En el momento de elegir**: `isICloudAvailable()` es `false` ⇒ no se puede validar ⇒ se informa y se
  sigue (matriz: `.localNoMirror`). Decidido en el ticket, sin ambigüedad.
- **No se puede preguntar aunque haya iCloud** (red caída, error de CloudKit): se ofrece **reintentar**,
  como hace `WelcomeRestoreView` con `.error`. No se bloquea y no se sigue a ciegas: seguir con el
  mirror adjunto y la red caída reproduce el bug en cuanto vuelva la red.
- **El espejo que se adjunta tarde** (K → el usuario activa iCloud después): la decisión dice «correr la
  misma validación y el mismo alert en ese momento». Las tres salidas del alert se traducen bien salvo
  una: **«cancelar» no tiene a dónde volver**, porque ahí no hay chooser. Preguntado a Jürgen el
  2026-09-10 con tres opciones; el resto del ticket no depende de la respuesta.

---

## La review adversarial, y lo que cambió del diseño (2026-09-10)

Cuatro lentes independientes sobre el diff (flujo y kill-safety · CloudKit y tabla de mounts · SwiftUI y
presentaciones, leyendo `swiftui-ds.md` CONTRA el diff · tests y cobertura, con `testing.md`).
**Diecinueve hallazgos, y los diecinueve eran de diseño propio.** El primer diseño compilaba, tenía 32
tests en verde y tres mutantes que caían — y aun así llevaba dentro cuatro defectos graves.

### Los cuatro graves

1. **El predicado de iCloud era el equivocado, y con él el bug seguía vivo.** La sonda salía por «no se
   puede validar» cuando `SwiftDataConfiguration.isICloudAvailable()` daba `false`, o sea
   `ubiquityIdentityToken == nil`, que mide **iCloud Drive**. Pero el repo tiene MEDIDO (auditoría
   R1(c), `PersonalStoreDecision.attachesCloudKitMirror`) que el mount `.localNoMirror` **adjunta el
   espejo igual**, porque cae en `cloudKitDatabase: .automatic`. Traducción: a quien tuviera Drive
   apagado y CloudKit funcionando, la app le decía «no pude comprobar», seguía adelante, y el histórico
   le bajaba encima igual — **el bug de este ticket, por el predicado elegido para arreglarlo**. Ahora
   el pre-filtro es `personalStoreMountedDecision.attachesCloudKitMirror`, que es el testigo de lo que
   este arranque montó, y quien declara «no hay cuenta» es CloudKit con su `notAuthenticated`.
2. **El borrado reportaba ÉXITO con la zona sin borrar.** `modifyRecordZones` solo lanza si falla la
   operación entera; los fallos POR ZONA llegan en `deleteResults` y el código los descartaba con
   `_ =`. Un `zoneBusy` daba «borrado OK» → se retiraba el arm → nadie reintentaba, y en el camino
   tardío el store local ya se había vaciado: la persona sin sus datos locales **y** con el corpus viejo
   entero en iCloud.
3. **El aviso tardío eran dos `.alert` encadenados del mismo anchor.** El molde que su propio comentario
   citaba (`UserDataResetView`) encadena sheet → alert **por su `onDismiss`**, y un `.alert` no lo
   tiene. Si UIKit descartaba el segundo, su flag —blocker de la matriz de readiness— se quedaba en
   `true` **para siempre**: el router dejaba de drenar nada en toda la sesión. Ahora es un sheet con
   fases (`LateICloudMirrorNoticeView`), entrado por `RouterEntryGate`.
4. **El chequeo tardío no miraba la sesión secundaria.** Los testigos viven en `UserDefaults.standard`
   —el dominio del dueño— mientras `hasCompletedOnboarding` resuelve por `SessionDefaults`, que en una
   visita es el de la invitada. Una visita podía recibir el aviso con las cifras del dueño y borrarle su
   iCloud.

### Y los que no eran graves pero cambiaban el resultado

- **`.unreachable` era un camino muerto.** Su única salida era «reintentar», y las otras dos ramas del
  chooser también necesitan red: un primer arranque sin conexión no podía entrar en la app. Ahora ofrece
  además «seguir sin comprobar», que deja el mismo testigo que el estado K — la validación se aplaza,
  no se pierde.
- **La vista lanzaba `Task { }` sin cancelación** desde los botones, así que sus `guard
  !Task.isCancelled` eran decorativos: un «volver» a media operación dejaba el trabajo corriendo sobre
  una vista desmontada, que acababa llamando a `onProceed()` y arrancando a la persona del chooser. Hoy
  la FASE conduce (`.task(id: phase)`) y el «volver» desaparece mientras se borra.
- **`clearICloudCorpusWipeArm` limpiaba un neutro durable que podía ser de OTRO dueño** (el wipe de
  cierre de sesión), dejando al device recién vaciado sin lo único que impide que el espejo se readjunte
  sobre el corpus del humano que se fue.
- **`truncated` se leía como «iCloud vacío»**: el tope de la sonda cuenta todos los tipos de la zona, así
  que un corpus enorme podía agotarlo antes del primer movimiento y salir `0/0/0`. «No lo sé» pasa a
  contar como «sí hay».
- **El arm ganaba a un destino pendiente más reciente**: quien abandonaba la puerta y pedía «Restaurar de
  iCloud» se encontraba con que el arranque siguiente le borraba justo lo que quería recuperar.
- **La espera de quiescencia se descartaba con `_ =`** y se borraba igual al agotar el tope — que con un
  corpus grande es el caso normal. Detrás venía un `save()` durante el import, o sea el SIGTRAP y su
  crash-loop, ahora con un arm durable que lo repetía en cada arranque.
- **`countsLine` no pintaba las categorías**, y `hasAnyData` sí las cuenta: quien solo tuviera categorías
  veía un `Text("")` en medio de un aviso que le pide confirmar un borrado irreversible.

### Lo que la lente de tests encontró, y no es menor

- **`copy_isOwnAndNamesICloud` era 100 % vacuo**: comprobaba la línea ENTERA del `.strings`, clave
  incluida, y todas las claves son `welcome.privateICloud.*` — el substring «iCloud» venía en el nombre.
  Pasaba con el valor puesto a `"xxx"`. Era la única red de una decisión de producto de Jürgen.
- **`truncatedCorpus_saysAtLeast` sobrevivía al swap del ternario**, que es el mutante que importa:
  comparaba `full != capped` y las dos líneas siguen siendo distintas, solo que intercambiadas.
- **Los tres seams de `ICloudPersonalCorpusProbe` no los usaba nadie**, con un `_testReset()` cuyo
  docblock decía «lo llaman los tests entre casos». Cero llamadas.
- **`!line.contains("0 ")`** era frágil por un lado y débil por el otro: se ponía rojo con
  `transactions: 10` sin que producción cambiara.

**Estado tras la review**: 41 casos en 6 suites, y **6 mutantes verificados** (los 3 primeros más el
swap del ternario, `truncated` sin su término, y el guard de sesión secundaria). Un séptimo mutante
—quitar el `return` de la rama de fallo— **no compila**: lo protege el propio compilador.

---

## Device-QA · lo que solo se puede verificar en un iPhone

CloudKit **no existe en simulador**, así que la mitad que de verdad importa de este ticket no la puede
verificar nadie desde aquí. Lo que sigue lo tiene que correr Jürgen en su iPhone, con su Apple ID y su
histórico real. Lo que la suite unit sí cubre está en `WelcomePrivateICloudGateTests` (6 suites, 41
casos, 6 mutantes verificados) y **no se repite aquí**.

### Antes de empezar

- **Build de TestFlight**, no de Xcode. Un build firmado en desarrollo no puede atestar contra
  producción (`.claude/rules/gateway-attest.md`), y aunque este ticket no toca el gateway, el
  contenedor de CloudKit que se va a **borrar** es el de producción: hay que estar en el build que lo
  usa de verdad.
- **Un iPhone con meses de datos en el iCloud privado**, y con el corpus anotado antes de tocar nada:
  cuántos movimientos, cuántas cuentas, y el mes del más antiguo. Las cifras del aviso se comparan
  contra eso.
- **La copia de seguridad es no tener prisa**: el recorrido 2 borra el contenedor de iCloud de verdad y
  no hay vuelta atrás. Si el Apple ID de pruebas no es desechable, hacer antes el recorrido 1 y el 3,
  que no destruyen nada.

### Punto BLOQUEANTE, y va primero

**Comprobar que la sonda no lanza.** `ICloudPersonalCorpusProbe` baja una lista de `desiredKeys` ÚNICA
sobre una zona MULTI-TIPO: `CD_isSystemAccount` no existe en el schema de `CD_TransactionItem`, ni
`CD_date` en el de `CD_Account`. Lo esperado es que el servidor devuelva cada registro sin las keys que
no le tocan. **Si en cambio las validara contra el schema del tipo, cada página lanzaría** y la rama
privada quedaría en «reintentar» para siempre — con la app inservible para todo usuario nuevo.

Es el primer lector de registros de CloudKit del repo, así que no hay precedente donde apoyarse y esto
**no se puede inferir**: hay que verlo.

- **Cómo se ve bien**: el recorrido 1 llega al aviso con cifras que casan con el corpus anotado.
- **Cómo se ve mal**: la pantalla «No pudimos conectarnos a iCloud» **siempre**, con reintentos que dan
  lo mismo.
- **Plan B si sale mal** (está escrito para no tener que pensarlo en caliente): bajar solo los metadatos
  del sistema (`desiredKeys: []`) y contar por `recordType` sin excluir las entidades de sistema. Las
  cifras salen algo altas —cuenta la infraestructura del bridge de Grupos— y el fallo cae del lado
  seguro: un aviso que sobra se cancela, uno que falta borra un histórico.

### Los cinco recorridos

#### 1 · Instalación fresca + iCloud CON datos → el aviso sale ANTES de cualquier reinicio

1. Desinstalar Yala. Instalar desde TestFlight.
2. «Es mi primera vez en Yala» → «Tu cuenta en tu iCloud privado».
3. **Tiene que salir «Revisando qué hay en tu iCloud…» y después el aviso con cifras.**

**PASS** exige las tres:
- La pantalla de reinicio **no aparece antes** del aviso. Ése era el bug entero.
- Las cifras casan con el corpus anotado (movimientos, cuentas, y «desde <mes>»).
- El aviso ofrece **tres** salidas: «Traer mis datos», «Empezar de cero» y el chevron de volver.

**FAIL si**: sale «Un último paso: reabre Yala» sin aviso previo (el bug original), o el onboarding
completo se monta encima de los datos que están bajando.

#### 2 · Borrar (doble confirmación) → reinicio → onboarding limpio, y iCloud a CERO

Desde el aviso del recorrido 1: «Empezar de cero» → «¿Seguro? Esto es definitivo.» → «Borrar todos los
datos».

- Sale «Borrando lo que había en iCloud…» **y el chevron de volver desaparece** mientras dura.
- Al terminar, la pantalla de reinicio. Reabrir.
- El onboarding arranca **de cero**, sin nombre y sin divisa preseleccionados.

**La verificación que de verdad cierra el AC no está en esta pantalla**: instalar Yala en OTRO
dispositivo con el mismo Apple ID, tocar «Ya tengo una cuenta → Restaurar desde iCloud», y comprobar
que dice **`notFound`**. Si dice que encontró datos, el borrado no llegó al contenedor y el AC falla —
por más que la app diga que fue bien.

#### 3 · Cancelar → chooser, con los datos intactos

Repetir el recorrido 1 y tocar el chevron en el aviso.

- Vuelve a la elección privado / nube.
- Y lo que hay que comprobar de verdad: **volver a entrar por «privado» y ver que las cifras siguen
  siendo las mismas**. Cancelar no puede haber tocado nada.

#### 4 · Instalación fresca + iCloud VACÍO → onboarding directo, sin aviso

Con un Apple ID que nunca usó Yala (o después del recorrido 2).

- Tras «privado» sale «Revisando…» un instante y va **directo** a la pantalla de reinicio y al
  onboarding. **Sin aviso.**
- **FAIL si sale el aviso**: la sonda está contando entidades de sistema —las cuentas y categorías que
  el bridge de Grupos crea en el bootstrap— como si fueran datos de la persona.

#### 5 · Sin iCloud → aviso, se sigue en local, y el aviso llega cuando iCloud vuelve

Éste es el que Jürgen añadió el 2026-09-09, y el que cierra el bug por la puerta de atrás.

1. Ajustes del iPhone → apagar iCloud Drive para Yala (o cerrar sesión de iCloud). Instalación fresca.
2. «Privado» → sale «No pudimos revisar tu iCloud» → «Seguir así» → onboarding local completo.
3. Crear un par de movimientos, para que haya algo propio que distinguir.
4. **Volver a activar iCloud** y reabrir la app.
5. **Tiene que salir el aviso del espejo tardío**, con las cifras del corpus viejo y dos salidas:
   «Déjalo así» y «Empezar de cero».

**PASS de las dos ramas, y hay que probar las dos:**
- «Déjalo así» → los datos viejos aparecen junto a los nuevos, y **el aviso NO vuelve a salir** en los
  arranques siguientes.
- «Empezar de cero» (con su segunda confirmación) → borra iCloud y lo local, y reabre el onboarding.

**Sub-caso que conviene no saltarse**: con **iCloud Drive apagado pero la sesión de iCloud activa**. Ése
es el caso que el primer diseño clasificaba mal —`ubiquityIdentityToken` mide Drive, no CloudKit— y el
arreglo pasa a preguntar por el espejo (`personalStoreMountedDecision.attachesCloudKitMirror`). Aquí el
aviso **sí** tiene que salir.

### Y la prueba fea: matar la app a mitad del borrado

En el recorrido 2, entre «Borrar todos los datos» y la pantalla de reinicio, **forzar el cierre de la
app** (deslizar hacia arriba en el multitarea).

Al reabrir, **la puerta vuelve a MEDIR**, no reanuda a ciegas:
- Si el borrado llegó a completarse → sonda vacía → onboarding limpio.
- Si no → el aviso otra vez, con las cifras, y la persona vuelve a decidir.

**FAIL si**: al reabrir sale el onboarding completo sobre datos que siguen en iCloud, o si la app
arranca borrando sin decir nada.

### Lo que este device-QA NO cubre, y por qué

- **La sesión secundaria (M1)**: el chequeo tardío sale antes de mirar nada si hay una sesión secundaria
  activa, y M1 está al 0 % en producción y se retira en el paso 12 del rediseño. Está pinneado por
  source-scan, no por recorrido.
- **El caso de la zona borrada a medias** (`CKError.partialFailure` con varias zonas del mirror): hoy
  `NSPersistentCloudKitContainer` usa una sola zona para el store privado, así que no es alcanzable sin
  fabricarlo.

### Residual conocido, con ticket

Matar la app entre el borrado de la zona y el borrado local, **en el camino tardío**, deja el corpus
local intacto con el espejo vivo: al reabrir puede re-exportarse a la zona recién vaciada. Es
reaparición, no pérdida, y la persona puede repetir el borrado. Ticket:
`late-icloud-wipe-can-re-export-between-its-two-halves`.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con los recorridos 1 y 3. Los que borran iCloud o piden otro Apple ID quedan cubiertos por los tests.
