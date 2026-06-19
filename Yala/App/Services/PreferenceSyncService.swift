//
//  PreferenceSyncService.swift
//  Yala
//
//  Syncs critical user preferences via NSUbiquitousKeyValueStore (iCloud Key-Value)
//  so they propagate across devices. NOT synced: hasCompletedOnboarding (per-device).
//

import Foundation
import WidgetKit

// MARK: - Cross-Device Wipe Notifications

extension Notification.Name {
    /// Fired when a remote device initiated a data wipe.
    /// `userInfo["onboardingAlreadyDone"]` (Bool) indicates whether another device already completed onboarding.
    static let remoteWipeDetected = Notification.Name("remoteWipeDetected")

    /// Fired when a remote device completed onboarding after a wipe.
    /// Used to pull a device out of mid-onboarding and show a sync banner instead.
    static let remoteOnboardingCompleted = Notification.Name("remoteOnboardingCompleted")

    /// Fired when iCloud became available after the container was created without CloudKit.
    static let iCloudMismatchDetected = Notification.Name("iCloudMismatchDetected")
}

@MainActor
final class PreferenceSyncService {

    // MARK: - Singleton

    static let shared = PreferenceSyncService()

    // MARK: - Synced Keys

    /// Keys that sync to iCloud via NSUbiquitousKeyValueStore
    private enum SyncKey: String, CaseIterable {
        case defaultCurrencyCode
        case userName
        case defaultPeriod
        case secondaryCurrencies
        case budgetAlertsEnabled
        case expensesOnlyMode
        case userProfileIcon
        case colorfulIcons
        case firstWeekday
        case decimalPlaces
        case currencyDisplayFormat
        case showVariations
        case averageLineMode
        case voiceLanguage
        case autoFocusField
        case accountsSortOrderNames
        case insightsTone
        case insightsFocus
        case financialMindset
        case onboardingMode
        // Panel 2.0 — per-section order/hidden + reserved sectionsHidden (P20-02)
        case panelTendenciasOrder
        case panelTendenciasHidden
        case panelDistribucionOrder
        case panelDistribucionHidden
        case panelPlanificacionOrder
        case panelPlanificacionHidden
        case panelSectionsHidden
        case panelSectionsOrder
        // P20-11 — Cuentas collapse state (synced so state follows across devices)
        case panelAccountsCollapsed
        // M2 (localización) — override de idioma elegido por el usuario, sincronizado cross-device
        case appLanguageOverride
        // A0-Bridge: 3 toggles existing (synced=true desde inicio pero faltaba el enum case)
        case includeGroupTransactionsInFeed
        case includeGroupsInPanelTotal
        case includeGroupTransactionsInStats
        // Bridge opt-out global per-user (synced=true). Cross-device sync de la decisión.
        case bridgeGroupExpensesToPersonalAccounts
    }

    /// Keys for cross-device wipe coordination (iKV = remote, local = UserDefaults)
    private enum WipeKey {
        static let remoteWipe = "lastWipeTimestamp"           // iKV
        static let remoteOnboarding = "lastOnboardingTimestamp" // iKV
        static let localWipe = "lastKnownWipeTimestamp"       // UserDefaults
        static let localOnboarding = "lastKnownOnboardingTimestamp" // UserDefaults
    }

    /// Key for notification userInfo
    static let onboardingAlreadyDoneKey = "onboardingAlreadyDone"

    private let iKV = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var isObserverRegistered = false

    private init() {}

    // MARK: - Bootstrap

