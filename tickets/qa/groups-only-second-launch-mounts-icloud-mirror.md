---
id: groups-only-second-launch-mounts-icloud-mirror
status: qa
priority: high
area: "modo-nube, groups"
created: 2026-09-09
source: "medido durante el device-QA guiado del 2026-09-09 · ADR 2026-09-09 «Sesiones — dos ejes» §2-3"
updated: 2026-09-23
---

# La segunda apertura de una sesión solo-grupos adjunta el espejo de iCloud y se trae los datos personales

## El síntoma, en lenguaje de usuario

Instalo Yala, toco «Vengo por un grupo → Crear mi primer grupo», entro con Google, pongo mi nombre y
creo el grupo. Cierro la app y la vuelvo a abrir. **Sin que yo haya tocado nada, la app se conecta al
iCloud del teléfono y baja todo lo que hubiera ahí** — los datos personales del Apple ID del móvil,
que pueden ser míos de otra época o de otra persona. Yo solo quería usar grupos.

Contradice la regla del ADR: una sesión en la nube solo-grupos **ignora** lo que haya en iCloud.

## Lo medido (2026-09-09, árbol `3a94604e`)

Cadena completa, `Yala/Utils/SwiftDataConfiguration.swift`:

1. **Arranque 1** (instalación fresca): `isFreshInstallForNeutralMount` (`:266-277`) es `true` —no hay
   archivo de store, modo `.icloud` por defecto, chooser no visto— ⇒ `personalStoreDecision` devuelve
   `.neutralNoMirror` (`:341`). Correcto.
2. La rama organizador NO requiere espejo (`WelcomeMirrorRelaunchLogic.requiresMirror(.groupsOrganizer)
   == false`), así que no hay relanzamiento y el alta corre sobre el store neutro. Correcto.
3. El alta solo-grupos (`GroupsOrganizerOnboarding.completeSetup`,
   `Yala/Services/Groups/GroupsOrganizerOnboarding.swift:218`, `writePreferences` `:142`) escribe
   nombre, período, divisa y `onboardingMode = .groupInvite`. **No arma el neutro duradero.**
   `StorageModePersistence.armNeutralMount` tiene UN solo llamador en todo el árbol: el hook de
   boot-wipe del cierre de sesión (`SwiftDataConfiguration.swift:689`).
4. **Arranque 2:** el archivo del store ya existe ⇒ `isFreshInstallForNeutralMount == false`; la marca
   no está armada ⇒ `shouldMountNeutralDurable == false` (`:296-301`); no hay sesión secundaria ni
   `mirrorOffArmed` ⇒ la decisión cae en `iCloudAvailable ? .iCloudMirror : .localNoMirror` (`:342`;
   inputs en `:1172-1178`). **El espejo se adjunta al store personal de la sesión solo-grupos** e
   importa el contenedor privado del Apple ID.

Efectos derivados: `hasExistingData` pasa a `true`; el bridge de grupos escribe en un Panel que ahora
tiene histórico ajeno; y «Activar Yala completo» (ticket
`full-mode-activation-must-ask-where-personal-data-lives`) correría el onboarding encima de esos datos
sin validación.

## Medido en device (2026-09-09, iPhone de Jürgen, TestFlight build 13)

Tras una reinstalación fresca y algún intento previo por otra rama (privado → «reabre Yala», o
«Restaurar desde iCloud»), el espejo ya estaba adjunto y el histórico de iCloud importado. Al tocar
«Vengo por un grupo → Crear mi primer grupo», la puerta de grupos (`WelcomeGroupsGateView` /
`GroupsOrganizerGateLogic`, término «datos ajenos» = `hasLocalDataNow()`) respondió **«Aquí ya hay
datos guardados … Si son tuyos, crea el grupo desde la app que ya usas»** y solo dejó «Volver». La app
que ya usa es ésta. Captura: `evidencia-groups-only-mount/2026-09-09-puerta-datos-ajenos-bloquea-al-dueno.png`.
Es el callejón que describía `welcome-copy-blames-owner` (descartado a favor de este ticket).

