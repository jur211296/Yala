//
//  CompartidoCableadoTests.swift
//  YalaTests
//
//  Lote 1 de Compartido (26-nov-2026): lo que no se ve en un cálculo. La pestaña se llama «Compartido» en los 16 idiomas
//  sin cambiar de identificador, los textos nuevos viven en su tabla propia, y la pantalla de Grupos monta los chips, la
//  lista de Personas y el botón de la barra de cada chip. Lee el código FUENTE (`#filePath`).
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · cableado")
@MainActor
struct CompartidoCableadoTests {

    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                                  "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(path), encoding: .utf8)
    }

    private static func table(_ locale: String, _ name: String) throws -> [String: String] {
        let url = repo.appendingPathComponent("Yala/Resources/\(locale).lproj/\(name).strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)/\(name)")
    }

    /// El código sin comentarios: documentar lo prohibido no puede poner rojo el test.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let range = line.range(of: "//") else { return String(line) }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    @Test("La pestaña cambia de nombre pero no de identificador: la barra que cada uno ordenó se conserva")
    func tabKeepsItsID() {
        #expect(ConfigurableTab.groups.rawValue == "groups")
    }

    @Test("«Compartido» en la pestaña y en el título, en los 16 idiomas, y traducido")
    func tabNameInEveryLanguage() throws {
        let expected: [String: String] = [
            "es": "Compartido", "es-419": "Compartido", "es-AR": "Compartido", "es-ES": "Compartido",
            "en": "Shared", "en-GB": "Shared", "de": "Geteilt", "fr": "Partagé", "it": "Condivisi", "ja": "共有",
            "nl": "Gedeeld", "pl": "Wspólne", "pt-BR": "Compartilhado", "pt": "Compartilhado", "pt-PT": "Partilhado",
            "zh-Hans": "共享",
        ]
        for locale in Self.locales {
            let strings = try Self.table(locale, "Localizable")
            #expect(strings["tab.groups"] == expected[locale], "\(locale) tab.groups")
            #expect(strings["groups.title"] == expected[locale], "\(locale) groups.title")
        }
    }

    @Test("Las frases que nombran la pestaña dicen su nombre nuevo")
    func sentencesNameTheNewTab() throws {
        let keys = ["groups.invite.slow.body", "settings.deleteAccountDebtWarning", "settings.wipeScopeGroupsDebt",
                    "iaGuided.group.needsAccount"]
        for locale in ["es", "es-419", "es-AR", "es-ES"] {
            let strings = try Self.table(locale, "Localizable")
            for key in keys {
                let value = try #require(strings[key], "\(locale) \(key)")
                #expect(value.contains("pestaña Compartido") && !value.contains("pestaña Grupos"), "\(locale) \(key)")
            }
        }
        let english = try Self.table("en", "Localizable")
        for key in keys { #expect(english[key]?.contains("Shared tab") == true, "en \(key)") }
    }

    @Test("Los textos nuevos viven en Compartido.strings, con las mismas claves en los 16 idiomas y traducidos")
    func stringsTableParity() throws {
        let reference = try Self.table("es-419", "Compartido")
        #expect(reference.count >= 9)
        for locale in Self.locales {
            let table = try Self.table(locale, "Compartido")
            #expect(Set(table.keys) == Set(reference.keys), "\(locale)")
            if !locale.hasPrefix("es") {
                #expect(table["compartido.people.emptyTitle"] != reference["compartido.people.emptyTitle"],
                        "\(locale) copia el español")
            }
        }
        let localizable = try Self.source("Yala/Resources/es-419.lproj/Localizable.strings")
        #expect(!localizable.contains("\"compartido."))
    }

    @Test("Grupos monta los chips bajo el título, la lista de Personas y el botón de la barra de cada chip")
    func groupsScreenWiring() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift"))
        #expect(code.contains(".navigationChipsInset { CompartidoChipsBar(selection: $compartidoChip) }"))
        #expect(code.contains("CompartidoPeopleList(people: viewModel.compartidoPeople"))
        #expect(code.contains("\"compartido_toolbar_add_person\""))
        #expect(code.contains("\"groups_toolbar_new_group\""))
        // La fila de captura y «Dividir una boleta» siguen fuera de la rama de los chips: iguales en los dos.
        let peopleBranch = try #require(code.range(of: "if shownCompartidoChip == .people {"))
        let quickActions = try #require(code.range(of: "topActions\n"))
        let receipt = try #require(code.range(of: "DividirBoletaEntryButton(identifier: \"groups_dividir_boleta\")"))
        #expect(quickActions.lowerBound < peopleBranch.lowerBound)
        #expect(receipt.lowerBound < peopleBranch.lowerBound)
    }

    @Test("Los chips son los de Planificación: nombre en los dos, dentro de navigationChipsInset")
    func chipsReusePlanningPattern() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Compartido/CompartidoChips.swift"))
        #expect(code.contains("NavigationChipButton("))
        #expect(code.contains("showsTitleWhenUnselected: true"))
    }
}
