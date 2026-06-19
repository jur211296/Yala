//
//  WidgetConfigManager.swift
//  Yala
//
//  Legacy store for widget `size` (per-widget config that P20-03 does not
//  expose in its per-section preferences sheet).
//
//  Since P20-03, order + visibility live in `AppPreferences.panel<Section>Order/Hidden`.
//  This manager is the silent persistence layer for the remaining fields, read
//  via `PanelViewModel.widgetConfigs` and paired with the per-section SSOT by
//  `PanelViewModel.activeWidgets(in:)`.
//

import Foundation
import SwiftUI

/// Holds widget configurations in `panel_widget_configs_v1` (UserDefaults blob).
/// Since P20-03 the UI no longer mutates these — only render-time reads happen.
@MainActor @Observable
final class WidgetConfigManager {

    // MARK: - State

    /// All widget configurations. Mutations should come from migration/decode paths
    /// only; the UI-driven mutation APIs were removed in P20-03 when the per-section
    /// SSOT moved to `AppPreferences`.
    var configs: [WidgetConfig] = []

    // MARK: - Layout Structures

    enum WidgetRowType {
        case fullWidth(WidgetConfig)
        case halfWidthPair(left: WidgetConfig, right: WidgetConfig?)
    }

    struct WidgetRow: Identifiable {
        let id: UUID
        let type: WidgetRowType
    }

    // MARK: - Constants

    private let storageKey = "panel_widget_configs_v1"

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Persistence

    /// Loads widget configs from UserDefaults. Falls back to defaults on absent
    /// or corrupt blob. Appends defaults for any widget type missing from the
    /// stored array (survives new widgets added in future app versions).
    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            var decoded: [WidgetConfig]
            do {
                decoded = try JSONDecoder().decode([WidgetConfig].self, from: data)
            } catch {
                #if DEBUG
                print("WidgetConfigManager: Error decoding widget configs: \(error)")
                #endif
                self.configs = WidgetConfig.defaultConfigs()
                return
            }
            // Migration: add missing new widget types at tail.
            let defaults = WidgetConfig.defaultConfigs()
            let existingTypes = Set(decoded.map { $0.type })
            for config in defaults where !existingTypes.contains(config.type) {
                decoded.append(config)
            }
            self.configs = decoded
        } else {
            self.configs = WidgetConfig.defaultConfigs()
        }
    }

    /// Saves widget configs to UserDefaults.
    func save() {
        do {
            let encoded = try JSONEncoder().encode(configs)
            UserDefaults.standard.set(encoded, forKey: storageKey)
            TelemetryService.track(.widgetConfigured)
        } catch {
            #if DEBUG
            print("WidgetConfigManager: Error encoding widget configs: \(error)")
            #endif
        }
    }

    // MARK: - Layout Computation

    /// Widget types that always need full width (charts/trends that need horizontal space).
    private static let fullWidthOnlyTypes: Set<WidgetType> = [
        .trend, .cashFlow, .expensesByNeed, .exchangeRate
    ]

    /// Pure layout computation — called by `PanelWidgetsGrid` to render per-section
    /// rows. PP2-05: widgets with `size == .small` pair on both iPhone and iPad;
    /// other sizes keep the prior behaviour (full-width on iPhone, pair on iPad).
    static func makeLayoutRows(for widgets: [WidgetConfig], columns: Int) -> [WidgetRow] {
        var rows: [WidgetRow] = []
        var pendingHalf: WidgetConfig?
        for config in widgets {
            let isFullWidthOnly = fullWidthOnlyTypes.contains(config.type)
            let isHalfCapable = config.size == .small || (columns >= 2 && !isFullWidthOnly)

            if !isHalfCapable {
                if let pending = pendingHalf {
                    rows.append(WidgetRow(id: pending.id, type: .halfWidthPair(left: pending, right: nil)))
                    pendingHalf = nil
                }
                rows.append(WidgetRow(id: config.id, type: .fullWidth(config)))
            } else {
                if let pending = pendingHalf {
                    rows.append(WidgetRow(id: pending.id, type: .halfWidthPair(left: pending, right: config)))
                    pendingHalf = nil
                } else {
                    pendingHalf = config
                }
            }
        }
        if let pending = pendingHalf {
            rows.append(WidgetRow(id: pending.id, type: .halfWidthPair(left: pending, right: nil)))
        }
        return rows
    }
}
