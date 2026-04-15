//
//  AppPreferences.swift
//  Yala
//
//  @Observable service con acceso tipado a todas las preferencias persistentes del app.
//  Reemplaza @AppStorage raw strings dispersos en ~30 views por una fuente única tipada.
//
//  Uso:
//      struct MiVista: View {
//          @Environment(AppPreferences.self) private var appPreferences
//
//          var body: some View {
//              Text("Moneda: \(appPreferences.defaultCurrencyCode.rawValue)")
//              Button("Toggle AI") { appPreferences.chatAssistantEnabled.toggle() }
//          }
//      }
//
//  Arquitectura:
//  - Stored properties en el body (único lugar que `@Observable` rastrea).
//  - `didSet` por property: persiste a UserDefaults (+ PreferenceSyncService si es synced),
//    con guard oldValue != newValue para evitar loop con el observer externo.
//  - Init carga TODAS las properties desde UserDefaults ANTES de registrar observers.
//  - Observer de `UserDefaults.didChangeNotification` + `NSUbiquitousKeyValueStore` →
//    `refreshFromDefaults()` diferencial (solo asigna si el valor cambió) evitando
//    re-renders innecesarios cuando cambian keys ajenas.
//  - Captura `[weak self]` en closures del observer + `deinit` remueve observers.
//
//  Backwards compatibility: los callsites legacy con `@AppStorage` siguen funcionando
//  porque leen/escriben a los mismos UserDefaults keys. Ambas rutas conviven sin migración
//  de datos.
//

import Foundation
import SwiftUI

// MARK: - CurrencyDisplayFormat

/// Formato de visualización de la moneda: símbolo ("$") vs código ISO ("USD").
enum CurrencyDisplayFormat: String, CaseIterable, Sendable {
    case code
    case symbol
}

// MARK: - AppPreferences

@Observable
@MainActor
final class AppPreferences {

    // MARK: - Dependencies

    private let defaults: UserDefaults

    /// Observer tokens. Marcados `nonisolated(unsafe)` porque (1) se asignan solo durante
    /// `registerObservers()` en MainActor, (2) se leen solo en deinit (nonisolated por
    /// default en Swift 6) — no hay concurrencia real entre ambas operaciones.
    @ObservationIgnored
    nonisolated(unsafe) private var didChangeToken: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var iKVChangeToken: NSObjectProtocol?

    // MARK: - Currency & Format

    var defaultCurrencyCode: CurrencyCode = .pen {
        didSet {
            guard oldValue != defaultCurrencyCode else { return }
            persistString(defaultCurrencyCode.rawValue, forKey: Keys.defaultCurrencyCode, synced: true)
        }
    }

    /// Comma-separated list of currency codes (e.g. "USD,EUR").
    var secondaryCurrencies: [String] = [] {
        didSet {
            guard oldValue != secondaryCurrencies else { return }
            persistString(secondaryCurrencies.joined(separator: ","), forKey: Keys.secondaryCurrencies, synced: true)
        }
    }

    var currencyDisplayFormat: CurrencyDisplayFormat = .code {
        didSet {
            guard oldValue != currencyDisplayFormat else { return }
            persistString(currencyDisplayFormat.rawValue, forKey: Keys.currencyDisplayFormat, synced: true)
        }
    }

    var decimalPlaces: Int = 0 {
        didSet {
            guard oldValue != decimalPlaces else { return }
            persistInt(decimalPlaces, forKey: Keys.decimalPlaces, synced: true)
        }
    }

    // MARK: - Identity

    var userName: String = "Usuario" {
        didSet {
            guard oldValue != userName else { return }
            persistString(userName, forKey: Keys.userName, synced: true)
        }
    }

    var userAlias: String = "" {
        didSet {
            guard oldValue != userAlias else { return }
            persistString(userAlias, forKey: Keys.userAlias, synced: false)
        }
    }

    var userProfileIcon: String = "" {
        didSet {
            guard oldValue != userProfileIcon else { return }
            persistString(userProfileIcon, forKey: Keys.userProfileIcon, synced: true)
        }
    }

    var colorfulIcons: Bool = true {
        didSet {
            guard oldValue != colorfulIcons else { return }
            persistBool(colorfulIcons, forKey: Keys.colorfulIcons, synced: true)
        }
    }

