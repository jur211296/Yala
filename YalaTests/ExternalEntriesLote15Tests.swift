//
//  ExternalEntriesLote15Tests.swift
//  YalaTests
//
//  Bugs del lote 15 de la auditoría UX 2.2 («Desde fuera de la app»):
//  · «Siri y Atajos» enseñaba tres frases que Siri no conoce.
//  · La guía de Apple Pay nombraba una acción («Registro Apple Pay») y un campo («Monto») que Atajos no tiene.
//  · «Anotar con Siri» mandaba el texto a la IA sin el consentimiento.
//  · Los widgets de pagos abrían Planificación en Presupuestos.
//  Los textos y los widgets viven en ficheros que la suite no compila o no puede abrir en otro idioma: se leen del árbol.
//

import Foundation
import Testing
@testable import Yala

private enum Repo {
    static func text(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Valor de `key` en el `Localizable.strings` de la app para `lang`, con las comillas escapadas ya resueltas.
    static func string(_ key: String, lang: String) throws -> String? {
        let source = try text("Yala/Resources/\(lang).lproj/Localizable.strings")
        for line in source.split(separator: "\n") where line.hasPrefix("\"\(key)\" = \"") {
            var value = line.dropFirst("\"\(key)\" = \"".count)
            guard value.hasSuffix("\";") else { continue }
            value = value.dropLast(2)
            return value.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return nil
    }

    static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "zh-Hans"]
}

@Suite("Lote 15 · «Siri y Atajos» solo enseña frases que Siri conoce")
struct SiriShortcutsScreenPhrasesTests {

    /// Las frases de `AppShortcutsProvider` solo existen en español e inglés: en esos idiomas, cada frase que enseña la
    /// pantalla tiene que estar registrada tal cual (con «Yala» en el sitio del nombre de la app).
    static let languagesWithRegisteredPhrases = ["es", "es-419", "es-ES", "es-AR", "en", "en-GB"]

    /// Lo que va entre comillas en un texto como «También puedes decir: "Anota un gasto en Yala"».
    private static func quoted(_ value: String) -> String {
        let parts = value.split(separator: "\"", omittingEmptySubsequences: false)
        return parts.count >= 3 ? String(parts[1]) : value
    }

    @Test(arguments: languagesWithRegisteredPhrases)
    func cadaFraseDeLaPantalla_estaRegistradaEnSiri(_ lang: String) throws {
        let provider = Repo.codeOnly(try Repo.text("Yala/App/Intents/AppShortcutsProvider.swift"))
        let keys = ["siriShortcuts.siri.phrase", "siriShortcuts.siri.alt1", "siriShortcuts.siri.alt2",
                    "siriShortcuts.phrase.quick", "siriShortcuts.phrase.voice", "siriShortcuts.phrase.image",
                    "siriShortcuts.phrase.applePay"]
        for key in keys {
            let value = try #require(try Repo.string(key, lang: lang), "Falta \(key) en \(lang).")
            let phrase = Self.quoted(value)
            #expect(phrase.hasSuffix(" Yala"), "\(lang) · \(key): «\(phrase)» no termina en el nombre de la app.")
            let registered = "\"\(phrase.dropLast(" Yala".count)) \\(.applicationName)\""
            #expect(provider.contains(registered),
                    "\(lang) · \(key): la pantalla enseña «\(phrase)» y Siri no la conoce (\(registered)).")
        }
    }

    /// La fila «Automatización» enseñaba «Registra desde automatización en Yala»: esa acción no existe.
    @Test func laFilaDeUnaAccionInexistente_noVuelve() throws {
        let view = Repo.codeOnly(try Repo.text("Yala/App/Views/Settings/SiriShortcutsView.swift"))
        #expect(!view.contains("siriShortcuts.phrase.automation"))
        for lang in Repo.languages {
            #expect(try Repo.string("siriShortcuts.phrase.automation", lang: lang) == nil,
                    "\(lang) conserva el texto de una acción que no existe.")
        }
    }
}

@Suite("Lote 15 · la guía de Apple Pay nombra lo que se ve en Atajos")
struct ApplePayGuideNamesTests {

    /// El paso 3 manda a elegir la acción de Yala por su nombre: tiene que ser el título que enseña Atajos.
    @Test(arguments: Repo.languages)
    func elPaso3_nombraLaAccionPorSuTituloReal(_ lang: String) throws {
        let title = try #require(try Repo.string("shortcut.applePay.title", lang: lang))
        let step = try #require(try Repo.string("tutorials.applePay.step2.desc", lang: lang))
        #expect(step.contains(title), "\(lang): el paso 3 no dice «\(title)», que es como se llama en Atajos.")
        let inbox = try #require(try Repo.string("tutorials.inboxApproval.step0.desc", lang: lang))
        #expect(inbox.contains(title), "\(lang): el tutorial de la Bandeja nombra otra acción que no es «\(title)».")
    }

