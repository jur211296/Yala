//
//  EstadisticasResumenOpcionBTests.swift
//  YalaTests
//
//  Estadísticas › Resumen, opción B · Decidir (Jürgen, 23-nov-2026): el ritmo del mes de los gastos hormiga, lo que
//  queda por día de un presupuesto, el orden y el silencio de «Para decidir hoy», la parte que más baja la nota y el
//  filtro de Registros por comercio.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Ritmo del mes de los gastos hormiga

@Suite("Resumen B · ritmo de los gastos hormiga")
struct ResumenBRitmoHormigaTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }

    /// 23 de noviembre de 2026 (noviembre tiene 30 días).
    private var dia23: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 10)) ?? Date()
    }

    @Test("«Este mes» en curso: lo gastado hasta hoy llevado al mes entero")
    func esteMes_cierraElMes() {
        let pace = AntExpensesPaceLogic.pace(total: 230, period: .thisMonth, countedDays: 23, now: dia23, calendar: calendar)
        #expect(pace == .closesMonth(300))
    }

    @Test("«Este mes» con menos de tres días no estima: un café el día 1 no es un ritmo")
    func esteMes_pocosDias_noEstima() {
        let dia2 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10)) ?? Date()
        #expect(AntExpensesPaceLogic.pace(total: 20, period: .thisMonth, countedDays: 2, now: dia2, calendar: calendar) == nil)
    }

    @Test("El último día del mes el total YA es el del mes: no hay estimación")
    func esteMes_ultimoDia_noEstima() {
        let dia30 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 10)) ?? Date()
        #expect(AntExpensesPaceLogic.pace(total: 300, period: .thisMonth, countedDays: 30, now: dia30, calendar: calendar) == nil)
    }

    @Test("Un período corto (semana) se lleva a 30 días")
    func semana_alMes() {
        let pace = AntExpensesPaceLogic.pace(total: 70, period: .last7Days, countedDays: 7, now: dia23, calendar: calendar)
        #expect(pace == .perMonth(300))
    }

    @Test("Un mes cerrado no estima: su total es el del mes")
    func mesPasado_noEstima() {
        #expect(AntExpensesPaceLogic.pace(total: 300, period: .lastMonth, countedDays: 31, now: dia23, calendar: calendar) == nil)
        #expect(AntExpensesPaceLogic.pace(total: 300, period: .last30Days, countedDays: 30, now: dia23, calendar: calendar) == nil)
    }

    @Test("Más de 31 días: el equivalente mensual de siempre")
    func anio_alMes() {
        let pace = AntExpensesPaceLogic.pace(total: 3650, period: .thisYear, countedDays: 365, now: dia23, calendar: calendar)
        #expect(pace == .perMonth(300))
    }

    @Test("InsightsCalculator rellena el ritmo de «Este mes» en curso")
    func insightsCalculator_rellenaElRitmo() {
        let mes = DateInterval(
            start: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)) ?? Date(),
            end: calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23, minute: 59, second: 59)) ?? Date()
        )
        let pace = AntExpensesPaceLogic.pace(
            total: 46, period: .thisMonth, countedDays: DateIntervalDayCount.days(in: mes, calendar: calendar),
            now: dia23, calendar: calendar)
        // 46 en 23 días → 2 al día → 60 en los 30 de noviembre.
        #expect(pace == .closesMonth(60))
    }
}

// MARK: - Lo que queda por día de un presupuesto

@Suite("Resumen B · lo que queda por día")
struct ResumenBPorDiaTests {

    @Test("Lo que queda entre los días que faltan, hoy incluido")
    func porDia() {
        let budget = ResumenPresupuesto(name: "Restaurantes", spent: 460, limit: 500, daysRemaining: 8, periodEnd: nil,
                                        currencyCode: "PEN")
        #expect(budget.remaining == 40)
        #expect(budget.perDay == 5)
        #expect(budget.usagePercent == 92)
    }

