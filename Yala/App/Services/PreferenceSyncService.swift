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

            case .budgetAlertsEnabled, .expensesOnlyMode, .colorfulIcons, .showVariations:
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

        // expensesOnlyMode didSet propagates to app group + WidgetCenter
        SessionState.shared.isExpensesOnlyMode = local.bool(forKey: SyncKey.expensesOnlyMode.rawValue)

        // financialMindset (educational UI only)
        if let mindset = local.string(forKey: SyncKey.financialMindset.rawValue), !mindset.isEmpty {
            SessionState.shared.financialMindset = mindset
        }

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

            #if DEBUG
            print("PreferenceSyncService: Remote wipe detected (onboardingAlreadyDone=\(onboardingAlreadyDone))")
            #endif

            NotificationCenter.default.post(
                name: .remoteWipeDetected,
                object: nil,
                userInfo: [Self.onboardingAlreadyDoneKey: onboardingAlreadyDone]
            )
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

            NotificationCenter.default.post(
                name: .remoteOnboardingCompleted,
                object: nil
            )
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
