---
id: session-exits-one-verb-per-session
status: qa
priority: high
area: "settings, modo-nube, groups"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» §5-6"
updated: 2026-09-23
---

# Cierres de sesión: dos botones («Cerrar sesión», «Vaciar datos»), un verbo por sesión, y la sesión privada que sale borra lo local

## El síntoma, en lenguaje de usuario

Según cómo entré a Yala veo botones distintos con nombres distintos: «Cerrar sesión», «Cerrar sesión
de grupos», «Salir de Yala en este dispositivo», «Vaciar datos», «Eliminar mi cuenta», y algunos
hacen cosas que no dicen. El peor: en privado, «Cerrar sesión» **no cierra nada** — me devuelve a la
pantalla de bienvenida con todos mis datos vivos en el teléfono, a la vista del siguiente que lo abra.

## Lo medido (2026-09-09, árbol `3a94604e`)

- 7 verbos visibles sobre **11 operaciones** (`DestructiveScopeLogic.Operation`,
  `Yala/App/Logic/DestructiveScopeLogic.swift`), **4 caminos** (`CloudSignOutFlowLogic.Path`,
  `Yala/App/Logic/CloudSignOutFlowLogic.swift`) y **4 layouts** de filas (`RowLayout`), elegidos por
  `storageMode`, `isGroupInviteMode`, `hasLiveSession` y `secondarySessionActive`.
- `.privateReset` (`Yala/Services/CloudSync/CloudSessionSignOut.swift:9-12`): «NO toca datos —
  teardown, signOut local, reset de onboarding → Welcome». Es la ventana «Welcome con corpus del dueño
  vivo» que obliga a la puerta de «datos ajenos» de grupos y origina los tickets de «secundaria».
- `.groupsOnlySignOut` cierra solo grupos también cuando hay iCloud privado con cuenta de grupos
  (la fila «Cerrar sesión de grupos» + «Salir de Yala» en `RowLayout.groupsSignOutPlusExitYala`).
- Sitios: `DestructiveScopeSheet.swift` (todas las operaciones), `ProfileView.swift`,
  `YalaAccountView.swift` («Tu cuenta de Yala»: método, dónde viven los datos, salir, volver a
  iCloud, eliminar), `UserDataResetView.swift`, `GroupsRetentionView.swift` («Seguir con mis grupos»
  tras vaciar), `SignOutRelaunchView.swift`.

## Lo que Jürgen decidió (ADR §5-6)

| Sesión | Verbo | Qué hace |
|---|---|---|
| Privada, sin grupos | **Cerrar sesión** | borra lo local; iCloud intacto; Welcome |
| Privada + grupos asociados («equipo») | **Cerrar sesión** | sube cambios de grupos, borra lo local, iCloud intacto; Welcome. **No hay «salir solo de grupos»** |
| Nube completa | **Cerrar sesión** | sube cambios, borra lo local, cuenta intacta; Welcome (= `cloudSecureSignOut` de hoy) |
| Nube solo grupos (sin sesión privada) | **Cerrar sesión** | sube cambios de grupos, borra lo local; Welcome |
| Datos | **Vaciar datos** | privada: local **e** iCloud; nube: contenido de la cuenta. **Grupos, nunca** |
| Cuenta en la nube | Eliminar mi cuenta | **dentro de «Tu cuenta de Yala»**, no como botón principal (App Store 5.1.1 v: obligatorio mientras la app cree cuentas) |
| Grupo | Salir del grupo | dentro de cada grupo, como hoy |

Dos botones en Ajustes y nada más. El texto de confirmación de cada uno dice exactamente qué se
borra y qué queda (el `DestructiveScopeSheet` ya sabe pintar eso por ubicación).

## Alcance

1. `CloudSignOutFlowLogic.path` pasa a decidir por los dos ejes del ADR (¿sesión privada? × sesión
   nube activa y su `kind`), y `.privateReset` deja de existir: la salida privada **borra lo local**
   (`DataWipeService.wipeAllUserData` + dominio grupos local si no hay asociación) y arma el neutro
   duradero, como hoy hace `cloudSecureSignOut` en el boot-wipe (`SwiftDataConfiguration.swift:689`).   El contenedor de iCloud no se toca: «entrar» vuelve a ser «Restaurar desde iCloud».
   **Antes de borrar, esperar al último export a CloudKit.** Medido el 2026-09-09: nadie espera hoy
   (`iCloudSyncService.startObserving` solo observa `NSPersistentCloudKitContainer.eventChangedNotification`
   para pintar estado; `.privateReset` no borraba y por eso no lo necesitaba). Con el borrado local, un
   movimiento guardado hace cinco segundos y aún no exportado **se pierde para siempre**. Regla: el wipe
   solo corre tras un evento `.export` con éxito posterior al último save (o un `exportPending == false`
   equivalente); sin red o con el export atascado, «un momento más» como en la nube, y nunca borrar.
   Kill-safety: reusar el arm del boot-wipe (`SwiftDataConfiguration.swift:689`), que ya es kill-safe.
