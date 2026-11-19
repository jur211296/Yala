//
//  SaludFinancieraDetalleCargador.swift
//  Yala
//
//  Lee lo que la hoja de la nota de salud enseña además de la nota: presupuestos con su barra, próximos pagos, la
//  cobertura de fin de mes y la racha. La nota llega hecha del Panel (`FinancialScore`); esto no la toca.
//
//  Los movimientos se leen por tramos, cediendo el hilo entre uno y otro, como la recarga del Panel (YALA-IOS-K): leídos
//  de una vez, un historial grande congelaba la app más de 2 s. Mientras leen, la hoja enseña la nota y lo demás llega
//  después.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SaludFinancieraDetalleCargador {

    struct Datos: Equatable {
        var presupuestos: [SaludFinancieraDetalleLogica.Presupuesto] = []
        var pagos: [SaludFinancieraDetalleLogica.Pago] = []
        var cobertura: SaludFinancieraDetalleLogica.Cobertura?
        var racha = SaludFinancieraDetalleLogica.Racha(dias: 0, tira: [], registroHoy: false)
        var tienePagos = false
        /// Cuentas en negativo con su id para abrir su ficha, por el nombre que trae la alerta de la nota.
        var cuentasEnRojo: [(nombre: String, id: UUID?)] = []

        static func == (lhs: Datos, rhs: Datos) -> Bool {
            lhs.presupuestos == rhs.presupuestos && lhs.pagos == rhs.pagos && lhs.cobertura == rhs.cobertura
                && lhs.racha == rhs.racha && lhs.tienePagos == rhs.tienePagos
                && lhs.cuentasEnRojo.map(\.nombre) == rhs.cuentasEnRojo.map(\.nombre)
                && lhs.cuentasEnRojo.map(\.id) == rhs.cuentasEnRojo.map(\.id)
        }
    }

    private(set) var datos: Datos?

    /// Movimientos por tramo: los mismos 1.500 del Panel.
    static let tamanoTramo = 1_500

    func cargar(
        context: ModelContext,
        score: FinancialScore,
        currencyCode: String,
        includeGroupsInTotal: Bool,
        includeGroupTransactionsInStats: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let budgets: [Budget]
        let payments: [ScheduledPayment]
        let accounts: [Account]
        do {
            budgets = try context.fetch(FetchDescriptor<Budget>()).filter { $0.isActive && $0.limitAmount > 0 }
            payments = try context.fetch(FetchDescriptor<ScheduledPayment>())
            accounts = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("SaludFinancieraDetalleCargador: Error: \(error)")
            #endif
            return
        }
        guard let transactions = await Self.leerMovimientosPorTramos(context: context) else { return }
        guard !Task.isCancelled else { return }

        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: context)
        let converter = CurrencyConverter.shared

        let presupuestos = budgets.map { budget -> SaludFinancieraDetalleLogica.Presupuesto in
            let interval = BudgetPeriodInterval.current(for: budget, now: now, calendar: calendar)
            let spent = BudgetsViewModel.calculateSpending(
                budget: budget, transactions: transactions, interval: interval,
                adjustment: adjustment, converter: converter
            )
            let display = Budget.computeDisplayProperties(for: budget, in: context)
            return .init(id: budget.id, nombre: budget.name, icono: display.icon, color: display.color,
                         gastado: spent, limite: budget.limitAmount, moneda: budget.currencyCode)
        }

        let pagos = SaludFinancieraDetalleLogica.proximosPagos(
            payments.map {
                (id: $0.id, nombre: $0.name, fecha: $0.nextDueDate, monto: $0.amount, moneda: $0.currencyCode,
                 esGasto: $0.type == .expense, activo: $0.isActive, saltado: $0.isDateSkipped($0.nextDueDate))
            },
            now: now, calendar: calendar
        )

        let cobertura = MonthEndBalanceLogic.compute(
            accounts: accounts,
            transactions: transactions,
            scheduledPayments: payments,
            currencyCode: currencyCode,
            includeGroups: includeGroupsInTotal,
            adjustment: adjustment,
            converter: converter,
            context: context,
            now: now,
            calendar: calendar
        ).map {
            SaludFinancieraDetalleLogica.Cobertura(
                alCierre: $0.closing, faltaSalir: $0.expenseLeft, fechaCierre: $0.endDate,
                moneda: currencyCode, esAproximada: $0.isApproximate
            )
        }

        // Los mismos movimientos que mira el Ritmo de la nota: sin ajustes de saldo y con el interruptor de Grupos.
        let diasConMovimiento = Set(transactions.compactMap { tx -> Date? in
            guard tx.balanceAdjustmentType == nil, tx.date <= now, BridgedTransactionFilter.shouldInclude(
                splitExpenseID: tx.splitExpenseID,
                splitSettlementID: tx.splitSettlementID,
                includeGroupsToggle: includeGroupTransactionsInStats
            ) else { return nil }
            return calendar.startOfDay(for: tx.date)
        })

        let vigiladas = accounts.filter(FinancialScoreAlertsLogic.isWatched)
        let cuentasEnRojo = score.alerts.negativeAccounts.map { nombre in
            (nombre: nombre, id: vigiladas.first { $0.name == nombre }?.shortcutID)
        }

        datos = Datos(
            presupuestos: SaludFinancieraDetalleLogica.ordenar(presupuestos),
            pagos: pagos,
            cobertura: cobertura,
            racha: SaludFinancieraDetalleLogica.racha(diasConMovimiento: diasConMovimiento, now: now,
                                                     calendar: calendar),
            tienePagos: payments.contains { $0.isActive },
            cuentasEnRojo: cuentasEnRojo
        )
    }

    /// Todos los movimientos, de 1.500 en 1.500 y cediendo el hilo entre tramos. `nil` si una lectura falla o la tarea
    /// se cancela (la hoja se cerró).
    static func leerMovimientosPorTramos(context: ModelContext) async -> [TransactionItem]? {
        var resultado: [TransactionItem] = []
        var vistos = Set<PersistentIdentifier>()
        var desde = 0
        while true {
            var descriptor = FetchDescriptor<TransactionItem>(sortBy: [
                SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
            ])
            descriptor.fetchOffset = desde
            descriptor.fetchLimit = tamanoTramo
            let tramo: [TransactionItem]
            do {
                tramo = try context.fetch(descriptor)
            } catch {
                #if DEBUG
                print("SaludFinancieraDetalleCargador: Error leyendo movimientos: \(error)")
                #endif
                return nil
            }
            for tx in tramo where vistos.insert(tx.persistentModelID).inserted {
                resultado.append(tx)
            }
            guard tramo.count == tamanoTramo else { break }
            desde += tamanoTramo
            await Task.yield()
            if Task.isCancelled { return nil }
        }
        return RecordPendingDeletion.shared.visible(resultado).filter { !$0.isDeleted && $0.modelContext != nil }
    }
}
