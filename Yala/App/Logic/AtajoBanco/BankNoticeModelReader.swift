//
//  BankNoticeModelReader.swift
//  Yala
//
//  El respaldo de las reglas (opción L2): el modelo del propio iPhone (Apple Intelligence) lee el aviso que ninguna regla
//  entiende. Sin servidor: el texto no sale del teléfono. Solo en iPhone con el modelo listo
//  (`SiriOnDeviceEntry.modelState`); en los demás, el aviso queda como «No entendimos este aviso».
//
//  «Un monto mal leído es peor que no leerlo» (definición del atajo, L2): el importe que devuelve el modelo tiene que
//  estar escrito en el aviso (`BankNoticeAmount.amountsWritten`). Si no, no se acepta.
//

import Foundation
import FoundationModels

nonisolated enum BankNoticeModelReader {

    /// Lo que el modelo devuelve.
    @Generable
    struct Reading {
        @Guide(description: "true solo si el aviso informa de un movimiento de dinero ya hecho: una compra, un pago, una transferencia enviada o recibida. false si es publicidad, un código, una clave, un saldo o una operación rechazada.")
        var isMovement: Bool
        @Guide(description: "Importe del movimiento tal como aparece en el aviso, en positivo. Vacío si no hay.")
        var amount: Double?
        @Guide(description: "Código ISO 4217 de la moneda si el aviso la dice (PEN para S/, USD para US$); vacío si no.")
        var currencyCode: String?
        @Guide(description: "true si sale dinero de la persona (compra, pago, envío); false si le entra (le pagan, recibe).")
        var isExpense: Bool
        @Guide(description: "Comercio donde compró o persona que le pagó, tal como lo escribe el aviso. Vacío si no aparece.")
        var counterparty: String?
    }

    /// Lee el aviso con el modelo. `nil` si el modelo no está listo, falla o devuelve algo que no se puede aceptar.
    static func read(_ text: String) async -> BankNoticeReading? {
        guard SiriOnDeviceEntry.modelState == .available else { return nil }
        let instructions = """
        Lees avisos de bancos y billeteras de Perú (BCP, Yape, Interbank, Plin, BBVA, Scotiabank y otros). \
        Dices si el aviso informa de un movimiento de dinero ya hecho y, si lo es, su importe, moneda, sentido y comercio. \
        No inventes importes: si el aviso no dice uno, déjalo vacío.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: BankNoticeParser.normalized(text), generating: Reading.self)
            return accept(response.content, text: text)
        } catch {
            #if DEBUG
            print("BankNoticeModelReader: Error: \(error)")
            #endif
            return nil
        }
    }

    /// Lo que se acepta de la respuesta del modelo. Pura, para los tests.
    static func accept(_ reading: Reading, text: String) -> BankNoticeReading? {
        guard reading.isMovement else { return .notAMovement }
        guard let raw = reading.amount, raw.isFinite, raw > 0,
              // Por texto y no desde `Double`: `Decimal(25.9)` guarda 25,8999999999999979…
              let amount = Decimal(string: String(raw), locale: Locale(identifier: "en_US_POSIX")),
              BankNoticeAmount.amountsWritten(in: text).contains(amount) else { return nil }
        let code = reading.currencyCode?.uppercased().trimmingCharacters(in: .whitespaces)
        let counterparty = reading.counterparty.map(BankNoticeParser.cleanCounterparty)
        return .movement(
            BankNoticeMovement(
                amount: amount,
                currencyCode: (code?.count == 3) ? code : nil,
                ambiguousSymbol: nil,
                isExpense: reading.isExpense,
                counterparty: (counterparty?.isEmpty ?? true) ? nil : counterparty,
                cardLast4: BankNoticeParser.last4(in: BankNoticeParser.normalized(text))
            ),
            ruleID: nil
        )
    }
}
