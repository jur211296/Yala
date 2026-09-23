---
id: groups-entry-on-a-mirrored-store-still-blocks-the-owner
status: qa
priority: high
area: "modo-nube, groups"
created: 2026-09-10
source: "mitad 2 de `groups-only-second-launch-mounts-icloud-mirror`, separada por decisión de Jürgen (2026-09-10) tras medir que el desmontaje en caliente no es viable"
updated: 2026-09-23
---

# «Vengo por un grupo» sobre un store que ya lleva espejo sigue bloqueando al dueño de los datos

## El síntoma, en lenguaje de usuario

Mi teléfono ya bajó datos de iCloud por otra rama (elegí «privado» y no terminé, o probé «Restaurar
desde iCloud»). Ahora toco «Vengo por un grupo → Crear mi primer grupo» y la app me dice **«Aquí ya hay
datos guardados… Si son tuyos, crea el grupo desde la app que ya usas»**, con un único botón «Volver».
La app que ya uso **es ésta**. No hay salida.

Captura: `evidencia-groups-only-mount/2026-09-09-puerta-datos-ajenos-bloquea-al-dueno.png` (en el
ticket padre).

## Lo que debería pasar (ADR 2026-09-09 §2-3)

Nunca bloquear. Si al elegir «Vengo por un grupo» el store personal ya lleva espejo o datos, la app
**vuelve al neutro** —espera el export pendiente, avisa sin pedir confirmación, borra lo local, deja
iCloud intacto, arma el neutro duradero— y sigue al sign-in. En el modelo, si se ve el Welcome no hay
sesión privada, y lo que haya en el store es una importación que nadie pidió.

## Por qué se separó del ticket padre (medido el 2026-09-10)

El padre cerró la mitad 1 (el alta solo-grupos deja neutro duradero, PR de la sesión). Esta mitad se
paró porque **los dos mecanismos que el padre daba por disponibles no cubren este caso**:

1. **El desmontaje en caliente lo rechaza su propio guard de alcance.** `PersonalContainerSwap`
   (`Yala/Services/CloudSync/PersonalContainerSwap.swift:178-255`) está completo y device-validado, pero
   `PersonalSwapReleaseLogic.mountAdmitsSwap` (`Yala/App/Logic/PersonalSwapReleaseLogic.swift:84-88`) es
   `!mountedDecision.attachesCloudKitMirror`: admite el swap **solo si ningún extremo lleva mirror**.
   Aquí el extremo de SALIDA es `.iCloudMirror` ⇒ `.skippedMountHasMirror`. El motivo está medido en
   device (spike R3, eje 3, citado en `PersonalContainerSwap.swift:19-23`): con el mirror vivo el release
   cierra los descriptores, **pero CloudKit siguió emitiendo 5 eventos en los 10 s POSTERIORES** — el
   trabajo en vuelo sobrevive al container.
2. **Borrar lo local con el espejo montado BORRA TAMBIÉN iCloud.** `wipeAllUserData`
   (`DataWipeService.wipeAllUserData`) borra el corpus personal **por filas**, y el propio
   fichero declara el invariante (`:257-263`): «borrar filas con el mirror montado exporta los deletes a
   iCloud». Eso contradice el criterio «el contenedor de iCloud sigue intacto». Y **«esperar al export»
   no existe en el repo**: cero `waitForExport`/`pendingExport`/`drainExport`/`hasCompletedFirstExport`;
   lo más cercano, `MigrationWorkExecutor.isMarkerExported()` , mira **una** fila de
   marcador, y las dos esperas reales (`waitForImportQuiescence`, `awaitQuiescence`) son de IMPORT.

## La salida que sí existe, y su precio

El ticket hermano `late-icloud-wipe-can-re-export-between-its-two-halves` propone —para su propio
caso— **no borrar filas: borrar la zona y armar el boot-wipe** (`StorageModePersistence.armSignOutWipe`),
que borra **archivos pre-mount** y es kill-safe por construcción. Ese mecanismo resuelve las dos
objeciones de arriba a la vez: pre-mount no hay mirror que exporte nada, y no hace falta soltar ningún
container vivo.

