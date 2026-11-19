//
//  CashFlowProjectionCalculator.swift
//  Yala
//
//  Calculates cash flow projections: planned vs real amounts per line per month.
//

import Foundation
import SwiftData

// MARK: - Output Structs

struct CashFlowProjection {
    let months: [CashFlowMonth]
    /// El saldo de tus cuentas al empezar el mes en curso (P5 del replanteo, 18-nov-2026: el saldo inicial manual se
    /// retiró). 0 sin cuentas que sumen.
    let startingBalance: Double
    let totalProjectedIncome: Double
    let totalProjectedExpense: Double
    let totalProjectedNet: Double
    /// Algún importe del plan (un movimiento o un pago programado) salió de una tasa aproximada: lo que falta lleva «≈».
    var isApproximate: Bool = false
}

/// Un mes del flujo de caja (motor del mes, `FlujoMotorMes`): lo real con signo más lo que falta. Un mes cerrado es solo
/// real; el mes en curso, real + lo que falta («Al 30 tendrías»); uno que viene, lo fechado, los pagos pendientes, lo
/// que falta de cada línea hasta su límite y «otros» por la mediana de 6 meses.
struct CashFlowMonth {
    let monthKey: String                     // "2026-04"
    let date: Date
    let isPast: Bool
    let isCurrent: Bool
    let incomeLines: [CashFlowLineResult]
    let expenseLines: [CashFlowLineResult]
    let otherExpenses: CashFlowOtherResult?
    let otherIncome: CashFlowOtherResult?
    /// Todo lo que entra en el mes: real + lo que falta.
    let totalIncome: Double
    /// Todo lo que sale en el mes (positivo; una devolución resta): real + lo que falta.
    let totalExpense: Double
    let netFlow: Double                      // income - expense
    /// Con lo que termina el mes: el saldo real de tus cuentas en un mes cerrado, «Al 30 tendrías» en el mes en curso
    /// y el anterior más el neto en los que vienen. `nil` sin cuentas que sumen.
    let accumulatedBalance: Double?
    /// Con lo que empieza el mes (el cierre del anterior). `nil` sin cuentas que sumen.
    var openingBalance: Double? = nil
    /// Lo que ya entró y salió (fechado antes de mañana).
    var realIncome: Double = 0
    var realExpense: Double = 0
    /// Las categorías como agrupador de sus líneas: la subcategoría es el id base y la categoría, su suma.
    var incomeGroups: [CashFlowCategoryGroup] = []
    var expenseGroups: [CashFlowCategoryGroup] = []
    /// Lo que falta que no es un movimiento fechado ni un pago pendiente (lo que les queda a las líneas y, en gastos, a
    /// «otros» por la mediana): lo que el flujo proyectado del Panel reparte entre los días que quedan. Se calcula
    /// aunque «Gastos no considerados» esté oculto.
    var spreadableIncomeLeft: Double = 0
    var spreadableExpenseLeft: Double = 0
    /// Lo que les falta a los fijos detectados que llegan una vez al mes, por su día típico (día del mes → importe): el
    /// flujo proyectado lo dibuja ese día en vez de repartirlo (`FlujoProyeccionInteligente`).
    var dayPlacedIncomeLeft: [Int: Double] = [:]
    var dayPlacedExpenseLeft: [Int: Double] = [:]

    /// Lo que falta entrar y salir: lo fechado por delante, los pagos pendientes y lo que queda a líneas y «otros».
    var incomeLeft: Double { totalIncome - realIncome }
    var expenseLeft: Double { totalExpense - realExpense }
}

struct CashFlowLineResult {
    let lineID: UUID
    let name: String
    let isIncome: Bool
    /// El límite del mes.
    let plannedAmount: Double
    /// Lo real del mes con signo (una devolución resta), fechado antes de mañana. `nil` en un mes que viene.
    let realAmount: Double?
    let difference: Double?
    let differencePercent: Double?
    let progress: Double?
    let isOverride: Bool
    let estimationMethod: EstimationMethod
    /// En una línea por categoría, lo real de cada subcategoría (y «sin subcategoría»): el detalle llega siempre a
    /// subcategoría.
    let subcategoryBreakdown: [SubcategoryLineResult]?
    /// `plannedAmount` salió de convertir un pago programado con una tasa no exacta: se pinta «≈».
    /// Solo lo enciende una línea `.scheduled` sin override (`ScheduledPaymentAmountConversion`).
    var isPlannedApproximate: Bool = false
    /// El mes desde el que vale el monto de este mes (UX 2.2 · L18-8): un cambio «este mes y los siguientes» hecho
    /// en `amountChangeFromMonthKey`. `nil` si el monto sale del método de la línea o de un ajuste de un solo mes.
    var amountChangeFromMonthKey: String? = nil
    /// Lo fechado de mañana en adelante (aún no es real).
    var datedAmount: Double = 0
    /// Pagos programados pendientes de la línea en el mes.
    var pendingAmount: Double = 0
    /// Lo que le queda hasta su límite, sin lo fechado ni lo pendiente.
    var leftAmount: Double = 0
    /// Lo real y lo fechado pasan del límite: cuenta lo que hay y no proyecta más.
    var isExceeded: Bool = false

    /// Lo que la línea suma al mes: real + fechado + pendiente + lo que falta.
    var expectedAmount: Double { (realAmount ?? 0) + datedAmount + pendingAmount + leftAmount }
}

/// Una categoría del plan como suma de sus líneas.
struct CashFlowCategoryGroup {
    let categoryID: PersistentIdentifier
    let categoryName: String
    let isIncome: Bool
    let lineIDs: [UUID]
    let plannedAmount: Double
    /// Lo real de sus líneas más lo anotado en la categoría sin subcategoría.
    let realAmount: Double
    let expectedAmount: Double
    /// Lo anotado en la categoría madre sin subcategoría cuando sus líneas son por subcategoría (real, fechado y
    /// pendiente): ya descuenta de lo que les falta a esas líneas.
    let unassignedAmount: Double
}

