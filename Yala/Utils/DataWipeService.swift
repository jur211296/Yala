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
            transaction.tags = []
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
            draft.tags = []
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
            budget.accounts = []
            budget.subcategories = []
            budget.tags = []
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
            favorite.tags = []
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

    // MARK: - Reset de preferencias de usuario
    private static func resetAllUserPreferences() {
        let defaults = UserDefaults.standard

        // --- Personalización ---
        defaults.removeObject(forKey: "defaultPeriod")          // Default: DetailPeriod.allTime.rawValue
        defaults.removeObject(forKey: "userTheme")              // Default: resolved by ThemeManager (liquidGlass for new users)
        defaults.removeObject(forKey: "translucentVariant")     // Default: TranslucentVariant.indigo.rawValue (0)
        defaults.removeObject(forKey: "colorfulIcons")          // Default: true
        defaults.removeObject(forKey: "firstWeekday")           // Default: 2 (Monday)
        defaults.removeObject(forKey: "showWidgetHints")        // Default: true
        defaults.removeObject(forKey: "defaultCurrencyCode")    // Default: "PEN"

        // --- Visualización ---
        defaults.removeObject(forKey: "showVariations")         // Default: true
        defaults.removeObject(forKey: "decimalPlaces")          // Default: 0
        defaults.removeObject(forKey: "currencyDisplayFormat")  // Default: "code"

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
        defaults.removeObject(forKey: "aiChatConsentAccepted")  // Default: false
        defaults.removeObject(forKey: "chatAssistantEnabled")   // Default: false
        defaults.removeObject(forKey: "chatFABVisible")         // Default: true
        defaults.removeObject(forKey: "financialMindset")          // Default: "cashFlow"

        // --- Orden de listas ---
        defaults.removeObject(forKey: "accountsSortOrderNames") // Default: ""
        defaults.removeObject(forKey: "tagsSortOrderNames")     // Default: ""

        // --- Configuración de widgets ---
        defaults.removeObject(forKey: "panel_widget_configs_v1") // Key real usada por WidgetConfigManager

        // --- Estado del servicio de tipos de cambio ---
        defaults.removeObject(forKey: "exchangeRate_lastHistoricalLoad")
        defaults.removeObject(forKey: "exchangeRate_lastTodayUpdate")

        // --- Preferencias de presupuestos ---
        defaults.removeObject(forKey: "budgets.hideInactive")   // Default: false
        defaults.removeObject(forKey: "budgetAlertsEnabled")    // Default: false

        // --- Onboarding ---
        defaults.removeObject(forKey: "hasCompletedOnboarding") // Default: false (triggers onboarding)
        defaults.removeObject(forKey: "onboardingMode")         // Default: .full (normal onboarding)
        defaults.removeObject(forKey: "sessionTimestamps")      // Default: [] (UserSegmentService sessions)
        defaults.removeObject(forKey: "secondaryCurrencies")    // Default: "" (no secondary currencies)

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
        ProTourManager.shared.reset()                                // Re-show pro tour

        // --- Setup Checklist ---
        SetupChecklistManager.shared.resetAll()

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
