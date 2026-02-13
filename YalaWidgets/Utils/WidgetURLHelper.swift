//
//  WidgetURLHelper.swift
//  YalaWidgets
//
//  Created by Claude on 2026-02-03.
//

import Foundation

/// Helper para generar URLs de deeplinks usando el scheme correcto del bundle.
/// Esto permite que los widgets de prod usen `yala://` y los de dev usen `yaladev://`.
enum WidgetURLHelper {
    /// URL scheme leído dinámicamente del Info.plist del widget bundle.
    static var urlScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as? String ?? "yala"
    }

    /// Genera una URL con el scheme correcto para el path dado.
    /// - Parameter path: El path del deeplink (ej: "panel", "statistics/categories")
    /// - Returns: URL formada o nil si el path es inválido
    static func url(for path: String) -> URL? {
        URL(string: "\(urlScheme)://\(path)")
    }
}
