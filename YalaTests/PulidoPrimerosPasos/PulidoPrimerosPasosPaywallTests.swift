//
//  PulidoPrimerosPasosPaywallTests.swift
//  YalaTests
//
//  Pulido de Primeros pasos y del paywall visto en el iPhone 14 (observación del 25-nov-2026): la hoja de la segunda
//  moneda, la fila de pasos del mazo, el nombre del presupuesto, la intro de Grupos, el confeti del cierre, el título
//  final con pasos para después y el texto del paywall sin precios. La lógica se prueba directa; el cableado de las
//  vistas, leyendo el código sin comentarios (documentar lo que el test busca no lo pone en verde).
//

import Foundation
import Testing

@testable import Yala

private enum PulidoPPPSource {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PulidoPrimerosPasos/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/PulidoPrimerosPasosPaywall.strings")
        let plist = try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: String])
    }
}

// MARK: - Título final

@Suite("Pulido Primeros pasos · título final")
struct PulidoPrimerosPasosFinalTitleTests {

    @Test("con los siete hechos dice «completos»; con alguno para después, no")
    func titleDependsOnLaterSteps() {
        #expect(PrimerosPasosFinalTitleLogic.title(laterCount: 0) == .complete)
        #expect(PrimerosPasosFinalTitleLogic.title(laterCount: 1) == .forNow)
        #expect(PrimerosPasosFinalTitleLogic.title(laterCount: 5) == .forNow, "el caso visto: 5 de 7 para después")
    }

    @Test("los dos títulos son textos distintos y ninguno sale crudo")
    func titlesAreDistinct() {
        let complete = PrimerosPasosFinalTitleLogic.complete.text
        let forNow = PrimerosPasosFinalTitleLogic.forNow.text
        #expect(complete != forNow)
        #expect(!forNow.hasPrefix("pulidoPPP."))
        #expect(complete == L10n.PrimerosPasos23.Final.doneTitle)
    }

    @Test("la tarjeta del cierre elige el título por los pasos para después")
    func cardUsesTheLogic() throws {
        let code = try PulidoPPPSource.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(code.contains("PrimerosPasosFinalTitleLogic.title(laterCount: laterSteps.count).text"))
        #expect(!code.contains("Text(L10n.PrimerosPasos23.Final.doneTitle)"), "el título fijo volvió")
    }
}

// MARK: - Paywall sin precios

@Suite("Pulido Primeros pasos · paywall sin precios")
struct PulidoPaywallPricesTests {

    @Test("el aviso sin precios usa el texto neutro, no el de la conexión")
    func usesTheNeutralText() throws {
        let code = try PulidoPPPSource.code("Yala/App/Views/Subscription/ProPurchaseComponents.swift")
        #expect(code.contains("Text(PulidoPrimerosPasosPaywallText.pricesUnavailable)"))
        #expect(!code.contains("L10n.TrialOffer.pricesUnavailable"))
    }

    @Test("el texto neutro no culpa a la conexión en ningún idioma", arguments: PulidoPPPSource.locales)
    func neutralInEveryLocale(_ locale: String) throws {
        let value = try #require(try PulidoPPPSource.table(locale)["pulidoPPP.paywall.pricesUnavailable"])
        let blame = ["conexi", "connection", "verbindung", "connexion", "connessione", "verbinding", "połączen",
                     "conexão", "ligação", "接続", "网络"]
        for word in blame {
            #expect(!value.lowercased().contains(word), "\(locale): «\(value)» menciona la conexión")
        }
    }
}

// MARK: - Selector de la segunda moneda

@Suite("Pulido Primeros pasos · selector de otra moneda")
struct PulidoOtherCurrencyPickerTests {

    @Test("la primera moneda conserva «Moneda principal»; añadir o cambiar otra dice «Otra moneda»")
    func titleBySlot() {
        #expect(FirstAccountCurrencyPickerTitleLogic.title(slotIndex: 0) == nil)
        #expect(FirstAccountCurrencyPickerTitleLogic.title(slotIndex: nil) == PulidoPrimerosPasosPaywallText.otherCurrencyTitle)
        #expect(FirstAccountCurrencyPickerTitleLogic.title(slotIndex: 1) == PulidoPrimerosPasosPaywallText.otherCurrencyTitle)
    }

    @Test("el paso 1 pasa el título y los nombres sin mayúsculas forzadas; la hoja los respeta")
    func wiring() throws {
        let flow = try PulidoPPPSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift")
        #expect(flow.contains("FirstAccountCurrencyPickerTitleLogic.title(slotIndex: target.index)"))
        #expect(flow.contains("CurrencyPickerSheet(selectedCurrency: $selection, title: title, namesAsWritten: true)"))
        let sheet = try PulidoPPPSource.code("Yala/App/Views/Settings/CurrencyPickerSheet.swift")
        #expect(sheet.contains(".navigationTitle(title ?? L10n.Settings.preferredCurrency)"))
        #expect(sheet.contains("Text(namesAsWritten ? info.name : info.name.capitalized)"))
    }