2. «Equipo»: con asociación, cerrar sesión = `pushAll` verificado de grupos (el mismo de
   `cloudSecureSignOut`, «jamás descartar») → cerrar la sesión nube → wipe local → Welcome.
   `.groupsOnlySignOut` queda solo para la celda «sin sesión privada + solo grupos».
3. `RowLayout` se reduce a un caso: dos filas. `GroupsRetentionView` se retira (con «Vaciar datos»
   sin tocar grupos, no hay nada que retener: la app sigue enseñando los grupos).
4. `DestructiveScopeLogic.Operation` se reduce a lo que la tabla necesita; `deleteFrozenCopy` (copia
   vieja de iCloud del cutover) pasa a un apartado «avanzado» dentro de «Tu cuenta de Yala».
5. «Eliminar mi cuenta» se mueve a `YalaAccountView` (ya está ahí como fila) y desaparece de las
   listas principales; sigue cumpliendo el borrado GDPR (`POST /account/delete`).
6. Copy nuevo en los 16 `.strings`; los strings de las operaciones retiradas se retiran.
7. **«Vaciar datos» en privada + asociada (D):** borra lo personal (local + iCloud), **la asociación y los
   grupos siguen**, y la app abre el onboarding [P]; al terminar sigue en D.
8. **«Eliminar mi cuenta» en D:** vive en «Tu cuenta de Yala» de la cuenta asociada; = desasociar +
   borrado GDPR de esa cuenta; lo personal privado no se toca.
9. Cambio de Apple ID en el teléfono con sesión privada: es un cierre de sesión (la sesión es del Apple
   ID); hoy `AppBootstrapper.checkForICloudMismatch` avisa — alinear en `shell-derives-from-two-session-axes`.

## Criterios de aceptación

- [ ] Ajustes muestra exactamente «Cerrar sesión» y «Vaciar datos» en las cuatro celdas del ADR.
- [ ] Privada: cerrar sesión → Welcome con `checkHasExistingData == false`, `personalStoreMountedDecision`
      neutro duradero al reabrir, y «Restaurar desde iCloud» encuentra los datos (device-QA).
- [ ] Privada: cerrar sesión 2 s después de guardar un movimiento nuevo → el movimiento está en iCloud
      (restaurar en otra instalación lo trae). Sin red → «un momento más», el store sigue intacto.
- [ ] D: «Vaciar datos» deja grupos y asociación; «Eliminar mi cuenta» desasocia y borra solo la nube.
- [ ] Equipo: cerrar sesión con un gasto de grupo sin subir → el gasto llega al backend antes del wipe
      (canario `pushAllVerdict == .drained`); si no puede subir, el cierre se bloquea con el «un momento
      más» existente, nunca descarta.
- [ ] Nube completa y solo-grupos: byte-idéntico a hoy salvo el copy.
- [ ] «Vaciar datos» nunca borra `YalaGroups`; en privada borra el contenedor de iCloud (verificable
      con «Restaurar desde iCloud» → `notFound`).
- [ ] «Eliminar mi cuenta» sigue accesible en ≤ 2 toques desde Ajustes para toda sesión nube.
- [ ] Tests: `CloudSignOutFlowLogicTests`, `DestructiveScopeLogicTests` reescritos sobre la tabla;
      XCUITest de Ajustes por celda (seeds uitest existentes para icloud / cloud / solo-grupos).

## Depende de

`cloud-sign-in-discovers-account-kind` (el `kind` de la sesión activa). Se coordina con
`groups-account-association-in-storage-row` (la asociación es el estado que distingue «equipo»).

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **Export atascado → salida de emergencia AVISADA.** No se deja al usuario atrapado ni se le borra en
  silencio: tras la espera normal («un momento más»), aparece una salida que dice **cuántos cambios
  siguen sin subir** y pide confirmación explícita. Es decir, hay que **contar lo pendiente**, no solo
  saber que lo hay. Nunca se borra sin haberlo dicho, y nunca se bloquea para siempre.
