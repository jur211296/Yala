//
//  TelemetryService.swift
//  Yala
//
//  Privacy-first analytics via TelemetryDeck.
//  No tracking IDs, no PII — only aggregate event signals.
//

import Foundation
import TelemetryDeck

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    case appLaunched = "App · Abierta"
    case transactionSaved = "Uso · Transacción guardada"
    case draftApproved = "Uso · Borrador aprobado"
    case draftRejected = "Uso · Borrador rechazado"
    case budgetSaved = "Planificación · Presupuesto guardado"
    case budgetFiltersAppearEmpty = "Diagnóstico · Filtros de presupuesto vacíos"  // params: budgetID, periodType, hadM2MNotEmpty
    case appEntityShortcutIDsRegenerated = "Diagnóstico · IDs de atajos regenerados"  // params: accounts, subcategories, tags, budgets, txs, drafts, favorites, scheduled, waitedForSync, waitDuration_bucket, sawRace
    case tagDeleted = "Uso · Etiqueta eliminada"  // params: duration_bucket, txCount, draftCount, favoriteCount, scheduledCount, budgetCount
    case tagCatalogRebuilt = "Diagnóstico · Catálogo de etiquetas reconstruido"  // params: tagCount
    case scheduledPaymentSaved = "Planificación · Pago programado guardado"
    case accountCreated = "Uso · Cuenta creada"
    case exportCompleted = "Uso · Exportación completada"
    case aiInsightsGenerated = "Análisis · Insight IA generado"
    case onboardingCompleted = "Activación · Onboarding completado"  // params: mode, expensesOnly, usedSeedCategories
    case onboardingStarted = "Activación · Onboarding iniciado"  // params: mode (initial|fullActivation), prefilled (true|false)
    case onboardingStepViewed = "Activación · Paso de onboarding"  // params: step, stepIndex, totalSteps, mode
    case onboardingPurposePicked = "Activación · Propósito elegido"  // params: purpose (expensesOnly|dayToDay|fullControl)
    case onboardingAccountsPicked = "Activación · Cuentas elegidas"  // params: accounts (single|multiple)
    case onboardingAccountTypePicked = "Activación · Tipo de cuenta elegido"  // params: type (checking|savings|creditCard|cash)
    case onboardingCurrencyPicked = "Activación · Moneda elegida"  // params: currency (rawValue)
    case onboardingCategoriesPicked = "Activación · Categorías elegidas"  // params: loadSeed (true|false)
    case onboardingBackTapped = "Activación · Onboarding atrás"  // params: fromStep, mode
    case onboardingCancelled = "Activación · Onboarding abandonado"  // params: atStep, mode
    case welcomeChooserBranchSelected = "Activación · Camino elegido"  // A4 — params: branch (new|restore|invite)
    case purchaseAttempted = "Pro · Compra intentada"
    case featureGateHit = "Pro · Tope de función Free"
    case reviewPromptShown = "App · Pidió reseña"
    case proUpsellShown = "Pro · Oferta mostrada"
    case proUpsellTapped = "Pro · Oferta tocada"
    case proUpsellDismissed = "Pro · Oferta descartada"
    case paywallViewed = "Pro · Vio el paywall"
    case trialStarted = "Pro · Prueba iniciada"
    case purchaseCompleted = "Pro · Compra exitosa"
    case trialExpiring = "Pro · Prueba por expirar"
    case proTourStarted = "Pro · Tour iniciado"
    case proTourPhaseCompleted = "Pro · Tour fase completada"
    case proTourCompleted = "Pro · Tour completado"
    case proTourSkipped = "Pro · Tour saltado"
    case chatSheetOpened = "Chat IA · Abierto"
    case chatSheetDismissed = "Chat IA · Cerrado"
    case chatQuestionAsked = "Chat IA · Pregunta enviada"
    case chatSuggestionTapped = "Chat IA · Sugerencia tocada"
    case chatErrorOccurred = "Chat IA · Error"
    case chatDailyLimitReached = "Chat IA · Límite diario alcanzado"
    case chatSuggestionsLLMSucceeded = "Diagnóstico · Sugerencias chat OK"
    case chatSuggestionsLLMFailed = "Diagnóstico · Sugerencias chat fallaron"
    case chatVoiceInputUsed = "Chat IA · Entrada por voz"
    case chatTopicsSheetOpened = "Chat IA · Temas abiertos"
    case chatPersistedSessionRehydrated = "Chat IA · Sesión retomada"
    // Yala AI Onboarding (4-step tutorial first-use post-consent)
    case yalaAIOnboardingShown = "Chat IA · Tutorial mostrado"  // params: launcher (panel|records|stats)
    case yalaAIOnboardingCompleted = "Chat IA · Tutorial completado"  // tap CTA Step 4 "Empezar a chatear"
    case yalaAIOnboardingSkipped = "Chat IA · Tutorial saltado"  // tap "Saltar" topRight (steps 1-3)
    case yalaAIOnboardingDismissed = "Chat IA · Tutorial cerrado"  // tap "X" topLeft — flag NO se setea
    case yalaAIOnboardingTonePicked = "Chat IA · Tono elegido"  // params: tone (normal|considerate|sarcastic), focus (balanced|saver|cautious)
    // Groups Onboarding (3-step informativo, primer tap del tab Grupos)
    case groupsOnboardingShown = "Grupos · Tutorial mostrado"  // params: launcher (groupsTab)
    case groupsOnboardingStepViewed = "Grupos · Paso de tutorial"  // params: step (1|2|3)
    case groupsOnboardingCompleted = "Grupos · Tutorial completado"  // tap CTA Step 3 "Ir a Grupos"
    // Chat → Registrar transacciones
    case chatIntentClassified = "Chat IA · Intención clasificada"  // params: intent, used_force_intent
    case chatDraftProposed = "Chat IA · Borrador propuesto"  // params: count
    case chatDraftSaved = "Chat IA · Gasto guardado"
    case chatDraftDismissed = "Chat IA · Borrador descartado"  // tap explícito en botón Descartar
    case chatDraftEditedExternally = "Chat IA · Borrador editado"
    case chatAmbiguousRepregunta = "Chat IA · Repregunta"

    // Intent lifecycle (Siri / Atajos / Lock Screen / Control Center)
    case intentInvoked = "Atajos · Atajo ejecutado"
    case intentSuccess = "Atajos · Atajo exitoso"
    case intentFailed = "Atajos · Atajo fallido"

    // Group lifecycle
    case groupCreated = "Grupos · Grupo creado"
    case groupArchived = "Grupos · Grupo archivado"
    case groupDeleted = "Grupos · Grupo eliminado"
    case groupSoftDeleted = "Grupos · Grupo eliminado para todos"
    case groupExpenseAdded = "Grupos · Gasto agregado"
    case groupTwoPersonSplitChosen = "Grupos · Split rápido elegido"  // params: choice (iPaidEqual|iPaidOwedFull|theyPaidEqual|theyPaidOwedFull|moreOptions)
    case openingBalanceCreated = "Grupos · Saldo inicial creado"
    case openingBalanceRemoved = "Grupos · Saldo inicial eliminado"
    case groupSettlementCreated = "Grupos · Liquidación creada"
    case groupSettlementConfirmed = "Grupos · Liquidación confirmada"
    case groupSettlementRejected = "Grupos · Liquidación rechazada"
    case groupInviteSent = "Grupos · Invitación enviada"
    case groupInviteAccepted = "Grupos · Invitación aceptada"

    // Bridge opt-out (F8) — disparados solo desde UI handlers (no didSet de AppPreferences)
    case bridgeGlobalToggled = "Grupos · Bridge global cambiado"
    case bridgeOverrideSet = "Grupos · Bridge override"
    case bridgeActivationCompleted = "Grupos · Bridge activado"
    case bridgeDeactivationCompleted = "Grupos · Bridge desactivado"
    case bridgeVirtualLentTxFailed = "Diagnóstico · TX préstamo virtual falló"  // params: role — TX2 virtual del préstamo no se pudo crear (saldo degradado)

    // Nudges
    case nudgeShown = "App · Sugerencia mostrada"
    case nudgeTapped = "App · Sugerencia tocada"
    case nudgeDismissed = "App · Sugerencia descartada"
    case nudgeAutoDismissed = "App · Sugerencia auto-descartada"

    // Conversion
    case fullModeActivationStarted = "Activación · Modo completo iniciado"
    case fullModeActivationCompleted = "Activación · Modo completo completado"
    case groupInviteOnboardingCompleted = "Activación · Onboarding de invitación completado"

    // Panel Hero IA
    case panelHeroAIGenerated = "Análisis · Hero IA generado"
    case panelHeroAICacheHit = "Diagnóstico · Hero IA caché"
    case panelHeroCTAImpression = "Análisis · Hero IA impresión"
    case panelHeroCTATap = "Análisis · Hero IA tocado"

    // CloudKit observability
    case cloudkitExportFailed = "Diagnóstico · Sync export falló"
    case cloudkitExportSucceeded = "Diagnóstico · Sync export OK"
    case cloudkitStalledDetected = "Diagnóstico · Sync estancado"
    case cloudkitIndicatorTapped = "Diagnóstico · Indicador sync tocado"
    case cloudkitDuplicateDetected = "Diagnóstico · Duplicado detectado"
    case cloudkitTransferOrphanRepaired = "Diagnóstico · Transferencia huérfana reparada"
    case cloudkitTransferCollisionDetected = "Diagnóstico · Colisión de transferencia"
    case cloudkitBudgetCSVMirrorRebuilt = "Diagnóstico · Espejo de presupuesto reconstruido"  // params: count
    case cloudkitGroupSyncGateHardCap = "Diagnóstico · Gate de grupos llegó al tope"  // params: isSyncing — el sync de grupos arrancó por tope sin import personal asentado
    case cloudkitGroupSyncPromotedToAuto = "Diagnóstico · Sync de grupos promovido a auto"  // params: importSettled (false = promovido por hard cap sin import asentado) — los engines pasaron de export-only a automaticallySync
    case cloudkitGroupSyncNoImportPromote = "Diagnóstico · Sync de grupos promovido sin import personal"  // sin params — store personal VACÍO (ningún .import apareció en la ventana de gracia) promovido a auto-sync; antes quedaba export-only para siempre (bug del usuario "solo grupos")
    case cloudkitGroupZoneRecovered = "Diagnóstico · Zona de grupo recuperada"  // params: count — zonas owner sin GroupMeta subido re-encoladas al arrancar
    case cloudkitGroupRecordsRecovered = "Diagnóstico · Records de grupo recuperados"  // params: count — records con ckSystemFieldsData nil (nunca subieron, p.ej. rechazados por schema) re-encolados al arrancar
    case cloudkitGroupRecordSaveRejected = "Diagnóstico · Save de grupo rechazado"  // params: code, recordType — CANARIO: >0 en prod = incidente de schema/permisos en el container de grupos (el server descarta el record; la recovery lo re-encola al próximo launch)
    case iCloudRestoreOutcome = "Diagnóstico · Resultado de restore"  // params: phase (completed|partial), destination (groupsOnly|directToApp|onboarding)

    // Routing observability (F9 — privacy-first: only intent IDs, no payloads)
    case routingIntentSuperseded = "Diagnóstico · Routing supersedido"  // a queued intent was dropped by an incoming one
    case routingIntentDeferred = "Diagnóstico · Routing diferido"  // an incoming intent was persisted to DeferredIntentBuffer
    case routingReadinessBlocked = "Diagnóstico · Routing bloqueado"  // a drain was blocked because a modal was visible
    case routingWelcomeChainSuperseded = "Diagnóstico · Routing welcome supersedido"  // welcome chain dismissed to let a superseding intent drain (B4-04)
    case inviteReEmittedFromStore = "Diagnóstico · Invitación re-emitida"  // a persisted group invite was re-emitted after the transient intent was dropped
    case invitePendingExpired = "Diagnóstico · Invitación pendiente expirada"  // a persisted group invite was purged by TTL (24h) before presenting

    // MARK: Telemetría 2.0 — eventos nuevos
    // Activación (primeras veces) · sesión · fin de suscripción
    case appResumed = "App · Reactivada"                          // warm start (foreground), complementa appLaunched (cold)
    case firstTransaction = "Activación · Primera transacción"    // params: origen
    case firstBudget = "Activación · Primer presupuesto"          // params: periodo
    case firstScheduledPayment = "Activación · Primer pago programado" // params: recurrencia
    case subscriptionEnded = "Pro · Suscripción terminada"        // Pro→Free; params: era_trial

    // P1 — CRUD · planificación · grupos · chat
    case transactionDeleted = "Uso · Transacción eliminada"           // params: type
    case transactionDuplicated = "Uso · Transacción duplicada"        // params: type
    case bulkEditApplied = "Uso · Edición masiva"                     // params: campos, cantidad_bucket
    case searchPerformed = "Uso · Búsqueda"                           // params: con_resultados
    case dataImported = "Uso · Importación"                           // params: formato, cantidad_bucket
    case budgetAlertTriggered = "Planificación · Alerta de presupuesto" // params: umbral (100 = superado)
    case budgetDeleted = "Planificación · Presupuesto eliminado"
    case scheduledPaymentDeleted = "Planificación · Pago eliminado"
    case groupLeft = "Grupos · Salió del grupo"                       // params: con_deuda
    case groupBalancesViewed = "Grupos · Balances vistos"
    case chatDraftRetried = "Chat IA · Reintento"

    // P2 — configuración + consumo
    case themeChanged = "Ajustes · Tema cambiado"                     // params: tema
    case currencyChanged = "Ajustes · Moneda principal"               // params: moneda
    case notificationsPermission = "Notificaciones · Permiso"         // params: resultado
    case notificationTapped = "Notificaciones · Tap"                  // params: tipo
    case biometricLockToggled = "Seguridad · Bloqueo biométrico"      // params: accion
    case widgetConfigured = "Atajos · Widget configurado"             // params: tipo
    case reportViewed = "Análisis · Reporte visto"
    case statsTabViewed = "Estadísticas · Tab visto"                  // params: tab
    case recordsDuplicateModeActivated = "Registros · Identificar duplicados"  // params: byAmount, byNote, bySubcategory, byDate
}