## Lo que se espera (ADR §2-3)

Una sesión en la nube **solo grupos** no tiene sesión privada: su store personal se monta **sin espejo
de iCloud** en TODOS los arranques, hasta que el usuario elija explícitamente lo personal (privado o
nube) desde «Activar Yala completo».

**Y la puerta «datos ajenos» se retira aquí, no en el barrido final.** Si al elegir «Vengo por un grupo»
el store personal ya lleva espejo o datos (porque otra rama lo adjuntó antes), la app **vuelve al
neutro** —borra lo local, iCloud intacto, arma el neutro duradero, relanza si hace falta— y sigue al
sign-in. Nunca bloquea: en el modelo, si se ve el Welcome no hay sesión privada, y lo que haya en el
store es una importación que nadie pidió. Los otros dos términos de la puerta (canal apagado, sesión
secundaria) siguen hasta que M1 se retire.

La **misma regla vale para la entrada por invitación** (`presentGroupBackendInviteOnboarding` →
`GroupBackendInviteEntryLogic`): es la otra puerta a solo-grupos y hereda el mismo mount. Y si hay una
**restauración de iCloud en curso** (`ICloudRestoreSessionSignal.isRestoringNow`) al elegir grupos, se
cancela la señal antes de la vuelta al neutro: iCloud queda intacto, así que no se pierde nada.

## Alcance

- Que la decisión de mount deje de inferir «no ha elegido» de la ausencia de archivo y pase a
  derivarse del eje «¿hay sesión privada?» (ADR §2). Mientras ese eje no exista como estado explícito
  (ticket `shell-derives-from-two-session-axes`), el arreglo mínimo es que el alta solo-grupos deje el
  neutro **duradero** —armar la misma marca que arma el boot-wipe— y que esa marca **no caduque** con
  `hasShownWelcomeChooser` en este caso (hoy `shouldMountNeutralDurable` la anula si el chooser se vio;
  leer el docblock de `CloudSyncFlags.armNeutralMount:160-180` antes de tocarla: explica por qué caduca).
- Revisar el mismo patrón en la entrada por **invitación** (`presentGroupBackendInviteOnboarding` →
  `GroupBackendInviteEntryLogic`): es la otra puerta a solo-grupos y hereda el mismo mount.
- La salida de solo-grupos hacia «Yala completo → privado» es la que SÍ adjunta el espejo, y pasa por
  la validación del ticket `welcome-private-fresh-start-skips-icloud-check`.

## Criterios de aceptación

**Los cuatro que quedan aquí** (mitad 1, cerrada en código el 2026-09-10):

- [ ] **DEVICE** · Instalación fresca → «Vengo por un grupo» (crear o invitación) → alta → matar y
      reabrir la app ×3: `personalStoreMountedDecision` sigue siendo un mount sin espejo
      (breadcrumb/canario), y con datos en el iCloud del Apple ID **ninguno aparece** en el store
      personal (`checkHasExistingData == false`).
- [ ] **DEVICE** · Invitación (link) en instalación fresca → mismo resultado que «crear»: sin espejo, y
      la hoja «unirme» al terminar.
- [ ] **DEVICE** · «Restaurar desde iCloud» y «Primera vez → privado» siguen adjuntando el espejo cuando
      toca (no-regresión: es el daño contrario, y el que más caro sale).
- [ ] **DEVICE** · El cierre de sesión solo-grupos sigue dejando el dispositivo en neutro duradero.
- [x] Test unitario sobre `personalStoreDecision` / `shouldMountNeutralDurable` con el escenario
      «solo-grupos, archivo existente, chooser visto» → sin espejo.
      (`YalaTests/CloudSync/GroupsOnlyNeutralMountTests.swift`, 14 casos en 3 suites.)

**Los tres que se fueron** al ticket `groups-entry-on-a-mirrored-store-still-blocks-the-owner` (mitad 2,
parada por decisión de Jürgen del 2026-09-10): el estado B con espejo ya montado, la vuelta al neutro y
la retirada de la puerta «datos ajenos». El porqué está en el «Paso 0» de abajo, decisión D3.

