//
//  RouterIntent.swift
//  Yala
//
//  Intent enum consumed by AppRouter. Each case represents a UI action (sheet,
//  alert, navigation) produced by async sources (deeplinks, notifications,
//  Share Extension, Control Center, monetization triggers) and drained by a
//  specific consumer view. Named RouterIntent (not AppIntent) to avoid
//  collision with Apple's AppIntents.AppIntent protocol.
//

import Foundation

/// Feature keys for upgrade prompts routed via `.presentUpgradeSheet`.
enum UpgradeFeature: String {
    case voice, image, accounts, chat
}

/// Custom keys del CKShare zone-wide (escritas/leídas por owner via `setArchived`,
/// leídas por invitados pre-accept via `metadata.share[key]`).
enum CKShareCustomKey {
    static let isArchived = "isArchived"
    static let isHiddenForAll = "isHiddenForAll"
}

// `InviteMetadata` se BORRÓ el 2026-09-05 (medido: CERO productores en todo el árbol — nadie escribía
// `InviteMetadata(`). Exigía un `CKShare.Metadata` no-opcional, o sea del canal que la Fase 3 borró, así
// que su único consumidor —`GroupInviteOnboardingView`— lo recibía siempre `nil` y pintaba el visual
// genérico aunque el enlace trajera el nombre del grupo. Su relevo es `InviteLinkService.BrandedMetadata`,
// que es lo que de verdad viaja en el enlace y además persiste con el join intent.

/// Routed app-level intent. Fully self-contained — does not leak internal
/// state into callers. Each case declares its consumer (`handler`), priority
/// ordering, stable `id` for deduplication, and whether it survives
/// scene-phase transitions (`isTransient`).
enum RouterIntent: Identifiable, Equatable {

    // A) Deep-link / Share / Notification → sheets
    case showInboxAlert(PendingInboxNotification)
    case presentInboxSheet
    case presentSharedImage(URL)
    case presentNewTransaction
    case presentNewTransactionFromChatDraft(ChatDraftPrefill)
    case presentVoiceEntry
    case presentImageEntry
    case presentUpgradeSheet(UpgradeFeature)
    case requestAIConsent(PendingAIInput)

    // B) Monetization (MainTabView consumer)
    case presentDowngradeResolution
    case presentTrialExpired
    case presentTrialOffer
    case presentMilestoneUpgrade(Int)
    case requestAppStoreReview

    /// **Paso 4 · el espejo de iCloud llegó tarde y trajo un corpus previo.** Va por el router y no como
    /// un `@State` encendido a pelo porque su sonda contesta desde un `Task` async, cuando el anchor de
    /// `ContentView` puede estar presentando otra cosa (el cover de idioma, el sheet del trial): encender
    /// una presentación ahí sin gate es la regla (3) de Presentaciones, y su corolario del MOMENTO —un
    /// cover montado con el bootstrap a medias se queda PEGADO— está medido en este repo.
    ///
    /// **Y lleva también «el borrado quedó a medias»** (ticket
    /// `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed`): es la misma hoja en otro momento, y
    /// lo pregunta el mismo `runLateICloudMirrorCheck` en el arranque. El dedup sigue siendo por el HECHO.
    case presentLateICloudMirrorNotice(LateICloudNotice)