    /// Call early in app launch (before services read preferences).
    /// Pulls remote values into UserDefaults and starts observing changes.
    /// Safe to call multiple times (e.g. pull-to-refresh) — observer registered only once.
    func bootstrap() {
        iKV.synchronize()
        applyRemoteValues()

        // Offline catch-up: process any wipe/onboarding signals that arrived while app was closed
        checkForRemoteWipeSignal()

        guard !isObserverRegistered else { return }
        isObserverRegistered = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iKV
        )
    }

    // MARK: - Write (dual-write: local + iKV)

    func set(string value: String, forKey key: String) {
        local.set(value, forKey: key)
        iKV.set(value, forKey: key)
        iKV.synchronize()
    }

    func set(bool value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        iKV.set(value, forKey: key)
        iKV.synchronize()
    }

    func set(int value: Int, forKey key: String) {
        local.set(value, forKey: key)
        iKV.set(value, forKey: key)
        iKV.synchronize()
    }

    // MARK: - Apply Detected Defaults (Risk 1 — "data found" with no currency)

    /// Sets sensible defaults when iCloud data arrives but no preferences exist.
    /// Guards on nil currency — only runs once.
    func applyDetectedDefaultsIfNeeded() {
        guard local.string(forKey: SyncKey.defaultCurrencyCode.rawValue) == nil else { return }

        let currency = CurrencyDefaults.detectCurrencyFromRegion()
        set(string: currency.rawValue, forKey: SyncKey.defaultCurrencyCode.rawValue)
        set(string: DetailPeriod.thisMonth.rawValue, forKey: SyncKey.defaultPeriod.rawValue)

        // Push to SessionState (already alive as singleton)
        SessionState.shared.selectedPeriod = .thisMonth

        #if DEBUG
        print("PreferenceSyncService: Applied detected defaults — currency=\(currency.rawValue)")
        #endif
    }

    // MARK: - Remote → Local merge

    /// Merges iKV values into UserDefaults and pushes to SessionState.
    private func applyRemoteValues() {
        var formattingChanged = false
        var weekdayChanged = false

        for key in SyncKey.allCases {
            let k = key.rawValue

            switch key {
            case .defaultCurrencyCode, .userName, .defaultPeriod, .secondaryCurrencies,
                 .userProfileIcon, .currencyDisplayFormat, .voiceLanguage, .autoFocusField,
                 .accountsSortOrderNames, .insightsTone, .insightsFocus, .financialMindset:
                if let remote = iKV.string(forKey: k), !remote.isEmpty {
                    if local.string(forKey: k) != remote {
                        local.set(remote, forKey: k)
                        if key == .currencyDisplayFormat { formattingChanged = true }
                    }
                }

            case .appLanguageOverride:
                // Storage es App Group suite (compartido con widgets), NO standard.
                let suite = LanguageManager.sharedDefaults
                if iKV.object(forKey: k) != nil {
                    let remote = iKV.string(forKey: k) ?? ""
                    let current = suite.string(forKey: k) ?? ""
                    if current != remote {
                        if remote.isEmpty {
                            suite.removeObject(forKey: k)
                        } else {
                            suite.set(remote, forKey: k)
                        }
                        // Notificar cambio de idioma en caliente para que la UI re-renderice
                        NotificationCenter.default.post(name: .languageDidChange, object: nil)
                    }
                }

            case .panelTendenciasOrder, .panelTendenciasHidden,
                 .panelDistribucionOrder, .panelDistribucionHidden,
                 .panelPlanificacionOrder, .panelPlanificacionHidden,
                 .panelSectionsHidden, .panelSectionsOrder:
                // Empty strings are a valid state (user hid every widget in a section).
                if iKV.object(forKey: k) != nil {
                    let remote = iKV.string(forKey: k) ?? ""
                    if local.string(forKey: k) != remote {
                        local.set(remote, forKey: k)
                    }
                }

            case .onboardingMode:
                // Never-downgrade merge: remote only wins if its rank is higher
                if let remoteRaw = iKV.string(forKey: k), !remoteRaw.isEmpty,
                   let remoteMode = OnboardingMode(rawValue: remoteRaw) {
                    let localMode = OnboardingMode.current()
                    if remoteMode.rank > localMode.rank {
                        local.set(remoteRaw, forKey: k)
                    }
                }

            case .budgetAlertsEnabled, .expensesOnlyMode, .colorfulIcons, .showVariations,
                 .panelAccountsCollapsed,
                 .includeGroupTransactionsInFeed, .includeGroupsInPanelTotal,
                 .includeGroupTransactionsInStats, .bridgeGroupExpensesToPersonalAccounts:
                if iKV.object(forKey: k) != nil {
                    local.set(iKV.bool(forKey: k), forKey: k)
                }

            case .firstWeekday, .decimalPlaces, .averageLineMode:
                if iKV.object(forKey: k) != nil {
                    let remote = Int(iKV.longLong(forKey: k))
                    if local.integer(forKey: k) != remote {
                        local.set(remote, forKey: k)
                        if key == .decimalPlaces { formattingChanged = true }
                        if key == .firstWeekday { weekdayChanged = true }
                    }
                }
            }
        }

        // Push to SessionState (critical: init() already ran with possibly empty values)
        if let rawPeriod = local.string(forKey: SyncKey.defaultPeriod.rawValue),
           let period = DetailPeriod(rawValue: rawPeriod) {
            SessionState.shared.selectedPeriod = period
        }

        // expensesOnlyMode didSet propagates to app group + WidgetCenter.
        // Guard against assigning when the key is absent: Swift's didSet fires even
        // when the value doesn't change, which would write the default `false` to
        // UserDefaults and contaminate fresh-install detection in OnboardingView.
        if local.object(forKey: SyncKey.expensesOnlyMode.rawValue) != nil {
            SessionState.shared.isExpensesOnlyMode = local.bool(forKey: SyncKey.expensesOnlyMode.rawValue)
        }

        // financialMindset (educational UI only)
        if let mindset = local.string(forKey: SyncKey.financialMindset.rawValue), !mindset.isEmpty {
            SessionState.shared.financialMindset = mindset
        }

        // onboardingMode (never-downgrade already applied above)
        SessionState.shared.onboardingMode = OnboardingMode.current()

        // Trigger UI refresh when formatting preferences change remotely
        if formattingChanged {
            SessionState.shared.formattingVersion += 1
        }

        // Sync firstWeekday to App Group for widgets
        if weekdayChanged {
            if let defaults = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
                defaults.set(local.integer(forKey: SyncKey.firstWeekday.rawValue), forKey: "firstWeekday")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Cross-Device Wipe Signaling

    /// Called by DataWipeService BEFORE deleting data — signals other devices that a wipe occurred.
    func signalWipeInitiated() {
        let timestamp = Date.now.timeIntervalSince1970
        iKV.set(timestamp, forKey: WipeKey.remoteWipe)
        iKV.synchronize()

        // Save locally so THIS device doesn't react to its own signal
        local.set(timestamp, forKey: WipeKey.localWipe)

        #if DEBUG
        print("PreferenceSyncService: Signaled wipe initiated (timestamp=\(timestamp))")
        #endif
    }

    /// Called after onboarding completes — signals other devices that onboarding is done.
    func signalOnboardingCompleted() {
        let timestamp = Date.now.timeIntervalSince1970
        iKV.set(timestamp, forKey: WipeKey.remoteOnboarding)
        iKV.synchronize()

        // Save locally to avoid redundant processing
        local.set(timestamp, forKey: WipeKey.localOnboarding)

        #if DEBUG
        print("PreferenceSyncService: Signaled onboarding completed (timestamp=\(timestamp))")
        #endif
    }

    /// Checks for remote wipe/onboarding signals and posts notifications.
    /// Called from iCloudDidChange and bootstrap (offline catch-up).
    private func checkForRemoteWipeSignal() {
        let remoteWipe = iKV.double(forKey: WipeKey.remoteWipe)
        let localWipe = local.double(forKey: WipeKey.localWipe)
        let remoteOnboarding = iKV.double(forKey: WipeKey.remoteOnboarding)
        let localOnboarding = local.double(forKey: WipeKey.localOnboarding)

        // Caso A: Nueva señal de wipe (remoteWipe > localWipe)
        if remoteWipe > 0 && remoteWipe > localWipe {
            // Mark as processed so we don't react again
            local.set(remoteWipe, forKey: WipeKey.localWipe)

            let onboardingAlreadyDone = remoteOnboarding > remoteWipe

            // Bug #6 P0 mitigation: evaluate the decider at SIGNAL TIME (not drain
            // time). If hasCompletedOnboarding=false right now (fresh-install with
            // contaminated KV-Store), don't submit the intent — otherwise the
            // readiness gate would park it across the onboarding session and
            // process it post-onboarding, wiping the user's fresh data.
            let hasCompletedOnboarding = local.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
            let decision = RemoteWipeSignalDecider.decide(
                hasCompletedOnboarding: hasCompletedOnboarding,
                isWipingData: SessionState.shared.isWipingData,
                hasRemoteWipeTimestamp: remoteWipe > 0
            )

            #if DEBUG
            print("PreferenceSyncService: Remote wipe detected (onboardingAlreadyDone=\(onboardingAlreadyDone), shouldProcess=\(decision.shouldProcess))")
            #endif

            // Mid-onboarding silencing: mark BOTH timestamps so neither Caso A nor B
            // re-fires post-onboarding. Mirrors ContentView.markRemoteSignalsAsProcessed.
            if decision.shouldMarkSignalsAsProcessed {
                if remoteOnboarding > 0 {
                    local.set(remoteOnboarding, forKey: WipeKey.localOnboarding)
                }
            }

            guard decision.shouldProcess else { return }

            RouterEntryGate.shared.submit(.remoteWipe(skipOnboarding: onboardingAlreadyDone))
            return
        }

        // Caso B: Wipe ya procesado, pero onboarding remoto nuevo
        // (another device completed onboarding after a wipe we already processed)
        if remoteWipe > 0 && remoteWipe == localWipe
            && remoteOnboarding > remoteWipe
            && remoteOnboarding > localOnboarding {

            local.set(remoteOnboarding, forKey: WipeKey.localOnboarding)

            #if DEBUG
            print("PreferenceSyncService: Remote onboarding completed after wipe")
            #endif

            // Dual-path: also post to NotificationCenter so the ContentView
            // observer can dismiss a visible onboarding screen INSTANTLY,
            // bypassing the readiness gate (which blocks .contentView drain
            // while showOnboarding=true — defeating the purpose of this signal).
            NotificationCenter.default.post(name: .remoteOnboardingCompleted, object: nil)
            RouterEntryGate.shared.submit(.remoteOnboardingCompleted)
        }
    }

    // MARK: - External Change Observer

    @objc private func iCloudDidChange(_ notification: Notification) {
        Task { @MainActor in
            self.applyRemoteValues()
            self.checkForRemoteWipeSignal()

            #if DEBUG
            print("PreferenceSyncService: Applied remote iKV changes")
            #endif
        }
    }
}
