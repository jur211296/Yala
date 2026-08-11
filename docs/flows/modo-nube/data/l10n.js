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
      { key: "welcome.hero.subtitle", value: "Tú captura. Yala se encarga.", role: "body" },
      { key: "welcome.hero.cta", value: "Empezar", role: "button" },
      { key: "welcome.hero.trust", value: "100% privado · Tu info siempre contigo", role: "caption" },
      { key: "welcome.detectedData.title", value: "¡Hola de nuevo! Detectamos tu cuenta", role: "alert-title" },
      { key: "welcome.detectedData.message", value: "Tienes datos guardados en tu iCloud. ¿Quieres cargarlos en este dispositivo?", role: "alert-body" },
      { key: "welcome.detectedData.loadMyData", value: "Cargar mis datos", role: "button" },
      { key: "welcome.detectedData.startFresh", value: "Empezar desde cero", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "El Hero rota además un carousel de 8 cards: 16 keys `welcome.hero.cards.{capture,assistant,groups,budgets,multiAndCurrencies,import,icloud,more}.{title,body}` (WelcomeHeroView.swift:84-95), omitidas por el tope de entradas.",
      "El alert vive en WelcomeFlowContainer.swift:160-182; su Cancel es `action.cancel`."
    ]
  },
  "alta-chooser": {
    copy: [
      { key: "welcome.chooser.title", value: "¡Hola! ¿Cómo llegaste a Yala?", role: "title" },
      { key: "welcome.chooser.subtitle", value: "Cuéntanos para acomodar tu experiencia.", role: "body" },
      { key: "welcome.chooser.optionNew.title", value: "Soy nuevo", role: "row" },
      { key: "welcome.chooser.optionNew.body", value: "Empieza desde cero conmigo. Te ayudo a configurar todo paso a paso.", role: "row" },
      { key: "welcome.chooser.optionExisting.title", value: "Ya tengo una cuenta", role: "row" },
      { key: "welcome.chooser.optionExisting.body", value: "Reinstalé Yala y quiero recuperar mis datos desde iCloud.", role: "row" },
      { key: "welcome.chooser.optionInvite.title", value: "Me invitaron a un grupo", role: "row" },
      { key: "welcome.chooser.optionInvite.body", value: "Tengo un enlace de invitación y quiero unirme.", role: "row" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["WelcomeChooserView.swift:60-108; las 3 cards salen de `Branch.title/.body` (:30-44)."]
  },
  "alta-newchooser": {
    copy: [
      { key: "welcome.chooser.optionNew.title", value: "Soy nuevo", role: "title" },
      { key: "welcome.new.subtitle", value: "Elige dónde quieres guardar tus datos.", role: "body" },
      { key: "welcome.new.privateTitle", value: "Solo tú y tus dispositivos", role: "row" },
      { key: "welcome.new.privateBody", value: "Tus datos viven en tu iPhone y se sincronizan con tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros.", role: "row" },
      { key: "welcome.new.cloudTitle", value: "Tu cuenta en la nube", role: "row" },
      { key: "welcome.new.cloudBody", value: "Entra con Apple o Google y accede a tus datos desde cualquier dispositivo, aunque no uses iCloud. Se guardan en los servidores de Yala y nuestro equipo podría verlos para darte soporte y funciones inteligentes.", role: "row" },
      { key: "welcome.new.cloudWarning", value: "En este modo renuncias a la privacidad total de la otra opción.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "El título reusa la key del chooser (WelcomeNewChooserView.swift:46).",
      "La key del badge `recommendedBadge` fue RETIRADA del código y de los 16 locales (comentario en L10n.swift:4835-4837): no queda distintivo de recomendada.",
      "La renuncia (`cloudWarning`) va inline DENTRO de la card de nube y VoiceOver la lee como parte de la etiqueta."
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
  "alta-consent": {
    copy: [
      { key: "storage.consent.title", value: "Antes de activar la nube", role: "title" },
      { key: "storage.consent.point1", value: "Tus transacciones, cuentas, notas y el texto que leemos de tus recibos saldrán de tu dispositivo y se guardarán en los servidores de Yala.", role: "body" },
      { key: "storage.consent.point2", value: "Las fotos de tus recibos se quedan solo en este dispositivo: no se respaldan en la nube ni se ven en otros dispositivos. Si quieres conservarlas, guárdalas antes de cambiar de teléfono.", role: "body" },
      { key: "storage.consent.point3", value: "Nuestro equipo podría leer esos datos para darte soporte, recuperar tu cuenta y ofrecerte funciones inteligentes (categorización, lectura de recibos). No es cifrado de extremo a extremo.", role: "body" },
      { key: "storage.consent.point4", value: "Cuando usas el chat, enviamos un resumen de tus finanzas (hasta unos 13 meses) a nuestro proveedor de inteligencia artificial para poder responderte.", role: "body" },
      { key: "storage.consent.point5", value: "Tus datos se guardan en servidores en Estados Unidos.", role: "body" },
      { key: "storage.consent.point6", value: "A cambio, accedes desde cualquier dispositivo con solo tu login de Apple o Google, sin depender de iCloud. Mientras conserves ese login: no hay recuperación por email ni contraseña de Yala, así que si pierdes el acceso a esa cuenta, exporta tus datos antes (Ajustes → Exportar datos).", role: "body" },
      { key: "storage.consent.point7", value: "Puedes volver al modo privado cuando quieras, sin perder nada.", role: "body" },
      { key: "storage.consent.privacyLink", value: "Ver la política de privacidad", role: "button" },
      { key: "storage.consent.accept", value: "Entiendo y quiero activar la nube", role: "button" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: [
      "El título se usa dos veces: navigationTitle y header inline (CloudConsentView.swift:53 y 69).",
      "Confirmado: el copy es genérico e idéntico para los tres `ConsentPath` — la ruta solo cambia la telemetría."
    ]
  },
  "alta-intro": {
    copy: [
      { key: "welcome.bornCloud.title", value: "Crea tu cuenta de Yala", role: "title" },
      { key: "welcome.bornCloud.subtitle", value: "Con ella podrás abrir Yala desde cualquier dispositivo.", role: "body" },
      { key: "auth.googleButton", value: "Continuar con Google", role: "button" },
      { key: "welcome.cloud.providerNote", value: "Entra con el mismo método que usaste al crear tu cuenta: tu cuenta de Yala queda ligada a él.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El botón de Apple es `ASAuthorizationAppleIDButton(type: .signIn)`: su rótulo lo pinta el sistema, sin key de Yala."]
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
      { key: "auth.googleButton", value: "Continuar con Google", role: "button" },
      { key: "welcome.cloud.providerNote", value: "Entra con el mismo método que usaste al crear tu cuenta: tu cuenta de Yala queda ligada a él.", role: "caption" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El subtítulo conmuta por provider (WelcomeCloudSignInView.swift:299-301). El botón de Apple es nativo del sistema."]
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
      { key: "groups.empty.signedOut.reentryBanner", value: "Cerraste tu sesión de grupos. Inicia sesión cuando quieras verlos de nuevo.", role: "note" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El panel parafrasea la variante estándar como «Aún no tienes grupos»; el valor real de `groups.empty.title` es «Sin grupos». El reentryBanner es el banner D2 asociado al mismo estado."]
  },
  "onboarding-crear": {
    copy: [
      { key: "groups.new", value: "Nuevo grupo", role: "title" },
      { key: "groups.consent.title", value: "Grupos en la nube", role: "title" },
      { key: "groups.consent.point1", value: "Los grupos son compartidos por naturaleza: viven en la nube de Yala para que todos vean los mismos gastos, al día.", role: "row" },
      { key: "groups.consent.point2", value: "Solo se comparte lo mínimo: tu alias y los gastos del grupo. Tu correo no sale de tu dispositivo.", role: "row" },
      { key: "groups.consent.point3", value: "Tus finanzas personales no se mueven: siguen donde tú elegiste, privadas como siempre.", role: "row" },
      { key: "groups.consent.point4", value: "Los datos del grupo viajan y se guardan protegidos, y puedes salir del grupo cuando quieras.", role: "row" },
      { key: "groups.consent.accept", value: "Aceptar y continuar", role: "button" },
      { key: "groups.signin.title", value: "Conecta tu cuenta", role: "title" },
      { key: "groups.signin.body", value: "Para unirte al grupo necesitas una cuenta de Yala. Entra con Apple o Google y sigue con tu invitación.", role: "body" },
      { key: "groups.signin.accountNote", value: "Esta será tu cuenta de Yala: si algún día llevas tus datos personales a la nube, usarás esta misma.", role: "caption" },
      { key: "action.cancel", value: "Cancelar", role: "button" }
    ],
    missing: [],
    hardcoded: [],
    notes: ["El copy de `groups.signin.body` está redactado para el flujo de invitación («unirte al grupo») aunque también se presenta desde crear-grupo."]
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
  }
};
