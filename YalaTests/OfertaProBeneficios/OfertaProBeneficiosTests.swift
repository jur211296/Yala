//
//  OfertaProBeneficiosTests.swift
//  YalaTests
//
//  Oferta Pro de Primeros pasos con todos los beneficios (opción A de Jürgen, 20-nov-2026, ticket
//  `2026-11-20-oferta-pro-primeros-pasos-mas-beneficios`): las ocho puertas Pro y ninguna más, las cifras leídas del
//  código, la página «Qué incluye Yala Pro» dentro de la hoja con el botón de la oferta, y los textos en su tabla en
//  los 16 idiomas.
//

import Foundation
import Testing
@testable import Yala

private enum OfertaSource {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // OfertaProBeneficios/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// El fichero sin las líneas de comentario: documentar lo que el test busca no lo pone en verde.
    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static let sheet = "Yala/App/Views/Subscription/SetupCompleteTrialOfferSheet.swift"
    static let card = "Yala/App/Views/Subscription/OfertaProBeneficios/OfertaProBeneficiosCard.swift"
    static let page = "Yala/App/Views/Subscription/OfertaProBeneficios/OfertaProTodosLosBeneficiosPage.swift"
    static let text = "Yala/Utils/L10n+OfertaProBeneficios.swift"
}

// MARK: - Qué se promete

@Suite("Oferta Pro · las ocho puertas y las cifras del código")
struct OfertaProBeneficiosLogicTests {
    typealias L = OfertaProBeneficiosLogic

    @Test("los cuatro bloques nombran las ocho puertas Pro, cada una una sola vez")
    func blocks_coverEveryGate() {
        let named = L.Block.allCases.flatMap(\.features)
        #expect(named.count == ProFeature.allCases.count)
        #expect(Set(named) == Set(ProFeature.allCases))
        #expect(L.Block.allCases == [.capture, .ai, .limits, .style])
    }

    @Test("la tabla tiene una fila por puerta Pro y «A mano», que es de todos")
    func table_hasOneRowPerGate() {
        let rows = L.groups().flatMap(\.rows)
        let gates = rows.compactMap(\.feature)
        #expect(gates.count == ProFeature.allCases.count)
        #expect(Set(gates) == Set(ProFeature.allCases))
        let manual = rows.filter { $0.feature == nil }
        #expect(manual.count == 1)
        #expect(manual.first?.free == .included && manual.first?.pro == .included)
        #expect(L.groups().map(\.id) == ["capture", "ai", "organize", "style"])
    }

    @Test("Gratis dice «—» en lo que solo trae Pro, el límite del código en cuentas y presupuestos, y cuántos temas e iconos")
    func table_freeColumnFollowsTheGate() {
        let counts = L.counts()
        for row in L.groups().flatMap(\.rows) {
            guard let feature = row.feature else { continue }
            switch feature {
            case .voiceInput, .imageInput, .chatAssistant, .smartInsightsAI:
                #expect(feature.isProOnly)
                #expect(row.free == .notIncluded, "\(feature): Pro solo, y Gratis no dice «—»")
                #expect(row.pro == .included)
            case .accounts, .budgets:
                #expect(row.free == L.Mark.limit(feature.freeLimit), "\(feature): el límite no sale del código")
                #expect(row.pro == .unlimited)
            // Puertas Pro sobre una parte: Gratis tiene los temas y el icono que no son Pro.
            case .proThemes:
                #expect(row.free == .count(counts.freeThemes))
                #expect(row.pro == .count(counts.allThemes))
            case .premiumIcons:
                #expect(row.free == .count(counts.freeIcons))
                #expect(row.pro == .count(counts.allIcons))
            }
        }
    }