    @Test("en español la grafía de la tabla ya va en minúscula: no hace falta forzarla")
    func spanishNamesAreLowercase() throws {
        let es = try String(contentsOf: PulidoPPPSource.repoRoot
            .appending(path: "Yala/Resources/es-419.lproj/Localizable.strings"), encoding: .utf8)
        #expect(es.contains("\"currency.pen\" = \"sol peruano\";"))
        #expect(es.contains("\"currency.usd\" = \"dólar estadounidense\";"))
    }
}

// MARK: - Fila de pasos del mazo

@Suite("Pulido Primeros pasos · fila de pasos al mismo tamaño")
struct PulidoDeckStepsRowTests {

    @Test("fuera de accesibilidad se intenta la fila de siete; con accesibilidad, la rejilla de cuatro")
    func layoutChoice() {
        #expect(SetupDeckStepsLayoutLogic.triesSingleRow(isAccessibilitySize: false))
        #expect(!SetupDeckStepsLayoutLogic.triesSingleRow(isAccessibilitySize: true))
        #expect(SetupDeckStepsLayoutLogic.fallbackColumns == 4)
    }

    @Test("en la fila de siete ninguna etiqueta se encoge; si no cabe, cede a la rejilla")
    func singleRowNeverShrinks() throws {
        let code = try PulidoPPPSource.code("Yala/App/Views/Panel/SetupDeckProgress.swift")
        #expect(code.contains("ViewThatFits(in: .horizontal)"))
        #expect(code.contains(".minimumScaleFactor(fitsLabel ? 1 : 0.6)"))
        #expect(code.contains(".fixedSize(horizontal: fitsLabel, vertical: false)"))
        #expect(code.contains("item(step, fitsLabel: true)"))
    }
}

// MARK: - Nombre del presupuesto, intro de Grupos, confeti

@Suite("Pulido Primeros pasos · presupuesto, Grupos y confeti")
struct PulidoBudgetGroupsConfettiTests {

    @Test("el nombre del presupuesto cabe en dos líneas en el widget pequeño y en la fila grande")
    func budgetNameTwoLines() throws {
        for path in ["Yala/App/Views/Panel/BudgetsWidget.swift", "Yala/App/Views/Panel/BudgetWidgetRow.swift"] {
            let code = try PulidoPPPSource.code(path).replacingOccurrences(of: " ", with: "")
            #expect(code.contains("Text(summary.budget.name)"), "\(path)")
            let after = try #require(code.components(separatedBy: "Text(summary.budget.name)").last)
            let next = after.prefix(240)
            #expect(next.contains(".lineLimit(2)"), "\(path): el nombre volvió a una línea")
        }
    }

    @Test("la intro de Grupos dice «Antes de empezar», como las de los pasos 1, 3 y 4")
    func groupsIntroEyebrow() throws {
        let code = try PulidoPPPSource.code("Yala/App/Views/Onboarding/PrimerosPasos/GroupsTutorialFlowView.swift")
        #expect(code.contains("eyebrow: L10n.PrimerosPasos23.Account.introEyebrow"))
        #expect(!code.contains("T.eyebrow(part + 1, 3)"))
    }

    @Test("el confeti del cierre lleva la máscara que deja limpia la franja de «Cerrar»")
    func confettiMask() throws {
        let code = try PulidoPPPSource.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(code.contains(".mask { SetupCelebrationMask() }"))
        #expect(SetupCelebrationMask.clearBottom >= 44, "la franja limpia cubre al menos el alto del botón")
    }
}

// MARK: - La tabla en los 16 idiomas

@Suite("Pulido Primeros pasos · textos en los 16 idiomas")
struct PulidoPPPStringsParityTests {

    @Test(arguments: PulidoPPPSource.locales)
    func everyLocale_hasEveryKey_withText(_ locale: String) throws {
        let reference = try PulidoPPPSource.table("es-419")
        let strings = try PulidoPPPSource.table(locale)
        #expect(Set(strings.keys) == Set(reference.keys), "\(locale): claves distintas de es-419.")
        for (key, value) in strings {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(key) vacía.")
        }
    }

    @Test func aliases_copyTheirReference() throws {
        #expect(try PulidoPPPSource.table("es") == PulidoPPPSource.table("es-419"))
        #expect(try PulidoPPPSource.table("pt") == PulidoPPPSource.table("pt-BR"))
    }

    @Test func referenceSpanish_readsAsAsked() throws {
        let es = try PulidoPPPSource.table("es-419")
        #expect(es["pulidoPPP.currency.otherTitle"] == "Otra moneda")
        #expect(es["pulidoPPP.final.doneForNowTitle"] == "¡Listo por ahora!")
        #expect(es["pulidoPPP.paywall.pricesUnavailable"] == "Ahora no podemos mostrar los precios. Inténtalo en un rato.")
    }

    @Test(arguments: PulidoPPPSource.locales)
    func theAppBundle_resolvesTheTable(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let value = PulidoPrimerosPasosPaywallText.string("final.doneForNowTitle", resolution: resolution)
        #expect(value == (try PulidoPPPSource.table(locale)["pulidoPPP.final.doneForNowTitle"]))
        #expect(!value.hasPrefix("pulidoPPP."))
    }

    @Test func aMissingKey_comesBackRaw() {
        #expect(PulidoPrimerosPasosPaywallText.string("no.existe") == "pulidoPPP.no.existe")
    }
}
