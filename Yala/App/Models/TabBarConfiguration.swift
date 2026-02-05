//
//  TabBarConfiguration.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation

/// Tabs que el usuario puede mostrar u ocultar del TabView principal
enum ConfigurableTab: String, Codable, CaseIterable, Identifiable {
    case panel
    case statistics
    case planning
    case records

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .panel: return L10n.Tab.panel
        case .statistics: return L10n.Tab.statistics
        case .planning: return L10n.Tab.planning
        case .records: return L10n.Tab.records
        }
    }

    var iconName: String {
        switch self {
        case .panel: return "rectangle.grid.2x2.fill"
        case .statistics: return "chart.bar.fill"
        case .planning: return "calendar"
        case .records: return "list.bullet.rectangle"
        }
    }

    /// Convierte a AppTab para usar en TabView selection
    var appTab: AppTab {
        switch self {
        case .panel: return .panel
        case .statistics: return .statistics
        case .planning: return .planning
        case .records: return .records
        }
    }
}

/// Configuración de qué tabs mostrar en el TabView principal
struct TabBarConfiguration: Codable, Equatable {
    /// Tabs activos en el TabView (mín 1, máx 3)
    var activeTabs: [ConfigurableTab]

    /// Tabs que no están en el TabView y aparecen en "Más"
    var inactiveTabs: [ConfigurableTab] {
        ConfigurableTab.allCases.filter { !activeTabs.contains($0) }
    }

    /// Configuración por defecto: todos los tabs visibles
    static let `default` = TabBarConfiguration(
        activeTabs: [.panel, .statistics, .planning]
    )

    /// Valida que la configuración cumpla las reglas (1-3 tabs)
    var isValid: Bool {
        activeTabs.count >= 1 && activeTabs.count <= 3
    }

    /// Intenta activar un tab. Retorna false si ya hay 3 activos.
    mutating func activate(_ tab: ConfigurableTab) -> Bool {
        guard !activeTabs.contains(tab) else { return true }
        guard activeTabs.count < 3 else { return false }
        activeTabs.append(tab)
        return true
    }

    /// Intenta desactivar un tab. Retorna false si solo queda 1 activo o si es .panel (siempre requerido).
    mutating func deactivate(_ tab: ConfigurableTab) -> Bool {
        guard tab != .panel else { return false } // Panel is always required
        guard activeTabs.contains(tab) else { return true }
        guard activeTabs.count > 1 else { return false }
        activeTabs.removeAll { $0 == tab }
        return true
    }

    /// Valida y corrige la configuración para asegurar que .panel esté siempre primero
    mutating func ensurePanelFirst() {
        // Add panel if missing
        if !activeTabs.contains(.panel) {
            activeTabs.insert(.panel, at: 0)
        }
        // Move panel to first position if not already
        if let panelIndex = activeTabs.firstIndex(of: .panel), panelIndex != 0 {
            activeTabs.remove(at: panelIndex)
            activeTabs.insert(.panel, at: 0)
        }
    }
}

// MARK: - AppStorage Support

extension TabBarConfiguration {
    /// Key para @AppStorage
    static let storageKey = "tabBarConfiguration"

    /// Serializa a JSON string para @AppStorage
    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
            let string = String(data: data, encoding: .utf8)
        else {
            return Self.default.toJSON()
        }
        return string
    }

    /// Deserializa desde JSON string
    static func fromJSON(_ string: String) -> TabBarConfiguration {
        guard let data = string.data(using: .utf8),
            var config = try? JSONDecoder().decode(TabBarConfiguration.self, from: data),
            config.isValid
        else {
            return .default
        }
        // Ensure panel is always first
        config.ensurePanelFirst()
        return config
    }
}