    // C) Groups & invites
    case showInviteError(String)
    case showGroupSyncError(String)
    /// g13_05: se tapeó el enlace de un grupo ARCHIVADO. No es un error y no se presenta como tal — ni
    /// `.showInviteError` (su título dice «Enlace no válido», y aquí el enlace es perfecto) ni
    /// `.showGroupSyncError` («Hubo un problema con el grupo», cuando no ha habido ninguno). Es un
    /// ESTADO del grupo, reversible por su admin, y por eso trae su propia tarjeta con el copy
    /// `groups.reconnect.archived.*` — los tres strings ya traducidos a 16 idiomas y hasta hoy sin
    /// consumidor. `groupName` viene del `n=` del enlace, o del fallback genérico si no lo traía.
    case showGroupArchivedNotice(groupID: String, groupName: String)
    case presentFullModeActivation
    /// G4-invites (DARK): un link backend llegó con sesión pero sin consentimiento de
    /// grupos → presentar la pantalla de consent. Payload = keying `zoneName`
    /// (== group_id backend). La VISTA la conecta A2; A1 define+drena el intent.
    case presentGroupsConsent(pendingJoin: String)
    /// G4-invites (DARK): un link backend (g+t) llegó sin sesión Nube → presentar el
    /// sign-in solo-grupos. El intent de join ya está persistido en `PendingJoinStore`;
    /// al firmar, el reconciler/handler completa el join. Mismo payload/keying.
    case presentGroupsSignIn(pendingJoin: String)
    /// G4-invites (DARK, A2): invitado FRESCO por link backend con sesión+consent listos →
    /// presentar el `GroupInviteOnboardingView` actual (metadata nil — visual genérico) para
    /// capturar el nombre ANTES del join; su CTA dispara el join vía el reconciler. El drain
    /// re-evalúa la condición viva (onboarding aún pendiente) antes de presentar.
    case presentGroupBackendInviteOnboarding(pendingJoin: String)
    /// G3 de Grupos-first: avanzar UN paso la rama organizador del Welcome (sign-in → consent → nombre →
    /// formulario). **Sin payload a propósito**: el paso no se recuerda, se RE-DECIDE en el drain con
    /// condiciones vivas (`GroupsOrganizerFlowLogic.nextStep`), que es la regla del repo y lo que hace que
    /// un sign-in ya hecho, un consent aceptado en otra pantalla o un kill a mitad no desalineen la máquina.
    /// Los dos primeros pasos reusan los sheets de `GroupsBackendInviteModifier` —el dueño ÚNICO de ese
    /// anchor—, así que la única presentación nueva es la del nombre.
    case presentGroupsOrganizerStep
    /// **La puerta del neutro del INVITADO** (`GroupInviteNeutralGateLogic`): aceptar esta invitación
    /// sobre un store que espeja iCloud —o que ya tiene corpus de alguien— mandaría los gastos del
    /// invitado al iCloud del dueño del teléfono, así que antes hay que devolver el dispositivo al
    /// neutro. El payload es el `groupID`, que es lo que la pantalla necesita para retomar el join.
    ///
    /// **No presenta una vista nueva**: su consumidor abre el Welcome en su step `.groupsGate` con el
    /// propósito del invitado, que es el motor de borrado ya probado. Y `supersedesWelcomeChain` es
    /// `true` como en sus tres hermanos de esta cadena, y por lo mismo: llega de FUERA (un link, el
    /// reconciler en boot) y se encuentra el Welcome montado por delante — sin eso, el cover del Welcome
    /// bloquearía justo el intent que tiene que reemplazarlo.
    case presentGroupsInviteNeutralGate(pendingJoin: String)

    // D) Tab navigation
    case navigate(DeepLinkDestination)

    // E) Auto-editors
    case autoOpenBudgetEditor
    case autoOpenScheduledEditor

    // F) System alerts
    case iCloudMismatch
    case remoteWipe(skipOnboarding: Bool)
    case remoteOnboardingCompleted
    /// **El Apple ID del teléfono cambió y la sesión privada era del anterior** (ADR §1: la sesión
    /// privada es del Apple ID). Pide el cierre con confirmación; lo decide
    /// `AppleIDChangeCloseLogic.decide`. Va al FINAL del bloque F y no en medio: el orden de este enum
    /// se lee desde fuera.
    case appleIDChangedClosePrivate
    /// **El aviso de «tus datos fueron eliminados de iCloud».** No lo produce la señal del Apple ID
    /// —esa es `.remoteWipe`, que BORRA— sino la gracia de cinco segundos de `ContentView`: las filas
    /// personales desaparecieron del store y siguen sin estar. Este intent no borra nada; PREGUNTA.
    ///
    /// **Va por la cola y no por un `@State` encendido desde su `Task`**, que es lo que hacía hasta el
    /// 2026-09-14: quien lo enciende es asíncrono, así que puede vencer con el anchor de `ContentView`
    /// ocupado —el aviso del espejo tardío, la oferta de prueba, el selector de idioma— y encender un
    /// `.alert` ahí DESMONTA lo que hubiera debajo (traza del 2026-09-03 en `ShellDataAlertsModifier`).
    /// Por la cola, el drenaje sólo ocurre con la matriz de readiness limpia. Regla (3) de
    /// Presentaciones, y el mismo molde que `.presentLateICloudMirrorNotice`.
    ///
    /// **Sin payload a propósito**: el veredicto NO viaja. El drenaje re-mide las tres condiciones vivas
    /// (el eje de sesión, que las filas sigan ausentes y que el onboarding siga completo), porque el
    /// intent no es transitorio y puede haber esperado en cola a través de un background entero — y el
    /// aviso afirma un hecho sobre AHORA.
    case presentRemoteWipeNotice

    // What's new (version bump)
    case presentWhatsNew(features: [WhatsNewFeature], version: String)
}

extension RouterIntent {