struct CashFlowOtherResult {
    /// Todo lo que suma el mes: real + fechado + pendiente + lo que falta (fijos y lo variable).
    let plannedAmount: Double
    let realAmount: Double?
    let categoryBreakdown: [OtherCategoryItem]
    /// Lo que falta: lo de los fijos detectados más lo variable (mes en curso y futuros).
    var leftAmount: Double = 0
    /// Lo que se proyecta como fijo (decisión de Jürgen del 19-nov-2026): lo que se repite cada mes en tus registros.
    var fixedItems: [OtherFixedItem] = []
    /// Lo que se dejó fuera de la proyección por aislado: de los últimos meses y de este mes.
    var isolatedItems: [OtherIsolatedItem] = []
    /// Lo que se proyecta por lo variable en un mes (la mediana sin fijos ni aislados). 0 en ingresos.
    var variableEstimate: Double = 0
    /// Lo que falta por lo variable en este mes.
    var variableLeft: Double = 0
    /// Meses completos de historia que miró la detección, y si alcanzan para detectar (3 o más).
    var historyMonths: Int = 0
    var detects: Bool = false
    /// Las filas de la hoja por subcategoría (decisión de Jürgen del 19-nov-2026: «siempre a nivel de subcategoría»):
    /// lo real, lo programado y lo proyectado de cada una. Su suma más `variableLeft` es `plannedAmount`.
    var items: [OtherSubcategoryItem] = []
    /// Con plan, un mes que viene: «otros» proyecta solo lo fijo.
    var isFixedOnly: Bool = false
}

/// Una fila de «Ingresos/Gastos no considerados»: una subcategoría, lo anotado en una categoría sin subcategoría o lo
/// sin categoría.
struct OtherSubcategoryItem: Identifiable {
    enum Kind {
        /// Una subcategoría: el + la agrega al plan.
        case subcategory
        /// Lo anotado en la categoría madre sin subcategoría, cuando la categoría tiene subcategorías.
        case parentWithoutSubcategory
        /// Una categoría que no tiene subcategorías: su línea es la categoría.
        case categoryWithoutSubcategories
        case uncategorized
    }

    let id: String
    let kind: Kind
    let name: String
    /// La categoría que la agrupa en la hoja.
    let categoryName: String
    let iconName: String
    let colorHex: String
    let category: Category?
    let subcategory: Subcategory?
    let realAmount: Double
    /// Lo fechado por delante y los pagos planificados pendientes.
    let scheduledAmount: Double
    /// Lo que se proyecta por sus fijos.
    let projectedAmount: Double
    /// Lo real de esta fila que se dejó fuera por aislado.
    let isolatedAmount: Double
    let fixedItems: [OtherFixedItem]

    var total: Double { realAmount + scheduledAmount + projectedAmount }
    /// Se puede agregar al plan sin perder el detalle de subcategoría.
    var canBecomeLine: Bool { kind == .subcategory || kind == .categoryWithoutSubcategories }
}

/// Un fijo detectado, para la hoja de «Otros».
struct OtherFixedItem {
    /// El comercio, la subcategoría o la categoría (o «Sin categoría»).
    let name: String
    /// La categoría que lo agrupa cuando el nombre es su subcategoría o un comercio; `nil` si el nombre ya es la categoría.
    var groupName: String? = nil
    let iconName: String
    let colorHex: String
    /// Lo que suma cada mes.
    let monthlyAmount: Double
    /// El día del mes en que suele llegar; `nil` si llega varias veces al mes.
    let day: Int?
    /// Lo que le falta en el mes elegido (0 si ya llegó o lo cubre un pago planificado).
    let leftAmount: Double
    let monthsSeen: Int
    let monthsWindow: Int
    /// Lo que de verdad entró en el mes elegido (sin lo fechado ni un pago pendiente): «Ya llegó este mes» sale de aquí.
    var receivedAmount: Double = 0
    /// La clave de «Considerar a futuro» (`FlujoFijosAFuturo`).
    var stableKey: String = ""
    /// Encendido en «Considerar a futuro»: se proyecta en los meses que vienen.
    var isConsideredInFuture: Bool = true
}

/// Un movimiento aislado que no entra en la proyección de los meses que vienen.
struct OtherIsolatedItem {
    let name: String
    var groupName: String? = nil
    let iconName: String
    let colorHex: String
    let amount: Double
    let month: Date
}

struct OtherCategoryItem {
    let categoryName: String
    let iconName: String
    let colorHex: String
    let amount: Double
}

struct SubcategoryLineResult {
    let subcategoryName: String
    let plannedAmount: Double
    let realAmount: Double?
}

// MARK: - Pre-grouped Transaction Index

/// O(1) lookup of pre-converted transaction totals by (category, month). Lo usan las estimaciones de una línea
/// (promedios, tendencia, último mes) y las sugerencias del plan.
///
/// Suma CON SIGNO del lado de la categoría (`ingreso-gasto.md`, «Cómo se suma»): en una categoría de gasto lo gastado es
/// positivo y una devolución resta. Hasta el replanteo del 18-nov-2026 sumaba magnitudes y una devolución de 80 contaba
/// como 80 de gasto (hallazgo 6).
struct TransactionIndex {
    /// Totals by category persistentModelID → monthKey → signed sum
    let byCategoryMonth: [PersistentIdentifier: [String: Double]]
    /// Totals by subcategory persistentModelID → monthKey → signed sum
    let bySubcategoryMonth: [PersistentIdentifier: [String: Double]]
    /// Lo que el reparto de dueños del motor del mes da a cada línea del plan (`FlujoMotorMes.importesPorLinea`): con
    /// él, el promedio de una línea por categoría no cuenta lo de sus subcategorías con línea propia ni lo de los pagos
    /// con línea. `nil` en las sugerencias del plan, que aún no tiene líneas.
    var byLineMonth: [UUID: [String: Double]]? = nil

    init(transactions: [TransactionItem], currencyCode: String, adjustment: GroupBridgeStatsAdjustment = .none, converter: CurrencyConverting, calendar: Calendar) {
        var catMonth: [PersistentIdentifier: [String: Double]] = [:]
        var subMonth: [PersistentIdentifier: [String: Double]] = [:]

        for tx in transactions {
            guard let catID = tx.category?.persistentModelID else { continue }
            // Suprime la pata de préstamo derivada (bridge): no es gasto/ingreso propio.
            if adjustment.isSuppressed(tx) { continue }
            let key = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)

            // `adjustment` proyecta el gasto de grupo Caso A a "mi parte" (neto).
            let value = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value
            let signed = TransactionClassificationLogic.isIncome(tx) ? value : -value

            catMonth[catID, default: [:]][key, default: 0] += signed

            if let subID = tx.subcategory?.persistentModelID {
                subMonth[subID, default: [:]][key, default: 0] += signed
            }
        }

