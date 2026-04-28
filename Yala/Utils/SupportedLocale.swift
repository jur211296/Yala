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
    case es = "es"      // Español neutro LatAm — se renombrará a es-419 en M9
    case en = "en"
    case pt = "pt"      // Alias catch-all (copia idéntica de pt-BR para usuarios pt-MZ/pt-AO)
    case ptBR = "pt-BR" // Brasil (base lusófona neutra de Yala)
    case ptPT = "pt-PT" // Portugal (overrides hacia portugués europeo)
    case de = "de"
    case fr = "fr"
    case it = "it"

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
        default: return nil
        }
    }

    var nativeName: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        case .pt: return "Português"
        case .ptBR: return "Português (Brasil)"
        case .ptPT: return "Português (Portugal)"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        }
    }

    var flag: String {
        switch self {
        case .es: return "🇪🇸"
        case .en: return "🇺🇸"
        case .pt: return "🇧🇷"      // Alias catch-all — bandera BR (mercado mayoritario)
        case .ptBR: return "🇧🇷"
        case .ptPT: return "🇵🇹"
        case .de: return "🇩🇪"
        case .fr: return "🇫🇷"
        case .it: return "🇮🇹"
        }
    }

    /// Cases que aparecen en el selector de idioma del usuario.
    /// `pt` (alias catch-all) se excluye porque ya está cubierto por `ptBR` con bandera explícita.
    static var selectableCases: [SupportedLocale] {
        allCases.filter { $0 != .pt }
    }

    /// Resolver el código preferido del usuario contra los soportados.
    /// Implementa chain: exact → region map → idioma base → en.
    /// Region map se va llenando en milestones futuros (M9: ES, M10: AR, M11: GB/AU/IE).
    static func bestMatch(forPreferredLanguages preferred: [String], region: String?) -> SupportedLocale {
        // 1. Match exacto (e.g. "pt-BR", "pt-PT", "es")
        for code in preferred {
            if let exact = SupportedLocale(rawValue: code) {
                // Resolver `pt` legacy directamente al canónico ptBR
                return exact == .pt ? .ptBR : exact
            }
        }
        // 2. Region map para usuarios sin variante explícita en preferredLanguages
        let regionMap: [String: SupportedLocale] = [
            "BR": .ptBR,
            "PT": .ptPT, "AO": .ptPT, "MZ": .ptPT, "CV": .ptPT, "GW": .ptPT, "ST": .ptPT, "TL": .ptPT
        ]
        if let region, let mapped = regionMap[region] { return mapped }
        // 3. Match por idioma base (e.g. "es-MX" → "es", "pt-AO" → "pt" → ptBR)
        for code in preferred {
            let base = String(code.prefix(2))
            if let baseMatch = SupportedLocale(rawValue: base) {
                return baseMatch == .pt ? .ptBR : baseMatch
            }
        }
        return .en
    }

    /// Construye un `SupportedLocale` desde un código BCP-47 (e.g. "es-MX" → .es).
    /// Útil para extraer la base de un identifier compuesto.
    static func from(_ identifier: String) -> SupportedLocale? {
        if let exact = SupportedLocale(rawValue: identifier) { return exact }
        let base = String(identifier.prefix(2))
        return SupportedLocale(rawValue: base)
    }
}
