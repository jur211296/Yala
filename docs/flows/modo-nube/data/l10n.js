// l10n.js — las keys de l10n del copy VISIBLE de cada pantalla del Atlas (chip F4).
//
// Este es el único contenido NUEVO del rediseño F4, y se derivó MIDIENDO (2026-08-11, HEAD 24b4bc91):
// para cada nodo con pantalla se leyó la vista en su coordenada, se siguió cada texto hasta su accessor
// en `Yala/Utils/L10n.swift` (o su `ls(...)`/`NSLocalizedString` directo) y el valor se copió EXACTO de
// `Yala/Resources/es.lproj/Localizable.strings`. Nada está inferido del panel ni del diseño.
//
// El pin vive en check.mjs: toda key citada aquí tiene que EXISTIR en es.lproj (Localizable.strings o
// .stringsdict) — una key inventada o con typo es exit 1. `missing` (key usada por la vista pero ausente
// del .strings) y `hardcoded` (texto visible sin localizar) serían hallazgos: hoy ambos están vacíos en
// todos los nodos; los dos `hardcoded` de migracion-idle viven bajo `#if DEV_BUILD` y no llegan a
// producción, y los nombres de marca de reentry-mismatch son interpolación deliberada (Apple/Google no
// se localizan).
//
// Acotado a propósito: máx. ~12-14 entradas por nodo, priorizando título > cuerpo > botones > alerts.
// El carousel del Hero (16 keys `welcome.hero.cards.*`) queda anotado en `notes`, no listado.
//
// roles: title · body · button · alert-title · alert-body · caption · row · note