    // MARK: - Session / Period

    var defaultPeriod: DetailPeriod = .thisMonth {
        didSet {
            guard oldValue != defaultPeriod else { return }
            persistString(defaultPeriod.rawValue, forKey: Keys.defaultPeriod, synced: true)
        }
    }

    var firstWeekday: Int = 2 {
        didSet {
            guard oldValue != firstWeekday else { return }
            persistInt(firstWeekday, forKey: Keys.firstWeekday, synced: true)
        }
    }

    /// Pipe-separated list of account names in sort order.
    /// NOTE: pipe (`|`) chosen to match legacy `@AppStorage("accountsSortOrderNames")` callsites
    /// and `PanelViewModel.ensureAccountsSortOrderConsistency`. Account names may legitimately
    /// contain commas but never pipes, so this separator is collision-safe.
    var accountsSortOrderNames: [String] = [] {
        didSet {
            guard oldValue != accountsSortOrderNames else { return }
            persistString(accountsSortOrderNames.joined(separator: "|"), forKey: Keys.accountsSortOrderNames, synced: true)
        }
    }

    /// Comma-separated list of tag names in sort order.
    var tagsSortOrderNames: [String] = [] {
        didSet {
            guard oldValue != tagsSortOrderNames else { return }
            persistString(tagsSortOrderNames.joined(separator: ","), forKey: Keys.tagsSortOrderNames, synced: false)
        }
    }

    /// JSON serializado de `TabBarConfiguration`.
    var tabConfigJSON: String = "" {
        didSet {
            guard oldValue != tabConfigJSON else { return }
            persistString(tabConfigJSON, forKey: Keys.tabConfigJSON, synced: false)
        }
    }

    // MARK: - Widget / Trend

    var showVariations: Bool = true {
        didSet {
            guard oldValue != showVariations else { return }
            persistBool(showVariations, forKey: Keys.showVariations, synced: true)
        }
    }

    var showWidgetHints: Bool = true {
        didSet {
            guard oldValue != showWidgetHints else { return }
            persistBool(showWidgetHints, forKey: Keys.showWidgetHints, synced: false)
        }
    }

    var averageLineMode: Int = 1 {
        didSet {
            guard oldValue != averageLineMode else { return }
            persistInt(averageLineMode, forKey: Keys.averageLineMode, synced: true)
        }
    }

    // MARK: - Voice / Image / AI

    var voiceInputEnabled: Bool = false {
        didSet {
            guard oldValue != voiceInputEnabled else { return }
            persistBool(voiceInputEnabled, forKey: Keys.voiceInputEnabled, synced: false)
        }
    }

    var voiceLanguage: VoiceLanguage = .system {
        didSet {
            guard oldValue != voiceLanguage else { return }
            persistString(voiceLanguage.rawValue, forKey: Keys.voiceLanguage, synced: true)
        }
    }

    var imageInputEnabled: Bool = false {
        didSet {
            guard oldValue != imageInputEnabled else { return }
            persistBool(imageInputEnabled, forKey: Keys.imageInputEnabled, synced: false)
        }
    }

    var aiDataConsentAccepted: Bool = false {
        didSet {
            guard oldValue != aiDataConsentAccepted else { return }
            persistBool(aiDataConsentAccepted, forKey: Keys.aiDataConsentAccepted, synced: false)
        }
    }

    var aiInsightsConsentAccepted: Bool = false {
        didSet {
            guard oldValue != aiInsightsConsentAccepted else { return }
            persistBool(aiInsightsConsentAccepted, forKey: Keys.aiInsightsConsentAccepted, synced: false)
        }
    }

    var aiChatConsentAccepted: Bool = false {
        didSet {
            guard oldValue != aiChatConsentAccepted else { return }
            persistBool(aiChatConsentAccepted, forKey: Keys.aiChatConsentAccepted, synced: false)
        }
    }

    var chatAssistantEnabled: Bool = false {
        didSet {
            guard oldValue != chatAssistantEnabled else { return }
            persistBool(chatAssistantEnabled, forKey: Keys.chatAssistantEnabled, synced: false)
        }
    }

    var chatFABVisible: Bool = true {
        didSet {
            guard oldValue != chatFABVisible else { return }
            persistBool(chatFABVisible, forKey: Keys.chatFABVisible, synced: false)
        }
    }

