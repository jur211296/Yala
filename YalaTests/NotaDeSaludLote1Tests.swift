//
//  NotaDeSaludLote1Tests.swift
//  YalaTests
//
//  Lote 1 de la nota de salud (decisión de Jürgen del 11-nov-2026): honesta sin desanimar.
//   • Perfiles de ejemplo: nadie razonable baja de 70; cuando algo va mal de verdad, sí baja de 50.
//   • El mensaje de la tarjeta: siempre un paso concreto, nunca «vas mal».
//   • La salud a la vista: encendida una vez a quien tenía la lista de fábrica (opción A).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Perfiles

@Suite(.serialized)
@MainActor
struct NotaDeSaludPerfilesTests {

    private let calendar = Calendar.current

    /// Martes 17 de marzo de 2026, 12:00: día 17 de 31.
    private var now: Date { day(17) }

    private func day(_ d: Int, month: Int = 3) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12))!
    }

    private struct Perfil {
        var name: String
        var expenseDays: [Int]
        var dailyExpense: Double
        var income: Double = 3000
        var initialBalance: Double = 0
        var budgetLimits: [Double] = []
        var budgetsCreatedDay: Int = 0
        var rent: Double? = 800
        var startsDay: Int = 1
    }

    private func score(_ p: Perfil, context: ModelContext) -> FinancialScore {
        let account = makeTestAccount(context: context, name: "Principal", currencyCode: "USD")
        let food = makeTestCategory(context: context, name: "Comida")
        let salary = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        var txs: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory?, adjustment: String? = nil) {
            let t = TransactionItem(
                date: date, amount: amount, currencyCode: "USD", note: nil, category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "USD"
            )
            t.balanceAdjustmentType = adjustment
            context.insert(t)
            txs.append(t)
        }
        if p.initialBalance > 0 {
            tx(p.initialBalance, day(p.startsDay), nil, adjustment: InitialBalanceService.typeInitialBalance)
        }
        if p.income > 0 { tx(p.income, day(1), salary) }
        for d in p.expenseDays { tx(-p.dailyExpense, day(d), food) }

        let budgets = p.budgetLimits.enumerated().map { index, limit in
            let b = Budget(currencyCode: "USD", limitAmount: limit, name: "P\(index)", periodType: "monthly")
            b.createdAt = p.budgetsCreatedDay > 0 ? day(p.budgetsCreatedDay) : day(1, month: 1)
            return b
        }
        var payments: [ScheduledPayment] = []
        if let rent = p.rent {
            let payment = ScheduledPayment(
                name: "Alquiler", amount: rent, currencyCode: "USD", isRecurring: false,
                nextDueDate: day(25), isActive: true
            )
            payment.createdAt = p.startsDay > 1 ? day(p.startsDay) : day(1, month: 1)
            payments = [payment]
        }
        return FinancialScoreCalculator.calculate(
            transactions: txs, budgets: budgets, scheduledPayments: payments, accounts: [account],
            paidAmounts: [:], period: .thisMonth, preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter(), now: now, calendar: calendar
        )
    }

    private var perfiles: [Perfil] {
        let everyDay = Array(1...17)
        return [
            Perfil(name: "Constante", expenseDays: everyDay, dailyExpense: 20, budgetLimits: [680, 760]),
            Perfil(name: "A ratos", expenseDays: [1, 2, 6, 7, 12, 13], dailyExpense: 50, budgetLimits: [600, 670]),
            Perfil(name: "Deja de registrar 10 días", expenseDays: Array(1...6), dailyExpense: 40,
                   budgetLimits: [600, 800]),
            Perfil(name: "Se pasa un poco", expenseDays: everyDay, dailyExpense: 40, budgetLimits: [618, 1500]),
            Perfil(name: "Se pasa al doble en uno", expenseDays: everyDay, dailyExpense: 40,
                   budgetLimits: [340, 1500]),
            Perfil(name: "Recién empieza", expenseDays: [15, 16, 17], dailyExpense: 20, income: 0,
                   initialBalance: 1500, budgetLimits: [600], budgetsCreatedDay: 15, startsDay: 15),
            Perfil(name: "Recién empieza, sin presupuesto ni pagos", expenseDays: [15, 16, 17], dailyExpense: 20,
                   income: 0, initialBalance: 1500, rent: nil, startsDay: 15),
            Perfil(name: "Va mal de verdad", expenseDays: Array(1...5), dailyExpense: 200, income: 1500,
                   budgetLimits: [500, 667]),
        ]
    }

    @Test("Perfiles de ejemplo: ninguno razonable por debajo de 70, y el que va mal de verdad por debajo de 50")
    func perfiles_notas() throws {
        var results: [String: FinancialScore] = [:]
        for perfil in perfiles {
            let context = try makeTestContext()
            let s = score(perfil, context: context)
            results[perfil.name] = s
            print("PERFIL|\(perfil.name)|B=\(s.budget.map(String.init) ?? "-")|R=\(s.activity.map(String.init) ?? "-")"
                  + "|C=\(s.bills.map(String.init) ?? "-")|T=\(s.total.map(String.init) ?? "-")"
                  + "|\(FinancialScoreCopy.cardMessage(for: s))")
        }

        let dejo = try #require(results["Deja de registrar 10 días"])
        let doble = try #require(results["Se pasa al doble en uno"])
        for name in ["Constante", "A ratos", "Deja de registrar 10 días", "Se pasa un poco",
                     "Se pasa al doble en uno", "Recién empieza"] {
            let total = try #require(results[name]?.total, "\(name) sin nota")
            #expect(total >= 70, "\(name) quedó en \(total)")
        }
        // El hueco hasta hoy se nota (antes, 100) y el doble pesa (antes, 92) sin hundir la nota.
        #expect(dejo.activity == 44)
        #expect(doble.budget == 65)
        #expect(try #require(results["Constante"]?.total) > (try #require(doble.total)))
        // Cuando algo va mal de verdad, la nota baja de 50: el suelo ya no lo esconde.
        #expect(try #require(results["Va mal de verdad"]?.total) < 50)
        // Sin presupuesto ni pagos, sin nota: la tarjeta dice qué hacer para tenerla.
        let sinNota = try #require(results["Recién empieza, sin presupuesto ni pagos"])
        #expect(sinNota.total == nil)
        #expect(FinancialScoreCopy.cardMessage(for: sinNota) == L10n.Panel.Health.cardStartBudget)
    }
}

