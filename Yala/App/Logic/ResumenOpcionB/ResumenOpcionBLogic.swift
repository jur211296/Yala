//
//  ResumenOpcionBLogic.swift
//  Yala
//
//  Estadísticas › Resumen, opción B · Decidir (Jürgen, 23-nov-2026; propuesta en
//  `docs/propuestas/estadisticas-resumen-2-3/`). La lógica pura de los bloques nuevos: la parte que más baja la nota,
//  el ritmo del mes de los gastos hormiga, lo que queda por día de un presupuesto y qué pide «Para decidir hoy», en qué
//  orden y cuándo se calla. La vista solo pinta lo que sale de aquí.
//

import Foundation

// MARK: - Salud financiera

enum ResumenSaludLogic {
    /// La parte que más baja la nota: la misma que elige el paso del Panel (`FinancialScoreCalculator.weakestPart`, la que
    /// más sube el total si llegara a 100). `nil` sin nota o si todas van bien.
    static func loweringPart(_ score: FinancialScore) -> FinancialScoreDetailKind? {
        guard score.total != nil else { return nil }
        return FinancialScoreCalculator.weakestPart(of: score)
    }
}

// MARK: - Ritmo del mes de los gastos hormiga

/// Lo que se dice del ritmo de los gastos hormiga. Nunca con «≈»: en Yala esa marca solo dice «convertido con una tasa
/// aproximada» (decisión 31 de 2.3); la estimación la dice el texto («a este ritmo»).
enum AntExpensesPace: Equatable {
    /// «Este mes» en curso: lo gastado hasta hoy llevado al mes entero.
    case closesMonth(Double)
    /// Un período que no es un mes (más corto, o más largo): su equivalente en 30 días.
    case perMonth(Double)
}

enum AntExpensesPaceLogic {
    /// Días que tienen que haber pasado para hablar de ritmo: un café el día 1 no lo es.
    static let minElapsedDays = 3
    /// Un período de entre 28 y 31 días ya ES un mes: su total no se estima.
    static let monthLikeDays = 28...AntExpensesCalculator.monthDays

    /// - Parameters:
    ///   - total: lo que suman los gastos hormiga del período.
    ///   - countedDays: los días sobre los que se reparte el período (`PeriodSummary.dayCount`): en uno en curso, hasta
    ///     hoy incluido.
    static func pace(
        total: Double,
        period: DetailPeriod,
        countedDays: Int,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> AntExpensesPace? {
        guard total > 0, countedDays >= minElapsedDays else { return nil }
        if period == .thisMonth {
            guard let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count,
                  countedDays < daysInMonth else { return nil }
            return .closesMonth(total / Double(countedDays) * Double(daysInMonth))
        }
        guard !monthLikeDays.contains(countedDays) else { return nil }
        return .perMonth(total / Double(countedDays) * 30)
    }
}

// MARK: - Presupuestos

/// Un presupuesto tal como lo lee «Para decidir hoy»: lo gastado de su período EN CURSO (la misma cifra que
/// Planificación, `InsightsCalculator.calculateCommitments`) y los días que le quedan.
struct ResumenPresupuesto: Equatable {
    let name: String
    let spent: Double
    let limit: Double
    /// Como `BudgetSummary.daysRemaining`: -1 = cerrado, 0 = aún no empieza, > 0 = en curso (hoy cuenta).
    let daysRemaining: Int
    /// El último instante de su período; `nil` si no se conoce.
    let periodEnd: Date?
    let currencyCode: String

