//
//  VisionNoteCleanerTests.swift
//  YalaTests
//
//  La nota de un movimiento leído de una foto o un PDF (ticket image-note-uses-bank-template-instead-of-merchant,
//  2026-10-10). Casos con la forma real de las alertas de BCP, Interbank, BBVA, Scotiabank, Yape y Plin, en
//  español y en inglés, tal como el modelo devuelve `merchant` y `note` — también las respuestas viejas, que
//  pegaban la plantilla del banco detrás del comercio.
//

import Testing

@testable import Yala

struct VisionNoteCleanerTests {

    struct Case: CustomTestStringConvertible, Sendable {
        let merchant: String?
        let note: String?
        let expected: String
        var testDescription: String { "\(merchant ?? "nil") | \(note ?? "nil") → \(expected)" }
    }

    // MARK: - El reporte

    /// El caso real de Jürgen: «GROK XAI - Consumo con tarjeta de crédito BCP» tenía que ser «Grok (xAI)».
    @Test func reportedCase_bcpTemplateIsDropped_andBrandIsRecognized() {
        #expect(VisionNoteCleaner.note(merchant: "GROK XAI", note: "Consumo con tarjeta de crédito BCP") == "Grok (xAI)")
    }

    // MARK: - Plantillas de banco, por banco y por idioma

    @Test(arguments: [
        // BCP
        Case(merchant: "GROK XAI SAN FRANCISCO US", note: nil, expected: "Grok (xAI)"),
        Case(merchant: "WONG SAN ISIDRO", note: "Consumo con Tarjeta de Débito BCP", expected: "Wong San Isidro"),
        Case(merchant: "Consumo con tarjeta de crédito BCP en GROK XAI", note: nil, expected: "Grok (xAI)"),
        Case(merchant: "MC DONALDS", note: "Nro. de operación: 0012345", expected: "McDonald's"),
        // Interbank
        Case(merchant: "TAMBO+ LARCOMAR", note: "Op. 882140 POS 00012", expected: "Tambo+ Larcomar"),
        Case(merchant: "Compra con tu tarjeta en WONG", note: "Interbank", expected: "Wong"),
        Case(merchant: "SPOTIFY P2A3B4C5", note: "Credit card purchase", expected: "Spotify"),
        // BBVA
        Case(merchant: "PLAZA VEA MIRAFLORES", note: "Has realizado una compra con tu tarjeta BBVA", expected: "Plaza Vea Miraflores"),
        Case(merchant: "UBER *TRIP HELP.UBER.COM", note: "Card purchase", expected: "Uber"),
        Case(merchant: "BBVA", note: "You made a purchase with your debit card ending 7712", expected: "BBVA - You made a purchase with your debit card ending"),
        // Scotiabank
        Case(merchant: "KFC JOCKEY PLAZA", note: "Consumo aprobado con tarjeta de crédito ****0098", expected: "KFC Jockey Plaza"),
        Case(merchant: "AMZN Mktp US*2K4X91LQ", note: "Purchase approved", expected: "Amazon"),
        // Yape
        Case(merchant: "Juan Pérez Quispe", note: "¡Yapeaste! Nro. de operación 03154827", expected: "Juan Pérez Quispe"),
        Case(merchant: "Yape", note: "Juan Pérez", expected: "Juan Pérez"),
        Case(merchant: "MARIA LOPEZ", note: "You received a Yape", expected: "Maria Lopez"),
        // Plin
        Case(merchant: "Plin", note: "Pago a BODEGA SANTA ROSA", expected: "Bodega Santa Rosa"),
        Case(merchant: "CARLOS RAMIREZ", note: "Plin transfer sent - Transaction 991204", expected: "Carlos Ramirez"),
    ])
    func bankTemplates_areDropped(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }

    // MARK: - Códigos

    @Test(arguments: [
        Case(merchant: "SHELL OIL 5741", note: nil, expected: "Shell Oil"),
        Case(merchant: "Purchase at CHEVRON 0012345", note: nil, expected: "Chevron"),
        Case(merchant: "WONG", note: "Terminal 12 - Autorización 553201", expected: "Wong"),
        Case(merchant: "Scotiabank", note: "Consumo aprobado ****1234", expected: "Scotiabank - Consumo aprobado"),
    ])
    func codes_areDropped(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }

    // MARK: - Lo que NO se toca

