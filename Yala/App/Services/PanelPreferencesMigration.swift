//
//  PanelPreferencesMigration.swift
//  Yala
//
//  One-shot classification of the legacy `panel_widget_configs_v1` JSON blob
//  into per-section order/hidden keys. Idempotent via a local sentinel flag.
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

        var orders: [PanelSectionKind: [String]] = [:]
        var hidden: [PanelSectionKind: [String]] = [:]

        // Corrupt blob or absent key → empty buckets; Panel falls back to defaults.
        if let data = defaults.data(forKey: legacyKey),
           let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
            for config in configs {
                let section = config.type.panelSection
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
        print("PanelPreferencesMigration: completed with \(orders.mapValues(\.count))")
        #endif
    }
}
