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

window.ATLAS_F2 = {
  head: "f4d10fa6",
  date: "2026-08-10",

  // ── Nodos SIN captura de sim: motivo + qué debería verse ─────────────────────────────
  deviceOnly: {
    "alta-error-403": {
      reason: "Requiere un 403 real del backend (cuenta suspendida server-side); el sim no puede fabricarlo.",
      expected: "El mismo layout de error del alta que alta-error-401, pero SIN botón Reintentar (CloudWelcomeSignInFlow.swift:136-137)."
    },
    "alta-error-transient": {
      reason: "La fase de pantalla es la MISMA que la del 401 — `.error(retryable: true)` — y su render está capturado en alta-error-401. Provocar la causa real (red caída / 5xx) no es posible en sim con staging accesible.",
      expected: "Idéntico a img/alta-error-401.png: «Algo no salió bien» + Reintentar. La vista no distingue la causa; solo el flag retryable cambia el render."
    },
    "alta-par-relaunch": {
      reason: "La pantalla terminal exige un claim `created` real y en sim SIWA/Google no completan sesión (el sim no tiene cuenta de Apple; Google exige credenciales reales).",
      expected: "Pantalla terminal con icono de recarga: «Cierra Yala y vuelve a abrirla», sin botones ni back (WelcomeCloudSignInView.swift:414). El equivalente visual del sign-out sí está capturado en img/signout-relaunch.png."
    },
    "alta-waitingleader": {
      reason: "Requiere que el backend devuelva `claiming_in_progress` (otro device liderando un claim) — no fabricable desde el sim.",
      expected: "«Otro dispositivo está migrando» + Reintentar + «Continuar a la app» (WelcomeCloudSignInView.swift:388)."
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
    }
  },

  // ── Notas de captura: contexto de CÓMO se obtuvo la imagen (sin tocar lo medido en F1) ─
  captureNotes: {
    "alta-creating": "El alert «Inicia sesión en tu cuenta de Apple» es el sim sin cuenta de Apple reaccionando al ASAuthorization — sale a ~0,5 s del tap y no existe ventana limpia (ráfaga de 14 frames a 120 ms lo confirmó). Debajo se ve el estado REAL de la fase `.creating`: spinner + «Creando tu cuenta…».",
    "alta-signin": "Es el flujo web REAL de Google (ASWebAuthenticationSession) corriendo en sim. El sheet nativo de SIWA no aparece en sim sin cuenta de Apple: ese lado queda device-only, como el nodo ya anota.",
    "alta-error-401": "Provocado REAL con `-uitest-fake-cloud-session`: el predicado global de sesión es true pero `accessToken()` es nil ⇒ el claim devuelve `sessionExpired` ⇒ `releaseSessionAndShowError`. Es la fase `.error(retryable: true)` auténtica.",
    "alta-privado": "El alert de wipe («Detectamos datos previos… ¿Borrar todo?») también se verificó en sim con datos residuales; esta captura es el camino limpio directo al onboarding.",
    "alta-postrelaunch": "Estado sembrado con las MISMAS keys que escribe `writeCloudArmed` + `hasShownWelcomeChooser` (vía `simctl spawn defaults`). La evidencia A6: el paso Propósito pinta SOLO dos cards — «Dividir gastos con amigos» no está, como dicta `OnboardingGroupsPurposeGateLogic` en `.cloud`.",
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
    "signout-relaunch": "Cover terminal real presentado por el dueño único (`SignOutRelaunchNetModifier`) tras `_debugForceAwaitingRelaunch()` del panel DEBUG — solo fase, sin wipe.",
    "degradado-killswitch": "Kill-switch simulado del panel DEBUG: la fila «Dónde viven tus datos» desaparece del Perfil (usuario no-engaged). En el mismo estado el tab Grupos cae al canal CloudKit («Crear grupo» directo)."
  },

  // ── Hallazgos de F2: lo que el recorrido contradijo o añadió al Atlas ─────────────────
  findings: [
    {
      id: "F2-H1",
      sev: "hueco del Atlas",
      title: "El flujo 6 tiene una capa previa que el Atlas no dibuja: el GATE BETA de Grupos",
      node: "onboarding-educativo",
      body: "En el recorrido full sin uitest, tocar la card «Grupos» de Más NO lleva al educativo ni al empty: sale el diálogo «Función en beta» (código 1050, `GroupsBetaGateLogic.shouldShowGate`, gate temporal de la 2.0.1). El educativo solo montó tras destrabar `groupsBetaUnlocked`. El alta solo-grupos lo destraba solo (`completeGroupsOnlyOnboarding` escribe la key), por eso el flujo 6 dibujado ES fiel para esa cohorte — pero un usuario full que llega al tab por Más pasa primero por un gate que ningún diagrama menciona."
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
