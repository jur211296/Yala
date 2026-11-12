//
//  L10nArgumentOrderTests.swift
//  YalaTests
//
//  Cada traducción tiene que recibir sus argumentos en el MISMO orden y del mismo tipo que la
//  referencia. `placeholders_matchAcrossLocales` solo cuenta especificadores —y no ve `%@`—, así que
//  dejó pasar `subcategory.transferDescription` en polaco, japonés y chino: ponían el nombre primero
//  («W „%@” jest %d…») y el código pasa primero el número, con lo que `%@` recibía un `Int`
//  (auditoría UX 2.2, lote 7, B11).
//

import Foundation
import Testing

@testable import Yala

struct L10nArgumentOrderTests {

    private let referenceLocale = "es-419"

    /// Para cada argumento (por posición), su tipo: entero, objeto, decimal…
    static func argumentTypes(in value: String) -> [Int: String] {
        // Sin el flag de espacio: «32% hoch» o «12% less» son porcentajes literales, no argumentos.
        let pattern = #"%(?:(\d+)\$)?[-+#0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfFeEgGcCsS])"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            Issue.record("L10nArgumentOrderTests: Error: \(error)")
            return [:]
        }
        let cleaned = value.replacing("%%", with: "")
        let ns = cleaned as NSString
        var result: [Int: String] = [:]
        var sequential = 0
        for match in regex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length)) {
            let explicit = match.range(at: 1).location != NSNotFound ? Int(ns.substring(with: match.range(at: 1))) : nil
            let conversion = ns.substring(with: match.range(at: 2))
            let position: Int
            if let explicit {
                position = explicit
            } else {
                sequential += 1
                position = sequential
            }
            result[position] = Self.kind(conversion)
        }
        return result
    }

    private static func kind(_ conversion: String) -> String {
        switch conversion {
        case "@": return "objeto"
        case "d", "D", "i", "u", "U", "x", "X", "o", "O", "c", "C": return "entero"
        case "f", "F", "e", "E", "g", "G": return "decimal"
        default: return "texto C"
        }
    }

    /// Todas las formas de cada clave: el valor del `.strings` y, si la clave es plural, cada forma
    /// del `.stringsdict` (one, few, many, other…).
    private func forms(forLocale code: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (key, value) in StringsFileParser.parseStrings(forLocale: code) {
            result[key, default: []].append(value)
        }
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let url = bundle.url(forResource: "Localizable", withExtension: "stringsdict"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else { return result }
        for (key, entry) in dict {
            guard let entry = entry as? [String: Any] else { continue }
            for (subKey, subValue) in entry where subKey != "NSStringLocalizedFormatKey" {
                guard let variable = subValue as? [String: Any] else { continue }
                for (category, form) in variable where !category.hasPrefix("NSString") {
                    if let form = form as? String { result[key, default: []].append(form) }
                }
            }
        }
        return result
    }

    @Test func detectsTheSwappedOrder_thatShippedInPolish() {
        let reference = Self.argumentTypes(in: "Hay %d transacciones en \"%@\".")
        let swapped = Self.argumentTypes(in: "W „%@” jest %d transakcji.")
        let positional = Self.argumentTypes(in: "W „%2$@” jest %1$d transakcji.")
        #expect(reference == [1: "entero", 2: "objeto"])
        #expect(swapped != reference)
        #expect(positional == reference)
    }

    /// Una forma puede omitir un argumento («1 cuenta» sin `%d`), pero el que use tiene que ser del tipo
    /// que la referencia espera en esa posición.
    @Test func everyLocale_passesArgumentsInTheReferenceOrder() {
        let reference = forms(forLocale: referenceLocale)
        var expected: [String: [Int: String]] = [:]
        for (key, values) in reference {
            var merged: [Int: String] = [:]
            for value in values { merged.merge(Self.argumentTypes(in: value)) { first, _ in first } }
            // Las claves sin argumentos en la referencia no son formatos: un «%» suyo es literal.
            if !merged.isEmpty { expected[key] = merged }
        }

        for locale in SupportedLocale.allCases where locale.code != referenceLocale {
            for (key, values) in forms(forLocale: locale.code) {
                guard let want = expected[key] else { continue }
                for value in values {
                    for (position, type) in Self.argumentTypes(in: value) where want[position] != type {
                        Issue.record(
                            "\(locale.code) «\(key)»: el argumento \(position) es \(type) y la referencia espera \(want[position] ?? "nada") — «\(value)»"
                        )
                    }
                }
            }
        }
    }
}
