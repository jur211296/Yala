//
//  ChatBubbleTextTests.swift
//  YalaTests
//
//  Cómo parte la burbuja del chat el texto de una respuesta en párrafos (`ChatBubbleText.paragraphs`): una línea en
//  blanco separa párrafos; un salto simple no.
//

import Testing
@testable import Yala

struct ChatBubbleTextTests {

    @Test func blankLineSeparatesParagraphs() {
        let text = "Este mes llevas **S/ 120** en Transporte.\n\nLa mayor parte es **Taxi**."
        #expect(ChatBubbleText.paragraphs(of: text) == [
            "Este mes llevas **S/ 120** en Transporte.",
            "La mayor parte es **Taxi**.",
        ])
    }

    @Test func singleLineBreakStaysInsideTheParagraph() {
        let text = "Gastos:\n- Taxi S/ 85\n- Bus S/ 35"
        #expect(ChatBubbleText.paragraphs(of: text) == [text])
    }

    @Test func extraBlankLinesAndWindowsBreaksDoNotMakeEmptyParagraphs() {
        let text = "Uno.\r\n\r\n\n\nDos.\n\n"
        #expect(ChatBubbleText.paragraphs(of: text) == ["Uno.", "Dos."])
    }

    @Test func textWithoutBlankLinesIsOneParagraphAsIs() {
        #expect(ChatBubbleText.paragraphs(of: "Hola") == ["Hola"])
    }

    @Test func blankTextIsKeptSoTheBubbleIsNotEmptyOfViews() {
        #expect(ChatBubbleText.paragraphs(of: "  ") == ["  "])
    }
}
