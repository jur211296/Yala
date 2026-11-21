//
//  SaludFinancieraCompromisosParidadTests.swift
//  YalaTests
//
//  Compromisos de la hoja y de la nota dicen lo mismo (pregunta 3 de Jürgen, 20-nov-2026): la cobertura parte de «Tu
//  dinero hoy» (sin tarjetas de crédito), y lo que falta pagar es el de la nota y el de «Lo que te falta pagar» de
//  Estadísticas en el caso normal. El caso de la captura: una tarjeta con deuda alta ya no hunde la cobertura.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Salud financiera · Compromisos · paridad con el Panel, la nota y Estadísticas")
struct SaludFinancieraCompromisosParidadTests {

    private let calendar = Calendar.current
    /// «Hoy» fijo: el 20 de noviembre de 2026 a mediodía.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)) ?? Date() }
    private func dia(_ d: Int, mes: Int = 11, hora: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: mes, day: d, hour: hora)) ?? now
    }

    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

    private func cuenta(_ nombre: String, tipo: AccountType = .checking) -> Account {
        Account(name: nombre, currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: tipo.rawValue)
    }

    private func movimiento(_ importe: Double, en cuenta: Account, dia d: Int = 10) -> TransactionItem {
        TransactionItem(date: dia(d), amount: importe, currencyCode: "PEN", note: "", category: comida, account: cuenta,
                        amountInPreferredCurrency: importe, preferredCurrencyCode: "PEN")
    }

    private func pago(_ nombre: String, _ importe: Double, dia d: Int, mes: Int = 11, hora: Int = 12,
                      tipo: TransactionType = .expense) -> ScheduledPayment {
        let p = ScheduledPayment(name: nombre, amount: importe, currencyCode: "PEN", transactionType: tipo.rawValue,
                                 isRecurring: false, nextDueDate: dia(d, mes: mes, hora: hora))
        p.createdAt = dia(1, mes: 1)
        return p
    }

    private var mes: DateInterval {
        FinancialScoreCalculator.commitmentsInterval(
            period: .thisMonth, fallback: DetailPeriod.thisMonth.dateInterval(customRange: nil, now: now), now: now,
            calendar: calendar
        )
    }

    private let scope = FinancialScoreCalculator.CoverageScope(includeGroupsInTotal: true, moneyOverrides: [:])

    // MARK: - Tu dinero hoy

    @Test("«Tu dinero hoy» deja fuera la tarjeta de crédito, y un ajuste por cuenta la vuelve a meter")
    func dineroHoy_sinTarjetas_yConElAjusteDeLaPersona() {
        let banco = cuenta("Banco")
        let visa = cuenta("Visa", tipo: .creditCard)
        let cuentas = [banco, visa]
        #expect(FinancialScoreCalculator.coverageAccounts(cuentas, scope: scope).map(\.name) == ["Banco"])
        let conVisa = FinancialScoreCalculator.CoverageScope(includeGroupsInTotal: true,
                                                             moneyOverrides: [visa.shortcutID: true])
        #expect(Set(FinancialScoreCalculator.coverageAccounts(cuentas, scope: conVisa).map(\.name)) == ["Banco", "Visa"])
    }

    @Test("La cifra de la hoja es la del hero del Panel con los mismos datos")
    func dineroHoy_esLaDelHeroDelPanel() {
        let banco = cuenta("Banco")
        let visa = cuenta("Visa", tipo: .creditCard)
        let txs = [movimiento(7850, en: banco), movimiento(-40_000, en: visa)]
        let ids = FinancialScoreCalculator.totalAccountIDs([banco, visa], scope: scope)
        let hoja = PanelMoneyScopeLogic.moneyBreakdown(accounts: [banco, visa], totalAccountIDs: ids, overrides: [:],
                                                       transactions: txs, preferredCurrencyCode: "PEN", asOf: now)
        // El hero suma las cuentas del saldo grande (`panelTotalAccountIDs`): sin filtro, las que suman en un saldo.
        let panelIDs = LiveBalanceCalculator.liveBalanceBreakdown(accounts: [banco, visa], transactions: txs,
                                                                  preferredCurrencyCode: "PEN").eligibleAccountIDs
        let hero = PanelMoneyScopeLogic.moneyBreakdown(accounts: [banco, visa], totalAccountIDs: panelIDs,
                                                       overrides: [:], transactions: txs,
                                                       preferredCurrencyCode: "PEN", asOf: now)
        #expect(hoja.convertedTotal == hero.convertedTotal)
        #expect(hoja.convertedTotal == 7850)
    }

    // MARK: - La nota

    private func notaDeCompromisos(_ cuentas: [Account], _ txs: [TransactionItem], _ pagos: [ScheduledPayment]) -> Int? {
        FinancialScoreCalculator.calculate(
            transactions: txs, budgets: [], scheduledPayments: pagos, accounts: cuentas, paidAmounts: [:],
            period: .thisMonth, preferredCurrencyCode: "PEN", now: now, calendar: calendar,
            coverageAccounts: FinancialScoreCalculator.coverageAccounts(cuentas, scope: scope)
        ).bills
    }

    @Test("El caso de la captura: una tarjeta con deuda alta ya no hunde la cobertura de la nota")
    func nota_tarjetaEndeudada_noRestaDeLaCobertura() throws {
        let banco = cuenta("Banco")
        let visa = cuenta("Visa", tipo: .creditCard)
        let txs = [movimiento(7850, en: banco), movimiento(-40_000, en: visa)]
        let pagos = [pago("Alquiler", 2230, dia: 28)]

        let conTarjeta = try #require(notaDeCompromisos([banco, visa], txs, pagos))
        let sinTarjeta = try #require(notaDeCompromisos([banco], [txs[0]], pagos))
        #expect(conTarjeta == sinTarjeta, "La deuda de la tarjeta movió la nota (con el bug: \(conTarjeta)).")
        #expect(conTarjeta >= 70, "Con 7.850 para 2.230 la cobertura es buena.")

        let todas = FinancialScoreCalculator.calculate(
            transactions: txs, budgets: [], scheduledPayments: pagos, accounts: [banco, visa], paidAmounts: [:],
            period: .thisMonth, preferredCurrencyCode: "PEN", now: now, calendar: calendar,
            coverageAccounts: [banco, visa]
        ).bills
        #expect((todas ?? 0) < conTarjeta, "Control: con todas las cuentas la tarjeta sí hunde la cobertura.")
    }

    // MARK: - Te falta pagar este mes

    @Test("Lo pendiente: solo gastos del mes, sin saltados, sin pagados, y diciembre fuera")
    func pendientes_soloLoQueFaltaEsteMes() {
        let alquiler = pago("Alquiler", 2230, dia: 28)
        let saltado = pago("Gimnasio", 180, dia: 25)
        saltado.skipDate(dia(25))
        let pagado = pago("Luz", 142.6, dia: 22)
        // A medianoche del 1 de diciembre: con un fin de mes abierto entraría en noviembre.
        let diciembre = pago("Workspace", 60, dia: 1, mes: 12, hora: 0)
        let sueldo = pago("Sueldo", 4500, dia: 28, tipo: .income)
        let activos = [alquiler, saltado, pagado, diciembre].filter { $0.transactionType != TransactionType.income.rawValue }
        let pagados = [pagado.id.uuidString: [PaidOccurrenceInfo(amount: 142.6, currencyCode: "PEN", date: dia(19))]]

        let pendientes = FinancialScoreCalculator.pendingOccurrences(active: activos, paidAmounts: pagados,
                                                                    interval: mes, calendar: calendar)
        #expect(pendientes.map(\.payment.name) == ["Alquiler"])
        #expect(!pendientes.contains { $0.payment === sueldo })
    }

    @Test("Lo que falta pagar es lo de «Lo que te falta pagar» de Estadísticas › Resumen en «Este mes»")
    func pendientes_paridadConEstadisticas() {
        let banco = cuenta("Banco")
        let pagos = [pago("Alquiler", 2230, dia: 28), pago("Luz", 142.6, dia: 24), pago("Spotify", 26.9, dia: 29)]
        let hoja = FinancialScoreCalculator.pendingOccurrences(active: pagos, paidAmounts: [:], interval: mes,
                                                              calendar: calendar)
            .reduce(0) { $0 + abs($1.payment.amount) }
        let estadisticas = InsightsCalculator.calculate(
            transactions: [movimiento(5000, en: banco)], accounts: [banco], categories: [comida], budgets: [],
            scheduledPayments: pagos, period: .thisMonth, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: nil, now: now
        ).commitments.pendingPaymentsAmount
        #expect(abs(hoja - estadisticas) < 0.001, "Hoja \(hoja) · Estadísticas \(estadisticas)")
    }
}
