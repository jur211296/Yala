//
//  AnomalyKeywords.swift
//  Yala
//
//  Multi-language keyword matcher for "include anomalies in chat context" gating.
//  Liberal matching: false positives are cheap (just adds anomalies to the JSON);
//  false negatives degrade the answer quality, so we err towards over-including.
//

import Foundation

nonisolated enum AnomalyKeywords {

    /// Returns true if the question should trigger anomaly inclusion in the context.
    /// Diacritic-insensitive substring match against a multi-language keyword list.
    static func matches(_ question: String) -> Bool {
        let normalized = question.lowercased().folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
        return keywords.contains { normalized.contains($0) }
    }

    /// Keywords already lowercased + folded (no diacritics) so the matcher only needs
    /// to fold the input once. Order optimized: shorter/common substrings first to
    /// short-circuit the search faster on typical inputs.
    /// Keywords use stems where possible to cover singular/plural/gender variants
    /// across romance languages without listing every form explicitly.
    private static let keywords: [String] = [
        // Cross-language stems (after diacritic folding)
        "anomal",       // anomalía, anomalías, anomalo/a/os/as, anomaly, anomalous, anomalies, anomal (DE)
        "anormal",      // anormal (ES/PT/FR), abnormal (after partial match? no — abnormal is separate)
        "atipic",       // atípico/a/os/as (ES/PT), atipico/a (IT)
        "outlier",      // outlier, outliers (EN)
        // Spanish
        "raro", "rara",
        "inusual",
        "extrano", "extrana",
        "sospechos",     // sospechoso/a
        "fuera de lo normal",
        "se salio", "se salieron",
        "salirse de lo",
        "llamativo", "llamativa",
        // English
        "unusual",
        "weird",
        "strange",
        "abnormal",
        "suspicious",
        "out of the ordinary",
        // German (folding strips umlauts: ungewöhnlich → ungewohnlich)
        "ungewohnlich",
        "seltsam",
        "auffallig",
        "verdachtig",
        // French
        "inhabituel",
        "etrange",
        "atypique",
        "suspect",
        // Italian
        "insolit",       // insolito, insolita, insolite, insoliti
        "strano", "strana",
        "sospett",       // sospetto, sospetta, sospetti
        // Portuguese
        "incomum",
        "estranho",
        "suspeito"
    ]
}