    @Test("Sin nada por gastar, o fuera de su período, no hay cifra por día")
    func sinCifra() {
        let agotado = ResumenPresupuesto(name: "A", spent: 500, limit: 500, daysRemaining: 8, periodEnd: nil, currencyCode: "PEN")
        #expect(agotado.perDay == nil)
        let pasado = ResumenPresupuesto(name: "B", spent: 600, limit: 500, daysRemaining: 8, periodEnd: nil, currencyCode: "PEN")
        #expect(pasado.perDay == nil)
        #expect(pasado.isOver)
        let cerrado = ResumenPresupuesto(name: "C", spent: 100, limit: 500, daysRemaining: -1, periodEnd: nil, currencyCode: "PEN")
        #expect(cerrado.perDay == nil)
    }

    @Test("Los días que faltan los cuenta la misma pieza que Planificación (hoy cuenta)")
    func diasComoPlanificacion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59, second: 59)) ?? Date()
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9)) ?? Date()
        let days = BudgetPeriodInterval.summaryDaysRemaining(now: now, in: DateInterval(start: start, end: end), calendar: calendar)
        #expect(days == 8)
    }
}

// MARK: - «Para decidir hoy»: orden y silencio

@Suite("Resumen B · Para decidir hoy")
struct ResumenBDecidirTests {

    private func presupuesto(_ name: String, spent: Double, limit: Double = 100, days: Int = 8) -> ResumenPresupuesto {
        ResumenPresupuesto(name: name, spent: spent, limit: limit, daysRemaining: days, periodEnd: nil, currencyCode: "PEN")
    }

    private func entrada(
        budgets: [ResumenPresupuesto] = [],
        toPay: Double = 0,
        toPayCount: Int = 0,
        variation: Double? = nil,
        includesToday: Bool = true,
        showsBudgets: Bool = true,
        showsVariations: Bool = true
    ) -> ResumenDecidirEntrada {
        ResumenDecidirEntrada(
            periodIncludesToday: includesToday,
            budgets: budgets,
            showsBudgets: showsBudgets,
            toPayAmount: toPay,
            toPayCount: toPayCount,
            toPayUntil: nil,
            dailyAverage: 210,
            dailyVariation: variation,
            showsVariations: showsVariations
        )
    }

    @Test("Sin nada que pida atención, el bloque se calla")
    func silencio() {
        let tranquilo = entrada(budgets: [presupuesto("Súper", spent: 40)], toPay: 0, variation: 3)
        #expect(ResumenDecidirLogic.actions(tranquilo).isEmpty)
    }

    @Test("Un período cerrado no pide decidir nada hoy")
    func periodoCerrado_silencio() {
        let cerrado = entrada(budgets: [presupuesto("Súper", spent: 150)], toPay: 400, toPayCount: 2, variation: 30,
                              includesToday: false)
        #expect(ResumenDecidirLogic.actions(cerrado).isEmpty)
    }

    @Test("El orden: pasado → ≥ 90 % → lo que falta pagar → 80–90 % → gasto diario; tres como mucho")
    func orden() {
        let todo = entrada(
            budgets: [presupuesto("Ropa", spent: 85), presupuesto("Restaurantes", spent: 92), presupuesto("Taxi", spent: 120)],
            toPay: 420, toPayCount: 5, variation: 8
        )
        let kinds = ResumenDecidirLogic.actions(todo).map(\.kind)
        #expect(kinds == [.budgetOver("Taxi"), .budgetAtRisk("Restaurantes"), .toPay])
    }

    @Test("Con hueco, entran el presupuesto 80–90 % y la subida del gasto diario")
    func huecos() {
        let dos = entrada(budgets: [presupuesto("Ropa", spent: 85)], toPay: 0, variation: 8)
        #expect(ResumenDecidirLogic.actions(dos).map(\.kind) == [.budgetAtRisk("Ropa"), .spendingUp])
    }

