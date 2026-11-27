//
//  TextosRepartoYAyudaTests.swift
//  YalaTests
//
//  Textos de reparto y ayuda de Distribución (encargo del 2026-11-27):
//  1. La pantalla de éxito de un gasto de grupo dice el reparto real («Todo de Pia»), no el tipo guardado («Partes
//     iguales»), con la misma función que arregló el detalle (`GroupSplitLabelLogic`).
//  2. VoiceOver de «y dividido…» en el formulario lee el reparto real.
//  3. La ayuda «?» de las tres tortas ya no promete «filtrar el resto del Panel» al tocar: en Distribución una
//     categoría abre su detalle.
//

import Foundation
import Testing

@testable import Yala

// MARK: - 1. Pantalla de éxito

@Suite("Textos de reparto · pantalla de éxito del gasto de grupo")
struct RepartoRealEnExitoTests {

    private func data(
        _ type: SplitType,
        _ shares: [(String, String, Double)],
        me: String? = "me"
    ) -> GroupExpenseSuccessData {
        GroupExpenseSuccessData(
            groupName: "Viaje", groupColorHex: "#8B5CF6", date: .distantPast, description: "Cena",
            totalAmount: shares.reduce(0) { $0 + $1.2 }, currencyCode: "PEN",
            paidByName: "Tú", paidByIsMe: true, subcategoryName: nil, accountName: nil, accountColorHex: nil,
            splitType: type,
            participants: shares.map { .init(id: $0.0, name: $0.1, amount: $0.2) },
            debt: .settled, isEditMode: false, currentUserMemberID: me
        )
    }

    @Test("«Pagaste · es todo de Pia»: dice «Todo de Pia», no «Partes iguales»")
    func todoDePia() {
        let success = data(.equal, [("pia", "Pia", 214)])
        #expect(success.splitKind == .allFor(memberID: "pia"))
        #expect(success.splitLabel == GruposPulidoDivisionDetalleText.allFor("Pia"))
        #expect(success.splitLabel != L10n.Split.typeEqual)
    }

    @Test("Con tu parte en cero también es «Todo de Pia»")
    func todoDePiaConMiParteEnCero() {
        let success = data(.equal, [("me", "Tú", 0), ("pia", "Pia", 214)])
        #expect(success.splitKind == .allFor(memberID: "pia"))
        #expect(success.splitLabel == GruposPulidoDivisionDetalleText.allFor("Pia"))
    }

    @Test("«Pagó Caro · es todo tuyo»: dice «Todo tuyo»")
    func todoTuyo() {
        let success = data(.equal, [("me", "Tú", 80)])
        #expect(success.splitKind == .allForMe)
        #expect(success.splitLabel == GruposPulidoDivisionDetalleText.allForMe)
    }

    @Test("Partes iguales de verdad siguen diciendo «Partes iguales»")
    func partesIguales() {
        let success = data(.equal, [("me", "Tú", 33.33), ("ana", "Ana", 33.33), ("luis", "Luis", 33.34)])
        #expect(success.splitKind == .equal)
        #expect(success.splitLabel == L10n.Split.typeEqual)
    }

    @Test("Monto exacto con partes distintas sigue diciendo «Monto exacto»")
    func montoExacto() {
        let success = data(.exact, [("me", "Tú", 50), ("ana", "Ana", 70)])
        #expect(success.splitKind == .exact)
        #expect(success.splitLabel == L10n.Split.typeExact)
    }

    @Test("Un gasto de una sola persona lleva el icono de persona; el resto, el de su tipo como antes")
    func icono() {
        #expect(data(.equal, [("pia", "Pia", 214)]).splitIconName == "person.fill")
        #expect(data(.equal, [("me", "Tú", 80)]).splitIconName == "person.fill")
        #expect(data(.equal, [("me", "Tú", 40), ("ana", "Ana", 40)]).splitIconName == SplitType.equal.iconName)
        #expect(data(.exact, [("me", "Tú", 50), ("ana", "Ana", 70)]).splitIconName == SplitType.exact.iconName)
    }
}

// MARK: - 2. VoiceOver de «y dividido…»

@Suite("Textos de reparto · VoiceOver de «y dividido…»")
struct RepartoRealEnVoiceOverTests {

    private func spoken(_ type: SplitType, _ shares: [(String, Double)]?, me: String? = "me") -> String {
        GruposPulidoDivisionDetalleText.splitLabel(
            splitType: type.rawValue,
            shares: (shares ?? []).map { (memberID: $0.0, amount: $0.1) },
            currentMemberID: me
        ) { id in ["pia": "Pia", "ana": "Ana"][id] ?? "—" }
    }

    @Test("Todo para una persona: lee «Todo de Pia»")
    func todoDePia() {
        #expect(spoken(.equal, [("pia", 120)]) == GruposPulidoDivisionDetalleText.allFor("Pia"))
    }

    @Test("Todo para ti: lee «Todo tuyo»")
    func todoTuyo() {
        #expect(spoken(.equal, [("me", 120), ("pia", 0)]) == GruposPulidoDivisionDetalleText.allForMe)
    }

