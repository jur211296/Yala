//
//  InboxMatchRuleTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 1: la regla de coincidencia del emparejador, campo a campo, en sus bordes (sección 3·B
//  de `docs/propuestas/bandeja-sin-duplicados/README.md`), qué fuente manda en cada campo y qué borradores entran.
//

import Foundation
import Testing
@testable import Yala

@Suite("Emparejador entre fuentes · la regla campo a campo")
struct InboxMatchRuleTests {

    private typealias F = MatchFixtures
    private typealias Logic = InboxMatchLogic

    // MARK: - Fuentes

    @Test("Dos borradores de la misma fuente nunca coinciden, aunque todo lo demás sea idéntico")
    func sameSource_isNeverAMatch() {
        for source in Logic.Source.allCases {
            let a = Logic.Candidate(source: source, amount: -10, currencyCode: "PEN", date: F.at(day: 15, 9),
                                    hasExactTime: true, accountID: F.bcpVisa, merchant: "Tambo")
            let b = Logic.Candidate(source: source, amount: -10, currencyCode: "PEN", date: F.at(day: 15, 9),
                                    hasExactTime: true, accountID: F.bcpVisa, merchant: "Tambo")
            #expect(F.compare(a, b).level == .none, "fuente \(source)")
        }
    }

    @Test("Qué borradores entran al emparejador: las cinco fuentes que avisan de un cargo, y nada de grupos")
    @MainActor
    func sourceMapping() {
        #expect(Logic.source(for: .applePay, isBankNotice: false) == .applePay)
        #expect(Logic.source(for: .emailAlert, isBankNotice: false) == .bankEmail)
        #expect(Logic.source(for: .automation, isBankNotice: true) == .bankNotice)
        #expect(Logic.source(for: .automation, isBankNotice: false) == .web)
        #expect(Logic.source(for: .aiConnector, isBankNotice: false) == .aiConnector)
        let outside: [DraftSourceType] = [
            .groupExpense, .groupSettlement, .groupScheduledExpense, .scheduledPayment, .subscription,
            .siri, .voice, .receiptPhoto, .screenshotList, .screenshotSingle, .manual,
        ]
        for type in outside {
            #expect(Logic.source(for: type, isBankNotice: false) == nil, "\(type) no entra")
        }
    }

    // MARK: - Tipo

    @Test("Un ingreso nunca se une a un gasto, e importe cero no se une a nada")
    func kind() {
        #expect(Logic.kindLevel(-5, -5) == .strong)
        #expect(Logic.kindLevel(5, 5) == .strong)
        #expect(Logic.kindLevel(-5, 5) == .none)
        #expect(Logic.kindLevel(0, -5) == .none)
    }

    // MARK: - Cuenta

    @Test("Cuenta: la misma es fuerte; dos distintas, nada")
    func account_sameOrDifferent() {
        let base = F.notice(-10, 9, 0)
        #expect(Logic.accountLevel(base, F.email(-10)) == .strong)
        #expect(Logic.accountLevel(base, F.email(-10, account: F.interbank, last4: "9955")) == .none)
    }

    @Test("Cuenta: una sin cuenta con los mismos últimos 4 es fuerte; con otros, nada; sin dígitos, dudosa")
    func account_withoutOneSide() {
        let withAccount = F.notice(-10, 9, 0, last4: "****4821")
        #expect(Logic.accountLevel(withAccount, F.email(-10, account: nil, last4: "4821")) == .strong)
        #expect(Logic.accountLevel(withAccount, F.email(-10, account: nil, last4: "7777")) == .none)
        #expect(Logic.accountLevel(withAccount, F.applePay(-10, 9, 0, account: nil)) == .doubtful)
        #expect(Logic.accountLevel(F.applePay(-10, 9, 0, account: nil), F.ai(-10, account: nil)) == .doubtful)
    }

    @Test("Últimos 4: se leen de lo que diga la fuente, y menos de 4 cifras no cuentan")
    func last4Normalization() {
        #expect(Logic.normalizedLast4("****4821") == "4821")
        #expect(Logic.normalizedLast4("Visa 1234 5678 9012 4821") == "4821")
        #expect(Logic.normalizedLast4("*821") == nil)
        #expect(Logic.normalizedLast4(nil) == nil)
    }

    // MARK: - Importe

    @Test("Importe: ±0,01 en la misma moneda es fuerte; un céntimo y medio ya no")
    func amount_strongTolerance() {
        #expect(F.compare(F.notice(-42.50, 9, 0), F.email(-42.51)).amount == .strong)
        #expect(F.compare(F.notice(-42.50, 9, 0), F.email(-42.49)).amount == .strong)
        #expect(F.compare(F.notice(-42.50, 9, 0), F.email(-42.52)).amount == .doubtful)
    }

    @Test("Importe: hasta 3 % en la misma moneda es dudosa; más, nada")
    func amount_doubtfulTolerance() {
        #expect(F.compare(F.notice(-100, 9, 0), F.email(-97)).amount == .doubtful)
        #expect(F.compare(F.notice(-100, 9, 0), F.email(-96.90)).amount == .none)
        #expect(F.compare(F.notice(-100, 9, 0), F.email(-110)).amount == .none)
    }

