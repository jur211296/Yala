//
//  WidgetConfigManager.swift
//  Yala
//
//  Manages widget configuration persistence and state.
//

import Foundation
import SwiftUI

/// Manages widget configurations including persistence, visibility, and ordering.
/// Extracted from PanelViewModel for better separation of concerns.
@MainActor @Observable
final class WidgetConfigManager {

    // MARK: - State

    /// All widget configurations
    var configs: [WidgetConfig] = [] {
        didSet {
            layoutRows = computeLayoutRows()
        }
    }

    /// Computed layout rows for the view
    var layoutRows: [WidgetRow] = []

    /// Number of columns (1 = compact/iPhone, 2 = regular/iPad)
    var columns: Int = 1 {
        didSet {
            if oldValue != columns {
                layoutRows = computeLayoutRows()
            }
        }
    }

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

    /// Loads widget configs from UserDefaults
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
                self.layoutRows = computeLayoutRows()
                return
            }
            // Migration: Add missing new widgets
            let defaults = WidgetConfig.defaultConfigs()
            let existingTypes = Set(decoded.map { $0.type })

            for config in defaults {
                if !existingTypes.contains(config.type) {
                    decoded.append(config)
                }
            }

            self.configs = decoded
        } else {
            // Default configuration
            self.configs = WidgetConfig.defaultConfigs()
        }
        // Force layout update on initial load
        self.layoutRows = computeLayoutRows()
    }

    /// Saves widget configs to UserDefaults
    func save() {
        do {
            let encoded = try JSONEncoder().encode(configs)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            #if DEBUG
            print("WidgetConfigManager: Error encoding widget configs: \(error)")
            #endif
        }
    }

    /// Resets widget configs to defaults
    func reset() {
        self.configs = WidgetConfig.defaultConfigs()
        save()
    }

    // MARK: - Queries

    /// Returns only visible widgets
    func activeWidgets() -> [WidgetConfig] {
        return configs.filter { $0.isVisible }
    }

    /// Returns the set of active widget types (for lazy evaluation)
    func activeTypes() -> Set<WidgetType> {
        return Set(activeWidgets().map { $0.type })
    }

    // MARK: - Mutations

    /// Toggles visibility for a widget
    func toggleVisibility(id: UUID) {
        if let index = configs.firstIndex(where: { $0.id == id }) {
            // Locked widgets cannot be hidden
            if configs[index].isLocked { return }

            configs[index].isVisible.toggle()
            save()
        }
    }

    /// Updates the size of a widget
    func updateSize(id: UUID, newSize: WidgetSize) {
        if let index = configs.firstIndex(where: { $0.id == id }) {
            // Locked widgets have fixed size
            if configs[index].isLocked { return }

            configs[index].size = newSize
            save()
        }
    }

    /// Updates the scheduled payments widget mode
    func updateScheduledPaymentsMode(id: UUID, mode: ScheduledPaymentsWidgetMode) {
        if let index = configs.firstIndex(where: { $0.id == id }) {
            configs[index].scheduledPaymentsMode = mode
            save()
        }
    }

    /// Moves a widget in the order
    func move(from source: IndexSet, to destination: Int) {
        var newConfigs = configs
        newConfigs.move(fromOffsets: source, toOffset: destination)

        self.configs = newConfigs
        save()
    }

    // MARK: - Layout Computation

    /// Widget types that always need full width (charts/trends that need horizontal space)
    private static let fullWidthOnlyTypes: Set<WidgetType> = [
        .trend, .cashFlow, .expensesByNature, .exchangeRate
    ]

    /// Computes layout rows based on current active widgets and column count
    private func computeLayoutRows() -> [WidgetRow] {
        let widgets = activeWidgets()
        var rows: [WidgetRow] = []

        if columns >= 2 {
            // iPad: pair compatible widgets side by side
            // Full width only for types that need horizontal space (trends, charts with bars)
            var pendingHalf: WidgetConfig?
            for config in widgets {
                let needsFullWidth = Self.fullWidthOnlyTypes.contains(config.type)

                if needsFullWidth {
                    // Flush any pending half-width first
                    if let pending = pendingHalf {
                        rows.append(WidgetRow(id: UUID(), type: .halfWidthPair(left: pending, right: nil)))
                        pendingHalf = nil
                    }
                    rows.append(WidgetRow(id: UUID(), type: .fullWidth(config)))
                } else {
                    // Pairable widget
                    if let pending = pendingHalf {
                        rows.append(WidgetRow(id: UUID(), type: .halfWidthPair(left: pending, right: config)))
                        pendingHalf = nil
                    } else {
                        pendingHalf = config
                    }
                }
            }
            // Flush remaining unpaired widget
            if let pending = pendingHalf {
                rows.append(WidgetRow(id: UUID(), type: .halfWidthPair(left: pending, right: nil)))
            }
        } else {
            // iPhone: all full width
            for config in widgets {
                rows.append(WidgetRow(id: UUID(), type: .fullWidth(config)))
            }
        }
        return rows
    }
}