enum DuplicateDetectionContext: String {
    case bootCleanup = "boot-cleanup"
    case runtimeFetch = "runtime-fetch"
    case syncApply = "sync-apply"
    case uniquingFallback = "uniquing-fallback"
}

enum TransferReconcileContext: String {
    case bootReconcile = "boot.transferReconcile"
    case bootCollision = "boot.transferCollision"
}

// MARK: - Telemetry Service

@MainActor
enum TelemetryService {

    private static var isConfigured = false
    private static var trackedOnceKeys: Set<String> = []

    // MARK: - Configuration

    static func configure() {
        guard let appID = APIKeyService.telemetryDeckAppID else {
            #if DEBUG
            print("TelemetryService: No App ID configured — analytics disabled")
            #endif
            return
        }
        TelemetryDeck.initialize(config: .init(appID: appID))
        isConfigured = true
        #if DEBUG
        print("TelemetryService: Initialized")
        #endif
    }

    // MARK: - Tracking

    static func track(_ event: AnalyticsEvent, parameters: [String: String] = [:]) {
        guard isConfigured else { return }
        var params = parameters
        params["isProUser"] = String(FeatureGateService.shared.isProUser)
        TelemetryDeck.signal(event.rawValue, parameters: params)
        #if DEBUG
        if event.rawValue.hasPrefix("cloudkit") {
            print("TelemetryService: [CloudKit] \(event.rawValue) params=\(params)")
        }
        #endif
    }

