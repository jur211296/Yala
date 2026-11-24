//
//  InboxMatchFixtures.swift
//  YalaTests
//
//  Lo común de las pruebas del emparejador entre fuentes (`InboxMatchLogic`): un calendario de Lima y un «ahora» fijo
//  (regla de tests: nunca el reloj), la cuenta «BCP Visa» del informe y un borrador por fuente con lo que esa fuente trae
//  de verdad: Apple Pay y el aviso con hora; el correo, la IA y la web, solo el día (a mediodía, como los pone la app).
//  Apple Pay en soles sale con la cuenta resuelta, como en el informe: la persona tiene una sola cuenta en soles.
//

import Foundation
@testable import Yala

enum MatchFixtures {

    static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    /// La cuenta «BCP Visa» en soles de los escenarios del informe, terminada en 4821.
    static let bcpVisa = UUID(uuidString: "0B0B0B0B-0000-4000-8000-000000004821") ?? UUID()
    static let interbank = UUID(uuidString: "1B1B1B1B-0000-4000-8000-000000009955") ?? UUID()

    /// Un instante de noviembre de 2026 en Lima.
    static func at(day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
        let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        return lima.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// Un dólar a 3,80 soles: la tasa de los escenarios en otra moneda.
    static let converter: InboxMatchLogic.Converter = { amount, from, to in
        switch (from, to) {
        case ("USD", "PEN"): return amount * 3.80
        case ("PEN", "USD"): return amount / 3.80
        default: return from == to ? amount : nil
        }
    }

    static func applePay(
        _ amount: Double, currency: String? = "PEN", day: Int = 15, _ hour: Int, _ minute: Int = 0,
        account: UUID? = bcpVisa, merchant: String? = "Starbucks"
    ) -> InboxMatchLogic.Candidate {
        .init(source: .applePay, amount: amount, currencyCode: currency, date: at(day: day, hour, minute),
              hasExactTime: true, accountID: account, merchant: merchant)
    }

    static func notice(
        _ amount: Double, currency: String? = "PEN", day: Int = 15, _ hour: Int, _ minute: Int = 0,
        account: UUID? = bcpVisa, last4: String? = "****4821", merchant: String? = "STARBUCKS COFFEE MIRAFLO"
    ) -> InboxMatchLogic.Candidate {
        .init(source: .bankNotice, amount: amount, currencyCode: currency, date: at(day: day, hour, minute),
              hasExactTime: true, accountID: account, last4: last4, merchant: merchant)
    }

    static func email(
        _ amount: Double, currency: String? = "PEN", day: Int = 15,
        account: UUID? = bcpVisa, last4: String? = "4821", merchant: String? = "STARBUCKS MIRAFLORES"
    ) -> InboxMatchLogic.Candidate {
        .init(source: .bankEmail, amount: amount, currencyCode: currency, date: at(day: day, 12),
              hasExactTime: false, accountID: account, last4: last4, merchant: merchant)
    }

    static func ai(
        _ amount: Double, currency: String? = "PEN", day: Int = 15, account: UUID? = bcpVisa,
        merchant: String? = "Starbucks"
    ) -> InboxMatchLogic.Candidate {
        .init(source: .aiConnector, amount: amount, currencyCode: currency, date: at(day: day, 12),
              hasExactTime: false, accountID: account, merchant: merchant)
    }

    /// Un movimiento ya guardado: con su hora y su cuenta. Sin origen conocido, `manual`.
    static func saved(
        _ amount: Double, day: Int = 15, _ hour: Int, _ minute: Int = 0, source: InboxMatchLogic.Source = .manual,
        account: UUID? = bcpVisa, merchant: String? = "Starbucks"
    ) -> InboxMatchLogic.Candidate {
        .init(source: source, amount: amount, currencyCode: "PEN", date: at(day: day, hour, minute), hasExactTime: true,
              accountID: account, last4: "4821", merchant: merchant)
    }

    static func pair(
        _ arrivals: [InboxMatchLogic.Candidate], saved: [InboxMatchLogic.Candidate] = []
    ) -> InboxMatchLogic.Outcome {
        InboxMatchLogic.pair(arrivals, saved: saved, converter: converter, calendar: lima)
    }

    static func compare(_ a: InboxMatchLogic.Candidate, _ b: InboxMatchLogic.Candidate) -> InboxMatchLogic.Comparison {
        InboxMatchLogic.compare(a, b, converter: converter, calendar: lima)
    }
}
