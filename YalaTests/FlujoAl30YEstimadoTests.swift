//
//  FlujoAl30YEstimadoTests.swift
//  YalaTests
//
//  Decisiones 30, 31 y 34 de la revisión 2.3 (9-nov-2026). Un bloque por punto del encargo:
//  1. «¿Llego a fin de mes?» tiene una sola cifra, «Al 30 de noviembre tendrías», la misma en el Panel y en el mes en
//     curso del flujo de caja, con su cuenta (hoy · entra · sale).
//  2. Real y estimado se distinguen: barra de dos tonos y las palabras «Real» y «Estimado»; «pago planificado».
//  3. El tramo punteado del widget tiene color propio y una cifra corta «Estimado S/ X al 30 nov».
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Al 30 tendrías, real y estimado (decisiones 30, 31 y 34 de 2.3)", .serialized)
struct FlujoAl30YEstimadoTests {

    // MARK: - Fixtures

    /// El caso de la revisión: el 6 de noviembre a las 15:00 en Lima, con el sueldo ya cobrado.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static var now: Date { date(2026, 11, 6, hour: 15) }

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func catalog(_ path: String) throws -> [String: String] {
        let text = try repoFile(path)
        var entries: [String: String] = [:]
        let pattern = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";"#, options: .anchorsMatchLines)
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) else { continue }
            entries[String(text[key])] = String(text[value])
        }
        return entries
    }

    private static let languages = [
        "es", "es-419", "es-AR", "es-ES", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "pt", "zh-Hans",
    ]

    private static func month(isCurrent: Bool, isPast: Bool = false, netFlow: Double) -> CashFlowMonth {
        CashFlowMonth(
            monthKey: "2026-11", date: date(2026, 11, 1), isPast: isPast, isCurrent: isCurrent,
            incomeLines: [], expenseLines: [], otherExpenses: nil, otherIncome: nil,
            totalIncome: max(netFlow, 0), totalExpense: max(-netFlow, 0), netFlow: netFlow, accumulatedBalance: nil
        )
    }

    // MARK: - 1. Una sola cifra

    /// La cifra del flujo de caja es la del Panel: las mismas cuentas (la excluida de estadísticas no suma), el mismo
    /// saldo vivo como ancla y el mismo `ProjectedFlowBuilder` hasta fin de mes. Aquí se rehace la cuenta del Panel tal
    /// como la hace `PanelViewModel.calculateTrendProjection` con Saldo, «Este mes» y sin filtro de cuentas.
    @Test func alTreintaTendrias_esLaMismaCifraQueElPanel_conSuCuenta() throws {
        let context = try makeTestContext()
        let calendar = Self.calendar
        let now = Self.now
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        let hidden = Account(name: "Ahorro aparte", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote",
                             type: "bank", excludeFromStatistics: true)
        context.insert(bank)
        context.insert(hidden)
        func tx(_ amount: Double, _ day: Date, _ account: Account) -> TransactionItem {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN")
            item.account = account
            context.insert(item)
            return item
        }
        let transactions = [
            tx(1_000, Self.date(2026, 11, 1, hour: 9), bank),
            tx(3_000, Self.date(2026, 11, 2, hour: 9), bank),   // el sueldo ya entró
            tx(-200, Self.date(2026, 11, 4, hour: 9), bank),
            tx(5_000, Self.date(2026, 11, 1, hour: 9), hidden),  // no suma en el Panel
        ]
        let rent = ScheduledPayment(
            name: "Alquiler", amount: 800, currencyCode: "PEN", transactionType: "expense",
            isRecurring: true, recurrenceType: "monthly", recurrenceInterval: 1,
            nextDueDate: Self.date(2026, 11, 20), paymentCategory: "recurring", isActive: true
        )
        rent.account = bank
        rent.createdAt = Self.date(2026, 1, 1)
        context.insert(rent)
        try context.save()

        let result = try #require(MonthEndBalanceLogic.compute(
            accounts: [bank, hidden], transactions: transactions, scheduledPayments: [rent], currencyCode: "PEN",
            includeGroups: true, adjustment: .none, converter: IdentityConverter(), context: context,
            now: now, calendar: calendar
        ))

        // La cuenta del Panel.
        let monthToDate = DateInterval(start: Self.date(2026, 11, 1), end: Self.date(2026, 11, 6, hour: 23).addingTimeInterval(3_599))
        let horizon = ProjectedFlowCalculator.horizon(for: .thisMonth, interval: monthToDate, calendar: calendar)
        let days = ProjectedFlowCalculator.futureDays(in: horizon, today: now, calendar: calendar)
        let balanceAccounts = PanelBalanceScopeLogic.accounts(
            eligible: [bank, hidden].filter { !$0.excludeFromStatistics }, includeGroups: true, selectedAccountIDs: []
        )
        let balanceTransactions = PanelBalanceScopeLogic.transactions(
            transactions, accountIDs: Set(balanceAccounts.map(\.persistentModelID))
        )
        let anchor = try #require(LiveBalanceCalculator.liveBalanceOverride(
            for: .balance, interval: monthToDate, accounts: balanceAccounts, transactions: balanceTransactions,
            preferredCurrencyCode: "PEN", asOf: now, converter: IdentityConverter()
        ))
        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: now, calendar: calendar,
                overdueWindowStart: ProjectedFlowBuilder.overdueWindowStart(today: now, calendar: calendar),
                days: days, allTransactions: transactions, countedTransactions: balanceTransactions,
                hasSessionFilters: false, scheduledPayments: [rent],
                paymentFilter: ProjectedFlowBuilder.PaymentFilter(
                    accounts: EntityFilter(included: Set(balanceAccounts.map(\.persistentModelID)))
                ),
                currencyCode: "PEN", adjustment: .none, converter: IdentityConverter()
            ),
            context: context
        )
        let panel = try #require(ProjectedFlowBuilder.chartProjection(
            metric: .balance, grouping: .day, realPoints: [], liveAnchorValue: anchor.value,
            result: built, days: days, today: now, calendar: calendar
        ))

        #expect(abs(result.today - 3_800) < 0.001, "Tienes hoy: el banco, sin la cuenta excluida")
        #expect(abs(result.today - anchor.value) < 0.001)
        #expect(abs(result.closing - panel.closingValue) < 0.001, "La misma cifra que «Ver proyectado» del Panel")
        #expect(abs(result.closing - (result.today + result.incomeLeft - result.expenseLeft)) < 0.001)
        #expect(result.expenseLeft >= 800 - 0.001, "El alquiler del 20 falta salir")
        #expect(result.endDate == Self.date(2026, 11, 30))
        #expect(panel.endDate == result.endDate, "El Panel nombra la misma fecha")
        #expect(panel.metric == .balance)
    }

    /// Con plan, lo que falta sale del plan, como en el Panel sin filtros (respuesta 10A de «Ver proyectado»): si esta
    /// pieza se creyera con filtros, mandaría el ritmo y la cifra dejaría de ser la del Panel. El plan lee el reloj por
    /// dentro (`CashFlowProjectionCalculator`), así que este caso usa el «hoy» real, como `ProjectedFlowBuilderPlanTests`.
    @Test func conPlan_loQueFaltaSaleDelPlan_comoEnElPanel() throws {
        let context = try makeTestContext()
        let calendar = Calendar.current
        let now = Date.now
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        let days = ProjectedFlowCalculator.futureDays(
            in: DateInterval(start: month.start, end: month.end.addingTimeInterval(-1)), today: now, calendar: calendar
        )
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        let opening = TransactionItem(date: month.start, amount: 2_000, currencyCode: "PEN")
        opening.account = bank
        context.insert(opening)
        let plan = CashFlowPlan(name: "Plan")
        context.insert(plan)
        let line = CashFlowLine(name: "Gastos", isIncome: false, estimationMethod: .manual, manualAmount: 600)
        line.plan = plan
        context.insert(line)
        try context.save()

        let result = try #require(MonthEndBalanceLogic.compute(
            accounts: [bank], transactions: [opening], scheduledPayments: [], currencyCode: "PEN",
            includeGroups: true, adjustment: .none, converter: IdentityConverter(), context: context,
            now: now, calendar: calendar
        ))
        #expect(abs(result.today - 2_000) < 0.001)
        #expect(abs(result.closing - (result.today + result.incomeLeft - result.expenseLeft)) < 0.001)
        // El último día del mes ya no queda nada por delante: no hay plan que repartir.
        if !days.isEmpty {
            #expect(result.source == .plan, "Sin filtros, lo que falta sale del plan, como en el Panel")
            #expect(result.expenseLeft > 0.001)
        }
    }

    /// El mes en curso abre con «Al 30 de noviembre tendrías», no con lo que entra menos lo que sale; los demás meses
    /// siguen con su neto, ya sin «te sobran».
    @Test func elMesEnCurso_diceAlTreintaTendrias_yLosDemasSuNeto() {
        let end = Self.date(2026, 11, 30)
        let current = Self.month(isCurrent: true, netFlow: 396.18)
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: current, monthEndDate: end)
            == L10n.ProjectedFlow.closingBalance(MonthEndBalanceLogic.dayAndMonth(end)))
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: current, monthEndDate: end)
            != CashFlowMonthSummaryLogic.netLabel(for: current))
        // Sin cuentas que sumen, la cabecera de antes.
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: current, monthEndDate: nil)
            == CashFlowMonthSummaryLogic.netLabel(for: current))
        // Otro mes no usa la fecha aunque se la pasen.
        let past = Self.month(isCurrent: false, isPast: true, netFlow: 120)
        #expect(CashFlowMonthSummaryLogic.heroLabel(for: past, monthEndDate: end) == CashFlowMonthSummaryLogic.netLabel(for: past))
    }

    @Test func dayAndMonth_llevaElAnioSoloSiNoEsElDeHoy() {
        let es = Locale(identifier: "es")
        #expect(MonthEndBalanceLogic.dayAndMonth(Self.date(2026, 11, 30), now: Self.now, calendar: Self.calendar, locale: es)
            == "30 de noviembre")
        #expect(MonthEndBalanceLogic.dayAndMonth(Self.date(2027, 5, 31), now: Self.now, calendar: Self.calendar, locale: es)
            .contains("2027"))
    }

    /// Los textos: «Proyectado al cierre» desaparece en los 16 idiomas, y el mes deja de decir «te sobran».
    @Test func losTextos_nombranLaMetricaYLaFecha_yNoDicenTeSobra() throws {
        for language in Self.languages {
            let strings = try Self.catalog("Yala/Resources/\(language).lproj/Localizable.strings")
            #expect(strings["trend.projected.closing"] == nil, "\(language): «Proyectado al cierre» sigue")
            for key in ["trend.projected.closing.balance", "trend.projected.closing.expense", "trend.projected.closing.income"] {
                #expect(strings[key]?.contains("%@") == true, "\(language): falta \(key) o su fecha")
            }
            for key in ["cashflow.monthEnd.leftIn", "cashflow.monthEnd.leftOut", "cashFlowPlan.estimateLeft"] {
                #expect(strings[key]?.isEmpty == false, "\(language): falta \(key)")
            }
        }
        let es = try Self.catalog("Yala/Resources/es-419.lproj/Localizable.strings")
        #expect(es["trend.projected.closing.balance"] == "Al %@ tendrías")
        for key in ["cashflow.l18.summary.surplus", "cashflow.l18.hero.surplusThisMonth",
                    "cashflow.l18.hero.surplusFuture", "cashflow.l18.hero.surplusPast"] {
            #expect(es[key]?.contains("sobr") == false, "\(key) sigue diciendo «te sobra»")
        }
    }

    // MARK: - 2. Real y estimado

    @Test func laBarra_pintaRealSolidoYLoQueFaltaRayado_soloEnElMesEnCurso() throws {
        let segments = try #require(CashFlowRealEstimateBarLogic.segments(real: 463, planned: 1_760, isCurrentMonth: true))
        #expect(abs(segments.real - 463.0 / 1_760) < 0.0001)
        #expect(abs(segments.real + segments.estimate - 1) < 0.0001)
        #expect(CashFlowRealEstimateBarLogic.segments(real: 463, planned: 1_760, isCurrentMonth: false) == nil,
                "Un mes cerrado no tiene nada estimado")
        #expect(CashFlowRealEstimateBarLogic.segments(real: 1_800, planned: 1_760, isCurrentMonth: true) == nil,
                "Una línea superada la pinta la barra de siempre, en rosa")
        #expect(CashFlowRealEstimateBarLogic.segments(real: 0, planned: 0, isCurrentMonth: true) == nil)
        let none = try #require(CashFlowRealEstimateBarLogic.segments(real: -50, planned: 100, isCurrentMonth: true))
        #expect(none.real == 0 && none.estimate == 1, "Una devolución no pinta real negativo")
    }

    @Test func lasPalabras_sonRealYEstimado_yPagoPlanificado() throws {
        let es = try Self.catalog("Yala/Resources/es-419.lproj/Localizable.strings")
        #expect(es["cashFlowPlan.real"] == "Real")
        #expect(es["cashFlowPlan.realIncome"] == "Real")
        #expect(es["cashFlowPlan.futureMonth"] == "Estimado")
        #expect(es["cashFlowPlan.plan"] == "Estimado")
        #expect(es["cashFlowPlan.estimateLeft"] == "Estimado que falta")
        #expect(es["cashFlowPlan.chartProjection"] == "Saldo estimado")
        for language in Self.languages {
            let strings = try Self.catalog("Yala/Resources/\(language).lproj/Localizable.strings")
            for (key, value) in strings where key.hasPrefix("cashFlowPlan.") {
                #expect(!value.lowercased().contains("programad"), "\(language) \(key): «\(value)»")
                #expect(!value.contains("programmé") && !value.contains("programmato"), "\(language) \(key): «\(value)»")
            }
        }
    }

    // MARK: - 3. El widget

    @Test func laCifraCortaDelWidget_esElUltimoPuntoDelTramo() {
        let anchorOnly = [(date: Self.date(2026, 11, 6), value: 100.0)]
        #expect(WidgetInsightsLogic.projectedEnd(anchorOnly) == nil, "El ancla sola no es una estimación")
        let points = [
            (date: Self.date(2026, 11, 6), value: 100.0),
            (date: Self.date(2026, 11, 7), value: 150.0),
            (date: Self.date(2026, 11, 30), value: 900.0),
        ]
        #expect(WidgetInsightsLogic.projectedEnd(points)
            == WidgetInsightsLogic.ProjectedEnd(date: Self.date(2026, 11, 30), value: 900))
    }

    /// El tramo punteado ya no comparte el color de lo real (rosa en Gasto, índigo en Saldo): va en el de lo estimado,
    /// y la cifra corta existe en los 16 idiomas con la palabra «Estimado», no «≈».
    @Test func elTramoDelWidget_tieneColorPropio_yLaCifraEnLos16Idiomas() throws {
        let estimateStroke = ".foregroundStyle(WidgetColors.estimate.opacity(WidgetDS.Chart.projectedOpacity))"
        for file in ["YalaWidgets/Widgets/ExpenseWidget.swift", "YalaWidgets/Widgets/BalanceWidget.swift"] {
            let source = try Self.repoFile(file)
            #expect(source.contains(estimateStroke), "\(file): el punteado no va en el color de lo estimado")
            #expect(!source.contains("hotPink.opacity(WidgetDS.Chart.projectedOpacity)"), "\(file)")
            #expect(!source.contains("electricIndigo.opacity(WidgetDS.Chart.projectedOpacity)"), "\(file)")
            #expect(source.contains("WidgetProjectedEndLine("), "\(file): falta la cifra corta")
        }
        for language in Self.languages {
            let strings = try Self.catalog("YalaWidgets/Resources/\(language).lproj/Localizable.strings")
            let caption = strings["widget.projected.endCaption"]
            #expect(caption?.contains("%1$@") == true && caption?.contains("%2$@") == true, "\(language)")
            #expect(caption?.contains("≈") == false, "\(language): «≈» es solo «convertido»")
        }
        let es = try Self.catalog("YalaWidgets/Resources/es-419.lproj/Localizable.strings")
        #expect(es["widget.projected.endCaption"] == "Estimado %1$@ al %2$@")
    }
}