**Su precio es el relanzamiento**, que es exactamente lo que Jürgen pidió evitar («que el alta de Grupos
no se interrumpa nunca con una pantalla de reabre Yala»). ⇒ **la decisión pendiente es esa**: aceptar
un relanzamiento en este camino (raro: solo lo pisa quien ya adjuntó espejo por otra rama), o abrir el
trabajo de ensanchar `mountAdmitsSwap` a transiciones CON espejo, que reabre el residual del eje 3 del
spike R3 en la capa que menos perdona.

Los dos tickets convergen en el mismo mecanismo, así que conviene decidirlos juntos.

## Alcance

- La vuelta al neutro (espera de export · aviso sin confirmación · borrado local · iCloud intacto ·
  neutro duradero armado · cancelar `ICloudRestoreSessionSignal` si hay restore en curso).
- **Retirar el término «datos ajenos»** de `GroupsOrganizerGateLogic.decide`
  (`Yala/App/Logic/GroupsOrganizerGateLogic.swift:96-114`, el `hasExistingData && !restoreInProgress`) y
  su pantalla `welcome_groups_gate_foreign_data`. **No antes**: sin la vuelta al neutro, retirar el
  bloqueo deja al usuario creando un grupo encima de datos ajenos, que es peor. Los otros dos términos
  (canal apagado, sesión secundaria) siguen hasta que M1 se retire.
- La misma regla para la entrada por **invitación**.

## Criterios de aceptación

- [ ] Store con espejo y datos importados + «Vengo por un grupo» → sin pantalla de bloqueo: vuelta al
      neutro y sign-in; el contenedor de iCloud sigue intacto («Restaurar desde iCloud» en otra
      instalación lo encuentra).
- [ ] Invitación (link) en ese mismo estado → mismo resultado, y la hoja «unirme» al terminar.
- [ ] Restauración en curso + «Vengo por un grupo» → la señal de restore se cancela, vuelta al neutro, y
      «Restaurar desde iCloud» en otra instalación sigue encontrando todo.
- [ ] Lo que el usuario escribió en este móvil y no llegó a subir **no se pierde**.
- [ ] La pantalla `welcome_groups_gate_foreign_data` ya no es alcanzable, y sus dos hermanas sí.

## Cómo se prueba

- Device-QA (CloudKit): es el único sitio donde el espejo existe. En simulador se puede verificar la
  DECISIÓN y el borrado local, nunca que iCloud quedó intacto.
- Unit: la vuelta al neutro debería tener su lógica pura, como la tienen las dos puertas de hoy.

## Lo que hereda la activación de Yala completo (paso 8, 2026-09-11)

La puerta privada de «Activar Yala completo» borra **solo la zona de iCloud**, porque el store de una
sesión solo-grupos nunca espejó y el borrado local (`wipeAllUserData`) resetearía además su onboarding.
Esa premisa falla exactamente en el estado de este ticket: una sesión solo-grupos montada sobre un store que
YA importó el corpus (instalaciones anteriores al paso 5, o una invitación aceptada sobre un store con
espejo). Ahí, tras «borrar mis datos de iCloud», lo ya importado sigue en local y el espejo lo vuelve a
subir; y por la rama de nube, la promoción sube lo importado a la cuenta. **La vuelta al neutro de este
ticket lo cierra de raíz**: con ella, una sesión solo-grupos nunca tiene corpus importado debajo.

## Lo que deja el paso 9 (`session-exits-one-verb-per-session`, 2026-09-11)

**El verbo que esta puerta necesitaba ya existe, y resuelve las dos objeciones medidas de arriba.** El cierre
de una sesión privada hace exactamente «subir lo pendiente, borrar lo local, dejar iCloud intacto»:

1. **Espera al export** antes de borrar: `PrivateSignOutExportGateLogic` + `PersonalExportPendingCounter`
   (cambios locales del historial posteriores al inicio del último export con éxito), con salida avisada si
   se agota la espera. Aquí casi siempre saldrá al instante: lo que hay en el store lo BAJÓ el espejo, y eso
   no cuenta como pendiente.
2. **Borra por ARCHIVOS pre-mount** (`armSignOutWipe` → `performSignOutWipeIfArmed`), así que no hay filas
   borradas que el espejo exporte ni container vivo que soltar. Arma el neutro duradero.

