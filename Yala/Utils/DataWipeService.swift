//
//  DataWipeService.swift
//  Yala
//
//  Servicio central para eliminar todos los datos del usuario
//  y resembrar la app a un estado inicial.
//

import Foundation
import SwiftData
import TipKit
import WidgetKit

// Clase de utilidad para operaciones de borrado masivo de datos de usuario.
// Marcada como @MainActor porque ModelContext debe usarse desde el hilo principal.
@MainActor
final class DataWipeService {

    // MARK: - Punto de entrada principal
    // Llama a esta función cuando quieras vaciar los datos del usuario.
    // 1. Elimina datos de todos los modelos relevantes.
    // 2. Resetea todas las preferencias de usuario a valores por defecto.
    // 3. Opcionalmente vuelve a lanzar la semilla inicial (categorías, etc.).
    // Note: reseedInitialData defaults to false - the UI should ask the user
    static func wipeAllUserData(
        in context: ModelContext,
        reseedInitialData: Bool = false,
        broadcastSignal: Bool = true
    ) throws {
        // ============================================================
        // PASO 0: Señalizar wipe a otros dispositivos via iCloud KV
        // ============================================================
        if broadcastSignal {
            PreferenceSyncService.shared.signalWipeInitiated()
        }

        // ============================================================
        // PASO 1: Borrar todos los datos de SwiftData
        // ============================================================
        // Orden de dependencias (de más dependiente a menos):
        // TransactionItem → Budget → FavoritePayment → ScheduledPayment →
        // Tag → ExchangeRate → Account → Subcategory → Category

        // 1.1 Limpiar relaciones many-to-many de TransactionItem y Tag
        let transactionDescriptor = FetchDescriptor<TransactionItem>()
        let allTransactions = try context.fetch(transactionDescriptor)
        for transaction in allTransactions {
            transaction.setTags(from: [])
        }

        let tagDescriptor = FetchDescriptor<Tag>()
        let allTags = try context.fetch(tagDescriptor)
        for tag in allTags {
            tag.transactions = []
            tag.favoritePayments = []
            tag.budgets = []
        }
        try context.save()

        // 1.1b Limpiar relaciones de InboxDraft y eliminar
        let inboxDraftDescriptor = FetchDescriptor<InboxDraft>()
        let allDrafts = try context.fetch(inboxDraftDescriptor)
        for draft in allDrafts {
            draft.setTags(from: [])
            draft.account = nil
            draft.subcategory = nil
            draft.approvedTransaction = nil
        }
        try context.save()
        for draft in allDrafts {
            context.delete(draft)
        }
        try context.save()

        // 1.1c Eliminar MerchantMemory (limpiar relaciones y eliminar)
        let merchantMemoryDescriptor = FetchDescriptor<MerchantMemory>()
        let allMerchantMemories = try context.fetch(merchantMemoryDescriptor)
        for memory in allMerchantMemories {
            memory.subcategory = nil
        }
        try context.save()
        for memory in allMerchantMemories {
            context.delete(memory)
        }
        try context.save()

        // 1.1d Eliminar notificaciones personalizadas y resetear default
        NotificationService.shared.deleteAllNotifications(context: context)

        // 1.2 Eliminar todas las transacciones
        for transaction in allTransactions {
            context.delete(transaction)
        }
        try context.save()

        // 1.3 Limpiar relaciones de Budget y eliminar
        let budgetDescriptor = FetchDescriptor<Budget>()
        let allBudgets = try context.fetch(budgetDescriptor)
        for budget in allBudgets {
            // SSOT: usa el helper único que mantiene M2M + CSV sincronizados.
            budget.setFilters(accounts: [], subcategories: [], tags: [])
        }
        try context.save()
        for budget in allBudgets {
            context.delete(budget)
        }
        try context.save()

        // 1.4 Limpiar relaciones de FavoritePayment y eliminar
        let favoriteDescriptor = FetchDescriptor<FavoritePayment>()
        let allFavorites = try context.fetch(favoriteDescriptor)
        for favorite in allFavorites {
            favorite.setTags(from: [])
        }
        try context.save()
        for favorite in allFavorites {
            context.delete(favorite)
        }
        try context.save()

        // 1.5 Eliminar todos los pagos programados
        let scheduledDescriptor = FetchDescriptor<ScheduledPayment>()
        let allScheduled = try context.fetch(scheduledDescriptor)
        for scheduled in allScheduled {
            context.delete(scheduled)
        }
        try context.save()

        // 1.6 Eliminar todos los tags
        let remainingTags = try context.fetch(tagDescriptor)
        for tag in remainingTags {
            context.delete(tag)
        }
        try context.save()

        // 1.7 Eliminar todos los tipos de cambio
        let exchangeDescriptor = FetchDescriptor<ExchangeRate>()
        let allExchangeRates = try context.fetch(exchangeDescriptor)
        for rate in allExchangeRates {
            context.delete(rate)
        }
        try context.save()

        // 1.8 Limpiar relaciones de Account y eliminar
        let accountDescriptor = FetchDescriptor<Account>()
        let allAccounts = try context.fetch(accountDescriptor)
        for account in allAccounts {
            account.budgets = []
        }
        try context.save()
        for account in allAccounts {
            context.delete(account)
        }
        try context.save()

        // 1.9 Limpiar relaciones de Subcategory y eliminar
        let subcategoryDescriptor = FetchDescriptor<Subcategory>()
        let allSubcategories = try context.fetch(subcategoryDescriptor)
        for subcategory in allSubcategories {
            subcategory.budgets = []
        }
        try context.save()
        for subcategory in allSubcategories {
            context.delete(subcategory)
        }
        try context.save()
        context.processPendingChanges()

        // 1.10 Eliminar todas las categorías
        let categoryDescriptor = FetchDescriptor<Category>()
        let allCategories = try context.fetch(categoryDescriptor)
        for category in allCategories {
            context.delete(category)
        }
        try context.save()
        context.processPendingChanges()

        // 1.11 Eliminar todos los CashFlowPlans (cascade → Lines → Overrides)
        let cashFlowPlanDescriptor = FetchDescriptor<CashFlowPlan>()
        let allCashFlowPlans = try context.fetch(cashFlowPlanDescriptor)
        for plan in allCashFlowPlans {
            context.delete(plan)
        }
        try context.save()
        context.processPendingChanges()

        // ============================================================
        // PASO 1.12: Limpiar archivo de imagen de perfil
        // ============================================================
        ProfileImageStorage.shared.delete()

        // ============================================================
        // PASO 2: Resetear todas las preferencias de usuario (UserDefaults)
        // ============================================================
        resetAllUserPreferences()

        // ============================================================
        // PASO 3: Limpiar cache de widgets + TipKit
        // ============================================================
        WidgetDataCache.clearCache()
        do {
            try Tips.resetDatastore()
        } catch {
            #if DEBUG
            print("DataWipeService: TipKit reset failed: \(error)")
            #endif
        }

        // ============================================================
        // PASO 4: Reseed de datos iniciales si corresponde
        // ============================================================
        if reseedInitialData {
            try reseedInitialAppState(in: context)
        }
    }