    @Test("Bajo el 80 % un presupuesto no es acción; una subida menor al 5 % tampoco")
    func umbrales() {
        let justo = entrada(budgets: [presupuesto("Ropa", spent: 79.9)], variation: 4.9)
        #expect(ResumenDecidirLogic.actions(justo).isEmpty)
        let enElBorde = entrada(budgets: [presupuesto("Ropa", spent: 80)], variation: 5)
        #expect(ResumenDecidirLogic.actions(enElBorde).map(\.kind) == [.budgetAtRisk("Ropa"), .spendingUp])
    }

    @Test("Gastar justo el límite no es pasarse: sale como riesgo, no como «te pasaste»")
    func justoElLimite() {
        let justo = entrada(budgets: [presupuesto("Ropa", spent: 100)])
        #expect(ResumenDecidirLogic.actions(justo).map(\.kind) == [.budgetAtRisk("Ropa")])
    }

    @Test("Los ajustes de Smart Insights apagan su acción")
    func ajustes() {
        let sinPresupuestos = entrada(budgets: [presupuesto("Taxi", spent: 120)], showsBudgets: false)
        #expect(ResumenDecidirLogic.actions(sinPresupuestos).isEmpty)
        let sinVariaciones = entrada(variation: 40, showsVariations: false)
        #expect(ResumenDecidirLogic.actions(sinVariaciones).isEmpty)
    }

    @Test("Un presupuesto fuera de su período (único que acabó o aún no empieza) no pide nada")
    func presupuestoFueraDePeriodo() {
        let fuera = entrada(budgets: [presupuesto("Viaje", spent: 150, days: -1), presupuesto("Feria", spent: 95, days: 0)])
        #expect(ResumenDecidirLogic.actions(fuera).isEmpty)
    }

    @Test("La subida del gasto diario lleva la marca «≈» de su promedio, como la celda de «Tus cifras»")
    func marcaAproximado() {
        var aprox = entrada(variation: 10)
        aprox.dailyAverageIsApproximate = true
        #expect(ResumenDecidirLogic.actions(aprox).first?.isApproximate == true)
        #expect(ResumenDecidirLogic.actions(entrada(variation: 10)).first?.isApproximate == false)
    }

    @Test("Cada acción lleva a su sitio")
    func destinos() {
        let todo = entrada(budgets: [presupuesto("Taxi", spent: 120)], toPay: 100, toPayCount: 1, variation: 10)
        #expect(ResumenDecidirLogic.actions(todo).map(\.destination) == [.budgets, .scheduledPayments, .trends])
    }
}

// MARK: - La parte que más baja la nota

@Suite("Resumen B · lo que más baja la nota")
struct ResumenBSaludTests {

    @Test("Es la parte que más sube el total si llegara a 100 (la del paso del Panel), no siempre la más baja")
    func laQueMasPesa() {
        // Presupuestos 80 (peso 0,32 → 6,4 puntos) frente a Ritmo 75 (peso 0,20 → 5): baja más Presupuestos.
        let score = FinancialScore(total: 79, budget: 80, activity: 75, bills: 95)
        #expect(ResumenSaludLogic.loweringPart(score) == .budget)
        #expect(ResumenSaludLogic.loweringPart(score) == FinancialScoreCalculator.weakestPart(of: score))
    }

    @Test("Con todas en 90 o más no hay nada que la baje; sin nota, tampoco")
    func nada() {
        #expect(ResumenSaludLogic.loweringPart(FinancialScore(total: 95, budget: 92, activity: 100, bills: 90)) == nil)
        #expect(ResumenSaludLogic.loweringPart(FinancialScore(total: nil, budget: 40, activity: nil, bills: nil)) == nil)
    }

    @Test("«Lo que te queda» también puede ser la que más baja")
    func teQueda() {
        let score = FinancialScore(total: 80, budget: 95, activity: 100, bills: 95, savings: 50)
        #expect(ResumenSaludLogic.loweringPart(score) == .savings)
    }
}

// MARK: - Registros filtrados por comercio

@MainActor
@Suite("Resumen B · Registros por comercio", .serialized)
struct ResumenBFiltroComercioTests {

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

