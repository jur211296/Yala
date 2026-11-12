//
//  ErrorReportScrubLogic.swift
//  Yala
//
//  Lo que se puede y lo que no se puede mandar a Sentry, sin depender del SDK (testeable en unit).
//  Yala maneja importes, nombres de cuentas y de grupos, correos y notas: nada de eso sale en un aviso de error.
//

import Foundation

/// `nonisolated`: Sentry llama a `beforeSend` y `beforeBreadcrumb` desde sus propias colas.
nonisolated enum ErrorReportScrubLogic {

    /// Lo que va a Sentry tras las reglas del SDK: si el DSN de la build no se resolvió, el SDK no arranca.
    static func usableDSN(_ raw: String?) -> String? {
        guard let dsn = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !dsn.isEmpty else { return nil }
        // Un `$(SENTRY_DSN)` sin sustituir (xcconfig sin la clave) o un DSN cortado por el `//` del xcconfig.
        guard !dsn.contains("$("), dsn.hasPrefix("https://"), dsn.contains("@") else { return nil }
        return dsn
    }

    private static let replacements: [(pattern: String, template: String)] = [
        // Tokens antes que nada: un JWT contiene puntos y cifras que las reglas de importes partirían.
        (#"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)?"#, "[token]"),
        (#"(?i)\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+"#, "$1 [token]"),
        (#"\b(?:sk|pk|rk)-[A-Za-z0-9_-]{8,}"#, "[token]"),
        (#"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "[email]"),
        // Un símbolo o código de divisa pegado a una cifra («S/ 12», «$9», «PEN 120»).
        (#"(?:[$€£¥₹]|S/\.?|\b[A-Z]{3}\s?)\s?-?\d[\d.,]*"#, "[monto]"),
        // Una cifra con decimales («12.50», «1,234.5»).
        (#"-?\b\d{1,3}(?:[.,]\d{3})*[.,]\d{1,2}\b"#, "[monto]"),
    ]

    private static let expressions: [(NSRegularExpression, String)] = replacements.compactMap { item in
        do {
            return (try NSRegularExpression(pattern: item.pattern), item.template)
        } catch {
            #if DEBUG
            print("ErrorReportScrubLogic: Error: \(error)")
            #endif
            return nil
        }
    }

    /// Tapa en un texto libre lo que puede ser un dato personal o financiero.
    static func scrubText(_ text: String) -> String {
        expressions.reduce(text) { current, item in
            let range = NSRange(current.startIndex..., in: current)
            return item.0.stringByReplacingMatches(in: current, range: range, withTemplate: item.1)
        }
    }

    /// La URL sin query ni fragmento: las queries llevan fechas, divisas y cursores del usuario.
    static func stripQuery(_ url: String) -> String {
        guard let cut = url.firstIndex(where: { $0 == "?" || $0 == "#" }) else { return url }
        return String(url[..<cut])
    }

    /// Lo que queda del `data` de un breadcrumb. De uno HTTP, el método, la URL sin query y el status; de cualquier
    /// otro, nada: sus datos pueden ser el texto de una pantalla.
    static func breadcrumbData(category: String, type: String?, data: [String: Any]?) -> [String: Any]? {
        guard let data, category == "http" || type == "http" else { return nil }
        var kept: [String: Any] = [:]
        if let method = data["method"] { kept["method"] = method }
        if let url = data["url"] as? String { kept["url"] = stripQuery(url) }
        if let status = data["status_code"] { kept["status_code"] = status }
        return kept.isEmpty ? nil : kept
    }
}
