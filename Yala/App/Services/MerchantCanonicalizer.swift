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