    private func tx(_ amount: Double, _ note: String?, day: Int) -> TransactionItem {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)) ?? Date()
        return TransactionItem(
            date: date, amount: amount, currencyCode: "PEN", note: note,
            category: comida, account: cuenta,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    @Test("Deja solo los registros del comercio, con la misma clave que agrupa los gastos hormiga")
    func soloElComercio() throws {
        let cafe1 = tx(-8, "Starbucks", day: 3)
        let cafe2 = tx(-9, "  starbucks ", day: 5)
        let taxi = tx(-12, "Uber", day: 5)
        let key = try #require(AntExpensesCalculator.groupKey(for: cafe1)?.key)
        let filter = RecordsMerchantFilter(label: "Starbucks", keys: [key])

        let groups: [(date: Date, records: [TransactionItem])] = [
            (date: cafe2.date, records: [cafe2, taxi]),
            (date: cafe1.date, records: [cafe1]),
        ]
        let filtered = RecordsMerchantFilter.applying(filter, to: groups)
        #expect(filtered.count == 2)
        #expect(filtered.flatMap(\.records).map(\.note) == ["  starbucks ", "Starbucks"])
    }

    @Test("Los días que se quedan vacíos se van")
    func diasVacios() throws {
        let taxi = tx(-12, "Uber", day: 7)
        let cafe = tx(-8, "Starbucks", day: 3)
        let key = try #require(AntExpensesCalculator.groupKey(for: cafe)?.key)
        let filtered = RecordsMerchantFilter.applying(
            RecordsMerchantFilter(label: "Starbucks", keys: [key]),
            to: [(date: taxi.date, records: [taxi]), (date: cafe.date, records: [cafe])])
        #expect(filtered.count == 1)
        #expect(filtered.first?.records.first?.note == "Starbucks")
    }

    @Test("Una unión de Yala IA filtra por todas sus grafías")
    func unionDeIA() throws {
        let a = tx(-8, "Starbucks", day: 3)
        let b = tx(-9, "STARBUCKS COFFEE", day: 4)
        let c = tx(-10, "Sbux Larco", day: 5)
        let otro = tx(-12, "Uber", day: 5)
        let keys = Set([a, b, c].compactMap { AntExpensesCalculator.groupKey(for: $0)?.key })
        #expect(keys.count == 3)
        let filtered = RecordsMerchantFilter.applying(
            RecordsMerchantFilter(label: "Starbucks", keys: keys),
            to: [(date: c.date, records: [c, otro]), (date: b.date, records: [b]), (date: a.date, records: [a])])
        #expect(filtered.flatMap(\.records).count == 3)
    }

    @Test("Sin filtro, la lista no cambia")
    func sinFiltro() {
        let taxi = tx(-12, "Uber", day: 7)
        let filtered = RecordsMerchantFilter.applying(nil, to: [(date: taxi.date, records: [taxi])])
        #expect(filtered.count == 1)
    }

    @Test("Una unión de Yala IA lleva las claves de las grafías que juntó")
    func unionLlevaClaves() {
        let groups = [
            AntExpenseGroup(key: "note:STARBUCKS", label: "Starbucks", count: 5, total: 40),
            AntExpenseGroup(key: "note:STARBUCKS COFFEE", label: "STARBUCKS COFFEE", count: 2, total: 18),
            AntExpenseGroup(key: "note:UBER", label: "Uber", count: 3, total: 36),
        ]
        let summary = AntExpensesSummary(total: 76, count: 8, groups: [groups[0], groups[2]], threshold: 20,
                                         monthlyEstimate: nil, candidates: groups)
        let ids = Dictionary(uniqueKeysWithValues: AntExpensesAILogic.orderedCandidates(summary).map { ($0.group.key, $0.id) })
        let response = AntAIResponse(
            merges: [.init(ids: [ids["note:STARBUCKS"] ?? "", ids["note:STARBUCKS COFFEE"] ?? ""])], tip: nil)
        let insight = AntExpensesAILogic.insight(from: response, summary: summary)
        #expect(insight.mergedGroups.first?.keys == ["note:STARBUCKS", "note:STARBUCKS COFFEE"])
    }
}
