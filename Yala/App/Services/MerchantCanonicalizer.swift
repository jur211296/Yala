//
//  MerchantCanonicalizer.swift
//  Yala
//
//  Normaliza nombres de comercios para matching consistente.
//  Fase 8.5: Merchant Memory
//

import Foundation

enum MerchantCanonicalizer {

    /// Prefijos comunes de procesadores de pago a remover
    private static let paymentPrefixes = [
        "DP*", "IZI*", "SQ *", "PAYPAL *", "MPOS*",
        "TSP*", "PAY*", "POS ", "PAGO*"
    ]

    /// Canonicaliza un nombre de comercio crudo a forma normalizada.
    /// Ejemplo: "DP*Starbucks Coffee #123" → "STARBUCKS COFFEE 123"
    static func canonicalize(_ merchantRaw: String) -> String {
        var result = merchantRaw
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remover prefijos de procesadores de pago
        for prefix in paymentPrefixes {
            let upperPrefix = prefix.uppercased()
            if result.hasPrefix(upperPrefix) {
                result = String(result.dropFirst(upperPrefix.count))
            }
        }

        // Colapsar espacios múltiples y remover símbolos no alfanuméricos (excepto espacios)
        result = result
            .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Cómo se le enseña un comercio al usuario (o a un prompt que lo copia tal cual): la nota sin el prefijo del
    /// procesador de pago, y con mayúscula inicial si venía entera en mayúsculas o en minúsculas. Lote 12.4: las
    /// sugerencias de Yala IA recibían el canónico («SUPERMERCADO») y el modelo lo copiaba. Una sigla corta en mayúsculas
    /// («KFC», «BCP») se queda como está.
    static func displayName(for note: String) -> String {
        var text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in paymentPrefixes where text.uppercased().hasPrefix(prefix.uppercased()) {
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty else { return text }
        let allUpper = letters == letters.uppercased() && letters != letters.lowercased()
        let allLower = letters == letters.lowercased() && letters != letters.uppercased()
        if allUpper && !text.contains(" ") && letters.count <= 4 { return text }
        guard allUpper || allLower else { return text }
        return text.split(separator: " ").map { word -> String in
            let lower = word.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    /// Calcula similitud entre dos strings (0.0 = nada, 1.0 = idénticos).
    /// Usa distancia de Levenshtein normalizada.
    static func similarity(_ a: String, _ b: String) -> Double {
        let s1 = a.uppercased()
        let s2 = b.uppercased()
        guard !s1.isEmpty || !s2.isEmpty else { return 1.0 }

        let maxLen = max(s1.count, s2.count)
        let distance = levenshteinDistance(s1, s2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Distancia de Levenshtein entre dos strings.
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,       // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            prev = curr
        }

        return prev[n]
    }
}
