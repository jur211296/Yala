//
//  SupportedLocale.swift
//  Yala
//
//  Single source of truth para idiomas y variantes regionales soportados.
//  Añadir un idioma nuevo: agregar case + properties + verificar que existe la .lproj.
//
//  Hoy solo expone los 6 idiomas históricos. Cada milestone de localización
//  añade su case en el mismo commit que crea la .lproj correspondiente
//  (evita falsos positivos en tests y bundle nil silencioso).
//

import Foundation

enum SupportedLocale: String, CaseIterable, Identifiable, Hashable {
    case es = "es"        // Alias catch-all (copia idéntica de es-419)
    case es419 = "es-419" // LatAm neutro (base hispana de Yala)
    case esES = "es-ES"   // España (overrides peninsulares)
    case esAR = "es-AR"   // Argentina (voseo gramatical — única variante país justificada)
    case en = "en"
    case enGB = "en-GB"   // Reino Unido / Australia / Irlanda (overrides ortográficos)
    case pt = "pt"        // Alias catch-all (copia idéntica de pt-BR)
    case ptBR = "pt-BR"   // Brasil (base lusófona neutra de Yala)
    case ptPT = "pt-PT"   // Portugal (overrides hacia portugués europeo)
    case de = "de"
    case fr = "fr"
    case it = "it"
    case nl = "nl"        // Países Bajos
    case pl = "pl"        // Polonia (4 reglas plurales: one/few/many/other)

    var id: String { rawValue }
    var code: String { rawValue }

    /// Nombre del recurso bundle (`.lproj`). Hoy coincide con `rawValue` en todos
    /// los casos. Cuando aparezcan variantes (es-AR, pt-PT) seguirá coincidiendo
    /// porque iOS busca por la ruta exacta del recurso.
    var bundleResourceName: String { rawValue }

    /// Padre para fallback chain. nil = locale base (no hereda de otro).
    /// Las variantes regionales declaran parent: cuando una key falta en la variante,
    /// `ls()` busca en el padre antes de caer a `Bundle.main` (en).
    var parent: SupportedLocale? {
        switch self {
        case .ptPT: return .ptBR
        case .esES, .esAR: return .es419
        case .enGB: return .en
        default: return nil
        }
    }

    var nativeName: String {
        switch self {
        case .es: return "Español"
        case .es419: return "Español (Latinoamérica)"
        case .esES: return "Español (España)"
        case .esAR: return "Español (Argentina)"
        case .en: return "English (US)"
        case .enGB: return "English (UK)"
        case .pt: return "Português"
        case .ptBR: return "Português (Brasil)"
        case .ptPT: return "Português (Portugal)"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .nl: return "Nederlands"
        case .pl: return "Polski"
        }
    }

    var flag: String {
        switch self {
        case .es: return "🌎"        // Alias catch-all — bandera LatAm
        case .es419: return "🌎"
        case .esES: return "🇪🇸"
        case .esAR: return "🇦🇷"
        case .en: return "🇺🇸"
        case .enGB: return "🇬🇧"
        case .pt: return "🇧🇷"        // Alias catch-all — bandera BR
        case .ptBR: return "🇧🇷"
        case .ptPT: return "🇵🇹"
        case .de: return "🇩🇪"
        case .fr: return "🇫🇷"
        case .it: return "🇮🇹"
        case .nl: return "🇳🇱"
        case .pl: return "🇵🇱"
        }
    }

    /// Cases que aparecen en el selector de idioma del usuario.
    /// Aliases catch-all (`es`, `pt`) se excluyen — están cubiertos por las variantes
    /// canónicas con bandera explícita.
    static var selectableCases: [SupportedLocale] {
        allCases.filter { $0 != .pt && $0 != .es }
    }

    /// Resolver el código preferido del usuario contra los soportados.
    /// Implementa chain: exact → region map → idioma base → en.
    /// Region map se va llenando en milestones futuros (M9: ES, M10: AR, M11: GB/AU/IE).
    static func bestMatch(forPreferredLanguages preferred: [String], region: String?) -> SupportedLocale {
        // 1. Match exacto (e.g. "pt-BR", "pt-PT", "es-ES", "es-419")
        for code in preferred {
            if let exact = SupportedLocale(rawValue: code) {
                // Resolver aliases catch-all directamente al canónico
                return canonicalize(exact)
            }
        }
        // 2. Region map para usuarios sin variante explícita en preferredLanguages
        let regionMap: [String: SupportedLocale] = [
            "BR": .ptBR,
            "PT": .ptPT, "AO": .ptPT, "MZ": .ptPT, "CV": .ptPT, "GW": .ptPT, "ST": .ptPT, "TL": .ptPT,
            "ES": .esES,
            "AR": .esAR,
            "GB": .enGB, "AU": .enGB, "IE": .enGB, "NZ": .enGB
        ]
        if let region, let mapped = regionMap[region] { return mapped }
        // 3. Match por idioma base (e.g. "es-MX" → "es" → es-419, "pt-AO" → "pt" → pt-BR)
        for code in preferred {
            let base = String(code.prefix(2))
            if let baseMatch = SupportedLocale(rawValue: base) {
                return canonicalize(baseMatch)
            }
        }
        return .en
    }

    /// Resolver alias catch-all a variante canónica.
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
