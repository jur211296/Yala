//
//  AntExpensesCalculatorTests.swift
//  YalaTests
//
//  Gastos hormiga (card 2.3 `tablero-detectar-gastos-hormiga-y-decir-cuanto-s-ea78`): la regla de
//  `AntExpensesCalculator` y su paso por `InsightsCalculator`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Gastos hormiga", .serialized)
struct AntExpensesCalculatorTests {

    private let calendar = Calendar.current
    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: d, hour: 12)) ?? Date()
    }

    private var abril: DateInterval {
        let start = calendar.startOfDay(for: day(1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func tx(_ amount: Double, _ note: String?, day d: Int = 10, category: YalaCategory? = nil) -> TransactionItem {
        TransactionItem(
            date: day(d), amount: amount, currencyCode: "PEN", note: note,
            category: category ?? comida, account: cuenta,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    private func calc(_ txs: [TransactionItem], days: Int = 30) -> AntExpensesSummary? {
        AntExpensesCalculator.calculate(transactions: txs, amountOf: { $0.amount }, dayCount: days)
    }

    /// Un mes típico: 4 cafés de 8, 3 taxis de 12, un alquiler, un súper grande y dos compras sueltas.
    private var mesTipico: [TransactionItem] {
        [tx(-8, "Café"), tx(-8, "café "), tx(-8, "CAFÉ"), tx(-8, "Café"),
         tx(-12, "Taxi"), tx(-12, "Taxi"), tx(-12, "Taxi"),
         tx(-2200, "Alquiler"), tx(-400, "Súper"), tx(-150, "Zapatillas"), tx(-90, "Cena")]
    }

    @Test("Agrupa por descripción sin mayúsculas ni espacios, y suma solo lo que se repite")
    func agrupaYSuma() throws {
        let r = try #require(calc(mesTipico))
        // Taxi (3 × 12 = 36) suma más que Café (4 × 8 = 32): va primero.
        #expect(r.groups.map(\.label) == ["Taxi", "Café"])
        #expect(r.groups[0].count == 3 && r.groups[0].total == 36)
        #expect(r.groups[1].count == 4 && r.groups[1].total == 32)
        #expect(r.total == 68)
        #expect(r.count == 7)
        // Mediana de 11 gastos ordenados: 8,8,8,8,12,12,12,90,150,400,2200 → 12.
        #expect(r.threshold == 12)
        #expect(r.monthlyEstimate == nil)
    }

    @Test("Dos veces no es hormiga; tres sí")
    func umbralDeRepeticiones() {
        var txs = mesTipico
        txs.removeAll { $0.note == "Taxi" }
        txs.append(contentsOf: [tx(-12, "Taxi"), tx(-12, "Taxi")])
        let r = calc(txs)
        #expect(r?.groups.map(\.label) == ["Café"])
    }

    @Test("Por encima de la mediana no cuenta, aunque se repita")
    func porEncimaDeLaMediana() {
        // 2,3,5,8,8,8,200,200,200,500,600 → mediana 8: la gasolina se repite pero no es pequeña.
        let txs = [tx(-2, "Chicle"), tx(-3, "Agua"), tx(-5, "Pan"), tx(-8, "Café"), tx(-8, "Café"), tx(-8, "Café"),
                   tx(-200, "Gasolina"), tx(-200, "Gasolina"), tx(-200, "Gasolina"), tx(-500, "Súper"), tx(-600, "Viaje")]
        let r = calc(txs)
        #expect(r?.groups.map(\.label) == ["Café"])
    }

    @Test("Ingresos, devoluciones, transferencias, ajustes y pagos planificados no entran")
    func exclusiones() {
        // Seis gastos reales y grandes: hay mediana, y todo lo pequeño y repetido es de lo que se excluye.
        var txs: [TransactionItem] = [tx(-200, "Súper"), tx(-300, "Ropa"), tx(-500, "Viaje"),
                                      tx(-250, "Cena"), tx(-350, "Regalo"), tx(-450, "Médico")]
        // Negativo en una categoría de ingreso: la categoría manda, es ingreso.
        txs += [tx(-5, "Propina", category: sueldo), tx(-5, "Propina", category: sueldo), tx(-5, "Propina", category: sueldo)]
        // Devolución: positivo en una categoría de gasto.
        txs += [tx(4, "Reembolso"), tx(4, "Reembolso"), tx(4, "Reembolso")]
        let transfers = [tx(-3, "Ahorro"), tx(-3, "Ahorro"), tx(-3, "Ahorro")]
        transfers.forEach { $0.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer }
        let planned = [tx(-6, "Spotify"), tx(-6, "Spotify"), tx(-6, "Spotify")]
        planned.forEach { $0.scheduledPaymentID = UUID().uuidString }
        txs += transfers + planned
        #expect(calc(txs) == nil)
    }

    @Test("Un gasto sin categoría (negativo) sí es gasto; sin nota cae a la subcategoría")
    func sinCategoriaYSinNota() throws {
        let sub = Subcategory(name: "Snacks", category: comida)
        var txs = [tx(-200, "Súper"), tx(-300, "Ropa"), tx(-500, "Viaje")]
        let snacks = (0..<3).map { _ in tx(-5, nil) }
        snacks.forEach { $0.subcategory = sub }
        let sueltos = (0..<3).map { _ -> TransactionItem in
            let t = tx(-4, "Chicle"); t.category = nil; return t
        }
        txs += snacks + sueltos
        let r = try #require(calc(txs))
        #expect(Set(r.groups.map(\.label)) == ["Snacks", "Chicle"])
    }

    @Test("Sin descripción ni subcategoría no hay nada que nombrar")
    func sinNadaQueNombrar() {
        var txs = [tx(-200, "Súper"), tx(-300, "Ropa"), tx(-500, "Viaje")]
        txs += (0..<4).map { _ in tx(-5, nil) }
        #expect(calc(txs) == nil)
    }

    @Test("Con pocos gastos no hay tarjeta")
    func pocosGastos() {
        #expect(calc([tx(-8, "Café"), tx(-8, "Café"), tx(-8, "Café"), tx(-100, "Cena")]) == nil)
    }

    @Test("Un período largo trae su equivalente mensual")
    func equivalenteMensual() throws {
        let r = try #require(calc(mesTipico, days: 90))
        #expect(r.monthlyEstimate == r.total / 90 * 30)
    }

    @Test("Llega a Insights por el cálculo del período")
    func llegaAInsights() throws {
        let data = InsightsCalculator.calculate(
            transactions: mesTipico, accounts: [cuenta], categories: [comida], budgets: [],
            scheduledPayments: [], period: .custom, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: abril, now: day(30)
        )
        let ants = try #require(data.quickStats.antExpenses)
        #expect(ants.total == 68)
        #expect(ants.monthlyEstimate == nil)
    }
}