    @Test("Importe: otra moneda convertida, hasta 4 % es dudosa y nunca fuerte")
    func amount_otherCurrency() {
        let dollars = F.applePay(-10, currency: "USD", 9, 0, account: nil)
        #expect(F.compare(dollars, F.email(-38.00)).amount == .doubtful)
        #expect(F.compare(dollars, F.email(-39.50)).amount == .doubtful)
        #expect(F.compare(dollars, F.email(-40.00)).amount == .none)
    }

    @Test("Importe: una moneda que la fuente no dijo no deja unir solo")
    func amount_unknownCurrency() {
        let symbolOnly = F.notice(-42.50, currency: nil, 9, 0)
        #expect(F.compare(symbolOnly, F.email(-42.50)).amount == .doubtful)
    }

    // MARK: - Tiempo

    @Test("Tiempo con hora en los dos: 6 h es fuerte, de ahí a 72 h dudosa, más allá nada")
    func time_bothExact() {
        let base = F.applePay(-10, day: 15, 8, 0)
        #expect(F.compare(base, F.notice(-10, day: 15, 14, 0)).time == .strong)
        #expect(F.compare(base, F.notice(-10, day: 15, 14, 1)).time == .doubtful)
        #expect(F.compare(base, F.notice(-10, day: 18, 8, 0)).time == .doubtful)
        #expect(F.compare(base, F.notice(-10, day: 18, 8, 1)).time == .none)
    }

    @Test("Tiempo con solo el día en uno: ese día o el siguiente es fuerte; antes o más tarde, dudosa hasta 3 días")
    func time_oneDayOnly() {
        let purchase = F.applePay(-10, day: 15, 23, 50)
        #expect(F.compare(purchase, F.email(-10, day: 15)).time == .strong)
        #expect(F.compare(purchase, F.email(-10, day: 16)).time == .strong)
        #expect(F.compare(purchase, F.email(-10, day: 17)).time == .doubtful)
        #expect(F.compare(purchase, F.email(-10, day: 14)).time == .doubtful)
        #expect(F.compare(purchase, F.email(-10, day: 18)).time == .doubtful)
        #expect(F.compare(purchase, F.email(-10, day: 19)).time == .none)
    }

    @Test("Tiempo a medianoche exacta y cruzando de mes: cuenta días de calendario, sin contar el instante dos veces")
    func time_midnightAndMonthCrossing() {
        let emailOn: (Int, Int) -> Logic.Candidate = { day, month in
            Logic.Candidate(source: .bankEmail, amount: -10, currencyCode: "PEN", date: F.at(day: day, 12, month: month),
                            hasExactTime: false, accountID: F.bcpVisa)
        }
        let atMidnight = Logic.Candidate(source: .applePay, amount: -10, currencyCode: "PEN",
                                         date: F.at(day: 1, 0, 0, month: 12), hasExactTime: true, accountID: F.bcpVisa)
        #expect(F.compare(atMidnight, emailOn(1, 12)).time == .strong)
        #expect(F.compare(atMidnight, emailOn(30, 11)).time == .doubtful)
        let lastMinute = Logic.Candidate(source: .applePay, amount: -10, currencyCode: "PEN",
                                         date: F.at(day: 30, 23, 59, month: 11), hasExactTime: true, accountID: F.bcpVisa)
        #expect(F.compare(lastMinute, emailOn(1, 12)).time == .strong)
        #expect(F.compare(lastMinute, emailOn(2, 12)).time == .doubtful)
    }

    @Test("Tiempo sin hora en ninguno: solo el mismo día es fuerte")
    func time_bothDayOnly() {
        #expect(F.compare(F.ai(-10, day: 15), F.email(-10, day: 15)).time == .strong)
        #expect(F.compare(F.ai(-10, day: 15), F.email(-10, day: 16)).time == .doubtful)
        #expect(F.compare(F.ai(-10, day: 15), F.email(-10, day: 19)).time == .none)
    }

    // MARK: - Comercio

    @Test("Comercio: palabras en común, sin acentos ni ruido del banco, o una dentro de otra")
    func merchant_lookAlike() {
        #expect(Logic.merchantsLookAlike("Starbucks", "STARBUCKS COFFEE MIRAFLO"))
        #expect(Logic.merchantsLookAlike("Café Bisetti", "CAFE BISETTI SAC"))
        #expect(Logic.merchantsLookAlike("Uber", "PAGO EN LINEA DLC*UBER"))
        #expect(Logic.merchantsLookAlike("Wong", "WONGSUPERMERCADO"))
        #expect(Logic.merchantsLookAlike("KFC", "kfc jockey plaza"))
        #expect(!Logic.merchantsLookAlike("Starbucks", "TAMBO+ MIRAFLORES"))
        #expect(!Logic.merchantsLookAlike("Rappi", "UBER EATS"))
    }

