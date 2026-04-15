//
//  AppPreferencesTests.swift
//  YalaTests
//
//  Tests para AppPreferences — verifica get/set tipados, persistencia en UserDefaults,
//  diferencial ante notificación sin cambio real, y ausencia de retain cycle con observers.
//
//  Cada test usa un `UserDefaults(suiteName:)` aislado con UUID para evitar contaminación
//  cruzada entre tests. No se verifica el path iCloud (PreferenceSyncService.shared) —
//  los tests usan el singleton real pero el efecto de interés es el local UserDefaults.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct AppPreferencesTests {

    // MARK: - Helpers

    /// Crea un UserDefaults suite aislado único por test.
    private static func makeSuite() -> UserDefaults {
        let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Init — load defaults

    @Test func init_fallsBackToBuiltinDefaults_whenKeyAbsent() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.defaultCurrencyCode == .pen)
        #expect(prefs.userName == "Usuario")
        #expect(prefs.colorfulIcons == true)
        #expect(prefs.showVariations == true)
        #expect(prefs.voiceLanguage == .system)
        #expect(prefs.insightsTone == .normal)
        #expect(prefs.insightsFocus == .balanced)
        #expect(prefs.voiceInputEnabled == false)
        #expect(prefs.imageInputEnabled == false)
        #expect(prefs.hasCompletedOnboarding == false)
        #expect(prefs.secondaryCurrencies == [])
        #expect(prefs.accountsSortOrderNames == [])
        #expect(prefs.currencyDisplayFormat == .code)
    }

    @Test func init_loadsFromUserDefaults_whenKeyPresent() {
        let defaults = Self.makeSuite()
        defaults.set("USD", forKey: AppPreferences.Keys.defaultCurrencyCode)
        defaults.set("Ada", forKey: AppPreferences.Keys.userName)
        defaults.set(false, forKey: AppPreferences.Keys.colorfulIcons)
        defaults.set(2, forKey: AppPreferences.Keys.decimalPlaces)
        defaults.set("symbol", forKey: AppPreferences.Keys.currencyDisplayFormat)
        defaults.set("USD,EUR,GBP", forKey: AppPreferences.Keys.secondaryCurrencies)
        defaults.set("es", forKey: AppPreferences.Keys.voiceLanguage)
        defaults.set("sarcastic", forKey: AppPreferences.Keys.insightsTone)
        defaults.set("saver", forKey: AppPreferences.Keys.insightsFocus)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.defaultCurrencyCode == .usd)
        #expect(prefs.userName == "Ada")
        #expect(prefs.colorfulIcons == false)
        #expect(prefs.decimalPlaces == 2)
        #expect(prefs.currencyDisplayFormat == .symbol)
        #expect(prefs.secondaryCurrencies == ["USD", "EUR", "GBP"])
        #expect(prefs.voiceLanguage == .spanish)
        #expect(prefs.insightsTone == .sarcastic)
        #expect(prefs.insightsFocus == .saver)
        #expect(prefs.hasCompletedOnboarding == true)
    }

    // MARK: - Setters — persistence

    @Test func set_defaultCurrencyCode_persistsToUserDefaults() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.defaultCurrencyCode = .eur

        #expect(defaults.string(forKey: AppPreferences.Keys.defaultCurrencyCode) == "EUR")
    }

    @Test func set_userName_persistsToUserDefaults() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.userName = "Turing"

        #expect(defaults.string(forKey: AppPreferences.Keys.userName) == "Turing")
    }

    @Test func set_secondaryCurrencies_roundTripsArrayViaCommaSeparation() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.secondaryCurrencies = ["USD", "EUR", "GBP"]

        #expect(defaults.string(forKey: AppPreferences.Keys.secondaryCurrencies) == "USD,EUR,GBP")

        // Reload and verify round-trip
        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.secondaryCurrencies == ["USD", "EUR", "GBP"])
    }

    @Test func set_accountsSortOrderNames_roundTripsArrayViaPipeSeparation() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.accountsSortOrderNames = ["Cash", "Bank", "Credit"]

        #expect(defaults.string(forKey: AppPreferences.Keys.accountsSortOrderNames) == "Cash|Bank|Credit")

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.accountsSortOrderNames == ["Cash", "Bank", "Credit"])
    }

    /// Nombres con comas (p.ej. "Savings, USD") no se colisionan con el separador pipe.
    @Test func set_accountsSortOrderNames_preservesNamesWithCommas() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.accountsSortOrderNames = ["Savings, USD", "Main", "Credit, Visa"]

        #expect(defaults.string(forKey: AppPreferences.Keys.accountsSortOrderNames) == "Savings, USD|Main|Credit, Visa")

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.accountsSortOrderNames == ["Savings, USD", "Main", "Credit, Visa"])
    }

    @Test func set_currencyDisplayFormat_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.currencyDisplayFormat = .symbol

        #expect(defaults.string(forKey: AppPreferences.Keys.currencyDisplayFormat) == "symbol")
    }

    @Test func set_voiceLanguage_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.voiceLanguage = .english

        #expect(defaults.string(forKey: AppPreferences.Keys.voiceLanguage) == "en")
    }

    @Test func set_insightsTone_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.insightsTone = .considerate

        #expect(defaults.string(forKey: AppPreferences.Keys.insightsTone) == "considerate")
    }

    @Test func set_insightsFocus_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.insightsFocus = .cautious

        #expect(defaults.string(forKey: AppPreferences.Keys.insightsFocus) == "cautious")
    }

    @Test func set_defaultPeriod_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.defaultPeriod = .thisWeek

        #expect(defaults.string(forKey: AppPreferences.Keys.defaultPeriod) == "thisWeek")
    }

    // MARK: - Setters — round-trip for all booleans

    @Test func set_allBooleans_persistAndReload() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.colorfulIcons = false
        prefs.showVariations = false
        prefs.showWidgetHints = false
        prefs.voiceInputEnabled = true
        prefs.imageInputEnabled = true
        prefs.aiDataConsentAccepted = true
        prefs.aiInsightsConsentAccepted = true
        prefs.aiChatConsentAccepted = true
        prefs.chatAssistantEnabled = true
        prefs.chatFABVisible = false
        prefs.cashFlowAIEnabled = true
        prefs.budgetsHideInactive = true
        prefs.budgetAlertsEnabled = true
        prefs.showSiriTip = false
        prefs.hasCompletedOnboarding = true
        prefs.expensesOnlyMode = true
        prefs.hasSeenSettingsTour = true
        prefs.hasSeenCashFlowSetupTour = true
        prefs.hasSeenCashFlowTableTour = true
        prefs.hasSeenGroupsNotificationPrompt = true
        prefs.insightsShowQuickStats = false
        prefs.insightsShowPendingPayments = false
        prefs.insightsShowSubscriptions = false
        prefs.insightsShowBudgetsAtRisk = false
        prefs.insightsShowWeekday = false
        prefs.insightsShowNature = false
        prefs.insightsShowTexts = false

        // Reload and verify everything persisted
        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.colorfulIcons == false)
        #expect(reloaded.showVariations == false)
        #expect(reloaded.showWidgetHints == false)
        #expect(reloaded.voiceInputEnabled == true)
        #expect(reloaded.imageInputEnabled == true)
        #expect(reloaded.aiDataConsentAccepted == true)
        #expect(reloaded.aiInsightsConsentAccepted == true)
        #expect(reloaded.aiChatConsentAccepted == true)
        #expect(reloaded.chatAssistantEnabled == true)
        #expect(reloaded.chatFABVisible == false)
        #expect(reloaded.cashFlowAIEnabled == true)
        #expect(reloaded.budgetsHideInactive == true)
        #expect(reloaded.budgetAlertsEnabled == true)
        #expect(reloaded.showSiriTip == false)
        #expect(reloaded.hasCompletedOnboarding == true)
        #expect(reloaded.expensesOnlyMode == true)
        #expect(reloaded.hasSeenSettingsTour == true)
        #expect(reloaded.hasSeenCashFlowSetupTour == true)
        #expect(reloaded.hasSeenCashFlowTableTour == true)
        #expect(reloaded.hasSeenGroupsNotificationPrompt == true)
        #expect(reloaded.insightsShowQuickStats == false)
        #expect(reloaded.insightsShowPendingPayments == false)
        #expect(reloaded.insightsShowSubscriptions == false)
        #expect(reloaded.insightsShowBudgetsAtRisk == false)
        #expect(reloaded.insightsShowWeekday == false)
        #expect(reloaded.insightsShowNature == false)
        #expect(reloaded.insightsShowTexts == false)
    }

    @Test func set_allIntegers_persistAndReload() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.decimalPlaces = 4
        prefs.firstWeekday = 1  // Sunday
        prefs.averageLineMode = 2

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.decimalPlaces == 4)
        #expect(reloaded.firstWeekday == 1)
        #expect(reloaded.averageLineMode == 2)
    }

    @Test func set_allStrings_persistAndReload() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.userName = "Lovelace"
        prefs.userAlias = "Ada"
        prefs.userProfileIcon = "star.fill"
        prefs.tabConfigJSON = "{\"version\":1}"
        prefs.autoFocusField = "amount"
        prefs.lastSeenAppVersion = "2.0.0"

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.userName == "Lovelace")
        #expect(reloaded.userAlias == "Ada")
        #expect(reloaded.userProfileIcon == "star.fill")
        #expect(reloaded.tabConfigJSON == "{\"version\":1}")
        #expect(reloaded.autoFocusField == "amount")
        #expect(reloaded.lastSeenAppVersion == "2.0.0")
    }

    // MARK: - Diferencial — observer no muta props si valor no cambió

    @Test func notification_propagatesExternalChange() async {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.userName == "Usuario")

        // Simulate external change (other process / @AppStorage legacy writes directly)
        defaults.set("Babbage", forKey: AppPreferences.Keys.userName)

        // Post the notification manually (UserDefaults suite doesn't always auto-post)
        NotificationCenter.default.post(
            name: UserDefaults.didChangeNotification,
            object: defaults
        )

        // Observer hops to MainActor via Task — yield so it completes
        try? await Task.sleep(for: .milliseconds(50))

        #expect(prefs.userName == "Babbage")
    }

    @Test func notification_diferentialSkipsRefreshWhenNoRealChange() async {
        let defaults = Self.makeSuite()
        defaults.set("USD", forKey: AppPreferences.Keys.defaultCurrencyCode)

        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.defaultCurrencyCode == .usd)

        // Post notification without changing anything
        NotificationCenter.default.post(
            name: UserDefaults.didChangeNotification,
            object: defaults
        )
        try? await Task.sleep(for: .milliseconds(50))

        // Value unchanged (we can't directly observe re-render, but verify no side effect
        // — the guard in didSet prevents loop + persist back).
        #expect(prefs.defaultCurrencyCode == .usd)
        #expect(defaults.string(forKey: AppPreferences.Keys.defaultCurrencyCode) == "USD")
    }

    // MARK: - Leak test — observer no retiene self

    @Test func deallocatesWithoutLeak() async {
        let defaults = Self.makeSuite()

        weak var ref: AppPreferences?
        do {
            let prefs = AppPreferences(defaults: defaults)
            ref = prefs
            #expect(ref != nil)
        }

        // Yield a couple of run loops so the token's weak reference can release
        try? await Task.sleep(for: .milliseconds(50))

        #expect(ref == nil, "AppPreferences debe desalocarse cuando sale de scope — observer no debe retener self")
    }

    // MARK: - Enum fallback on invalid raw

    @Test func init_fallsBackOnInvalidEnumRaw() {
        let defaults = Self.makeSuite()
        defaults.set("xxxInvalid", forKey: AppPreferences.Keys.defaultCurrencyCode)
        defaults.set("xxxInvalid", forKey: AppPreferences.Keys.insightsTone)
        defaults.set("xxxInvalid", forKey: AppPreferences.Keys.voiceLanguage)
        defaults.set("xxxInvalid", forKey: AppPreferences.Keys.currencyDisplayFormat)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.defaultCurrencyCode == .pen)         // fallback
        #expect(prefs.insightsTone == .normal)             // fallback
        #expect(prefs.voiceLanguage == .system)            // fallback
        #expect(prefs.currencyDisplayFormat == .code)      // fallback
    }

    // MARK: - Backwards compat — @AppStorage legacy writes are seen by AppPreferences

    @Test func externalAppStorageWrite_reflectsOnNextInit() {
        let defaults = Self.makeSuite()

        // Simulate a legacy @AppStorage view writing directly
        defaults.set("EUR", forKey: AppPreferences.Keys.defaultCurrencyCode)
        defaults.set(true, forKey: AppPreferences.Keys.showVariations)

        // AppPreferences reading fresh
        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.defaultCurrencyCode == .eur)
        #expect(prefs.showVariations == true)
    }

    @Test func appPreferencesWrite_visibleToLegacyAppStorageReads() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.defaultCurrencyCode = .gbp
        prefs.chatAssistantEnabled = true

        // Simulate a legacy @AppStorage view reading via raw UserDefaults
        #expect(defaults.string(forKey: "defaultCurrencyCode") == "GBP")
        #expect(defaults.bool(forKey: "chatAssistantEnabled") == true)
    }

    // MARK: - Empty arrays

    @Test func set_emptySecondaryCurrencies_persistsAsEmptyString() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.secondaryCurrencies = ["USD"]
        #expect(defaults.string(forKey: AppPreferences.Keys.secondaryCurrencies) == "USD")

        prefs.secondaryCurrencies = []
        #expect(defaults.string(forKey: AppPreferences.Keys.secondaryCurrencies) == "")

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.secondaryCurrencies == [])
    }
}
