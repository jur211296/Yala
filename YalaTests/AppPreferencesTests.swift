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
@Suite(.serialized)
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
        #expect(prefs.currencyDisplayFormat == .symbol)
        #expect(prefs.decimalPlaces == 2)
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

        // Default es .symbol — asignar .code dispara el didSet (oldValue != newValue).
        prefs.currencyDisplayFormat = .code

        #expect(defaults.string(forKey: AppPreferences.Keys.currencyDisplayFormat) == "code")
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

    // MARK: - usageFocus (D1)

    @Test func set_usageFocus_persistsRawValue() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.usageFocus = .groupsOnly

        #expect(defaults.string(forKey: AppPreferences.Keys.usageFocus) == "groupsOnly")
    }

    @Test func init_usageFocus_present_loadsGroupsOnly() {
        let defaults = Self.makeSuite()
        defaults.set("groupsOnly", forKey: AppPreferences.Keys.usageFocus)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.usageFocus == .groupsOnly)
    }

    @Test func init_usageFocus_absent_defaultsFull() {
        // Reset-on-absent: sin la key (p.ej. tras el wipe) → .full.
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.usageFocus == .full)
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
        prefs.aiInsightsEnabled = true
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
        #expect(reloaded.aiInsightsEnabled == true)
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
        prefs.firstWeekday = .sunday
        prefs.averageLineMode = 2

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.decimalPlaces == 4)
        #expect(reloaded.firstWeekday == .sunday)
        #expect(reloaded.averageLineMode == 2)
    }

    @Test func set_allStrings_persistAndReload() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.userName = "Lovelace"
        prefs.userAlias = "Ada"
        prefs.userProfileIcon = "star.fill"
        prefs.tabConfigJSON = "{\"version\":1}"
        prefs.autoFocusField = .amount
        prefs.lastSeenAppVersion = "2.0.0"

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.userName == "Lovelace")
        #expect(reloaded.userAlias == "Ada")
        #expect(reloaded.userProfileIcon == "star.fill")
        #expect(reloaded.tabConfigJSON == "{\"version\":1}")
        #expect(reloaded.autoFocusField == .amount)
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
        #expect(prefs.currencyDisplayFormat == .symbol)    // fallback al default
    }

    @Test func init_usageFocus_fallsBackOnInvalidRaw() {
        let defaults = Self.makeSuite()
        defaults.set("xxxInvalid", forKey: AppPreferences.Keys.usageFocus)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.usageFocus == .full)  // fallback (reset-on-absent/invalid)
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

    // MARK: - AI Insights migration — consent/feature desacople

    @Test func aiInsightsMigration_consentTrueWithoutSentinel_seedsEnabled() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        // Sentinel NOT set → migración corre al init

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == true)
        #expect(prefs.aiInsightsEnabled == true, "usuario con consent preexistente debe quedar con feature activa")
        #expect(defaults.bool(forKey: AppPreferences.Keys.aiInsightsMigratedV1) == true)
    }

    @Test func aiInsightsMigration_consentFalseWithoutSentinel_leavesEnabledFalseAndSetsSentinel() {
        let defaults = Self.makeSuite()
        // Ningún flag seteado → migración corre, no siembra

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == false)
        #expect(prefs.aiInsightsEnabled == false)
        #expect(defaults.bool(forKey: AppPreferences.Keys.aiInsightsMigratedV1) == true, "sentinel debe setearse siempre tras primer check")
    }

    @Test func aiInsightsMigration_sentinelAlreadySet_doesNotOverwriteEnabled() {
        let defaults = Self.makeSuite()
        // Simula user que ya migró v1 y v2 y luego apagó la feature manteniendo consent.
        // Pre-setear aiTogglesRemovedV2 para evitar que la migración v2 revoque el consent.
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        defaults.set(false, forKey: AppPreferences.Keys.aiInsightsEnabled)
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)
        defaults.set(true, forKey: AppPreferences.Keys.aiTogglesRemovedV2)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == true)
        #expect(prefs.aiInsightsEnabled == false, "migración no debe re-ejecutarse si los sentinels ya están seteados")
    }

    // MARK: - aiTogglesRemovedV2 — migración conservadora

    @Test func aiTogglesRemovedV2_insightsConsentOnTogglesOff_revokesConsent() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1) // v1 ya corrió
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        defaults.set(false, forKey: AppPreferences.Keys.aiInsightsEnabled)
        // aiTogglesRemovedV2 NOT set

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == false, "consent revocado porque toggle estaba OFF (decisión histórica del user)")
        #expect(defaults.bool(forKey: AppPreferences.Keys.aiTogglesRemovedV2) == true, "sentinel debe setearse")
    }

    @Test func aiTogglesRemovedV2_chatConsentOnToggleOff_revokesConsent() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)
        defaults.set(true, forKey: AppPreferences.Keys.aiChatConsentAccepted)
        defaults.set(false, forKey: AppPreferences.Keys.chatAssistantEnabled)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiChatConsentAccepted == false)
        #expect(defaults.bool(forKey: AppPreferences.Keys.aiTogglesRemovedV2) == true)
    }

    @Test func aiTogglesRemovedV2_dataConsentOnAllVoiceImageOff_revokesConsent() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)
        defaults.set(true, forKey: AppPreferences.Keys.aiDataConsentAccepted)
        defaults.set(false, forKey: AppPreferences.Keys.voiceInputEnabled)
        defaults.set(false, forKey: AppPreferences.Keys.imageInputEnabled)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiDataConsentAccepted == false)
    }

    @Test func aiTogglesRemovedV2_consentAndTogglesAligned_doesNotRevoke() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)
        // Caso: user con consent=true y feature=true (aligned) — no revocar
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsEnabled)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == true)
        #expect(prefs.aiInsightsEnabled == true)
        #expect(defaults.bool(forKey: AppPreferences.Keys.aiTogglesRemovedV2) == true)
    }

    @Test func aiTogglesRemovedV2_idempotent_doesNotRevokeOnSecondInit() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)
        defaults.set(true, forKey: AppPreferences.Keys.aiTogglesRemovedV2) // ya migró
        // Caso edge: alguien setea consent=true && toggle=false manualmente post-migración
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        defaults.set(false, forKey: AppPreferences.Keys.aiInsightsEnabled)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.aiInsightsConsentAccepted == true, "migración no se re-ejecuta si sentinel v2 ya seteado")
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

    // MARK: - Panel 2.0 — per-section keys

    @Test func init_loadsPanelSectionKeys_whenPresent() {
        let defaults = Self.makeSuite()
        // Pre-set the flag so migration doesn't clobber these values on init
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        defaults.set("tendencia_saldo,flujo_efectivo", forKey: AppPreferences.Keys.panelTendenciasOrder)
        defaults.set("flujo_efectivo", forKey: AppPreferences.Keys.panelTendenciasHidden)
        defaults.set("categorias_torta,categorias_principales", forKey: AppPreferences.Keys.panelDistribucionOrder)
        defaults.set("presupuestos", forKey: AppPreferences.Keys.panelPlanificacionHidden)
        defaults.set("tools", forKey: AppPreferences.Keys.panelSectionsHidden)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.panelPrefsMigratedV2 == true)
        #expect(prefs.panelTendenciasOrder == ["tendencia_saldo", "flujo_efectivo"])
        #expect(prefs.panelTendenciasHidden == ["flujo_efectivo"])
        #expect(prefs.panelDistribucionOrder == ["categorias_torta", "categorias_principales"])
        #expect(prefs.panelPlanificacionHidden == ["presupuestos"])
        #expect(prefs.panelSectionsHidden == ["tools"])
    }

    @Test func set_panelTendenciasOrder_persists_roundTrip() {
        let defaults = Self.makeSuite()
        // Mark migrated so init doesn't interfere
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)

        let prefs = AppPreferences(defaults: defaults)
        prefs.panelTendenciasOrder = ["flujo_efectivo", "tendencia_saldo", "gastos_por_naturaleza"]

        #expect(defaults.string(forKey: AppPreferences.Keys.panelTendenciasOrder)
                == "flujo_efectivo,tendencia_saldo,gastos_por_naturaleza")

        // Empty round-trip (hiding everything is a legit state)
        prefs.panelTendenciasOrder = []
        #expect(defaults.string(forKey: AppPreferences.Keys.panelTendenciasOrder) == "")

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.panelTendenciasOrder == [])
    }

    @Test func set_panelPrefsMigratedV2_persistsToUserDefaults() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        // Migration already ran during init (no legacy data → writes flag).
        #expect(prefs.panelPrefsMigratedV2 == true)
        #expect(defaults.bool(forKey: AppPreferences.Keys.panelPrefsMigratedV2) == true)

        // Manual toggle still works (e.g. for testing re-migration scenarios)
        prefs.panelPrefsMigratedV2 = false
        #expect(defaults.bool(forKey: AppPreferences.Keys.panelPrefsMigratedV2) == false)
    }

    // MARK: - P20-11 panelAccountsCollapsed (synced)

    @Test func set_panelAccountsCollapsed_persistsAndReloads() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        // Default true (collapsed on first open) tras Panel 2.0
        #expect(prefs.panelAccountsCollapsed == true)

        // Toggle off: persists immediately to UserDefaults. Usamos object(forKey:)
        // porque defaults.bool(forKey:) devuelve false tanto para "key ausente" como
        // para "key explícitamente false" — no permite verificar persistencia de false.
        prefs.panelAccountsCollapsed = false
        #expect(defaults.object(forKey: AppPreferences.Keys.panelAccountsCollapsed) as? Bool == false)

        // Round-trip through a fresh AppPreferences instance
        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.panelAccountsCollapsed == false)
    }

    // MARK: - PP2-05 WidgetSize.small Codable

    @Test func widgetSize_small_encodesToS() throws {
        let data = try JSONEncoder().encode(WidgetSize.small)
        let raw = String(data: data, encoding: .utf8)
        #expect(raw == "\"S\"")
    }

    @Test func widgetSize_small_roundTripThroughJSON() throws {
        let encoded = try JSONEncoder().encode(WidgetSize.small)
        let decoded = try JSONDecoder().decode(WidgetSize.self, from: encoded)
        #expect(decoded == .small)
    }

    @Test func widgetConfig_withSmallSize_roundTripsInJSON() throws {
        let original = WidgetConfig(
            id: UUID(),
            type: .topSpending,
            isVisible: true,
            size: .small
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetConfig.self, from: data)
        #expect(decoded.size == .small)
        #expect(decoded.type == .topSpending)
        #expect(decoded.isVisible == true)
    }

    // MARK: - PP2-06b WidgetConfig .small roundtrip

    @Test func widgetConfig_budgetsSmall_roundTripsInJSON() throws {
        let original = WidgetConfig(
            id: UUID(),
            type: .budgets,
            isVisible: true,
            size: .small
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetConfig.self, from: data)
        #expect(decoded.size == .small)
        #expect(decoded.type == .budgets)
    }

    @Test func widgetConfig_scheduledPaymentsSmall_roundTripsInJSON() throws {
        let original = WidgetConfig(
            id: UUID(),
            type: .scheduledPayments,
            isVisible: true,
            size: .small
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetConfig.self, from: data)
        #expect(decoded.size == .small)
        #expect(decoded.type == .scheduledPayments)
    }

    // MARK: - Formatting parity (regression-guards migration to appPreferences.X)

    /// `appPreferences.currency(...)` must produce byte-identical strings to
    /// `YalaFormatterStatic.currency(value:currencyCode:)` for every combination of prefs.
    /// Any divergence introduced by the migration would fail these tests.
    @Test func currency_parity_acrossDecimalsAndFormat() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let values: [Double] = [0, 1000, -1000, 1234.567, -0.5]
        let codes = ["PEN", "USD", "EUR"]

        for decimals in [0, 1, 2] {
            for format in [CurrencyDisplayFormat.code, .symbol] {
                prefs.decimalPlaces = decimals
                prefs.currencyDisplayFormat = format

                // Match the underlying UserDefaults so YalaFormatter (which reads
                // UserDefaults.standard) can read the same prefs from the test process.
                UserDefaults.standard.set(decimals, forKey: "decimalPlaces")
                UserDefaults.standard.set(format.rawValue, forKey: "currencyDisplayFormat")

                for value in values {
                    for code in codes {
                        let viaPrefs = prefs.currency(value, currencyCode: code)
                        let viaFormatter = YalaFormatterStatic.currency(value: value, currencyCode: code)
                        #expect(
                            viaPrefs == viaFormatter,
                            "decimals=\(decimals) format=\(format) value=\(value) code=\(code) → prefs=\(viaPrefs) vs formatter=\(viaFormatter)"
                        )
                    }
                }
            }
        }
    }

    @Test func currencyIdentifier_parity_acrossFormat() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        for format in [CurrencyDisplayFormat.code, .symbol] {
            prefs.currencyDisplayFormat = format
            UserDefaults.standard.set(format.rawValue, forKey: "currencyDisplayFormat")
            for code in ["PEN", "USD", "EUR", "JPY"] {
                #expect(
                    prefs.currencyIdentifier(for: code) == YalaFormatterStatic.currencyIdentifier(for: code),
                    "format=\(format) code=\(code)"
                )
            }
        }
    }

    @Test func number_parity_acrossDecimals() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let values: [Double] = [0, 1234.5, -987.6, 100_000]

        for decimals in [0, 1, 2] {
            prefs.decimalPlaces = decimals
            UserDefaults.standard.set(decimals, forKey: "decimalPlaces")
            for value in values {
                #expect(
                    prefs.number(value) == YalaFormatterStatic.number(value: value),
                    "decimals=\(decimals) value=\(value)"
                )
            }
        }
    }

    @Test func currencyCompact_parity() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // Sincronizar prefs ↔ UserDefaults.standard (lo que YalaFormatterStatic lee).
        prefs.decimalPlaces = 0
        prefs.currencyDisplayFormat = .code
        UserDefaults.standard.set(0, forKey: "decimalPlaces")
        UserDefaults.standard.set("code", forKey: "currencyDisplayFormat")

        for value in [0.0, 500, 5_000, 12_345.67, -50_000] {
            #expect(
                prefs.currencyCompact(value, currencyCode: "PEN") == YalaFormatterStatic.currencyCompact(value: value, currencyCode: "PEN"),
                "value=\(value)"
            )
        }
    }

    @Test func amountCashFlowCell_parity() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        UserDefaults.standard.set("symbol", forKey: "currencyDisplayFormat")
        prefs.currencyDisplayFormat = .symbol

        for value in [0.0, 9_999, 10_500, -25_000] {
            #expect(
                prefs.amountCashFlowCell(value, currencyCode: "PEN") == YalaFormatterStatic.amountCashFlowCell(value: value, currencyCode: "PEN"),
                "value=\(value)"
            )
        }
    }

    @Test func currency_changingDecimalsLiveYieldsDifferentString() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)

        prefs.decimalPlaces = 0
        let zero = prefs.currency(1234.56, currencyCode: "PEN")
        prefs.decimalPlaces = 2
        let two = prefs.currency(1234.56, currencyCode: "PEN")
        #expect(zero != two)
        #expect(two.contains(".56"))
    }
}
