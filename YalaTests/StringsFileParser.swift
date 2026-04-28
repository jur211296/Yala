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
                    if c.isLetter || c == "%" {
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