## Cómo se prueba

- Unit: la lógica de mount es pura (`personalStoreDecision(storageMode:mirrorOffArmed:iCloudAvailable:
  secondarySessionActive:freshInstall:neutralDurable:)`), con tests en `YalaTests`.
- Device-QA (CloudKit): iPhone con datos en el iCloud del Apple ID → reinstalar → solo-grupos → reabrir.
  En simulador no hay iCloud: solo se puede verificar la DECISIÓN de mount, no la importación.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **La vuelta al neutro ESPERA AL EXPORT antes de borrar lo local.** Es la misma regla que la matriz
  exigió para la salida privada, y aquí aplica igual: «iCloud lo conserva» solo es cierto para lo que ya
  subió. Antes de borrar, esperar a que CloudKit termine de subir lo pendiente. Lo que un usuario
  escribió en este móvil y no llegó a subir **no se pierde**.
- **Se avisa, pero no se pide confirmación.** La vuelta al neutro no frena la entrada a Grupos —es la
  puerta de captación— pero el usuario no se queda a oscuras: se le informa de que sus datos personales
  siguen a salvo en iCloud. Informar, no preguntar.
- **El relanzamiento hay que EVITARLO**: se busca desmontar el espejo en caliente para que el alta de
  Grupos no se interrumpa nunca con una pantalla de «reabre Yala». Es la decisión con más riesgo técnico
  del ticket, en la capa que menos perdona. **Si el [spec] mide que no es viable, no caigas al
  relanzamiento por tu cuenta: avisa a Jürgen con lo medido y espera.**
- **La marca de neutro duradero dura hasta que el usuario elija lo personal.** No caduca con
  `hasShownWelcomeChooser`; solo la levanta «Activar Yala completo» al elegir privado o nube. Es la
  lectura literal del ADR §2 (el mount se deriva de si hay sesión privada). Lee igualmente el docblock
  de `CloudSyncFlags.armNeutralMount:160-180` antes de tocar la caducidad: explica por qué existía.

## Paso 0 — el árbol de decisiones, resuelto contra el árbol (2026-09-10)

Medido en `encargo/2026-09-10-groups-only-second-launch-mounts-icloud-mirror`. Las coordenadas del
cuerpo de arriba son del árbol `3a94604e` y **se han movido**: el docblock de `armNeutralMount` no está
en `:160-180` sino en `CloudSyncFlags.swift`, docblock de `neutralMountArmedKey`.

### D1 · Cómo se expresa el neutro duradero de una sesión solo-grupos → **marca PROPIA, sin caducidad**

Tres candidatos, y los dos primeros se descartan **por medición**:

- **Derivar de `onboardingMode == .groupInvite`** (sin key nueva). **Descartado: destruye un restore
  legítimo.** `RestoreRouter.decide` (`Yala/App/Logic/RestoreDestination.swift:31-34`) devuelve
  `.groupsOnly` en cuanto el `onboardingMode` **restaurado por iKV** sea `.groupInvite`, y el callsite
  (`ContentView.swift:694-699`) lo re-escribe. Ese modo viaja sincronizado con **never-downgrade**
  (rank 1 sobre rank 0, `GroupsOrganizerOnboarding.swift:196`), así que un device que restaura de iCloud
  puede quedar en `.groupInvite` **con mirror adjunto y su histórico recién bajado**. Derivar de ahí le
  apagaría el espejo en el arranque siguiente.
