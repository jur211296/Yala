//
//  VocabularioSaldarYReflejarTests.swift
//  YalaTests
//
//  Decisión 40 de la revisión 2.3 (9-nov-2026): un solo vocabulario para saldar y un solo nombre para el puente, en los
//  16 idiomas. «Saldos» es la pantalla; «Saldar», la acción y el botón (sustituye «Apuntar pago» y «Liquidar»); «Pago»,
//  lo registrado, con el estado «Confirmado»; «Para quedar a mano», solo el título de sección. El puente se llama
//  «Reflejar en tus cuentas» en todas partes.
//
//  El test compara cada texto que se ve con el de la palabra canónica de su idioma: así vale en los 16 sin repetir las
//  traducciones aquí.
//

import Foundation
import Testing

@Suite("Vocabulario de saldar y del puente (decisión 40 de 2.3)")
struct VocabularioSaldarYReflejarTests {

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func catalog(_ language: String) throws -> [String: String] {
        let text = try repoFile("Yala/Resources/\(language).lproj/Localizable.strings")
        var entries: [String: String] = [:]
        let pattern = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";"#, options: .anchorsMatchLines)
        let range = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: range) {
            guard let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) else { continue }
            entries[String(text[key])] = String(text[value])
        }
        return entries
    }

    static let languages = [
        "es", "es-419", "es-AR", "es-ES", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "pt", "zh-Hans",
    ]

    // MARK: - Saldar

    /// El formulario de pago se llama «Saldar» y su botón dice «Saldar», igual que el botón de Saldos que lo abre.
    @Test("«Apuntar pago» pasa a «Saldar» en el título y el botón", arguments: languages)
    func settleFormSaysSettle(language: String) throws {
        let strings = try Self.catalog(language)
        let settle = try #require(strings["groups.l13.settle"], "\(language): falta «Saldar»")
        #expect(strings["groups.settlement.title"] == settle, "\(language): el título del formulario no es «Saldar»")
        #expect(strings["groups.settlement.registerPayment"] == settle, "\(language): el botón no es «Saldar»")
    }

    /// «Para quedar a mano» es el título de la sección de Saldos, y el resumen que se comparte usa el mismo.
    @Test("El resumen compartido titula su sección como Saldos", arguments: languages)
    func shareableSummaryUsesTheSectionTitle(language: String) throws {
        let strings = try Self.catalog(language)
        let section = try #require(strings["groups.l13.settleUp.title"], "\(language): falta el título de sección")
        #expect(strings["groups.shareableSummary.settleUp"] == section, "\(language): el resumen titula distinto")
    }

    /// Lo registrado es un «Pago»: su estado concuerda con él («Confirmado», no «Confirmada», que venía de «liquidación»).
    @Test("El estado de un pago es «Confirmado» donde el género lo marca")
    func paymentStatusAgreesWithPayment() throws {
        let expected = [
            "es": "Confirmado", "es-419": "Confirmado", "es-AR": "Confirmado", "es-ES": "Confirmado",
            "pt-BR": "Confirmado", "pt-PT": "Confirmado", "pt": "Confirmado", "it": "Confermato", "pl": "Potwierdzona",
        ]
        for (language, value) in expected {
            #expect(try Self.catalog(language)["groups.balance.confirmed"] == value, "\(language)")
        }
    }

    /// En español, ninguna pantalla de Grupos dice ya «Apuntar pago» ni «Liquidar».
    @Test("El español no conserva «Apuntar pago» ni «Liquidar» en lo que se ve")
    func spanishHasNoOldWords() throws {
        let visibleKeys = [
            "groups.settlement.title", "groups.settlement.registerPayment", "groups.settlement.settleHint",
            "groups.balance.confirmed", "groups.shareableSummary.settleUp",
        ]
        for language in ["es", "es-419", "es-AR", "es-ES"] {
            let strings = try Self.catalog(language)
            for key in visibleKeys {
                let value = try #require(strings[key], "\(language): falta \(key)")
                #expect(!value.localizedCaseInsensitiveContains("apuntar"), "\(language) · \(key) = \(value)")
                #expect(!value.localizedCaseInsensitiveContains("liquid"), "\(language) · \(key) = \(value)")
            }
        }
    }

    // MARK: - Puente

    /// Los tres interruptores del puente (Ajustes de Grupos, ajustes de un grupo y opciones del grupo) se llaman como la
    /// sección: «Reflejar en tus cuentas».
    @Test("Los interruptores del puente se llaman «Reflejar en tus cuentas»", arguments: languages)
    func bridgeTogglesUseOneName(language: String) throws {
        let strings = try Self.catalog(language)
        let name = try #require(strings["groups.bridge.activateTitle"], "\(language): falta el nombre del puente")
        #expect(strings["groups.globalSettings.bridgeSectionTitle"] == name, "\(language): sección global")
        #expect(strings["groups.settings.personalIntegrationSectionTitle"] == name, "\(language): sección del grupo")
        #expect(strings["groups.globalSettings.bridgeToggleLabel"] == name, "\(language): interruptor global")
        #expect(strings["groups.settings.personalIntegrationToggleLabel"] == name, "\(language): interruptor del grupo")
        #expect(strings["groups.l19.options.personalToggle"] == name, "\(language): opciones del grupo")
    }

    /// La pregunta tras guardar un gasto con el puente apagado usa el mismo verbo, no «registrar en tu Yala personal».
    @Test("La pregunta del puente usa el mismo verbo", arguments: languages)
    func bridgeQuestionUsesTheSameVerb(language: String) throws {
        let strings = try Self.catalog(language)
        let title = try #require(strings["groups.bridge.optoutAlertTitle"], "\(language): falta la pregunta")
        #expect(!title.localizedCaseInsensitiveContains("Yala"), "\(language): la pregunta sigue nombrando «tu Yala personal»: \(title)")
        if language.hasPrefix("es") {
            #expect(title == "¿Reflejar en tus cuentas?", "\(language): \(title)")
            #expect(strings["groups.bridge.optoutAlertYes"] == "Sí, reflejar", "\(language)")
        }
    }
}
