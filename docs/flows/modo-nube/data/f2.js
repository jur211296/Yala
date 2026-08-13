// f2.js — el estado del chip F2: capturas en simulador + lista device-only.
//
// Recorrido el 2026-08-10 contra HEAD f4d10fa6 (branch 2.0.5), simulador iPhone 17 Pro
// (iOS 26.5), scheme Yala Dev (staging: percents al 100, attest en bypass de sim).
// Vehículo: XcodeBuildMCP (snapshot_ui/tap/screenshot) + `xcrun simctl launch` directo
// para los launch-args (launch_app_sim los descarta) + axe para taps por coordenada.
//
// REGLA del chip, aplicada aquí: cada nodo del Atlas tiene o una imagen REAL del sim
// (img/<id>.png) o una marca device-only con su motivo y qué debería verse — jamás una
// pantalla parecida de otro estado. `check.mjs` valida que ningún nodo quede vacío.
//
// Los estados sembrados (par `.cloud`, beta unlock, kill-switch DEBUG) se escribieron con
// `xcrun simctl spawn <udid> defaults write` — las MISMAS keys que escribe el código real
// (`StorageModePersistence.writeCloudArmed` escribe exactamente `cloudSync.storageMode` +
// `cloudSync.migration.relaunchRequested`); un `defaults write` del host NO persiste
// (el cfprefsd del sim lo pisa).

// **F3 (2026-08-11)** · pasada de refresco tras la tanda del relanzamiento cero, contra HEAD
// `24b4bc91`, mismo vehículo y mismo simulador. Re-capturado `alta-newchooser.png` (el badge
// «Recomendado» ya no existe) y capturado por primera vez `alta-mirrorrelaunch.png`, el terminal
// nuevo del Welcome. `alta-privado.png` se CONSERVA tras comprobar que la pantalla de destino es la
// misma —lo que cambió es que ahora hay un relanzamiento por delante, y eso se verificó en sim—.
// Los dos estados nuevos que el sim NO puede dar entran a `deviceOnly` con su motivo.

// **F5 (2026-08-12)** · derivación del código + pasada de captura en el simulador (iPhone 17 Pro
// `9D0F6D32`, iOS 26.5, scheme **Yala Dev** en configuración `Debug-Dev`).
//
// ⚠️ La configuración importa y costó un build: el scheme «Yala Dev» NO usa `Debug` sino **`Debug-Dev`**.
// Compilado con `Debug` sale el bundle de PRODUCCIÓN (`com.jurgenschmidt.yala`, sin `DEV_BUILD`), y con él
// los percents remotos apagados ⇒ ni el sub-chooser de nube ni el canal de Grupos aparecen, y el recorrido
// que este chip necesitaba habría sido invisible.
//
// Se RE-capturaron las 8 que las olas W/G/C/M habían dejado obsoletas y se estrenaron 3 pantallas que el
// Atlas no tenía. `stale` queda VACÍO, y se conserva el mecanismo: es la categoría que hay que usar cuando
// una pantalla se re-escribe y su imagen no se puede rehacer en el momento.
//
// Lo que la pasada verificó de paso, además de fotografiar (comportamiento, no solo píxeles):
//   · el educativo es el PRIMER escalón de la puerta del organizador, y la card «Solo grupos» del
//     onboarding cede a ESA MISMA cadena — las dos mitades de `GroupsGateLogic` vistas en vivo;
//   · cancelar el educativo devuelve al chooser de grupos del Welcome, que es lo que la matriz de
//     cancelación de la rama organizador promete;
//   · la puerta con el canal apagado pinta su copy propio y sus DOS botones «Volver».
//
// ⚠️ Y una trampa de método, MEDIDA aquí: en un build **Yala Dev**, una instalación limpia **no nace
// virgen en preferencias**. A los 12 s de un launch sin tocar nada ya existen `onboardingMode = groupInvite`,
// `userName = Ana` y `defaultCurrencyCode = PEN` —las TRES sincronizadas, ninguna per-device—. No lo escribe
// la rama del organizador (se comprobó sin interactuar) y no se identificó al escritor. Consecuencia
// práctica: **la invariante «nada se persiste hasta que la cadena confirma» NO se puede verificar en Dev
// leyendo el plist**, porque el arranque ya deja esas keys puestas.