- **«Vaciar datos» en privada avisa de que borra en TODOS sus dispositivos.** La confirmación tiene que
  nombrar que los datos desaparecerán también del iPad y de cualquier aparato con ese Apple ID, no solo
  de este móvil. No basta con «local e iCloud». No hace falta listar los dispositivos.
- **Cerrar sesión privada sin iCloud activo: se avisa de que NO hay copia.** Se le dice claramente que en
  este móvil no hay iCloud, que no existe copia en ninguna parte y que cerrar sesión borra sus datos para
  siempre, con confirmación reforzada. **No se bloquea el cierre** y **no** hay que construir un export
  previo.
- **El verbo sigue siendo «Cerrar sesión» en las cuatro celdas**, sin subtítulo por fila. La coherencia
  es lo que arregla la confusión medida; el detalle de qué se borra y qué queda vive en el **texto de
  confirmación**, que ya sabe pintarse por ubicación. No reintroduzcas verbos por celda.

---

## Análisis técnico (spec, 2026-09-11, árbol `ba618216`)

Las decisiones de implementación (26 nodos, resueltas en autónomo) están en el `## Paso 0` del encargo
`encargos/lanzados/2026-09-11-session-exits-one-verb-per-session.md` y viajan al PR. Aquí, lo medido que
las sostiene y el plan.

### Lo medido (y lo que corrige del cuerpo de arriba)

- **Borrar filas con el espejo montado exporta los deletes a iCloud** (`DataWipeService`, invariante
  escrito). ⇒ la salida privada NO puede usar `wipeAllUserData`: borra por archivos pre-mount con el
  mismo boot-wipe de la nube (`armSignOutWipe` → `performSignOutWipeIfArmed`, que ya arma el neutro).
- **El swap sin relanzar no admite mounts con espejo** (`PersonalSwapReleaseLogic.mountAdmitsSwap`) ⇒ la
  privada relanza (cover terminal + salida en segundo plano), como la nube cuando el swap no aplica.
- **Nadie espera al export hoy** y no hay API de «export pendiente». Lo que sí hay: el historial de
  SwiftData del store personal ya se lee en producción con el espejo montado (el drain de Grupos y el
  motor), `NSPersistentCloudKitContainer.Event` trae `startDate`, y `CloudSyncEngine.isPersonalStoreTransaction`
  acota por store. ⇒ el testigo es «cambios locales del historial posteriores al inicio del último export
  con éxito» (ancla persistida). `CKContainer.accountStatus()` está descartado por decisión escrita
  (`ICloudCutoverGateLogic`, `MigrationWorkExecutor`).
- **`deleteFrozenCopy` no tiene ningún call-site**: el ítem 4 del alcance no tiene nada que mover; el
  case se retira.
- **«Eliminar mi cuenta» hoy NO existe para solo-grupos**: `AccountDeletionRowLogic` excluye
  `isGroupInviteMode` con la premisa de la era CKShare (group-invite = sin backend), que el alta por
  «Vengo por un grupo» dejó falsa. El criterio «toda sesión nube» obliga a abrirla.
- **Solo-grupos hoy no vuelve al Welcome** al cerrar: arma solo el wipe del store de grupos y reabre en la
  shell de grupos sin sesión (el estado «5a»). El ADR, la tabla y la matriz piden neutro.
- **«Vaciar datos» hoy aterriza en el Welcome** (`removeUserPreferenceKeys` borra `hasShownWelcomeChooser`,
  A4); el ticket (§7) y la fila H piden onboarding personal, y en solo-grupos la retención era lo único que
  la mantenía en su shell.
