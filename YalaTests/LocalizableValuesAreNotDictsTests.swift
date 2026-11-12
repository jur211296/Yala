//
//  LocalizableValuesAreNotDictsTests.swift
//  YalaTests
//
//  Ticket `inbox-strings-show-a-python-dict-in-four-languages`: el lote 4 de la auditoría UX 2.2 dejó diez cadenas
//  de la Bandeja como un diccionario serializado en lugar de la traducción («{'de': 'Entwurf bearbeiten', 'fr': …}»),
//  y en alemán, francés, italiano y los portugueses salía tal cual en pantalla. Ningún test de paridad lo veía:
//  la clave existía y no tenía marcadores. Se lee del árbol, como `ExternalEntriesLote15Tests`.
//

import Foundation
import Testing

@Suite("Catálogos · ningún valor es un diccionario serializado")
struct LocalizableValuesAreNotDictsTests {

    private static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl",
                                    "pl", "pt", "pt-BR", "pt-PT", "zh-Hans"]

    @Test(arguments: languages)
    func ningunValorEmpiezaPorUnDiccionario(_ lang: String) throws {
        let root = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Yala/Resources/\(lang).lproj/Localizable.strings"), encoding: .utf8)
        let offenders = source.split(separator: "\n")
            .filter { $0.contains("\" = \"{'") }
            .map { String($0.prefix(60)) }
        #expect(offenders.isEmpty, "\(lang): valores que son un diccionario serializado: \(offenders)")
    }
}
