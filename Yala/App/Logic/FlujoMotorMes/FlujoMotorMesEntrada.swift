//
//  FlujoMotorMesEntrada.swift
//  Yala
//
//  Lo que alimenta al motor del mes (`FlujoMotorMes`) desde los modelos: los movimientos resueltos a la divisa del
//  plan con las mismas reglas que el flujo proyectado del Panel (sin ajustes de saldo ni transferencias, sin las patas
//  de préstamo de un gasto de grupo, con «mi parte»), los pagos programados pendientes por el mismo camino que «Ver
//  proyectado» (`ProjectedFlowBuilder.scheduledOccurrences`) y el saldo real de las cuentas en una fecha.
//

import Foundation
import SwiftData

enum FlujoMotorMesEntrada {

    /// Los movimientos que entran al motor y si alguno salió de una tasa aproximada.
    static func movimientos(
        _ transactions: [TransactionItem],
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        startOfTomorrow: Date,
        calendar: Calendar
    ) -> (movimientos: [FlujoMotorMes.Movimiento], aproximado: Bool) {
        var result: [FlujoMotorMes.Movimiento] = []
        result.reserveCapacity(transactions.count)
        var aproximado = false
        // YALA-IOS-12 / -Q (build 2.3 (4)): este bucle corre en el hilo principal sobre toda la historia, varias veces
        // por cálculo. Cada propiedad de un `@Model` cuesta lo suyo al leerla, así que cada una se lee una vez, y el mes
        // sale de la caché de intervalos (`MonthBucketer`), no de una pregunta al calendario por movimiento.
        var buckets = MonthBucketer(calendar: calendar)
        for tx in transactions {
            // Los ajustes de saldo y las transferencias no son ingreso ni gasto; la pata de préstamo de un gasto de
            // grupo, tampoco (el mismo filtro que el ritmo y lo fechado de `ProjectedFlowBuilder`).
            guard tx.balanceAdjustmentType == nil, !adjustment.isSuppressed(tx) else { continue }
            let date = tx.date
            guard let mes = buckets.monthStart(of: date) else { continue }
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
            if resolved.approximateMagnitude > 0 { aproximado = true }
            let esIngreso = TransactionClassificationLogic.isIncome(tx)
            let categoria = tx.category
            let subcategoria = tx.subcategory
            var movimiento = FlujoMotorMes.Movimiento(
                mes: mes,
                importe: esIngreso ? resolved.value : -resolved.value,
                esIngreso: esIngreso,
                categoriaID: categoria?.persistentModelID,
                subcategoriaID: subcategoria?.persistentModelID,
                categoria: categoria,
                pagoID: tx.scheduledPaymentID.flatMap(UUID.init(uuidString:)),
                esFechado: date >= startOfTomorrow
            )
            movimiento.dia = calendar.component(.day, from: date)
            // El comercio sale de la nota, como en la memoria de comercios (se canoniza solo donde se mira: la ventana).
            movimiento.nota = tx.note
            movimiento.subcategoriaNombre = subcategoria?.name
            movimiento.subcategoria = subcategoria
            result.append(movimiento)
        }
        return (result, aproximado)
    }

    /// Las ocurrencias pendientes de los pagos programados desde hoy hasta el fin de `lastMonth`, con las reglas de «Ver
    /// proyectado»: las vencidas de este mes sin registrar, mañana; lo ya pagado o saltado, fuera.
    static func ocurrencias(
        allTransactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        paymentFilter: ProjectedFlowBuilder.PaymentFilter,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        lastMonth: Date,
        now: Date,
        calendar: Calendar
    ) -> [ProjectedFlowBuilder.Occurrence] {
        guard !scheduledPayments.isEmpty,
              let current = calendar.dateInterval(of: .month, for: now),
              let last = calendar.dateInterval(of: .month, for: lastMonth),
              last.end > current.start else { return [] }
        let horizon = DateInterval(start: current.start, end: last.end.addingTimeInterval(-1))
        let days = ProjectedFlowCalculator.futureDays(in: horizon, today: now, calendar: calendar)
        return ProjectedFlowBuilder.scheduledOccurrences(ProjectedFlowBuilder.Inputs(
            today: now,
            calendar: calendar,
            overdueWindowStart: ProjectedFlowBuilder.overdueWindowStart(today: now, calendar: calendar),
            days: days,
            allTransactions: allTransactions,
            countedTransactions: allTransactions,
            hasSessionFilters: false,
            scheduledPayments: scheduledPayments,
            paymentFilter: paymentFilter,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        ))
    }