**Lo que falta, y es de Jürgen:** ese camino **relanza** (el swap sin relanzar no admite mounts con espejo,
y es a propósito). Consumirlo aquí es aceptar una pantalla de «reabre Yala» en el alta de Grupos para quien
ya tenía espejo — la decisión pendiente de este ticket, sin cambios. Técnicamente, la puerta se cablea con
un tramo como `CloudSessionSignOut.finalizeSessionExit(kind: .privateOnly, …)` sin tocar la sesión en la
nube (aquí todavía no existe) y con un destino que retome «Vengo por un grupo» tras el arranque (el
intent del organizador no es durable: ticket propio). No se consumió en el paso 9: su alcance era Ajustes.

**Y lo que no está en `2.1`:** la segunda pasada de este ticket —diseño, código de la puerta, tres lentes y
el paso a `blocked/`— vive en la rama `encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner`,
subida y **sin PR**. Sus dos bloqueantes eran exactamente estas dos piezas (un borrado acotado y una espera
de export demostrable), y su añadido al ticket del paso 9 ya está incorporado allí con una respuesta por
punto. Al rebasar esa rama, esta sección tiene que viajar a su copia en `tickets/blocked/`.


---

## Implementación (2026-09-11, rama `encargo/2026-09-11-groups-entry-on-a-mirrored-store-still-blocks-the-owner`)

### Lo que cambia para quien usa Yala

- **«Vengo por un grupo → Crear mi primer grupo» ya no te deja tirado.** Antes, si el teléfono ya tenía
  datos, salía «Aquí ya hay datos guardados… si son tuyos, crea el grupo desde la app que ya usas» con un
  único botón «Volver» — y la app que ya usas es ésa. Ahora Yala **prepara el teléfono y sigue**: sube a
  iCloud lo último que guardaste, deja el teléfono en blanco, te pide reabrir la app una vez y te devuelve
  justo donde estabas, listo para crear tu grupo. **Tu iCloud no se toca**: «Restaurar desde iCloud» lo
  encuentra todo.
- **También pasa con el teléfono vacío**, si ese teléfono todavía sincroniza con un iCloud. Antes te dejaba
  entrar, y los gastos de tu grupo acababan en la cuenta de iCloud del dueño del móvil.
- **Si de verdad no hay copia en iCloud** —y solo cuando hay prueba de que no la hay— Yala te lo dice y
  pide un segundo gesto antes de borrar nada.
- **Si algo no llega a subir en 45 s**, un aviso te dice cuántos cambios faltan y te deja elegir entre
  esperar o continuar igualmente.
- **Y si el teléfono tiene cambios de grupos sin subir de una cuenta caducada**, no se borra nada: se te
  pide volver a entrar con esa cuenta para que suban.

### Cómo está hecho

- `GroupsOrganizerGateLogic.decide` pierde `.blockedForeignData` y `restoreInProgress`; gana
  `.returnsToNeutral` y `mountAttachesMirror`, **el eje ANCHO** (`attachesCloudKitMirror`), que es `true`
  también para `.localNoMirror` y cierra la mitad del bug que el detector de filas no puede ver.
- La vuelta al neutro **CONSUME el cierre privado del paso 9** (`CloudSessionSignOut.signOut`) en vez de
  armar el boot-wipe por su cuenta: es lo único que cumple las tres precondiciones que el hook declara, y
  hereda sus redes (bloqueo si quedan grupos sin subir, aviso si la espera se agota, desarme si aborta).
- **La celda de cierre se mide ANTES de arrancar**, con la misma función pura que el dispatch: los tres
  `return` mudos de `signOut` no tocan la fase que la vista observa, y arrancar a ciegas dejaba un progreso
  eterno sin botón. Las dos celdas que no borran por archivos salen por una pantalla con salida.
- El destino `.groupsOrganizer` se persiste **al armar** (antes haría `exit(0)` en background sin nada
  armado) y `presentNextOnboardingScreen` lo retoma **en la puerta**, que vuelve a medir.
- El terminal «reabre Yala» es el del cierre de sesión, no el del Welcome: los dos covers cuelgan del mismo
  body y UIKit presenta uno.
- 13 claves de copy nuevas en 16 idiomas; se retiran las dos de `existingData*`.