    /// Builds common parameters for upsell/conversion tracking.
    static func upsellParameters(source: String) -> [String: String] {
        var params: [String: String] = ["source": source]
        if let firstLaunch = UserDefaults.standard.object(forKey: "reviewFirstLaunchDate") as? Date {
            let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: .now).day ?? 0
            params["daysSinceInstall"] = String(days)
        }
        params["sessionNumber"] = String(UserDefaults.standard.integer(forKey: "pro.upsell.sessionCount"))
        return params
    }

    /// Tracks an event only once per session (deduplicates by composite key).
    static func trackOnce(_ event: AnalyticsEvent, key: String, parameters: [String: String] = [:]) {
        let compositeKey = "\(event.rawValue):\(key)"
        guard !trackedOnceKeys.contains(compositeKey) else { return }
        trackedOnceKeys.insert(compositeKey)
        track(event, parameters: parameters)
    }

    /// Reports a CloudKit-driven duplicate observation. The composite key includes
    /// `keySuffix` (typically a zoneID or count) so each distinct duplicate fires once
    /// instead of collapsing every dup in a session into a single event. The suffix
    /// is local-only — it never reaches the backend.
    static func cloudkitDuplicateDetected(
        model: String,
        count: Int,
        context: DuplicateDetectionContext,
        keySuffix: String
    ) {
        trackOnce(
            .cloudkitDuplicateDetected,
            key: "\(model):\(context.rawValue):\(keySuffix)",
            parameters: [
                "model": model,
                "count": String(count),
                "context": context.rawValue
            ]
        )
    }

    // MARK: - Routing observability (F9)

    /// Fires when `RouterEntryGate` drops queued intents because an incoming one
    /// supersedes them (e.g. `.navigate(.inbox)` supersedes `.showInboxAlert`).
    /// Privacy-first: only intent IDs, no payloads.
    static func routingIntentSuperseded(droppedID: String, by incomingID: String) {
        track(.routingIntentSuperseded, parameters: [
            "dropped": droppedID,
            "by": incomingID
        ])
    }

    /// Fires when an intent is deferred to the DeferredIntentBuffer because
    /// the app cannot present right now (pre-bootstrap, locked, mid-onboarding).
    static func routingIntentDeferred(intentID: String, reason: String) {
        track(.routingIntentDeferred, parameters: [
            "intent": intentID,
            "reason": reason
        ])
    }

    /// Fires when the .contentView consumer is unable to drain because a
    /// modal is blocking. Surfaces unexpected gates in production.
    static func routingReadinessBlocked(blocker: String) {
        track(.routingReadinessBlocked, parameters: [
            "blocker": blocker
        ])
    }

    /// Fires when ContentView dismisses the welcome chain so a pending
    /// welcome-superseding intent (group invite/reconnect) can drain past the
    /// readiness gate. Confirms the B4-04 deadlock fix triggers in production.
    /// Privacy-first: only the intent ID, no payloads.
    static func routingWelcomeChainSuperseded(intentID: String) {
        track(.routingWelcomeChainSuperseded, parameters: [
            "intent": intentID
        ])
    }

    /// Fires when a persisted group invite is re-emitted from `PendingInviteStore`
    /// (cold launch or foreground) after the transient intent was dropped by
    /// `resetTransients`. Confirms the fix rescues invites in production.
    /// Privacy-first: no payload.
    static func inviteReEmittedFromStore() {
        track(.inviteReEmittedFromStore)
    }

    /// Fires when a persisted group invite is purged by TTL (24h) without ever
    /// being presented. Privacy-first: no payload.
    static func invitePendingExpired() {
        track(.invitePendingExpired)
    }

    /// Reports orphan / malformed / pairing repair from `TransferPairReconcileService`.
    /// Privacy-first: no pairIDs ni TX identifiers, solo counts.
    static func cloudkitTransferOrphanRepaired(orphansCleared: Int, pairedCount: Int) {
        track(.cloudkitTransferOrphanRepaired, parameters: [
            "orphansCleared": String(orphansCleared),
            "pairedCount": String(pairedCount),
            "context": TransferReconcileContext.bootReconcile.rawValue
        ])
    }

    /// Reports a `transferPairID` shared by 3+ TXs (collision). NO auto-repair se aplica
    /// porque la heurística podría borrar data válida. Solo telemetry.
    static func cloudkitTransferCollisionDetected(count: Int) {
        track(.cloudkitTransferCollisionDetected, parameters: [
            "model": "TransactionItem",
            "count": String(count),
            "context": TransferReconcileContext.bootCollision.rawValue
        ])
    }
}
