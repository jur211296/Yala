//
//  CargaPanelParidadTests.swift
//  YalaTests / Eficiencia8CalculadorasYCargaPanel
//
//  Lote 8 de eficiencia (27-nov-2026). La carga del Panel en el arranque dejaba un bloque de ~0,55 s en el hilo principal
//  con 16.004 movimientos en el iPhone 14. Ahora va por tramos (`PanelViewModel.cargarPorTramos`): el ajuste de los gastos
//  de grupo y el recuento de movimientos sin cuenta reciben solo las filas que miran
//  (`CargaPanelPorTramos.importaAGruposOHuerfanos`), y los saldos de las cuentas y las líneas de la tarjeta «Grupos» se
//  suman en una sola pasada. El saldo grande del Panel suma por tramos y una sola vez por cálculo.
//
//  Se fija que las dos cargas —la de una vez (`loadData()`) y la de la recarga, por tramos— dejan lo mismo que el código
//  previo sobre el historial ENTERO: el ajuste de grupos fila a fila, el recuento de huérfanos, los saldos de las cuentas,
//  las líneas de Grupos y el saldo grande, con gastos de grupo con sus dos patas, una liquidación, filas sin cuenta (con y
//  sin puntero), cuentas excluida y archivada, otra divisa y fechas futuras.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Eficiencia 8 · la carga del Panel por tramos deja lo mismo que antes", .serialized)
@MainActor
struct CargaPanelParidadTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func sembrar(_ context: ModelContext) throws -> Account {
        let cuentas = try CalculadorasLote8Fixture.seed(context, count: 1_800, now: .now)
        let grupos = Account(name: "Grupos", currencyCode: "PEN", colorHex: "#444444", iconName: "x", type: "cash",
                             isSystemAccount: true)
        context.insert(grupos)
        let comida = Category(name: "Cena", colorHex: "#FF00FF", isIncome: false)
        context.insert(comida)
        let hoy = Date.now
        for g in 0..<40 {
            let fecha = hoy.addingTimeInterval(Double(g % 9 == 0 ? 3 : -g) * 86_400)  // alguno con fecha futura
            let gasto = "gasto-\(g)"
            let zona = "zona-\(g % 4)"
            // Pata real (cuenta personal) y pata de préstamo (cuenta de Grupos, ingreso): el ajuste las netea.
            let real = TransactionItem(date: fecha, amount: -100 - Double(g), currencyCode: "PEN", category: comida,
                                       account: cuentas.pen, amountInPreferredCurrency: -100 - Double(g))
            real.splitExpenseID = gasto
            real.splitGroupZoneID = zona
            let prestamo = TransactionItem(date: fecha, amount: 60 + Double(g), currencyCode: "PEN", category: comida,
                                           account: grupos, amountInPreferredCurrency: 60 + Double(g))
            prestamo.splitExpenseID = gasto
            prestamo.splitGroupZoneID = zona
            for tx in [real, prestamo] { tx.createdAt = fecha; context.insert(tx) }
            if g % 5 == 0 {
                // Una pata sin cuenta del mismo gasto: el recuento de huérfanos lee su evidencia.
                let suelta = TransactionItem(date: fecha, amount: -7, currencyCode: "PEN", category: comida)
                suelta.splitExpenseID = gasto
                suelta.splitGroupZoneID = zona
                suelta.createdAt = fecha
                context.insert(suelta)
            }
            if g % 6 == 0 {
                // La pata de una liquidación, con cuenta de Grupos: suma en su saldo y en su línea.
                let liquidacion = TransactionItem(date: fecha, amount: -25, currencyCode: "PEN", account: grupos,
                                                  amountInPreferredCurrency: -25)
                liquidacion.splitSettlementID = "liq-\(g)"
                liquidacion.splitGroupZoneID = zona
                liquidacion.createdAt = fecha
                context.insert(liquidacion)
            }
        }
        try context.save()
        return grupos
    }

    private func panel(_ context: ModelContext) async throws -> PanelViewModel {
        // El eco del guardado llega a los pocos ms: que caiga antes de la primera carga (regla de `testing.md`).
        try await Task.sleep(for: .milliseconds(300))
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    /// Lo que la carga tiene que dejar, calculado con el código previo sobre el historial entero.
    private struct Esperado {
        let ajuste: GroupBridgeStatsAdjustment
        let huerfanos: Int
        let saldos: [PersistentIdentifier: Double]
        let lineas: [GroupsAccountCardLogic.GroupLine]
        let saldoGrande: Double
    }

    private func esperado(_ context: ModelContext, viewModel: PanelViewModel) throws -> Esperado {
        let todos = viewModel.transactions
        let cuentas = viewModel.accounts
        let ahora = Date.now
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: ahora)
        let systemIDs = Set(cuentas.filter { $0.isSystemAccount && !$0.isArchived }.map(\.persistentModelID))
        let movimientos: [GroupsAccountCardLogic.Movement] = systemIDs.isEmpty ? [] : todos.compactMap { tx in
            guard cutoff.counts(tx.date), let account = tx.account,
                  systemIDs.contains(account.persistentModelID) else { return nil }
            let pointsToGroup = tx.splitExpenseID != nil || tx.splitSettlementID != nil
            return .init(zoneID: pointsToGroup ? tx.splitGroupZoneID : nil,
                         currencyCode: account.currencyCode, amount: tx.amount)
        }
        let totales = PanelTotalAccountsLogic.accountsForTotal(cuentas, includeGroups: true, hasSelectedAccount: false)
        let saldoGrande = ReferenciaCalculadorasPreLote8.liveBalanceBreakdown(
            accounts: totales, transactions: todos, preferredCurrencyCode: "PEN")
        return Esperado(
            ajuste: GroupBridgeStatsAdjustment.build(from: todos, context: context),
            huerfanos: OrphanedRecordsService.orphanCount(in: todos, context: context),
            saldos: ReferenciaCalculadorasPreLote8.batchCalculateBalances(accounts: cuentas, transactions: todos)
                .mapValues { ($0 as NSDecimalNumber).doubleValue },
            lineas: GroupsAccountCardLogic.groupLines(movimientos),
            saldoGrande: (saldoGrande.convertedTotal as NSDecimalNumber).doubleValue
        )
    }

    private func comprobar(_ viewModel: PanelViewModel, contra esperado: Esperado, _ via: String) {
        for tx in viewModel.transactions {
            #expect(viewModel.statsAdjustment.isSuppressed(tx) == esperado.ajuste.isSuppressed(tx), "\(via): suprimida")
            #expect(viewModel.statsAdjustment.isAdjusted(tx) == esperado.ajuste.isAdjusted(tx), "\(via): ajustada")
            #expect(viewModel.statsAdjustment.amountInPreferredCurrency(tx)
                    == esperado.ajuste.amountInPreferredCurrency(tx), "\(via): importe ajustado")
        }
        #expect(viewModel.orphanedRecordCount == esperado.huerfanos, "\(via): huérfanos")
        #expect(viewModel.accountBalances == esperado.saldos, "\(via): saldos de las cuentas")
        #expect(viewModel.groupAccountLines == esperado.lineas, "\(via): líneas de Grupos")
    }

    @Test("La carga de una vez deja lo mismo que el código previo")
    func cargaDeUnaVez_igualQueAntes() async throws {
        let context = try makeTestContext()
        _ = try sembrar(context)
        let viewModel = try await panel(context)
        viewModel.loadData()
        let esperado = try esperado(context, viewModel: viewModel)
        comprobar(viewModel, contra: esperado, "de una vez")

        // El fixture no es trivial: hay patas suprimidas y ajustadas, huérfanos, líneas de varios grupos y saldos.
        let todos = viewModel.transactions
        #expect(todos.contains { esperado.ajuste.isSuppressed($0) })
        #expect(todos.contains { esperado.ajuste.isAdjusted($0) })
        #expect(esperado.huerfanos > 0)
        #expect(esperado.lineas.count >= 3)
        #expect(esperado.saldos.count >= 5)
    }

    @Test("La recarga por tramos deja lo mismo, y el saldo grande también")
    func recargaPorTramos_igualQueAntes() async throws {
        let context = try makeTestContext()
        _ = try sembrar(context)
        let viewModel = try await panel(context)
        let antes = viewModel.debugCalculationRuns
        viewModel.reloadAndRecalculate()
        for _ in 0..<500 where viewModel.debugCalculationRuns <= antes {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(viewModel.debugCalculationRuns == antes + 1, "la recarga no terminó")
        let esperado = try esperado(context, viewModel: viewModel)
        comprobar(viewModel, contra: esperado, "por tramos")
        #expect(viewModel.panelTotalBalance == esperado.saldoGrande, "el saldo grande cambió")
        #expect(viewModel.isReady)
    }

    @Test("El filtro de la carga deja dentro toda fila con gasto de grupo o sin cuenta, y fuera las demás")
    func filtroDeLaCarga() throws {
        let cuenta = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        let normal = TransactionItem(date: .now, amount: -1, currencyCode: "PEN", account: cuenta)
        let sinCuenta = TransactionItem(date: .now, amount: -1, currencyCode: "PEN")
        let deGasto = TransactionItem(date: .now, amount: -1, currencyCode: "PEN", account: cuenta)
        deGasto.splitExpenseID = "g"
        let liquidacion = TransactionItem(date: .now, amount: -1, currencyCode: "PEN", account: cuenta)
        liquidacion.splitSettlementID = "l"
        #expect(!CargaPanelPorTramos.importaAGruposOHuerfanos(normal))
        #expect(CargaPanelPorTramos.importaAGruposOHuerfanos(sinCuenta))
        #expect(CargaPanelPorTramos.importaAGruposOHuerfanos(deGasto))
        #expect(!CargaPanelPorTramos.importaAGruposOHuerfanos(liquidacion))
    }
}