### La review adversarial (tres lentes + la rule de área, 2026-09-11)

Pérdida de datos, flujo de UI y celdas/reglas contra el diff. **Arreglados, los graves primero:**

1. **El testigo del mount MIENTE bajo `-uitest`** y nadie lo había medido para este uso:
   `personalConfiguration` sale por su rama `YalaModel-UITest` antes de
   `capturePersonalStoreMountedDecisionOnce`, así que el default de declaración (`.iCloudMirror`) manda y el
   eje ancho daba `true` en TODA corrida. Sin arreglarlo, `.proceed` era inalcanzable en XCUITest,
   `WelcomeChooserUITests.testGroupsOrganizer_createCardWalksToTheGroupForm` caía, y cada corrida armaba un
   boot-wipe real cuya key sobrevive a `-uitest-reset`. Se cierra con un seam cuyo default es la VERDAD de
   ese host (`false`) y un hook (`-uitest-groups-gate-mirror-live`) para quien quiera la otra rama.
2. **`signOut` puede volver sin tocar su fase** (fase ocupada, celda distinta, plan nulo) y la vista se
   quedaba en un progreso sin botón de volver. Ahora la celda se mide antes y hay pantalla con salida.
3. **El copy prometía lo que no sabía**: «tus datos personales siguen a salvo en tu iCloud» es categórico, y
   quien no tiene cuenta de iCloud llega igual a esa pantalla (el canal solo dice «no hay copia» con
   prueba, que es lo correcto). Ahora describe la acción, no el resultado.
4. **Apagar el latch de restauración era peor que no apagarlo**: si el cierre se aborta, el import sigue
   bajando con el latch apagado y su único encendedor vive en otra pantalla ⇒ el guard cross-cuenta vuelve a
   clasificar el corpus propio de la dueña como ajeno. Se retiró la llamada; el latch vive en memoria y
   muere con el relanzamiento, que es lo que este camino hace.
5. **Los botones del aviso eran de un solo uso**: `.task(id:)` no re-arranca con el mismo valor, y el
   primero en morir era «Esperar», el que NO destruye. Las fases de trabajo llevan nonce.
6. **`onChange` sin `initial:`** dejaba el Welcome delante del cover terminal si el step se montaba con la
   fase ya puesta.
7. **La purga del arm en UITest no cubría su caso**: el ejecutor corre en `PersonalContainerHost` antes que
   `applyUITestHooksEarly`, y bajo `-uitest` está apagado de todos modos. Se retiró — con el seam del punto
   1 la puerta ya no arma en corridas normales, y una red que no cubre su caso es peor que ninguna.
8. **El docblock afirmaba que el store de Grupos no se borra**, y `forgetsGroups` sí lo marca cuando hay
   filas del canal backend. Corregido con la semántica real.
9. **La cita del ADR era imprecisa**: el §2 declara válida la celda «privada + grupos asociados», cuyo
   camino no borra nada. Ahora se cita la fila B de la matriz, que es la que dice esto.
10. `neutralStalledBody` pasa a accessor-función, como su hermano de Ajustes, para que
    `L10nFormatAccessorsTests` pueda cubrirla.

**Refutado con medición:** que `privateCopyChannel()` produzca un borrado silencioso sin cuenta de iCloud.
Su docblock ya decide ese trade-off («ni la falta de token ni la falta de ancla prueban nada… el error cae
del lado de esperar»): sin cuenta, la espera se agota y sale el aviso con sus dos salidas. El caso del ancla
rancia es semántica heredada del verbo del paso 9, idéntica en Ajustes, y tiene su ticket allí
(`export-anchor-accepts-events-from-any-container`).

**Tickets que salen:** `groups-invite-on-a-mirrored-store-crosses-data` (la entrada por invitación, `high`)
· `invite-recovery-relaunches-for-a-mirror-it-never-uses` · `sign-out-wipe-abort-loops-the-groups-gate` ·
`superseding-intent-can-strand-the-sign-out-coordinator` · y dos rescatados de la rama sin PR del 10-sep:
`forcesync-returns-ok-without-touching-the-network` e `icloud-export-error-latch-never-clears`.

### Verificación