        self.byCategoryMonth = catMonth
        self.bySubcategoryMonth = subMonth
    }

    func total(for categoryID: PersistentIdentifier, monthKey: String) -> Double {
        byCategoryMonth[categoryID]?[monthKey] ?? 0
    }

    func subcategoryTotal(for subcategoryID: PersistentIdentifier, monthKey: String) -> Double {
        bySubcategoryMonth[subcategoryID]?[monthKey] ?? 0
    }

    func monthKeys(for categoryID: PersistentIdentifier) -> [String: Double] {
        byCategoryMonth[categoryID] ?? [:]
    }
}

// MARK: - Calculator

struct CashFlowProjectionCalculator {

    private static let customMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    /// La proyección del plan, mes a mes, con el motor del mes (`FlujoMotorMes`).
    ///
    /// - `transactions`: los movimientos que cuentan como reales. El flujo de caja pasa los de las cuentas que suman en
    ///   el saldo del Panel (`FlujoMotorMesEntrada.alcanceDelSaldo`), como «Al 30 tendrías».
    /// - `balance`: de dónde sale el saldo real de cada mes. Sin él, los meses no llevan saldo (`accumulatedBalance`).
    /// - `occurrences`: los pagos programados pendientes ya calculados (el flujo proyectado pasa los suyos); sin ellos,
    ///   se calculan aquí desde `scheduledPayments` sin filtro de cuentas.
    /// - `historyTransactions`: de dónde salen los límites de las líneas (promedios) y la mediana de «otros». Todos los
    ///   movimientos, sea quien sea quien llama, para que el Panel y el flujo de caja proyecten lo mismo. `nil` =
    ///   `transactions`.
    /// - `includesSubcategoryBreakdown`: el desglose por subcategoría de cada línea, que solo pintan las vistas del
    ///   flujo de caja (el flujo proyectado del Panel no lo calcula).
    /// - `allExpenseCategories` / `allIncomeCategories` ya no se usan: «otros» sale de los movimientos, con lo sin
    ///   categoría dentro. Se quedan para no tocar a quien llama.
    static func calculate(
        plan: CashFlowPlan,
        lines: [CashFlowLine],
        transactions: [TransactionItem],
        allExpenseCategories: [Category],
        allIncomeCategories: [Category] = [],
        scheduledPayments: [ScheduledPayment],
        monthsBack: Int,
        monthsAhead: Int,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared,
        balance: FlujoMotorMesEntrada.FuenteSaldo? = nil,
        occurrences: [ProjectedFlowBuilder.Occurrence]? = nil,
        historyTransactions: [TransactionItem]? = nil,
        includesSubcategoryBreakdown: Bool = true,
        excludedFutureFixed: Set<String>? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CashFlowProjection {
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return CashFlowProjection(months: [], startingBalance: 0,
                                       totalProjectedIncome: 0, totalProjectedExpense: 0, totalProjectedNet: 0)
        }
        let months = generateMonthRange(
            from: currentMonthStart, monthsBack: monthsBack, monthsAhead: monthsAhead, calendar: calendar
        )
        let startOfTomorrow = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar).startOfTomorrow

        let enabled = lines.filter(\.isEnabled)
        // El reparto de dueños sigue el orden del plan: con dos líneas para lo mismo gana la primera, siempre la misma.
        let planOrder = enabled.sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        let motorLines = planOrder.map { FlujoMotorMesEntrada.linea($0) }

        let resolved = FlujoMotorMesEntrada.movimientos(
            transactions, currencyCode: currencyCode, adjustment: adjustment, converter: converter,
            startOfTomorrow: startOfTomorrow, calendar: calendar
        )
        let movimientos = resolved.movimientos
        let history = historyTransactions ?? transactions
        let historia = historyTransactions == nil ? movimientos : FlujoMotorMesEntrada.movimientos(
            history, currencyCode: currencyCode, adjustment: adjustment, converter: converter,
            startOfTomorrow: startOfTomorrow, calendar: calendar
        ).movimientos

        // Índice para las estimaciones de cada línea (promedios de meses completos), con lo que el motor da a cada línea.
        var index = TransactionIndex(
            transactions: history.filter { $0.balanceAdjustmentType == nil },
            currencyCode: currencyCode, adjustment: adjustment, converter: converter, calendar: calendar
        )
        index.byLineMonth = FlujoMotorMes.importesPorLinea(historia, lineas: motorLines).mapValues { byMonth in
            Dictionary(byMonth.map { (Self.monthKey(for: $0.key, calendar: calendar), $0.value) },
                       uniquingKeysWith: +)
        }

        let currentMKey = Self.monthKey(for: currentMonthStart, calendar: calendar)
        let incomeLines = sortLinesByAmountGrouped(
            enabled.filter(\.isIncome), monthKey: currentMKey, monthDate: currentMonthStart,
            currentMonthStart: currentMonthStart, index: index,
            currencyCode: currencyCode, converter: converter, calendar: calendar
        )
        let expenseLines = sortLinesByAmountGrouped(
            enabled.filter { !$0.isIncome }, monthKey: currentMKey, monthDate: currentMonthStart,
            currentMonthStart: currentMonthStart, index: index,
            currencyCode: currencyCode, converter: converter, calendar: calendar
        )
        let orderedLines = incomeLines + expenseLines

        // El límite de cada línea en cada mes, una vez.
        var planned: [UUID: [Date: (amount: Double, isApproximate: Bool, isOverride: Bool, changeFromMonthKey: String?)]] = [:]
        for line in orderedLines {
            for month in months {
                planned[line.id, default: [:]][month] = resolvePlanned(
                    line: line, monthKey: Self.monthKey(for: month, calendar: calendar), monthDate: month,
                    currentMonthStart: currentMonthStart, index: index,
                    currencyCode: currencyCode, converter: converter, calendar: calendar
                )
            }
        }