    /// Una nota útil se queda: sucursal, ciudad, qué se compró.
    @Test(arguments: [
        Case(merchant: "Walmart", note: "Groceries", expected: "Walmart - Groceries"),
        Case(merchant: "Starbucks", note: "Larcomar", expected: "Starbucks - Larcomar"),
        Case(merchant: "Restaurante Central", note: "Restaurante Central", expected: "Restaurante Central"),
        Case(merchant: "PLAZA VEA", note: "Plaza Vea - Miraflores", expected: "Plaza Vea - Miraflores"),
    ])
    func usefulNotes_areKept(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }

    /// Líneas de extracto sin comercio: describen el movimiento y se quedan enteras. «Transfer», «Retiro» o
    /// «Comercio» solo se recortan delante de un nombre («Transferencia a PEDRO G.»).
    @Test(arguments: [
        Case(merchant: "Internal Transfer", note: nil, expected: "Internal Transfer"),
        Case(merchant: "Retiro cajero Ag. Miraflores", note: nil, expected: "Retiro cajero Ag. Miraflores"),
        Case(merchant: "Abono haberes Empresa SAC", note: nil, expected: "Abono haberes Empresa SAC"),
        Case(merchant: "Comercio Local", note: nil, expected: "Comercio Local"),
        Case(merchant: "Acquisto online", note: nil, expected: "Acquisto online"),
        Case(merchant: "Pago a tercero", note: nil, expected: "Pago a tercero"),
        Case(merchant: "TRANSFERENCIA A PEDRO G.", note: nil, expected: "Pedro G."),
        Case(merchant: "Bizum de Laura M.", note: nil, expected: "Laura M."),
        Case(merchant: "MARIA FERNANDA TORRES", note: "Transferencia recibida", expected: "Maria Fernanda Torres"),
    ])
    func statementDescriptions_areKept(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }

    /// Si todo es plantilla, se queda lo leído sin códigos: una nota con palabras de más es mejor que vacía.
    @Test func allTemplate_keepsTheReadTextWithoutCodes() {
        #expect(VisionNoteCleaner.note(merchant: nil, note: "Pago tarjeta BCP") == "Pago tarjeta BCP")
        #expect(VisionNoteCleaner.note(merchant: "Consumo con tarjeta 4821", note: nil) == "Consumo con tarjeta")
        #expect(VisionNoteCleaner.note(merchant: nil, note: nil) == "")
        #expect(VisionNoteCleaner.note(merchant: "", note: "") == "")
    }

    // MARK: - Mayúsculas

    @Test(arguments: [
        Case(merchant: "LA LUCHA SANGUCHERIA", note: nil, expected: "La Lucha Sangucheria"),
        Case(merchant: "COMPRA EL CORTE INGLES", note: nil, expected: "El Corte Ingles"),
        Case(merchant: "BODEGA DON LUCHO", note: nil, expected: "Bodega Don Lucho"),
        Case(merchant: "CASA DE LA ABUELA", note: nil, expected: "Casa de La Abuela"),
        Case(merchant: "7-ELEVEN", note: nil, expected: "7-Eleven"),
        Case(merchant: "CVS PHARMACY", note: nil, expected: "CVS Pharmacy"),
        Case(merchant: "ACME SERVICIOS SAC", note: nil, expected: "Acme Servicios SAC"),
        Case(merchant: "Supermercados La Economía S.A.", note: nil, expected: "Supermercados La Economía S.A."),
        Case(merchant: "iShop Perú", note: nil, expected: "iShop Perú"),
    ])
    func allCaps_getsNormalCapitalization_mixedCaseIsKept(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }

    // MARK: - Marcas de descriptor

    @Test(arguments: [
        Case(merchant: "PAYPAL *NETFLIX", note: nil, expected: "Netflix"),
        Case(merchant: "OPENAI *CHATGPT SUBSCR", note: nil, expected: "ChatGPT (OpenAI)"),
        Case(merchant: "CLAUDE.AI SUBSCRIPTION", note: nil, expected: "Claude (Anthropic)"),
        Case(merchant: "UBER *EATS", note: nil, expected: "Uber Eats"),
        Case(merchant: "APPLE.COM/BILL", note: nil, expected: "Apple"),
        Case(merchant: "SQ *CAFE MIA", note: nil, expected: "Cafe Mia"),
        Case(merchant: "DLO*RAPPI", note: nil, expected: "Rappi"),
    ])
    func descriptorBrands_areNamed(_ c: Case) {
        #expect(VisionNoteCleaner.note(merchant: c.merchant, note: c.note) == c.expected)
    }
}