// MARK: - Mensaje de la tarjeta

@MainActor
struct NotaDeSaludMensajeTests {

    private func s(_ total: Int?, b: Int?, r: Int?, c: Int?) -> FinancialScore {
        FinancialScore(total: total, budget: b, activity: r, bills: c)
    }

    @Test func conNota_daElPasoDeLaParteQueMasLaSube() {
        #expect(FinancialScoreCopy.cardMessage(for: s(83, b: 100, r: 44, c: 91)) == L10n.Panel.Health.cardStepActivity)
        #expect(FinancialScoreCopy.cardMessage(for: s(79, b: 65, r: 100, c: 80)) == L10n.Panel.Health.cardStepBudget)
        #expect(FinancialScoreCopy.cardMessage(for: s(70, b: 100, r: 100, c: 30)) == L10n.Panel.Health.cardStepBills)
    }

    @Test func todoBien_diceVasBien() {
        #expect(FinancialScoreCopy.cardMessage(for: s(97, b: 100, r: 100, c: 91)) == L10n.Panel.Health.cardStepGood)
    }

    @Test func todoBienPeroConAlertas_noFelicita() {
        var score = s(100, b: 100, r: 100, c: 100)
        score.alerts = FinancialScoreAlerts(overBudgets: [], negativeAccounts: ["Cuenta Principal"])
        #expect(FinancialScoreCopy.cardMessage(for: score) == L10n.Panel.Health.totalHeadlineHighWithAlerts)
        // En «Solo gastos» una cuenta en negativo no cuenta como alerta.
        #expect(FinancialScoreCopy.cardMessage(for: score, isExpensesOnlyMode: true) == L10n.Panel.Health.cardStepGood)
    }