    @Test("las cifras de hoy, leídas del código: 4 cuentas, 3 presupuestos, 4 de 9 temas, 1 de 4 iconos")
    func counts_today() {
        let counts = L.counts()
        #expect(counts.freeAccounts == ProFeature.accounts.freeLimit)
        #expect(counts.freeBudgets == ProFeature.budgets.freeLimit)
        #expect(counts.freeThemes == AppTheme.allCases.filter { !$0.isPro }.count)
        #expect(counts.allThemes == AppTheme.allCases.count)
        #expect(counts.freeIcons == AppIconOption.allCases.filter { !$0.isPremium }.count)
        #expect(counts.allIcons == AppIconOption.allCases.count)
        // La foto del 20-nov-2026: si cambia el código, cambian estas cifras y el texto con ellas.
        #expect(counts == L.Counts(freeAccounts: 4, freeBudgets: 3, freeThemes: 4, allThemes: 9, freeIcons: 1,
                                   allIcons: 4))
        #expect(counts.exclusiveThemes == 5)
        #expect(counts.exclusiveIcons == 3)
    }

    @Test("cambiar un límite o un tema cambia la tabla y el texto")
    func counts_drivenByTheCode() {
        let counts = L.counts(themes: [.system, .indigo], icons: [.original, .dark, .neon],
                              accountsLimit: 7, budgetsLimit: nil)
        #expect(counts.exclusiveThemes == 1)
        #expect(counts.exclusiveIcons == 2)
        let rows = Dictionary(uniqueKeysWithValues: L.groups(counts).flatMap(\.rows).map { ($0.id, $0) })
        #expect(rows["accounts"]?.free == .count(7))
        #expect(rows["budgets"]?.free == .unlimited)
        #expect(rows["themes"]?.free == .count(1))
        #expect(rows["themes"]?.pro == .count(2))
        #expect(rows["icons"]?.pro == .count(3))
        let detail = L.Block.style.detail(counts)
        #expect(detail.contains("1") && detail.contains("2"), "«\(detail)» no lleva las cifras del código")
        #expect(!detail.contains("5") && !detail.contains("3"), "«\(detail)» lleva cifras escritas a mano")
    }

    @Test("VoiceOver lee la fila entera, con Gratis y Pro")
    func spokenRow_readsBothColumns() throws {
        let row = try #require(L.groups().flatMap(\.rows).first { $0.id == "accounts" })
        let spoken = L.spokenRow(row)
        #expect(spoken.contains(row.title))
        #expect(spoken.contains(L.Mark.count(4).spoken))
        #expect(spoken.contains(L.Mark.unlimited.spoken))
    }
}

// MARK: - La hoja y la página

@Suite("Oferta Pro · «Ver todos los beneficios» empuja la página dentro de la hoja")
struct OfertaProBeneficiosWiringTests {

    @Test("la oferta lleva la tarjeta de cuatro bloques y empuja «Qué incluye Yala Pro» con el botón de la oferta")
    func sheet_pushesThePageWithTheOffersButton() throws {
        let sheet = try OfertaSource.code(OfertaSource.sheet)
        #expect(sheet.contains("OfertaProBeneficiosCard { showsAllBenefits = true }"))
        #expect(sheet.contains(".navigationDestination(isPresented: $showsAllBenefits) {"))
        #expect(sheet.contains("OfertaProTodosLosBeneficiosPage { bottomButton }"),
                "La página compra con el botón de la oferta, el del plan elegido.")
        #expect(!sheet.contains("SubscriptionView"), "«Ver todos» no abre el paywall de Ajustes.")
        // Al confirmarse la compra, la página se retira y queda «¡Listo! Tienes Pro».
        let confirmed = try OfertaSource.code(OfertaSource.sheet)
            .components(separatedBy: "private func purchaseConfirmed() {").last ?? ""
        #expect(confirmed.contains("showsAllBenefits = false"))
    }

    @Test("la página no tiene plan propio ni otro paywall, y su botón va fijo abajo")
    func page_hasNoPlanOfItsOwn() throws {
        let page = try OfertaSource.code(OfertaSource.page)
        #expect(!page.contains("@State"), "La página no guarda plan: lo lee de la oferta.")
        #expect(!page.contains("selectedPlan"))
        #expect(!page.contains("ProPlanCard"))
        #expect(!page.contains("SubscriptionView"))
        #expect(page.contains(".safeAreaBar(edge: .bottom"))
        #expect(page.contains("bottomBar()"))
    }

    @Test("a tamaños de accesibilidad el icono del bloque va encima y la tabla se apila")
    func accessibilitySizes_stack() throws {
        let card = try OfertaSource.code(OfertaSource.card)
        #expect(card.contains("if dynamicTypeSize.isAccessibilitySize {"))
        #expect(card.contains(".accessibilityElement(children: .ignore)"), "Cada bloque, un elemento.")
        #expect(card.contains("setup_offer_see_all"))
        let page = try OfertaSource.code(OfertaSource.page)
        #expect(page.contains("if dynamicTypeSize.isAccessibilitySize {"))
        #expect(page.contains(".accessibilityLabel(OfertaProBeneficiosLogic.spokenRow(row))"))
    }

    @Test("la línea bajo el título sin método probado es la nueva, y sigue la de lo probado si lo hubo")
    func subtitle_newLineOrTried() throws {
        let sheet = try OfertaSource.code(OfertaSource.sheet)
        #expect(sheet.contains("case .manual, nil: OfertaProBeneficiosText.subtitle"))
        #expect(sheet.contains("case .voice: P.triedVoice"))
    }
}

