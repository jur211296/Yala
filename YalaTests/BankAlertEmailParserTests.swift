//
//  BankAlertEmailParserTests.swift
//  YalaTests
//
//  «Conectar Gmail», fase 1 (encargo 2026-10-23): el lector de avisos del banco que convierte un correo en borrador.
//  Fija lo que el video de la verificación de Google enseña —un aviso del BCP que llega a la Bandeja con su importe,
//  su divisa y su comercio— y que lo que no se reconoce queda en `nil` en vez de inventarse.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("BankAlertEmailParser")
struct BankAlertEmailParserTests {

    /// Un aviso de consumo del BCP en HTML, con la tabla que Gmail entrega como `text/html`.
    private let bcpConsumptionHTML = """
    <html><body><p>Hola Jürgen,</p><p>Realizaste un consumo con tu Tarjeta de Cr&eacute;dito BCP.</p>
    <table><tr><td>Monto total</td><td>S/ 1,245.90</td></tr><tr><td>Empresa</td><td>RAPPI*RESTAURANTES</td></tr>
    <tr><td>Fecha y hora</td><td>22 de octubre de 2026 - 08:15 PM</td></tr></table>
    <p>Empresas del grupo Credicorp</p></body></html>
    """

    @Test func bcpConsumption_inHTML_readsAmountCurrencyAndMerchant() {
        let text = BankAlertEmailParser.plainText(fromHTML: bcpConsumptionHTML)
        let result = BankAlertEmailParser.parse(subject: "Realizaste un consumo con tu Tarjeta de Crédito BCP", body: text)
        #expect(result == .init(amount: -1245.90, currencyCode: "PEN", merchant: "RAPPI*RESTAURANTES"))
    }

    @Test func plainText_dropsTagsAndDecodesEntities() {
        let text = BankAlertEmailParser.plainText(fromHTML: bcpConsumptionHTML)
        #expect(text.contains("Tarjeta de Crédito BCP"))
        #expect(!text.contains("<"))
        #expect(text.components(separatedBy: "\n").contains("Monto total"))
    }

    @Test func labelAndValueOnTheSameLine() {
        let result = BankAlertEmailParser.parse(subject: "x", body: "Monto total: S/. 45,90\nComercio: TAMBO")
        #expect(result == .init(amount: -45.90, currencyCode: "PEN", merchant: "TAMBO"))
    }

    @Test func dollarsAndIncome_keepThePositiveSign() {
        let result = BankAlertEmailParser.parse(
            subject: "Recibiste una transferencia", body: "Monto: US$ 50.00\nEnviado a: Juan Pérez")
        #expect(result == .init(amount: 50, currencyCode: "USD", merchant: "Juan Pérez"))
    }

    @Test func labeledAmountWinsOverAnEarlierFigure() {
        let body = "Tu línea disponible es S/ 9,000.00\nMonto total: S/ 12.50\nEmpresa: TAMBO"
        #expect(BankAlertEmailParser.parse(subject: "x", body: body).amount == -12.50)
    }

    @Test func merchantLabel_mustBeAWholeWord() {
        let body = "Monto: S/ 10.00\nEmpresas del grupo Credicorp"
        #expect(BankAlertEmailParser.parse(subject: "x", body: body).merchant == nil)
    }

    @Test func nothingRecognised_leavesEveryFieldNil() {
        #expect(BankAlertEmailParser.parse(subject: "Novedades", body: "Hola, conoce nuestras promociones")
            == .init(amount: nil, currencyCode: nil, merchant: nil))
    }

    @Test(arguments: [
        ("45.90", 45.90), ("45,90", 45.90), ("1,234.56", 1234.56), ("1.234,56", 1234.56),
        ("1 234,5", 1234.5), ("1,234", 1234), ("45", 45)
    ])
    func parseNumber_readsThousandsAndDecimals(raw: String, expected: Double) {
        #expect(BankAlertEmailParser.parseNumber(raw) == expected)
    }
}

#if DEV_BUILD
/// El paso de un mensaje de Gmail (`format=full`) a borrador, sin red: lo que hace `connectAndImport` tras la descarga.
@MainActor
@Suite("GmailBankAlertImporter · mensaje → borrador", .serialized)
struct GmailBankAlertImporterDraftTests {

    private func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Un correo multipart como lo entrega Gmail: cabeceras arriba y el HTML dentro de una parte.
    private func message(html: String, id: String = "18f2a") throws -> GmailBankAlertImporter.Message {
        let json = """
        {"id":"\(id)","internalDate":"1761185700000","snippet":"Realizaste un consumo",
         "payload":{"mimeType":"multipart/alternative",
          "headers":[{"name":"Subject","value":"Realizaste un consumo con tu Tarjeta de Crédito BCP"},
                     {"name":"From","value":"BCP <notificaciones@notificacionesbcp.com.pe>"}],
          "parts":[{"mimeType":"text/html","body":{"data":"\(base64URL(html))"}}]}}
        """
        return try JSONDecoder().decode(GmailBankAlertImporter.Message.self, from: Data(json.utf8))
    }

    @Test func bcpMessage_becomesAnEmailAlertDraftMarkedWithItsGmailID() throws {
        let context = try makeTestContext()
        let html = "<table><tr><td>Monto total</td><td>S/ 45.90</td></tr><tr><td>Empresa</td><td>TAMBO</td></tr></table>"
        let draft = GmailBankAlertImporter.makeDraft(from: try message(html: html), context: context)

        #expect(draft.amount == -45.90)
        #expect(draft.note == "TAMBO")
        #expect(draft.sourceType == .emailAlert)
        #expect(draft.evidence == "gmail:18f2a")
        #expect(draft.date == Date(timeIntervalSince1970: 1_761_185_700))
        #expect(draft.needsUserInput.contains("account"))
        #expect(draft.rawText?.contains("Monto total") == true)
    }

    @Test func unreadableBody_keepsTheSubjectAndAsksForTheAmount() throws {
        let context = try makeTestContext()
        let draft = GmailBankAlertImporter.makeDraft(from: try message(html: "<p>Hola</p>"), context: context)

        #expect(draft.amount == nil)
        #expect(draft.note == "Realizaste un consumo con tu Tarjeta de Crédito BCP")
        #expect(draft.needsUserInput.contains("amount"))
    }

    @Test func searchQuery_onlyAsksForTheKnownBankSenders() {
        #expect(GmailBankAlertImporter.searchQuery == "(from:notificaciones@notificacionesbcp.com.pe) newer_than:180d")
    }
}
#endif