    var cashFlowAIEnabled: Bool = false {
        didSet {
            guard oldValue != cashFlowAIEnabled else { return }
            persistBool(cashFlowAIEnabled, forKey: Keys.cashFlowAIEnabled, synced: false)
        }
    }

    var insightsTone: InsightTone = .normal {
        didSet {
            guard oldValue != insightsTone else { return }
            persistString(insightsTone.rawValue, forKey: Keys.insightsTone, synced: true)
        }
    }

    var insightsFocus: InsightFocus = .balanced {
        didSet {
            guard oldValue != insightsFocus else { return }
            persistString(insightsFocus.rawValue, forKey: Keys.insightsFocus, synced: true)
        }
    }

    var autoFocusField: String = "none" {
        didSet {
            guard oldValue != autoFocusField else { return }
            persistString(autoFocusField, forKey: Keys.autoFocusField, synced: true)
        }
    }

    // MARK: - Budgets / Alerts

    var budgetsHideInactive: Bool = false {
        didSet {
            guard oldValue != budgetsHideInactive else { return }
            persistBool(budgetsHideInactive, forKey: Keys.budgetsHideInactive, synced: false)
        }
    }

    var budgetAlertsEnabled: Bool = false {
        didSet {
            guard oldValue != budgetAlertsEnabled else { return }
            persistBool(budgetAlertsEnabled, forKey: Keys.budgetAlertsEnabled, synced: true)
        }
    }

    // MARK: - UI Feature Flags

    var showSiriTip: Bool = true {
        didSet {
            guard oldValue != showSiriTip else { return }
            persistBool(showSiriTip, forKey: Keys.showSiriTip, synced: false)
        }
    }

    var hasCompletedOnboarding: Bool = false {
        didSet {
            guard oldValue != hasCompletedOnboarding else { return }
            persistBool(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding, synced: false)
        }
    }

    var lastSeenAppVersion: String = "" {
        didSet {
            guard oldValue != lastSeenAppVersion else { return }
            persistString(lastSeenAppVersion, forKey: Keys.lastSeenAppVersion, synced: false)
        }
    }

    /// Acceso tipado; `SessionState.isExpensesOnlyMode` sigue siendo el autor de la
    /// propagación a App Group + Widget — ambos paths conviven sin conflicto.
    var expensesOnlyMode: Bool = false {
        didSet {
            guard oldValue != expensesOnlyMode else { return }
            persistBool(expensesOnlyMode, forKey: Keys.expensesOnlyMode, synced: true)
        }
    }

    // MARK: - One-Off Tours

    var hasSeenSettingsTour: Bool = false {
        didSet {
            guard oldValue != hasSeenSettingsTour else { return }
            persistBool(hasSeenSettingsTour, forKey: Keys.hasSeenSettingsTour, synced: false)
        }
    }

    var hasSeenCashFlowSetupTour: Bool = false {
        didSet {
            guard oldValue != hasSeenCashFlowSetupTour else { return }
            persistBool(hasSeenCashFlowSetupTour, forKey: Keys.hasSeenCashFlowSetupTour, synced: false)
        }
    }

    var hasSeenCashFlowTableTour: Bool = false {
        didSet {
            guard oldValue != hasSeenCashFlowTableTour else { return }
            persistBool(hasSeenCashFlowTableTour, forKey: Keys.hasSeenCashFlowTableTour, synced: false)
        }
    }

    var hasSeenGroupsNotificationPrompt: Bool = false {
        didSet {
            guard oldValue != hasSeenGroupsNotificationPrompt else { return }
            persistBool(hasSeenGroupsNotificationPrompt, forKey: Keys.hasSeenGroupsNotificationPrompt, synced: false)
        }
    }

    // MARK: - Insights Section Visibility

    var insightsShowQuickStats: Bool = true {
        didSet {
            guard oldValue != insightsShowQuickStats else { return }
            persistBool(insightsShowQuickStats, forKey: Keys.insightsShowQuickStats, synced: false)
        }
    }

    var insightsShowPendingPayments: Bool = true {
        didSet {
            guard oldValue != insightsShowPendingPayments else { return }
            persistBool(insightsShowPendingPayments, forKey: Keys.insightsShowPendingPayments, synced: false)
        }
    }