// MARK: - Textos

@Suite("Oferta Pro · textos en su tabla y en los 16 idiomas")
struct OfertaProBeneficiosTextTests {

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]

    private static func table(_ locale: String) throws -> [String: String] {
        let url = OfertaSource.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/OfertaProBeneficios.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale) sin tabla")
    }

    private static func specifiers(_ text: String) -> [String] {
        text.matches(of: /%(\d\$)?[@d]/).map { String($0.output.0) }.sorted()
    }

    @Test("las mismas claves y los mismos formatos que es-419, en su tabla y no en Localizable", arguments: locales)
    func everyLocaleMatchesTheBase(locale: String) throws {
        let base = try Self.table("es-419")
        let table = try Self.table(locale)
        #expect(Set(table.keys) == Set(base.keys), "\(locale): claves distintas")
        for (key, value) in base {
            let translated = try #require(table[key], "\(locale): falta \(key)")
            #expect(!translated.isEmpty)
            #expect(Self.specifiers(translated) == Self.specifiers(value), "\(locale): \(key) cambia los formatos")
        }
        let localizable = try String(
            contentsOf: OfertaSource.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings"),
            encoding: .utf8)
        #expect(!localizable.contains("ofertaProBeneficios."), "\(locale): textos nuevos en Localizable")
    }

    @Test("ninguna cifra de Gratis ni de Pro escrita en el texto, salvo por formato", arguments: locales)
    func noHandWrittenFigures(locale: String) throws {
        for (key, value) in try Self.table(locale) {
            let withoutSpecifiers = value.replacingOccurrences(of: "%\\d\\$[@d]", with: "", options: .regularExpression)
            #expect(withoutSpecifiers.rangeOfCharacter(from: .decimalDigits) == nil, "\(locale): \(key) lleva una cifra")
        }
    }

    @Test("no promete lo que la app no tiene")
    func noFakeBenefits() throws {
        let base = try Self.table("es-419").values.joined(separator: " ").lowercased()
        for promise in ["avanzad", "adelantad", "soporte", "prioritari"] {
            #expect(!base.contains(promise), "La oferta promete «\(promise)…», que la app no tiene.")
        }
    }

    @Test("cada lector apunta a una clave que existe")
    func readersResolve() throws {
        let base = try Self.table("es-419")
        let code = try OfertaSource.code(OfertaSource.text)
        let regex = try NSRegularExpression(pattern: "(?:string|format)\\(\"([a-zA-Z0-9.]+)\"")
        let range = NSRange(code.startIndex..., in: code)
        let keys = regex.matches(in: code, range: range).compactMap { Range($0.range(at: 1), in: code).map { String(code[$0]) } }
        #expect(keys.count == base.count, "Un lector por clave: \(keys.count) lectores y \(base.count) claves.")
        for key in keys {
            #expect(base["ofertaProBeneficios.\(key)"] != nil, "Falta \(key) en la tabla")
        }
    }
}
