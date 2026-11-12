//
//  WidgetURLHelper.swift
//  YalaWidgets
//
//  Created by Claude on 2026-02-03.
//

import Foundation

/// Helper compartido para URL scheme y App Group identifier.
/// Membership: Yala main + YalaWidgetsExtension + YalaShare (vía exception sets en pbxproj).
/// Permite que los widgets de prod usen `yala://` y los de dev usen `yaladev://`.
enum WidgetURLHelper {
    /// URL scheme leído dinámicamente del Info.plist del bundle activo.
    nonisolated static var urlScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as? String ?? "yala"
    }

    /// App Group identifier leído del Info.plist del bundle activo.
    nonisolated static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
            ?? "group.com.jurgenschmidt.yala"
    }

    /// Genera una URL con el scheme correcto para el path dado.
    /// - Parameter path: El path del deeplink (ej: "panel", "statistics/categories")
    /// - Returns: URL formada o nil si el path es inválido
    nonisolated static func url(for path: String) -> URL? {
        URL(string: "\(urlScheme)://\(path)")
    }
}

/// Los destinos de los widgets que no son una pestaña a secas. Viven aquí, en el fichero que comparten la app y los
/// widgets, para que un test de la app compruebe que cada uno se entiende (`WidgetDeepLinkTests`).
///
/// UX 2.2 · L15-3 (opción B, Jürgen 2026-10-18): cada widget abre la pantalla que amplía lo que enseña. Antes «Gastos»
/// de inicio y «Entradas y salidas» abrían el Panel, y los de subcategorías la vista de categorías.
nonisolated enum WidgetDeepLink {
    /// «Gastos» (inicio y pantalla bloqueada): Estadísticas › Resumen.
    static let expenses = "statistics/insights"
    /// «Entradas y salidas»: Estadísticas › Tendencias, en esa tarjeta.
    static let inAndOut = "statistics/trends/in-and-out"
    /// Los dos de subcategorías: Estadísticas › Distribución, con las subcategorías a la vista.
    static let subcategories = "statistics/categories/subcategories"
    /// «Aún no tienes pagos planificados · Toca para crear uno» (L15-2): el editor de un pago nuevo.
    static let newScheduledPayment = "planning/scheduled-payments/new"
    /// «Aún no tienes presupuestos · Toca para crear uno» (L15-2): el editor de un presupuesto nuevo.
    static let newBudget = "budgets/new"
}