    /// El paso 4 empieza por el campo de la acción de Yala donde va el importe: el nombre del parámetro.
    @Test(arguments: ["es", "es-419", "es-ES", "es-AR", "pt", "pt-BR", "pt-PT"])
    func elPaso4_empiezaPorElCampoQueTieneLaAccion(_ lang: String) throws {
        let field = try #require(try Repo.string("shortcut.applePay.param.amount", lang: lang))
        let step = try #require(try Repo.string("tutorials.applePay.step3.desc", lang: lang))
        let preposition = lang.hasPrefix("es") ? "En" : "Em"
        #expect(step.hasPrefix("\(preposition) \(field) "),
                "\(lang): el paso 4 empieza por un campo que la acción no tiene (el suyo es «\(field)»).")
    }
}

@Suite("Lote 15 · «Anotar con Siri» respeta el consentimiento de IA")
@MainActor
struct SiriNaturalEntryConsentTests {

    @Test func sinConsentimiento_elTextoNoSaleDelTelefono() async {
        var remoteCalls = 0
        let result = await SiriNaturalEntryIntent.parseTransactions("Gasté 25 en almuerzo", consentAccepted: false) { _ in
            remoteCalls += 1
            return []
        }
        #expect(remoteCalls == 0, "Sin el consentimiento, el texto se mandó a la IA.")
        #expect(result.isOfflineFallback)
        #expect(result.transactions.first?.amount == 25, "La lectura local tenía que sacar el monto.")
    }

    @Test func conConsentimiento_leeConLaIA() async {
        var remoteCalls = 0
        let parsed = ParsedTransaction(
            amount: 25, date: nil, note: "almuerzo", isExpense: true, subcategoryHint: nil, tagHints: [],
            currencyHint: nil,
            confidence: .init(amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0))
        let result = await SiriNaturalEntryIntent.parseTransactions("Gasté 25 en almuerzo", consentAccepted: true) { _ in
            remoteCalls += 1
            return [parsed]
        }
        #expect(remoteCalls == 1)
        #expect(!result.isOfflineFallback)
        #expect(result.transactions == [parsed])
    }

    @Test func conConsentimientoYSinConexion_caeALaLecturaLocal() async {
        struct Offline: Error {}
        let result = await SiriNaturalEntryIntent.parseTransactions("25 taxi", consentAccepted: true) { _ in
            throw Offline()
        }
        #expect(result.isOfflineFallback)
        #expect(result.transactions.first?.amount == 25)
    }

    /// El cable: el intent lee el consentimiento y se lo pasa al lector; sin esa línea, los tres casos de arriba no
    /// protegen nada.
    @Test func elIntentPasaElConsentimientoAlLector() throws {
        let source = Repo.codeOnly(try Repo.text("Yala/App/Intents/QuickExpenseIntent.swift"))
        #expect(source.contains(
            "let aiConsentAccepted = UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted)"))
        #expect(source.contains("consentAccepted: aiConsentAccepted"))
        #expect(source.components(separatedBy: "TranscriptionParserService.shared.parseMultiple(").count == 2,
                "El intent llama a la IA por otro camino que no pasa por el consentimiento.")
    }
}

@Suite("Lote 15 · los widgets de pagos abren Pagos planificados")
struct PaymentsWidgetURLTests {

    @Test(arguments: ["YalaWidgets/Widgets/ScheduledPaymentsWidget.swift", "YalaWidgets/Widgets/AccessoryWidgets.swift"])
    func elWidgetPideLaSubPestanaDePagos(_ path: String) throws {
        let source = Repo.codeOnly(try Repo.text(path))
        #expect(source.contains("WidgetURLHelper.url(for: \"planning/scheduled-payments\")"))
        #expect(!source.contains("WidgetURLHelper.url(for: \"planning\")"),
                "Un widget de pagos vuelve a abrir Planificación sin elegir la sub-pestaña (cae en Presupuestos).")
    }

    @Test func laAppLlevaEsaURLaPagosPlanificados() throws {
        let source = Repo.codeOnly(try Repo.text("Yala/App/AppBootstrapper.swift"))
        // El `case "planning":` del enlace es el que va seguido de la rama de la sub-pestaña (hay otro antes, el del
        // hook de XCUITest, que mapea el destino a secas).
        let check = try #require(source.range(of: "if url.pathComponents.contains(\"scheduled-payments\") {"))
        let before = String(source[..<check.lowerBound].suffix(80))
        #expect(before.contains("case \"planning\":"), "La rama de la sub-pestaña no cuelga del caso `planning`.")
        let branch = String(source[check.upperBound...].prefix(200))
        #expect(branch.contains("setOrDeferDeepLink(.scheduledPayments)"))
    }
}
