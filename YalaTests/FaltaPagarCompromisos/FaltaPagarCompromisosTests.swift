//
//  FaltaPagarCompromisosTests.swift
//  YalaTests
//
//  Tres tickets del 20-nov-2026 sobre «lo que te falta pagar» y Compromisos:
//  - `lo-que-te-falta-pagar-cuenta-ingresos-y-saltados`: Estadísticas › Resumen cuenta con la misma pieza que la nota y
//    la hoja (`FinancialScoreCalculator.pendingOccurrences`): sin ingresos planificados, sin ocurrencias saltadas ni
//    pagadas, y cada ocurrencia de un pago semanal.
//  - `hoja-y-nota-difieren-con-pagos-apuntados-a-futuro`: la comparación de la hoja cuenta lo apuntado con fecha
//    posterior a hoy, como la cobertura de la nota, sin cambiar «Tu dinero hoy».
//  - `nota-no-recalcula-al-cambiar-tu-dinero-hoy`: el Panel recalcula al cambiar el ajuste por cuenta de «Tu dinero hoy».
//
//  Sin `ModelContext`: los `@Model` sueltos bastan (molde de `SaludFinancieraCompromisosParidadTests`).
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Lo que te falta pagar y Compromisos · una cuenta para Estadísticas, la hoja y la nota")
struct FaltaPagarCompromisosTests {