    @Test func sinNota_pideLoQueFaltaEmpezandoPorRegistrar() {
        #expect(FinancialScoreCopy.cardMessage(for: s(nil, b: nil, r: nil, c: nil)) == L10n.Panel.Health.cardStartActivity)
        #expect(FinancialScoreCopy.cardMessage(for: s(nil, b: nil, r: 100, c: nil)) == L10n.Panel.Health.cardStartBudget)
        #expect(FinancialScoreCopy.cardMessage(for: s(nil, b: 100, r: nil, c: nil)) == L10n.Panel.Health.cardStartActivity)
    }

    /// Ningún mensaje de la tarjeta dice que vas mal.
    @Test func ningunMensajeDesanima() {
        let messages = [
            L10n.Panel.Health.cardStepActivity, L10n.Panel.Health.cardStepBudget, L10n.Panel.Health.cardStepBills,
            L10n.Panel.Health.cardStepGood, L10n.Panel.Health.cardStartActivity, L10n.Panel.Health.cardStartBudget,
            L10n.Panel.Health.cardStartBills, L10n.Panel.Health.totalHeadlineHighWithAlerts,
        ]
        for message in messages {
            let lower = message.lowercased()
            #expect(!message.isEmpty)
            #expect(!lower.contains("vas mal") && !lower.contains("going badly") && !lower.contains("cuidado"))
        }
    }
}

// MARK: - La salud a la vista (opción A)

@MainActor
struct NotaDeSaludVisibleTests {

    private func prefs(hidden: [String], seeded: Bool = true) -> (AppPreferences, UserDefaults) {
        let defaults = makeIsolatedDefaults(prefix: "nota-salud")
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelSectionsHidden = hidden
        prefs.panelPrefsMigratedV2 = seeded
        return (prefs, defaults)
    }

    @Test func nuevaInstalacion_naceConLaSaludALaVista() {
        #expect(!PanelDefaults.hiddenSections.contains(.health))
        #expect(PanelDefaults.hiddenSectionRawValues == ["distribucion", "tools"])
    }

    @Test func listaDeFabricaAnterior_laEnciendeUnaVez() {
        let (p, defaults) = prefs(hidden: PanelDefaults.hiddenSectionsUntil22)
        PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: p, defaults: defaults)
        #expect(p.panelSectionsHidden == ["distribucion", "tools"])
        #expect(defaults.bool(forKey: PanelPreferencesMigration.healthShownOnceKey))

        // Si después la apaga a mano, no vuelve a encenderse.
        p.panelSectionsHidden = ["health", "distribucion", "tools"]
        PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: p, defaults: defaults)
        #expect(p.panelSectionsHidden == ["health", "distribucion", "tools"])
    }

    @Test func quienTocoConfigurarPanel_noSeToca() {
        for hidden in [["health", "tools"], ["distribucion", "tools", "health"], ["health"]] {
            let (p, defaults) = prefs(hidden: hidden)
            PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: p, defaults: defaults)
            #expect(p.panelSectionsHidden == hidden)
            #expect(defaults.bool(forKey: PanelPreferencesMigration.healthShownOnceKey))
        }
    }

    @Test func sinSiembraOListaVacia_noDecideTodavia() {
        let (unseeded, d1) = prefs(hidden: PanelDefaults.hiddenSectionsUntil22, seeded: false)
        PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: unseeded, defaults: d1)
        #expect(unseeded.panelSectionsHidden == PanelDefaults.hiddenSectionsUntil22)
        #expect(!d1.bool(forKey: PanelPreferencesMigration.healthShownOnceKey))

        let (empty, d2) = prefs(hidden: [])
        PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: empty, defaults: d2)
        #expect(!d2.bool(forKey: PanelPreferencesMigration.healthShownOnceKey), "la de iCloud puede no haber bajado")
    }

    @Test func elArranqueLaLlamaTrasLaSiembra() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/AppBootstrapper.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let seed = try #require(source.range(of: "PanelPreferencesMigration.runIfNeeded(appPreferences: appPreferences)"))
        let show = try #require(
            source.range(of: "PanelPreferencesMigration.showHealthOnceIfUntouched(appPreferences: appPreferences)")
        )
        #expect(seed.upperBound <= show.lowerBound)
    }
}