    @Test("Comercio vacío no resta: el correo a veces no lo trae")
    func merchant_emptyIsNeutral() {
        #expect(Logic.merchantsLookAlike(nil, "Starbucks"))
        #expect(Logic.merchantsLookAlike("   ", "Starbucks"))
        #expect(Logic.merchantsLookAlike("POS 1234", "Starbucks"))
        #expect(Logic.merchantsLookAlike("Compra Visa", "Tambo"), "solo ruido del banco cuenta como vacío")
    }

    @Test("Comercio distinto baja a dudosa, nunca a nada")
    func merchant_differentIsDoubtful() {
        let comparison = F.compare(F.applePay(-10, 9, 0, merchant: "Starbucks"), F.notice(-10, 9, 1, merchant: "TAMBO"))
        #expect(comparison.merchant == .doubtful)
        #expect(comparison.level == .doubtful)
    }

    // MARK: - El conjunto

    @Test("El conjunto vale lo que su campo más flojo")
    func level_isTheWeakestField() {
        let strong = F.compare(F.applePay(-10, 9, 0), F.notice(-10, 9, 1, merchant: "STARBUCKS"))
        #expect(strong.level == .strong)
        let oneDoubtful = F.compare(F.applePay(-10, 9, 0), F.notice(-10, 18, 0, merchant: "STARBUCKS"))
        #expect(oneDoubtful.level == .doubtful)
        let oneNone = F.compare(F.applePay(-10, 9, 0), F.notice(10, 9, 1, merchant: "STARBUCKS"))
        #expect(oneNone.level == .none)
    }

    @Test("Comparar es simétrico")
    func compare_isSymmetric() {
        let pairs: [(Logic.Candidate, Logic.Candidate)] = [
            (F.applePay(-89.90, day: 15, 23, 50), F.email(-89.90, day: 16)),
            (F.applePay(-11.30, currency: "USD", 13, 5, account: nil), F.email(-42.94)),
            (F.applePay(-100, 7, 45, merchant: "Primax"), F.notice(-98.50, 7, 50, merchant: "PRIMAX")),
            (F.ai(-10, day: 15), F.email(-10, day: 17)),
        ]
        for (a, b) in pairs {
            #expect(F.compare(a, b).level == F.compare(b, a).level)
        }
    }

    // MARK: - Qué fuente manda

    @Test("Manda el banco en el importe, Apple Pay en el comercio y la hora, quien trae los últimos 4 en la cuenta")
    func resolve_fieldByField() {
        var consumption = Logic.Consumption(F.ai(-42.50, account: nil, merchant: "café"))
        consumption.absorb(F.email(-42.60, last4: "4821", merchant: "STARBUCKS MIRAFLORES"))
        consumption.absorb(F.applePay(-42.50, 13, 5, account: nil, merchant: "Starbucks"))

        let resolved = consumption.resolved

        #expect(resolved.money == .init(amount: -42.60, currencyCode: "PEN"))
        #expect(resolved.moneySource == .bankEmail)
        #expect(resolved.originalMoney == .init(amount: -42.50, currencyCode: "PEN"))
        #expect(resolved.merchant == "Starbucks")
        #expect(resolved.merchantSource == .applePay)
        #expect(resolved.date == F.at(day: 15, 13, 5))
        #expect(resolved.dateSource == .applePay)
        #expect(resolved.accountID == F.bcpVisa)
        #expect(resolved.accountSource == .bankEmail)
        #expect(resolved.last4 == "4821")
        #expect(resolved.sources == [.aiConnector, .bankEmail, .applePay])
    }

    @Test("Sin Apple Pay, la hora es la del aviso; sin ninguna hora, el día del correo")
    func resolve_timeFallbacks() {
        var withNotice = Logic.Consumption(F.email(-10, day: 16))
        withNotice.absorb(F.notice(-10, day: 15, 23, 55))
        #expect(withNotice.resolved.date == F.at(day: 15, 23, 55))
        #expect(withNotice.resolved.dateSource == .bankNotice)

        var dayOnly = Logic.Consumption(F.ai(-10, day: 16))
        dayOnly.absorb(F.email(-10, day: 16))
        #expect(!dayOnly.resolved.hasExactTime)
        #expect(dayOnly.resolved.dateSource == .bankEmail)
    }

    @Test("Un consumo no absorbe una fuente que ya tiene")
    func consumption_oneOfEach() {
        var consumption = Logic.Consumption(F.applePay(-10, 9, 0))
        let firstNotice = consumption.absorb(F.notice(-10, 9, 1))
        let secondNotice = consumption.absorb(F.notice(-10, 9, 2))
        #expect(firstNotice)
        #expect(!secondNotice)
        #expect(consumption.members.count == 2)
    }

    @Test("Lo que llega se compara con lo que manda en el consumo: el aviso en soles no vuelve a preguntar por la moneda")
    func compareWithConsumption_usesResolvedFields() {
        var consumption = Logic.Consumption(F.applePay(-11.30, currency: "USD", 13, 5, account: nil))
        consumption.absorb(F.email(-42.94))

        let comparison = Logic.compare(F.notice(-42.94, 13, 6), with: consumption, converter: F.converter, calendar: F.lima)

        #expect(comparison.amount == .strong)
        #expect(comparison.account == .strong)
        #expect(comparison.level == .strong)
    }
}