- **Reusar `armNeutralMount` tal cual.** Descartado: `shouldMountNeutralDurable` la anula con
  `hasShownWelcomeChooser`, y ese flag **sí** puede estar puesto al llegar a grupos —
  `onSelectPrivateAccount` (`ContentView.swift:1712-1717`) lo marca en el acto, antes de cualquier
  escritura, y desde ahí se llega al alta **sin volver al Welcome**: el onboarding privado ofrece la
  card «Solo grupos», que entra por `startGroupsOnlyBranch` (`ContentView.swift:751`) a la misma cadena
  del organizador. Ese recorrido llega a `writePreferences` con `true` y el bug revive.
  **Confirma la decisión de Jürgen sobre la caducidad.** (La vuelta por el Welcome NO sirve de ejemplo:
  `onCancelFromStep1` repone el flag a `false`, `ContentView.swift:746`.)
  (Matiz medido: el camino *limpio* de grupos no marca el flag — `onSelectGroupsOrganizer`,
  `ContentView`, `onSelectGroupsOrganizer`, y es deliberado. Por eso el fallo es intermitente y no constante.)
- **Marca propia `groupsOnlySessionArmed`, POSITIVA y sin término de caducidad.** ✅ Elegida.
  El restore no la arma nunca ⇒ inmune al bucle que la caducidad existía para cerrar.

### D2 · Dónde se arma, dónde se levanta

- Arma: `GroupsOrganizerOnboarding.writePreferences` (alta organizador) y
  `GroupInviteOnboardingView.performSilentSetup` (alta por invitación). **Las dos altas, no las dos
  puertas**: `performJoinOnlySetup` (invitado con onboarding ya hecho) no escribe el modo y **no debe
  armar** — es el caso «privada + grupos asociados» del ADR §2, que sí quiere su espejo.
- Levanta: `FullModeActivationView.completeFullActivation` (`completeFullActivation`), única salida a lo personal hoy.
- **Y se levanta también en `onNeedsMirrorRelaunch` (`ContentView`, callback `onNeedsMirrorRelaunch`)**, que es el punto
  único donde se decide que un destino necesita espejo. Sin esto el bucle vuelve por la puerta de
  Ajustes: marca puesta + destino con mirror ⇒ «reabre Yala» ⇒ vuelve a montar neutro ⇒ gira.

### D3 · La vuelta al neutro con espejo ya montado (estado B) → **BLOQUEADA, decisión de Jürgen**

Los dos mecanismos que el ticket da por disponibles **no cubren este caso**, y las dos cosas están medidas:

1. **El desmontaje en caliente existe pero rechaza este caso por diseño.** `PersonalContainerSwap`
   (`Yala/Services/CloudSync/PersonalContainerSwap.swift:178-255`) está completo y device-validado, pero
   su guard de alcance `PersonalSwapReleaseLogic.mountAdmitsSwap` (`mountAdmitsSwap`) es
   `!mountedDecision.attachesCloudKitMirror`: admite el swap **solo si ningún extremo tiene mirror**.
   Aquí el extremo de SALIDA es `.iCloudMirror` ⇒ devuelve `.skippedMountHasMirror`. El motivo está
   medido en device (spike R3, eje 3, citado en `PersonalContainerSwap.swift:19-23`): con el mirror vivo
   el release cierra los descriptores, **pero CloudKit emitió 5 eventos en los 10 s POSTERIORES** — el
   trabajo en vuelo sobrevive al container.
2. **Borrar lo local con el espejo montado BORRA TAMBIÉN iCLOUD.** `wipeAllUserData`
   (`DataWipeService.wipeAllUserData`) borra el corpus personal **por filas**, y el propio
   fichero declara el invariante (`:257-263`): «borrar filas con el mirror montado exporta los deletes a
   iCloud». Eso **contradice directamente** el criterio de aceptación «el contenedor de iCloud sigue
   intacto». Y **«esperar al export» no existe en el repo**: cero `waitForExport`/`pendingExport`/
   `drainExport`/`hasCompletedFirstExport`. Lo más cercano, `MigrationWorkExecutor.isMarkerExported()`, mira **una** fila de marcador, no el corpus; las dos esperas reales
   (`waitForImportQuiescence`, `awaitQuiescence`) son de IMPORT.

⇒ Jürgen escribió: «Si el [spec] mide que no es viable, no caigas al relanzamiento por tu cuenta: avisa
a Jürgen con lo medido y espera». **Es este punto.** D3 queda esperando decisión; D1/D2 son independientes
y cierran el síntoma del título.