window.ATLAS_L10N = {
  // ══ FLUJO 1 · alta ══════════════════════════════════════════════════════
  "alta-hero": {
    copy: [
      { key: "welcome.hero.title", value: "Tus finanzas personales,", role: "title" },
      { key: "welcome.hero.titleAccent", value: "sin esfuerzo.", role: "title" },
      { key: "welcome.hero.cta", value: "Empezar", role: "button" },
      { key: "welcome.hero.trust", value: "100% privado · Tu info siempre contigo", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5: **cinco keys menos**. `welcome.hero.subtitle` la retiró `c8575d8b` y las cuatro `welcome.detectedData.*` se fueron con el alert en `e999bfef` — borradas de los 16 locales, no solo del código.",
      "El Hero rota además un carousel de 8 cards: 16 keys `welcome.hero.cards.{capture,assistant,groups,budgets,multiAndCurrencies,import,icloud,more}.{title,body}` (WelcomeHeroView.swift:70-83), omitidas por el tope de entradas."
    ]
  },
  "alta-chooser": {
    copy: [
      { key: "welcome.chooser.title", value: "¡Hola! ¿Qué quieres hacer en Yala?", role: "title" },
      { key: "welcome.chooser.subtitle", value: "Elige tu punto de partida y seguimos desde ahí.", role: "body" },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala", role: "row" },
      { key: "welcome.chooser.optionNew.body", value: "Empieza desde cero conmigo. Te ayudo a configurar todo paso a paso.", role: "row" },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta", role: "row" },
      { key: "welcome.chooser.optionExisting.body", value: "Ya usé Yala antes y quiero recuperar mis datos, estén en iCloud o en mi cuenta.", role: "row" },
      { key: "welcome.chooser.optionInvite.title", value: "Vengo por un grupo", role: "row" },
      { key: "welcome.chooser.optionInvite.body", value: "Quiero dividir gastos con amigos: crear un grupo o unirme a uno.", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5: **seis de los ocho valores cambiaron** (G1) conservando su key. El cuerpo de `optionExisting` deja de decir «desde iCloud» —que era falso para quien tiene cuenta en la nube— y el de `optionInvite` deja de presuponer el enlace.",
      "Las 3 cards salen de `Branch.title`/`.body` (WelcomeChooserView.swift:30-44)."
    ]
  },
  "alta-newchooser": {
    copy: [
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala", role: "title" },
      { key: "welcome.new.subtitle", value: "Elige dónde quieres guardar tus datos.", role: "body" },
      { key: "welcome.new.cloudTitle", value: "Tu cuenta en la nube", role: "row" },
      { key: "welcome.new.cloudBody", value: "Tus datos viven en nuestros servidores, como en la mayoría de tus aplicaciones. Nuestro equipo puede verlos para darte soporte y funciones nuevas.", role: "row" },
      { key: "welcome.new.privateTitle", value: "Tu cuenta en tu iCloud privado", role: "row" },
      { key: "welcome.new.privateBody", value: "Tus datos viven en los dispositivos Apple de tu Apple ID y se sincronizan por tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros.", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · **el orden de esta lista ES el de la pantalla, y se invirtió** (W3): la nube va primero. Las dos cards se re-titularon en paralelo («tu cuenta en X»), de modo que el eje que se compara es DÓNDE viven los datos y no cuál es la buena.",
      "F5 · `welcome.new.cloudWarning` («renuncias a la privacidad total de la otra opción») está BORRADA de los 16 locales: sermoneaba. La idea no se pierde — el `cloudBody` dice quién puede ver los datos y el consent posterior la lleva entera.",
      "El título reusa la key del chooser (WelcomeNewChooserView.swift:69), así que cambió con él.",
      "La key del badge `recommendedBadge` sigue retirada (chip RC): ninguna de las dos opciones se recomienda, ni en pantalla ni para VoiceOver."
    ]
  },
  "alta-privado": {
    copy: [
      { key: "onboarding.welcomeTitle", value: "Empecemos a organizar tu dinero", role: "title" },
      { key: "onboarding.welcomeSubtitle", value: "Solo unos pasos para personalizar Yala a tu medida.", role: "body" },
      { key: "onboarding.nameLabel", value: "¿Cómo quieres que te llamemos?", role: "caption" },
      { key: "onboarding.namePlaceholder", value: "Tu nombre", role: "caption" },
      { key: "onboarding.nameHint", value: "Puede ser tu nombre, apodo o como prefieras", role: "caption" },
      { key: "action.next", value: "Siguiente", role: "button" },
      { key: "welcome.freshStart.alertTitle", value: "Empezar desde cero", role: "alert-title" },
      { key: "welcome.freshStart.alertMessage", value: "Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?", role: "alert-body" },
      { key: "welcome.freshStart.alertConfirm", value: "Borrar todo y continuar", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "Primer paso del onboarding: `nameStep` (OnboardingView.swift:382); el CTA global «Siguiente» es `action.next`.",
      "El alert de wipe vive en ContentView.swift:253-287."
    ]
  },
  "alta-mirrorrelaunch": {
    copy: [
      { key: "welcome.mirrorRelaunch.title", value: "Un último paso: reabre Yala", role: "title" },
      { key: "welcome.mirrorRelaunch.body", value: "Para cuidar tus datos, Yala tiene que abrirse de nuevo. Ve a la pantalla de inicio y vuelve a entrar: seguimos justo donde lo dejaste.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Sin botones — icono + título + cuerpo (WelcomeMirrorRelaunchView.swift:41-58). Copy propio, NO reusa `storage.relaunch.*`."]
  },
  "alta-groupschooser": {
    copy: [
      { key: "welcome.groups.title", value: "¿Cómo empiezas con tu grupo?", role: "title" },
      { key: "welcome.groups.subtitle", value: "Las dos vías te dejan en el mismo sitio.", role: "body" },
      { key: "welcome.groups.createTitle", value: "Crear mi primer grupo", role: "row" },
      { key: "welcome.groups.createBody", value: "Invitas tú. Registras lo que pagan todos y Yala lleva las cuentas.", role: "row" },
      { key: "welcome.groups.joinTitle", value: "Tengo una invitación", role: "row" },
      { key: "welcome.groups.joinBody", value: "Pega el enlace que te enviaron y entras al grupo.", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Pantalla NUEVA de G2 (`35077287`). El subtítulo es una promesa comprobable: las dos vías desembocan en el mismo shell de Grupos, aunque una pase por la puerta y la otra por el portal."]
  },
  "alta-groupsgate": {
    copy: [
      { key: "welcome.groups.checking", value: "Comprobando que todo esté listo…", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Un solo texto, sin CTA: la pantalla dura lo que dure el refresh forzado del remote-config."]
  },
  "alta-groupsgate-blocked": {
    copy: [
      { key: "welcome.groups.channelOffTitle", value: "Ahora mismo no podemos abrirte grupos", role: "title" },
      { key: "welcome.groups.channelOffBody", value: "Es algo de nuestro lado y dura poco. Vuelve a intentarlo en un momento: no se ha guardado nada.", role: "body" },
      { key: "welcome.groups.secondaryTitle", value: "Aquí estás como invitado", role: "title" },
      { key: "welcome.groups.secondaryBody", value: "Esta sesión vive en el dispositivo de otra persona, así que tu primer grupo se crea desde el tuyo. Cierra tu sesión de invitado y vuelve a intentarlo allí.", role: "body" },
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta", role: "title" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.", role: "body" },
      { key: "welcome.groups.gateBack", value: "Volver", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "Tres motivos, tres copys, un solo layout. El par `channelOff*` es SSOT de ese hecho: el mismo par sirve el alert de `GroupsContainerView` cuando el canal se apaga al crear desde el tab.",
      "El par `secondary*` es lo único que M3 (`ec551b71`) estrenó en los 16 locales, y el de datos ajenos es PRESTADO del guard de sign-in de nube — con las dos imprecisiones que el panel anota."
    ]
  },
  "alta-organizername": {
    copy: [
      { key: "welcome.groups.nameTitle", value: "¿Cómo te llamas?", role: "title" },
      { key: "welcome.groups.nameBody", value: "Es el nombre que verán los demás en el grupo.", role: "body" },
      { key: "groups.invite.namePlaceholder", value: "Tu nombre", role: "caption" },
      { key: "welcome.groups.nameCta", value: "Crear mi grupo", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El placeholder se reusa de la vía del invitado; el CTA es propio y nombra el resultado («crear mi grupo»), no el paso."]
  },

  "alta-consent": {
    copy: [
      { key: "storage.consent.title", value: "Tus datos en la nube de Yala", role: "title" },
      { key: "storage.consent.pointServers", value: "Tus datos se guardan en los servidores de Yala y nuestro equipo puede verlos para darte soporte y funciones inteligentes. No usamos cifrado de extremo a extremo.", role: "body" },
      { key: "storage.consent.pointPhotos", value: "Las fotos de tus recibos se quedan solo en este dispositivo: no se respaldan en la nube ni se ven en otros dispositivos. Si quieres conservarlas, guárdalas antes de cambiar de teléfono.", role: "body" },
      { key: "storage.consent.pointAccess", value: "A cambio, accedes desde cualquier dispositivo con solo tu login de Apple o Google, sin depender de iCloud. Mientras conserves ese login: no hay recuperación por email ni contraseña de Yala, así que si pierdes el acceso a esa cuenta, exporta tus datos antes (Ajustes → Exportar datos).", role: "body" },
      { key: "storage.consent.footer", value: "Puedes volver al modo privado cuando quieras, sin perder nada.", role: "caption" },
      { key: "storage.consent.privacyLink", value: "Ver la política de privacidad", role: "button" },
      { key: "storage.consent.accept", value: "Entiendo y quiero activar la nube", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · **de siete puntos a tres y un pie** (W4, `e8b59372`): las keys `point1..point7` están borradas de los 16 locales y las sustituyen `pointServers` · `pointPhotos` · `pointAccess` + `footer`. Salieron del contrato el envío a la IA (que ya lo dice el consent de IA) y la ubicación de los servidores (que la dice la política de privacidad), y el punto 7 pasó de viñeta a pie.",
      "El título ya NO se pinta dos veces: solo `navigationTitle` (CloudConsentView.swift:84). El header inline desapareció con el recorte.",
      "Confirmado: el copy sigue siendo genérico e idéntico para los tres `ConsentPath` — la ruta solo cambia la telemetría y, desde M0, DÓNDE se registra."
    ]
  },
  "alta-intro": {
    copy: [
      { key: "welcome.bornCloud.title", value: "Crea tu cuenta de Yala", role: "title" },
      { key: "welcome.bornCloud.subtitle", value: "Con ella podrás abrir Yala desde cualquier dispositivo.", role: "body" },
      { key: "auth.googleButtonSignUp", value: "Crear cuenta con Google", role: "button" },
      { key: "welcome.bornCloud.providerNote", value: "Tu cuenta de Yala quedará ligada al método que elijas.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · **el verbo lo decide el contexto** (W4b): aquí la cuenta NO existe todavía ⇒ Google dice «Crear cuenta con Google» (`purpose: .signUp`) y el botón de Apple es `AppleSignInButton(type: .signUp)`, cuyo rótulo lo pinta el sistema en el idioma del OS. Antes los dos decían «continuar»/«iniciar sesión».",
      "F5 · la nota §13 también se desdobló: el alta usa `welcome.bornCloud.providerNote` («quedará ligada al método que elijas») y la re-entrada conserva `welcome.cloud.providerNote` («entra con el mismo método que usaste»). Una sola nota no podía decir las dos cosas."
    ]
  },
  "alta-signin": {
    copy: [],
    missing: [],
    hardcoded: [],
    notes: ["El sheet SIWA / flujo web de Google es copy del OS/Google, no de Yala. Detrás queda visible el intro del alta (keys en su frame)."]
  },
  "alta-creating": {
    copy: [
      { key: "welcome.bornCloud.creating", value: "Creando tu cuenta…", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Spinner + un solo texto, sin hint (WelcomeCloudSignInView.swift:184-185)."]
  },
  "alta-par-relaunch": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala", role: "title" },
      { key: "storage.relaunch.body", value: "Cierra Yala del todo (deslízala fuera del selector de apps) y vuelve a abrirla para terminar.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["`relaunchContent` usa `storage.relaunch.body` (cierre MANUAL), no `bodyAutoExit` — coherente con que este terminal no auto-exita."]
  },
  "alta-bornready": {
    copy: [
      { key: "welcome.bornCloud.readyTitle", value: "¡Tu cuenta está lista!", role: "title" },
      { key: "welcome.bornCloud.readyBody", value: "Ya puedes empezar. Todo lo que registres se guardará en tu cuenta.", role: "body" },
      { key: "welcome.bornCloud.readyCta", value: "Empezar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El CTA «Empezar» comparte VALOR con `welcome.hero.cta` pero es key propia."]
  },
  "alta-postrelaunch": {
    copy: [
      { key: "onboarding.welcomeTitle", value: "Empecemos a organizar tu dinero", role: "title" },
      { key: "onboarding.welcomeSubtitle", value: "Solo unos pasos para personalizar Yala a tu medida.", role: "body" },
      { key: "onboarding.nameLabel", value: "¿Cómo quieres que te llamemos?", role: "caption" },
      { key: "onboarding.namePlaceholder", value: "Tu nombre", role: "caption" },
      { key: "onboarding.nameHint", value: "Puede ser tu nombre, apodo o como prefieras", role: "caption" },
      { key: "action.next", value: "Siguiente", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Mismo primer paso (`nameStep`) que el frame del onboarding privado, sin alert de wipe: es el `OnboardingView` normal ya en modo nube."]
  },
  "alta-waitingleader": {
    copy: [
      { key: "welcome.cloud.waitingTitle", value: "Tu cuenta se está preparando en otro dispositivo", role: "title" },
      { key: "welcome.cloud.waitingBody", value: "Puedes esperar aquí o continuar a la app; seguiremos intentándolo.", role: "body" },
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" },
      { key: "welcome.cloud.continueToApp", value: "Continuar a la app", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El `sees` del panel parafrasea el título como «Otro dispositivo está migrando»; el valor real es «Tu cuenta se está preparando en otro dispositivo»."]
  },
  "alta-error-401": {
    copy: [
      { key: "welcome.cloud.errorTitle", value: "Algo no salió bien", role: "title" },
      { key: "welcome.cloud.errorBody", value: "No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.", role: "body" },
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Los tres errores (401/403/transitorio) comparten la MISMA pantalla `.error`; solo varía `retryable`."]
  },
  "alta-error-403": {
    copy: [
      { key: "welcome.cloud.errorTitle", value: "Algo no salió bien", role: "title" },
      { key: "welcome.cloud.errorBody", value: "No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["`retryable: false` ⇒ sin botón Reintentar; título y cuerpo son los MISMOS genéricos del 401 — no hay copy propio de «cuenta suspendida», y el cuerpo pide «revisa tu conexión» para un fallo que no es de conexión."]
  },
  "alta-error-transient": {
    copy: [
      { key: "welcome.cloud.errorTitle", value: "Algo no salió bien", role: "title" },
      { key: "welcome.cloud.errorBody", value: "No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.", role: "body" },
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Idéntico en pantalla al 401; aquí el cuerpo genérico («revisa tu conexión») es literal."]
  },

  // ══ FLUJO 2 · reentry ═══════════════════════════════════════════════════
  "reentry-chooser": {
    copy: [
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta", role: "title" },
      { key: "welcome.existing.subtitle", value: "Elige cómo quieres recuperar tus datos.", role: "body" },
      { key: "welcome.existing.restoreTitle", value: "Restaurar desde iCloud", role: "row" },
      { key: "welcome.existing.restoreBody", value: "Tus datos guardados con tu iCloud vuelven a este dispositivo.", role: "row" },
      { key: "welcome.existing.cloudTitle", value: "Entrar con Apple", role: "row" },
      { key: "welcome.existing.cloudBody", value: "Tu cuenta Yala en la nube, desde cualquier dispositivo.", role: "row" },
      { key: "welcome.existing.googleTitle", value: "Entrar con Google", role: "row" },
      { key: "welcome.existing.googleBody", value: "Tu cuenta Yala en la nube, si la creaste con tu cuenta de Google.", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["WelcomeExistingChooserView.swift (título :36, cards :63-77). Con una sola opción visible la pantalla ni se monta (bypass)."]
  },
  "reentry-intro": {
    copy: [
      { key: "welcome.cloud.title", value: "Entra a tu cuenta", role: "title" },
      { key: "welcome.cloud.subtitle", value: "Usa el mismo Apple ID con el que creaste tu cuenta de la nube.", role: "body" },
      { key: "welcome.cloud.subtitleGoogle", value: "Usa la misma cuenta de Google con la que creaste tu cuenta de la nube.", role: "body" },
      { key: "auth.googleButtonSignIn", value: "Iniciar sesión con Google", role: "button" },
      { key: "welcome.cloud.providerNote", value: "Entra con el mismo método que usaste al crear tu cuenta: tu cuenta de Yala queda ligada a él.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · aquí la cuenta YA existe ⇒ el verbo es iniciar sesión en los DOS botones: Google con `purpose: .signIn` y Apple con `AppleSignInButton(type: .signIn)` (WelcomeCloudSignInView.swift:361-377).",
      "El subtítulo conmuta por provider (WelcomeCloudSignInView.swift:352-354)."
    ]
  },
  "reentry-mismatch": {
    copy: [
      { key: "welcome.cloud.providerMismatchTitle", value: "Esa cuenta usa otro método", role: "title" },
      { key: "welcome.cloud.providerMismatchBody", value: "Tu cuenta de Yala se creó con %@. Vuelve atrás y entra con ese método.", role: "body" },
      { key: "welcome.cloud.providerMismatchBodyGeneric", value: "Tu cuenta de Yala se creó con otro método de acceso. Vuelve atrás y entra con el que usaste la primera vez.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El %@ interpola «Apple»/«Google» desde `ProviderMismatchLogic.displayName` — nombres de marca sin localizar A PROPÓSITO; provider desconocido → nil ⇒ body genérico."]
  },
  "reentry-notfound": {
    copy: [
      { key: "welcome.cloud.notFoundTitle", value: "No encontramos una cuenta", role: "title" },
      { key: "welcome.cloud.notFoundBody", value: "Este Apple ID aún no tiene una cuenta Yala en la nube.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El body dice «Apple ID» aunque la fase también es alcanzable con Google — copy único, sin variante por provider."]
  },
  "reentry-blocked": {
    copy: [
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta", role: "title" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Fase `.blockedForeignData`, icono lock.shield."]
  },
  "reentry-secondary": {
    copy: [
      { key: "welcome.cloud.secondaryConfirmTitle", value: "Entrar con tu cuenta", role: "title" },
      { key: "welcome.cloud.secondaryConfirmBody", value: "Este dispositivo tiene datos de otra persona. Entrarás con tu propia cuenta en un espacio separado: verás solo tus datos y los del dueño no se tocan. Al cerrar tu sesión, tus datos se quitarán del dispositivo.", role: "body" },
      { key: "welcome.cloud.secondaryConfirmCta", value: "Entrar con mi cuenta", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Tras confirmar, la fase `.relaunchSecondary` usa `storage.relaunch.title` + `storage.relaunch.bodyAutoExit`. Fase DARK en producción (flag M1)."]
  },
  "reentry-slotocupado": {
    copy: [
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta", role: "title" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Sin copy propio: reusa LITERAL el de datos ajenos. El hecho es el mismo para quien lo lee («aquí hay datos que no son tuyos»), aunque el dueño de esos datos sea otra invitada y no el del móvil."]
  },
  "reentry-adopt": {
    copy: [
      { key: "welcome.cloud.adopting", value: "Conectando con tu cuenta…", role: "title" },
      { key: "welcome.cloud.adoptingHint", value: "Esto puede tardar unos minutos. Mantén Yala abierta.", role: "caption" },
      { key: "storage.progress.waitingImport", value: "Esperando a que iCloud termine de sincronizar…", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El hint de import solo aparece con `resumeWaitingForImport` (misma key que la card de Almacenamiento). La fase previa `.checking` usa `welcome.cloud.checking` = «Verificando tu cuenta…»."]
  },
  "reentry-autoresume": {
    copy: [
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Sin copy propio hasta agotar 3 auto-resumes: entonces aparece el botón dentro de la pantalla del adopt. El resto es breadcrumbs, invisible."]
  },
  "reentry-relaunch": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala", role: "title" },
      { key: "storage.relaunch.body", value: "Cierra Yala del todo (deslízala fuera del selector de apps) y vuelve a abrirla para terminar.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Usa `body` (NO `bodyAutoExit`): el relaunch del adopt no auto-exita en background — el copy pide el cierre manual explícito."]
  },

  // ══ FLUJO 3 · migración ═════════════════════════════════════════════════
  "migracion-fila": {
    copy: [
      { key: "storage.title", value: "Dónde viven tus datos", role: "row" },
      { key: "settings.dataLocationSubtitleICloud", value: "iCloud privado", role: "caption" },
      { key: "settings.dataLocationSubtitleCloud", value: "Tu cuenta en la nube", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El subtítulo es dinámico: ProfileView.swift:235-239 elige entre las dos keys según `storageMode`. `storage.title` es también el navigationTitle de la pantalla destino."]
  },
  "migracion-idle": {
    copy: [
      { key: "storage.status.icloudTitle", value: "iCloud privado", role: "title" },
      { key: "storage.status.icloudBody", value: "Tus datos viven en tu dispositivo y se sincronizan por tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros.", role: "body" },
      { key: "storage.migrate.title", value: "Migrar a la nube", role: "title" },
      { key: "storage.migrate.body", value: "Crea una cuenta con Apple o Google y accede a tus datos desde cualquier dispositivo, incluso sin iCloud.", role: "body" },
      { key: "storage.migrate.previewButton", value: "Ver qué migraría", role: "button" },
      { key: "storage.migrate.previewResult", value: "%1$d movimientos · %2$d categorías · %3$d cuentas · %4$d presupuestos", role: "caption" },
      { key: "storage.migrate.button", value: "Activar la nube", role: "button" }
    ],
    missing: [],
    hardcoded: [
      { text: "Modo Nube · Auth", at: "StorageSettingsView.swift:452 · bajo #if DEV_BUILD, no llega a producción" },
      { text: "Panel DEBUG (solo Yala Dev)", at: "StorageSettingsView.swift:455 · bajo #if DEV_BUILD" }
    ],
    notes: ["El `sees` del panel dice «Ver qué se migraría»; el valor real es «Ver qué migraría» (sin «se»)."]
  },
  "migracion-adopt-copy": {
    copy: [
      { key: "storage.adopt.title", value: "Activar la nube en este dispositivo", role: "title" },
      { key: "storage.adopt.body", value: "Esta cuenta ya tiene tus datos en la nube. Vamos a activarla en este dispositivo.", role: "body" },
      { key: "storage.adopt.button", value: "Activar en este dispositivo", role: "button" },
      { key: "storage.adopt.otherAccountNote", value: "Esta copia de la nube pertenece a otra cuenta de Yala, la de %@. Cierra sesión y entra con esa cuenta para continuar.", role: "note" },
      { key: "storage.adopt.otherAccountNoteGeneric", value: "Esta copia de la nube pertenece a otra cuenta de Yala. Cierra sesión y entra con esa cuenta para continuar.", role: "note" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["En adopt NO se pinta el preview del dry-run (gate `if !isAdopt`). Las notas de cuenta ajena aparecen solo con `blockedOtherAccount`."]
  },
  "migracion-confirm": {
    copy: [
      { key: "storage.confirm.migrateTitle", value: "¿Activar la nube?", role: "alert-title" },
      { key: "storage.confirm.migrateBody", value: "Tus datos se moverán a tu cuenta de Yala. Es reversible, pero es un cambio importante.", role: "alert-body" },
      { key: "storage.confirm.migrateContinue", value: "Continuar", role: "button" },
      { key: "storage.confirm.migrate2Title", value: "¿Seguro?", role: "alert-title" },
      { key: "storage.confirm.migrate2Body", value: "Se activará la nube en este dispositivo.", role: "alert-body" },
      { key: "storage.confirm.migrate2Confirm", value: "Sí, activar la nube", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Dos confirmationDialog encadenados (`StorageConfirmations`), botones con `role: .destructive`."]
  },
  "migracion-progreso": {
    copy: [
      { key: "storage.progress.migrating", value: "Activando la nube…", role: "title" },
      { key: "storage.progress.waitingImport", value: "Esperando a que iCloud termine de sincronizar…", role: "caption" },
      { key: "storage.progress.waitingICloudExport", value: "Esperando la confirmación de iCloud…", role: "caption" },
      { key: "storage.progress.resume", value: "Retomar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El `sees` del panel dice «Migrando…»; el valor real es «Activando la nube…». Los captions son excluyentes: import gana sobre export."]
  },
  "migracion-cutover": {
    copy: [
      { key: "storage.progress.migrating", value: "Activando la nube…", role: "title" },
      { key: "storage.progress.waitingICloudExport", value: "Esperando la confirmación de iCloud…", role: "caption" },
      { key: "storage.progress.resume", value: "Retomar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El caption del 89 % (`markerWritten`) es `storage.progress.waitingICloudExport`. El cutover reusa la misma progressCard del frame de progreso."]
  },
  "migracion-relaunch": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala", role: "title" },
      { key: "storage.relaunch.body", value: "Cierra Yala del todo (deslízala fuera del selector de apps) y vuelve a abrirla para terminar.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["`relaunchCard` (StorageSettingsView.swift:363-380). Las variantes `bodyAutoExit*` son del cover terminal de sign-out, NO de esta card."]
  },
  "migracion-fallo": {
    copy: [
      { key: "storage.failed.migrationICloudFull", value: "No pudimos terminar de activar la nube: iCloud se quedó sin espacio. Tus datos están enteros en este dispositivo. Libera espacio en iCloud y vuelve a intentarlo.", role: "body" },
      { key: "storage.failed.migrationICloudOff", value: "No pudimos terminar de activar la nube: este dispositivo no tiene iCloud activo. Tus datos están enteros aquí. Activa iCloud en Ajustes y vuelve a intentarlo.", role: "body" },
      { key: "storage.failed.migrationICloudStalled", value: "No pudimos terminar de activar la nube: iCloud no confirmó el último paso. Tus datos están enteros en este dispositivo; vuelve a intentarlo cuando tengas buena conexión.", role: "body" },
      { key: "storage.failed.migration", value: "No pudimos activar la nube. Tus datos están a salvo en tu dispositivo; puedes reintentar.", role: "body" },
      { key: "storage.progress.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Mapa de `failureMessage`: quotaExceeded → iCloudFull · noAccountWithFootprint/accountUnusable → iCloudOff · healthy/noChannelNoFootprint → iCloudStalled · nil → genérico. La pantalla además tiene el alert `storage.errors.title` = «Algo salió mal» + `common.ok`."]
  },
  "migracion-cloudactive": {
    copy: [
      { key: "storage.status.cloudTitle", value: "Tu cuenta en la nube", role: "title" },
      { key: "storage.status.cloudBody", value: "Tus datos se guardan en tu cuenta de Yala y se sincronizan en todos tus dispositivos.", role: "body" },
      { key: "storage.sync.title", value: "Sincronización", role: "title" },
      { key: "storage.sync.upToDate", value: "Todo sincronizado", role: "caption" },
      { key: "storage.sync.needsSignIn", value: "Inicia sesión para subir %d cambios", role: "caption" },
      { key: "storage.sync.signInButton", value: "Iniciar sesión", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["La tercera card de `.cloudActive` es la de reversa — su copy está en el frame de la card de reversa."]
  },

  // ══ FLUJO 4 · reversa ═══════════════════════════════════════════════════
  "reversa-card": {
    copy: [
      { key: "storage.revert.title", value: "Volver a iCloud", role: "title" },
      { key: "storage.revert.body", value: "Vuelve al modo privado. Tus datos regresan a tu dispositivo y a tu iCloud, sin perder nada.", role: "body" },
      { key: "storage.revert.desenlaceNote", value: "Es la forma de desvincular tu cuenta de este dispositivo: queda en pausa por si vuelves.", role: "note" },
      { key: "storage.revert.button", value: "Volver a iCloud", role: "button" },
      { key: "storage.revert.ineligible", value: "Ahora mismo no puedes volver a iCloud desde este dispositivo.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Título, cuerpo y nota se pintan SIEMPRE; el botón solo con elegibilidad — si no, el texto ineligible."]
  },
  "reversa-confirm": {
    copy: [
      { key: "storage.confirm.revertTitle", value: "¿Volver a iCloud?", role: "alert-title" },
      { key: "storage.confirm.revertBody", value: "Tus datos volverán a tu dispositivo y a tu iCloud. No perderás nada.", role: "alert-body" },
      { key: "storage.confirm.revertContinue", value: "Continuar", role: "button" },
      { key: "storage.confirm.revert2Title", value: "¿Seguro?", role: "alert-title" },
      { key: "storage.confirm.revert2Body", value: "Se desactivará la nube en este dispositivo.", role: "alert-body" },
      { key: "storage.confirm.revert2Confirm", value: "Sí, volver a iCloud", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Mismo patrón de doble confirmación que migración (StorageSettingsView.swift:600-613)."]
  },
  "reversa-fases": {
    copy: [
      { key: "storage.progress.reverting", value: "Volviendo a iCloud…", role: "title" },
      { key: "storage.progress.waitingImport", value: "Esperando a que iCloud termine de sincronizar…", role: "caption" },
      { key: "storage.progress.resume", value: "Retomar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El `sees` del panel dice «Revirtiendo…»; el valor real es «Volviendo a iCloud…». Misma progressCard compartida."]
  },
  "reversa-relaunch": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala", role: "title" },
      { key: "storage.relaunch.body", value: "Cierra Yala del todo (deslízala fuera del selector de apps) y vuelve a abrirla para terminar.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Misma `relaunchCard` que migración — el copy no distingue la dirección."]
  },
  "reversa-cierre": {
    copy: [
      { key: "storage.status.icloudTitle", value: "iCloud privado", role: "title" },
      { key: "storage.status.icloudBody", value: "Tus datos viven en tu dispositivo y se sincronizan por tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros.", role: "body" },
      { key: "storage.migrate.title", value: "Migrar a la nube", role: "title" },
      { key: "storage.migrate.button", value: "Activar la nube", role: "button" },
      { key: "storage.failed.reverse", value: "No pudimos completar la vuelta a iCloud. Tus datos están a salvo; puedes reintentar.", role: "body" },
      { key: "storage.progress.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["`icloudActive` → `.idle` vuelve a pintar las cards de iCloud + migrar. El otro terminal (`reverseFailedRollback`) pinta `storage.failed.reverse` + Reintentar."]
  },

  // ══ FLUJO 5 · sign-out ══════════════════════════════════════════════════
  "signout-hoja": {
    copy: [
      { key: "settings.signOutConfirmTitle", value: "¿Cerrar tu sesión en este dispositivo?", role: "title" },
      { key: "settings.scopeDeviceLabel", value: "En este dispositivo", role: "row" },
      { key: "settings.scopeICloudLabel", value: "En iCloud", role: "row" },
      { key: "settings.scopeCloudAccountLabel", value: "En tu cuenta de Yala", role: "row" },
      { key: "settings.scopeGroupsLabel", value: "En tus grupos", role: "row" },
      { key: "settings.signOutScopeDeviceCloud", value: "Vuelves a la pantalla de inicio como recién instalado", role: "row" },
      { key: "settings.signOutScopeCloudCloud", value: "Tus datos quedan seguros; primero subimos los cambios pendientes", role: "row" },
      { key: "settings.scopeUntouchedShort", value: "No se tocan", role: "row" },
      { key: "settings.signOutScopeDevicePrivate", value: "No se borra nada; vuelves a la pantalla de inicio", role: "row" },
      { key: "settings.signOutScopeCloudPrivate", value: "Tus datos siguen en iCloud", role: "row" },
      { key: "settings.signOutScopeConservationCloud", value: "Puedes volver a entrar cuando quieras y recuperar todo.", role: "note" },
      { key: "settings.signOutScopeConservationPrivate", value: "Puedes volver a entrar cuando quieras; tus datos seguirán aquí.", role: "note" },
      { key: "settings.signOutConfirmAction", value: "Cerrar sesión", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "El texto lo mapea `DestructiveScopeSheet.Config.make` (Yala/App/Views/Shared/DestructiveScopeSheet.swift:217-467) desde el modelo de `DestructiveScopeLogic`; la etiqueta ☁️ conmuta por `storageMode`.",
      "Variantes no listadas por el tope: secundaria M1 (`settings.signOutScope*Secondary`) y solo-grupos (`settings.signOutScopeDeviceGroupsOnly`, `settings.scopePersonalInICloud`, `settings.scopeForgetGroups`, `settings.signOutScopeConservationGroups`)."
    ]
  },
  "signout-pushall": {
    copy: [
      { key: "settings.signOut", value: "Cerrar sesión", role: "row" },
      { key: "settings.signOutSubtitle", value: "Este dispositivo, no tu cuenta", role: "row" },
      { key: "settings.signOutWorking", value: "Guardando tus cambios pendientes…", role: "caption" },
      { key: "settings.signOutBlockedTitle", value: "No pudimos cerrar tu sesión", role: "alert-title" },
      { key: "settings.signOutBlockedMessage", value: "Hay cambios sin subir a la nube y no queremos que pierdas nada. Revisa tu conexión e inténtalo de nuevo.", role: "alert-body" },
      { key: "settings.signOutPendingTitle", value: "Un momento más", role: "alert-title" },
      { key: "settings.signOutPendingMessage", value: "Todavía estamos terminando de guardar unos cambios. Espera unos segundos y vuelve a intentarlo.", role: "alert-body" },
      { key: "common.ok", value: "OK", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Los dos alerts son excluyentes: blocked = permanente (401/403); pending = transitorio tras agotar el retry interno (ProfileView.swift:419-435)."]
  },
  "signout-relaunch": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala", role: "title" },
      { key: "storage.relaunch.bodyAutoExit", value: "Ve a la pantalla de inicio y vuelve a abrir Yala — todo quedará listo.", role: "body" },
      { key: "storage.relaunch.bodyAutoExitGroupsOnly", value: "Cerramos tu sesión de grupos. Ve a la pantalla de inicio y vuelve a abrir Yala; tus datos personales siguen en este dispositivo.", role: "body" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Sin botones a propósito (SignOutRelaunchView). La variante groups-only la decide `isGroupsOnlyWipeArmed()`. La key `storage.relaunch.body` («Cierra Yala del todo…») es de la card de migración, NO de este cover."]
  },
  "signout-exityala": {
    copy: [
      { key: "settings.exitYala", value: "Salir de Yala en este dispositivo", role: "row" },
      { key: "settings.exitYalaSubtitle", value: "Volverás a la pantalla de inicio. Tus grupos siguen en tu iCloud.", role: "row" },
      { key: "settings.exitYalaConfirmTitle", value: "¿Salir de Yala en este dispositivo?", role: "title" },
      { key: "settings.exitYalaScopeDeviceLegacy", value: "Vuelves a la pantalla de inicio; tus datos no se tocan", role: "row" },
      { key: "settings.exitYalaScopeCloudLegacy", value: "Tus grupos siguen en tu iCloud", role: "row" },
      { key: "settings.exitYalaScopeGroupsLegacy", value: "Siguen en tu iCloud", role: "row" },
      { key: "settings.exitYalaScopeDeviceGroups", value: "Vuelves a la pantalla de inicio; tus datos no se borran", role: "row" },
      { key: "settings.scopePersonalInICloud", value: "Tus datos personales siguen en iCloud", role: "row" },
      { key: "settings.scopeForgetGroups", value: "Este dispositivo olvidará tus grupos (siguen en tu cuenta)", role: "row" },
      { key: "settings.exitYalaScopeConservationLegacy", value: "Puedes volver a entrar cuando quieras; tus grupos siguen en tu iCloud.", role: "note" },
      { key: "settings.exitYalaConfirmAction", value: "Salir de Yala", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Dos variantes de la hoja: `.exitYalaLegacy` (solo-grupos 5a) y `.exitYalaGroups` (split D2, donde la fila «Cerrar sesión de grupos» acompaña: `settings.signOutGroups` / `settings.signOutGroupsSubtitle`)."]
  },
  "signout-borrarcuenta": {
    copy: [
      { key: "settings.deleteAccount", value: "Eliminar mi cuenta", role: "row" },
      { key: "settings.deleteAccountConfirmTitle", value: "¿Eliminar tu cuenta de Yala?", role: "title" },
      { key: "settings.deleteAccountScopeDeviceCloud", value: "Se borran tus datos de este dispositivo", role: "row" },
      { key: "settings.deleteAccountScopeCloudCloud", value: "Se borra tu cuenta y todos tus datos, para siempre", role: "row" },
      { key: "settings.deleteAccountScopeGroups", value: "Seguirás apareciendo como «Usuario eliminado»", role: "row" },
      { key: "settings.deleteAccountDebtWarning", value: "Tienes saldos pendientes en tus grupos. Para los demás miembros quedarán como deuda de «Usuario eliminado». Si prefieres, salda primero desde la pestaña Grupos.", role: "body" },
      { key: "settings.deleteAccountCrossReferHint", value: "¿Solo quieres borrar tus datos y conservar tu cuenta? Usa «Vaciar mis datos».", role: "body" },
      { key: "settings.deleteAccountFrozenICloudNote", value: "Tu copia antigua de iCloud (de antes de la nube) no se toca: si vuelves a abrir Yala, la verás como una reinstalación.", role: "body" },
      { key: "settings.deleteAccountLegacyFootprintNote", value: "En grupos antiguos (iCloud) tu nombre puede seguir visible para sus miembros.", role: "body" },
      { key: "settings.deleteAccountViewGroups", value: "Ver mis grupos", role: "button" },
      { key: "settings.deleteAccountContinue", value: "Continuar", role: "button" },
      { key: "settings.deleteAccountFinalTitle", value: "Esto es definitivo", role: "alert-title" },
      { key: "settings.deleteAccountFinalMessage", value: "No hay vuelta atrás: tu cuenta y tus datos se eliminarán por completo.", role: "alert-body" },
      { key: "settings.deleteAccountFinalAction", value: "Eliminar mi cuenta", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Variante 5b solo-grupos: `settings.deleteAccountScopeDeviceGroupsOnly` y `settings.deleteAccountScopeCloudGroupsOnly`. Fila de Ajustes con subtítulo `settings.deleteAccountSubtitle`."]
  },
  "signout-vaciar": {
    copy: [
      { key: "settings.deleteDataConfirmation", value: "¿Vaciar tus datos?", role: "title" },
      { key: "settings.wipeScopeDevice", value: "Se borran tus cuentas, movimientos y presupuestos", role: "row" },
      { key: "settings.wipeScopeCloudAccount", value: "También se borran de tu cuenta; tus otros dispositivos los perderán al sincronizar", role: "row" },
      { key: "settings.wipeScopeCloudICloud", value: "También se borran; tus otros dispositivos los perderán", role: "row" },
      { key: "settings.wipeScopeGroups", value: "No se tocan — siguen igual", role: "row" },
      { key: "settings.wipeScopeGroupsDebt", value: "Tus grupos se conservan, pero tienes saldos pendientes. Puedes saldarlos desde la pestaña Grupos.", role: "row" },
      { key: "settings.wipeScopeMultiDeviceResidual", value: "Un dispositivo sin conexión podría traer de vuelta cambios recientes al sincronizar.", role: "body" },
      { key: "settings.wipeScopeConservation", value: "Tu suscripción Pro no cambia.", role: "note" },
      { key: "settings.wipeExportBeforeButton", value: "Exportar antes", role: "button" },
      { key: "settings.wipeExportBeforeCloudCaption", value: "En modo nube esta puede ser tu única copia", role: "caption" },
      { key: "settings.wipeLeaveGroupsButton", value: "También salir de mis grupos", role: "button" },
      { key: "settings.deleteAllDataAction", value: "Vaciar definitivamente", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["La fila ☁️ conmuta por modo: `.cloud` → `wipeScopeCloudAccount` (+ residual multi-device), resto → `wipeScopeCloudICloud` sin residual. Con deuda, «Ver mis grupos» va primero en las secundarias."]
  },

  // ══ FLUJO 6 · onboarding de propósito ═══════════════════════════════════
  "onboarding-purpose": {
    copy: [
      { key: "onboarding.purpose.title", value: "¿Qué te gustaría hacer con Yala?", role: "title" },
      { key: "onboarding.purpose.control", value: "Llevar el control de mi dinero", role: "row" },
      { key: "onboarding.purpose.controlDesc", value: "Gastos, ingresos y cuánto tienes", role: "row" },
      { key: "onboarding.purpose.expenses", value: "Solo anotar mis gastos", role: "row" },
      { key: "onboarding.purpose.expensesDesc", value: "Registra lo que gastas y listo", role: "row" },
      { key: "onboarding.purpose.groups", value: "Dividir gastos con amigos", role: "row" },
      { key: "onboarding.purpose.groupsDesc", value: "Viajes, cenas y cuentas compartidas", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["OnboardingView.swift:453-540 (purposeStep). La tercera card solo con `shouldShowGroupsCard` (flujo inicial ∧ `.icloud`)."]
  },
  "onboarding-muro": {
    copy: [
      { key: "groups.errors.iCloudRequiredTitle", value: "Activa iCloud para usar grupos", role: "alert-title" },
      { key: "groups.errors.iCloudRequiredBody", value: "Los grupos se sincronizan por iCloud. Actívalo en Ajustes para crear o unirte a un grupo.", role: "alert-body" },
      { key: "common.ok", value: "OK", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El body («se sincronizan por iCloud») es exactamente el que mentiría con el canal backend ON — coherente con que el muro entero se retire en ese caso."]
  },
  "onboarding-groupsonly": {
    copy: [
      { key: "onboarding.currencyName.titleGroups", value: "Elijamos tu moneda", role: "title" },
      { key: "onboarding.currencyName.subtitleGroups", value: "La usaremos para tus gastos compartidos", role: "body" },
      { key: "onboarding.confirm.motivationGroups", value: "¡Listo para dividir gastos con amigos!", role: "title" },
      { key: "onboarding.confirm.title", value: "Así queda tu Yala", role: "body" },
      { key: "profile.defaultName", value: "Usuario", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El cierre en sí no pinta pantalla propia: aterriza en el tab Grupos. El copy listado es el de los pasos previos en variante groupsOnly."]
  },
  "onboarding-educativo": {
    copy: [
      { key: "groups.onboarding.step1.title", value: "Comparte gastos sin perderles el rastro", role: "title" },
      { key: "groups.onboarding.step1.subtitle", value: "Yala te avisa al instante cuando alguien suma un gasto al grupo.", role: "body" },
      { key: "groups.onboarding.step2.title", value: "Tres pasos, cero hojas de cálculo", role: "title" },
      { key: "groups.onboarding.step2.subtitle", value: "Yala divide, registra y liquida por ti.", role: "body" },
      { key: "groups.onboarding.step3.title", value: "Tu privacidad, primero", role: "title" },
      { key: "groups.onboarding.step3.subtitle", value: "Solo compartes lo necesario, nada más.", role: "body" },
      { key: "groups.onboarding.step3.point1", value: "Cada miembro entra con su cuenta de Yala.", role: "row" },
      { key: "groups.onboarding.step3.point2", value: "Tu información personal no se sincroniza con el grupo, solo los gastos compartidos.", role: "row" },
      { key: "groups.onboarding.step3.signInCTA", value: "Iniciar sesión", role: "button" },
      { key: "groups.onboarding.step3.cta", value: "Ir a Grupos", role: "button" },
      { key: "action.continue", value: "Continuar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Con `shouldShowSignInCTA` (último paso ∧ canal ON ∧ sin sesión) el primario es «Iniciar sesión» y «Ir a Grupos» baja a secundario (GroupsOnboardingView.swift:288-319)."]
  },
  "onboarding-empty": {
    copy: [
      { key: "groups.empty.title", value: "Sin grupos", role: "title" },
      { key: "groups.empty.message", value: "Crea un grupo para dividir gastos con otras personas", role: "body" },
      { key: "groups.empty.action", value: "Crear grupo", role: "button" },
      { key: "groups.empty.signedOut.title", value: "Tus grupos están en tu cuenta", role: "title" },
      { key: "groups.empty.signedOut.message", value: "Inicia sesión para ver los grupos que compartes.", role: "body" },
      { key: "groups.empty.signedOut.action", value: "Iniciar sesión", role: "button" },
      { key: "groups.empty.signedOut.reentryBanner", value: "Cerraste tu sesión de grupos. Inicia sesión cuando quieras verlos de nuevo.", role: "note" },
      { key: "groups.empty.needsEducational.title", value: "¿Cómo funcionan los grupos?", role: "title" },
      { key: "groups.empty.needsEducational.action", value: "Ver cómo funciona", role: "button" },
      { key: "groups.empty.createAccount.title", value: "Crea tu cuenta de Yala", role: "title" },
      { key: "groups.empty.createAccount.action", value: "Crear mi cuenta", role: "button" },
      { key: "groups.empty.needsConsent.title", value: "Un último paso", role: "title" },
      { key: "groups.empty.needsConsent.action", value: "Continuar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · C2 añadió TRES estados con copy propio (`needsEducational`, `createAccount`, `needsConsent`); los dos que ya había (`groups.empty.*` estándar y `signedOut`) quedan acotados a cuando son verdad.",
      "El panel parafrasea la variante estándar como «Aún no tienes grupos»; el valor real de `groups.empty.title` es «Sin grupos». El `reentryBanner` (D2) solo se pinta sobre el caso de re-entrada."
    ]
  },
  "onboarding-groupssignin": {
    copy: [
      { key: "groups.signin.title", value: "Conecta tu cuenta", role: "title" },
      { key: "groups.signin.body", value: "Para unirte al grupo necesitas una cuenta de Yala. Entra con Apple o Google y sigue con tu invitación.", role: "body" },
      { key: "auth.googleButtonSignUp", value: "Crear cuenta con Google", role: "button" },
      { key: "groups.signin.accountNote", value: "Esta será tu cuenta de Yala: si algún día llevas tus datos personales a la nube, usarás esta misma.", role: "caption" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "⚠︎ El botón de Apple lo pinta el sistema con `type: .signIn` («Iniciar sesión con Apple») y el de Google con `purpose: .signUp` («Crear cuenta con Google»): **dos verbos contradictorios en la misma pantalla**, medido en sim el 2026-08-12.",
      "⚠︎ El cuerpo es el del INVITADO y no tiene variante: quien llega desde «Crear mi primer grupo» lee que se va a unir a un grupo y que siga con su invitación."
    ]
  },
  "onboarding-consent": {
    copy: [
      { key: "groups.consent.title", value: "Grupos en la nube", role: "title" },
      { key: "groups.consent.point1", value: "Los grupos son compartidos por naturaleza: viven en la nube de Yala para que todos vean los mismos gastos, al día.", role: "row" },
      { key: "groups.consent.point2", value: "Solo se comparte lo mínimo: tu alias y los gastos del grupo. Tu correo no sale de tu dispositivo.", role: "row" },
      { key: "groups.consent.point3", value: "Tus finanzas personales no se mueven: siguen donde tú elegiste, privadas como siempre.", role: "row" },
      { key: "groups.consent.point4", value: "Los datos del grupo viajan y se guardan protegidos, y puedes salir del grupo cuando quieras.", role: "row" },
      { key: "storage.consent.privacyLink", value: "Ver la política de privacidad", role: "button" },
      { key: "groups.consent.accept", value: "Aceptar y continuar", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["La pantalla es LITERAL para las cuatro puertas: `path` es un parámetro de telemetría, no una rama de copy. Comparte el enlace de privacidad con el consent de Nube."]
  },
  "onboarding-canalapagado": {
    copy: [
      { key: "welcome.groups.channelOffTitle", value: "Ahora mismo no podemos abrirte grupos", role: "alert-title" },
      { key: "welcome.groups.channelOffBody", value: "Es algo de nuestro lado y dura poco. Vuelve a intentarlo en un momento: no se ha guardado nada.", role: "alert-body" },
      { key: "common.ok", value: "OK", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El par `channelOff*` es SSOT de este hecho: lo comparten el alert del tab, el error de guardado del formulario y la puerta del Welcome. Un solo texto para un solo hecho."]
  },
  "onboarding-crear": {
    copy: [
      { key: "groups.new", value: "Nuevo grupo", role: "title" },
      { key: "groups.signin.title", value: "Conecta tu cuenta", role: "title" },
      { key: "groups.signin.body", value: "Para unirte al grupo necesitas una cuenta de Yala. Entra con Apple o Google y sigue con tu invitación.", role: "body" },
      { key: "groups.signin.accountNote", value: "Esta será tu cuenta de Yala: si algún día llevas tus datos personales a la nube, usarás esta misma.", role: "caption" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "F5 · las cinco keys del consent de Grupos se han mudado a su frame propio, que es donde se pinta esa pantalla.",
      "⚠︎ El copy de `groups.signin.body` está redactado para el flujo de INVITACIÓN («para unirte al grupo… y sigue con tu invitación») aunque esta misma pantalla se le presenta a quien viene a CREAR un grupo y no tiene ninguna invitación que seguir."
    ]
  },

  // ══ FLUJO 7 · degradados ════════════════════════════════════════════════
  "degradado-killswitch": {
    copy: [
      { key: "storage.title", value: "Dónde viven tus datos", role: "row" },
      { key: "settings.dataLocationSubtitleICloud", value: "iCloud privado", role: "caption" },
      { key: "settings.dataLocationSubtitleCloud", value: "Tu cuenta en la nube", role: "caption" },
      { key: "welcome.new.cloudTitle", value: "Tu cuenta en la nube", role: "row" },
      { key: "welcome.existing.cloudTitle", value: "Entrar con Apple", role: "row" },
      { key: "welcome.existing.googleTitle", value: "Entrar con Google", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Este copy es el que DESAPARECE con el kill-switch, no uno que se muestre: no existe pantalla de aviso — la ausencia ES el estado."]
  },
  "degradado-sesion": {
    copy: [
      { key: "storage.sync.title", value: "Sincronización", role: "title" },
      { key: "storage.sync.needsSignIn", value: "Inicia sesión para subir %d cambios", role: "body" },
      { key: "storage.sync.signInButton", value: "Iniciar sesión", role: "button" },
      { key: "storage.sync.upToDate", value: "Todo sincronizado", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Banner S11 (StorageSettingsView.swift:291-307): con pendientes + sesión irrenovable, needsSignIn(%d) + botón; sin pendientes, upToDate — ninguna alarma."]
  },
  "degradado-sinred": {
    copy: [
      { key: "welcome.cloud.errorTitle", value: "Algo no salió bien", role: "title" },
      { key: "welcome.cloud.errorBody", value: "No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.", role: "body" },
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["Sin red no hay pantalla única: en alta/re-entrada sale la fase `.error`; en el adopt la pantalla se queda y entra el auto-resume; en la migración la barra se aparca sin copy nuevo."]
  },
  "degradado-claiming": {
    copy: [
      { key: "welcome.cloud.waitingTitle", value: "Tu cuenta se está preparando en otro dispositivo", role: "title" },
      { key: "welcome.cloud.waitingBody", value: "Puedes esperar aquí o continuar a la app; seguiremos intentándolo.", role: "body" },
      { key: "welcome.cloud.retry", value: "Reintentar", role: "button" },
      { key: "welcome.cloud.continueToApp", value: "Continuar a la app", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["`waitingLeaderContent` (WelcomeCloudSignInView.swift:401-425)."]
  },
  "degradado-mount": {
    copy: [],
    missing: [],
    hardcoded: [],
    notes: ["VERIFICADO: el guard A3 no pinta ninguna pantalla ni string — el breadcrumb `personalMountMismatch` es su única superficie. Coincide con el «sees: NADA» del panel."]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R3 · Llego con una invitación a un grupo
  // ══════════════════════════════════════════════════════════════════════════

  "r3-enlace-origen": {
    copy: [
      { key: "groups.settings.invite", value: "Invitar por enlace" },
      { key: "groups.settings.generatingInvite", value: "Generando enlace…" },
      { key: "groups.errors.inviteFailed", value: "No se pudo crear el enlace de invitación. Revisa tu conexión e inténtalo de nuevo." }
    ],
    notes: [
      "`groups.errors.inviteFailed` se pinta desde DOS sitios de la misma función: la rama `else` del grupo legacy (`GroupMembersView.swift:470`) y el `catch` (`:480`). El texto es idéntico y la causa no."
    ]
  },

  "r3-landing": {
    copy: [

    ],
    notes: [
      "Esta pantalla es WEB y su copy NO vive en `Yala/Resources/es.lproj/Localizable.strings`: está en `Web/src/i18n/translations.ts`. Por eso la lista va vacía a propósito — no hay ninguna key de `es.lproj` que declarar.",
      "Valores en español medidos en `translations.ts`, para que el pin del Atlas pueda comprobarlos contra SU fuente: `inviteFallbackGroupName` = «Grupo» (:314) · `inviteMembers` = «Miembros» (:315) · `inviteInvitedFallback` = «Te invitaron a este grupo en Yala» (:316) · `inviteOpenInYala` = «Abrir en Yala» (:317) · `inviteDownloadAppStore` = «Descargar en App Store» (:318) · `inviteFooter` = «Yala — Finanzas personales, sin esfuerzo» (:319). Los tres de :320-322 (`invitePageTitle`, `invitePageTitleWithInviter`, `invitePageDescription`) NO se ven en la página: solo en el `<title>` y en las OG tags."
    ]
  },

  "r3-recovery": {
    copy: [
      { key: "welcome.invite.title", value: "Pega tu enlace de invitación" },
      { key: "welcome.invite.body", value: "Si te invitaron a un grupo en Yala, pega aquí el enlace que recibiste." },
      { key: "welcome.invite.placeholder", value: "https://yala-app.pe/invite?..." },
      { key: "welcome.invite.invalidLink", value: "Este enlace no parece de Yala. Verifica que copiaste el enlace completo." },
      { key: "welcome.invite.join", value: "Unirme al grupo" },
      { key: "action.back", value: "Atrás" },
      { key: "welcome.invite.back", value: "Volver" }
    ],
    notes: [
      "`welcome.invite.back` NO es copy de ESTA pantalla y no se ve en la captura: el botón visible es `action.back` = «Atrás» (`InviteRecoveryView.swift:112`). Se declara porque el panel la entrecomilla y porque su nombre engaña: la usa `WelcomeBackButton.swift:29` como `.accessibilityLabel`, o sea que solo la oye VoiceOver. Está VIVA (no marcarla `unreachable`), pero un pin que exija ver «Volver» en `r3-recovery.png` fallaría con razón."
    ]
  },

  "r3-onboarding-nombre": {
    copy: [
      { key: "groups.invite.welcome", value: "Te invitaron a un grupo" },
      { key: "groups.invite.welcomeWithGroup", value: "Te invitaron al grupo %@", unreachable: true },
      { key: "groups.invite.subtitle", value: "Yala te ayuda a dividir gastos y saber cuánto debes o te deben" },
      { key: "groups.invite.namePlaceholder", value: "Tu nombre" },
      { key: "groups.invite.joinButton", value: "Unirme al grupo" }
    ],
    notes: [
      "`groups.invite.welcomeWithGroup` va marcada `unreachable`: el título con nombre de grupo exige `inviteMetadata?.groupName` no vacío (`GroupInviteOnboardingView.swift:454-456`) y en el canal backend el drain fuerza `pendingInviteMetadata = nil` (`ContentView.swift:947`), además de que `GroupBackendInviteEntryHandler.handle` recibe el `branded:` (:70) y no lo usa. El invitado siempre ve la variante genérica.",
      "El botón dice lo mismo que el de `r3-recovery` pero es OTRA key: aquí `groups.invite.joinButton`, allí `welcome.invite.join`. Las dos valen «Unirme al grupo»."
    ]
  },

  "r3-esperando": {
    copy: [
      { key: "groups.invite.joining.title", value: "Conectando con tu grupo…" },
      { key: "groups.invite.joining.body", value: "Estamos preparando todo para que puedas dividir gastos. Esto puede tardar un momento." },
      { key: "groups.invite.slow.title", value: "Está tardando un poco más de lo normal" },
      { key: "groups.invite.slow.body", value: "Seguimos conectando con tu grupo en segundo plano. Puedes usar Yala mientras tanto: el grupo aparecerá en la pestaña Grupos apenas esté listo." },
      { key: "groups.invite.slow.continueButton", value: "Seguir a la app" }
    ],
    notes: [
      "El panel muestra DOS estados de la misma pantalla; si el pin exige las cinco keys en una sola captura, fallará: `joining.*` y `slow.*` nunca coexisten."
    ]
  },

  "r3-solicitud": {
    copy: [
      { key: "groups.invite.waitingApproval.title", value: "Solicitud enviada" },
      { key: "groups.invite.waitingApproval.body", value: "El admin del grupo debe aprobarte antes de que puedas participar. Te avisamos cuando esté listo." },
      { key: "groups.invite.waitingApproval.banner", value: "Esperando aprobación del admin" },
      { key: "groups.card.pendingApprovalChip", value: "Esperando aprobación" },
      { key: "action.continue", value: "Continuar" }
    ],
    notes: [
      "`groups.invite.waitingApproval.banner` se pinta en DOS superficies distintas con el mismo texto: el chip flotante del tab (`GroupsContainerView.swift:589`) y el banner de dentro del grupo (`GroupDetailView.swift:636`, rama `.pending`).",
      "`groups.card.pendingApprovalChip` es de la TARJETA del tab, no de la pantalla del cover: no aparece en `r3-solicitud.png` si la captura es del cover."
    ]
  },

  "r3-listo": {
    copy: [
      { key: "groups.invite.ready", value: "¡Todo listo!" },
      { key: "groups.invite.goToGroup", value: "Ir al grupo" }
    ],
    notes: [
      "Ninguna de las dos es `unreachable` —el re-tap de un miembro ya activo las alcanza (`supabase-groups-staging.ddl:492-495`)—, pero en el PRIMER join del invitado no se ven nunca."
    ]
  },

  "r3-banner": {
    copy: [
      { key: "groups.invite.syncBanner", value: "Conectando con tu grupo…" },
      { key: "groups.invite.waitingApproval.banner", value: "Esperando aprobación del admin" },
      { key: "groups.invite.error.title", value: "No pudimos unirte al grupo" },
      { key: "groups.invite.expired.banner", value: "No pudimos conectar con el grupo. Pídele al admin un enlace nuevo." },
      { key: "action.retry", value: "Reintentar" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: [
      "NINGUNA de las seis va marcada `unreachable`, y eso corrige a la derivación: `groups.invite.error.title` + `action.retry` se alcanzan por `.memberSaveFailed` (productor vivo: `GroupJoinReconciler.swift:235`) y `groups.invite.expired.banner` por `.acceptFailed(recoverable: false)` (productor vivo: `GroupBackendInviteEntryHandler.swift:320`). Lo inalcanzable en release son SUB-CASOS de la fase (`.accepting`, `.acceptFailed(recoverable: true)`), no las caras del banner.",
      "`action.cancel` no se ve como texto: es el `.accessibilityLabel` de la «✕» del banner de expirado (`GroupsContainerView.swift:617`). Solo la oye VoiceOver.",
      "Las cinco caras son excluyentes: una sola captura no puede contenerlas todas."
    ]
  },

  "r3-aprobacion": {
    copy: [
      { key: "groups.invite.rejected.title", value: "Solicitud rechazada", unreachable: true },
      { key: "groups.invite.rejected.body", value: "El admin no aprobó tu solicitud. Pídele un nuevo enlace si quieres volver a intentarlo.", unreachable: true },
      { key: "groups.card.rejectedChip", value: "Solicitud rechazada", unreachable: true }
    ],
    notes: [
      "Las tres se citan A PROPÓSITO estando medidas como sin camino alcanzable, y la razón NO es que el estado `rejected` no exista —sí existe y el servidor lo escribe (`supabase-groups-staging.ddl:596`)— sino que un `rejected` pierde el SELECT de `is_group_member` (`:71-75`), sale del alcance del pull (`gateway/src/groups/routes.ts:388`) y `reconcileLostMemberships` (`GroupsSyncClient.swift:1994-2036`) le borra el grupo local antes de que ninguna vista pueda pintarlas.",
      "La captura de este panel NO puede contener estas tres keys: retrata la aprobación y la desaparición del grupo, no el rechazo."
    ]
  },

  "r3-err-enlace": {
    copy: [
      { key: "groups.invite.linkInvalidTitle", value: "Enlace no válido" },
      { key: "groups.invite.linkInvalidDetail", value: "Este enlace ya no es válido o expiró. Pídele al admin que regenere uno." },
      { key: "groups.invite.error.title", value: "No pudimos unirte al grupo" },
      { key: "groups.invite.error.body", value: "Revisa tu conexión a internet e inténtalo de nuevo." },
      { key: "action.retry", value: "Reintentar" },
      { key: "groups.invite.error.exitButton", value: "Salir por ahora" },
      { key: "common.ok", value: "OK" },
      { key: "groups.bridge.alertTitle", value: "Hubo un problema con el grupo" },
      { key: "groups.errors.actionFailed", value: "No se pudo completar la acción. Vuelve a intentarlo." }
    ],
    notes: [
      "`groups.invite.error.title` + `groups.invite.error.body` + `action.retry` son lo que se ve PRIMERO con el cover abierto, porque la rama permanente escribe `.acceptFailed(recoverable: false)` y no `.expired` (`GroupJoinIntentTracker.swift:66-70`); `linkInvalidDetail` sin botón llega solo tras tapear «Reintentar» (`:125-126`).",
      "`groups.bridge.alertTitle` + `groups.errors.actionFailed` son la OTRA cara de la misma rama permanente, la de los kinds `notAuthorized` y `generic` (`GroupBackendInviteEntryHandler.swift:324`). Comparte título con `r3-err-canal` y cuerpo distinto — es la colisión visual que el panel denuncia."
    ]
  },

  "r3-err-canal": {
    copy: [
      { key: "groups.bridge.alertTitle", value: "Hubo un problema con el grupo" },
      { key: "groups.invite.channelUnavailable", value: "No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a intentarlo en un momento." },
      { key: "common.ok", value: "OK" }
    ],
    notes: [
      "Las tres keys son idénticas por los DOS caminos que llegan aquí (snapshot local OFF y 403 del servidor), a propósito: `AppBootstrapper.swift:2003-2005` y `GroupBackendInviteEntryHandler.swift:309-311` submitean lo mismo."
    ]
  },

  "r3-err-ckshare": {
    copy: [
      { key: "groups.invite.linkInvalidTitle", value: "Enlace no válido" },
      { key: "groups.invite.linkInvalidDetail", value: "Este enlace ya no es válido o expiró. Pídele al admin que regenere uno." },
      { key: "common.ok", value: "OK" }
    ],
    notes: [
      "Alert byte-idéntico al de `r3-err-enlace` (mismo título hardcodeado en `ContentView.swift:2014`, mismo cuerpo). Un pin que compare las dos capturas por pixel las dará por iguales, y lo son."
    ]
  },

  "r3-err-red": {
    copy: [
      { key: "groups.signin.retryLater", value: "Hmm, no pudimos conectar tu cuenta ahora. Tu grupo sigue aquí y no pierdes nada — inténtalo más tarde." },
      { key: "groups.invite.joining.title", value: "Conectando con tu grupo…" },
      { key: "groups.invite.slow.title", value: "Está tardando un poco más de lo normal" },
      { key: "groups.invite.slow.continueButton", value: "Seguir a la app" }
    ],
    notes: [
      "Las tres últimas son PRESTADAS de `r3-esperando`: la rama transitoria no tiene copy propio, y esa es exactamente la tesis del panel. La única key que es de este panel es `groups.signin.retryLater`."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R10 · Estoy de visita en el móvil de otra persona
  // ══════════════════════════════════════════════════════════════════════════

  "visita-shell": {
    copy: [
      { key: "welcome.cloud.secondaryHydrationBanner", value: "Descargando tus datos…" },
      { key: "storage.title", value: "Dónde viven tus datos" },
      { key: "storage.errors.generic", value: "Algo no salió bien. Inténtalo de nuevo." },
      { key: "settings.yalaAccountRowTitle", value: "Tu cuenta de Yala" }
    ],
    notes: [
      "`settings.yalaAccountRowTitle` se añade porque el panel entrecomilla «Tu cuenta de Yala» y la key no estaba declarada. Es la de la FILA (ProfileView); la de la pantalla es `settings.yalaAccountTitle`, con el mismo valor."
    ]
  },

  "visita-vaciar": {
    copy: [
      { key: "settings.wipeData", value: "Vaciar datos" },
      { key: "settings.wipeDataSubtitle", value: "Borra tus datos. Tu cuenta y tus grupos se conservan" },
      { key: "settings.resetAllData", value: "Vaciar todos tus datos" },
      { key: "settings.deleteAllData", value: "Vaciar mis datos" },
      { key: "settings.deleteAllDataAction", value: "Vaciar definitivamente" },
      { key: "settings.wipeDataSecondConfirmTitle", value: "¿Seguro? Esto es definitivo." },
      { key: "action.cancel", value: "Cancelar" },
      { key: "settings.retentionTitle", value: "Tus datos se vaciaron. Tus grupos siguen aquí." },
      { key: "settings.retentionQuestion", value: "¿Cómo quieres seguir usando Yala?" },
      { key: "settings.retentionGroupsOnly", value: "Solo mis grupos" },
      { key: "settings.retentionStartFresh", value: "Empezar de cero" }
    ],
    notes: [
      "`settings.deleteAllDataAction` se añade: es el botón destructivo de la hoja de alcance, que el `sees` corregido nombra.",
      "El alert corto usa `L10n.Settings.cancel` para su botón de cancelar (UserDataResetView.swift:186); el «Cancelar» que este panel declara con `action.cancel` es el del alert de borrado del Welcome, compartido con `visita-privado-alert`."
    ]
  },

  "visita-chooser": {
    copy: [
      { key: "welcome.chooser.title", value: "¡Hola! ¿Qué quieres hacer en Yala?" },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala" },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta" },
      { key: "welcome.chooser.optionInvite.title", value: "Vengo por un grupo" },
      { key: "welcome.hero.trust", value: "100% privado · Tu info siempre contigo" }
    ],
    notes: []
  },

  "visita-crear-grupo": {
    copy: [
      { key: "welcome.groups.createTitle", value: "Crear mi primer grupo" },
      { key: "welcome.groups.checking", value: "Comprobando que todo esté listo…" },
      { key: "welcome.groups.secondaryTitle", value: "Aquí estás como invitado" },
      { key: "welcome.groups.secondaryBody", value: "Esta sesión vive en el dispositivo de otra persona, así que tu primer grupo se crea desde el tuyo. Cierra tu sesión de invitado y vuelve a intentarlo allí." },
      { key: "welcome.groups.gateBack", value: "Volver" },
      { key: "welcome.groups.channelOffTitle", value: "Ahora mismo no podemos abrirte grupos" }
    ],
    notes: [
      "`welcome.groups.channelOffTitle` se añade porque las notas del panel citan ese copy al explicar el orden de los tres términos."
    ]
  },

  "visita-reentrar-cuenta": {
    copy: [
      { key: "welcome.existing.subtitle", value: "Elige cómo quieres recuperar tus datos." },
      { key: "welcome.existing.restoreTitle", value: "Restaurar desde iCloud" },
      { key: "welcome.existing.cloudTitle", value: "Entrar con Apple" },
      { key: "welcome.existing.googleTitle", value: "Entrar con Google" },
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera." }
    ],
    notes: [
      "`welcome.existing.restoreTitle` se añade: el `sees` entrecomilla «Restaurar desde iCloud» y la key no estaba declarada."
    ]
  },

  "visita-restaurar-icloud": {
    copy: [
      { key: "welcome.restore.iCloudDisabledTitle", value: "Activa iCloud para continuar" },
      { key: "welcome.restore.iCloudDisabledBody", value: "Necesitas tener iCloud activado para recuperar tus datos. Actívalo en Ajustes y vuelve a intentar." },
      { key: "welcome.restore.wiped.title", value: "Borraste tus datos" },
      { key: "welcome.restore.wiped.body", value: "Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras." },
      { key: "welcome.restore.progress.connecting", value: "Conectando con iCloud…" },
      { key: "welcome.restore.progress.importing", value: "Trayendo tus datos…" },
      { key: "welcome.restore.notFoundTitle", value: "No encontramos tus datos" },
      { key: "welcome.restore.notFoundBody", value: "No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?" },
      { key: "welcome.restore.startFresh", value: "Empezar desde cero" },
      { key: "welcome.restore.searching", value: "Buscando tus datos en iCloud…", unreachable: true },
      { key: "welcome.restore.searchingTip", value: "Esto puede tardar unos segundos.", unreachable: true }
    ],
    notes: [
      "MEDIDO: `welcome.restore.searching` y `welcome.restore.searchingTip` están declaradas en `L10n.swift:4971-4972` y traducidas, pero **cero call-sites las pintan** (grep exhaustivo sobre `Yala/`, `YalaTests/` y `YalaUITests/`: los únicos hits de `.searching` son el `case` del enum de estado de `WelcomeRestoreView`). El texto real de la espera es `welcome.restore.progress.*`, que renderiza `RestoreProgressView.swift:53-58`. Se citan marcadas como inalcanzables porque la versión previa del panel las daba por visibles.",
      "Las cuatro fases del progreso son `connecting`/`importing`/`completed`/`partial`; el panel solo entrecomilla las dos primeras porque son las que se ven en el caso sin espejo."
    ]
  },

  "visita-cuenta-nueva": {
    copy: [
      { key: "welcome.new.subtitle", value: "Elige dónde quieres guardar tus datos." },
      { key: "welcome.new.privateTitle", value: "Tu cuenta en tu iCloud privado" },
      { key: "welcome.new.cloudTitle", value: "Tu cuenta en la nube" },
      { key: "welcome.new.cloudBody", value: "Tus datos viven en nuestros servidores, como en la mayoría de tus aplicaciones. Nuestro equipo puede verlos para darte soporte y funciones nuevas." }
    ],
    notes: [
      "`welcome.new.privateTitle` se añade aquí porque el `sees` nombra las DOS cards del sub-chooser, no solo la de nube."
    ]
  },

  "visita-privado": {
    copy: [
      { key: "welcome.new.privateTitle", value: "Tu cuenta en tu iCloud privado" },
      { key: "welcome.new.privateBody", value: "Tus datos viven en los dispositivos Apple de tu Apple ID y se sincronizan por tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros." },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala" },
      { key: "welcome.chooser.optionNew.body", value: "Empieza desde cero conmigo. Te ayudo a configurar todo paso a paso." }
    ],
    notes: []
  },

  "visita-privado-alert": {
    copy: [
      { key: "welcome.freshStart.alertTitle", value: "Empezar desde cero" },
      { key: "welcome.freshStart.alertMessage", value: "Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?" },
      { key: "welcome.freshStart.alertConfirm", value: "Borrar todo y continuar" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: []
  },

  "visita-privado-onboarding": {
    copy: [
      { key: "onboarding.nameLabel", value: "¿Cómo quieres que te llamemos?" },
      { key: "onboarding.namePlaceholder", value: "Tu nombre" },
      { key: "onboarding.purpose.title", value: "¿Qué te gustaría hacer con Yala?" },
      { key: "onboarding.purpose.groups", value: "Dividir gastos con amigos" },
      { key: "onboarding.purpose.groupsDesc", value: "Viajes, cenas y cuentas compartidas" }
    ],
    notes: [
      "`onboarding.name.title` NO existe (0 hits en `es.lproj`): sustituida por `onboarding.nameLabel` (OnboardingView.swift:436) y `onboarding.namePlaceholder` (:440), que son las dos que se ven en el paso 1.",
      "`settings.wipeData` retirada de este panel: era un residuo de `visita-vaciar` y su copy no aparece en ninguna pantalla de este panel.",
      "`onboarding.purpose.groups` / `groupsDesc` añadidas: son el copy de la card que este panel afirma que NO se pinta, y sin ellas la afirmación no es verificable contra el árbol."
    ]
  },

  "visita-salida": {
    copy: [
      { key: "welcome.hero.title", value: "Tus finanzas personales," },
      { key: "welcome.hero.titleAccent", value: "sin esfuerzo." },
      { key: "welcome.hero.cta", value: "Empezar" }
    ],
    notes: [
      "Las tres se añaden porque el `sees` corregido reconoce que el panel SÍ tiene una pantalla: el Hero que el dueño encuentra al reabrir (WelcomeHeroView.swift:265, 267, 286)."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R11 · El dueño recupera su móvil
  // ══════════════════════════════════════════════════════════════════════════

  "vuelta-salida-ajustes": {
    copy: [
      { key: "settings.data", value: "Datos" },
      { key: "settings.security", value: "Seguridad y cuenta" },
      { key: "settings.signOut", value: "Cerrar sesión" },
      { key: "settings.signOutSubtitle", value: "Este dispositivo, no tu cuenta" },
      { key: "settings.wipeData", value: "Vaciar datos" },
      { key: "settings.wipeDataSubtitle", value: "Borra tus datos. Tu cuenta y tus grupos se conservan" },
      { key: "storage.title", value: "Dónde viven tus datos", unreachable: true },
      { key: "storage.sync.needsSignIn", value: "Inicia sesión para subir %d cambios", unreachable: true },
      { key: "storage.sync.signInButton", value: "Iniciar sesión", unreachable: true },
      { key: "storage.errors.generic", value: "Algo no salió bien. Inténtalo de nuevo.", unreachable: true },
      { key: "settings.yalaAccountRowTitle", value: "Tu cuenta de Yala", unreachable: true },
      { key: "settings.deleteAccount", value: "Eliminar mi cuenta", unreachable: true }
    ],
    notes: [
      "Las seis marcadas `unreachable` son el copy que el panel cita PARA DECIR QUE NO SE VE, y su inalcanzabilidad está medida para un binario de producción en sesión secundaria: `storage.title` y el banner que vive detrás (`storage.sync.needsSignIn`/`signInButton`) los tapa `StorageRowGateLogic.swift:59` con `devPanelOverrideAvailable == false`; `storage.errors.generic` es lo que pintaría `StorageSettingsView.swift:52-53` si se llegara a la pantalla, y no hay cómo llegar (los dos únicos `NavigationLink(value: .storageMode)` son ProfileView.swift:948 —oculto— y YalaAccountView.swift:149, detrás de la fila «Tu cuenta de Yala», también oculta); `settings.yalaAccountRowTitle` lo apaga ProfileView.swift:220 y `settings.deleteAccount`, ProfileView.swift:1144.",
      "En un build `Yala Dev` (`DEV_BUILD`) las tres primeras SÍ son alcanzables: la fila se abre como puerta de servicio al panel DEBUG.",
      "`storage.sync.needsSignIn` lleva `%d`: el valor de es.lproj es el literal con el formato, sin sustituir."
    ]
  },

  "vuelta-hoja": {
    copy: [
      { key: "settings.signOutConfirmTitle", value: "¿Cerrar tu sesión en este dispositivo?" },
      { key: "settings.scopeDeviceLabel", value: "En este dispositivo" },
      { key: "settings.signOutScopeDeviceSecondary", value: "Tus datos se eliminan de este dispositivo (siguen en tu cuenta)" },
      { key: "settings.scopeCloudAccountLabel", value: "En tu cuenta de Yala" },
      { key: "settings.signOutScopeCloudSecondary", value: "Tus datos siguen seguros en tu cuenta" },
      { key: "settings.scopeGroupsLabel", value: "En tus grupos" },
      { key: "settings.scopeUntouchedShort", value: "No se tocan" },
      { key: "settings.signOutScopeConservationSecondary", value: "Los datos del dueño de este dispositivo no se tocan." },
      { key: "settings.signOutConfirmAction", value: "Cerrar sesión" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: [
      "`settings.scopeCloudAccountLabel` (y no `settings.scopeICloudLabel`) porque `cloudLabel` resuelve `.cloudAccount`: en secundaria el modo EFECTIVO es `.cloud` (CloudSyncFlags.swift:249) → DestructiveScopeLogic.swift:96-97 → DestructiveScopeSheet.swift:314-315.",
      "`settings.signOutScopeConservationSecondary` es la única nota de conservación de toda la app que nombra al dueño del dispositivo."
    ]
  },

  "vuelta-pushall": {
    copy: [
      { key: "settings.signOutWorking", value: "Guardando tus cambios pendientes…", unreachable: true }
    ],
    notes: [
      "Citada A PROPÓSITO para decir que NO aparece en este camino, y por eso va marcada. Medido: `signOutWorkingCaption` exige `waitingForPending` (ProfileView.swift:158) y las dos únicas escrituras de `waitingForPending = true` viven en el cierre SOLO-GRUPOS (CloudSessionSignOut.swift:426 y :455). El copy sí es alcanzable en ese otro recorrido; en el de la invitada, no.",
      "El valor lleva puntos suspensivos tipográficos (U+2026), no tres puntos."
    ]
  },

  "vuelta-bloqueado": {
    copy: [
      { key: "settings.signOutBlockedTitle", value: "No pudimos cerrar tu sesión" },
      { key: "settings.signOutBlockedMessage", value: "Hay cambios sin subir a la nube y no queremos que pierdas nada. Revisa tu conexión e inténtalo de nuevo." },
      { key: "common.ok", value: "OK" },
      { key: "settings.signOutPendingTitle", value: "Un momento más", unreachable: true }
    ],
    notes: [
      "`settings.signOutPendingTitle` se cita para decir que este camino NUNCA la enciende: las tres salidas de bloqueo del cierre secundario construyen `reason: .permanent` (CloudSessionSignOut.swift:345, :353, :364) y `syncSignOutUI` solo enciende el alert transitorio con `.transient` (ProfileView.swift:97). Alcanzable en el cierre solo-grupos, no aquí."
    ]
  },

  "vuelta-cover": {
    copy: [
      { key: "storage.relaunch.title", value: "Ya casi está — reinicia Yala" },
      { key: "storage.relaunch.bodyAutoExit", value: "Ve a la pantalla de inicio y vuelve a abrir Yala — todo quedará listo." }
    ],
    notes: [
      "Las dos llevan raya (—, U+2014) y no guion.",
      "La variante `storage.relaunch.bodyAutoExitGroupsOnly` NO sale en este camino: `isGroupsOnly` lee `StorageModePersistence.isGroupsOnlyWipeArmed()` (SignOutRelaunchView.swift:22), que el cierre secundario no arma."
    ]
  },

  "vuelta-welcome": {
    copy: [
      { key: "welcome.hero.title", value: "Tus finanzas personales," },
      { key: "welcome.hero.titleAccent", value: "sin esfuerzo." },
      { key: "welcome.hero.cta", value: "Empezar" },
      { key: "welcome.hero.trust", value: "100% privado · Tu info siempre contigo" },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta" },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala" },
      { key: "welcome.freshStart.alertTitle", value: "Empezar desde cero" },
      { key: "welcome.freshStart.alertMessage", value: "Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?" },
      { key: "welcome.freshStart.alertConfirm", value: "Borrar todo y continuar" }
    ],
    notes: [
      "El shot es el Hero; las tres keys del chooser y del alert se citan porque el `exits` del panel las nombra literalmente (la trampa de «Es mi primera vez en Yala» es el hallazgo del panel).",
      "El Hero rota además 16 keys `welcome.hero.cards.*` (WelcomeHeroView.swift:73-80), omitidas por el tope de entradas — mismo criterio que `alta-hero`."
    ]
  },

  "vuelta-restaurar": {
    copy: [
      { key: "welcome.restore.foundTitle", value: "¡Hola %@! Qué bueno verte de vuelta." },
      { key: "welcome.restore.foundTitleAnonymous", value: "¡Qué bueno verte de vuelta!" },
      { key: "welcome.restore.foundBody", value: "Encontramos tus datos en iCloud:" },
      { key: "welcome.restore.foundAccounts", value: "%d cuentas" },
      { key: "welcome.restore.foundTransactions", value: "%d registros" },
      { key: "welcome.restore.foundBudgets", value: "%d presupuestos" },
      { key: "welcome.restore.foundGroups", value: "%d grupos compartidos" },
      { key: "welcome.restore.continue", value: "Continuar" },
      { key: "welcome.restore.startFresh", value: "Empezar desde cero" }
    ],
    notes: [
      "El título alterna: con `summary.userName` sale `foundTitle` con el nombre interpolado; sin él, `foundTitleAnonymous` (WelcomeRestoreView.swift:146). El dueño de este recorrido tiene nombre —es lo que hace `isFullyPrefilled` verdadero—, así que su pantalla es la primera.",
      "Los cuatro contadores son `%d` con `String(format:)` (L10n.swift:4988-4998); no hay .stringsdict para ellos, así que el valor de es.lproj es literalmente el formato.",
      "`welcome.restore.startFresh` comparte texto con `welcome.freshStart.alertTitle` («Empezar desde cero») pero son keys distintas."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R6 · Soy privada y salgo de Yala
  // ══════════════════════════════════════════════════════════════════════════

  "signout-fila-privada": {
    copy: [
      { key: "settings.security", value: "Seguridad y cuenta" },
      { key: "settings.signOut", value: "Cerrar sesión" },
      { key: "settings.signOutSubtitle", value: "Este dispositivo, no tu cuenta" },
      { key: "settings.exitYala", value: "Salir de Yala en este dispositivo" },
      { key: "settings.exitYalaSubtitle", value: "Volverás a la pantalla de inicio. Tus grupos siguen en tu iCloud." },
      { key: "settings.signOutGroups", value: "Cerrar sesión de grupos" },
      { key: "settings.signOutGroupsSubtitle", value: "Este dispositivo olvidará tus grupos; tus finanzas no se tocan" },
      { key: "settings.exitYalaGroupsSubtitle", value: "Volver a la pantalla de inicio; tus datos no se borran" },
      { key: "settings.signOutWorking", value: "Guardando tus cambios pendientes…" }
    ],
    notes: [
      "Las tres keys del split (`signOutGroups`, `signOutGroupsSubtitle`, `exitYalaGroupsSubtitle`) NO se marcan `unreachable`: tienen camino de código (`rowLayout` → `.groupsSignOutPlusExitYala`) y solo dependen de una sesión backend viva, que hoy es DARK en producción pero no en `Yala Dev`. No es lo mismo que no tener camino."
    ]
  },

  "signout-hoja-privada": {
    copy: [
      { key: "settings.scopeCloudAccountLabel", value: "En tu cuenta de Yala" },
      { key: "settings.signOutConfirmTitle", value: "¿Cerrar tu sesión en este dispositivo?" },
      { key: "settings.scopeDeviceLabel", value: "En este dispositivo" },
      { key: "settings.signOutScopeDevicePrivate", value: "No se borra nada; vuelves a la pantalla de inicio" },
      { key: "settings.scopeICloudLabel", value: "En iCloud" },
      { key: "settings.signOutScopeCloudPrivate", value: "Tus datos siguen en iCloud" },
      { key: "settings.scopeGroupsLabel", value: "En tus grupos" },
      { key: "settings.scopeUntouchedShort", value: "No se tocan" },
      { key: "settings.signOutScopeConservationPrivate", value: "Puedes volver a entrar cuando quieras; tus datos seguirán aquí." },
      { key: "settings.signOutConfirmAction", value: "Cerrar sesión" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: [
      "`settings.signOutConfirmAction` y `settings.signOut` tienen el MISMO valor («Cerrar sesión») y son keys distintas: una es la fila de Ajustes, la otra el botón de la hoja."
    ]
  },

  "signout-privado-ejecucion": {
    copy: [
      { key: "settings.signOutBlockedTitle", value: "No pudimos cerrar tu sesión" },
      { key: "settings.signOutBlockedMessage", value: "Hay cambios sin subir a la nube y no queremos que pierdas nada. Revisa tu conexión e inténtalo de nuevo." },
      { key: "settings.signOutPendingTitle", value: "Un momento más" },
      { key: "settings.signOutPendingMessage", value: "Todavía estamos terminando de guardar unos cambios. Espera unos segundos y vuelve a intentarlo." }
    ],
    notes: [
      "Panel SIN pantalla: estas cuatro keys se declaran porque el panel las entrecomilla para decir que son inalcanzables DESDE ESTE CAMINO.",
      "NO se marcan `unreachable`: tienen camino vivo desde `.cloud`, secundario (M1) y solo-grupos (`phase = .blocked` en CloudSessionSignOut.swift:243/253/264/284, 345/353/364 y 417/421/431). Lo inalcanzable es la combinación «alert + camino privado», no el copy."
    ]
  },

  "signout-welcome-condatos": {
    copy: [
      { key: "welcome.mirrorRelaunch.title", value: "Un último paso: reabre Yala" },
      { key: "welcome.hero.title", value: "Tus finanzas personales," },
      { key: "welcome.hero.titleAccent", value: "sin esfuerzo." },
      { key: "welcome.hero.cta", value: "Empezar" },
      { key: "welcome.hero.trust", value: "100% privado · Tu info siempre contigo" },
      { key: "welcome.chooser.title", value: "¡Hola! ¿Qué quieres hacer en Yala?" },
      { key: "welcome.chooser.subtitle", value: "Elige tu punto de partida y seguimos desde ahí." },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala" },
      { key: "welcome.chooser.optionNew.body", value: "Empieza desde cero conmigo. Te ayudo a configurar todo paso a paso." },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta" },
      { key: "welcome.chooser.optionExisting.body", value: "Ya usé Yala antes y quiero recuperar mis datos, estén en iCloud o en mi cuenta." },
      { key: "welcome.chooser.optionInvite.title", value: "Vengo por un grupo" },
      { key: "welcome.chooser.optionInvite.body", value: "Quiero dividir gastos con amigos: crear un grupo o unirme a uno." }
    ],
    notes: [
      "`welcome.hero.trust` se pinta bajo el CTA (WelcomeHeroView.swift:291) y por eso entra en el `sees`: la corrección del refutador era que estaba declarada y no citada."
    ]
  },

  "signout-salidas-matriz": {
    copy: [
      { key: "welcome.groups.title", value: "¿Cómo empiezas con tu grupo?" },
      { key: "welcome.groups.subtitle", value: "Las dos vías te dejan en el mismo sitio." },
      { key: "welcome.groups.createTitle", value: "Crear mi primer grupo" },
      { key: "welcome.groups.createBody", value: "Invitas tú. Registras lo que pagan todos y Yala lleva las cuentas." },
      { key: "welcome.groups.joinTitle", value: "Tengo una invitación" },
      { key: "welcome.groups.joinBody", value: "Pega el enlace que te enviaron y entras al grupo." },
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera." },
      { key: "welcome.groups.channelOffTitle", value: "Ahora mismo no podemos abrirte grupos" },
      { key: "welcome.groups.channelOffBody", value: "Es algo de nuestro lado y dura poco. Vuelve a intentarlo en un momento: no se ha guardado nada." }
    ],
    notes: [
      "Panel SIN pantalla: las keys se declaran porque el panel entrecomilla el copy de la puerta del organizador (regla 4). La pantalla que las pinta es `WelcomeGroupsGateView` y su panel propio en el Atlas es `alta-groupsgate-blocked`.",
      "`welcome.groups.secondaryTitle` («Aquí estás como invitado») y `welcome.groups.secondaryBody` NO se citan aquí: pertenecen al tercer término de la puerta, que es de la ola M1 y de otro recorrido."
    ]
  },

  "signout-freshstart-alert": {
    copy: [
      { key: "welcome.freshStart.alertTitle", value: "Empezar desde cero" },
      { key: "welcome.freshStart.alertMessage", value: "Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?" },
      { key: "welcome.freshStart.alertConfirm", value: "Borrar todo y continuar" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: [
      "`welcome.freshStart.alertTitle` y `welcome.restore.startFresh` tienen el MISMO valor («Empezar desde cero») y son dos cosas distintas: éste borra, el otro no."
    ]
  },

  "signout-restaurar-vuelta": {
    copy: [
      { key: "welcome.restore.progress.connecting", value: "Conectando con iCloud…" },
      { key: "welcome.restore.progress.importing", value: "Trayendo tus datos…" },
      { key: "welcome.restore.progress.completed", value: "Sincronización completada" },
      { key: "welcome.restore.progress.partial", value: "Listo lo esencial. Seguiremos sincronizando mientras usas la app." },
      { key: "welcome.restore.foundTitle", value: "¡Hola %@! Qué bueno verte de vuelta." },
      { key: "welcome.restore.foundTitleAnonymous", value: "¡Qué bueno verte de vuelta!" },
      { key: "welcome.restore.foundBody", value: "Encontramos tus datos en iCloud:" },
      { key: "welcome.restore.foundAccounts", value: "%d cuentas" },
      { key: "welcome.restore.foundTransactions", value: "%d registros" },
      { key: "welcome.restore.foundBudgets", value: "%d presupuestos" },
      { key: "welcome.restore.foundGroups", value: "%d grupos compartidos" },
      { key: "welcome.restore.continue", value: "Continuar" },
      { key: "welcome.restore.startFresh", value: "Empezar desde cero" },
      { key: "welcome.restore.startFreshConfirm.title", value: "¿Empezar desde cero?" },
      { key: "welcome.restore.startFreshConfirm.body", value: "Esto creará una cuenta nueva sin tus datos previos. ¿Continuar?" },
      { key: "welcome.restore.startFreshConfirm.confirm", value: "Sí, empezar desde cero" },
      { key: "welcome.restore.startFreshConfirm.cancel", value: "Cancelar" }
    ],
    notes: [
      "El código llama a estas cuatro últimas por los símbolos `startFreshConfirmTitle`/`Body`/`Confirm`/`Cancel` (WelcomeRestoreView.swift:94, 98, 101, 103); las keys en `es.lproj` llevan el punto (`welcome.restore.startFreshConfirm.title`, …)."
    ]
  },

  "signout-restaurar-errores": {
    copy: [
      { key: "welcome.restore.iCloudDisabledTitle", value: "Activa iCloud para continuar" },
      { key: "welcome.restore.iCloudDisabledBody", value: "Necesitas tener iCloud activado para recuperar tus datos. Actívalo en Ajustes y vuelve a intentar." },
      { key: "welcome.restore.openSettings", value: "Abrir Ajustes" },
      { key: "welcome.restore.wiped.title", value: "Borraste tus datos" },
      { key: "welcome.restore.wiped.body", value: "Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras." },
      { key: "welcome.restore.notFoundTitle", value: "No encontramos tus datos" },
      { key: "welcome.restore.notFoundBody", value: "No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?" },
      { key: "welcome.restore.errorTitle", value: "Hubo un problema" },
      { key: "welcome.restore.errorBody", value: "No pudimos buscar tus datos en iCloud. Intenta de nuevo o configura desde cero." },
      { key: "welcome.restore.retry", value: "Reintentar búsqueda" },
      { key: "welcome.restore.startFresh", value: "Empezar desde cero" }
    ],
    notes: [
      "`welcome.restore.retry` no es el texto de un botón visible: es el `accessibilityLabel` del icono `arrow.clockwise` de la barra (WelcomeRestoreView.swift:88)."
    ]
  },

  "signout-hoja-legado5a": {
    copy: [
      { key: "settings.exitYalaConfirmTitle", value: "¿Salir de Yala en este dispositivo?" },
      { key: "settings.scopeDeviceLabel", value: "En este dispositivo" },
      { key: "settings.exitYalaScopeDeviceLegacy", value: "Vuelves a la pantalla de inicio; tus datos no se tocan" },
      { key: "settings.scopeICloudLabel", value: "En iCloud" },
      { key: "settings.exitYalaScopeCloudLegacy", value: "Tus grupos siguen en tu iCloud" },
      { key: "settings.scopeGroupsLabel", value: "En tus grupos" },
      { key: "settings.exitYalaScopeGroupsLegacy", value: "Siguen en tu iCloud" },
      { key: "settings.exitYalaScopeConservationLegacy", value: "Puedes volver a entrar cuando quieras; tus grupos siguen en tu iCloud." },
      { key: "settings.exitYalaConfirmAction", value: "Salir de Yala" },
      { key: "action.cancel", value: "Cancelar" }
    ],
    notes: [
      "`settings.exitYala` («Salir de Yala en este dispositivo») y `settings.exitYalaConfirmAction` («Salir de Yala») son distintas: la primera es la fila, la segunda el botón de la hoja."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R5 · Vuelvo a Yala en un móvil nuevo
  // ══════════════════════════════════════════════════════════════════════════

  "reentry-movilnuevo": {
    copy: [
      { key: "welcome.chooser.title", value: "¡Hola! ¿Qué quieres hacer en Yala?" },
      { key: "welcome.chooser.optionNew.title", value: "Es mi primera vez en Yala" },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta" },
      { key: "welcome.existing.subtitle", value: "Elige cómo quieres recuperar tus datos." },
      { key: "welcome.existing.restoreTitle", value: "Restaurar desde iCloud" },
      { key: "welcome.existing.cloudTitle", value: "Entrar con Apple" },
      { key: "welcome.existing.googleTitle", value: "Entrar con Google" },
      { key: "welcome.cloud.title", value: "Entra a tu cuenta" },
      { key: "welcome.cloud.subtitle", value: "Usa el mismo Apple ID con el que creaste tu cuenta de la nube." },
      { key: "welcome.cloud.subtitleGoogle", value: "Usa la misma cuenta de Google con la que creaste tu cuenta de la nube." },
      { key: "welcome.cloud.providerNote", value: "Entra con el mismo método que usaste al crear tu cuenta: tu cuenta de Yala queda ligada a él." },
      { key: "storage.consent.title", value: "Tus datos en la nube de Yala" },
      { key: "storage.consent.accept", value: "Entiendo y quiero activar la nube" },
      { key: "welcome.cloud.checking", value: "Verificando tu cuenta…" }
    ],
    notes: [
      "Las siete primeras keys faltaban en la versión anterior del panel, que sí entrecomillaba su copy: el pin de «copy exacto» se las estaba perdiendo.",
      "La cabecera del sub-chooser reusa `welcome.chooser.optionExisting.title` (WelcomeExistingChooserView.swift:36), no una key propia.",
      "El intro conmuta entre `welcome.cloud.subtitle` y `welcome.cloud.subtitleGoogle` según el provider (WelcomeCloudSignInView.swift:352-354)."
    ]
  },

  "reentry-mismomovil": {
    copy: [
      { key: "storage.consent.title", value: "Tus datos en la nube de Yala" },
      { key: "storage.consent.accept", value: "Entiendo y quiero activar la nube" },
      { key: "action.cancel", value: "Cancelar" },
      { key: "welcome.cloud.checking", value: "Verificando tu cuenta…" },
      { key: "welcome.cloud.providerMismatchTitle", value: "Esa cuenta usa otro método" },
      { key: "welcome.cloud.providerMismatchBody", value: "Tu cuenta de Yala se creó con %@. Vuelve atrás y entra con ese método." }
    ],
    notes: [
      "`action.cancel` es el botón de la barra del sheet de consent (CloudConsentView.swift:88, vía `L10n.Common.cancel`).",
      "Las dos keys de mismatch se añaden porque la nota del panel entrecomilla «Tu cuenta de Yala se creó con Google»: el copy real lleva `%@`, y el «Google» sale del provider del faro. NO se marcan `unreachable`: la pantalla tiene camino real (cuenta borrada server-side con faro stale y sin `accountHash`), solo que NO es el que el panel anterior describía."
    ]
  },

  "reentry-falsobloqueo": {
    copy: [
      { key: "welcome.cloud.blockedTitle", value: "Este dispositivo tiene datos de otra cuenta" },
      { key: "welcome.cloud.blockedBody", value: "Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera." },
      { key: "storage.title", value: "Dónde viven tus datos" }
    ],
    notes: [
      "`storage.title` se añade porque `exits` entrecomilla «Dónde viven tus datos» al describir la salida por Ajustes.",
      "El identifier de a11y de la pantalla es `welcome_cloud_blocked_foreign_data` (WelcomeCloudSignInView.swift:261), declarado SIN XCUITest a propósito: su gemela de la puerta de Grupos (`welcome_groups_gate_foreign_data`) es la que cubre `SecondarySessionGateUITests`."
    ]
  },

  "reentry-errores": {
    copy: [
      { key: "welcome.cloud.errorTitle", value: "Algo no salió bien" },
      { key: "welcome.cloud.errorBody", value: "No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo." },
      { key: "welcome.cloud.retry", value: "Reintentar" },
      { key: "welcome.cloud.adopting", value: "Conectando con tu cuenta…" },
      { key: "welcome.cloud.adoptingHint", value: "Esto puede tardar unos minutos. Mantén Yala abierta." },
      { key: "welcome.cloud.waitingTitle", value: "Tu cuenta se está preparando en otro dispositivo" },
      { key: "welcome.cloud.waitingBody", value: "Puedes esperar aquí o continuar a la app; seguiremos intentándolo." },
      { key: "welcome.cloud.continueToApp", value: "Continuar a la app" }
    ],
    notes: [
      "Es también el pin de `welcome.cloud.adopting` / `adoptingHint` para los paneles de decisión que las citan sin tener pantalla propia (`reentry-adoptvacio`, `reentry-attestmuerta`)."
    ]
  },

  "reentry-killmidadopt": {
    copy: [
      { key: "storage.title", value: "Dónde viven tus datos" }
    ],
    notes: [
      "Única cita textual del panel: la fila de Ajustes a la que aterriza quien mató la app a mitad del adopt. La versión anterior la entrecomillaba con la lista de keys vacía."
    ]
  },

  "reentry-nuevainstalacion": {
    copy: [
      { key: "setup.title", value: "Primeros pasos" },
      { key: "setup.progress", value: "%d de %d completados" },
      { key: "subscription.trialOffer.title", value: "Prueba Yala Pro gratis" },
      { key: "subscription.trialOffer.subtitle", value: "30 días con todas las funciones. Sin compromiso, cancela cuando quieras." }
    ],
    notes: [
      "El panel anterior no citaba copy y salía sin keys; se le añade el copy REAL de las dos superficies que describe, medido en SetupChecklistCard.swift:74-78 y ProTrialOfferSheet.swift:55-60.",
      "`setup.progress` lleva dos `%d` (completados / total) — el valor se cita con los placeholders, no resuelto."
    ]
  },

  "reentry-vacio": {
    copy: [
      { key: "welcome.cloud.secondaryHydrationBanner", value: "Descargando tus datos…", unreachable: true },
      { key: "storage.title", value: "Dónde viven tus datos" },
      { key: "subscription.trialOffer.title", value: "Prueba Yala Pro gratis" }
    ],
    notes: [
      "`welcome.cloud.secondaryHydrationBanner` va marcada `unreachable`: HOY EN PRODUCCIÓN ningún usuario puede verla. Su gate exige `SecondarySessionStore.isActive()` y los únicos dos escritores del descriptor son la rama `.proceedSecondarySession` (WelcomeCloudSignInView.swift:778), que exige `CloudSyncFlags.secondarySessionEntryAvailable` —percent 0 en producción y `absentDefault` false—, y el panel DEBUG (CloudSyncDebugView.swift:1004). NO es copy muerto: en DEV/staging al 100 % la invitada sí lo ve, y el seam `-uitest-secondary-session` lo enciende para XCUITest. El Atlas la cita a propósito: es el hallazgo del panel.",
      "`storage.title` y `subscription.trialOffer.title` se añaden porque el panel entrecomilla las dos superficies que sí aparecen."
    ]
  },

  "reentry-puertaequivocada": {
    copy: [
      { key: "storage.title", value: "Dónde viven tus datos" },
      { key: "welcome.existing.restoreTitle", value: "Restaurar desde iCloud" },
      { key: "welcome.existing.restoreBody", value: "Tus datos guardados con tu iCloud vuelven a este dispositivo." },
      { key: "welcome.restore.notFoundTitle", value: "No encontramos tus datos" },
      { key: "welcome.restore.notFoundBody", value: "No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?" },
      { key: "welcome.restore.startFresh", value: "Empezar desde cero" },
      { key: "welcome.restore.wiped.title", value: "Borraste tus datos" },
      { key: "welcome.restore.wiped.body", value: "Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras." },
      { key: "storage.adopt.title", value: "Activar la nube en este dispositivo" },
      { key: "storage.adopt.body", value: "Esta cuenta ya tiene tus datos en la nube. Vamos a activarla en este dispositivo." },
      { key: "storage.adopt.button", value: "Activar en este dispositivo" }
    ],
    notes: [
      "Las dos keys de `wiped` son nuevas: acompañan a la tercera rama que este pase añadió tras medirla.",
      "La cuarta salida de la misma pantalla, `welcome.restore.iCloudDisabledTitle` = \"Activa iCloud para continuar\", NO se lista porque el panel no la retrata — pero es la que sale en un simulador sin cuenta de iCloud, y por eso la captura queda `pending`."
    ]
  },

  "reentry-killswitch": {
    copy: [
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta" },
      { key: "welcome.chooser.optionExisting.body", value: "Ya usé Yala antes y quiero recuperar mis datos, estén en iCloud o en mi cuenta." },
      { key: "welcome.existing.restoreTitle", value: "Restaurar desde iCloud" },
      { key: "welcome.restore.notFoundTitle", value: "No encontramos tus datos" },
      { key: "welcome.restore.notFoundBody", value: "No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?" },
      { key: "storage.title", value: "Dónde viven tus datos" }
    ],
    notes: [
      "`welcome.existing.restoreTitle` y `storage.title` faltaban aunque el panel las entrecomilla.",
      "El copy de la card de nivel 1 (`optionExisting.body`) sigue prometiendo «estén en iCloud o en mi cuenta» cuando bajo el kill solo queda iCloud: es parte del hallazgo, no una cita decorativa."
    ]
  }
};