    enum Priority: Int, Comparable {
        case low, normal, high, critical
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Consumer view that owns this intent's drain logic.
    var handler: AppRouter.ConsumerID {
        switch self {
        case .presentLateICloudMirrorNotice: return .contentView
        case .showInboxAlert, .presentTrialOffer, .presentWhatsNew,
             .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsOrganizerStep, .presentGroupsInviteNeutralGate,
             .showInviteError,
             .showGroupSyncError,
             .showGroupArchivedNotice,
             .iCloudMismatch, .remoteWipe, .remoteOnboardingCompleted,
             .appleIDChangedClosePrivate, .presentRemoteWipeNotice,
             .presentFullModeActivation:
            return .contentView

        case .presentInboxSheet, .presentSharedImage, .presentNewTransaction,
             .presentNewTransactionFromChatDraft,
             .presentVoiceEntry, .presentImageEntry, .presentUpgradeSheet,
             .requestAIConsent:
            return .panel

        case .presentDowngradeResolution, .presentTrialExpired,
             .presentMilestoneUpgrade, .requestAppStoreReview, .navigate:
            return .mainTab

        case .autoOpenBudgetEditor, .autoOpenScheduledEditor:
            return .planning
        }
    }

    /// Relative ordering inside a single consumer's drain queue. Higher
    /// priority intents are drained first when multiple are queued for the
    /// same consumer.
    var priority: Priority {
        switch self {
        // `.showGroupArchivedNotice` va con `.showInviteError` y no con `.showGroupSyncError`: la
        // prioridad la fija el MOMENTO, no la gravedad. Los dos contestan a un tap de enlace que el
        // usuario acaba de dar y cuya respuesta está esperando; si otra cosa se cuela delante, se queda
        // sin saber por qué no entró.
        // `.appleIDChangedClosePrivate` va con `.remoteWipe` y no con el aviso de espejo tardío: hasta
        // que se conteste, la app le está enseñando a quien cambió de Apple ID los datos personales del
        // dueño anterior. No es un aviso que pueda esperar al arranque siguiente.
        case .iCloudMismatch, .remoteWipe, .showInviteError, .showGroupArchivedNotice,
             .appleIDChangedClosePrivate:
            return .critical
        // **`.presentRemoteWipeNotice` es `.high` y NO `.critical`, y esa es su red.** La regla
        // `remoteWipe_supersedes_nonCritical` de `IntentSupersessionLogic` tira todo lo que esté por
        // debajo de `.critical` cuando llega un `.remoteWipe`: si la señal explícita del Apple ID
        // aparece mientras este aviso espera su turno, el aviso que sólo SOSPECHA que borraron los
        // datos sobra — lo que procede es el borrado orquestado, con su aterrizaje. Marcarlo
        // `.critical` como su hermano lo dejaría en cola para salir DESPUÉS del borrado, diciéndole a
        // la persona que le eliminaron unos datos que la app acaba de barrer delante de ella.
        case .showInboxAlert, .presentSharedImage, .presentDowngradeResolution,
             .presentTrialExpired, .requestAIConsent, .showGroupSyncError,
             .remoteOnboardingCompleted, .presentRemoteWipeNotice:
            return .high
        // **`.high` y no `.normal`**: mientras este aviso no se conteste, el espejo sigue mezclando dos
        // corpus personales. Va por delante del trial y del What's New —que pueden esperar al arranque
        // siguiente— y por detrás de los `.critical`, que contestan a un tap que la persona acaba de dar.
        case .presentLateICloudMirrorNotice:
            return .high
        case .presentInboxSheet, .presentNewTransaction, .presentNewTransactionFromChatDraft,
             .presentVoiceEntry, .presentImageEntry, .presentUpgradeSheet,
             .presentMilestoneUpgrade,
             .presentFullModeActivation, .navigate,
             .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsOrganizerStep, .presentGroupsInviteNeutralGate,
             .presentTrialOffer, .autoOpenBudgetEditor, .autoOpenScheduledEditor:
            return .normal
        case .requestAppStoreReview, .presentWhatsNew:
            return .low
        }
    }