### D4 · La puerta «datos ajenos» NO se retira todavía

Retirar el término `hasExistingData` de `GroupsOrganizerGateLogic.decide`
(`Yala/App/Logic/GroupsOrganizerGateLogic.swift:96-114`) **sin** la vuelta al neutro de D3 deja al usuario
creando un grupo encima de un store con espejo y datos ajenos — peor que el bloqueo que hoy le molesta.
La puerta se va **con** D3, no antes. Los otros tres términos (canal, secundaria, restore-en-curso) no se
tocan en ningún caso.

## Guion de device-QA (iPhone real — en simulador NO se puede)

**Por qué no vale el simulador:** el mount se puede verificar, pero la importación no. Sin cuenta de
iCloud no hay espejo que adjuntar, así que el fallo original (bajar datos ajenos) es **inobservable**.
Lo que el simulador sí cubre ya está cubierto por los 14 tests unitarios.

**Montaje (una vez):**

1. En el iPhone, Ajustes → tu Apple ID → iCloud: **iCloud encendido** y con Yala permitido.
2. El Apple ID tiene que tener **datos personales de Yala en iCloud**. Si no los tiene: instala Yala,
   haz el onboarding privado, crea 2-3 cuentas y unas transacciones, y espera a que suba (déjala abierta
   un minuto). Ese es el histórico que NO debe aparecer después.
3. **Borra Yala del teléfono** (mantener pulsado → Eliminar app). Esto deja iCloud intacto: es
   justamente lo que hay que comprobar.
4. Instala el TestFlight con este cambio.

**Recorrido 1 — el bug del título (el que importa):**

5. Abre Yala → «Vengo por un grupo» → «Crear mi primer grupo» → entra con Google → pon tu nombre → crea
   el grupo.
6. **Mata la app del todo** (deslizar hacia arriba en el conmutador, no solo mandarla al fondo).
7. Ábrela otra vez. **Repite matar+abrir tres veces.**
8. **Lo que tiene que pasar:** sigues viendo solo la pestaña Grupos, con tu grupo. **No aparece ninguna
   cuenta, ninguna transacción ni ningún presupuesto del paso 2.** Si aparece el Panel con datos que no
   creaste en este recorrido, es FAIL.

**Recorrido 2 — la invitación:**

9. Repite desde el paso 3, pero en vez de crear un grupo, entra por un **enlace de invitación** a un
   grupo de otra persona. Acepta, pon tu nombre, únete.
10. Mata y reabre ×3. **Mismo veredicto que el paso 8.**

**Recorrido 3 — la no-regresión, y es la que más caro sale si falla:**

11. Repite desde el paso 3. Esta vez elige **«Ya tengo cuenta» → «Restaurar desde iCloud»**.
12. **Tiene que restaurar tu histórico del paso 2.** Si se queda vacío, o si te pide reabrir la app una
    y otra vez sin avanzar (bucle), es FAIL — y es el fallo grave de este cambio.
13. Igual con **«Primera vez» → «Tu cuenta en tu iCloud privado»**: tiene que llegar a su validación de
    iCloud normal (la del paso 4 del rediseño), no quedarse sin espejo.

**Recorrido 4 — el cierre de sesión solo-grupos:**

14. Desde el recorrido 1 o 2, cierra la sesión de Grupos (Más → tu cuenta → Cerrar sesión).
15. Mata y reabre. **No debe aparecer nada del histórico de iCloud.**

**Si algo falla, lo que hay que capturar:** el panel DEBUG con `personalStoreMountedDecision` (tiene que
decir un mount **sin espejo** en los recorridos 1, 2 y 4, y **con** espejo en el 3), y una captura de la
pantalla donde aparezcan los datos que no deberían estar.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con los recorridos 1, 3 y 4. El 3 («Ya tengo cuenta → Restaurar desde iCloud» trae todo) se recorre en el paso C7 del guion, junto al recorrido 2 de `groups-entry-on-a-mirrored-store-still-blocks-the-owner`. El 2 pide un enlace ajeno.
