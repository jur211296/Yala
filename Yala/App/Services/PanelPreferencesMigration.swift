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

        // Only classify into sections that have persisted keys. Single-widget
        // sections (latestRecords, tools) and future multi-widget ones without
        // dedicated keys yet (health P20-06, paraTi P20-10) are skipped — their
        // widget state is not persisted per-section.
        let persistedSections: Set<PanelSectionKind> = [.tendencias, .distribucion, .planificacion]

        // Corrupt blob or absent key → empty buckets; Panel falls back to defaults.
        if let data = defaults.data(forKey: legacyKey),
           let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
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
        print("PanelPreferencesMigration: completed with \(orders.mapValues(\.count))")
        #endif
    }
}
