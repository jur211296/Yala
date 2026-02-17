//
//  PreferenceSyncService.swift
//  Yala
//
//  Syncs critical user preferences via NSUbiquitousKeyValueStore (iCloud Key-Value)
//  so they propagate across devices. NOT synced: hasCompletedOnboarding (per-device).
//

import Foundation

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
    }

    private let iKV = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    private init() {}

    // MARK: - Bootstrap

    /// Call early in app launch (before services read preferences).
    /// Pulls remote values into UserDefaults and starts observing changes.
    func bootstrap() {
        iKV.synchronize()
        applyRemoteValues()

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
        for key in SyncKey.allCases {
            let k = key.rawValue

            switch key {
            case .defaultCurrencyCode, .userName, .defaultPeriod, .secondaryCurrencies:
                if let remote = iKV.string(forKey: k), !remote.isEmpty {
                    local.set(remote, forKey: k)
                }

            case .budgetAlertsEnabled, .expensesOnlyMode:
                // iKV returns 0 for unset bools — only overwrite if the key actually exists
                if iKV.object(forKey: k) != nil {
                    local.set(iKV.bool(forKey: k), forKey: k)
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
    }

    // MARK: - External Change Observer

    @objc private func iCloudDidChange(_ notification: Notification) {
        Task { @MainActor in
            self.applyRemoteValues()

            #if DEBUG
            print("PreferenceSyncService: Applied remote iKV changes")
            #endif
        }
    }
}