    /// Cada ocurrencia en el mes del día en que se proyecta (una vencida el último día del mes cae en el siguiente).
    static func pendientes(
        _ occurrences: [ProjectedFlowBuilder.Occurrence], calendar: Calendar
    ) -> [FlujoMotorMes.Pendiente] {
        occurrences.compactMap { occurrence in
            guard let mes = calendar.dateInterval(of: .month, for: occurrence.day)?.start else { return nil }
            let esIngreso = occurrence.flow.income > 0
            return FlujoMotorMes.Pendiente(
                mes: mes,
                pagoID: occurrence.paymentID,
                categoriaID: occurrence.categoryID,
                subcategoriaID: occurrence.subcategoryID,
                esIngreso: esIngreso,
                importe: esIngreso ? occurrence.flow.income : occurrence.flow.expense
            )
        }
    }

    static func linea(_ line: CashFlowLine) -> FlujoMotorMes.Linea {
        FlujoMotorMes.Linea(
            id: line.id,
            esIngreso: line.isIncome,
            categoriaID: (line.category ?? line.subcategory?.category)?.persistentModelID,
            subcategoriaID: line.subcategory?.persistentModelID,
            pagoID: line.method == .scheduled ? line.scheduledPayment?.id : nil
        )
    }

    /// El saldo real de las cuentas que suman, en el sentido del saldo del Panel.
    struct FuenteSaldo {
        let accounts: [Account]
        let transactions: [TransactionItem]
        let currencyCode: String
        let converter: any CurrencyConverting

        /// El saldo vivo de hoy, con la regla del saldo vivo (`LiveBalanceCalculator`): la misma cifra que «Tienes hoy».
        func saldoDeHoy(_ now: Date) -> Double {
            let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
                accounts: accounts, transactions: transactions, preferredCurrencyCode: currencyCode,
                asOf: now, converter: converter
            )
            return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
        }

        /// Lo que había antes de cada instante (excluido) en instantes ya pasados: el cierre del mes que acaba ahí. Cada
        /// divisa por la tasa de ese cierre (`BalanceValuation`, la regla de un saldo pasado de `currency-fx.md`), como
        /// la curva de saldo del Panel; una pasada por el libro para todos los instantes.
        func saldos(antesDe instantes: [Date], now: Date, calendar: Calendar) -> [Date: Double] {
            guard !instantes.isEmpty else { return [:] }
            let eligible = Set(accounts.filter(\.sumsInBalance).map(\.persistentModelID))
            var natives: [Date: [String: Decimal]] = Dictionary(uniqueKeysWithValues: instantes.map { ($0, [:]) })
            var currencies: Set<String> = []
            for tx in transactions {
                guard LiveBalanceCalculator.entersBalance(tx), let account = tx.account,
                      eligible.contains(account.persistentModelID) else { continue }
                currencies.insert(tx.currencyCode)
                for instante in instantes where tx.date < instante {
                    LiveBalanceCalculator.addNative(tx, to: &natives[instante, default: [:]])
                }
            }
            let cierres = instantes.map { $0.addingTimeInterval(-1) }
            let valuation = BalanceValuation(
                currencies: currencies, to: currencyCode, closingDates: cierres, converter: converter,
                now: now, calendar: calendar
            )
            var result: [Date: Double] = [:]
            for instante in instantes {
                result[instante] = valuation.doubleValue(natives[instante] ?? [:], at: instante.addingTimeInterval(-1))
            }
            return result
        }
    }

    /// Las cuentas y los movimientos del saldo del Panel sin filtro de cuentas, como «Al 30 tendrías»
    /// (`MonthEndBalanceLogic`). `nil` sin cuentas que sumen.
    static func alcanceDelSaldo(
        accounts: [Account], transactions: [TransactionItem], includeGroups: Bool
    ) -> (accounts: [Account], transactions: [TransactionItem])? {
        let balanceAccounts = PanelBalanceScopeLogic.accounts(
            eligible: accounts.filter(\.sumsInBalance), includeGroups: includeGroups, selectedAccountIDs: []
        )
        guard !balanceAccounts.isEmpty else { return nil }
        let scoped = PanelBalanceScopeLogic.transactions(
            transactions, accountIDs: Set(balanceAccounts.map(\.persistentModelID))
        )
        return (balanceAccounts, scoped)
    }
}
