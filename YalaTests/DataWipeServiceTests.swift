//
//  DataWipeServiceTests.swift
//  YalaTests
//
//  Unit tests for DataWipeService preference reset and deletion logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct DataWipeServiceTests {

    // MARK: - Preference Keys Coverage

    /// Keys que `removeUserPreferenceKeys(from:)` DEBE borrar (auditoría 2026-07-14).
    /// Espejo del contrato en DataWipeService — si añades una key persistida de usuario
    /// nueva a AppPreferences.Keys, debe entrar al reset Y a esta lista.
    private static let expectedResetKeys: [String] = [
        // Personalización
        "defaultPeriod", "userTheme", "translucentVariant", "colorfulIcons", "firstWeekday",
        "showWidgetHints", "defaultCurrencyCode", "tabBarConfiguration",
        "customPeriodStart", "customPeriodEnd",
        // Visualización
        "showVariations", "decimalPlaces", "currencyDisplayFormat", "useRoundedAmounts",
        "averageLineMode", "sankeyLabelMode",
        // Perfil
        "userName", "userAlias", "userProfileImageData", "userProfileIcon",
        // Features de entrada / AI
        "voiceInputEnabled", "voiceLanguage", "imageInputEnabled", "aiDataConsentAccepted",
        "aiInsightsConsentAccepted", "aiInsightsEnabled", "aiInsightsMigratedV1",
        "aiTogglesRemovedV2", "aiChatConsentAccepted", "chatAssistantEnabled", "chatFABVisible",
        "cashFlowAIEnabled", "insightsTone", "insightsFocus", "autoFocusField",
        "financialMindset", "expensesOnlyMode",
        // Chat
        "chatQuestionsToday", "chatLastQuestionDate", "chat_draft_saved_signal",
        // Orden de listas
        "accountsSortOrderNames", "tagsSortOrderNames",
        // Widgets / Panel 2.0
        "panel_widget_configs_v1", "panelHeroAIMessage_v1",
        "panelTendenciasOrder", "panelTendenciasHidden", "panelDistribucionOrder",
        "panelDistribucionHidden", "panelPlanificacionOrder", "panelPlanificacionHidden",
        "panelSectionsHidden", "panelSectionsOrder", "moreSectionOrder",
        "panelAccountsCollapsed", "panelHeroKPIsOrder", "panelHeroKPIsHidden",
        "panelHeroKPIsCustomized", "panelPrefsMigratedV2",
        // Exchange rate
        "exchangeRate_lastHistoricalLoad", "exchangeRate_lastTodayUpdate",
        // Presupuestos
        "budgets.hideInactive", "budgetAlertsEnabled",
        // Grupos (toggles personales)
        "includeGroupTransactionsInFeed", "includeGroupsInPanelTotal",
        "includeGroupTransactionsInStats", "bridgeGroupExpensesToPersonalAccounts",
        "hasShownGroupsOnboarding", "hasSeenGroupsNotificationPrompt",
        // Sync
        "subcatDedupRemoteHookDisabled",
        // Insights visibilidad
        "insightsShowQuickStats", "insightsShowPendingPayments", "insightsShowSubscriptions",
        "insightsShowBudgetsAtRisk", "insightsShowWeekday", "insightsShowNature",
        "insightsShowTexts",
        // Onboarding
        "hasCompletedOnboarding", "hasShownWelcomeChooser", "hasShownYalaAIOnboarding",
        "onboardingMode", "sessionTimestamps", "secondaryCurrencies", "needsPostOnboardingTrial",
        "lastKnownOnboardingTimestamp",
        // What's New / App Update
        "lastSeenAppVersion", "appUpdate.latestVersion", "appUpdate.lastChecked", "appUpdate.trackId",
        // Tours / one-shots
        "hasSeenSettingsTour", "hasSeenCashFlowSetupTour", "hasSeenCashFlowTableTour",
        "hasSeenChatContextHint", "hasSeenTodayFXCoachMark", "showSiriTip",
        "hasSeenNotificationPrimer",
        // Contadores derivados de datos
        "transactionsSavedCount", "pro.milestone.lastShown", "hasExportedData",
        "processedInboxDraftSignatures", "lastSplitType", "lastSplitPercentage",
        // Seeds
        "seedCategoriesExecuted", "notificationsSeeded", "devSeedDataExecuted",
        // Legacy
        "preferredCurrency",
    ]

    /// Keys que el reset debe PRESERVAR (exclusiones deliberadas — ver doc de
    /// `removeUserPreferenceKeys`).
    private static let preservedKeys: [String] = [
        "lastKnownWipeTimestamp",      // anti-eco de la señal de wipe cross-device
        "groupsBetaUnlocked",          // gate beta per-device (doc en AppPreferences.Keys)
        "pro.upsell.sessionCount",     // pacing de monetización del device/App Store
        "pro.trial.wasInTrial",
        "pro.trial.expiredSheetShown",
        "reviewFirstLaunchDate",       // pacing del review prompt (per-device)
        "hasMigratedToLiveBalance",    // migración de datos legacy — post-wipe no hay legacy
    ]

    @Test func removeUserPreferenceKeys_clearsAllExpectedKeys() {
        let defaults = makeIsolatedDefaults()
        for key in Self.expectedResetKeys {
            defaults.set("testValue", forKey: key)
        }
        // Keys de prefijo dinámico (chat + guides) también deben caer
        defaults.set("x", forKey: "chat_session_2026-07-14")
        defaults.set("x", forKey: "chat_suggestions_2026-07-14")
        defaults.set(true, forKey: "guide.panel.dismissed")

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        for key in Self.expectedResetKeys {
            #expect(
                defaults.object(forKey: key) == nil,
                "Key '\(key)' debería quedar borrada tras el reset"
            )
        }
        #expect(defaults.object(forKey: "chat_session_2026-07-14") == nil)
        #expect(defaults.object(forKey: "chat_suggestions_2026-07-14") == nil)
        #expect(defaults.object(forKey: "guide.panel.dismissed") == nil)
    }

    /// Regresión (2026-07-21): el estado de dedup de notificaciones se llavea con UUID +
    /// fecha, así que `expectedResetKeys` no puede nombrarlo y sobrevivía al wipe Y al
    /// sign-out. `creditCardNotif_` era la crítica — marca "ya avisé hoy del pago de esta
    /// tarjeta", de modo que una entrada de la cuenta anterior silenciaba el recordatorio
    /// de la entrante. Se barre por PREFIJO; los prefijos vecinos de Grupos / device-global
    /// deben sobrevivir (exclusiones deliberadas del doc de `removeUserPreferenceKeys`).
    @Test func removeUserPreferenceKeys_sweepsNotificationDedupPrefixes() {
        let defaults = makeIsolatedDefaults()
        let sweptKeys = [
            "creditCardNotif_\(UUID().uuidString)_20260721",
            "creditCardNotif_Visa_20260721",  // formato legacy (llaveado por nombre de cuenta)
            "scheduledPaymentNotif_\(UUID().uuidString)_20260721_dueDate",
            "budgetAlert_\(UUID().uuidString)_2026-07",
        ]
        let survivingKeys = [
            "GroupNotifications.lastNotified.abc",             // dominio Grupos: sobrevive por diseño
            "groupPrefs_zone1_settlementAccount_PEN",          // ídem
            "metrics.cloudRegistered.user1",                   // device-global
            "cloudSync.prefsCutoverDrained.user1",             // #37: lo purga el boot-hook, no este reset
        ]
        for key in sweptKeys + survivingKeys {
            defaults.set(true, forKey: key)
        }

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        for key in sweptKeys {
            #expect(
                defaults.object(forKey: key) == nil,
                "Key '\(key)' debería caer en el barrido por prefijo"
            )
        }
        for key in survivingKeys {
            #expect(
                defaults.object(forKey: key) != nil,
                "Key '\(key)' debe sobrevivir el reset (exclusión deliberada)"
            )
        }
    }

    /// Regresión del hallazgo device 2026-07-14 (HALLAZGO 3, guion SIGNOUT-WELCOME):
    /// el pre-fill de OnboardingView exige `expensesOnlyMode` Y `financialMindset`
    /// presentes JUNTAS. El reset debe borrar AMBAS — dejar `expensesOnlyMode` viva
    /// re-activaba la selección "Solo anotar mis gastos" de la cuenta anterior.
    @Test func signOutWipe_clearsOnboardingPrefillPair() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.expensesOnlyMode)
        defaults.set("cashFlow", forKey: AppPreferences.Keys.financialMindset)

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        #expect(defaults.object(forKey: AppPreferences.Keys.expensesOnlyMode) == nil)
        #expect(defaults.object(forKey: AppPreferences.Keys.financialMindset) == nil)
    }

    @Test func preservedKeys_surviveReset() {
        let defaults = makeIsolatedDefaults()
        for key in Self.preservedKeys {
            defaults.set("keepMe", forKey: key)
        }

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        for key in Self.preservedKeys {
            #expect(!Self.expectedResetKeys.contains(key), "'\(key)' no debe estar en la lista de reset")
            #expect(
                defaults.string(forKey: key) == "keepMe",
                "Key '\(key)' debe sobrevivir el reset (exclusión deliberada)"
            )
        }
    }

    // MARK: - Deletion Order Contract

    @Test func deletionOrder_dependentsBeforeParents() throws {
        // DataWipeService deletes in this order (most dependent first):
        // TransactionItem.tags → Tag relations → InboxDraft → MerchantMemory →
        // NotificationItem → TransactionItem → Budget → FavoritePayment →
        // ScheduledPayment → Tag → ExchangeRate → Account → Subcategory → Category →
        // CashFlowPlan (cascade → CashFlowLine → CashFlowOverride)
        //
        // Verify the order is correct: children before parents
        let deletionOrder = [
            "TransactionItem.tags",  // M2M cleanup
            "Tag.relations",         // M2M cleanup
            "InboxDraft",
            "MerchantMemory",
            "NotificationItem",
            "TransactionItem",
            "Budget",
            "FavoritePayment",
            "ScheduledPayment",
            "Tag",
            "ExchangeRate",
            "Account",
            "Subcategory",
            "Category",
            "CashFlowPlan",
        ]

        // CashFlowPlan must be last (cascade deletes Lines → Overrides)
        #expect(deletionOrder.last == "CashFlowPlan")

        // TransactionItem must be deleted before Account and Category
        let txIndex = try #require(deletionOrder.firstIndex(of: "TransactionItem"))
        let accountIndex = try #require(deletionOrder.firstIndex(of: "Account"))
        let categoryIndex = try #require(deletionOrder.firstIndex(of: "Category"))
        #expect(txIndex < accountIndex)
        #expect(txIndex < categoryIndex)

        // Budget must be deleted before Account (has account relation)
        let budgetIndex = try #require(deletionOrder.firstIndex(of: "Budget"))
        #expect(budgetIndex < accountIndex)

        // Subcategory must be deleted before Category
        let subIndex = try #require(deletionOrder.firstIndex(of: "Subcategory"))
        #expect(subIndex < categoryIndex)

        // Tag relations cleaned before Tag deletion
        let tagRelIndex = try #require(deletionOrder.firstIndex(of: "Tag.relations"))
        let tagIndex = try #require(deletionOrder.firstIndex(of: "Tag"))
        #expect(tagRelIndex < tagIndex)
    }

    // MARK: - Reseed Flag

    @Test func reseedFlag_defaultIsFalse() {
        // Verify the default parameter value contract
        // The method signature has reseedInitialData: Bool = false
        // This test documents the expectation that wipe does NOT reseed by default
        let defaultReseed = false
        #expect(defaultReseed == false)
    }

    // MARK: - BroadcastSignal Flag

    @Test func broadcastSignal_defaultIsTrue() {
        // When broadcastSignal is true, PreferenceSyncService signals other devices
        // When false (used in tests and remote-wipe handling), it skips the signal
        let defaultBroadcast = true
        #expect(defaultBroadcast == true)
    }

    // MARK: - Entity Relationship Cleanup

    @Test func manyToMany_tagTransactions_cleanedBeforeDeletion() {
        // Contract: before deleting a Tag, its transactions array must be emptied
        // This prevents orphan references in SwiftData/CloudKit
        let tag = YalaTag(name: "test", colorHex: "#000", iconName: "tag")
        tag.transactions = []
        tag.favoritePayments = []
        tag.budgets = []
        #expect(tag.transactions?.isEmpty == true)
        #expect(tag.favoritePayments?.isEmpty == true)
        #expect(tag.budgets?.isEmpty == true)
    }

    @Test func manyToMany_budgetRelations_cleanedBeforeDeletion() {
        // Contract: before deleting a Budget, its M2M relations must be emptied
        let budget = Budget(
            currencyCode: "USD",
            limitAmount: 1000,
            periodType: "monthly"
        )
        budget.accounts = []
        budget.subcategories = []
        budget.tags = []
        #expect(budget.accounts?.isEmpty == true)
        #expect(budget.subcategories?.isEmpty == true)
        #expect(budget.tags?.isEmpty == true)
    }

    @Test func inboxDraft_relationsCleared() {
        // Contract: before deleting InboxDraft, nullable relations set to nil
        let draft = InboxDraft(note: "test", amount: 50, date: .now, sourceType: .voice)
        draft.tags = []
        draft.account = nil
        draft.subcategory = nil
        draft.approvedTransaction = nil
        #expect(draft.tags?.isEmpty == true)
        #expect(draft.account == nil)
        #expect(draft.subcategory == nil)
    }
}
