//
//  PanelPreferencesMigration.swift
//  Yala
//
//  One-shot classification of the legacy `panel_widget_configs_v1` JSON blob
//  into per-section order/hidden keys. Idempotent via a local sentinel flag.
//
//  P20-11: when no legacy blob exists (truly fresh install) we seed the
//  opinionated defaults defined in `AppPreferences.setupDefaultsForNewUser()`
//  instead of bucketizing an empty blob. This ensures a new user lands on
//  the curated Panel 2.0 defaults without waiting for onboarding flow to
//  complete.
//

import Foundation

enum PanelPreferencesMigration {

    /// Legacy storage key managed by `WidgetConfigManager`.
    static let legacyKey = "panel_widget_configs_v1"

    @MainActor
    static func runIfNeeded(
        appPreferences: AppPreferences,
        defaults: UserDefaults = .standard
    ) {
        guard !appPreferences.panelPrefsMigratedV2 else { return }

        guard let legacyBlob = defaults.data(forKey: legacyKey) else {
            // Install fresh — seed opinionated P20-11 defaults so the first
            // Panel open lands on "rich but not saturated".
            appPreferences.setupDefaultsForNewUser()
            appPreferences.panelPrefsMigratedV2 = true
            #if DEBUG
            print("PanelPreferencesMigration: install fresh → setupDefaultsForNewUser applied")
            #endif
            return
        }

        // Upgrade path — bucketize the legacy blob into per-section keys,
        // preserving whatever the user had configured in v1.x.
        var orders: [PanelSectionKind: [String]] = [:]
        var hidden: [PanelSectionKind: [String]] = [:]

        // Only classify into sections that have persisted keys. Single-widget
        // sections (accounts, latestRecords, tools) and the health section
        // are toggled via `panelSectionsHidden`, not per-widget keys.
        let persistedSections: Set<PanelSectionKind> = [.tendencias, .distribucion, .planificacion]

        if let configs = try? JSONDecoder().decode([WidgetConfig].self, from: legacyBlob) {
            for config in configs {
                let section = config.type.panelSection
                guard persistedSections.contains(section) else { continue }
                orders[section, default: []].append(config.type.rawValue)
                if !config.isVisible {
                    hidden[section, default: []].append(config.type.rawValue)
                }
            }
        }

        appPreferences.panelTendenciasOrder     = orders[.tendencias]     ?? []
        appPreferences.panelTendenciasHidden    = hidden[.tendencias]     ?? []
        appPreferences.panelDistribucionOrder   = orders[.distribucion]   ?? []
        appPreferences.panelDistribucionHidden  = hidden[.distribucion]   ?? []
        appPreferences.panelPlanificacionOrder  = orders[.planificacion]  ?? []
        appPreferences.panelPlanificacionHidden = hidden[.planificacion]  ?? []

        appPreferences.panelPrefsMigratedV2 = true

        #if DEBUG
        print("PanelPreferencesMigration: upgrade path → \(orders.mapValues(\.count))")
        #endif
    }
}
