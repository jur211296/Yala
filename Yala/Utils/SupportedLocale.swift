//
//  SupportedLocale.swift
//  Yala
//
//  Single source of truth para idiomas y variantes regionales soportados.
//  Cada `case` mapea 1:1 con un `.lproj` en `Yala/Resources/`.
//  Añadir un idioma nuevo: agregar case + entry en `metadata` + crear .lproj.
//

import Foundation

enum SupportedLocale: String, CaseIterable, Identifiable, Hashable {
    case es = "es"            // Alias catch-all — copia idéntica de es-419
    case es419 = "es-419"     // LatAm neutro (base hispana de Yala)
    case esES = "es-ES"       // España (overrides peninsulares)
    case esAR = "es-AR"       // Argentina (voseo gramatical)
    case en = "en"
    case enGB = "en-GB"       // Reino Unido / Australia / Irlanda
    case pt = "pt"            // Alias catch-all — copia idéntica de pt-BR
    case ptBR = "pt-BR"       // Brasil (base lusófona de Yala)
    case ptPT = "pt-PT"       // Portugal (overrides peninsulares)
    case de = "de"
    case fr = "fr"
    case it = "it"
    case nl = "nl"
    case pl = "pl"            // 4 reglas plurales (one/few/many/other)
    case ja = "ja"            // sin distinción singular/plural
    case zhHans = "zh-Hans"   // chino simplificado

    // MARK: - Identifiers

    var id: String { rawValue }
    var code: String { rawValue }
    var bundleResourceName: String { rawValue }

    // MARK: - Display metadata

    /// `(nativeName, flag, parent)` por case. Centraliza las 3 properties que antes
    /// eran 3 switches separados con 16 ramas cada uno.
    private static let metadata: [SupportedLocale: (nativeName: String, flag: String, parent: SupportedLocale?)] = [
        .es:     ("Español",                "🌎", nil),       // alias → es-419 vía canonicalize
        .es419:  ("Español (Latinoamérica)", "🌎", nil),
        .esES:   ("Español (España)",       "🇪🇸", .es419),
        .esAR:   ("Español (Argentina)",    "🇦🇷", .es419),
        .en:     ("English (US)",           "🇺🇸", nil),
        .enGB:   ("English (UK)",           "🇬🇧", .en),
        .pt:     ("Português",              "🇧🇷", nil),       // alias → pt-BR vía canonicalize
        .ptBR:   ("Português (Brasil)",     "🇧🇷", nil),
        .ptPT:   ("Português (Portugal)",   "🇵🇹", .ptBR),
        .de:     ("Deutsch",                "🇩🇪", nil),
        .fr:     ("Français",               "🇫🇷", nil),
        .it:     ("Italiano",               "🇮🇹", nil),
        .nl:     ("Nederlands",             "🇳🇱", nil),
        .pl:     ("Polski",                 "🇵🇱", nil),
        .ja:     ("日本語",                  "🇯🇵", nil),
        .zhHans: ("简体中文",                "🇨🇳", nil)
    ]

    var nativeName: String { Self.metadata[self]!.nativeName }
    var flag: String       { Self.metadata[self]!.flag }
    /// Padre para fallback chain. nil = locale base.
    /// `ls()` busca en el padre cuando una key falta en la variante.
    var parent: SupportedLocale? { Self.metadata[self]!.parent }

    // MARK: - Selection / matching

    /// Cases que aparecen en el selector del usuario. Aliases catch-all (`es`, `pt`)
    /// se excluyen — están cubiertos por las variantes canónicas con bandera explícita.
    static var selectableCases: [SupportedLocale] {
        allCases.filter { $0 != .pt && $0 != .es }
    }

    /// Region → variante canónica para usuarios sin variante explícita en preferredLanguages.
    private static let regionMap: [String: SupportedLocale] = [
        "BR": .ptBR,
        "PT": .ptPT, "AO": .ptPT, "MZ": .ptPT, "CV": .ptPT, "GW": .ptPT, "ST": .ptPT, "TL": .ptPT,
        "ES": .esES,
        "AR": .esAR,
        "GB": .enGB, "AU": .enGB, "IE": .enGB, "NZ": .enGB
    ]

    /// Resolver el código preferido del usuario contra los soportados.
    /// Chain: exact match → region map → idioma base → en.
    static func bestMatch(forPreferredLanguages preferred: [String], region: String?) -> SupportedLocale {
        for code in preferred {
            if let exact = SupportedLocale(rawValue: code) {
                return canonicalize(exact)
            }
        }
        if let region, let mapped = regionMap[region] { return mapped }
        for code in preferred {
            let base = String(code.prefix(2))
            if let baseMatch = SupportedLocale(rawValue: base) {
                return canonicalize(baseMatch)
            }
        }
        return .en
    }

    /// Resolver alias catch-all a variante canónica (pt → pt-BR, es → es-419).
    private static func canonicalize(_ locale: SupportedLocale) -> SupportedLocale {
        switch locale {
        case .pt: return .ptBR
        case .es: return .es419
        default: return locale
        }
    }

    /// Construye un `SupportedLocale` desde un código BCP-47 (e.g. "es-MX" → .es).
    /// Útil para extraer la base de un identifier compuesto.
    static func from(_ identifier: String) -> SupportedLocale? {
        if let exact = SupportedLocale(rawValue: identifier) { return exact }
        let base = String(identifier.prefix(2))
        return SupportedLocale(rawValue: base)
    }
}
