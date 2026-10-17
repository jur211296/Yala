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
    static func url(to address: String, subject: String) -> URL? {
        guard var components = URLComponents(string: "mailto:\(address)") else { return nil }
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