    var usagePercent: Double { limit > 0 ? spent / limit * 100 : 0 }
    var remaining: Double { BudgetRemainingLogic.remaining(limit: limit, spent: spent) }
    var isOver: Bool { BudgetRemainingLogic.isOver(limit: limit, spent: spent) }
    /// Lo que se puede gastar al día sin pasarse, hoy incluido. La misma pieza que la fila de Planificación.
    var perDay: Double? { BudgetRemainingLogic.perDay(remaining: remaining, daysRemaining: daysRemaining) }
    var isInProgress: Bool { daysRemaining > 0 }
}

extension ResumenPresupuesto {
    init(_ budget: BudgetAtRisk) {
        self.init(
            name: budget.name, spent: budget.spent, limit: budget.limit, daysRemaining: budget.daysRemaining,
            periodEnd: budget.periodEnd, currencyCode: budget.currencyCode)
    }
}

// MARK: - Para decidir hoy

struct ResumenDecidirEntrada {
    /// El período elegido llega a hoy. En uno cerrado no hay nada que decidir HOY y el bloque se calla.
    var periodIncludesToday: Bool
    var budgets: [ResumenPresupuesto]
    /// Ajustes › Smart Insights › presupuestos en riesgo.
    var showsBudgets: Bool
    /// Lo que falta pagar del período, ya con los ajustes de pagos y suscripciones aplicados.
    var toPayAmount: Double
    var toPayCount: Int
    var toPayUntil: Date?
    var dailyAverage: Double
    /// El promedio diario lleva «≈» (algún gasto con tasa aproximada): la acción lo pinta con la misma marca que su
    /// celda en «Tus cifras» (`ApproximateMarkThreshold`, regla del revisor del 24-nov).
    var dailyAverageIsApproximate: Bool = false
    /// La variación del gasto diario frente al período anterior, en porcentaje (8 = 8 % más).
    var dailyVariation: Double?
    /// Ajustes › Mostrar variaciones.
    var showsVariations: Bool
}

enum ResumenDestino: Equatable {
    case budgets
    case scheduledPayments
    case trends
}

struct ResumenAccion: Equatable, Identifiable {
    enum Kind: Equatable {
        case budgetOver(String)
        case budgetAtRisk(String)
        case toPay
        case spendingUp
    }

    let kind: Kind
    /// Presupuestos: el que pide la acción. Las demás, `nil`.
    var budget: ResumenPresupuesto? = nil
    var amount: Double = 0
    var count: Int = 0
    var until: Date? = nil
    var percent: Double = 0
    /// `amount` lleva «≈»: hoy solo el promedio diario de `.spendingUp`.
    var isApproximate: Bool = false

    var id: String {
        switch kind {
        case .budgetOver(let name): return "over:" + name
        case .budgetAtRisk(let name): return "risk:" + name
        case .toPay: return "toPay"
        case .spendingUp: return "spendingUp"
        }
    }

    var destination: ResumenDestino {
        switch kind {
        case .budgetOver, .budgetAtRisk: return .budgets
        case .toPay: return .scheduledPayments
        case .spendingUp: return .trends
        }
    }
}

enum ResumenDecidirLogic {
    /// Tres como mucho: más ya no es «decidir hoy».
    static let maxActions = 3
    /// Desde aquí un presupuesto pide atención.
    static let budgetRiskPercent = 80.0
    /// Desde aquí va por delante de lo que falta pagar.
    static let budgetHighRiskPercent = 90.0
    /// Una subida del gasto diario menor no se menciona.
    static let spendingUpPercent = 5.0

    /// Las acciones, por urgencia: un presupuesto pasado (ya no tiene vuelta este período) → uno al 90 % o más → lo que
    /// falta pagar → uno entre el 80 y el 90 % → el gasto diario que sube. Dentro de cada escalón, el más usado primero.
    /// Vacío = el bloque no se pinta.
    static func actions(_ input: ResumenDecidirEntrada) -> [ResumenAccion] {
        guard input.periodIncludesToday else { return [] }

        let live = input.showsBudgets
            ? input.budgets.filter { $0.isInProgress && $0.limit > 0 }.sorted { $0.usagePercent > $1.usagePercent }
            : []
        let over = live.filter(\.isOver).map {
            ResumenAccion(kind: .budgetOver($0.name), budget: $0, amount: -$0.remaining, until: $0.periodEnd)
        }
        let atRisk = live.filter { !$0.isOver && $0.usagePercent >= budgetRiskPercent }
        let high = atRisk.filter { $0.usagePercent >= budgetHighRiskPercent }.map { riskAction($0) }
        let medium = atRisk.filter { $0.usagePercent < budgetHighRiskPercent }.map { riskAction($0) }

        var toPay: [ResumenAccion] = []
        if input.toPayAmount > 0, input.toPayCount > 0 {
            toPay = [ResumenAccion(kind: .toPay, amount: input.toPayAmount, count: input.toPayCount, until: input.toPayUntil)]
        }

        var spending: [ResumenAccion] = []
        if input.showsVariations, let variation = input.dailyVariation, variation >= spendingUpPercent {
            spending = [ResumenAccion(
                kind: .spendingUp, amount: input.dailyAverage, percent: variation,
                isApproximate: input.dailyAverageIsApproximate)]
        }

        return Array((over + high + toPay + medium + spending).prefix(maxActions))
    }

    private static func riskAction(_ budget: ResumenPresupuesto) -> ResumenAccion {
        ResumenAccion(
            kind: .budgetAtRisk(budget.name), budget: budget, amount: budget.remaining, until: budget.periodEnd,
            percent: budget.usagePercent)
    }
}
