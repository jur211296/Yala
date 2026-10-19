//
//  YalaIAAnswerLinkPolicyTests.swift
//  YalaTests
//
//  Los enlaces que escribe el modelo (decisión 4A de Jürgen, 2026-10-18; ticket
//  `yala-ia-answer-renders-model-links-as-tappable`): en la burbuja de Yala IA y en las tarjetas de Observaciones solo
//  se pueden tocar los de yala-app.pe; los demás salen como texto. Que un enlace a otro dominio «no abra nada al
//  tocarlo» es que el texto no lleve el atributo `link`: sin él, SwiftUI no lo pinta como enlace ni lo abre.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct YalaIAAnswerLinkPolicyTests {

    @Test("solo https a yala-app.pe o a un subdominio suyo", arguments: [
        ("https://yala-app.pe", true),
        ("https://yala-app.pe/ayuda", true),
        ("https://YALA-APP.PE/privacidad", true),
        ("https://www.yala-app.pe/ayuda", true),
        ("http://yala-app.pe/ayuda", false),
        ("https://example.com/?gasto=85", false),
        ("https://yala-app.pe.example.com/", false),
        ("https://noyala-app.pe/", false),
        ("https://example.com/yala-app.pe", false),
        ("https://user@example.com", false),
        ("mailto:hola@yala-app.pe", false),
        ("tel:+51999999999", false),
        ("yala://records", false),
        ("javascript:alert(1)", false),
    ])
    func allowedLinks(_ raw: String, allowed: Bool) throws {
        let url = try #require(URL(string: raw))
        #expect(YalaIAAnswerLinkPolicy.isAllowed(url) == allowed, "\(raw)")
    }

    private func links(in text: AttributedString) -> [(label: String, url: URL)] {
        text.runs.compactMap { run in run.link.map { (String(text[run.range].characters), $0) } }
    }

    @Test("un enlace markdown a otro dominio queda como texto; uno a yala-app.pe se puede tocar")
    func markdownLinks() {
        let text = YalaIAAnswerLinkPolicy.inlineMarkdown(
            "Más en la [ayuda de Yala](https://yala-app.pe/ayuda) o en [este enlace](https://example.com/?gasto=85)."
        )
        let found = links(in: text)
        #expect(found.count == 1)
        #expect(found.first?.label == "ayuda de Yala")
        #expect(found.first?.url.absoluteString == "https://yala-app.pe/ayuda")
        // El texto del enlace quitado sigue ahí, sin la URL.
        #expect(String(text.characters) == "Más en la ayuda de Yala o en este enlace.")
    }

    @Test("los enlaces automáticos (<https://…>) siguen la misma regla")
    func autolinks() {
        let text = YalaIAAnswerLinkPolicy.inlineMarkdown("Mira <https://example.com/x> y <https://yala-app.pe/y>")
        #expect(links(in: text).map(\.url.absoluteString) == ["https://yala-app.pe/y"])
    }

    @Test("la negrita y el código se quedan, y los saltos de línea también")
    func formattingSurvives() {
        let text = YalaIAAnswerLinkPolicy.inlineMarkdown("Llevas **S/ 120** en `Taxi`\nsegunda línea")
        #expect(String(text.characters) == "Llevas S/ 120 en Taxi\nsegunda línea")
        let bold = text.runs.first { run in String(text[run.range].characters) == "S/ 120" }
        #expect(bold?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        let code = text.runs.first { run in String(text[run.range].characters) == "Taxi" }
        #expect(code?.inlinePresentationIntent?.contains(.code) == true)
    }

    @Test("las tarjetas de Observaciones filtran igual")
    func insightCardsFilterToo() {
        let text = AIInsightCardComponents.markdownAttributed("[a](https://example.com) y [b](https://yala-app.pe/b)")
        #expect(links(in: text).map(\.url.absoluteString) == ["https://yala-app.pe/b"])
    }

    @Test("la burbuja pinta con la política, no con LocalizedStringKey (que dejaba tocar cualquier enlace)")
    func bubbleUsesThePolicy() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views/Chat/ChatMessageBubble.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("Text(YalaIAAnswerLinkPolicy.inlineMarkdown(paragraph))"))
        #expect(!source.contains("LocalizedStringKey("))
    }
}
