//
//  CreditCardStatementSummary.swift
//  Yala
//
//  El estado de cuenta de una tarjeta leído de sus `@Model` (card nmtk): lo que pintan la ficha y la fila del flujo de
//  caja. Las cuentas se agrupan en tarjetas con `AccountCardLogic`; los días de corte y de pago son de la principal
//  (`AccountCardLogic.ownsCardSettings`) y cada línea se factura en su divisa. Las cuentas van en el `@MainActor` porque
//  leen relaciones de SwiftData; el cálculo es `CreditCardStatementLogic`, puro.
//

import Foundation
import SwiftData

@MainActor
enum CreditCardStatementSummary {

    /// El estado de cuenta de una línea (o de una cuenta de una divisa).
    struct Line: Equatable {
        let accountName: String
        let currencyCode: String
        let statement: CreditCardStatementLogic.Statement
    }

    /// El estado de cuenta de una tarjeta.
    struct Card: Equatable {
        let accountID: UUID
        let name: String
        let cycle: CreditCardStatementLogic.Cycle
        let lines: [Line]
    }

    /// `nil` si la cuenta no es una tarjeta de crédito con día de corte. `head` es la principal (o la cuenta suelta) y
    /// `members` la principal y sus líneas.
    static func card(head: Account, members: [Account], now: Date, calendar: Calendar) -> Card? {
        guard AccountType(rawValue: head.type) == .creditCard,
              let statementDay = CreditCardStatementLogic.validDay(head.creditCardStatementDay),
              let paymentDay = CreditCardStatementLogic.validDay(head.creditCardPaymentDay),
              let cycle = CreditCardStatementLogic.cycle(statementDay: statementDay, paymentDay: paymentDay,
                                                         now: now, calendar: calendar)
        else { return nil }
        let lines = members.map { member in
            Line(accountName: member.name,
                 currencyCode: normalizeCurrencyCode(member.currencyCode),
                 statement: CreditCardStatementLogic.statement(
                    entries: CreditCardReminderScheduler.entries(of: member), cycle: cycle, now: now, calendar: calendar))
        }
        return Card(accountID: head.shortcutID, name: head.name, cycle: cycle, lines: lines)
    }

    /// Los pagos de tarjeta que caen en el mes de `month`, para la fila informativa del flujo de caja (D4-A): uno por
    /// tarjeta con día de corte y algo facturado sin pagar, en la fecha de pago de su último corte. Solo lo FACTURADO: lo
    /// que entra en el corte siguiente aún no tiene cifra. No suma a nada: los gastos con tarjeta ya cuentan el mes en que
    /// se hicieron y el pago es una transferencia entre cuentas propias.
    static func payments(accounts: [Account], inMonthOf month: Date, now: Date, calendar: Calendar) -> [Card] {
        let roles = accounts.lineRoles
        let live = accounts.filter { !$0.isArchived && !$0.isDeleted && $0.modelContext != nil }
        return live.accountCards(roles: roles).compactMap { group -> Card? in
            guard AccountCardLogic.ownsCardSettings(roles[group.head.shortcutID]),
                  let card = card(head: group.head, members: group.members, now: now, calendar: calendar),
                  calendar.isDate(card.cycle.paymentDate, equalTo: month, toGranularity: .month)
            else { return nil }
            let owed = card.lines.filter { $0.statement.billed > 0 }
            guard !owed.isEmpty else { return nil }
            return Card(accountID: card.accountID, name: card.name, cycle: card.cycle, lines: owed)
        }
    }
}