        let pending = occurrences ?? FlujoMotorMesEntrada.ocurrencias(
            allTransactions: history, scheduledPayments: scheduledPayments, paymentFilter: .none,
            currencyCode: currencyCode, adjustment: adjustment, converter: converter,
            lastMonth: months.last ?? currentMonthStart, now: now, calendar: calendar
        )
        let quedanDias = startOfTomorrow < (calendar.dateInterval(of: .month, for: now)?.end ?? startOfTomorrow)
        let motor = FlujoMotorMes.calcular(FlujoMotorMes.Entrada(
            meses: months,
            mesEnCurso: currentMonthStart,
            quedanDiasEnElMes: quedanDias,
            lineas: motorLines,
            limite: { id, month in planned[id]?[month]?.amount ?? 0 },
            movimientos: movimientos,
            pendientes: FlujoMotorMesEntrada.pendientes(pending, calendar: calendar),
            calendar: calendar,
            historia: historia,
            // Con plan, en los meses que vienen «otros» proyecta solo lo fijo (decisión de Jürgen del 19-nov-2026).
            soloFijosEnMesesFuturos: true,
            excluidosAFuturo: excludedFutureFixed ?? FlujoFijosAFuturo.excluidos()
        ))
        let isApproximate = resolved.aproximado || planned.values.contains { $0.values.contains(where: \.isApproximate) }

        // Saldos: el real de tus cuentas hasta el mes en curso (cada cierre a la tasa de su fecha); desde ahí, encadenados.
        let pastInstants: [Date] = months.filter { $0 <= currentMonthStart }.compactMap { month in
            month == currentMonthStart ? month : calendar.date(byAdding: .month, value: 1, to: month)
        } + (months.first.map { [$0] } ?? [])
        let pastBalances = balance?.saldos(antesDe: Array(Set(pastInstants)), now: now, calendar: calendar) ?? [:]
        let startingBalance = balance == nil ? nil : pastBalances[currentMonthStart]
        let todayBalance = balance?.saldoDeHoy(now)
        var previousClosing: Double? = months.first.flatMap { pastBalances[$0] }
        let ownership = FlujoMotorMes.Dueños(lineas: motorLines)
        let movimientosPorMes = includesSubcategoryBreakdown
            ? Dictionary(grouping: movimientos.filter { !$0.esFechado }, by: \.mes) : [:]