    /// El calendario con el que corta Estadísticas (`userConfiguredCalendar`), también para la nota y la hoja.
    private let calendar = userConfiguredCalendar()
    /// «Hoy» fijo: el 20 de noviembre de 2026 a mediodía.
    private var now: Date { dia(20) }
    private func dia(_ d: Int, mes: Int = 11, hora: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: mes, day: d, hour: hora)) ?? Date()
    }

    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

    private func cuenta(_ nombre: String) -> Account {
        Account(name: nombre, currencyCode: "PEN", colorHex: "#000000", iconName: "banknote",
                type: AccountType.checking.rawValue)
    }

    private func movimiento(_ importe: Double, en cuenta: Account, dia d: Int = 10) -> TransactionItem {
        TransactionItem(date: dia(d), amount: importe, currencyCode: "PEN", note: "", category: comida, account: cuenta,
                        amountInPreferredCurrency: importe, preferredCurrencyCode: "PEN")
    }

    private func pago(_ nombre: String, _ importe: Double, dia d: Int, tipo: TransactionType = .expense,
                      recurrencia: String? = nil,
                      categoria: PaymentCategory = .recurring) -> ScheduledPayment {
        // Semanal: los lunes (`selectedWeekdays` es obligatorio en `weeklyDates`; 2 = lunes en `Calendar`).
        let p = ScheduledPayment(name: nombre, amount: importe, currencyCode: "PEN", transactionType: tipo.rawValue,
                                 isRecurring: recurrencia != nil, recurrenceType: recurrencia ?? "monthly",
                                 nextDueDate: dia(d), selectedWeekdays: recurrencia == "weekly" ? "2" : nil,
                                 paymentCategory: categoria.rawValue)
        p.createdAt = dia(1, mes: 1)
        return p
    }

    private var mes: DateInterval {
        FinancialScoreCalculator.commitmentsInterval(
            period: .thisMonth,
            fallback: DetailPeriod.thisMonth.dateInterval(customRange: nil, now: now, calendar: calendar),
            now: now, calendar: calendar
        )
    }

    private func estadisticas(_ pagos: [ScheduledPayment], pagados: [String: [PaidOccurrenceInfo]] = [:]) -> Commitments {
        let banco = cuenta("Banco")
        return InsightsCalculator.calculate(
            transactions: [movimiento(5000, en: banco)], accounts: [banco], categories: [comida], budgets: [],
            scheduledPayments: pagos, period: .thisMonth, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: nil, paidAmounts: pagados, now: now
        ).commitments
    }

    /// Lo que cuentan la nota y la hoja: solo gastos activos, con `pendingOccurrences`.
    private func notaYHoja(_ pagos: [ScheduledPayment], pagados: [String: [PaidOccurrenceInfo]] = [:]) -> Double {
        let gastos = pagos.filter { $0.isActive && $0.transactionType != TransactionType.income.rawValue }
        return FinancialScoreCalculator.pendingOccurrences(active: gastos, paidAmounts: pagados, interval: mes,
                                                           calendar: calendar)
            .reduce(0) { $0 + abs($1.payment.amount) }
    }

    // MARK: - Estadísticas › «Lo que te falta pagar»

    @Test("Un sueldo planificado no sale como «te falta pagar»")
    func estadisticas_ingresoPlanificado_noCuenta() {
        let pagos = [pago("Alquiler", 2230, dia: 28), pago("Sueldo", 4500, dia: 28, tipo: .income)]
        let c = estadisticas(pagos)
        #expect(c.pendingPaymentsAmount == 2230, "Con el bug: 6730 (el sueldo sumaba).")
        #expect(c.pendingPaymentsCount == 1)
        #expect(c.pendingPaymentsAmount == notaYHoja(pagos))
    }

    @Test("Una ocurrencia saltada no cuenta")
    func estadisticas_ocurrenciaSaltada_noCuenta() {
        let gimnasio = pago("Gimnasio", 180, dia: 25)
        gimnasio.skipDate(dia(25))
        let pagos = [pago("Alquiler", 2230, dia: 28), gimnasio]
        let c = estadisticas(pagos)
        #expect(c.pendingPaymentsAmount == 2230, "Con el bug: 2410 (el saltado sumaba).")
        #expect(c.pendingPaymentsAmount == notaYHoja(pagos))
    }

    @Test("Un pago semanal cuenta cada semana del mes, no una vez")
    func estadisticas_pagoSemanal_cuentaCadaOcurrencia() {
        let pagos = [pago("Clases", 50, dia: 2, recurrencia: "weekly")]
        let ocurrencias = FinancialScoreCalculator.pendingOccurrences(active: pagos, paidAmounts: [:], interval: mes,
                                                                     calendar: calendar).count
        #expect(ocurrencias >= 4, "Control: noviembre tiene al menos 4 semanas (\(ocurrencias)).")
        let c = estadisticas(pagos)
        #expect(c.pendingPaymentsCount == ocurrencias, "Con el bug: 1.")
        #expect(c.pendingPaymentsAmount == Double(ocurrencias) * 50)
        #expect(c.pendingPaymentsAmount == notaYHoja(pagos))
    }

    @Test("Lo ya pagado con un movimiento enlazado sale de lo pendiente, como en la nota")
    func estadisticas_pagado_noCuenta() {
        let luz = pago("Luz", 142.6, dia: 22)
        let pagos = [pago("Alquiler", 2230, dia: 28), luz]
        let pagados = [luz.id.uuidString: [PaidOccurrenceInfo(amount: 142.6, currencyCode: "PEN", date: dia(19))]]
        let c = estadisticas(pagos, pagados: pagados)
        #expect(c.pendingPaymentsAmount == 2230)
        #expect(c.pendingPaymentsAmount == notaYHoja(pagos, pagados: pagados))
    }

    @Test("Suscripciones y el resto siguen sumando el total, por ocurrencia")
    func estadisticas_reparto_sumaElTotal() {
        let pagos = [pago("Clases", 50, dia: 2, recurrencia: "weekly"),
                     pago("Spotify", 26.9, dia: 29, categoria: .subscription),
                     pago("Sueldo", 4500, dia: 28, tipo: .income)]
        let c = estadisticas(pagos)
        #expect(c.pendingSubscriptionsCount == 1)
        #expect(abs(c.pendingSubscriptionsAmount - 26.9) < 0.001)
        #expect(c.pendingSubscriptionsCount + c.pendingOtherPaymentsCount == c.pendingPaymentsCount)
        #expect(abs(c.pendingSubscriptionsAmount + c.pendingOtherPaymentsAmount - c.pendingPaymentsAmount) < 0.001)
    }

    @Test("Un pago de una vez del día 1 cuenta una sola vez en un período que cruza dos meses")
    func pagoDeUnaVezDelDia1_noSeDuplica() throws {
        // Semana del lunes 30 de noviembre al domingo 6 de diciembre: el pago del 1 de diciembre sale en noviembre y en
        // diciembre si el mes se mira cerrado.
        let semana = DateInterval(start: dia(30), end: dia(6, mes: 12, hora: 23).addingTimeInterval(59 * 60 + 59))
        let primero = pago("Seguro", 300, dia: 1)
        primero.nextDueDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let ocurrencias = FinancialScoreCalculator.pendingOccurrences(active: [primero], paidAmounts: [:],
                                                                     interval: semana, calendar: calendar)
        #expect(ocurrencias.count == 1, "Con el bug: 2.")
        let noviembre = ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: primero.dateCalculatorParams, month: dia(15), calendar: calendar)
        #expect(noviembre.isEmpty, "El pago del 1 de diciembre no es de noviembre: \(noviembre)")
    }

    // MARK: - La hoja y la nota con un pago apuntado a fecha futura

    private let scope = FinancialScoreCalculator.CoverageScope(includeGroupsInTotal: true, moneyOverrides: [:])

    private func dinero(_ cuentas: [Account], _ txs: [TransactionItem], asOf: Date) -> Double {
        let ids = FinancialScoreCalculator.totalAccountIDs(cuentas, scope: scope)
        let total = PanelMoneyScopeLogic.moneyBreakdown(accounts: cuentas, totalAccountIDs: ids, overrides: [:],
                                                        transactions: txs, preferredCurrencyCode: "PEN", asOf: asOf)
            .convertedTotal
        return NSDecimalNumber(decimal: total).doubleValue
    }

    private func luz() -> SaludFinancieraDetalleLogica.Pago {
        SaludFinancieraDetalleLogica.Pago(id: UUID(), nombre: "Luz", fecha: dia(27), dias: 7, monto: 900, moneda: "PEN",
                                          montoConvertido: 900, esAproximado: false)
    }

    @Test("El alquiler apuntado hoy para el 25: la hoja ya no dice «Te alcanza» con ese importe de más")
    func hoja_apuntadoAFuturo_cuentaComoLaNota() {
        let banco = cuenta("Banco")
        // Hoy hay 3.000; el alquiler (2.230) se apuntó hoy con fecha 25 y salió de lo pendiente. Falta la luz (900).
        let txs = [movimiento(3000, en: banco), movimiento(-2230, en: banco, dia: 25)]
        let hoy = dinero([banco], txs, asOf: now)
        let conFuturo = dinero([banco], txs, asOf: .distantFuture)
        #expect(hoy == 3000, "«Tu dinero hoy» es la cifra del hero: no cuenta lo del 25.")

        let c = SaludFinancieraDetalleLogica.comparacion(pagos: [luz()], dineroHoy: hoy,
                                                         apuntadoFuturo: conFuturo - hoy, moneda: "PEN")
        #expect(c.dineroHoy == 3000, "La barra de «Tu dinero hoy» no cambia.")
        #expect(c.cuentaApuntadoFuturo)
        #expect(!c.alcanza, "Con el bug: «Te alcanza, y te quedarían 2.100».")
        #expect(abs(c.diferencia - -130) < 0.001)

        // La nota mide la cobertura con el mismo dinero: el saldo de esas cuentas con todo lo apuntado.
        let nota = LiveBalanceCalculator.liveBalance(
            accounts: FinancialScoreCalculator.coverageAccounts([banco], scope: scope), transactions: txs,
            preferredCurrencyCode: "PEN", asOf: .distantFuture
        )
        #expect(abs((c.dineroHoy + c.apuntadoFuturo) - nota) < 0.001,
                "Hoja \(c.dineroHoy + c.apuntadoFuturo) · nota \(nota)")
    }

    @Test("Sin nada apuntado a futuro, la comparación es la de siempre y no hay línea")
    func hoja_sinApuntadoAFuturo_sinCambios() {
        let banco = cuenta("Banco")
        let txs = [movimiento(3000, en: banco)]
        let hoy = dinero([banco], txs, asOf: now)
        let c = SaludFinancieraDetalleLogica.comparacion(
            pagos: [luz()], dineroHoy: hoy, apuntadoFuturo: dinero([banco], txs, asOf: .distantFuture) - hoy,
            moneda: "PEN"
        )
        #expect(!c.cuentaApuntadoFuturo)
        #expect(abs(c.diferencia - 2100) < 0.001)
        #expect(c.alcanza)
    }

    @Test("La línea de lo apuntado a futuro existe en los 16 idiomas")
    func hoja_lineaApuntadoAFuturo_traducida() throws {
        let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Yala/Resources")
        let idiomas = try FileManager.default.contentsOfDirectory(atPath: raiz.path)
            .filter { $0.hasSuffix(".lproj") }
            .filter { FileManager.default.fileExists(atPath: raiz.appending(path: "\($0)/SaludFinancieraDetalle.strings").path) }
        #expect(idiomas.count == 16, "\(idiomas)")
        for idioma in idiomas {
            let tabla = try String(contentsOf: raiz.appending(path: "\(idioma)/SaludFinancieraDetalle.strings"),
                                   encoding: .utf8)
            #expect(tabla.contains("\"saludDetalle.commit.futureOut\""), "\(idioma)")
            #expect(tabla.contains("\"saludDetalle.commit.futureIn\""), "\(idioma)")
        }
    }

    // MARK: - La nota recalcula al cambiar «Tu dinero hoy»

    @Test("El Panel recalcula con el ajuste por cuenta de «Tu dinero hoy», no solo con el interruptor de Grupos")
    func panel_recalculaAlCambiarTuDineroHoy() throws {
        let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let panel = try String(contentsOf: raiz.appending(path: "Yala/App/Views/Panel/PanelView.swift"), encoding: .utf8)
        let inicio = try #require(panel.range(of: "struct PanelMoneyScopeObserver: ViewModifier {"))
        let fin = try #require(panel.range(of: "\n}\n", range: inicio.upperBound..<panel.endIndex))
        let observador = String(panel[inicio.upperBound..<fin.lowerBound])
        #expect(observador.contains(".onChange(of: appPreferences.panelMoneyAccountOverrides) { _, _ in recalculate() }"))
        #expect(observador.contains(".onChange(of: appPreferences.includeGroupsInPanelTotal) { _, _ in recalculate() }"))
        #expect(panel.contains(
            ".modifier(PanelMoneyScopeObserver(appPreferences: appPreferences) { viewModel.recalculateData() })"
        ))
        // Y la nota lee esa preferencia al calcular: si no, recalcular no cambiaría nada.
        let vm = try String(contentsOf: raiz.appending(path: "Yala/App/ViewModels/PanelViewModel.swift"),
                            encoding: .utf8)
        #expect(vm.contains("moneyOverrides: PanelMoneyScopeLogic.decode(appPreferences.panelMoneyAccountOverrides)"))
        #expect(vm.contains(
            "coverageAccounts: FinancialScoreCalculator.coverageAccounts(accounts, scope: healthCoverageScope)"
        ))
    }
}