window.ATLAS_F2 = {
  head: "6c6eb3fe",
  date: "2026-08-12",

  // ── Capturas que ya no muestran la pantalla de hoy (vacío: F5 las rehízo todas) ──────
  stale: {},

  // ── Nodos SIN captura de sim: motivo + qué debería verse ─────────────────────────────
  // `pending: true` ⇒ el simulador SÍ puede darla y este chip no la hizo. Todo lo demás es device-only
  // de verdad: el sim NO puede producir ese estado.
  deviceOnly: {
    "alta-groupsgate": {
      pending: true,
      reason: "INTENTADA el 2026-08-12 y no conseguida: la pantalla dura lo que dure el `refreshIfDue(force: true)` y con el canal encendido el step se desmonta en la misma vuelta. Dos ráfagas de `simctl io` no la pillaron —la primera terminó antes del tap, la segunda tampoco coincidió—. Se captura provocando latencia (Network Link Conditioner) o con el canal a punto de responder, no con una ráfaga a ciegas.",
      expected: "Spinner grande en blanco sobre el fondo hero y «Comprobando que todo esté listo…» (WelcomeGroupsGateView.swift:97-109). Su variante BLOQUEADA sí está capturada, en img/alta-groupsgate-blocked.png."
    },
    "alta-organizername": {
      pending: true,
      reason: "MEDIDO el 2026-08-12: vive detrás del sign-in de Grupos, y el simulador no completa SIWA (sin cuenta de Apple) ni Google. El recorrido llega hasta la pantalla de sign-in —capturada— y se detiene ahí. El seam `-uitest-fake-cloud-session` da `hasSession` pero pone la app bajo `-uitest`, donde los getters de canal cortan a su default y el recorrido deja de ser el real.",
      expected: "Cover con «¿Cómo te llamas?», «Es el nombre que verán los demás en el grupo.», campo «Tu nombre» y el botón «Crear mi grupo» (GroupsOrganizerNameView.swift)."
    },
    "onboarding-crear": {
      pending: true,
      reason: "F5 · la imagen que este nodo tenía (`onboarding-crear.png`) NO era el formulario: era la pantalla del consent de Grupos. Al ganar el consent frame propio, la imagen se RENOMBRÓ a `onboarding-consent.png` —que es lo que de verdad muestra— y este nodo se queda sin la suya. El formulario vive detrás del sign-in, con la misma barrera que `alta-organizername`.",
      expected: "El formulario de grupo (`GroupFormView`) recién abierto: nombre, divisa y la lista de miembros vacía."
    },
    "onboarding-canalapagado": {
      pending: true,
      reason: "MEDIDO el 2026-08-12: el alert vive en el TAB Grupos, y llegar al tab exige haber cerrado la cadena de puertas (sesión real). Por el Welcome no se alcanza: con el canal apagado la rama del organizador se detiene ANTES, en la puerta —ese estado sí está capturado en img/alta-groupsgate-blocked.png, con el MISMO par de keys—. Y bajo `-uitest` el kill-switch DEBUG ni siquiera se respeta: `CloudRemoteFlags.decide` corta a `absentDefault` antes de leerlo.",
      expected: "Alert «Ahora mismo no podemos abrirte grupos» sobre el tab Grupos, con la lista intacta detrás y sin ningún grupo creado. La segunda superficie es el mismo texto como error de guardado dentro del formulario."
    },
    "alta-error-403": {
      reason: "Requiere un 403 real del backend (cuenta suspendida server-side); el sim no puede fabricarlo.",
      expected: "El mismo layout de error del alta que alta-error-401, pero SIN botón Reintentar (CloudWelcomeSignInFlow.swift:161-163)."
    },
    "alta-error-transient": {
      reason: "La fase de pantalla es la MISMA que la del 401 — `.error(retryable: true)` — y su render está capturado en alta-error-401. Provocar la causa real (red caída / 5xx) no es posible en sim con staging accesible.",
      expected: "Idéntico a img/alta-error-401.png: «Algo no salió bien» + Reintentar. La vista no distingue la causa; solo el flag retryable cambia el render."
    },
    "alta-par-relaunch": {
      reason: "La pantalla terminal exige un claim `created` real y en sim SIWA/Google no completan sesión (el sim no tiene cuenta de Apple; Google exige credenciales reales). Desde R2 exige ADEMÁS un device con archivo de store: una instalación fresca ya no llega aquí.",
      expected: "Pantalla terminal con icono de recarga: «Cierra Yala y vuelve a abrirla», sin botones ni back (WelcomeCloudSignInView.swift:427). El equivalente visual del sign-out sí está capturado en img/signout-relaunch.png, y el del Welcome en img/alta-mirrorrelaunch.png."
    },
    "alta-bornready": {
      reason: "Exige un claim `created` REAL: la fase `.bornCloudReady` sale de `activateBornCloudStorage`, que solo corre tras un alta completa contra el backend, y en sim SIWA/Google no completan sesión. El seam `-uitest-fake-cloud-session` no sirve —hace `hasSession` true con `accessToken()` nil, así que el claim devuelve `sessionExpired` y la pantalla es el error 401, ya capturado—.",
      expected: "Check verde, «¡Tu cuenta está lista!», «Ya puedes empezar. Todo lo que registres se guardará en tu cuenta.» y un botón «Empezar» (`welcome_born_cloud_ready`, WelcomeCloudSignInView.swift:449). Al pulsarlo, el onboarding de img/alta-postrelaunch.png."
    },
    "alta-waitingleader": {
      reason: "Requiere que el backend devuelva `claiming_in_progress` (otro device liderando un claim) — no fabricable desde el sim.",
      expected: "«Otro dispositivo está migrando» + Reintentar + «Continuar a la app» (WelcomeCloudSignInView.swift:401)."
    },
    "degradado-claiming": {
      reason: "Misma pantalla y misma dependencia server-side que alta-waitingleader.",
      expected: "La pantalla de espera con Reintentar y «Continuar a la app»."
    },
    "degradado-mount": {
      reason: "SIN PANTALLA POR CONSTRUCCIÓN (hallazgo F1-H1): el guard solo apaga el motor y deja el breadcrumb `personalMountMismatch`. No hay nada que capturar sin fingir.",
      expected: "Nada visible. La card que SÍ se ve cuando el par está armado con el proceso montado en .icloud es la de Almacenamiento — capturada en img/migracion-relaunch.png (ese estado se fabricó REAL en sim: par escrito con el proceso vivo)."
    },
    "degradado-sesion": {
      reason: "El banner S11 exige outbox vivo > 0 con sesión irrenovable en `.cloud`; el outbox es SwiftData y no se puede sembrar sin una sesión backend real.",
      expected: "En Almacenamiento: «tienes N cambios sin subir» + botón de re-entrada con el método de la cuenta (SessionExpiryPolicy.swift:34)."
    },
    "degradado-sinred": {
      reason: "En el alta, el render sin-red es la misma fase `.error(retryable: true)` capturada en alta-error-401; los estados sin-red del adopt y de la migración requieren la máquina real conducida contra backend.",
      expected: "Alta: error con Reintentar. Adopt: la pantalla se queda y entra el auto-resume. Migración: la barra se aparca y el foreground re-kickea."
    },
    "migracion-adopt-copy": {
      reason: "La variante ADOPT exige el marcador CloudKit de un líder real en el mirror (`markerDecision() == .secondaryDeviceCloudLogin`) — multi-device real.",
      expected: "La misma pantalla de Almacenamiento idle pero con el copy de ADOPTAR en vez de MIGRAR, y sin doble confirmación destructiva."
    },
    "migracion-cutover": {
      reason: "Los 4 sub-estados del cutover pertenecen a una migración real avanzada (staging + sesión); en sim la máquina se aparca en `claimingMigration` sin sesión.",
      expected: "La misma barra de progreso de img/migracion-progreso.png, con el 89 % (`markerWritten`) esperando la confirmación de iCloud y su caption honesto."
    },
    "migracion-fallo": {
      reason: "El journal (`MigrationState`) es SwiftData y no es sembrable desde fuera; llegar a `failedRollback` exige una migración real que falle.",
      expected: "Card de fallo con uno de los 4 copys por veredicto (iCloud lleno · no activo · sin confirmar · genérico) + botón Reintentar (StorageSettingsView.swift:421)."
    },
    "reentry-adopt": {
      reason: "La máquina de adopt exige sesión backend real y una cuenta poblada.",
      expected: "Barra de progreso + «Conectando…», más el hint honesto de import si la pre-espera de quiescencia está activa."
    },
    "reentry-autoresume": {
      reason: "Además de la sesión real, el botón manual exige agotar 3 auto-resumes sin avance (~12 s de máquina real aparcada).",
      expected: "La misma pantalla del adopt; tras agotar intentos, aparece el botón «Reintentar» manual."
    },
    "reentry-blocked": {
      reason: "Exige una sesión real de una cuenta DISTINTA a la del claim persistido en el device (guard cross-cuenta).",
      expected: "«Estos datos son de otra cuenta» con icono de escudo; back permitido."
    },
    "reentry-mismatch": {
      reason: "Exige el faro iCloud-KV escrito con un provider distinto MÁS una sesión real que lo contradiga; el iCloud-KV del sim no es sembrable desde fuera y no hay sesión.",
      expected: "«Parece que tu cuenta se creó con Apple/Google» (o el copy genérico si el provider no se reconoce)."
    },
    "reentry-notfound": {
      reason: "Exige una sesión real cuyo `GET /account/exists` devuelva false — sin sesión el flujo no llega a `exists`.",
      expected: "«No encontramos una cuenta», con back permitido."
    },
    "reentry-relaunch": {
      reason: "Terminal del adopt completo — misma dependencia que reentry-adopt.",
      expected: "La misma pantalla terminal de relanzamiento del alta (ver img/signout-relaunch.png como referencia visual del patrón)."
    },
    "reentry-slotocupado": {
      reason: "Exige DOS cuentas SIWA reales y un descriptor secundario ya escrito por la primera invitada; el seam `-uitest-secondary-session` finge el descriptor pero no puede firmar una segunda cuenta distinta. Y la entrada secundaria sigue DARK en producción.",
      expected: "La MISMA pantalla de img/reentry-blocked.png cuando exista: candado, «Este dispositivo tiene datos de otra cuenta» y el back permitido. No hay copy propio para este caso."
    },
    "reentry-secondary": {
      reason: "M1 está DARK y la pantalla de confirmación vive tras exists + guard con sesión real; el descriptor FAKE del panel DEBUG monta el store secundario pero no fabrica esta pantalla.",
      expected: "«Entrarás con tu cuenta; los datos del dueño no se tocan» + CTA y Cancelar propio."
    },
    "reversa-cierre": {
      reason: "El terminal `icloudActive` exige una reversa completa real (backend + sesión).",
      expected: "Vuelta a la pantalla de estado iCloud de img/migracion-idle.png — se vuelve a ofrecer migrar."
    },
    "reversa-confirm": {
      reason: "Los dos diálogos solo salen desde el botón de reversa, y el botón está gateado por `reverseEligibility()` — que exige sesión, imposible en sim. La card en su variante no-elegible SÍ está capturada (img/reversa-card.png).",
      expected: "Dos confirmationDialogs destructivos encadenados, análogos a los de migración (img/migracion-confirm.png)."
    },
    "reversa-fases": {
      reason: "Las fases `reverse*` pertenecen a una reversa real conducida.",
      expected: "La misma card de progreso de migración con el copy «Revirtiendo…»."
    },
    "reversa-relaunch": {
      reason: "Fase `reverseMountMirror` de una reversa real.",
      expected: "La misma card bloqueante de relanzamiento de img/migracion-relaunch.png (dirección `toICloud`)."
    },
    "signout-pushall": {
      reason: "El spinner y el caption «Guardando tus cambios pendientes…» son ventanas del drenaje real de un outbox con sesión backend viva.",
      expected: "Spinner en la fila de cerrar sesión y, en bloqueo transitorio, el caption honesto."
    },
    // ── R3 · Llego con una invitación a un grupo ──
    "r3-landing": {
      pending: true,
      reason: "No es una pantalla de iOS: es la página SSR `Web/src/pages/invite.astro` renderizada en un navegador. El simulador no la produce por definición. Para capturarla hay que levantar el sitio (`Web/`) y abrir `/invite` con una query completa (`?g=&t=&s=&n=&i=&c=&m=&u=`), o abrir un enlace de invitación real en un navegador. No se intentó en esta pasada.",
      expected: "Fondo oscuro, logo de Yala arriba, tarjeta con el icono del grupo en su color, el NOMBRE del grupo como titular, la etiqueta «Miembros» con los chips de los nombres, y los dos botones «Abrir en Yala» (arriba, relleno) y «Descargar en App Store» (abajo, contorno). Footer «Yala — Finanzas personales, sin esfuerzo». Una segunda toma sin `m=` debería mostrar «Te invitaron a este grupo en Yala» en lugar de los chips."
    },
    "r3-aprobacion": {
      reason: "Requiere un SEGUNDO humano con rol admin aprobando o dando de baja contra el backend REAL, y que ese cambio baje por el pull. El simulador no puede: crear el grupo y el member exigen sesión Nube y App Attest, y App Attest rechaza un build de desarrollo contra producción (`verifyAttestation.ts:79`). Con `Yala Dev` (staging) sería otro mundo de datos y aun así hace falta el segundo device. No hay ningún seam `-uitest` que ponga a mi member en `pendingApproval` — `DevSeedGroups` los siembra todos `.active` (`DevSeedGroups.swift:46`).",
      expected: "Dos tomas. (a) APROBADO: el mismo grupo antes con el banner naranja «Esperando aprobación del admin» y la lista de gastos vacía, y después sin banner, con sus gastos y con el FAB de crear gasto visible. (b) BAJA: el tab Grupos con la tarjeta del grupo, y la toma siguiente sin ella — sin ningún alert, banner ni mensaje entre las dos."
    },
    "r3-err-canal": {
      pending: true,
      reason: "No se puede producir de forma determinista desde el código: la rama `.backendUnavailable` exige que `CloudSyncFlags.groupsBackendEnabled` siga OFF DESPUÉS de un `refreshIfDue(force: true)`, y eso lo decide el snapshot vivo de remote-config (`absentDefault = false`, refresco ≤ 6 h, `GROUPS_BACKEND_ROLLOUT_PERCENT`, hoy al 100 en producción). Con el device dentro del bucket la ruta sale `.backend` y el alert no llega. Confirmarlo exige correr el escenario con el canal apagado, no leer código. No se intentó.",
      expected: "Un alert del sistema, título «Hubo un problema con el grupo», cuerpo «No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a intentarlo en un momento.» y un único botón «OK». Sin botón de reintentar y sin nada detrás salvo la pantalla en la que estuviera el usuario."
    },
    "r3-err-red": {
      pending: true,
      reason: "Su cara distintiva es el texto rojo de `GroupsSignInView`, y llegar a esa vista exige el canal ENCENDIDO más un enlace backend real sin sesión Nube (`.presentGroupsSignIn`); encima hay que hacer FALLAR el sign-in para encender `signInFailed` (`GroupsSignInView.swift:58`). No existe ningún seam `-uitest` que fuerce ese estado (`-uitest-fake-cloud-session` hace lo contrario). Las otras dos caras no son capturables por definición: una es la ausencia de UI y la otra es el sheet de sign-in reapareciendo.",
      expected: "La pantalla de sign-in de Grupos (icono `person.crop.circle.badge.checkmark`, título y cuerpo de `groups.signin.*`) con un párrafo en rojo bajo el cuerpo: «Hmm, no pudimos conectar tu cuenta ahora. Tu grupo sigue aquí y no pierdes nada — inténtalo más tarde.», y los botones de Apple y Google intactos debajo."
    },
    // ── R10 · Estoy de visita en el móvil de otra persona ──
    "visita-reentrar-cuenta": {
      reason: "La parte distintiva del panel es lo que el guard cross-cuenta decide DESPUÉS de que el backend conteste `accountFound`, y eso exige una cuenta real y un sign-in real (Apple o Google) contra el gateway. En producción la entrada secundaria no existe (`SECONDARY_SESSION_ROLLOUT_PERCENT = \"0\"`, gateway/wrangler.toml:176) y un build de desarrollo no puede atestar contra producción; contra staging haría falta el scheme `Yala Dev` con una segunda cuenta real firmada en el simulador, que no es un estado que el sim reproduzca por sí solo. El sub-chooser de las tres cards SÍ se pinta en un build DEV, pero la captura sin el desenlace no dice nada de este panel.",
      expected: "El sub-chooser «Elige cómo quieres recuperar tus datos.» con sus tres cards y, encadenada, la pantalla de sign-in de la re-entrada — con la sesión de invitada viva y sin ninguna mención de ella. En el caso bloqueado, la pantalla honesta «Este dispositivo tiene datos de otra cuenta»."
    },
    "visita-restaurar-icloud": {
      reason: "Las tres ramas del panel exigen tres estados de iCloud distintos y el simulador solo produce uno con fiabilidad: sin cuenta iCloud, `startSearch` sale por `.iCloudDisabled` y ni la búsqueda ni el `.notFound` llegan a existir. La rama `.wiped` es capturable en sim (basta llegar aquí tras el vaciado en sesión), pero la rama que el panel usa para su tesis —los 90 s de espera sobre un store sin espejo hasta «No encontramos tus datos»— necesita un dispositivo con cuenta iCloud viva y sin señal de wipe fresca.",
      expected: "Las tres pantallas del fan-out: «Activa iCloud para continuar», «Borraste tus datos» y la secuencia «Conectando con iCloud…» → «Trayendo tus datos…» → «No encontramos tus datos», las tres con «Empezar desde cero» como botón."
    },
    "visita-cuenta-nueva": {
      reason: "El sub-chooser con las dos cards sí se pinta en un build DEV (staging sirve `CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT` al 100), pero lo que el panel retrata es el ALTA que resuelve `created` y escribe el faro, y eso crea una cuenta real en el backend. En producción la card no existe (percent 0, gateway/wrangler.toml:132) y la sesión secundaria tampoco (:176), así que la combinación no es alcanzable ahí; en staging exige un alta real que no se puede fabricar desde el simulador sin ensuciar el backend.",
      expected: "«Elige dónde quieres guardar tus datos.» con las dos cards, el consentimiento y el alta, más la evidencia de que el faro quedó escrito en el iCloud KV del Apple ID del dispositivo (no hay pantalla que lo muestre: sería una comprobación fuera de la captura)."
    },
    "visita-privado-alert": {
      pending: true,
      reason: "El alert exige `hasExistingData == true` en el instante del tap, y el único camino medido que trae a la invitada al chooser —el vaciado en sesión— es justamente el que deja el store personal vacío. Para que salte harían falta grupos vivos en el store MONTADO: con el canal de Grupos encendido (que es lo que sirve staging a un build `Yala Dev`) ese store es `YalaGroups-Secondary`, que nace vacío porque no hay pull real; y para que fuera el del dueño haría falta apagar el canal, cosa que no he medido cómo hacer desde un build DEV en el simulador. La variante que el panel llama HALLAZGO GRAVE (borrar los grupos del dueño) es exactamente la que no se puede montar hoy.",
      expected: "El alert «Empezar desde cero» · «Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?» con «Borrar todo y continuar» y «Cancelar», sobre el Welcome oscuro y con el chooser detrás."
    },
    // ── R11 · El dueño recupera su móvil ──
    "vuelta-pushall": {
      reason: "El estado que retrata (fila con spinner y deshabilitada) exige `signOutCoordinator.phase == .working` SOSTENIDO, y eso solo ocurre mientras el push-all cicla contra un backend real. En el simulador `CloudMigrationController.shared` sí existe (AppBootstrapper.swift:305-306 solo pide `CloudBackendConfig.isConfigured`), pero con el outbox vacío el veredicto es `.drained` en microsegundos y el spinner es un parpadeo, no una pantalla. Y forzarlo de verdad exige una sesión secundaria REAL: está al 0 % en producción y App Attest rechaza builds de desarrollo contra producción (AAGUID `appattestdevelop` vs `production`).",
      expected: "La sección «Seguridad y cuenta» con la fila «Cerrar sesión» deshabilitada y su spinner a la derecha, y SIN el caption «Guardando tus cambios pendientes…» debajo — la ausencia de ese caption es justo lo que la captura tiene que probar."
    },
    "vuelta-bloqueado": {
      reason: "El alert exige un veredicto `.blocked`, es decir filas VIVAS en `SyncOutbox` que el push-all no consiga drenar. En el simulador bajo `-uitest` el store es `YalaModel-UITest` recién creado y el conteo da 0 ⇒ `.drained`. No medí si un guardado dentro de la sesión secundaria fake llega a encolar filas de outbox en el simulador (dependería de que el runtime de sync arranque en ese proceso), así que no lo afirmo en ninguna dirección: lo que sí está medido es que el camino natural en sim NO bloquea.",
      expected: "Alert de sistema con el título «No pudimos cerrar tu sesión», el cuerpo «Hay cambios sin subir a la nube y no queremos que pierdas nada. Revisa tu conexión e inténtalo de nuevo.» y un único botón «OK», sobre la pantalla de Ajustes."
    },
    "vuelta-cover": {
      pending: true,
      reason: "MEDIDO y refuta la vía alternativa que se había propuesto: el cover NO se puede sacar de la ventana de ENTRADA secundaria (ContentView.swift:1746). `UITestEphemeralDefaults.applySecondarySession` declara el testigo del mount con `setMountWitness(true)` (:174) precisamente para no caer en esa ventana, y su docblock (:154-157) lo dice —«La VENTANA DE ENTRADA no es expresable desde XCUITest y no se intenta»—, lo mismo que la cabecera de `SecondarySessionGateUITests.swift:23-26`. Queda la vía del propio cierre (presentador ContentView.swift:1671): con el outbox vacío el camino secundario llega a `.drained` → `armWipe` → `.awaitingRelaunch` y el cover aparece. No la ejercité, y tiene un coste que hay que decidir antes: `SecondarySessionStore.armWipe()` escribe `cloudSync.secondaryWipeArmed` en el `UserDefaults` PERSISTENTE del simulador, y ese dominio no lo purga nadie (`-uitest-reset` no limpia `cloudSync.*` y `DataWipeService` las excluye a propósito — UITestEphemeralDefaults.swift:159-164), así que el siguiente arranque manual correría el boot-cleanup y dejaría el simulador en Welcome.",
      expected: "Pantalla completa sobre fondo de panel, sin ningún botón: flecha circular gris, título «Ya casi está — reinicia Yala» y debajo «Ve a la pantalla de inicio y vuelve a abrir Yala — todo quedará listo.» Nada de barra de navegación ni tab bar."
    },
    "vuelta-restaurar": {
      pending: true,
      reason: "No medí qué pinta `WelcomeRestoreView` en un simulador sin cuenta de iCloud. Tiene cuatro estados alternativos con copy propio —«no encontrada» (:281-283), «iCloud desactivado» (:292-296), error (:305-307) y «wiped» (:319-321)— y cuál sale depende del fetch de CloudKit, que en el simulador no corre de verdad (`-uitest-fake-icloud` fuerza `isAccountAvailable` pero no habilita CloudKit real). El resumen sí se calcula del store LOCAL, así que con datos sembrados la pantalla del resumen podría salir; hay que probarlo antes de afirmarlo.",
      expected: "«¡Hola <nombre>! Qué bueno verte de vuelta.», «Encontramos tus datos en iCloud:» y los chips con los conteos («N cuentas», «N registros», «N presupuestos», y «N grupos compartidos» si los hay), el botón «Continuar» y, debajo, «Empezar desde cero»."
    },
    // ── R6 · Soy privada y salgo de Yala ──
    "signout-restaurar-vuelta": {
      pending: true,
      reason: "`WelcomeRestoreView.startSearch()` (WelcomeRestoreView.swift:113-117) corta en `guard iCloudSyncService.shared.isAccountAvailable` ANTES de buscar nada, y ese getter es `FileManager.default.ubiquityIdentityToken != nil` (SwiftDataConfiguration.swift:36-38). Un simulador sin Apple ID iniciado cae SIEMPRE en `.iCloudDisabled` y no llega jamás a la pantalla de reencuentro. NO se intentó en esta sesión: no se lanzó la app ni se comprobó si el iPhone 17 Pro del inventario tiene sesión de iCloud. Si la tiene, la captura es posible en sim, con la advertencia de que `RestoreProgressView` espera quiescencia hasta 90 s (RestoreProgressView.swift:28) antes de asentar y decidir `.found`/`.notFound`.",
      expected: "La pantalla de reencuentro: «¡Hola <nombre>! Qué bueno verte de vuelta.», «Encontramos tus datos en iCloud:» y las cuatro tarjetas de conteo (cuentas / registros / presupuestos / grupos compartidos), con «Continuar» y el «Empezar desde cero» pequeño debajo. Idealmente además un segundo fotograma de la pantalla de progreso con «Trayendo tus datos…»."
    },
    // ── R5 · Vuelvo a Yala en un móvil nuevo ──
    "reentry-movilnuevo": {
      reason: "El arco termina en «Verificando tu cuenta…», que exige un sign-in REAL con SIWA o Google. El propio código lo declara donde más cuesta: WelcomeCloudSignInView.swift:254-260 dice que llegar a esas fases «exige un sign-in REAL con SIWA/Google […] y el simulador no firma». El prefijo (chooser → sub-chooser → «Entra a tu cuenta») SÍ es alcanzable en `Yala Dev` contra staging sin firmar, pero duplicaría `reentry-chooser.png` y `reentry-intro.png`, que ya existen. NO ejecuté el simulador para refutarlo.",
      expected: "Idealmente una tira de tres: el sub-chooser con sus TRES cards («Restaurar desde iCloud» · «Entrar con Apple» · «Entrar con Google») bajo «Elige cómo quieres recuperar tus datos.», la pantalla «Entra a tu cuenta», y el spinner «Verificando tu cuenta…» inmediatamente después de la hoja de Apple. Lo que hay que ver es que la pantalla intermedia EXISTE y que después del Face ID no hay ninguna pregunta más."
    },
    "reentry-mismomovil": {
      reason: "El panel entero cuelga de que la sesión de Supabase sobreviva al borrado de la app, que es una INFERENCIA sin medir. Reproducirlo exige: firmar de verdad en un device, borrar la app, reinstalarla y llegar al consent. Ninguno de esos pasos existe en el simulador (no hay sign-in real), y además es la primera cosa que el device-QA debería comprobar.",
      expected: "Dos fotogramas consecutivos: el sheet del consent con «Entiendo y quiero activar la nube», y lo que sale al tapearlo — «Verificando tu cuenta…» SIN que se haya interpuesto ninguna hoja de Apple/Google ni Face ID. La ausencia es la prueba."
    },
    "reentry-falsobloqueo": {
      reason: "La cadena exige un import REAL de CloudKit (corpus materializado) más un sign-in REAL, y además el resultado depende del flag de sesión secundaria: en producción da el bloqueo, en un build DEV contra staging (percent 100) la misma cadena rutea a la confirmación de sesión secundaria. No se puede fabricar en el simulador sin falsear las dos mitades a la vez.",
      expected: "La pantalla «Este dispositivo tiene datos de otra cuenta» con el icono `lock.shield` y el cuerpo «Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.» — sobre un device cuyo corpus es del PROPIO usuario que la está viendo."
    },
    "reentry-errores": {
      reason: "MEDIDO que el simulador no puede: el único seam que finge sesión (`UITestHooks.fakeCloudSession`) pasa por `hasArg`, que exige `-uitest` (UITestHooks.swift:274-280); y bajo `-uitest` las dos cards de nube desaparecen (`WelcomeAccountChoiceLogic.visibleExistingOptions` pide `!isUITest`) y el faro deja de encaminar porque `cloudEntryAvailable` se deriva de ellas. Los dos seams son mutuamente excluyentes por construcción, así que a `WelcomeCloudSignInView` no se llega con sesión fingida.",
      expected: "La pantalla de error: icono `wifi.exclamationmark`, «Algo no salió bien», «No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.» y el botón «Reintentar». Vale con provocarla en device cortando la red durante `GET /account/exists`."
    },
    "reentry-killmidadopt": {
      reason: "Exige un adopt en vuelo, y un adopt en vuelo exige sesión real + `POST /account/claim` contra el backend. El estado post-kill (app abierta con tabs y sin datos) es indistinguible a ojo de cualquier app vacía, así que una captura fabricada en el simulador mentiría sobre lo que el panel afirma.",
      expected: "Dos cosas juntas: la app en su tab normal tras relanzar a mitad del adopt (NO el Welcome), y la card de Ajustes → «Dónde viven tus datos» mostrando el estado REAL de la máquina (progreso o relanzamiento pendiente), no `idle`."
    },
    "reentry-vacio": {
      reason: "El punto del panel es lo que NO se ve mientras el pull baja la cuenta. En el simulador se puede fabricar una app vacía, pero no una app vacía CON datos bajando: eso exige un adopt real completado y un corpus en el backend. Una captura de sim sería visualmente igual y factualmente falsa.",
      expected: "La pantalla principal recién relanzada, con los empty states y —si no hay Pro— la hoja «Prueba Yala Pro gratis» encima, mientras el primer pull está en curso. Lo que hay que poder señalar es el hueco donde debería estar «Descargando tus datos…» y no está."
    },
    "reentry-puertaequivocada": {
      pending: true,
      reason: "Es la única de las ocho que el simulador podría dar, pero no sin preparar el entorno: `WelcomeRestoreView.startSearch` (:113-117) sale por `.iCloudDisabled` («Activa iCloud para continuar») si el sim no tiene cuenta de iCloud, y por `.wiped` si los timestamps del iKV dicen que el último acto fue un borrado. Para la rama born-cloud hace falta un sim con sesión de iCloud y base privada de CloudKit VACÍA. No lo intenté en esta pasada.",
      expected: "«No encontramos tus datos · No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?» con el botón «Empezar desde cero», tras haber elegido «Restaurar desde iCloud» y pagado el relanzamiento. Idealmente, al lado, la card de Ajustes con el copy de adopción («Activar la nube en este dispositivo») para la rama del que migró."
    },
    // ── F6 · capturables en simulador, pendientes de la pasada de captura ──
    "r3-enlace-origen": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un enlace `https://yala-app.pe/invite?g=…&t=…&s=…&n=…&i=…&c=…&m=…&u=…` en WhatsApp."
    },
    "r3-recovery": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un icono de enlace verde, «Pega tu enlace de invitación» y debajo «Si te invitaron a un grupo en Yala, pega aquí el enlace que recibiste.»."
    },
    "r3-onboarding-nombre": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un círculo con el color de acento del tema y el icono `person.2.fill`, «Te invitaron a un grupo» y debajo «Yala te ayuda a dividir gastos y saber cuánto debes o te deben»."
    },
    "r3-esperando": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Primero un spinner grande con «Conectando con tu grupo…» y «Estamos preparando todo para que puedas dividir gastos."
    },
    "r3-solicitud": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un reloj naranja, «Solicitud enviada» y «El admin del grupo debe aprobarte antes de que puedas participar."
    },
    "r3-listo": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un check verde, «¡Todo listo!» y un botón «Ir al grupo»."
    },
    "r3-banner": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Una tira flotante sobre la lista de grupos, con CINCO caras según la fase: spinner + «Conectando con tu grupo…» · reloj + «Esperando aprobación del admin» · triángulo + «No pudimos unirte al grupo» con botón «Reintentar» · triá…"
    },
    "r3-err-ckshare": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "El alert «Enlace no válido» / «Este enlace ya no es válido o expiró."
    },
    "r3-err-enlace": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "DOS superficies según dónde te pille."
    },
    "visita-shell": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "La app normal, con tres diferencias."
    },
    "visita-vaciar": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "En Ajustes, la última fila de su sección: «Vaciar datos» · «Borra tus datos."
    },
    "visita-chooser": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "El Welcome de siempre: «¡Hola!"
    },
    "visita-crear-grupo": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Primero «Comprobando que todo esté listo…» con un spinner; después, la pantalla honesta: reloj sobre persona, «Aquí estás como invitado» y «Esta sesión vive en el dispositivo de otra persona, así que tu primer grupo se crea des…"
    },
    "visita-privado": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Si las dos cards son visibles, «Tu cuenta en tu iCloud privado» · «Tus datos viven en los dispositivos Apple de tu Apple ID y se sincronizan por tu iCloud privado."
    },
    "visita-privado-onboarding": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "El onboarding completo de siempre: «¿Cómo quieres que te llamemos?» con el campo «Tu nombre», «¿Qué te gustaría hacer con Yala?», divisa, estilo, cuenta inicial, presupuesto."
    },
    "visita-salida": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "La salida se pide desde Ajustes y la cuenta el nodo del cierre de sesión; lo que este panel retrata es lo que pasa DESPUÉS, en el arranque siguiente, antes de que exista una sola vista."
    },
    "vuelta-salida-ajustes": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Ajustes, DOS secciones y un reparto que importa."
    },
    "vuelta-hoja": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Título «¿Cerrar tu sesión en este dispositivo?» y las tres filas de siempre."
    },
    "vuelta-welcome": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "El Hero de bienvenida: logo, el carrusel de cards, «Tus finanzas personales, sin esfuerzo.» y el botón «Empezar»."
    },
    "signout-fila-privada": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Al final de la sección «Seguridad y cuenta», una fila con icono rojo de salida (`rectangle.portrait.and.arrow.right`)."
    },
    "signout-hoja-privada": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Pantalla completa (`.large`, con drag indicator) titulada «¿Cerrar tu sesión en este dispositivo?» y las tres filas de siempre, cada una con su símbolo de sistema y en tono «no se toca» (ninguna en rojo): iPhone (`iphone`) «En …"
    },
    "signout-welcome-condatos": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "El Hero de siempre: logo, carousel de cards, «Tus finanzas personales, sin esfuerzo.», el botón «Empezar» y, bajo él en pequeño, «100% privado · Tu info siempre contigo»."
    },
    "signout-freshstart-alert": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Alert del sistema sobre el Welcome: título «Empezar desde cero», mensaje «Detectamos datos previos en tu dispositivo."
    },
    "signout-restaurar-errores": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Cuatro pantallas hermanas, decididas ANTES de buscar nada."
    },
    "signout-hoja-legado5a": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "La misma hoja de tres filas con los mismos símbolos de sistema (`iphone` / `icloud` / `person.2`), pero con otro título y otro copy: «¿Salir de Yala en este dispositivo?» · «En este dispositivo» → «Vuelves a la pantalla de inic…"
    },
    "reentry-nuevainstalacion": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Tras reabrir la app, el usuario que acaba de recuperar su cuenta de años se encuentra tratado como recién llegado: en el Panel aparece la card «Primeros pasos» con su contador «%d de %d completados» arrancando de cero y, si no …"
    },
    "reentry-killswitch": {
      pending: true,
      reason: "F6 (2026-08-12): el simulador SÍ puede producir este estado. Esta pasada DERIVÓ el contenido del código y no abrió el simulador — la captura entra en el guion de la próxima pasada.",
      expected: "Un chooser que parece normal y no lo es."
    }
  },

  // ── Notas de captura: contexto de CÓMO se obtuvo la imagen (sin tocar lo medido en F1) ─
  captureNotes: {
    "alta-hero": "F5 · RE-capturada (2026-08-12) sobre `6c6eb3fe`: sin subtítulo. El árbol de accesibilidad lo confirma — solo `welcome.hero.title`, `titleAccent` y `trust`, y un único target (`welcome_hero_cta`) sin ninguna rama de alert.",
    "alta-chooser": "F5 · RE-capturada: los seis valores nuevos de las tres cards, leídos del árbol y coincidentes byte a byte con `es.lproj`.",
    "alta-newchooser": "F5 · RE-capturada: **la nube va primero** y la card privada después, sin renuncia inline y sin distintivo de recomendada. Es la evidencia visual del `displayOrder` de W3.",
    "alta-intro": "F5 · RE-capturada: «Registrarse con Apple» (lo pinta el sistema por `type: .signUp`) + «Crear cuenta con Google» + la nota propia del alta. Los tres verbos de W4b en una sola pantalla.",
    "alta-consent": "F5 · RE-capturada: tres puntos y un pie (versión 2 del contrato), sin el header inline duplicado que tenía la versión 1.",
    "reentry-intro": "F5 · RE-capturada por la rama Google: «Iniciar sesión con Google» — el otro lado del desdoble de verbos.",
    "alta-groupschooser": "F5 · captura NUEVA. Recorrido real sin ningún hook: Hero → «Vengo por un grupo». Las dos cards con su alto igualado.",
    "alta-groupsgate-blocked": "F5 · captura NUEVA, variante CANAL APAGADO, fabricada con el kill-switch DEBUG (`simctl spawn defaults write cloudSync.debug.remoteFlagsForceOff -bool YES`) y un relanzamiento SIN args de uitest —bajo `-uitest` el kill-switch ni se lee—. El árbol confirma el identifier `welcome_groups_gate_channel_off` y los DOS botones «Volver» que el panel anota.",
    "onboarding-groupssignin": "F5 · captura NUEVA, alcanzada por el recorrido real del organizador (la puerta abrió con el canal ON). Es la pantalla donde se ve el hallazgo F5-H7: «Iniciar sesión con Apple» encima de «Crear cuenta con Google».",
    "onboarding-educativo": "F5 · RE-capturada en su PASO 3, que es donde C2 puso el punto nuevo («los gastos se guardan en los servidores de Yala») y donde el CTA dice «Crear mi cuenta» porque este móvil nunca tuvo sesión. Ojo: esta imagen es el educativo montado como COVER por la puerta del organizador; el del tab es el mismo contenido en sheet.",
    "onboarding-groupsonly": "F5 · RE-capturada: el paso 8 en variante solo-grupos («¡Listo para dividir gastos con amigos!», resumen «Dividir gastos con amigos · PEN»). Se verificó además lo que el nodo afirma: su CTA NO aterriza en el tab — cede a la cadena de puertas y monta el educativo.",
    "alta-mirrorrelaunch": "F3 · captura NUEVA (2026-08-11). Recorrido REAL sin ningún hook: `simctl uninstall` + `install` de Yala Dev (Debug-Dev) para que NO exista archivo de store ⇒ mount neutro; Hero → «Soy nuevo» → «Solo tú y tus dispositivos» y esta pantalla monta sola. En la misma corrida se verificó el auto-exit (Inicio ⇒ el proceso desaparece de `launchctl list`), la durabilidad del destino (`welcome.pendingMirrorRelaunchDestination = privateOnboarding` en el plist del contenedor) y el consumo one-shot (al relanzar aterriza en el onboarding y la key ya no está).",
    "alta-creating": "El alert «Inicia sesión en tu cuenta de Apple» es el sim sin cuenta de Apple reaccionando al ASAuthorization — sale a ~0,5 s del tap y no existe ventana limpia (ráfaga de 14 frames a 120 ms lo confirmó). Debajo se ve el estado REAL de la fase `.creating`: spinner + «Creando tu cuenta…».",
    "alta-signin": "Es el flujo web REAL de Google (ASWebAuthenticationSession) corriendo en sim. El sheet nativo de SIWA no aparece en sim sin cuenta de Apple: ese lado queda device-only, como el nodo ya anota.",
    "alta-error-401": "Provocado REAL con `-uitest-fake-cloud-session`: el predicado global de sesión es true pero `accessToken()` es nil ⇒ el claim devuelve `sessionExpired` ⇒ `releaseSessionAndShowError`. Es la fase `.error(retryable: true)` auténtica.",
    "alta-privado": "El alert de wipe («Detectamos datos previos… ¿Borrar todo?») también se verificó en sim con datos residuales; esta captura es el estado FINAL (el onboarding ya montado). F3 (2026-08-11): se CONSERVA porque la pantalla de destino no cambió, y se re-verificó en sim que sobre un mount neutro se llega aquí DESPUÉS del terminal «Un último paso: reabre Yala» —no en su lugar—; sobre un device con archivo de store sigue siendo directo.",
    "alta-postrelaunch": "F3: el nodo ahora cubre las DOS entradas (el CTA de «Tu cuenta está lista» y el post-relanzamiento del device con archivo de store); la pantalla es la misma y la captura vale para ambas. Estado sembrado con las MISMAS keys que escribe `writeCloudArmed` + `hasShownWelcomeChooser` (vía `simctl spawn defaults`). La evidencia A6: el paso Propósito pinta SOLO dos cards — «Dividir gastos con amigos» no está, como dicta `OnboardingGroupsPurposeGateLogic` en `.cloud`.",
    "migracion-progreso": "Migración REAL contra staging desde el panel DEBUG (consent + signInSucceeded journaleados); sin sesión la máquina se aparca en `claimingMigration` ⇒ ESTA es la pantalla de una migración aparcada con «Retomar». La barra al 100 % de fases no se alcanza en sim.",
    "migracion-cloudactive": "Par `.cloud` completo sembrado (mismas keys que el cutover). La card de reversa muestra la variante NO-elegible real (sin sesión).",
    "migracion-relaunch": "Mount-mismatch REAL: par escrito con el proceso vivo montado en `.icloud` ⇒ `CloudMigrationUIStateDeriver` pinta `needsRelaunch(.toCloud)`. Es también el único reflejo visible del estado que `degradado-mount` guarda en silencio.",
    "reversa-card": "Variante NO-elegible («Ahora mismo no puedes volver a iCloud desde este dispositivo») — la real sin sesión. El botón de la variante elegible queda device-only (reversa-confirm).",
    "onboarding-empty": "Empty state de RE-ENTRADA (`signInToView`: canal ON ∧ flag ∧ sin sesión) — el mismo render aparece en el aterrizaje del alta solo-grupos (onboarding-groupsonly).",
    "onboarding-groupsonly": "Aterrizaje real del cierre «Solo grupos»: tab bar reducido (Grupos + Más) y el empty de re-entrada porque el canal backend está ON en Dev.",
    "onboarding-educativo": "Último paso del educativo con el CTA «Iniciar sesión» (A1) visible — canal ON ∧ sin sesión. Para alcanzarlo sin uitest hizo falta destrabar el GATE BETA de Grupos (ver hallazgo F2-H1).",
    "onboarding-muro": "Canal apagado con el kill-switch DEBUG (`cloudSync.debug.remoteFlagsForceOff`) + sim sin cuenta iCloud ⇒ el muro real del selector.",
    "onboarding-crear": "Ruta `needsConsent` de `GroupCreateRoutingLogic`: sesión fingida (`-uitest-fake-cloud-session`) sin consent ⇒ el consent de Grupos en el camino de crear.",
    "signout-borrarcuenta": "`-uitest-fake-backend-session` + seed `grupos` (saldos pendientes) ⇒ hoja real con el aviso de deudas en ámbar y «Ver mis grupos» PRIMERO en las secundarias.",
    "signout-relaunch": "Cover terminal real presentado por el dueño único (`SignOutRelaunchNetModifier`) tras `_debugForceAwaitingRelaunch()` del panel DEBUG — solo fase, sin wipe. F3: sigue siendo la captura correcta de este nodo, que desde R4 describe el camino DEGRADADO; forzar la fase es justamente lo que el swap abortado deja en pantalla.",
    "degradado-killswitch": "Kill-switch simulado del panel DEBUG: la fila «Dónde viven tus datos» desaparece del Perfil (usuario no-engaged). En el mismo estado el tab Grupos cae al canal CloudKit («Crear grupo» directo)."
  },

  // ── Hallazgos de F2: lo que el recorrido contradijo o añadió al Atlas ─────────────────
  findings: [
    {
      id: "F2-H1",
      sev: "CERRADO el 2026-08-12 (F5)",
      title: "El flujo 6 tenía una capa previa que el Atlas no dibujaba: el GATE BETA de Grupos",
      node: "onboarding-adopcion",
      body: "En el recorrido full sin uitest, tocar la card «Grupos» de Más NO llevaba al educativo ni al empty: salía el diálogo «Función en beta» (código 1050), un gate temporal de la 2.0.1. **CERRADO por `9e504480`**, comprobado y no asumido: cero ocurrencias de la vista del gate, del campo del código y del gate del FAB, y las 6 keys retiradas de los 16 idiomas. Lo único que sobrevive es el STRING de la key `groupsBetaUnlocked`, que hoy significa otra cosa —que este dispositivo adoptó el dominio Grupos— y que el Atlas dibuja como tal. Ver el nodo de adopción y el hallazgo F5-H2."
    },
    {
      id: "F2-H2",
      sev: "verificación",
      title: "El cover terminal del sign-out presenta bien con las sheets cerradas (dueño único)",
      node: "signout-relaunch",
      body: "Forzar la fase `awaitingRelaunch` con el panel DEBUG abierto NO presentó el cover (dos anchors); al cerrar las sheets del Perfil, el cover del root presentó a la primera. Confirma en sim el diseño del dueño único del 2026-07-14 que el nodo describe."
    },
    {
      id: "F2-H3",
      sev: "verificación",
      title: "El relanzamiento con el par a medio camino se comporta como el Atlas predice",
      node: "migracion-relaunch",
      body: "Escribiendo el par con el proceso vivo (mount .icloud) la card bloqueante apareció al entrar a Almacenamiento; tras relanzar con el par completo, Almacenamiento pintó `cloudActive`. Las dos transiciones coinciden con `CloudMigrationUIStateDeriver`."
    }
  ]
};