    var insightsShowSubscriptions: Bool = true {
        didSet {
            guard oldValue != insightsShowSubscriptions else { return }
            persistBool(insightsShowSubscriptions, forKey: Keys.insightsShowSubscriptions, synced: false)
        }
    }

    var insightsShowBudgetsAtRisk: Bool = true {
        didSet {
            guard oldValue != insightsShowBudgetsAtRisk else { return }
            persistBool(insightsShowBudgetsAtRisk, forKey: Keys.insightsShowBudgetsAtRisk, synced: false)
        }
    }

    var insightsShowWeekday: Bool = true {
        didSet {
            guard oldValue != insightsShowWeekday else { return }
            persistBool(insightsShowWeekday, forKey: Keys.insightsShowWeekday, synced: false)
        }
    }

    var insightsShowNature: Bool = true {
        didSet {
            guard oldValue != insightsShowNature else { return }
            persistBool(insightsShowNature, forKey: Keys.insightsShowNature, synced: false)
        }
    }

    var insightsShowTexts: Bool = true {
        didSet {
            guard oldValue != insightsShowTexts else { return }
            persistBool(insightsShowTexts, forKey: Keys.insightsShowTexts, synced: false)
        }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Carga inicial ANTES de registrar observers (mitiga race con notificaciones
        // tempranas durante bootstrap). Los `didSet` de cada property aplican el guard
        // diferencial; no se re-persisten valores que no cambiaron del default hardcoded.
        loadFromDefaults()
        registerObservers()
    }

    deinit {
        if let token = didChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = iKVChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Observer Registration

    private func registerObservers() {
        didChangeToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadFromDefaults()
            }
        }

        iKVChangeToken = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadFromDefaults()
            }
        }
    }

    // MARK: - Load from Defaults (init + external change refresh)

    /// Re-lee todas las properties desde `defaults` y asigna solo las que cambiaron.
    ///
    /// Usado tanto en la carga inicial (`init`) como tras notificaciones externas
    /// (`UserDefaults.didChangeNotification` global, `NSUbiquitousKeyValueStore`).
    /// El guard `oldValue != newValue` en cada `didSet` evita re-renders innecesarios
    /// cuando la notificación se dispara por keys ajenas (TipKit, StoreKit) — y también
    /// previene persist-loops cuando el valor viene de una escritura externa (iKV) y
    /// no debe propagarse de vuelta.
    private func loadFromDefaults() {
        // Currency & Format
        if let raw = defaults.string(forKey: Keys.defaultCurrencyCode), let code = CurrencyCode(rawValue: raw) {
            defaultCurrencyCode = code
        }
        if let raw = defaults.string(forKey: Keys.secondaryCurrencies) {
            secondaryCurrencies = raw.isEmpty ? [] : raw.split(separator: ",").map { String($0) }
        }
        if let raw = defaults.string(forKey: Keys.currencyDisplayFormat), let fmt = CurrencyDisplayFormat(rawValue: raw) {
            currencyDisplayFormat = fmt
        }
        if defaults.object(forKey: Keys.decimalPlaces) != nil {
            decimalPlaces = defaults.integer(forKey: Keys.decimalPlaces)
        }

        // Identity
        if let raw = defaults.string(forKey: Keys.userName), !raw.isEmpty {
            userName = raw
        }
        userAlias = defaults.string(forKey: Keys.userAlias) ?? ""
        userProfileIcon = defaults.string(forKey: Keys.userProfileIcon) ?? ""
        if defaults.object(forKey: Keys.colorfulIcons) != nil {
            colorfulIcons = defaults.bool(forKey: Keys.colorfulIcons)
        }

        // Session / Period
        if let raw = defaults.string(forKey: Keys.defaultPeriod), let period = DetailPeriod(rawValue: raw) {
            defaultPeriod = period
        }
        if defaults.object(forKey: Keys.firstWeekday) != nil {
            firstWeekday = defaults.integer(forKey: Keys.firstWeekday)
        }
        if let raw = defaults.string(forKey: Keys.accountsSortOrderNames) {
            accountsSortOrderNames = raw.isEmpty ? [] : raw.split(separator: "|").map { String($0) }
        }
        if let raw = defaults.string(forKey: Keys.tagsSortOrderNames) {
            tagsSortOrderNames = raw.isEmpty ? [] : raw.split(separator: ",").map { String($0) }
        }
        tabConfigJSON = defaults.string(forKey: Keys.tabConfigJSON) ?? ""

        // Widget / Trend
        if defaults.object(forKey: Keys.showVariations) != nil {
            showVariations = defaults.bool(forKey: Keys.showVariations)
        }
        if defaults.object(forKey: Keys.showWidgetHints) != nil {
            showWidgetHints = defaults.bool(forKey: Keys.showWidgetHints)
        }
        if defaults.object(forKey: Keys.averageLineMode) != nil {
            averageLineMode = defaults.integer(forKey: Keys.averageLineMode)
        }

        // Voice / Image / AI
        voiceInputEnabled = defaults.bool(forKey: Keys.voiceInputEnabled)
        if let raw = defaults.string(forKey: Keys.voiceLanguage), let lang = VoiceLanguage(rawValue: raw) {
            voiceLanguage = lang
        }
        imageInputEnabled = defaults.bool(forKey: Keys.imageInputEnabled)
        aiDataConsentAccepted = defaults.bool(forKey: Keys.aiDataConsentAccepted)
        aiInsightsConsentAccepted = defaults.bool(forKey: Keys.aiInsightsConsentAccepted)
        aiChatConsentAccepted = defaults.bool(forKey: Keys.aiChatConsentAccepted)
        chatAssistantEnabled = defaults.bool(forKey: Keys.chatAssistantEnabled)
        if defaults.object(forKey: Keys.chatFABVisible) != nil {
            chatFABVisible = defaults.bool(forKey: Keys.chatFABVisible)
        }
        cashFlowAIEnabled = defaults.bool(forKey: Keys.cashFlowAIEnabled)
        if let raw = defaults.string(forKey: Keys.insightsTone), let tone = InsightTone(rawValue: raw) {
            insightsTone = tone
        }
        if let raw = defaults.string(forKey: Keys.insightsFocus), let focus = InsightFocus(rawValue: raw) {
            insightsFocus = focus
        }
        if let raw = defaults.string(forKey: Keys.autoFocusField), !raw.isEmpty {
            autoFocusField = raw
        }

        // Budgets / Alerts
        budgetsHideInactive = defaults.bool(forKey: Keys.budgetsHideInactive)
        budgetAlertsEnabled = defaults.bool(forKey: Keys.budgetAlertsEnabled)

        // UI Feature Flags
        if defaults.object(forKey: Keys.showSiriTip) != nil {
            showSiriTip = defaults.bool(forKey: Keys.showSiriTip)
        }
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        lastSeenAppVersion = defaults.string(forKey: Keys.lastSeenAppVersion) ?? ""
        expensesOnlyMode = defaults.bool(forKey: Keys.expensesOnlyMode)

        // One-Off Tours
        hasSeenSettingsTour = defaults.bool(forKey: Keys.hasSeenSettingsTour)
        hasSeenCashFlowSetupTour = defaults.bool(forKey: Keys.hasSeenCashFlowSetupTour)
        hasSeenCashFlowTableTour = defaults.bool(forKey: Keys.hasSeenCashFlowTableTour)
        hasSeenGroupsNotificationPrompt = defaults.bool(forKey: Keys.hasSeenGroupsNotificationPrompt)

        // Insights Section Visibility
        if defaults.object(forKey: Keys.insightsShowQuickStats) != nil {
            insightsShowQuickStats = defaults.bool(forKey: Keys.insightsShowQuickStats)
        }
        if defaults.object(forKey: Keys.insightsShowPendingPayments) != nil {
            insightsShowPendingPayments = defaults.bool(forKey: Keys.insightsShowPendingPayments)
        }
        if defaults.object(forKey: Keys.insightsShowSubscriptions) != nil {
            insightsShowSubscriptions = defaults.bool(forKey: Keys.insightsShowSubscriptions)
        }
        if defaults.object(forKey: Keys.insightsShowBudgetsAtRisk) != nil {
            insightsShowBudgetsAtRisk = defaults.bool(forKey: Keys.insightsShowBudgetsAtRisk)
        }
        if defaults.object(forKey: Keys.insightsShowWeekday) != nil {
            insightsShowWeekday = defaults.bool(forKey: Keys.insightsShowWeekday)
        }
        if defaults.object(forKey: Keys.insightsShowNature) != nil {
            insightsShowNature = defaults.bool(forKey: Keys.insightsShowNature)
        }
        if defaults.object(forKey: Keys.insightsShowTexts) != nil {
            insightsShowTexts = defaults.bool(forKey: Keys.insightsShowTexts)
        }
    }

    // MARK: - Persistence Helpers

    private func persistString(_ value: String, forKey key: String, synced: Bool) {
        defaults.set(value, forKey: key)
        if synced {
            PreferenceSyncService.shared.set(string: value, forKey: key)
        }
    }

    private func persistBool(_ value: Bool, forKey key: String, synced: Bool) {
        defaults.set(value, forKey: key)
        if synced {
            PreferenceSyncService.shared.set(bool: value, forKey: key)
        }
    }

    private func persistInt(_ value: Int, forKey key: String, synced: Bool) {
        defaults.set(value, forKey: key)
        if synced {
            PreferenceSyncService.shared.set(int: value, forKey: key)
        }
    }

    // MARK: - Storage Keys

    /// Centraliza los raw string keys de UserDefaults. Mantiene compatibilidad con
    /// `@AppStorage` callsites legacy (mismo key → misma persistencia).
    enum Keys {
        // Currency & Format
        static let defaultCurrencyCode = "defaultCurrencyCode"
        static let secondaryCurrencies = "secondaryCurrencies"
        static let currencyDisplayFormat = "currencyDisplayFormat"
        static let decimalPlaces = "decimalPlaces"

        // Identity
        static let userName = "userName"
        static let userAlias = "userAlias"
        static let userProfileIcon = "userProfileIcon"
        static let colorfulIcons = "colorfulIcons"

        // Session / Period
        static let defaultPeriod = "defaultPeriod"
        static let firstWeekday = "firstWeekday"
        static let accountsSortOrderNames = "accountsSortOrderNames"
        static let tagsSortOrderNames = "tagsSortOrderNames"
        static let tabConfigJSON = "tabBarConfiguration"  // ← TabBarConfiguration.storageKey

        // Widget / Trend
        static let showVariations = "showVariations"
        static let showWidgetHints = "showWidgetHints"
        static let averageLineMode = "averageLineMode"

        // Voice / Image / AI
        static let voiceInputEnabled = "voiceInputEnabled"
        static let voiceLanguage = "voiceLanguage"
        static let imageInputEnabled = "imageInputEnabled"
        static let aiDataConsentAccepted = "aiDataConsentAccepted"
        static let aiInsightsConsentAccepted = "aiInsightsConsentAccepted"
        static let aiChatConsentAccepted = "aiChatConsentAccepted"
        static let chatAssistantEnabled = "chatAssistantEnabled"
        static let chatFABVisible = "chatFABVisible"
        static let cashFlowAIEnabled = "cashFlowAIEnabled"
        static let insightsTone = "insightsTone"        // ← InsightTone.storageKey
        static let insightsFocus = "insightsFocus"      // ← InsightFocus.storageKey
        static let autoFocusField = "autoFocusField"

        // Budgets / Alerts
        static let budgetsHideInactive = "budgets.hideInactive"
        static let budgetAlertsEnabled = "budgetAlertsEnabled"

        // UI Feature Flags
        static let showSiriTip = "showSiriTip"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastSeenAppVersion = "lastSeenAppVersion"
        static let expensesOnlyMode = "expensesOnlyMode"

        // One-Off Tours
        static let hasSeenSettingsTour = "hasSeenSettingsTour"
        static let hasSeenCashFlowSetupTour = "hasSeenCashFlowSetupTour"
        static let hasSeenCashFlowTableTour = "hasSeenCashFlowTableTour"
        static let hasSeenGroupsNotificationPrompt = "hasSeenGroupsNotificationPrompt"

        // Insights Section Visibility
        static let insightsShowQuickStats = "insightsShowQuickStats"
        static let insightsShowPendingPayments = "insightsShowPendingPayments"
        static let insightsShowSubscriptions = "insightsShowSubscriptions"
        static let insightsShowBudgetsAtRisk = "insightsShowBudgetsAtRisk"
        static let insightsShowWeekday = "insightsShowWeekday"
        static let insightsShowNature = "insightsShowNature"
        static let insightsShowTexts = "insightsShowTexts"
    }
}
