//
//  SaludFinancieraDetalleCargador.swift
//  Yala
//
//  Lee lo que la hoja de la nota de salud enseña además de la nota: los presupuestos con su barra, su historia y dónde
//  más pesa cada uno; tu dinero de hoy frente a lo que te falta pagar este mes; los ingresos que esperas; la racha; y,
//  en Pro, la tarjeta del resumen con IA que Estadísticas ya guardó. La nota llega hecha del Panel (`FinancialScore`).
//
//  Los movimientos se leen por tramos, cediendo el hilo entre uno y otro, como la recarga del Panel (YALA-IOS-K): leídos
//  de una vez, un historial grande congelaba la app más de 2 s. Mientras leen, la hoja enseña la nota y lo demás llega
//  después. Nada de esto llama a la red: la tarjeta de IA sale de lo guardado o no sale.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SaludFinancieraDetalleCargador {

    /// Un nombre con su fecha: el próximo pago cuando ya no falta nada este mes.
    struct ProximoPago: Equatable {
        let nombre: String
        let fecha: Date
    }

    /// Por dónde empezar sin presupuestos: la categoría con más gasto medio de los últimos meses completos.
    struct CategoriaSugerida: Equatable {
        let nombre: String
        let promedioMensual: Double
        let moneda: String
    }

    /// Una cuenta en negativo, con su id para abrir su ficha.
    struct CuentaEnRojo: Equatable {
        let nombre: String
        let id: UUID?
    }

    struct Datos: Equatable {
        var presupuestos: [SaludFinancieraDetalleLogica.Presupuesto] = []
        var pagos: [SaludFinancieraDetalleLogica.Pago] = []
        var comparacion: SaludFinancieraDetalleLogica.Comparacion?
        /// «Tu dinero hoy», también sin pagos (la frase de «Aún no tienes pagos planificados» lo nombra).
        var dineroHoy: Double = 0
        var ingresos: [SaludFinancieraDetalleLogica.IngresoEsperado] = []
        var proximoPago: ProximoPago?
        var tienePagos = false
        var cuentasEnRojo: [CuentaEnRojo] = []
        var racha = SaludFinancieraDetalleLogica.Racha(dias: 0, tira: [], registroHoy: false)
        /// Nombres de los cobros que se repiten y aún no son pagos planificados (solo sin pagos).
        var cobrosQueSeRepiten: [String] = []
        var categoriaSugerida: CategoriaSugerida?
        var tarjetaIA: SaludFinancieraDetalleLogica.TarjetaIA?
        var esPro = false
        var finDeMes: Date = .now
    }

    private(set) var datos: Datos?

    /// Movimientos por tramo: los mismos 1.500 del Panel.
    static let tamanoTramo = 1_500
    /// Meses completos que mira la sugerencia de presupuesto.
    static let mesesSugerencia = 3

    func cargar(
        context: ModelContext,
        score: FinancialScore,
        currencyCode: String,
        coverageScope: FinancialScoreCalculator.CoverageScope,
        includeGroupTransactionsInStats: Bool,
        esPro: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let budgets: [Budget]
        let payments: [ScheduledPayment]
        let accounts: [Account]
        do {
            budgets = try context.fetch(FetchDescriptor<Budget>()).filter { $0.isActive && $0.limitAmount > 0 }
            payments = ScheduledPaymentPendingDeletion.shared.visible(try context.fetch(FetchDescriptor<ScheduledPayment>()))
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

        let presupuestos = budgets.map { budget in
            Self.presupuesto(budget, transactions: transactions, adjustment: adjustment, converter: converter,
                             context: context, now: now, calendar: calendar)
        }

        // Este mes natural, cerrado en su último segundo: el intervalo de la nota (`commitmentsInterval`).
        let monthFallback = DetailPeriod.thisMonth.dateInterval(customRange: nil, now: now)
        let mes = FinancialScoreCalculator.commitmentsInterval(
            period: .thisMonth, fallback: monthFallback, now: now, calendar: calendar
        )
        let activos = payments.filter(\.isActive)
        let gastos = activos.filter { $0.transactionType != TransactionType.income.rawValue }
        let ingresos = activos.filter { $0.transactionType == TransactionType.income.rawValue }
        let pagados = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(for: activos, interval: mes, context: context)

        let pagos = SaludFinancieraDetalleLogica.pagosPendientes(
            FinancialScoreCalculator.pendingOccurrences(active: gastos, paidAmounts: pagados, interval: mes,
                                                        calendar: calendar).map { o in
                let convertido = converter.convertCheckedWithLatestRate(
                    Decimal(abs(o.payment.amount)), from: o.payment.currencyCode, to: currencyCode
                )
                return (id: o.payment.id, nombre: o.payment.name, fecha: o.date, monto: o.payment.amount,
                        moneda: o.payment.currencyCode,
                        convertido: NSDecimalNumber(decimal: convertido.amount).doubleValue,
                        aproximado: o.payment.currencyCode != currencyCode && convertido.quality != .exact)
            },
            now: now, calendar: calendar
        )

        // «Tu dinero hoy»: la cifra chica del hero del Panel, sin filtro de sesión.
        let dinero = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts,
            totalAccountIDs: FinancialScoreCalculator.totalAccountIDs(accounts, scope: coverageScope),
            overrides: coverageScope.moneyOverrides,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            asOf: now,
            converter: converter
        )
        // La magnitud dudosa del dinero, con la misma conversión que su cifra (`LiveBalanceCalculator`).
        let dineroDudoso = LiveBalanceCalculator.convertAtLatestRate(
            dinero.nativeBalances, to: currencyCode, converter: converter
        ).approximateMagnitude
        // Lo apuntado con fecha posterior a hoy en esas cuentas: la nota lo cuenta (`asOf: .distantFuture`) y la cifra
        // del hero no. La comparación lo suma para decir lo mismo que la nota; «Tu dinero hoy» no cambia.
        let dineroConFuturo = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts,
            totalAccountIDs: FinancialScoreCalculator.totalAccountIDs(accounts, scope: coverageScope),
            overrides: coverageScope.moneyOverrides,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            asOf: .distantFuture,
            converter: converter
        )
        let comparacion = gastos.isEmpty ? nil : SaludFinancieraDetalleLogica.comparacion(
            pagos: pagos,
            dineroHoy: NSDecimalNumber(decimal: dinero.convertedTotal).doubleValue,
            dineroDudoso: NSDecimalNumber(decimal: dineroDudoso).doubleValue,
            apuntadoFuturo: NSDecimalNumber(decimal: dineroConFuturo.convertedTotal - dinero.convertedTotal).doubleValue,
            moneda: currencyCode
        )

        // Los cobros del mes se descuentan desde el día 1 (un sueldo quincenal cobrado el 15 no tapa el del 30) y solo
        // se nombran los que aún llegan.
        let hoy = calendar.startOfDay(for: now)
        let esperados = FinancialScoreCalculator.pendingOccurrences(
            active: ingresos, paidAmounts: pagados, interval: mes, calendar: calendar
        )
        .filter { $0.date >= hoy }
        .map { SaludFinancieraDetalleLogica.IngresoEsperado(nombre: $0.payment.name, fecha: $0.date,
                                                             monto: abs($0.payment.amount),
                                                             moneda: $0.payment.currencyCode) }
        .sorted { $0.fecha < $1.fecha }

        let proximo = gastos
            .filter { $0.nextDueDate > mes.end && !$0.isDateSkipped($0.nextDueDate) }
            .min { $0.nextDueDate < $1.nextDueDate }
            .map { ProximoPago(nombre: $0.name, fecha: $0.nextDueDate) }

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
            CuentaEnRojo(nombre: nombre, id: vigiladas.first { $0.name == nombre }?.shortcutID)
        }

        var cobros: [String] = []
        if gastos.isEmpty {
            do {
                cobros = try RecurringProposalsSource.load(context: context, now: now, calendar: calendar)
                    .map(\.proposal.displayName)
            } catch {
                #if DEBUG
                print("SaludFinancieraDetalleCargador: Error leyendo cobros que se repiten: \(error)")
                #endif
            }
        }

        let sugerida = presupuestos.isEmpty
            ? Self.categoriaSugerida(transactions: transactions, currencyCode: currencyCode, adjustment: adjustment,
                                     includeGroupTransactions: includeGroupTransactionsInStats,
                                     converter: converter, now: now, calendar: calendar)
            : nil

        datos = Datos(
            presupuestos: SaludFinancieraDetalleLogica.ordenar(presupuestos),
            pagos: pagos,
            comparacion: comparacion,
            dineroHoy: NSDecimalNumber(decimal: dinero.convertedTotal).doubleValue,
            ingresos: esperados,
            proximoPago: proximo,
            tienePagos: !gastos.isEmpty,
            cuentasEnRojo: cuentasEnRojo,
            racha: SaludFinancieraDetalleLogica.racha(diasConMovimiento: diasConMovimiento, now: now,
                                                     calendar: calendar),
            cobrosQueSeRepiten: cobros,
            categoriaSugerida: sugerida,
            tarjetaIA: esPro ? Self.tarjetaIAGuardada(now: now, calendar: calendar) : nil,
            esPro: esPro,
            finDeMes: mes.end
        )
    }

    /// Para las capturas y los XCUITest de los seis estados (`SaludFinancieraDetalleMuestra`).
    func usar(_ muestra: Datos) {
        datos = muestra
    }

    // MARK: - Presupuestos

    private static func presupuesto(
        _ budget: Budget,
        transactions: [TransactionItem],
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> SaludFinancieraDetalleLogica.Presupuesto {
        let interval = BudgetPeriodInterval.current(for: budget, now: now, calendar: calendar)
        let spent = BudgetsViewModel.calculateSpending(
            budget: budget, transactions: transactions, interval: interval, adjustment: adjustment, converter: converter
        )
        let display = Budget.computeDisplayProperties(for: budget, in: context)

        // Los períodos completos anteriores (un presupuesto único no tiene).
        var historial: [Double] = []
        if budget.periodType != BudgetPeriodType.unique.rawValue {
            var cursor = interval.start
            for _ in 0..<SaludFinancieraDetalleLogica.periodosDeHistorial {
                let previo = BudgetPeriodInterval.current(for: budget, now: cursor.addingTimeInterval(-1),
                                                          calendar: calendar)
                guard previo.start < cursor else { break }
                // Un período entero anterior a su creación no es historia: no se gastó contra este límite. El de la
                // creación sí cuenta, como en la nota (`FinancialScoreCalculator.bucketIsValid`).
                guard FinancialScoreCalculator.bucketIsValid(previo, for: budget, calendar: calendar) else { break }
                historial.append(BudgetsViewModel.calculateSpending(
                    budget: budget, transactions: transactions, interval: previo, adjustment: adjustment,
                    converter: converter
                ))
                cursor = previo.start
            }
        }

        return .init(id: budget.id, nombre: budget.name, icono: display.icon, color: display.color,
                     gastado: spent, limite: budget.limitAmount, moneda: budget.currencyCode,
                     historial: historial,
                     dondeMasPesa: dondeMasPesa(budget, transactions: transactions, interval: interval,
                                                adjustment: adjustment, converter: converter))
    }

    /// Lo gastado dentro del presupuesto por subcategoría (o categoría si el movimiento no trae subcategoría), con los
    /// mismos movimientos y la misma conversión que `calculateSpending`.
    private static func dondeMasPesa(
        _ budget: Budget,
        transactions: [TransactionItem],
        interval: DateInterval,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting
    ) -> [SaludFinancieraDetalleLogica.Recorte] {
        typealias Recorte = SaludFinancieraDetalleLogica.Recorte
        var sumas: [Recorte.Filtro: (nombre: String, monto: Double)] = [:]
        for tx in BudgetsViewModel.filterTransactions(transactions, forBudget: budget, in: interval,
                                                      adjustment: adjustment) {
            let monto = abs(BudgetsViewModel.budgetAmount(of: tx, in: budget.currencyCode, adjustment: adjustment,
                                                          converter: converter))
            let clave: Recorte.Filtro
            let nombre: String
            if let sub = tx.subcategory, tx.category != nil {
                clave = .subcategoria(sub.persistentModelID)
                nombre = sub.name
            } else if let cat = tx.category {
                clave = .categoria(cat.persistentModelID)
                nombre = cat.name
            } else {
                clave = .ninguno
                nombre = L10n.Report.uncategorized
            }
            sumas[clave, default: (nombre, 0)].monto += monto
        }
        return SaludFinancieraDetalleLogica.dondeMasPesa(
            sumas.map { Recorte(nombre: $0.value.nombre, monto: $0.value.monto, filtro: $0.key) }
        )
    }

    /// La categoría de gasto con más gasto medio en los últimos `mesesSugerencia` meses completos.
    private static func categoriaSugerida(
        transactions: [TransactionItem],
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        includeGroupTransactions: Bool,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> CategoriaSugerida? {
        guard let inicioMes = calendar.dateInterval(of: .month, for: now)?.start,
              let desde = calendar.date(byAdding: .month, value: -mesesSugerencia, to: inicioMes) else { return nil }
        var sumas: [PersistentIdentifier: (nombre: String, monto: Double)] = [:]
        for tx in transactions where tx.date >= desde && tx.date < inicioMes {
            // Los gastos de grupo, con el interruptor de Estadísticas (la sugerencia habla de lo que ahí se ve).
            guard tx.balanceAdjustmentType == nil, tx.account != nil, !adjustment.isSuppressed(tx),
                  BridgedTransactionFilter.shouldInclude(splitExpenseID: tx.splitExpenseID,
                                                         splitSettlementID: tx.splitSettlementID,
                                                         includeGroupsToggle: includeGroupTransactions),
                  !TransactionClassificationLogic.isIncome(tx), let cat = tx.category else { continue }
            let monto = CashFlowCalculator.resolvedAmount(tx, currencyCode: currencyCode, adjustment: adjustment,
                                                          converter: converter).value
            // Con signo: una devolución resta de su categoría (`ingreso-gasto.md`).
            sumas[cat.persistentModelID, default: (cat.name, 0)].monto += -monto
        }
        guard let mayor = sumas.values.filter({ $0.monto > 0 }).max(by: { $0.monto < $1.monto }) else { return nil }
        return CategoriaSugerida(nombre: mayor.nombre, promedioMensual: mayor.monto / Double(mesesSugerencia),
                                 moneda: currencyCode)
    }

    // MARK: - Tarjeta de IA guardada

    /// Lee los resúmenes que Estadísticas guardó (`StatsAIAutoRefreshStore`, página `.summary`) sin pedir ninguno.
    static func tarjetaIAGuardada(
        defaults: UserDefaults = .standard,
        now: Date,
        calendar: Calendar
    ) -> SaludFinancieraDetalleLogica.TarjetaIA? {
        guard let key = StatsAIAutoRefreshStore.storageKeys.first,
              let data = defaults.data(forKey: key) else { return nil }
        let entries: [StatsAIAutoRefreshStore.Entry]
        do {
            entries = try JSONDecoder().decode([StatsAIAutoRefreshStore.Entry].self, from: data)
        } catch {
            #if DEBUG
            print("SaludFinancieraDetalleCargador: Error leyendo el resumen guardado: \(error)")
            #endif
            return nil
        }
        let guardados: [(guardado: Date, respuesta: LLMInsightResponse)] = entries
            .filter { $0.page == .summary }
            .compactMap { entry in
                do {
                    return (entry.savedAt, try JSONDecoder().decode(LLMInsightResponse.self, from: entry.payload))
                } catch {
                    #if DEBUG
                    print("SaludFinancieraDetalleCargador: Error: \(error)")
                    #endif
                    return nil
                }
            }
        return SaludFinancieraDetalleLogica.tarjetaIA(
            SaludFinancieraDetalleLogica.resumenDelMes(guardados, now: now, calendar: calendar)
        )
    }

    // MARK: - Movimientos

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