- **XCUITest**: `-uitest-fake-cloud-session` finge la sesión global ⇒ con él las celdas D y F son
  alcanzables; la E (`.cloud`) no tiene seam y se cubre por tabla.

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---|---|---|
| `Yala/App/Logic/CloudSignOutFlowLogic.swift` | `Path` por dos ejes; `BlockReason.exportUnconfirmed`; se retiran `RowLayout`/`shouldShow*` | Alto |
| `Yala/App/Logic/PrivateSignOutExportGateLogic.swift` | **Nuevo**: canal de copia, filtro de pendientes, veredicto y bucle de espera (reloj inyectado) | Alto |
| `Yala/Services/CloudSync/PersonalExportPendingCounter.swift` | **Nuevo**: cuenta cambios locales del historial tras el ancla | Alto |
| `Yala/Services/iCloudSyncService.swift` | Ancla de export confirmado (persistida, monótona) + `notAuthenticated` observado | Medio |
| `Yala/Services/CloudSync/CloudSessionSignOut.swift` | Salida privada C/D (espera + emergencia + arm), cola nueva de F, se retiran `performPrivateReset`/`exitYalaOnThisDevice` | Alto |
| `Yala/Services/CloudSync/AccountDeletionService.swift` | Fila sin exclusión de group-invite; cierre local completo en F | Medio |
| `Yala/App/Logic/DestructiveScopeLogic.swift` · `Yala/App/Views/Shared/DestructiveScopeSheet.swift` | Operaciones por celda × variante; aterrizaje de «Vaciar» | Medio |
| `Yala/App/Views/Profile/ProfileView.swift` · `YalaAccountView.swift` | Fila única, hoja por item, alert sin copia, alert de export, sin fila de borrar cuenta | Alto |
| `Yala/App/Views/Settings/UserDataResetView.swift` | Sin retención; aterrizaje por celda | Medio |
| `GroupsRetentionView.swift` (borrar) · `ContentView.swift` · `ContentViewReadinessLogic.swift` · `SessionState.swift` · `AppBootstrapper.swift` · `UITestHooks.swift` | Retirada de la retención | Medio |
| `Yala/Services/CloudSync/CloudSyncEngine.swift` | Breadcrumbs del cierre privado | Bajo |
| `Yala/Utils/L10n.swift` + 16 `Localizable.strings` | Copy nuevo, cambiado y retirado | Medio |
| Tests | `CloudSignOutFlowLogicTests`, `DestructiveScopeLogicTests` (reescritas), `PrivateSignOutExportGateLogicTests`, `PersonalExportPendingCounterTests` (nuevas), `iCloudSyncServiceTests`, `AccountDeletionServiceTests`, `ContentViewReadinessLogicTests`, `SignOutWipeHookTests`; XCUITest `SessionExitsPerCellUITests` (nueva), `DeleteAccountDialogUITests`, `GroupsRetentionUITests` (borrar) | Alto |

### Modelo de datos
Ninguno. Una key nueva `cloudSync.*` (ancla del export), excluida del barrido de preferencias por prefijo.

## Plan de implementación

### Incrementos (orden de ejecución)
1. **Lógica pura** — `Path` por dos ejes, `PrivateSignOutExportGateLogic`, 12 operaciones de la hoja,
   aterrizaje de «Vaciar», `AccountDeletionRowLogic`.
   - Tests: tablas completas + mutantes (quitar la exclusión del autor del espejo, invertir `>`/`>=` del
     presupuesto, dejar pasar un `nil` como 0).
2. **Ancla + contador** — `apply(…startDate:)` persiste el ancla solo en éxito; contador sobre historial.
   - Tests: `iCloudSyncServiceTests` (éxito persiste y es monótono; error no); on-disk de tres stores
     (cuenta lo local, excluye el autor del espejo, respeta el ancla, dedupe por objeto, ignora otros stores).
3. **Coordinador** — C: espera → arm. D: grupos → espera → re-verificación → teardown → arm (+grupos).
   F: grupos → teardown → arm personal+grupos → swap. Emergencia avisada. Borrado de cuenta en F.
   - Tests: bucle de espera con reloj inyectado; source-scans de ORDEN (espera antes del arm; nunca
     `wipeAllUserData`; F sin `armGroupsOnlyWipe`); `AccountDeletionServiceTests` (F → cierre completo).
4. **UI** — Ajustes con dos filas; hoja por celda; confirmación reforzada; alert de export; «Tu cuenta de
   Yala» con el borrado; retirada de la retención.
   - Tests: `SessionExitsPerCellUITests` (C/D/F: una fila «Cerrar sesión», la de «Vaciar», ninguna de
     salida extra ni de borrar cuenta; la hoja nombra su celda); `DeleteAccountDialogUITests` vía «Tu cuenta».
5. **Copy** — 16 locales; retirar las claves de lo retirado.
6. **Docs/QA** — matriz, `coverage-index`, regla en `swiftdata-cloudkit.md`, guion de device-QA, tickets
   de lo que salga, anotación en la mitad 2 del paso 5.

### Riesgos
- **Autor del espejo no medible en simulador** → device-QA dedicado; si no casara, el fallo es seguro
  (bloquea con salida avisada, nunca borra de más).
