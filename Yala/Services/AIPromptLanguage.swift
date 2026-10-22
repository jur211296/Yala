//
//  AIPromptLanguage.swift
//  Yala
//
//  En qué idioma contesta la IA y con qué trato. Un solo sitio para las llamadas que escriben texto
//  que el usuario lee (Insights, flujo de caja, desviaciones y el chat).
//

import Foundation

enum AIPromptLanguage {
    /// El idioma de la interfaz, en BCP-47 («es-PE», «de», «zh-Hans»): el override de la app o, sin él, el
    /// primer idioma soportado del sistema (`AppLocale`).
    ///
    /// NUNCA `Locale.current`: es la región de formato del iPhone. Con la app en inglés y la región en Perú,
    /// `Locale.current.language` puede decir español, y la IA contestaba en un idioma que la pantalla no usa.
    static var current: String { AppLocale.identifier }

    /// El código base de un identificador BCP-47: «es-PE» → «es», «zh-Hans» → «zh».
    static func baseCode(of language: String) -> String {
        Locale(identifier: language).language.languageCode?.identifier ?? String(language.prefix(2))
    }

    /// El idioma como se nombra en un prompt: nombre y código, «italiano (it)», «español (es-PE)». El código solo era
    /// ambiguo dentro de una frase en español: «Responde en de» o «en it» se leen como palabras, y en el banco del
    /// 2026-10-07 un caso en italiano salió en español. Un idioma sin nombre en la tabla va con su código.
    static func label(for language: String) -> String {
        guard let name = spanishName(forBaseLanguage: baseCode(of: language)) else { return language }
        return "\(name) (\(language))"
    }

    /// El nombre en español de cada idioma base de la app (los prompts están en español).
    static func spanishName(forBaseLanguage base: String) -> String? {
        switch base {
        case "es": return "español"
        case "en": return "inglés"
        case "pt": return "portugués"
        case "fr": return "francés"
        case "de": return "alemán"
        case "it": return "italiano"
        case "nl": return "neerlandés"
        case "pl": return "polaco"
        case "ja": return "japonés"
        case "zh": return "chino"
        default: return nil
        }
    }

    /// El trato informal que se pide en cada idioma base. Es la tabla que usaba el chat; un idioma sin entrada
    /// cae a «informal you».
    static func informalRegister(forBaseLanguage base: String) -> String {
        switch base {
        case "es": return "tuteo (tú)"
        case "de": return "du"
        case "fr": return "tu"
        case "it": return "tu"
        case "pt": return "você"
        default: return "informal you"
        }
    }
}