        // Para nombrar las partidas de «otros» que solo llegan por un pago planificado (sin movimientos en el mes).
        var namesByID: [PersistentIdentifier: (Category?, Subcategory?)] = [:]
        for payment in scheduledPayments {
            guard let sub = payment.subcategory else { continue }
            namesByID[sub.persistentModelID] = (sub.category, sub)
            if let cat = sub.category { namesByID[cat.persistentModelID] = (cat, nil) }
        }
        let categoriesByID = Dictionary(
            orderedLines.compactMap { line in
                (line.category ?? line.subcategory?.category).map { ($0.persistentModelID, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        var projectedMonths: [CashFlowMonth] = []
        var totalProjectedIncome: Double = 0
        var totalProjectedExpense: Double = 0
        for (month, result) in zip(months, motor) {
            let mKey = Self.monthKey(for: month, calendar: calendar)
            let closing: Double?
            if result.esPasado {
                closing = calendar.date(byAdding: .month, value: 1, to: month).flatMap { pastBalances[$0] }
            } else if result.esEnCurso {
                closing = todayBalance.map { $0 + result.ingresos.resto - result.gastos.resto }
            } else {
                closing = previousClosing.map { $0 + result.ingresos.total - result.gastos.total }
            }
            let lineResults: (CashFlowLine) -> CashFlowLineResult = { line in
                let side = line.isIncome ? result.ingresos : result.gastos
                return lineResult(
                    line: line, month: result, side: side,
                    planned: planned[line.id]?[month] ?? (0, false, false, nil),
                    breakdownSource: includesSubcategoryBreakdown
                        ? (movimientosPorMes[month] ?? [], ownership) : nil
                )
            }
            let incomeResults = incomeLines.map(lineResults)
            let expenseResults = expenseLines.map(lineResults)
            let totalIncome = result.ingresos.total
            let totalExpense = result.gastos.total
            projectedMonths.append(CashFlowMonth(
                monthKey: mKey, date: month, isPast: result.esPasado, isCurrent: result.esEnCurso,
                incomeLines: incomeResults, expenseLines: expenseResults,
                otherExpenses: otherResult(result.gastos, isPast: result.esPasado, isCurrent: result.esEnCurso,
                                           showsPlannedOthers: plan.showOtherExpenses, names: namesByID),
                otherIncome: otherResult(result.ingresos, isPast: result.esPasado, isCurrent: result.esEnCurso,
                                         showsPlannedOthers: plan.showOtherExpenses, names: namesByID),
                totalIncome: totalIncome, totalExpense: totalExpense,
                netFlow: totalIncome - totalExpense,
                accumulatedBalance: closing,
                openingBalance: result.esEnCurso ? startingBalance : previousClosing,
                realIncome: result.ingresos.real,
                realExpense: result.gastos.real,
                incomeGroups: groups(result.ingresos, results: incomeResults, categories: categoriesByID),
                expenseGroups: groups(result.gastos, results: expenseResults, categories: categoriesByID),
                spreadableIncomeLeft: result.ingresos.faltaRepartible,
                spreadableExpenseLeft: result.gastos.faltaRepartible,
                dayPlacedIncomeLeft: result.ingresos.faltaPorDia,
                dayPlacedExpenseLeft: result.gastos.faltaPorDia
            ))
            previousClosing = closing
            totalProjectedIncome += totalIncome
            totalProjectedExpense += totalExpense
        }

        return CashFlowProjection(
            months: projectedMonths, startingBalance: startingBalance ?? 0,
            totalProjectedIncome: totalProjectedIncome,
            totalProjectedExpense: totalProjectedExpense,
            totalProjectedNet: totalProjectedIncome - totalProjectedExpense,
            isApproximate: isApproximate
        )
    }

    /// «Otros» del mes. Lo sin categoría va en su desglose con el nombre y el gris de «Sin categoría». Con «Gastos no
    /// considerados» apagado (`showOtherExpenses`), no se pinta, aunque su dinero sigue en los totales del mes: un total
    /// sin él no sería lo que pasa en tus cuentas.
    private static func otherResult(
        _ side: FlujoMotorMes.Lado, isPast: Bool, isCurrent: Bool, showsPlannedOthers: Bool,
        names: [PersistentIdentifier: (Category?, Subcategory?)] = [:]
    ) -> CashFlowOtherResult? {
        guard showsPlannedOthers else { return nil }
        let otros = side.otros
        let deteccion = side.deteccion
        let breakdown = otros.porCategoria.map { item in
            OtherCategoryItem(
                categoryName: item.categoria?.name ?? L10n.Report.uncategorized,
                iconName: item.categoria.map { $0.iconName ?? "folder" } ?? AppConstants.uncategorizedIconName,
                colorHex: item.categoria?.colorHex ?? AppConstants.uncategorizedColorHex,
                amount: item.importe
            )
        }
        // Un mes cerrado no proyecta nada: ni fijos ni aislados que explicar.
        let apagados = Set(otros.fijosApagados.map(\.fijo.claveEstable))
        let fixed: [OtherFixedItem] = isPast ? [] : otros.fijos.map {
            var item = fixedItem($0.fijo, left: $0.falta, received: $0.cobrado)
            item.isConsideredInFuture = !apagados.contains(item.stableKey)
            return item
        }
        let items: [OtherSubcategoryItem] = otros.partidas.map { partida in
            subcategoryItem(partida, names: names, apagados: apagados, isPast: isPast)
        }
        let isolated = (isPast ? [] : otros.aislados + deteccion.aisladosVentana).map { aislado in
            OtherIsolatedItem(
                name: displayName(categoria: aislado.categoria, subcategoria: aislado.subcategoriaNombre,
                                  comercio: aislado.comercioVisible),
                groupName: groupName(categoria: aislado.categoria, subcategoria: aislado.subcategoriaNombre,
                                     comercio: aislado.comercioVisible),
                iconName: aislado.categoria.map { $0.iconName ?? "folder" } ?? AppConstants.uncategorizedIconName,
                colorHex: aislado.categoria?.colorHex ?? AppConstants.uncategorizedColorHex,
                amount: aislado.importe,
                month: aislado.mes
            )
        }
        return CashFlowOtherResult(
            plannedAmount: otros.esperado,
            realAmount: (isPast || isCurrent) ? otros.real : nil,
            categoryBreakdown: breakdown,
            leftAmount: otros.falta,
            fixedItems: fixed,
            isolatedItems: isolated,
            variableEstimate: deteccion.variable,
            variableLeft: otros.faltaVariable,
            historyMonths: deteccion.mesesDeHistoria,
            detects: deteccion.detecta,
            items: items,
            isFixedOnly: otros.soloFijos
        )
    }

    /// Una fila de la hoja de no considerados: una subcategoría (el id base), lo anotado en una categoría sin
    /// subcategoría o lo sin categoría, con su categoría como agrupador.
    private static func subcategoryItem(
        _ partida: FlujoMotorMes.PartidaOtros, names: [PersistentIdentifier: (Category?, Subcategory?)],
        apagados: Set<String>, isPast: Bool
    ) -> OtherSubcategoryItem {
        var category = partida.categoria
        var subcategory = partida.subcategoria
        var subName = partida.subcategoriaNombre
        switch partida.base {
        case .subcategoria(let id):
            if let named = names[id] {
                category = category ?? named.0
                subcategory = subcategory ?? named.1
                subName = subName ?? named.1?.name
            }
        case .categoria(let id):
            category = category ?? names[id]?.0
        case .sinCategoria:
            break
        }
        let readableCategory = category.flatMap { $0.isDeleted ? nil : $0 }
        let kind: OtherSubcategoryItem.Kind
        switch partida.base {
        case .subcategoria: kind = .subcategory
        case .categoria:
            let hasVisibleSubs = (readableCategory?.subcategories ?? []).contains(where: \.isVisible)
            kind = hasVisibleSubs ? .parentWithoutSubcategory : .categoryWithoutSubcategories
        case .sinCategoria: kind = .uncategorized
        }
        let name: String
        switch kind {
        case .subcategory: name = subName ?? readableCategory?.name ?? L10n.Report.uncategorized
        case .parentWithoutSubcategory: name = L10n.Report.noSubcategory
        case .categoryWithoutSubcategories: name = readableCategory?.name ?? L10n.Report.uncategorized
        case .uncategorized: name = L10n.Report.uncategorized
        }
        return OtherSubcategoryItem(
            id: String(describing: partida.base),
            kind: kind,
            name: name,
            categoryName: readableCategory?.name ?? L10n.Report.uncategorized,
            iconName: (subcategory?.iconName ?? readableCategory?.iconName) ?? AppConstants.uncategorizedIconName,
            colorHex: (subcategory?.colorHex ?? readableCategory?.colorHex) ?? AppConstants.uncategorizedColorHex,
            category: readableCategory,
            subcategory: subcategory,
            realAmount: partida.real,
            scheduledAmount: partida.programado,
            projectedAmount: partida.proyectado,
            isolatedAmount: partida.aislado,
            fixedItems: isPast ? [] : partida.fijos.map { fijoMes in
                var item = fixedItem(fijoMes.fijo, left: fijoMes.falta, received: fijoMes.cobrado)
                item.isConsideredInFuture = !apagados.contains(item.stableKey)
                return item
            }
        )
    }

    private static func fixedItem(
        _ fijo: FlujoProyeccionInteligente.Fijo, left: Double, received: Double
    ) -> OtherFixedItem {
        OtherFixedItem(
            name: displayName(categoria: fijo.categoria, subcategoria: fijo.subcategoriaNombre,
                              comercio: fijo.comercioVisible),
            groupName: groupName(categoria: fijo.categoria, subcategoria: fijo.subcategoriaNombre,
                                 comercio: fijo.comercioVisible),
            iconName: fijo.categoria.map { $0.iconName ?? "folder" } ?? AppConstants.uncategorizedIconName,
            colorHex: fijo.categoria?.colorHex ?? AppConstants.uncategorizedColorHex,
            monthlyAmount: fijo.monto,
            day: fijo.unaVezAlMes ? fijo.dia : nil,
            leftAmount: left,
            monthsSeen: fijo.mesesVistos,
            monthsWindow: fijo.mesesVentana,
            receivedAmount: received,
            stableKey: fijo.claveEstable
        )
    }

    /// El nombre de un fijo o de un aislado: el comercio si lo hay, si no la subcategoría y si no la categoría (o «Sin
    /// categoría»). El detalle llega a subcategoría; la categoría va aparte, como agrupador (`groupName`).
    private static func displayName(categoria: Category?, subcategoria: String?, comercio: String?) -> String {
        comercio ?? subcategoria ?? categoria?.name ?? L10n.Report.uncategorized
    }

    /// Lo que agrupa al nombre: la categoría cuando el nombre es su subcategoría o un comercio (con la subcategoría si la
    /// hay); `nil` cuando el nombre ya es la categoría.
    private static func groupName(categoria: Category?, subcategoria: String?, comercio: String?) -> String? {
        if comercio != nil {
            let grupo = subcategoria.map { sub in categoria.map { "\($0.name) · \(sub)" } ?? sub } ?? categoria?.name
            return grupo ?? L10n.Report.uncategorized
        }
        return subcategoria == nil ? nil : categoria?.name
    }

    private static func groups(
        _ side: FlujoMotorMes.Lado, results: [CashFlowLineResult],
        categories: [PersistentIdentifier: Category]
    ) -> [CashFlowCategoryGroup] {
        let byID = Dictionary(results.map { ($0.lineID, $0) }, uniquingKeysWith: { first, _ in first })
        return side.grupos.map { group in
            let lineResults = group.lineas.compactMap { byID[$0] }
            return CashFlowCategoryGroup(
                categoryID: group.categoriaID,
                categoryName: categories[group.categoriaID]?.name ?? "",
                isIncome: group.esIngreso,
                lineIDs: group.lineas,
                plannedAmount: lineResults.reduce(0) { $0 + $1.plannedAmount },
                realAmount: lineResults.reduce(0) { $0 + ($1.realAmount ?? 0) } + group.sinSubcategoriaReal,
                expectedAmount: lineResults.reduce(0) { $0 + $1.expectedAmount } + group.sinSubcategoria,
                unassignedAmount: group.sinSubcategoria
            )
        }
    }

    // MARK: - Month Range

    static func generateMonthRange(
        from currentMonth: Date, monthsBack: Int, monthsAhead: Int, calendar: Calendar
    ) -> [Date] {
        (-monthsBack...monthsAhead).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    // MARK: - Line Result

    private static func lineResult(
        line: CashFlowLine,
        month: FlujoMotorMes.Mes,
        side: FlujoMotorMes.Lado,
        planned: (amount: Double, isApproximate: Bool, isOverride: Bool, changeFromMonthKey: String?),
        breakdownSource: (movimientos: [FlujoMotorMes.Movimiento], dueños: FlujoMotorMes.Dueños)?
    ) -> CashFlowLineResult {
        let engine = side.lineas[line.id]
        let plannedAmount = planned.amount
        let hasReal = month.esPasado || month.esEnCurso
        let realAmount: Double? = hasReal ? (engine?.real ?? 0) : nil

        let difference = realAmount.map { $0 - plannedAmount }
        let differencePercent = realAmount.flatMap { real in
            plannedAmount != 0 ? (real - plannedAmount) / plannedAmount : nil
        }
        let progress: Double? = month.esEnCurso && plannedAmount > 0 ? (realAmount ?? 0) / plannedAmount : nil

        return CashFlowLineResult(
            lineID: line.id, name: line.name, isIncome: line.isIncome,
            plannedAmount: plannedAmount, realAmount: realAmount,
            difference: difference, differencePercent: differencePercent,
            progress: progress, isOverride: planned.isOverride,
            estimationMethod: line.method,
            subcategoryBreakdown: hasReal ? breakdownSource.flatMap {
                subcategoryBreakdown(line: line, movimientos: $0.movimientos, dueños: $0.dueños)
            } : nil,
            isPlannedApproximate: planned.isApproximate,
            amountChangeFromMonthKey: planned.changeFromMonthKey,
            datedAmount: engine?.fechado ?? 0,
            pendingAmount: engine?.pendiente ?? 0,
            leftAmount: engine?.falta ?? 0,
            isExceeded: engine?.excedida ?? false
        )
    }

    /// Lo real de cada subcategoría de una línea por categoría (sus visibles y «sin subcategoría» si hay algo), para que
    /// el detalle llegue siempre a subcategoría. Con el mismo reparto de dueños que su real, así que suma lo mismo: lo
    /// de una subcategoría con línea propia no es suyo, y lo de un pago sin línea sí.
    private static func subcategoryBreakdown(
        line: CashFlowLine, movimientos: [FlujoMotorMes.Movimiento], dueños: FlujoMotorMes.Dueños
    ) -> [SubcategoryLineResult]? {
        guard line.subcategory == nil, let category = line.category else { return nil }
        var bySub: [PersistentIdentifier?: Double] = [:]
        for mov in movimientos where mov.esIngreso == line.isIncome {
            guard case .linea(let owner) = dueños.dueño(
                esIngreso: mov.esIngreso, categoriaID: mov.categoriaID, subcategoriaID: mov.subcategoriaID,
                pagoID: mov.pagoID
            ), owner == line.id else { continue }
            bySub[mov.categoriaID == category.persistentModelID ? mov.subcategoriaID : nil, default: 0] += mov.importe
        }
        guard !bySub.isEmpty else { return nil }
        var items: [SubcategoryLineResult] = (category.subcategories ?? [])
            .filter { $0.isVisible || bySub[$0.persistentModelID] != nil }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { sub in
                guard let real = bySub[sub.persistentModelID] else { return nil }
                return SubcategoryLineResult(subcategoryName: sub.name, plannedAmount: 0, realAmount: real)
            }
        if let without = bySub[nil], abs(without) > 0.000_5 {
            items.append(SubcategoryLineResult(subcategoryName: L10n.Report.noSubcategory, plannedAmount: 0,
                                               realAmount: without))
        }
        return items.isEmpty ? nil : items
    }

    /// Lo planeado para un mes, en el orden de L18-8: el ajuste de ese mes, el último cambio «desde este mes» igual o
    /// anterior, y si no hay ninguno, el método de la línea. Lo usan la fila de cada mes y la ordenación de las líneas,
    /// para que las dos digan el mismo número.
    ///
    /// Un método que mira la historia (promedios, último mes, tendencia) la mira desde `currentMonthStart` en el mes en
    /// curso y en todos los que vienen: solo meses completos, y el mismo límite para todos (hallazgos 8 y 9 del
    /// replanteo; antes el mes a medias entraba en el promedio de diciembre y el límite cambiaba solo cada mes). Un mes
    /// cerrado conserva el suyo.
    static func resolvePlanned(
        line: CashFlowLine, monthKey: String, monthDate: Date,
        currentMonthStart: Date,
        index: TransactionIndex,
        currencyCode: String, converter: any CurrencyConverting,
        calendar: Calendar
    ) -> (amount: Double, isApproximate: Bool, isOverride: Bool, changeFromMonthKey: String?) {
        if let override = line.monthOverride(for: monthKey) {
            return (override.amount, false, true, nil)
        }
        if let change = CashFlowAmountChangeLogic.change(for: monthKey, in: line.amountChanges) {
            return (change.amount, false, false, change.monthKey)
        }
        let estimate = estimatePlanned(
            line: line, monthDate: monthDate, historyReference: min(monthDate, currentMonthStart), index: index,
            currencyCode: currencyCode, converter: converter, calendar: calendar
        )
        return (estimate.amount, estimate.isApproximate, false, nil)
    }

    // MARK: - Lookup (subcategory → category fallback)

    static func lookupTotal(line: CashFlowLine, index: TransactionIndex, monthKey: String) -> Double {
        if let byLine = index.byLineMonth {
            return byLine[line.id]?[monthKey] ?? 0
        }
        if let subID = line.subcategory?.persistentModelID {
            return index.subcategoryTotal(for: subID, monthKey: monthKey)
        } else if let catID = line.category?.persistentModelID {
            return index.total(for: catID, monthKey: monthKey)
        }
        return 0
    }

    // MARK: - Estimation Methods

    /// Importe planificado + si salió de una tasa aproximada. Solo la rama `.scheduled` convierte:
    /// las demás leen el `TransactionIndex`, que ya está en `currencyCode`.
    private static func estimatePlanned(
        line: CashFlowLine, monthDate: Date, historyReference: Date,
        index: TransactionIndex,
        currencyCode: String, converter: any CurrencyConverting,
        calendar: Calendar
    ) -> (amount: Double, isApproximate: Bool) {
        if line.method == .scheduled, let payment = line.scheduledPayment {
            let estimate = estimateScheduled(
                payment: payment, monthDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
            return (estimate.amount, estimate.isApproximate)
        }
        return (
            estimatePlannedAmount(line: line, monthDate: historyReference, index: index, calendar: calendar),
            false
        )
    }

    /// Rama sin conversión. `.scheduled` con pago vivo NO llega aquí: lo resuelve `estimatePlanned`.
    private static func estimatePlannedAmount(
        line: CashFlowLine, monthDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        switch line.method {
        case .average3m:
            return estimateAverage(months: 3, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .average6m:
            return estimateAverage(months: 6, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .average12m:
            return estimateAverage(months: 12, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .lastMonth:
            return estimateLastMonth(line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .manual:
            return line.manualAmount ?? 0
        case .scheduled:
            // Con pago, `estimatePlanned` ya salió antes por la ruta que convierte.
            return line.manualAmount ?? 0
        case .trend:
            return estimateTrend(line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .custom:
            return estimateCustom(customMonths: line.customMonths, line: line, index: index, calendar: calendar)
        }
    }

    // MARK: - Average Estimation

    /// Cómo sale el límite de una línea por un método que mira la historia: el monto, los meses que entraron y los que
    /// se dejaron fuera por aislados (decisión de Jürgen del 19-nov-2026: «a veces son súper claros y arruinan la
    /// media»). Los aislados se buscan en los 6 meses anteriores (12 con «Promedio 12 meses») con
    /// `FlujoProyeccionInteligente.mesesAislados`, y cada método mira su ventana sin ellos. `excludesIsolated: false` es
    /// la regla de antes (la usa la migración de las líneas sembradas por P4).
    struct LimitEstimate: Equatable {
        let method: EstimationMethod
        let amount: Double
        /// Los meses que entraron en la cifra, del más reciente al más antiguo.
        let usedMonths: [Date]
        /// Los meses de la ventana del método que se dejaron fuera por aislados, del más reciente al más antiguo.
        let isolatedMonths: [Date]
    }

    static func explainEstimate(
        method: EstimationMethod, line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar, excludesIsolated: Bool = true
    ) -> LimitEstimate {
        let empty = LimitEstimate(method: method, amount: 0, usedMonths: [], isolatedMonths: [])
        guard line.subcategory != nil || line.category != nil else { return empty }
        let detection = method == .average12m ? 12 : 6
        var totals: [Date: Double] = [:]
        var monthsBack: [Date] = []
        for offset in 1...detection {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            monthsBack.append(month)
            totals[month] = lookupTotal(line: line, index: index, monthKey: monthKey(for: month, calendar: calendar))
        }
        let isolated = excludesIsolated ? FlujoProyeccionInteligente.mesesAislados(totals) : []

        switch method {
        case .average3m, .average6m, .average12m:
            let window = Array(monthsBack.prefix(method == .average3m ? 3 : method == .average6m ? 6 : 12))
            let used = window.filter { !isolated.contains($0) && (totals[$0] ?? 0) > 0 }
            let total = used.reduce(0.0) { $0 + (totals[$1] ?? 0) }
            return LimitEstimate(
                method: method, amount: used.isEmpty ? 0 : total / Double(used.count),
                usedMonths: used, isolatedMonths: window.filter(isolated.contains)
            )
        case .lastMonth:
            // El último mes que no fue aislado (si el mes pasado lo fue, el anterior).
            guard let chosen = monthsBack.first(where: { !isolated.contains($0) }) ?? monthsBack.first else {
                return empty
            }
            let skipped = monthsBack.prefix { $0 != chosen }
            return LimitEstimate(
                method: method, amount: totals[chosen] ?? 0, usedMonths: [chosen], isolatedMonths: Array(skipped)
            )
        case .trend:
            // Regresión lineal sobre los 6 meses (x = 0 el más antiguo), sin los aislados, proyectada al mes siguiente.
            let points: [(month: Date, x: Double, y: Double)] = monthsBack.prefix(6).enumerated().compactMap { i, month in
                guard !isolated.contains(month) else { return nil }
                return (month, Double(5 - i), totals[month] ?? 0)
            }
            let isolatedInWindow = monthsBack.prefix(6).filter(isolated.contains)
            guard points.count >= 2 else {
                return LimitEstimate(method: method, amount: 0, usedMonths: points.map(\.month),
                                     isolatedMonths: isolatedInWindow)
            }
            let n = Double(points.count)
            let sumX = points.reduce(0.0) { $0 + $1.x }
            let sumY = points.reduce(0.0) { $0 + $1.y }
            let sumXY = points.reduce(0.0) { $0 + $1.x * $1.y }
            let sumX2 = points.reduce(0.0) { $0 + $1.x * $1.x }
            let denominator = n * sumX2 - sumX * sumX
            let amount: Double
            if denominator == 0 {
                amount = sumY / n
            } else {
                let m = (n * sumXY - sumX * sumY) / denominator
                let b = (sumY - m * sumX) / n
                amount = max(0, m * 6 + b)
            }
            return LimitEstimate(method: method, amount: amount, usedMonths: points.map(\.month),
                                 isolatedMonths: isolatedInWindow)
        default:
            return empty
        }
    }

    static func estimateAverage(
        months: Int, line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        let method: EstimationMethod = months <= 3 ? .average3m : months >= 12 ? .average12m : .average6m
        return explainEstimate(
            method: method, line: line, referenceDate: referenceDate, index: index, calendar: calendar
        ).amount
    }

    /// Category-based average (used by calculateOtherExpenses)
    static func estimateAverage(
        months: Int, category: Category?, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard let catID = category?.persistentModelID else { return 0 }

        var total: Double = 0
        var monthCount = 0

        for offset in 1...months {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let key = Self.monthKey(for: monthStart, calendar: calendar)
            let amount = index.total(for: catID, monthKey: key)
            if amount > 0 {
                total += amount
                monthCount += 1
            }
        }

        return monthCount > 0 ? total / Double(monthCount) : 0
    }

    // MARK: - Last Month Estimation

    static func estimateLastMonth(
        line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        explainEstimate(method: .lastMonth, line: line, referenceDate: referenceDate, index: index, calendar: calendar)
            .amount
    }

    // MARK: - Scheduled Estimation

    /// Importe del pago en el mes, **convertido a la divisa del plan** (`currencyCode`).
    static func estimateScheduled(
        payment: ScheduledPayment, monthDate: Date,
        currencyCode: String, converter: any CurrencyConverting,
        calendar: Calendar
    ) -> ScheduledPaymentAmountConversion.Result {
        let params = payment.dateCalculatorParams
        let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: params, month: monthDate, calendar: calendar
        )
        guard !dates.isEmpty else { return .init(amount: 0, isApproximate: false) }
        let perPayment = ScheduledPaymentAmountConversion.magnitude(
            of: payment, in: currencyCode, converter: converter
        )
        return .init(amount: perPayment.amount * Double(dates.count), isApproximate: perPayment.isApproximate)
    }

    // MARK: - Trend Estimation (Linear Regression)

    static func estimateTrend(
        line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        explainEstimate(method: .trend, line: line, referenceDate: referenceDate, index: index, calendar: calendar)
            .amount
    }

    // MARK: - Custom Estimation

    static func estimateCustom(
        customMonths: [String], line: CashFlowLine,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard (line.subcategory != nil || line.category != nil), !customMonths.isEmpty else { return 0 }

        var total: Double = 0
        var count = 0

        for monthString in customMonths {
            guard let monthDate = customMonthFormatter.date(from: monthString) else { continue }
            let key = Self.monthKey(for: monthDate, calendar: calendar)
            total += lookupTotal(line: line, index: index, monthKey: key)
            count += 1
        }

        return count > 0 ? total / Double(count) : 0
    }

    // MARK: - Sort Lines by Amount (grouped by category)

    /// Groups subcategory lines under their parent category, sorts categories by
    /// their top line amount (descending), then sorts lines within each group by amount.
    private static func sortLinesByAmountGrouped(
        _ lines: [CashFlowLine],
        monthKey: String, monthDate: Date, currentMonthStart: Date,
        index: TransactionIndex,
        currencyCode: String, converter: any CurrencyConverting,
        calendar: Calendar
    ) -> [CashFlowLine] {
        // Pre-compute amounts once per line (O(n)) to avoid redundant calls during sort
        let amounts: [UUID: Double] = Dictionary(uniqueKeysWithValues: lines.map { line in
            let amt = resolvePlanned(
                line: line, monthKey: monthKey, monthDate: monthDate, currentMonthStart: currentMonthStart, index: index,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            ).amount
            return (line.id, amt)
        })

        // Group by parent category persistentModelID
        var groups: [PersistentIdentifier: [CashFlowLine]] = [:]
        var ungrouped: [CashFlowLine] = []

        for line in lines {
            if let catID = line.category?.persistentModelID {
                groups[catID, default: []].append(line)
            } else {
                ungrouped.append(line)
            }
        }

        // Sort lines within each group by amount descending
        for key in groups.keys {
            groups[key]?.sort { (amounts[$0.id] ?? 0) > (amounts[$1.id] ?? 0) }
        }

        // Sort groups by their top line amount descending
        let sortedGroups = groups.values.sorted { groupA, groupB in
            let maxA = groupA.lazy.compactMap { amounts[$0.id] }.max() ?? 0
            let maxB = groupB.lazy.compactMap { amounts[$0.id] }.max() ?? 0
            return maxA > maxB
        }

        // Flatten: grouped lines first, then ungrouped sorted by amount
        var result: [CashFlowLine] = []
        for group in sortedGroups {
            result.append(contentsOf: group)
        }
        result.append(contentsOf: ungrouped.sorted { (amounts[$0.id] ?? 0) > (amounts[$1.id] ?? 0) })
        return result
    }
}