    // MARK: - Reset del boot-cleanup de cierre de sesión (H4)

    /// Reset a "recién instalada" SIN ModelContext — para el boot-cleanup del sign-out en `.cloud`
    /// (`SwiftDataConfiguration.performSignOutWipeIfArmed`), donde los datos mueren por borrado de
    /// ARCHIVOS del store, no por deletes de filas. Reusa el mismo reset de prefs/caches del wipe
    /// normal (onboarding, seeds, router, checklist, widgets, TipKit, imagen de perfil).
    /// Corre PRE-UI en el arranque: solo toca UserDefaults, archivos y singletons de estado.
    static func resetForSignOutWipe() {
        ProfileImageStorage.shared.delete()
        resetAllUserPreferences()
        WidgetDataCache.clearCache()
        do {
            try Tips.resetDatastore()
        } catch {
            #if DEBUG
            print("DataWipeService: TipKit reset failed: \(error)")
            #endif
        }
    }

    // MARK: - Reset de preferencias de usuario
    private static func resetAllUserPreferences() {
        // --- Routing state ---
        // Clear both the in-memory AppRouter queue AND the persistent
        // DeferredIntentBuffer. Without this, queued / deferred intents
        // survive the wipe and replay against the reseeded data.
        AppRouter.shared.resetAll()

        removeUserPreferenceKeys(from: .standard)

        ProTourManager.shared.reset()                                // Re-show pro tour

        // --- Setup Checklist ---
        SetupChecklistManager.shared.resetAll()

        // --- Espejos App Group (cross-process: widgets/intents) ---
        // Solo keys que llevan datos/preferencias de la CUENTA. `isProUser` NO se toca
        // (sigue a la suscripción del Apple ID de App Store del device; StoreKitManager
        // la re-deriva y re-escribe); `pendingControlAction` tampoco (transient, se
        // drena en cada activación y no lleva datos de cuenta).
        if let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
            appGroup.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)   // espejo del didSet de SessionState (widgets)
            appGroup.removeObject(forKey: "firstWeekday")                         // espejo de PreferenceSyncService (widgets)
            appGroup.removeObject(forKey: AppPreferences.Keys.lastUsedAccountID)  // shortcutID de una Account ya borrada
        }
    }

    /// Barrido de las keys de preferencias de usuario en `defaults`. Separado de
    /// `resetAllUserPreferences` para poder testearse con un `UserDefaults` aislado
    /// (el reset completo toca singletons que escriben en `.standard`).
    ///
    /// EXCLUSIONES deliberadas (auditoría 2026-07-14 — NO añadir sin razonar):
    /// - `lastKnownWipeTimestamp` — protege de reaccionar a la señal del propio wipe.
    /// - `groupsBetaUnlocked` — gate beta per-device (documentado en AppPreferences.Keys).
    /// - `isProUser` / `pro.upsell.*` / `pro.trial.*` / `review*` — siguen a la suscripción
    ///   y al pacing de monetización/review del Apple ID de App Store del DEVICE, no a la
    ///   cuenta Yala; resetearlos re-mostraría sheets one-shot al mismo suscriptor.
    /// - `hasMigratedToLiveBalance` / `biometricKeychainCleanedV1` — sentinels de migración
    ///   de datos LEGACY: post-wipe no existen datos legacy que migrar.
    /// - keys `cloudSync.*` / storageMode / arms de wipe — infra del propio sign-out/wipe,
    ///   las gestiona StorageModePersistence en el orden kill-safe del boot. JAMÁS aquí.
    ///   (El sentinel `cloudSync.prefsCutoverDrained.*` lo purga `performSignOutWipeIfArmed`
    ///   tras este reset, #37 — no re-añadirlo aquí.)
    /// - `groupPrefs_*` y estado de Grupos — el dominio Grupos sobrevive el wipe por diseño
    ///   (store propio, CKSyncEngine); sus prefs se limpian en leaveGroup/deleteGroup.
    /// - override de idioma (App Group de LanguageManager) — preferencia del DEVICE
    ///   compartida con widgets/extensiones, no de la cuenta.
    static func removeUserPreferenceKeys(from defaults: UserDefaults) {
        // --- Personalización ---
        defaults.removeObject(forKey: "defaultPeriod")          // Default: DetailPeriod.allTime.rawValue
        defaults.removeObject(forKey: "userTheme")              // Default: resolved by ThemeManager (liquidGlass for new users)
        defaults.removeObject(forKey: "translucentVariant")     // Default: TranslucentVariant.indigo.rawValue (0)
        defaults.removeObject(forKey: "colorfulIcons")          // Default: true
        defaults.removeObject(forKey: "firstWeekday")           // Default: 2 (Monday)
        defaults.removeObject(forKey: "showWidgetHints")        // Default: true
        defaults.removeObject(forKey: "defaultCurrencyCode")    // Default: "PEN"
        defaults.removeObject(forKey: AppPreferences.Keys.tabConfigJSON)  // Layout custom de tabs ("tabBarConfiguration")
        defaults.removeObject(forKey: "customPeriodStart")      // Rango del período .custom (SessionState)
        defaults.removeObject(forKey: "customPeriodEnd")

        // --- Visualización ---
        defaults.removeObject(forKey: "showVariations")         // Default: true
        defaults.removeObject(forKey: "decimalPlaces")          // Default: 2
        defaults.removeObject(forKey: "currencyDisplayFormat")  // Default: "symbol"
        defaults.removeObject(forKey: "useRoundedAmounts")      // Legacy pre-decimalPlaces: YalaFormatterStatic cae a esta key si decimalPlaces falta → resucitaría el redondeo de la cuenta anterior
        defaults.removeObject(forKey: AppPreferences.Keys.averageLineMode)  // Default: 1
        defaults.removeObject(forKey: AppPreferences.Keys.sankeyLabelMode)  // Default: .amount

        // --- Perfil de usuario ---
        defaults.removeObject(forKey: "userName")               // Default: "Usuario"
        defaults.removeObject(forKey: "userAlias")              // Default: ""
        defaults.removeObject(forKey: "userProfileImageData")   // Default: nil
        defaults.removeObject(forKey: "userProfileIcon")        // Default: "" (sin emoji)

        // --- Features de entrada ---
        defaults.removeObject(forKey: "voiceInputEnabled")      // Default: false
        defaults.removeObject(forKey: "voiceLanguage")          // Default: VoiceLanguage.system.rawValue
        defaults.removeObject(forKey: "imageInputEnabled")      // Default: false
        defaults.removeObject(forKey: "aiDataConsentAccepted") // Default: false
        defaults.removeObject(forKey: "aiInsightsConsentAccepted") // Default: false
        defaults.removeObject(forKey: "aiInsightsEnabled")         // Default: false
        defaults.removeObject(forKey: "aiInsightsMigratedV1")      // Sentinel de migración one-shot
        defaults.removeObject(forKey: "aiTogglesRemovedV2")        // Sentinel remove-ai-toggles refactor
        defaults.removeObject(forKey: "aiChatConsentAccepted")  // Default: false
        defaults.removeObject(forKey: "chatAssistantEnabled")   // Default: false
        defaults.removeObject(forKey: "chatFABVisible")         // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.cashFlowAIEnabled)  // Default: false
        defaults.removeObject(forKey: AppPreferences.Keys.insightsTone)       // Default: .normal
        defaults.removeObject(forKey: AppPreferences.Keys.insightsFocus)      // Default: .balanced
        defaults.removeObject(forKey: AppPreferences.Keys.autoFocusField)     // Default: .none
        defaults.removeObject(forKey: "financialMindset")          // Default: "cashFlow"
        // PAR de financialMindset: el pre-fill de OnboardingView exige AMBAS keys presentes —
        // dejar esta viva re-activaba la selección "Solo gastos" de la cuenta anterior
        // (hallazgo device 2026-07-14, HALLAZGO 3 del guion SIGNOUT-WELCOME).
        defaults.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)    // Default: false

        // --- Rate-limit y señales del chat ---
        defaults.removeObject(forKey: "chatQuestionsToday")     // Contador diario del rate-limit
        defaults.removeObject(forKey: "chatLastQuestionDate")
        defaults.removeObject(forKey: "chat_draft_saved_signal") // Señal draft→TX de la sesión anterior

        // --- Orden de listas ---
        defaults.removeObject(forKey: "accountsSortOrderNames") // Default: ""
        defaults.removeObject(forKey: "tagsSortOrderNames")     // Default: ""

        // --- Configuración de widgets ---
        defaults.removeObject(forKey: "panel_widget_configs_v1") // Key real usada por WidgetConfigManager
        defaults.removeObject(forKey: "panelHeroAIMessage_v1")   // Cache 24h del mensaje IA del hero

        // --- Panel 2.0 (orden/ocultos por sección + hero KPIs) ---
        defaults.removeObject(forKey: AppPreferences.Keys.panelTendenciasOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelTendenciasHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelDistribucionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelDistribucionHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelPlanificacionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelPlanificacionHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelSectionsHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelSectionsOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.moreSectionOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelAccountsCollapsed)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsOrder)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsHidden)
        defaults.removeObject(forKey: AppPreferences.Keys.panelHeroKPIsCustomized)
        // Sentinel (como seedCategoriesExecuted): re-permite el seed fresh de
        // PanelPreferencesMigration para el próximo usuario.
        defaults.removeObject(forKey: AppPreferences.Keys.panelPrefsMigratedV2)

        // --- Estado del servicio de tipos de cambio ---
        defaults.removeObject(forKey: "exchangeRate_lastHistoricalLoad")
        defaults.removeObject(forKey: "exchangeRate_lastTodayUpdate")

        // --- Preferencias de presupuestos ---
        defaults.removeObject(forKey: "budgets.hideInactive")   // Default: false
        defaults.removeObject(forKey: "budgetAlertsEnabled")    // Default: false

        // --- Grupos (toggles personales de visibilidad/bridge) ---
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupTransactionsInFeed)   // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupsInPanelTotal)        // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.includeGroupTransactionsInStats)  // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.bridgeGroupExpensesToPersonalAccounts)  // Default: true
        defaults.removeObject(forKey: AppPreferences.Keys.hasShownGroupsOnboarding)
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt)

        // --- Sync (toggle de usuario en iCloudSyncSettingsView) ---
        defaults.removeObject(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled)  // Default: false (hook activo)

        // --- Visibilidad de secciones de Insights ---
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowQuickStats)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowPendingPayments)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowSubscriptions)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowBudgetsAtRisk)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowWeekday)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowNature)
        defaults.removeObject(forKey: AppPreferences.Keys.insightsShowTexts)

        // --- Onboarding ---
        defaults.removeObject(forKey: "hasCompletedOnboarding") // Default: false (triggers onboarding)
        defaults.removeObject(forKey: "hasShownWelcomeChooser") // A4: tras wipe vuelve a mostrarse el chooser
        defaults.removeObject(forKey: "hasShownYalaAIOnboarding") // Tras wipe vuelve a mostrarse el onboarding del chat
        defaults.removeObject(forKey: "onboardingMode")         // Default: .full (normal onboarding)
        defaults.removeObject(forKey: "sessionTimestamps")      // Default: [] (UserSegmentService sessions)
        defaults.removeObject(forKey: "secondaryCurrencies")    // Default: "" (no secondary currencies)
        defaults.removeObject(forKey: "needsPostOnboardingTrial") // One-shot del trial post-onboarding

        // --- Cross-device wipe coordination ---
        // DO NOT clear lastKnownWipeTimestamp — it protects against reacting to our own wipe signal
        defaults.removeObject(forKey: "lastKnownOnboardingTimestamp")  // Allow re-processing remote onboarding

        // --- What's New ---
        defaults.removeObject(forKey: "lastSeenAppVersion")       // Re-show What's New post-wipe

        // --- App Update ---
        defaults.removeObject(forKey: "appUpdate.latestVersion")  // Clear cached App Store version
        defaults.removeObject(forKey: "appUpdate.lastChecked")    // Force re-check after wipe

        // --- Coach mark tours ---
        defaults.removeObject(forKey: "hasSeenSettingsTour")      // Re-show settings tour
        defaults.removeObject(forKey: "hasSeenCashFlowSetupTour")  // Re-show cash flow setup tour
        defaults.removeObject(forKey: "hasSeenCashFlowTableTour")  // Re-show cash flow table tour
        defaults.removeObject(forKey: "hasSeenChatContextHint")     // Re-show chat context hint
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenTodayFXCoachMark)
        defaults.removeObject(forKey: AppPreferences.Keys.showSiriTip)
        defaults.removeObject(forKey: "hasSeenNotificationPrimer")  // Primer de notifs (NewTransactionViewModel)

        // --- Contadores/señales derivados de los datos borrados ---
        defaults.removeObject(forKey: "transactionsSavedCount")   // Alimenta primer/review/milestones
        defaults.removeObject(forKey: "pro.milestone.lastShown")  // Derivado de transactionsSavedCount — sin reset, la cuenta siguiente no ve milestones hasta superar el conteo anterior
        defaults.removeObject(forKey: "hasExportedData")          // Señal de segmento (UserSegmentService)
        defaults.removeObject(forKey: "processedInboxDraftSignatures")  // Firmas de drafts ya borrados
        defaults.removeObject(forKey: "lastSplitType")            // Memoria del split del formulario de TX
        defaults.removeObject(forKey: "lastSplitPercentage")

        // Persistencia día calendario del chat + cache diario de sugerencias LLM
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("chat_session_") || key.hasPrefix("chat_suggestions_") {
            defaults.removeObject(forKey: key)
        }

        // --- Contextual Guides ---
        let guideIDs = ["panel", "trends", "categories", "records", "budgets", "scheduled",
                        "accounts", "transaction", "comparative", "cashflow", "insights", "inbox",
                        "budgetEditor", "scheduledEditor"]
        for guideID in guideIDs {
            defaults.removeObject(forKey: "guide.\(guideID).dismissed")
        }

        // --- Seed guards ---
        defaults.removeObject(forKey: "seedCategoriesExecuted") // Allow re-seed after wipe
        defaults.removeObject(forKey: "notificationsSeeded")    // Allow re-seed after wipe
        defaults.removeObject(forKey: "devSeedDataExecuted")    // DEV — simetría con seedCategoriesExecuted

        // --- AppEntity shortcutID / CSV mirror migration sentinels ---
        // Re-correr migración contra entidades recién sembradas.
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsMigratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsRegeneratedV3)
        defaults.removeObject(forKey: AppPreferences.Keys.appEntityShortcutIDsBackfillAttemptsV3)
        AppPreferences.Keys.LegacyKeys.v2MigrationSentinels.forEach {
            defaults.removeObject(forKey: $0)
        }

        // --- Legacy (compatibilidad) ---
        defaults.removeObject(forKey: "preferredCurrency")      // Reemplazado por defaultCurrencyCode

        // Forzar sincronización inmediata
        defaults.synchronize()
    }

    // MARK: - Reseed de estado inicial
    // Encapsula aquí la lógica para volver al estado "recien instalada".
    private static func reseedInitialAppState(in context: ModelContext) throws {
        // Semilla inicial de categorías y subcategorías.
        // La función es idempotente: si ya existen categorías, no hace nada.
        // Como acabamos de borrar todo, SIEMPRE sembrará.
        seedCategoriesIfNeeded(in: context)

        // Note: Notifications are NOT seeded here.
        // They are created during onboarding (step 6) based on user selection.
        // For existing users upgrading, YalaApp.swift handles the seed.
    }
}
