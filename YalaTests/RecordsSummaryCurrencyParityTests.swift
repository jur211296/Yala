//
//  RecordsSummaryCurrencyParityTests.swift
//  YalaTests
//
//  Ticket `records-summary-mixes-preferred-currencies`: el resumen de Registros sumaba el
//  `amountInPreferredCurrency` guardado sin mirar EN QUÉ divisa preferida se guardó. Si el usuario
//  cambió de divisa principal y quedaban filas sin recalcular, el total mezclaba dos escalas.
//
//  Los casos van por el camino real (`applyFilters`) y se comparan con el Panel
//  (`CashFlowCalculator.calculateCashFlow`) y con el calendario (`DailySpendingCalculator`), que
//  son las otras dos superficies que suman los mismos importes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Resumen de Registros · divisas preferidas mezcladas", .serialized)
struct RecordsSummaryCurrencyParityTests {

    /// 1 USD = 3,7 PEN en el doble: la tasa que reconvierte las filas guardadas en USD.
    private let tasaUSD: Decimal = 3.7

    /// Estado global del que depende `applyFilters`, fijado y restaurado.
    private func conEstadoDeRegistros(_ cuerpo: () throws -> Void) rethrows {
        let periodoAnterior = SessionState.shared.selectedPeriod
        let clave = AppPreferences.Keys.includeGroupTransactionsInFeed
        let incluirAnterior = UserDefaults.standard.object(forKey: clave)
        SessionState.shared.selectedPeriod = .allTime
        UserDefaults.standard.set(true, forKey: clave)
        defer {
            SessionState.shared.selectedPeriod = periodoAnterior
            if let incluirAnterior {
                UserDefaults.standard.set(incluirAnterior, forKey: clave)
            } else {
                UserDefaults.standard.removeObject(forKey: clave)
            }
        }
        try cuerpo()
    }

