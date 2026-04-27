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
