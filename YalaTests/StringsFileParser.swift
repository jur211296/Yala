//
//  StringsFileParser.swift
//  YalaTests
//
//  Helpers test-only para parsear .strings y .stringsdict desde el bundle.
//  Usado por LocalizationParityTests, LocalizationVariantsTests, etc.
//

import Foundation

@testable import Yala

enum StringsFileParser {

    /// Parsea un Localizable.strings del bundle del locale en cuestión.
    /// Retorna un `[key: value]`. Devuelve dict vacío si el archivo no existe.
    static func parseStrings(forLocale code: String) -> [String: String] {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let stringsURL = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let dict = NSDictionary(contentsOf: stringsURL) as? [String: String]
        else {
            return [:]
        }
        return dict
    }

    /// Parsea un Localizable.stringsdict del bundle del locale.
    /// Retorna las keys que tienen entrada plural (no el contenido full).
    static func parseStringsdictKeys(forLocale code: String) -> Set<String> {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let stringsdictURL = bundle.url(forResource: "Localizable", withExtension: "stringsdict"),
              let dict = NSDictionary(contentsOf: stringsdictURL) as? [String: Any]
        else {
            return []
        }
        return Set(dict.keys)
    }

    /// Para cada key del `.stringsdict` del locale, devuelve los placeholders de su
    /// forma plural `other` — la cadena que las variantes materializan como entrada
    /// flat de degradación (ver `variants_haveAllKeys_fromParent`). En este proyecto la
    /// forma `other` de la variable plural contiene la frase completa con todos los
    /// placeholders; el `NSStringLocalizedFormatKey` es solo la referencia `%#@var@`.
    static func parseStringsdictOtherPlaceholders(forLocale code: String) -> [String: [String]] {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let stringsdictURL = bundle.url(forResource: "Localizable", withExtension: "stringsdict"),
              let dict = NSDictionary(contentsOf: stringsdictURL) as? [String: Any]
        else {
            return [:]
        }
        var result: [String: [String]] = [:]
        for (key, value) in dict {
            guard let entry = value as? [String: Any] else { continue }
            // La variable plural es la sub-dict con NSStringFormatSpecTypeKey == NSStringPluralRuleType.
            for (subKey, subValue) in entry where subKey != "NSStringLocalizedFormatKey" {
                guard let variable = subValue as? [String: Any],
                      variable["NSStringFormatSpecTypeKey"] as? String == "NSStringPluralRuleType",
                      let other = variable["other"] as? String
                else { continue }
                result[key] = extractPlaceholders(from: other)
                break
            }
        }
        return result
    }

    /// Extrae los placeholders de format en orden (e.g. ["%@", "%d"] o ["%1$@", "%2$d"]).
    /// Útil para detectar drift entre traducciones.
    static func extractPlaceholders(from value: String) -> [String] {
        var result: [String] = []
        var idx = value.startIndex
        while idx < value.endIndex {
            if value[idx] == "%" {
                var endIdx = value.index(after: idx)
                while endIdx < value.endIndex {
                    let c = value[endIdx]
                    // Format specifiers Swift son siempre ASCII (e.g. %@, %d, %lld, %1$@).
                    // Los kanji y otros caracteres Unicode con `isLetter == true` (como `%増`
                    // en japonés "32%増") son falsos positivos del parser.
                    if (c.isASCII && c.isLetter) || c == "%" {
                        endIdx = value.index(after: endIdx)
                        result.append(String(value[idx..<endIdx]))
                        break
                    }
                    if !(c.isNumber || c == "$" || c == "." || c == "+" || c == "-" || c == "*" || c == "0" || c == "#") {
                        // Carácter inesperado; abortar este placeholder
                        endIdx = value.index(after: endIdx)
                        break
                    }
                    endIdx = value.index(after: endIdx)
                }
                idx = endIdx
            } else {
                idx = value.index(after: idx)
            }
        }
        // Filtrar literales "%%"
        return result.filter { $0 != "%%" }
    }
}
