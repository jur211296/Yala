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
            for (key, value) in table where key.hasPrefix("yalaAI.onboarding.") || key.hasPrefix("chat.l14.") {
                for name in names where name != own {
                    #expect(!value.contains(name), "\(locale) · \(key) dice «\(name)»; el chat dice «\(own)».")
                }
            }
        }
    }

    /// UX 2.2 · L14-2: el paso «Antes de empezar» reparte el texto del aviso de permiso sin perder nada de lo que
    /// decía: qué se envía (de los últimos 13 meses) y que no entrena a la IA. Y nombra la pantalla donde se apaga con un
    /// solo hueco, que el código rellena con los títulos reales.
    @Test func consentStep_keepsWhatTheAlertSaid_inEveryLocale() throws {
        for locale in try Self.locales() {
            let table = try Self.strings(locale)
            let reads = try #require(table["yalaAI.onboarding.l14.consent.readsBody"], "\(locale) sin «Qué lee»")
            #expect(reads.contains("13"), "\(locale): «Qué lee» perdió los 13 meses.")
            let alert = try #require(table["aiConsent.chatMessage"], "\(locale) sin el aviso")
            #expect(alert.contains("13"), "\(locale): el aviso dejó de decir 13 meses; revisa también «Qué lee».")
            let decide = try #require(table["yalaAI.onboarding.l14.consent.decideBody"], "\(locale) sin «Tú decides»")
            #expect(decide.components(separatedBy: "%@").count == 2, "\(locale): «Tú decides» debe tener un solo hueco.")
            for key in ["yalaAI.onboarding.l14.consent.useBody", "yalaAI.onboarding.l14.consent.cta",
                        "chat.l14.greetingTwoUses", "chat.l14.logBody"] {
                let value = try #require(table[key], "\(locale) sin \(key)")
                #expect(!value.isEmpty, "\(locale) · \(key) vacío")
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