    /// Stable identifier used for deduplication. Intents with identical ids
    /// collapse inside the queue (last-write-wins for payload).
    var id: String {
        switch self {
        case .showInboxAlert(let n):
            return "inboxAlert:\(n.scheduledPayments)-\(n.subscriptions)-\(n.automations)"
        case .presentInboxSheet:
            return "inboxSheet"
        case .presentSharedImage(let url):
            return "sharedImage:\(url.lastPathComponent)"
        case .presentNewTransaction:
            return "newTransaction"
        case .presentNewTransactionFromChatDraft:
            return "newTransactionFromChatDraft"
        case .presentVoiceEntry:
            return "voiceEntry"
        case .presentImageEntry:
            return "imageEntry"
        case .presentUpgradeSheet(let feature):
            return "upgrade:\(feature.rawValue)"
        case .requestAIConsent(let input):
            return "requestAIConsent:\(input)"
        case .presentDowngradeResolution:
            return "downgrade"
        case .presentTrialExpired:
            return "trialExpired"
        case .presentTrialOffer:
            return "trialOffer"
        // Dedup por el HECHO y no por las cifras: dos sondas del mismo arranque hablan del mismo corpus
        // aunque el espejo haya bajado tres filas más entre una y otra.
        case .presentLateICloudMirrorNotice:
            return "lateICloudMirrorNotice"
        case .presentMilestoneUpgrade(let n):
            return "milestone:\(n)"
        case .requestAppStoreReview:
            return "appReview"
        case .showInviteError(let detail):
            return "inviteError:\(detail.hashValue)"
        case .showGroupSyncError(let detail):
            return "groupSyncError:\(detail.hashValue)"
        // Dedup por GRUPO y no por el texto: dos taps al mismo enlace archivado son el mismo aviso, y el
        // nombre puede variar entre ellos (un enlace con `n=` y otro sin él) sin que sean cosas distintas.
        case .showGroupArchivedNotice(let groupID, _):
            return "groupArchived:\(groupID)"
        case .presentFullModeActivation:
            return "fullMode"
        case .presentGroupsConsent(let pendingJoin):
            return "groupsConsent:\(pendingJoin)"
        case .presentGroupsSignIn(let pendingJoin):
            return "groupsSignIn:\(pendingJoin)"
        case .presentGroupBackendInviteOnboarding(let pendingJoin):
            return "groupBackendInviteOnboarding:\(pendingJoin)"
        case .presentGroupsInviteNeutralGate(let pendingJoin):
            return "groupsInviteNeutralGate:\(pendingJoin)"
        case .presentGroupsOrganizerStep:
            // Clave FIJA (sin payload): dos avances encolados a la vez son el mismo avance, y colapsarlos
            // es lo correcto — el drain re-decide el paso con condiciones vivas de todos modos.
            return "groupsOrganizerStep"
        case .navigate(let dest):
            return "navigate:\(dest.routerKey)"
        case .autoOpenBudgetEditor:
            return "budgetEditor"
        case .autoOpenScheduledEditor:
            return "scheduledEditor"
        case .iCloudMismatch:
            return "iCloudMismatch"
        case .remoteWipe:
            return "remoteWipe"
        case .remoteOnboardingCompleted:
            return "remoteOnboardingCompleted"
        case .appleIDChangedClosePrivate:
            return "appleIDChangedClosePrivate"
        case .presentRemoteWipeNotice:
            return "remoteWipeNotice"
        case .presentWhatsNew(_, let version):
            return "whatsNew:\(version)"
        }
    }

    /// Transient intents are dropped on `.background` via `resetTransients()`.
    /// Persistence-backed intents re-emit on `.active` from their source
    /// services. Critical alerts survive backgrounding.
    var isTransient: Bool {
        switch self {
        case .remoteWipe, .iCloudMismatch, .remoteOnboardingCompleted,
             .appleIDChangedClosePrivate, .presentRemoteWipeNotice:
            return false
        default:
            return true
        }
    }

    /// Intents que REEMPLAZAN la cadena welcome/onboarding en lugar de apilarse
    /// sobre ella. ContentView cierra la cadena welcome cuando uno de estos está
    /// pendiente, de modo que su drain (y presentación) pase el readiness gate
    /// — sin esto el cover del WelcomeFlow bloquea el propio intent que lo
    /// reemplazaría (deadlock B4-04).
    /// G3 · `.presentGroupsOrganizerStep` **NO está aquí, y es deliberado**: los otros tres llegan de fuera
    /// (un link, una notificación) y se encuentran el Welcome montado por delante; este lo emite el propio
    /// Welcome al salir por su portal, que cierra `showWelcomeFlow` en la MISMA vuelta. Marcarlo como
    /// superseding le daría permiso para tumbar la cadena welcome en cualquier otro momento —por ejemplo,
    /// si el usuario relanza a mitad de la rama— en vez de esperar su turno, que es lo correcto.
    var supersedesWelcomeChain: Bool {
        switch self {
        case .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsInviteNeutralGate:
            return true
        default:
            return false
        }
    }
}

extension DeepLinkDestination {
    /// Stable key for router dedup. `.groupDetail(...)` collapses to a single
    /// entry regardless of payload (last-write-wins on groupID).
    var routerKey: String {
        switch self {
        case .panel: return "panel"
        case .statistics: return "statistics"
        case .records: return "records"
        case .categories: return "categories"
        case .planning: return "planning"
        case .budgets: return "budgets"
        case .inbox: return "inbox"
        case .scheduledPayments: return "scheduledPayments"
        case .recordsStandalone: return "recordsStandalone"
        case .groups: return "groups"
        case .groupDetail: return "groupDetail"
        }
    }
}
