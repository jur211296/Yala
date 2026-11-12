//
//  SupportMailLinkLogic.swift
//  Yala
//
//  El enlace `mailto:` de las pantallas que mandan a escribir a soporte (UX 2.2 · L6-9). Con el asunto puesto, quien
//  escribe no tiene que explicar desde qué pantalla viene, y soporte sabe qué mirar.
//

import Foundation

nonisolated enum SupportMailLinkLogic {
    /// `nil` solo si el correo no forma una URL (no ocurre con la constante de soporte). El asunto va codificado:
    /// lleva espacios y acentos.
    /// `body`, si va, también codificado: la pantalla de iCloud mete ahí el detalle técnico (UX 2.2 · L20-14), que ya no
    /// se enseña en pantalla.
    static func url(to address: String, subject: String, body: String? = nil) -> URL? {
        guard var components = URLComponents(string: "mailto:\(address)") else { return nil }
        var items = [URLQueryItem(name: "subject", value: subject)]
        if let body { items.append(URLQueryItem(name: "body", value: body)) }
        components.queryItems = items
        return components.url
    }
}