- **Unit**: suite completa en verde (ver el PR). Las suites de la puerta: 65 tests en 6 suites.
- **XCUITest**: `SecondarySessionGateUITests` 5/5 y `WelcomeChooserUITests` 6/6, con `-scheme "Yala Dev"`.
- **Mutantes: 15 aplicados, 15 muertos.**
- **Audit**: cero `try?`, cero force unwraps, cero `print(` en las líneas añadidas.

## Guion de device-QA (NO simulable)

**Por qué no vale el simulador:** sin cuenta de iCloud no hay espejo, así que ni el borrado por archivos ni
el testigo del export se pueden observar. Lo que el simulador cubre —la DECISIÓN y qué pantalla sale— ya
está en los unit y el XCUITest.

**Montaje**

1. Un iPhone con tu iCloud y un TestFlight que lleve este cambio.
2. El Apple ID tiene que tener **datos personales de Yala en iCloud**. Si no: instala Yala, haz el
   onboarding privado, crea 2-3 cuentas y unas transacciones, y deja la app abierta un minuto.
3. **Borra Yala del teléfono** (mantener pulsado → Eliminar app). Eso deja iCloud intacto.
4. Instala el TestFlight.

**Recorrido 1 — el bug del título, y el que importa**

5. Abre Yala → «Primera vez» → «Tu cuenta en tu iCloud privado» → **en la validación de iCloud, elige
   «Restaurar mis datos»** y deja que baje el histórico. Mata la app.
6. Ábrela otra vez y **vuelve al Welcome** (atrás desde donde estés).
7. «Vengo por un grupo» → «Crear mi primer grupo».
8. **Lo que tiene que pasar:** ninguna pantalla que diga «Aquí ya hay datos guardados». Sale «Estamos
   subiendo tus últimos cambios a iCloud…» y después la pantalla de reabrir Yala.
9. Ve a la pantalla de inicio, espera dos segundos y **abre Yala otra vez**.
10. **Tienes que aterrizar en la puerta de Grupos, no en el chooser**, y pasar de ahí al sign-in de grupos
    sin volver a elegir nada. El Panel tiene que estar vacío.

**Recorrido 2 — el criterio que más caro sale si falla: iCloud intacto**

11. Desde el recorrido 1, sal de Grupos y vuelve al Welcome (o reinstala la app).
12. «Ya tengo cuenta» → «Restaurar desde iCloud». **Tiene que volver TODO el histórico del paso 2.**
    Si vuelve vacío, es FAIL y es el fallo grave de este cambio.

**Recorrido 3 — lo que escribiste y no subió**

13. Repite hasta el paso 6. Antes de tocar «Vengo por un grupo», **pon el modo avión** y crea una
    transacción.
14. «Vengo por un grupo» → «Crear mi primer grupo». A los 45 s tiene que salir el aviso **con un 1**.
15. Toca **«Esperar»** y quita el modo avión: tiene que continuar solo hasta la pantalla de reabrir.
16. Repite eligiendo **«Continuar igualmente»**: tras restaurar, esa transacción NO está — y el aviso lo
    había dicho.

**Recorrido 4 — sin copia**

17. En un dispositivo de pruebas **sin sesión de iCloud**, con datos locales, recorre la puerta. Apunta qué
    sale: la pantalla de «No encontramos una copia en iCloud» con su segundo gesto, o la normal y a los 45 s
    «no pudimos confirmar». **Lo segundo es correcto y esperado** cuando CloudKit todavía no ha contestado;
    lo primero, cuando ya contestó que no hay cuenta.

**Recorrido 5 — el teléfono vacío que aún espeja**

18. Reinstala, haz el onboarding privado, **no crees nada** y vuelve al Welcome. «Vengo por un grupo» →
    «Crear mi primer grupo». Tiene que volver al neutro igual (no hay filas, pero sí espejo).
19. Tras el relanzamiento, crea el grupo y anota un gasto. **En otro dispositivo del mismo Apple ID, ese
    gasto NO puede aparecer en el Panel personal.**

**Si algo falla, captura:** el panel DEBUG con `personalStoreMountedDecision` (tiene que decir un mount
**sin espejo** después del relanzamiento) y la pantalla donde se rompió.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con los recorridos 1 y 2. El 4 pide un aparato sin iCloud.
