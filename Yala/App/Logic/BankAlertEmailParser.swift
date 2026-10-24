//
//  BankAlertEmailParser.swift
//  Yala
//
//  Lee un aviso de movimiento que el banco manda por correo (hoy, el BCP) y saca lo que necesita un borrador de la
//  Bandeja: importe con su signo, divisa y comercio. Sin IA y sin red: texto en, campos fuera.
//
//  Es la pieza de la fase 1 de «Conectar Gmail» (encargo 2026-10-23), que solo existe en Yala Dev para grabar el
//  video de la verificación de Google. La versión final lee el correo en el servidor (roadmap 2.3, «Correo del
//  banco»); este lector se queda como respaldo y como banco de pruebas de los formatos.
//
//  Tolerante a propósito: lo que no reconoce lo deja en `nil` y el borrador pide ese dato, nunca lo inventa.
//

import Foundation

nonisolated enum BankAlertEmailParser {

    /// Lo que se pudo leer de un aviso. `amount` va firmado como en el resto de borradores: gasto negativo.
    struct Result: Equatable {
        var amount: Double?
        var currencyCode: String?
        var merchant: String?
    }

    /// Remitentes de avisos que la fase 1 sabe leer. La búsqueda en Gmail se arma con ellos.
    static let knownSenders: [String] = [
        "notificaciones@notificacionesbcp.com.pe"
    ]

    /// Etiquetas del importe, de la más específica a la más genérica. La primera que tenga una cifra detrás gana.
    private static let amountLabels: [String] = [
        "monto total", "total del consumo", "monto del consumo", "monto transferido", "monto pagado",
        "importe total", "monto", "importe", "total"
    ]

    /// Etiquetas del comercio o destinatario.
    private static let merchantLabels: [String] = [
        "empresa", "comercio", "establecimiento", "lugar", "destinatario", "enviado a", "beneficiario"
    ]

    /// Palabras que convierten el movimiento en ingreso. Todo lo demás se lee como gasto, el default del Inbox.
    private static let incomeMarkers: [String] = [
        "recibiste", "te depositaron", "abono", "depósito recibido", "te transfirieron", "te yapearon"
    ]

    static func parse(subject: String, body: String) -> Result {
        let text = normalizeWhitespace(body)
        let lowered = text.lowercased()
        let money = labeledMoney(in: text, lowered: lowered) ?? firstMoney(in: text)
        let isIncome = incomeMarkers.contains { lowered.contains($0) || subject.lowercased().contains($0) }
        let signed = money.map { isIncome ? abs($0.amount) : -abs($0.amount) }
        return Result(amount: signed, currencyCode: money?.currency, merchant: merchant(in: text))
    }

    // MARK: - Importe

    /// Símbolo o código de divisa, espacio opcional y cifra con separadores de miles y decimales.
    private static let moneyPattern =
        #"(S/\.?|PEN|US\$|USD|\$)\s?([0-9]{1,3}(?:[.,\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)"#

    private struct Money { let amount: Double; let currency: String }

    private static func labeledMoney(in text: String, lowered: String) -> Money? {
        for label in amountLabels {
            var searchStart = lowered.startIndex
            while let range = lowered.range(of: label, range: searchStart..<lowered.endIndex) {
                // Lo que sigue a la etiqueta, hasta 40 caracteres: «Monto total: S/ 45.90», «Monto total\nS/ 45.90».
                let offset = lowered.distance(from: lowered.startIndex, to: range.upperBound)
                let start = text.index(text.startIndex, offsetBy: offset)
                let end = text.index(start, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
                if let money = firstMoney(in: String(text[start..<end])) { return money }
                searchStart = range.upperBound
            }
        }
        return nil
    }

    private static let moneyRegex: NSRegularExpression? = {
        do {
            return try NSRegularExpression(pattern: moneyPattern)
        } catch {
            #if DEBUG
            print("BankAlertEmailParser: Error: \(error)")
            #endif
            return nil
        }
    }()

    private static func firstMoney(in text: String) -> Money? {
        guard let regex = moneyRegex else { return nil }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let symbol = ns.substring(with: match.range(at: 1))
            let number = ns.substring(with: match.range(at: 2))
            guard let value = parseNumber(number), value > 0 else { continue }
            return Money(amount: value, currency: currency(forSymbol: symbol))
        }
        return nil
    }

    private static func currency(forSymbol symbol: String) -> String {
        symbol.hasPrefix("S/") || symbol == "PEN" ? "PEN" : "USD"
    }

    /// «1,234.56», «1.234,56», «1 234,56», «45.90», «45,90» y «45». El último separador con 1-2 cifras detrás es el
    /// decimal; el resto son miles.
    static func parseNumber(_ raw: String) -> Double? {
        let compact = raw.replacingOccurrences(of: " ", with: "")
        guard let lastSeparator = compact.lastIndex(where: { $0 == "," || $0 == "." }) else {
            return Double(compact)
        }
        let decimals = compact[compact.index(after: lastSeparator)...]
        let integerPart = compact[..<lastSeparator].filter(\.isNumber)
        if decimals.count <= 2 {
            return Double("\(integerPart).\(decimals)")
        }
        // Tres cifras detrás: era separador de miles.
        return Double(compact.filter(\.isNumber))
    }

    // MARK: - Comercio

    private static func merchant(in text: String) -> String? {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        for label in merchantLabels {
            for (index, line) in lines.enumerated() where startsWithLabel(line, label) {
                let rest = line.dropFirst(label.count).trimmingCharacters(in: CharacterSet(charactersIn: ": \t"))
                if let value = cleanMerchant(rest) { return value }
                // La etiqueta sola en su línea y el valor en la siguiente (así sale una tabla HTML pasada a texto).
                if index + 1 < lines.count, let value = cleanMerchant(lines[index + 1]) { return value }
            }
        }
        return nil
    }

    /// La línea empieza por la etiqueta como palabra entera: «Empresa: X» sí, «Empresas del grupo BCP» no.
    private static func startsWithLabel(_ line: String, _ label: String) -> Bool {
        let lowered = line.lowercased()
        guard lowered.hasPrefix(label) else { return false }
        guard let next = lowered.dropFirst(label.count).first else { return true }
        return next == ":" || next == " " || next == "\t"
    }

    private static func cleanMerchant(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 60, firstMoney(in: value) == nil else { return nil }
        return value
    }

    // MARK: - Texto

    /// Pasa un cuerpo HTML a texto con un salto por bloque, y deja un solo espacio dentro de cada línea.
    static func plainText(fromHTML html: String) -> String {
        var text = html
        let replacements: [(String, String)] = [
            (#"(?is)<(script|style)[^>]*>.*?</\1>"#, ""),
            (#"(?i)<br\s*/?>"#, "\n"),
            (#"(?i)</(p|div|tr|td|th|li|h[1-6]|table)>"#, "\n"),
            (#"(?s)<[^>]+>"#, " ")
        ]
        for (pattern, template) in replacements {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
                        "&aacute;": "á", "&eacute;": "é", "&iacute;": "í", "&oacute;": "ó", "&uacute;": "ú",
                        "&ntilde;": "ñ", "&Aacute;": "Á", "&Eacute;": "É", "&Iacute;": "Í", "&Oacute;": "Ó",
                        "&Uacute;": "Ú", "&Ntilde;": "Ñ"]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        return normalizeWhitespace(text)
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"[ \t\u{00A0}]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