- **Ancla ausente la primera vez** → sobre-cuenta; el recorrido de device-QA mide que el ancla se fija.
- **Un save durante un export** → queda como pendiente aunque subiera (conservador: a lo sumo una espera).
- **Alerts en el mismo anchor** → botones literales, alerts dedicados, cadenas sheet → alert.
- **Retirar la retención** mueve el aterrizaje de «Vaciar» en solo-grupos: se repone su shell.

### Estimación
- Incrementos: 6
- Complejidad: alta

## Lo que pidió la puerta de Grupos (mitad 2 del paso 5), y cómo lo contesta este paso

La sesión de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` escribió el 2026-09-10 en este
ticket que este verbo es su segundo consumidor, con tres conclusiones medidas. Ese texto vive en su rama
`encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner` —subida, **sin PR**—, así que
no está en `2.1`. Se trae aquí para que aterrice con este paso, cada punto con su respuesta:

1. **«No reuses `armSignOutWipe` para un camino que no cierra sesión»**: borra `YalaSyncMeta` —el canal de
   Grupos— y purga las colas de Apple Pay y Siri, que nunca pasaron por iCloud. → Este paso lo usa solo
   para CERRAR sesión, que es lo que el hook presupone. En C no hay canal de Grupos que conservar; en D y
   F el outbox se sube y se verifica ANTES del arm, sin salida de emergencia. Purgar las colas del App
   Group es la frontera correcta al cerrar sesión: lo que capturó la cuenta saliente no puede
   materializarse en la entrante.
2. **«La espera de export necesita una señal que hoy no existe»**: `forceSync` devuelve `.ok` sin tocar la
   red, su watchdog convierte «no ha empezado» en «terminó» y `lastExportError` no se limpia nunca. → La
   espera de este paso no usa ninguna de las tres. Su testigo es el historial de SwiftData contra el ancla
   del último export con éxito (el `startDate` del evento del espejo). `forceSync` llama a `apply(…)` sin
   `startDate`, así que no puede mover el ancla. Los dos tickets de aquella rama siguen valiendo para sus
   otros consumidores.
3. **«El arm no tiene desarme si el borrado aborta»** → En `.icloud` (C, D, F) el hook desarma ahora al
   abortar. Con el espejo montado, un reintento posterior borraría cambios que nadie esperó a exportar, así
   que lo seguro es quedarse con los datos. `.cloud` sigue como estaba. Lo que queda, que el fallo se vea,
   está en `sign-out-wipe-abort-in-icloud-says-nothing`.

Y el «al cerrar este paso, avisar a la puerta de Grupos» está hecho en su ticket, sección «Lo que deja el
paso 9». Al rebasar aquella rama sobre `2.1` chocarán 23 ficheros —los 16 `Localizable.strings`,
`L10n.swift`, `ContentView`, `AppBootstrapper`, `UITestHooks`, `GroupsOrganizerGateLogic`, la matriz y su
propio ticket, que allí se movió a `blocked/`—: su añadido a este ticket ya está incorporado aquí, y la
sección del paso 9 de su ticket tiene que viajar a `tickets/blocked/`.

## Implementación (2026-09-11, rama `encargo/2026-09-11-session-exits-one-verb-per-session`)

### Lo que cambia para quien usa Yala

- **Dos botones en Ajustes, en las cuatro celdas**: «Cerrar sesión» y «Vaciar datos». «Eliminar mi cuenta» vive
  dentro de «Tu cuenta de Yala» (dos toques). Se fueron «Salir de Yala en este dispositivo», «Cerrar sesión de
  grupos» y la pantalla «Seguir con mis grupos».
- **Cerrar sesión en tu sesión privada (C) o en el «equipo» (D)**: antes de borrar, Yala espera a que lo último
  que guardaste llegue a iCloud («Guardando tus cambios…»). Luego borra lo de este teléfono, se reinicia y
  vuelve al Welcome; «Restaurar desde iCloud» lo trae todo. En D suben antes tus gastos de grupo.
- **Si iCloud no confirma en 45 s**, un aviso dice cuántos cambios no llegaron —o que no se pudo confirmar— y
  ofrece «Cerrar sesión igualmente» o «Esperar». «Esperar» sigue esperando y cierra solo cuando llegan.
- **Sin iCloud** (el teléfono no espeja, o iCloud contestó que no hay cuenta): la hoja dice que no hay copia en
  ninguna parte y pide un segundo gesto. No hay espera.
- **Solo grupos (F)**: cerrar sesión borra lo local y vuelve al Welcome, como un teléfono nuevo; antes se quedaba
  en una pantalla de grupos sin sesión. Y ahora puede borrar su cuenta, que antes no tenía.
- **Vaciar datos**: en tu sesión privada la hoja avisa de que se borra también en el iPad y en todo dispositivo
  con tu Apple ID, y al terminar vas directo al onboarding personal. En solo grupos sigues en tus grupos.

### Cómo está hecho

- `CloudSignOutFlowLogic`: el camino por celda y `exitPlan`, la tabla pura de quién sube grupos y quién espera.
- `PrivateSignOutExportGateLogic` + `PersonalExportPendingCounter`: el testigo del export —historial local contra
  el inicio del último export con éxito— y la espera con reloj inyectado. La regla durable está en
  `.claude/rules/swiftdata-cloudkit.md`.
- `iCloudSyncService`: el ancla persistida (monótona; se invalida con cambio de cuenta, de reloj y
  `notAuthenticated`; se descarta si queda en el futuro) y el uso de `Event.succeeded`.
- `CloudSessionSignOut`: C, D y F por el mismo boot-wipe de archivos que la nube, con la espera, la salida de
  emergencia que vuelve a contar pegada al arm y «Esperar» que retoma donde se paró.
- `DestructiveScopeLogic` / `DestructiveScopeSheet`: doce operaciones, una por celda y variante de copia.
- `ProfileView` / `YalaAccountView` / `UserDataResetView`: la fila única, las cadenas hoja → aviso, el borrado
  de cuenta con bloqueo cruzado y el aterrizaje de «Vaciar datos».
- Se retiraron `GroupsRetentionView` (con su XCUITest, su seam y su blocker), 29 claves de copy de lo retirado
  y 3 más que ya no usaba nadie.

### La review adversarial (cuatro lentes, 2026-09-11)

Pérdida de datos, flujo de UI, celdas y reglas del repo contra el diff: unos 39 hallazgos, verificados uno a
uno en el código. **Arreglados**, los graves primero:

1. Un export que terminaba con un error que no era de CloudKit movía el ancla como si hubiera ido bien, y el
   cierre borraba lo que no estaba en iCloud. Ahora solo confirma un evento con `succeeded`.
2. «Vaciar datos» en solo grupos sobre un store que espeja decía «No se tocan» y borraba iCloud: hoja completa.
3. El cierre de F dejaba `.groupInvite` en el iCloud KV, y la vida siguiente del teléfono nacía solo-grupos: se
   suelta al cerrar sesión y al borrar la cuenta.
4. La privada con una sesión de grupos caducada descartaba el outbox de grupos en silencio, con una hoja que
   decía «No se tocan»: bloquea pidiendo volver a entrar, y su hoja es la del «equipo».
5. «Esperar» cancelaba el cierre sin decirlo, y parado tras soltar la sesión dejaba el teléfono a medio
   cerrar: ahora retoma.
6. La salida de emergencia contaba antes de las esperas largas y armaba sin volver a contar: re-cuenta al armar.
7. La hoja «sin copia» le mentía a quien tiene iCloud con Drive apagado: «no hay copia» solo con prueba.
8. Un ancla en el futuro (reloj atrasado con la app cerrada) escondía cambios: se descarta.
9. Contar «creado y borrado» como nada podía resucitar un borrado al restaurar: cuenta.
10. «Tu cuenta de Yala» dejaba cerrar sesión y borrar la cuenta a la vez: bloqueo cruzado.
11. Un aviso con productor asíncrono podía quedarse sin presentar, con la fila muda: la presentación se
    reintenta un turno después, y tocar la fila vuelve a pedir el aviso.
12. Una sesión caducada con grupos pendientes decía «revisa tu conexión»: tiene su motivo y su texto.
13. Tests nuevos donde un mutante sobrevivía: la tabla `exitPlan`, el cableado de «Vaciar datos», la celda leída
    en `signOutRowPath`, el control de la reescritura idéntica, el latch de grupos, `succeeded` y el ancla futura.

**Lo que no se tocó, y por qué**: la puerta de quiescencia con Drive apagado (su sustituto colgaría el cierre
en un teléfono sin iCloud; ticket), el foco «solo grupos» de `usageFocus` (no es regresión de este paso) y la
etiqueta del breadcrumb del borrado de cuenta en F (en su ticket).

**Tickets que salen**: `remote-wipe-signal-honored-by-any-session` · `owner-preferences-return-via-ikv-after-private-sign-out`
· `groups-signout-reentry-banner-has-no-producer` · `private-sign-out-keeps-legacy-cloudkit-groups` ·
`cloudsync-witnesses-survive-the-sign-out-wipe` · `sign-out-wipe-abort-in-icloud-says-nothing` ·
`export-anchor-accepts-events-from-any-container` · `private-exit-loses-unmaterialized-inbound-captures` ·
`groups-outbox-rows-without-a-live-session-have-no-exit` · `groups-sign-out-quiescence-gate-fails-open-with-drive-off`
· `icloud-sync-status-treats-non-ck-failures-as-success` · `groups-only-account-deletion-skips-export-wait`.

## Guion de device-QA (NO simulable)

Sin cuenta de iCloud no hay espejo, así que el testigo del export no se puede probar en el simulador.

**Montaje**

1. Un iPhone con tu iCloud y un TestFlight que lleve este cambio. Si tienes un iPad con el mismo Apple ID, úsalo
   también.
2. Para D y F, una cuenta de grupos (Apple o Google) con un grupo de prueba y alguien más dentro.
3. Si puedes, ten abierto el dashboard de métricas: los canarios `privateSignOutExportUnconfirmed` y
   `privateSignOutExportDiscarded` cuentan cuántas veces se agotó la espera y cuántas se salió igualmente.

**Primero, el spike: mide los supuestos del testigo antes de nada**

1. **Lo que baja no cuenta.** En tu sesión privada, crea un gasto en el iPad. Cuando aparezca en el iPhone, toca
   «Cerrar sesión» y confirma. Esperado: cierra sin aviso. Si sale «Cambios de este dispositivo que aún no
   llegaron a iCloud: 1», el espejo no firma sus importaciones como suponemos: para aquí y apúntalo.
2. **Lo tuyo sube y se confirma.** Crea un gasto en el iPhone, espera diez segundos y cierra sesión. Esperado:
   cierra sin aviso, y tras «Restaurar desde iCloud» el gasto está.
3. **Un lote grande.** Importa un CSV de miles de filas y cierra sesión enseguida. Esperado: «Guardando tus
   cambios…» y cierre al terminar; al restaurar están todas las filas. Si falta alguna, el ancla da por subido
   lo que no: ticket `export-anchor-accepts-events-from-any-container`.
4. **Sin iCloud.** En un dispositivo de pruebas sin sesión de iCloud, toca «Cerrar sesión». Apunta qué sale: la
   hoja «no hay copia», o la hoja normal y, a los 45 s, «no pudimos confirmar». Lo segundo es seguro, pero
   decide el ticket `groups-sign-out-quiescence-gate-fails-open-with-drive-off`.

**Después, los recorridos**

1. **C con copia**: cierra sesión → pantalla de reabrir → sal al inicio → abre Yala → Welcome → «Ya tengo
   cuenta» → «Restaurar desde iCloud». Tiene que estar todo.
2. **C sin red**: modo avión, crea un gasto y cierra sesión. Verás «Guardando tus cambios…» y a los 45 s el aviso
   con un 1. Toca «Esperar» y quita el modo avión: tiene que cerrar solo. Repite eligiendo «Cerrar sesión
   igualmente»: tras restaurar ese gasto no está, y el aviso lo había dicho.
3. **C, matando la app**: en el recorrido 2, fuerza el cierre de Yala durante la espera. Al reabrir, la sesión y
   los datos siguen ahí.
4. **D**: con la cuenta de grupos, anota un gasto de grupo en modo avión y cierra sesión. Tiene que quedarse en
   «un momento más» sin borrar nada. Con red, vuelve a tocar «Cerrar sesión»: cierra, y en el otro teléfono el
   gasto llegó. Al volver («Restaurar desde iCloud» y entrar en Grupos), está todo.
5. **F**: entra solo por Grupos y cierra sesión → Welcome, no la pantalla de grupos. Después «Primera vez →
   privado»: tiene que abrirse la app completa, no la de grupos (es el arreglo del iCloud KV).
6. **F, borrar la cuenta**: «Tu cuenta de Yala» → «Eliminar mi cuenta» → confirma → Welcome.
7. **Vaciar datos en C**: la hoja nombra todos tus dispositivos. Confirma: el iPad también se vacía, y el iPhone
   va directo al onboarding personal.
8. **Vaciar datos en F**: sigues en tus grupos, con el perfil y las preferencias restablecidos.

## Verificación de cierre (2026-09-11, segunda sesión)

La sesión anterior se cortó por tokens antes del gate; ésta lo cerró. **Todo commiteado.**

- **Suite unitaria completa**: 6848 tests en 701 suites, cero rojos (`-parallel-testing-enabled NO`).
  Incluye las 11 suites del paso 9 (120 casos) y la `SignOutBackendGroupRowsTests` nueva (4).
- **Builds** `Yala` y `Yala Dev`: los dos en verde y **cero warnings nuevos**. Los dos warnings que
  caen en ficheros tocados (`ContentView.swift:1779`, `DataWipeService.swift:297`) son preexistentes,
  comprobados contra `ba618216` línea a línea. Uno que sí era mío —`DataWipeService.swift:489`, el
  default argument `= OwnerKeyValueStore.shared` de `releaseGroupsOnlyOnboardingModeFromICloudKV`,
  que se evalúa en el contexto nonisolated del llamador— se corrigió quitando el parámetro: el valor
  se resuelve dentro del cuerpo, que sí es `@MainActor`. Nadie lo inyectaba.
- **XCUITest**: **las 62 clases, por lotes de 6 y en primer plano**: 62/62 clases, 139 casos verdes y UN rojo, `TransactionsCrudUITests.test_createTransaction` — el flaky del helper de guardar (`transaction-save-helper-flake-one-per-suite`), **bisecado contra un worktree limpio de `ba618216`, donde cae igual**. Muestra 19 escrita en su ticket. La clase nueva `SessionExitsPerCellUITests` pasa sus tres casos.
- **Mutantes: 15 aplicados, 14 muertos.**
- **M15 sobrevive, y eso es el hallazgo.** Quitarle el `> 0` al filtro de `updatedAttributes` de
  `PersonalExportPendingCounter` deja verde «una reescritura idéntica no cuenta» ⇒ el historial de
  SwiftData **no entrega ninguna actualización** para una reescritura idéntica, ni siquiera una con
  la lista vacía. El cero de ese caso lo pone el historial, no el filtro. El filtro se queda —cubre
  el caso contrario y es barato—, pero los tres sitios que lo explicaban como si fuera el mecanismo
  (el docblock del contador, el del test y `.claude/rules/swiftdata-cloudkit.md`) ahora dicen lo medido.
- **Audit de las 2 885 líneas añadidas**: cero `try?`, cero force unwraps, tres `print(` — los dos de
  producción dentro de `#if DEBUG`, el tercero en un test.
- **Índice de QA**: `RESULT: OK`. **Board**: 298 tickets en disco = 298 en `docs/TICKETS.md`.

**Lo que sigue sin hacerse, y es de Jürgen**: el device-QA del guion de arriba. **NO es simulable.**

## Qué cambió bajo este guion el 2026-09-12 (#150) — míralo al correrlo

El eje que elige la celda de cierre **ya no sale del flag de onboarding**: sale de una marca
persistida propia (`PrivateSessionMark`). Los recorridos son los mismos y no se ha tocado ninguna
pantalla, pero si alguno diera un resultado distinto al esperado, **mira el eje antes que el flujo**:

- **Qué comprobar de más, en las dos celdas que ya cubre este guion.** En **D** (privada + cuenta de
  grupos) y en **F** (solo grupos), que la hoja prometa exactamente lo que el borrado hace. Antes las
  dos cosas salían de la misma fuente y no podían contradecirse; ahora la hoja y el alcance leen la
  marca y el resto de la shell sigue leyendo el flag, así que una divergencia se vería aquí primero.
- **El caso nuevo que este guion NO cubría y conviene añadir:** «Vaciar datos» desde **F**, mirando si
  el iPad o el Mac del mismo Apple ID se vacían también. **No deben.** Esa decisión es la única que
  lee la lectura estricta del eje (`confirmedPrivateSession`), y su modo de fallo alcanza datos que no
  están en este teléfono.
- **Y un caso de entorno, barato de provocar:** entra por un grupo, cierra sesión, y comprueba que el
  teléfono **no se queda creyendo que sigue siendo solo-grupos**. La marca muere en el boot-wipe del
  cierre; si sobreviviera, la vida siguiente de ese teléfono heredaría el eje del humano anterior.

Nada de esto es simulable: el simulador no tiene sesión de nube y las dos celdas piden dos
dispositivos del mismo Apple ID.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con los recorridos C1, C2 y C3 (sesión privada). D y F, que piden otra persona, quedan cubiertos por los tests.