    @Test("Sin monto todavía: lee el tipo guardado, como antes")
    func sinMonto() {
        #expect(spoken(.equal, nil) == L10n.Split.typeEqual)
        #expect(spoken(.percentage, [("me", 0), ("pia", 0)]) == L10n.Split.typePercentage)
    }

    @Test("Partes iguales entre varios: lee «Partes iguales»")
    func iguales() {
        #expect(spoken(.equal, [("me", 40), ("pia", 40), ("ana", 40)]) == L10n.Split.typeEqual)
    }
}

// MARK: - Cableado

@Suite("Textos de reparto · cableado de las dos pantallas")
struct RepartoRealCableadoTests {

    private static func source(_ path: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    /// Quita comentarios de línea: documentar el bug no puede poner rojo el scan.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    @Test("La fila «Reparto» del éxito pinta y lee la etiqueta real, no el tipo guardado")
    func exito() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupExpenseSuccessView.swift"))
        #expect(!code.contains("data.splitType.displayName"), "El éxito vuelve a leer el tipo guardado.")
        #expect(!code.contains("data.splitType.iconName"), "El icono del éxito vuelve a salir del tipo guardado.")
        #expect(code.contains("data.splitLabel"))
        #expect(code.contains("data.splitIconName"))
    }

    @Test("La pieza «dividido» del formulario lee la etiqueta real a VoiceOver")
    func formulario() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Groups/GroupExpenseFormView.swift"))
        #expect(!code.contains("dividedLabel): \\(viewModel.splitType.displayName)"),
                "VoiceOver vuelve a leer el tipo guardado.")
        #expect(code.contains("dividedLabel): \\(spokenSplitLabel)"))
        #expect(code.contains("GruposPulidoDivisionDetalleText.splitLabel("))
        #expect(code.contains("viewModel.calculatedShares"))
    }
}

// MARK: - 3. Ayuda de las tortas

@Suite("Textos de reparto · ayuda «?» de las tortas")
struct AyudaTortasTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]
    static let keys = ["categoriesPie", "subcategoriesPie", "tagsPie"]
        .flatMap { ["panel.widgetInfo.\($0).smallHowA", "panel.widgetInfo.\($0).largeHowA"] }

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/Localizable.strings")
        let plist = try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: String])
    }

    /// Lo que decía la ayuda de antes y ya no es verdad en Distribución, por idioma.
    private static let oldFilterPhrase: [String: String] = [
        "es": "filtrar el resto del Panel", "es-419": "filtrar el resto del Panel", "es-AR": "filtrar el resto del Panel",
        "es-ES": "filtrar el resto del Panel", "en": "filter the rest of the Panel", "en-GB": "filter the rest of the Panel",
        "de": "den Rest des Panels", "fr": "filtrer le reste du Panel", "it": "filtrare il resto del Panel",
        "nl": "de rest van het Panel te filteren", "pl": "przefiltrować resztę Panelu",
        "pt-BR": "filtrar o resto do Painel", "pt": "filtrar o resto do Painel", "pt-PT": "filtrar o resto do Painel",
        "ja": "パネル全体をフィルタリング", "zh-Hans": "筛选面板其余内容",
    ]

    /// El nombre de Distribución en cada idioma (`statistics.categories`): la ayuda de categorías lo nombra.
    @Test("La ayuda de categorías dice que en Distribución se abre el detalle, en los 16 idiomas", arguments: locales)
    func categoriasNombranDistribucion(locale: String) throws {
        let table = try Self.table(locale)
        let distribution = try #require(table["statistics.categories"])
        for size in ["small", "large"] {
            let value = try #require(table["panel.widgetInfo.categoriesPie.\(size)HowA"])
            #expect(value.contains(distribution), "\(locale) \(size): no nombra «\(distribution)».")
        }
    }

    @Test("Ninguna de las seis ayudas promete filtrar el resto del Panel", arguments: locales)
    func sinFiltrarElRestoDelPanel(locale: String) throws {
        let table = try Self.table(locale)
        let old = try #require(Self.oldFilterPhrase[locale])
        for key in Self.keys {
            let value = try #require(table[key], "\(locale): falta \(key)")
            #expect(!value.isEmpty)
            #expect(!value.contains(old), "\(locale) \(key) sigue diciendo «\(old)».")
        }
    }

    @Test("Las variantes llevan su texto: es-AR con voseo y pt-PT con el «tu» de Portugal")
    func variantes() throws {
        let ar = try Self.table("es-AR")
        let pt = try Self.table("pt-PT")
        for key in Self.keys {
            let arValue = ar[key] ?? ""
            #expect(arValue.contains("Tocá") || arValue.contains("tocá"), "es-AR \(key) sin voseo")
            let ptValue = pt[key] ?? ""
            #expect(ptValue.contains("Toca numa") || ptValue.contains("toca numa"), "pt-PT \(key) no usa el «tu» de Portugal")
        }
    }

    @Test("Cada idioma base trae su propia traducción, no la de otro")
    func traduccionReal() throws {
        let es = try Self.table("es-419")
        for locale in ["de", "en", "fr", "it", "ja", "nl", "pl", "pt-BR", "zh-Hans"] {
            let table = try Self.table(locale)
            for key in Self.keys {
                #expect(table[key] != es[key], "\(locale) \(key) es el texto en español")
            }
        }
    }
}