    /// Una fila con su monto nativo y el monto que se guardó cuando la principal era `guardadaEn`.
    private func makeTx(
        nativo: Double, divisa: String, guardado: Double, guardadaEn: String,
        account: Account, category: YalaCategory, provisional: Bool = false,
        context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(), amount: nativo, currencyCode: divisa, note: "",
            category: category, account: account, tags: [],
            amountInPreferredCurrency: guardado, preferredCurrencyCode: guardadaEn,
            isExchangeRateProvisional: provisional
        )
        context.insert(tx)
        return tx
    }

    private func registros(
        _ txs: [TransactionItem], _ accounts: [Account], _ context: ModelContext,
        principal: String, converter: CurrencyConverting
    ) -> RecordsViewModel {
        let vm = RecordsViewModel()
        vm.applyFilters(
            transactions: txs, accounts: accounts, categories: [], tags: [], context: context,
            currencyCode: principal, converter: converter
        )
        return vm
    }

    /// Escenario del bug: principal PEN, dos filas ya en PEN y dos guardadas cuando la principal
    /// era USD y sin recalcular.
    private struct Mezcla {
        let txs: [TransactionItem]
        let cuentas: [Account]
    }

    private func mezcla(_ context: ModelContext) throws -> Mezcla {
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let dolares = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let txs = [
            makeTx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN",
                   account: soles, category: comida, context: context),
            makeTx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN",
                   account: soles, category: sueldo, context: context),
            makeTx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
                   account: dolares, category: comida, context: context),
            makeTx(nativo: 200, divisa: "USD", guardado: 200, guardadaEn: "USD",
                   account: dolares, category: sueldo, context: context),
        ]
        try context.save()
        return Mezcla(txs: txs, cuentas: [soles, dolares])
    }

    @Test("Con filas guardadas en otra divisa, el total suma sus importes convertidos")
    func mixedPreferredCurrencies_convertsBeforeSumming() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let m = try mezcla(context)
            let converter = MockCurrencyConverter(fixedRate: tasaUSD)

            let s = registros(m.txs, m.cuentas, context, principal: "PEN", converter: converter)
                .recordsSummary

            // 100 + 50 × 3,7 = 285; 1.000 + 200 × 3,7 = 1.740. Con el código viejo: 150 y 1.200,
            // dos escalas sumadas con el símbolo de soles.
            #expect(abs(s.expense - 285) < 0.001, "gasto: \(s.expense)")
            #expect(abs(s.income - 1_740) < 0.001, "ingreso: \(s.income)")
            #expect(abs(s.balance - 1_455) < 0.001, "saldo: \(s.balance)")
        }
    }

    /// La otra dirección: si todo se guardó en la principal, el converter no interviene. Con una
    /// tasa absurda, cualquier reconversión de más se ve en el total.
    @Test("Con todo guardado en la principal, el total es el de siempre")
    func singlePreferredCurrency_readsStoredAmounts() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let cuenta = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
            let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
            // Nativo en USD, guardado ya convertido a PEN.
            let txs = [
                makeTx(nativo: -10, divisa: "USD", guardado: -37, guardadaEn: "PEN",
                       account: cuenta, category: comida, context: context),
                makeTx(nativo: 100, divisa: "USD", guardado: 370, guardadaEn: "PEN",
                       account: cuenta, category: sueldo, context: context),
            ]
            try context.save()

            let s = registros(txs, [cuenta], context, principal: "PEN",
                              converter: MockCurrencyConverter(fixedRate: 999)).recordsSummary

            #expect(s.expense == 37)
            #expect(s.income == 370)
            #expect(s.balance == 333)
            #expect(!s.expenseIsApproximate && !s.incomeIsApproximate && !s.balanceIsApproximate)
        }
    }

    /// La marca «≈» sale de las dos vías: una fila reconvertida con una tasa que no es la del día
    /// marca su lado aunque su flag diga exacta.
    @Test("Una fila reconvertida con tasa aproximada marca su lado y no el otro")
    func reconvertedWithApproximateRate_marksItsSide() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
            let dolares = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
            let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
            let txs = [
                makeTx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
                       account: dolares, category: comida, provisional: false, context: context),
                makeTx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN",
                       account: soles, category: sueldo, context: context),
            ]
            try context.save()
            let converter = MockCurrencyConverter(fixedRate: tasaUSD, quality: .staticFallback)

            let s = registros(txs, [soles, dolares], context, principal: "PEN", converter: converter)
                .recordsSummary

            #expect(s.expenseIsApproximate, "el único gasto salió de la tabla estática")
            #expect(!s.incomeIsApproximate, "el ingreso se leyó guardado y exacto")
        }
    }

    @Test("Paridad con el Panel: mismos totales y misma marca para las mismas filas")
    func parityWithPanelCashFlow() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let m = try mezcla(context)
            let converter = MockCurrencyConverter(fixedRate: tasaUSD, quality: .staticFallback)

            let vm = registros(m.txs, m.cuentas, context, principal: "PEN", converter: converter)
            let s = vm.recordsSummary
            let hoy = Calendar.current.startOfDay(for: Date())
            let panel = CashFlowCalculator.calculateCashFlow(
                transactions: m.txs,
                interval: DateInterval(start: hoy, duration: 86_400),
                grouping: .day,
                currencyCode: "PEN",
                adjustment: vm.statsAdjustment,
                converter: converter
            )

            #expect(abs(s.income - panel.totalIncome) < 0.001)
            #expect(abs(s.expense - panel.totalExpense) < 0.001)
            #expect(abs(s.balance - panel.netFlow) < 0.001)
            #expect(s.incomeIsApproximate == panel.incomeAmountsAreApproximate)
            #expect(s.expenseIsApproximate == panel.expenseAmountsAreApproximate)
            #expect(s.balanceIsApproximate == panel.amountsAreApproximate)
        }
    }

    /// El calendario es la misma pantalla: la suma de sus barras tiene que dar el gasto del resumen.
    @Test("Paridad con el calendario de Registros: las barras suman el gasto del resumen")
    func parityWithRecordsCalendar() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let m = try mezcla(context)
            let converter = MockCurrencyConverter(fixedRate: tasaUSD)

            let vm = registros(m.txs, m.cuentas, context, principal: "PEN", converter: converter)
            let calendario = DailySpendingCalculator.compute(
                groups: vm.groupedRecords, adjustment: vm.statsAdjustment,
                currencyCode: "PEN", converter: converter
            )

            let barras = calendario.spendingByDay.values.reduce(0, +)
            #expect(abs(barras - vm.recordsSummary.expense) < 0.001, "barras \(barras)")
            #expect(abs(barras - 285) < 0.001, "barras \(barras)")
        }
    }
}
