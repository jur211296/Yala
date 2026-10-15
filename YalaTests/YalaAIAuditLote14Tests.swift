//
//  YalaAIAuditLote14Tests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 14 (Yala IA): los arreglos de texto que se prueban leyendo los `.strings`.
//  - La presentación decía «Te presento a Yala AI» en los idiomas donde la función se llama «Yala IA» o «Yala KI».
//  - El contador decía «Te quedan 1 preguntas hoy»: la frase no depende del número en ningún idioma.
//
//  Las otras dos mitades (el aviso al llegar al tope y el «S/» de la hoja de detalles) son de pantalla y las prueba
//  `ChatMessagingLayoutUITests`.
//

import Foundation
import Testing

struct YalaAIAuditLote14Tests {

    private static let resources: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Yala/Resources")

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = resources.appendingPathComponent("\(locale).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func locales() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "Base.lproj" }
            .map { String($0.dropLast(".lproj".count)) }
            .sorted()
    }

    /// Cada texto de la presentación que nombra a la función usa el nombre del chat de ESE idioma
    /// (`chat.assistantName`), y no otro: «Yala AI» en español era el nombre en inglés.
    @Test func onboarding_namesTheAssistantLikeTheChatDoes() throws {
        let locales = try Self.locales()
        #expect(locales.count == 16, "Se esperaban los 16 idiomas de la app.")
        let names = ["Yala AI", "Yala IA", "Yala KI"]
        for locale in locales {
            let table = try Self.strings(locale)
            let own = try #require(table["chat.assistantName"], "\(locale) sin chat.assistantName")
            for (key, value) in table where key.hasPrefix("yalaAI.onboarding.") {
                for name in names where name != own {
                    #expect(!value.contains(name), "\(locale) · \(key) dice «\(name)»; el chat dice «\(own)».")
                }
            }
        }
    }

    /// «Te quedan 1 preguntas hoy»: el contador va en una forma que vale para cualquier número.
    @Test func questionsRemaining_readsWellForOne() throws {
        let es = try Self.strings("es")
        #expect(es["chat.questionsRemaining"] == "Preguntas que te quedan hoy: %d")
        let en = try Self.strings("en")
        #expect(en["chat.questionsRemaining"] == "Questions left today: %d")
        for locale in try Self.locales() {
            let value = try #require(try Self.strings(locale)["chat.questionsRemaining"], "\(locale) sin contador")
            #expect(value.contains("%d"), "\(locale): el contador perdió el número.")
        }
    }
}
