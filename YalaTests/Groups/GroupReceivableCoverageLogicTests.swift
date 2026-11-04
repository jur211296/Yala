//
//  GroupReceivableCoverageLogicTests.swift
//  YalaTests
//
//  Grupos B · card 9: qué parte de una venta por cobrar está cobrada y en qué fecha (`GroupReceivableCoverageLogic`).
//  La tabla de arriba son los cuatro casos del escenario 6 de `docs/disenos/grupos-tu-parte-en-lineas/opcion-b.html`;
//  debajo, los bordes que la regla tiene que aguantar.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos B · lo cobrado de una venta, lo más antiguo primero")
struct GroupReceivableCoverageLogicTests {

    // MARK: - Andamio

    private typealias Logic = GroupReceivableCoverageLogic
    private let me = "yo"
    private let ana = "ana"
    private let beto = "beto"

    private static func day(_ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/Lima")
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? .distantPast
    }

    private static func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? -1
    }

    private func expense(
        _ id: UUID = UUID(), on date: Date, amount: Double, paidBy: String, shares: [String: Double],
        currency: String = "PEN", isSale: Bool = false, isSettled: Bool = false
    ) -> Logic.ExpenseInput {
        Logic.ExpenseInput(
            id: id, date: date, amount: amount, currencyCode: currency, paidByMemberID: paidBy, isSettled: isSettled,
            shares: shares.sorted { $0.key < $1.key }.map { Logic.Share(memberID: $0.key, amount: $0.value) },
            isSale: isSale)
    }

    private func payment(
        _ id: UUID = UUID(), on date: Date, amount: Double, from: String, to: String,
        currency: String = "PEN", confirmed: Bool = true
    ) -> Logic.SettlementInput {
        Logic.SettlementInput(
            id: id, date: date, amount: amount, currencyCode: currency, fromMemberID: from, toMemberID: to,
            isConfirmed: confirmed)
    }

    private func coverage(
        _ expenses: [Logic.ExpenseInput], _ settlements: [Logic.SettlementInput], currency: String = "PEN"
    ) -> [UUID: Logic.Coverage] {
        Logic.coverage(of: Logic.events(
            for: me, currencyCode: currency, expenses: expenses, settlements: settlements))
    }

    // MARK: - Escenario 6: los cuatro casos de la página

    /// Pago parcial: la cena de enero (adelantaste 100 de Ana) y la venta de marzo (120). En abril Ana paga 100 y cubre la
    /// cena: la venta sigue por cobrar. En mayo paga 120 y la cubre: el ingreso cuenta en mayo.
    @Test func partialPayment_coversTheOldestFirst_andTheSaleCountsInMay() throws {
        let sale = UUID(), april = UUID(), may = UUID()
        let result = coverage(
            [expense(on: Self.day(1, 10), amount: 200, paidBy: me, shares: [me: 100, ana: 100]),
             expense(sale, on: Self.day(3, 5), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(april, on: Self.day(4, 2), amount: 100, from: ana, to: me),
             payment(may, on: Self.day(5, 2), amount: 120, from: ana, to: me)])

        let venta = try #require(result[sale])
        #expect(venta.owed == 120)
        #expect(venta.collected == [.init(eventID: may, date: Self.day(5, 2), amount: 120)])
        #expect(venta.remaining == 0)
        #expect(!venta.collected.contains { $0.eventID == april })
    }

    /// Lo mismo, cortado en abril: la venta entera sigue por cobrar y abril no tiene ingreso.
    @Test func partialPayment_afterTheFirstPayment_theSaleIsStillUncollected() throws {
        let sale = UUID()
        let result = coverage(
            [expense(on: Self.day(1, 10), amount: 200, paidBy: me, shares: [me: 100, ana: 100]),
             expense(sale, on: Self.day(3, 5), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(on: Self.day(4, 2), amount: 100, from: ana, to: me)])
        let venta = try #require(result[sale])
        #expect(venta.collected.isEmpty)
        #expect(venta.remaining == 120)
    }

    /// Venta cubierta a medias: Ana paga 50 hoy (50 de ingreso hoy) y 70 al pagar el resto.
    @Test func saleCoveredInHalves_countsEachPaymentOnItsDay() throws {
        let sale = UUID(), first = UUID(), second = UUID()
        let partial = coverage(
            [expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(first, on: Self.day(11, 8), amount: 50, from: ana, to: me)])
        let half = try #require(partial[sale])
        #expect(half.collected == [.init(eventID: first, date: Self.day(11, 8), amount: 50)])
        #expect(half.remaining == 70)

        let full = coverage(
            [expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(first, on: Self.day(11, 8), amount: 50, from: ana, to: me),
             payment(second, on: Self.day(11, 20), amount: 70, from: ana, to: me)])
        let venta = try #require(full[sale])
        #expect(venta.collected == [
            .init(eventID: first, date: Self.day(11, 8), amount: 50),
            .init(eventID: second, date: Self.day(11, 20), amount: 70),
        ])
        #expect(venta.remaining == 0)
    }

    /// Deudas cruzadas: venta de 120 y un almuerzo que pagó Ana (tu parte, 64). El grupo dice que Ana te debe 56; te paga
    /// 56 y el saldo queda en cero: la venta está cubierta entera. Los 64 cuentan el día del almuerzo (bajó tu saldo) y los
    /// 56 el día del pago.
    @Test func crossedDebts_aZeroBalanceCoversTheWholeSale() throws {
        let sale = UUID(), lunch = UUID(), pay = UUID()
        let result = coverage(
            [expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [ana: 120], isSale: true),
             expense(lunch, on: Self.day(11, 3), amount: 128, paidBy: ana, shares: [me: 64, ana: 64])],
            [payment(pay, on: Self.day(11, 8), amount: 56, from: ana, to: me)])
        let venta = try #require(result[sale])
        #expect(venta.collected == [
            .init(eventID: lunch, date: Self.day(11, 3), amount: 64),
            .init(eventID: pay, date: Self.day(11, 8), amount: 56),
        ])
        #expect(venta.collected.reduce(Decimal(0)) { $0 + $1.amount } == 120)
        #expect(venta.remaining == 0)
    }

    /// La deuda cruzada al revés: ya le debías 64 a Ana cuando le vendes. La venta salda esa deuda en su propia fecha y
    /// el pago de 56 cubre el resto. Sin esto, un saldo en cero dejaría 64 por cobrar para siempre.
    @Test func crossedDebts_aDebtFromBeforeTheSaleIsSettledOnTheSaleDate() throws {
        let sale = UUID(), lunch = UUID(), pay = UUID()
        let result = coverage(
            [expense(lunch, on: Self.day(10, 28), amount: 128, paidBy: ana, shares: [me: 64, ana: 64]),
             expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(pay, on: Self.day(11, 8), amount: 56, from: ana, to: me)])
        let venta = try #require(result[sale])
        #expect(venta.collected == [
            .init(eventID: sale, date: Self.day(11, 1), amount: 64),
            .init(eventID: pay, date: Self.day(11, 8), amount: 56),
        ])
        #expect(venta.remaining == 0)
    }

    /// Simplificar deudas: Beto te debe una venta, pero el grupo le dice que le pague a Ana (a quien tú le debes lo mismo).
    /// Su pago a Ana no te toca; lo que cubre la venta es lo que bajó tu saldo, tu parte de lo que pagó Ana.
    @Test func simplifiedDebts_countYourBalance_notWhoPaysWhom() throws {
        let sale = UUID(), anaPaid = UUID(), betoToAna = UUID()
        let expenses = [
            expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [beto: 120], isSale: true),
            expense(anaPaid, on: Self.day(11, 4), amount: 240, paidBy: ana, shares: [me: 120, ana: 120]),
        ]
        let settlements = [payment(betoToAna, on: Self.day(11, 9), amount: 120, from: beto, to: ana)]
        let events = Logic.events(for: me, currencyCode: "PEN", expenses: expenses, settlements: settlements)
        #expect(!events.contains { $0.id == betoToAna })

        let venta = try #require(coverage(expenses, settlements)[sale])
        #expect(venta.collected == [.init(eventID: anaPaid, date: Self.day(11, 4), amount: 120)])
        #expect(venta.remaining == 0)
    }

    /// Y con tu saldo sin bajar, la venta sigue por cobrar aunque Beto pague a otro.
    @Test func simplifiedDebts_aPaymentBetweenOthersCoversNothing() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [beto: 120], isSale: true)],
            [payment(on: Self.day(11, 9), amount: 120, from: beto, to: ana)])[sale])
        #expect(venta.collected.isEmpty)
        #expect(venta.remaining == 120)
    }

    // MARK: - Bordes

    /// El caso Ana de la card 10: la venta de 120 y su pago de 120 el día 8.
    @Test func caseAna_onePaymentCoversTheSaleOnItsDay() throws {
        let sale = UUID(), pay = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(11, 1), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(pay, on: Self.day(11, 8), amount: 120, from: ana, to: me)])[sale])
        #expect(venta.collected == [.init(eventID: pay, date: Self.day(11, 8), amount: 120)])
    }

    /// Un pago que cubre el final de un gasto adelantado y el principio de una venta: solo la parte de la venta es ingreso.
    @Test func onePaymentAcrossTwoLots_onlyTheSalePartIsCollected() throws {
        let sale = UUID(), pay = UUID()
        let venta = try #require(coverage(
            [expense(on: Self.day(10, 1), amount: 60, paidBy: me, shares: [me: 30, ana: 30]),
             expense(sale, on: Self.day(10, 5), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(pay, on: Self.day(10, 9), amount: 100, from: ana, to: me)])[sale])
        #expect(venta.collected == [.init(eventID: pay, date: Self.day(10, 9), amount: 70)])
        #expect(venta.remaining == 50)
    }

    /// Dos ventas: el pago cubre primero la más antigua.
    @Test func twoSales_theOlderOneIsCollectedFirst() throws {
        let older = UUID(), newer = UUID(), pay = UUID()
        let result = coverage(
            [expense(newer, on: Self.day(10, 9), amount: 80, paidBy: me, shares: [ana: 80], isSale: true),
             expense(older, on: Self.day(10, 2), amount: 50, paidBy: me, shares: [ana: 50], isSale: true)],
            [payment(pay, on: Self.day(10, 20), amount: 70, from: ana, to: me)])
        #expect(try #require(result[older]).collected.map(\.amount) == [50])
        #expect(try #require(result[newer]).collected.map(\.amount) == [20])
        #expect(try #require(result[newer]).remaining == 60)
    }

    /// Una venta en la que también tienes parte (fuera de alcance como producto, pero la cuenta no se rompe): te deben el
    /// total menos tu parte.
    @Test func aSaleWithYourOwnShare_owesTheTotalMinusYourShare() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [me: 20, ana: 100], isSale: true)],
            [])[sale])
        #expect(venta.owed == 100)
    }

    /// Lo que pagas tú en una liquidación sube tu saldo: no cubre ninguna venta.
    @Test func aPaymentYouMake_coversNothing() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(on: Self.day(10, 5), amount: 40, from: me, to: ana)])[sale])
        #expect(venta.collected.isEmpty)
    }

    /// Ni una liquidación sin confirmar, ni un gasto saldado, ni otra divisa, ni un gasto entre otros.
    @Test func unconfirmedSettledOtherCurrencyAndOthersExpenses_doNotMoveYourBalance() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120], isSale: true),
             expense(on: Self.day(10, 3), amount: 100, paidBy: ana, shares: [me: 50, ana: 50], isSettled: true),
             expense(on: Self.day(10, 3), amount: 100, paidBy: ana, shares: [me: 50, ana: 50], currency: "USD"),
             expense(on: Self.day(10, 3), amount: 100, paidBy: ana, shares: [beto: 100])],
            [payment(on: Self.day(10, 4), amount: 120, from: ana, to: me, confirmed: false),
             payment(on: Self.day(10, 4), amount: 120, from: ana, to: me, currency: "USD")])[sale])
        #expect(venta.collected.isEmpty)
        #expect(venta.remaining == 120)
    }

    /// Una venta en dólares se cubre con lo que pasa en dólares.
    @Test func aSaleInAnotherCurrency_isCoveredInItsCurrency() throws {
        let sale = UUID(), pay = UUID()
        let result = coverage(
            [expense(sale, on: Self.day(10, 2), amount: 40, paidBy: me, shares: [ana: 40], currency: "USD", isSale: true)],
            [payment(pay, on: Self.day(10, 4), amount: 40, from: ana, to: me, currency: "USD")], currency: "USD")
        #expect(try #require(result[sale]).collected.map(\.amount) == [40])
    }

    /// Una venta la paga quien vende: un gasto con categoría de ingreso que pagó Ana no es venta tuya, aunque te toque
    /// una parte. Su deuda baja tu saldo como cualquier gasto y no genera nada por cobrar.
    /// Hoy `coverage` no lo distinguiría (lo que baja tu saldo no abre lote), así que el contrato se fija en `events`.
    @Test func aSaleThatAnaPaid_isNotYourSale() throws {
        let hers = UUID()
        let input = [expense(hers, on: Self.day(10, 2), amount: 120, paidBy: ana, shares: [me: 60, ana: 60], isSale: true)]
        let event = try #require(Logic.events(for: me, currencyCode: "PEN", expenses: input, settlements: []).first)
        #expect(!event.isSale)
        #expect(event.amount == -60)
        #expect(coverage(input, [payment(on: Self.day(10, 5), amount: 60, from: me, to: ana)]).isEmpty)
    }

    /// Un gasto que no es venta no tiene entrada en el resultado, y una venta sin nadie que deba tampoco.
    @Test func onlySalesWithSomethingOwed_appearInTheResult() {
        let normal = UUID(), selfSale = UUID()
        let result = coverage(
            [expense(normal, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120]),
             expense(selfSale, on: Self.day(10, 3), amount: 30, paidBy: me, shares: [me: 30], isSale: true)],
            [])
        #expect(result.isEmpty)
    }

    /// Lo cubierto por un movimiento que llega a la venta en dos trozos sale en UNA parte.
    @Test func aSaleSettlingTwoDebts_isOnePortion() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(on: Self.day(10, 1), amount: 40, paidBy: ana, shares: [me: 20, ana: 20]),
             expense(on: Self.day(10, 2), amount: 60, paidBy: ana, shares: [me: 30, ana: 30]),
             expense(sale, on: Self.day(10, 5), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [])[sale])
        #expect(venta.collected == [.init(eventID: sale, date: Self.day(10, 5), amount: 50)])
        #expect(venta.remaining == 70)
    }

    /// El mismo gasto o la misma liquidación dos veces (duplicado de sync) cuentan una vez.
    @Test func duplicatedRows_countOnce() throws {
        let sale = UUID(), pay = UUID()
        let saleRow = expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)
        let payRow = payment(pay, on: Self.day(10, 4), amount: 50, from: ana, to: me)
        let venta = try #require(coverage([saleRow, saleRow], [payRow, payRow])[sale])
        #expect(venta.owed == 120)
        #expect(venta.collected.map(\.amount) == [50])
    }

    /// Dos aparatos con los movimientos en otro orden dan el mismo reparto, también con la misma fecha.
    @Test func theOrderOfTheInputDoesNotMatter() {
        let date = Self.day(10, 2)
        let saleA = UUID(), saleB = UUID()
        let expenses = [
            expense(saleA, on: date, amount: 50, paidBy: me, shares: [ana: 50], isSale: true),
            expense(saleB, on: date, amount: 50, paidBy: me, shares: [ana: 50], isSale: true),
        ]
        let settlements = [payment(on: Self.day(10, 3), amount: 70, from: ana, to: me)]
        #expect(coverage(expenses, settlements) == coverage(expenses.reversed(), settlements))
    }

    /// Ana paga 119,99 de una venta de 120: el grupo ya no ofrece ese céntimo (`GroupBalanceService` no pide deudas de
    /// 0,01), así que va con el pago y la venta queda cobrada entera, sin un «por cobrar» de 0,01 para siempre.
    @Test func aCentTheGroupConsidersSettled_goesWithTheLastPayment() throws {
        let sale = UUID(), pay = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(pay, on: Self.day(10, 9), amount: 119.99, from: ana, to: me)])[sale])
        #expect(venta.collected == [.init(eventID: pay, date: Self.day(10, 9), amount: 120)])
        #expect(venta.remaining == 0)
    }

    /// Sin nada cobrado, un céntimo sigue siendo lo que te deben: no hay pago al que sumarlo.
    @Test func aCentWithNothingCollected_staysToCollect() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 0.01, paidBy: me, shares: [ana: 0.01], isSale: true)], [])[sale])
        #expect(venta.collected.isEmpty)
        #expect(venta.remaining == Self.dec("0.01"))
    }

    /// Dos céntimos no son un resto que el grupo dé por saldado: siguen por cobrar.
    @Test func twoCents_stayToCollect() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 120, paidBy: me, shares: [ana: 120], isSale: true)],
            [payment(on: Self.day(10, 9), amount: 119.98, from: ana, to: me)])[sale])
        #expect(venta.remaining == Self.dec("0.02"))
    }

    /// Los importes con cola binaria se redondean al céntimo: tres partes de 33.33 no dejan restos raros.
    @Test func binaryTails_areRoundedToTheCent() throws {
        let sale = UUID()
        let venta = try #require(coverage(
            [expense(sale, on: Self.day(10, 2), amount: 0.1 + 0.2, paidBy: me, shares: [ana: 0.3], isSale: true)],
            [payment(on: Self.day(10, 3), amount: 0.3, from: ana, to: me)])[sale])
        #expect(venta.owed == Self.dec("0.3"))
        #expect(venta.remaining == 0)
    }
    // MARK: - Entre divisas (decisión A: el tipo de cambio del día del pago, fijo)

    /// Soles por dólar según el día: el 8 de octubre 3,00 y el 20 de octubre 4,00. Un pago del 8 que se convirtiera con
    /// otro tipo daría otra cifra cobrada.
    private static func penPerUSD(on date: Date) -> Decimal {
        date < day(10, 15) ? 3 : 4
    }

    private static let convert: Logic.Convert = { amount, from, to, date in
        let rate = penPerUSD(on: date)
        if from == to { return amount }
        return from == "USD" ? amount * rate : amount / rate
    }

    private func crossCoverage(
        _ expenses: [Logic.ExpenseInput], _ settlements: [Logic.SettlementInput], convert: Logic.Convert? = convert
    ) -> [UUID: Logic.Coverage] {
        Logic.coverage(
            of: Logic.events(for: me, currencyCode: nil, expenses: expenses, settlements: settlements),
            convert: convert)
    }

    /// El caso del encargo: venta en USD, Ana paga en PEN lo sugerido con el tipo del día del pago ⇒ cobrada entera ese
    /// día, en dólares.
    @Test func aUSDSale_paidInPENWithTheSuggestedAmount_isCollectedWholeOnThePaymentDay() throws {
        let sale = UUID(), pay = UUID()
        let venta = try #require(crossCoverage(
            [expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true)],
            [payment(pay, on: Self.day(10, 8), amount: 300, from: ana, to: me, currency: "PEN")])[sale])
        #expect(venta.collected == [Logic.Portion(eventID: pay, date: Self.day(10, 8), amount: 100)])
        #expect(venta.remaining == 0)
    }

    /// Sin «deudas en una sola moneda» (sin conversión) cada divisa va por su lado: el pago en soles no cubre la venta.
    @Test func withoutConversion_aPaymentInAnotherCurrency_coversNothing() throws {
        let sale = UUID()
        let venta = try #require(crossCoverage(
            [expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true)],
            [payment(on: Self.day(10, 8), amount: 300, from: ana, to: me, currency: "PEN")], convert: nil)[sale])
        #expect(venta.collected.isEmpty)
        #expect(venta.remaining == 100)
    }

    /// El tipo es el del día del PAGO y no cambia con el tiempo: un pago del 8 se convierte a 3,00 aunque el repaso corra
    /// cuando el dólar ya vale 4,00. El del 20 se convierte a 4,00.
    @Test func eachPayment_usesItsOwnDayRate() throws {
        let sale = UUID(), early = UUID(), late = UUID()
        let venta = try #require(crossCoverage(
            [expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true)],
            [payment(early, on: Self.day(10, 8), amount: 150, from: ana, to: me, currency: "PEN"),
             payment(late, on: Self.day(10, 20), amount: 200, from: ana, to: me, currency: "PEN")])[sale])
        #expect(venta.collected.map(\.amount) == [50, 50])
        #expect(venta.collected.map(\.eventID) == [early, late])
        #expect(venta.remaining == 0)
    }

    /// Un pago a medias en la otra divisa deja el resto por cobrar, en la divisa de la venta.
    @Test func aPartialPaymentInAnotherCurrency_leavesTheRestToCollect() throws {
        let sale = UUID()
        let venta = try #require(crossCoverage(
            [expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true)],
            [payment(on: Self.day(10, 8), amount: 90, from: ana, to: me, currency: "PEN")])[sale])
        #expect(venta.collected.map(\.amount) == [30])
        #expect(venta.remaining == 70)
    }

    /// Una deuda cruzada en otra divisa: debías S/ 150 de un almuerzo que pagó Ana; la venta en dólares la salda primero,
    /// con el tipo del día de la venta, y esa parte queda cobrada ese día.
    @Test func aDebtInAnotherCurrency_isSettledByTheSaleFirst() throws {
        let sale = UUID()
        let venta = try #require(crossCoverage(
            [expense(on: Self.day(10, 1), amount: 300, paidBy: ana, shares: [me: 150, ana: 150]),
             expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true)],
            [])[sale])
        #expect(venta.collected == [Logic.Portion(eventID: sale, date: Self.day(10, 2), amount: 50)])
        #expect(venta.remaining == 50)
    }

    /// Un sobrante del pago en la otra divisa sigue cubriendo lo siguiente, en su orden.
    @Test func whatIsLeftOfACrossPayment_coversTheNextSale() throws {
        let usd = UUID(), pen = UUID(), pay = UUID()
        let result = crossCoverage(
            [expense(usd, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "USD", isSale: true),
             expense(pen, on: Self.day(10, 3), amount: 60, paidBy: me, shares: [ana: 60], isSale: true)],
            [payment(pay, on: Self.day(10, 8), amount: 330, from: ana, to: me, currency: "PEN")])
        #expect(try #require(result[usd]).remaining == 0)
        #expect(try #require(result[pen]).collected.map(\.amount) == [30])
        #expect(try #require(result[pen]).remaining == 30)
    }
    /// Un tipo fijo de soles por dólar, para los casos de redondeo.
    private static func fixedRate(_ penPerUSD: String) -> Logic.Convert {
        let rate = dec(penPerUSD)
        return { amount, from, to, _ in
            if from == to { return amount }
            return from == "USD" ? amount * rate : amount / rate
        }
    }

    /// Hallazgo de la review: con el grupo en dólares y la venta en soles, lo «Sugerido» va redondeado al centavo de
    /// dólar, que vale casi 4 céntimos de sol. 26,93 USD a 3,71266 son 99,98 PEN: la venta de 100 tiene que quedar
    /// cobrada entera, no con 0,02 por cobrar para siempre.
    @Test func theSuggestedInTheStrongerCurrency_collectsTheWholeSale() throws {
        let sale = UUID()
        let venta = try #require(crossCoverage(
            [expense(sale, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "PEN", isSale: true)],
            [payment(on: Self.day(10, 8), amount: 26.93, from: ana, to: me, currency: "USD")],
            convert: Self.fixedRate("3.71266"))[sale])
        #expect(venta.remaining == 0)
        #expect(venta.collected.map(\.amount) == [100])
    }

    /// Hallazgo de la review: el resto de céntimo de una venta cubierta entre divisas no puede cortar el recorrido. La
    /// venta B en dólares, pagada entera en dólares, queda cobrada aunque delante quede un lote diminuto en soles.
    @Test func aCentLeftInAnotherCurrency_doesNotStopTheNextPayment() throws {
        let saleA = UUID(), saleB = UUID()
        let result = crossCoverage(
            [expense(saleA, on: Self.day(10, 2), amount: 100, paidBy: me, shares: [ana: 100], currency: "PEN", isSale: true),
             expense(saleB, on: Self.day(10, 10), amount: 50, paidBy: me, shares: [ana: 50], currency: "USD", isSale: true)],
            [payment(on: Self.day(10, 8), amount: 26.94, from: ana, to: me, currency: "USD"),
             payment(on: Self.day(10, 12), amount: 50, from: ana, to: me, currency: "USD")],
            convert: Self.fixedRate("3.7116"))
        #expect(try #require(result[saleA]).remaining == 0)
        #expect(try #require(result[saleB]).remaining == 0)
        #expect(try #require(result[saleB]).collected.map(\.amount) == [50])
    }
}
