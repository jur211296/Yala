//
//  MCPAppParityGoldenTests.swift
//  YalaTests / MCP
//
//  Golden de paridad del conector de Claude (`mcp/`, TypeScript) con la app.
//
//  `mcp/test/golden/app-parity.json` trae escenarios escritos a mano como FILAS DE POSTGREST —lo mismo que lee el
//  conector—. Este test las mete en SwiftData por el camino real del pull (`EntityApplyMap`) y calcula con el código
//  de producción, sin réplicas:
//
//  - saldo por cuenta: `AccountBalanceCalculator.currentBalance` (con el corte de hoy en `now`, y lo que está en otra
//    divisa convertido a la de la cuenta con la tasa de su fecha);
//  - saldo total y su «≈»: `LiveBalanceCalculator.liveBalanceBreakdown` (con el corte de hoy en `now`) sobre las cuentas
//    que cuentan (como el Panel; el chat recorta a 13 meses al leer, y el conector no);
//  - periodos y totales de recurrentes: `FullFinancialContextBuilder.buildFromArrays` (el contexto del chat, que es
//    lo que el conector porta), con `GroupBridgeStatsAdjustment.build(from:context:)`;
//  - gasto de presupuesto: `BudgetsViewModel.calculateSpending` (la pantalla de Presupuestos);
//  - ajuste de grupos por movimiento: `GroupBridgeStatsAdjustment`;
//  - el `tipo` de cada movimiento (`buscar_movimientos`): `TransactionClassificationLogic`, con transferencias y ajustes
//    de saldo aparte;
//  - conversiones sueltas: `CurrencyConverter.convertChecked(on:)`, con su escalón de filas anteriores y tabla
//    estática;
//  - Yala web, lote 2 (`shared-core/src/logic/stats.ts` y `schedule.ts`): Estadísticas › Resumen
//    (`InsightsCalculator.calculate`, con el período anterior alineado), Distribución
//    (`TopSpendingCategoriesCalculator` sobre lo que filtra `FilterService.filterForTrends`), Tendencias › Entradas y
//    salidas (`CashFlowCalculator` mes a mes) y las fechas de cobro de cada pago planificado
//    (`ScheduledPaymentDateCalculator.paymentDatesInMonth`, con `isDateSkipped` para los próximos cobros).
//
//  Dos modos:
//  - Por defecto VERIFICA: recalcula y compara con los `expected` del fichero. Si la app cambia una regla, este test
//    se pone rojo y avisa de que el conector ya no cuadra.
//  - Con `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1` en el entorno de `xcodebuild`, ESCRIBE los `expected` (y la
//    cabecera `app`). Después, `npm test` en `mcp/` dice si el TypeScript da lo mismo.
//
//  Determinismo: la app usa `Date.now` para «la tasa de hoy» y `Calendar.current` para los periodos. Por eso los
//  escenarios ponen `now` y los movimientos a las 12:00 UTC (mismo día civil de UTC−11 a UTC+11) y todas sus filas de
//  tasas en el pasado. No hay semanas en el golden: dependen de `firstWeekday`, que el servidor no conoce.
//
//  Lo que el golden NO mide, a propósito (diferencias declaradas del conector): el PERIODO de cada presupuesto (es una
//  entrada del escenario; la app termina en la medianoche del periodo siguiente, ticket
//  `budget-interval-counts-next-period-midnight`, y el conector cuenta días completos), las semanas, y un movimiento
//  de hoy posterior a `now` (el conector cuenta por días; el chat, por instantes).
//
//  Carga el JSON por `#filePath`, como `Canonc1GoldenVectorTests`: el runner no empaqueta el fichero.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("MCP · las cifras del conector de Claude cuadran con la app (golden)", .serialized)
@MainActor
struct MCPAppParityGoldenTests {

    // MARK: - Fichero

    private static var goldenURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/MCP/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
            .appendingPathComponent("mcp/test/golden/app-parity.json")
    }

    private static var writeMode: Bool {
        ProcessInfo.processInfo.environment["YALA_WRITE_MCP_GOLDENS"] == "1"
    }

    /// Tolerancia de la verificación. Los `expected` se guardan redondeados a 6 decimales.
    private static let tolerance = 1e-5

    // MARK: - Entradas

    private struct Golden: Decodable {
        let scenarios: [Scenario]
    }

    private struct Scenario: Decodable {
        let id: String
        let now: String
        let preferredCurrency: String
        let rows: [String: [[String: WireValue]]]
        let budgetPeriod: Period
        let conversions: [Conversion]
    }

    private struct Period: Decodable {
        let desde: String
        let hasta: String
    }

    private struct Conversion: Decodable {
        let amount: Double
        let from: String
        let to: String
        let dateKey: String
    }

    private enum GoldenError: Error, CustomStringConvertible {
        case bad(String)
        var description: String { if case .bad(let m) = self { return m }; return "" }
    }

    // MARK: - Test

    @Test func theConnectorGoldenMatchesTheApp() throws {
        let data = try Data(contentsOf: Self.goldenURL)
        let golden = try JSONDecoder().decode(Golden.self, from: data)
        guard var root = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any],
              var rawScenarios = root["scenarios"] as? [[String: Any]],
              rawScenarios.count == golden.scenarios.count
        else { throw GoldenError.bad("app-parity.json no tiene la forma esperada") }

        #expect(!golden.scenarios.isEmpty)

        let app = appHeader()
        var computed: [[String: Any]] = []
        for scenario in golden.scenarios {
            computed.append(try compute(scenario))
        }

        if Self.writeMode {
            root["app"] = app
            for i in rawScenarios.indices { rawScenarios[i]["expected"] = computed[i] }
            root["scenarios"] = rawScenarios
            let out = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try (out + Data("\n".utf8)).write(to: Self.goldenURL)
            return
        }

        compare(app, root["app"], path: "app")
        for (i, scenario) in golden.scenarios.enumerated() {
            guard let expected = rawScenarios[i]["expected"], !(expected is NSNull) else {
                Issue.record("[\(scenario.id)] sin expected: genera el golden con TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1")
                continue
            }
            compare(computed[i], expected, path: scenario.id)
        }
    }

    // MARK: - Cabecera: lo que el conector copia tal cual de la app

    private func appHeader() -> [String: Any] {
        let names = L10n.allLocalizedValues(forKey: "subcategory.system.loanToGroups").map { $0.lowercased() }
        return [
            "fallbackRates": CurrencyCode.fallbackRates.mapValues { round6($0) },
            "loanToGroupsNames": Array(Set(names)).sorted(),
        ]
    }

    // MARK: - Cálculo con el código de la app

    private func compute(_ scenario: Scenario) throws -> [String: Any] {
        let context = try makeTestContext()
        guard let now = ISO8601DateFormatter().date(from: scenario.now) else {
            throw GoldenError.bad("[\(scenario.id)] now no es ISO 8601")
        }

        // Orden de las referencias: primero los destinos, luego quien los apunta.
        let accounts = try apply(EntityApplyMap.account, scenario, "accounts", context)
        _ = try apply(EntityApplyMap.category, scenario, "categories", context)
        _ = try apply(EntityApplyMap.subcategory, scenario, "subcategories", context)
        let tags = try apply(EntityApplyMap.tag, scenario, "tags", context)
        _ = try apply(EntityApplyMap.exchangeRate, scenario, "exchange_rates", context)
        let txs = try apply(EntityApplyMap.transactionItem, scenario, "tx_items", context)
        let budgets = try apply(EntityApplyMap.budget, scenario, "budgets", context)
        let payments = try apply(EntityApplyMap.scheduledPayment, scenario, "scheduled_payments", context)
        try context.save()

        let converter = CurrencyConverter()
        converter.setContext(context)
        let allTx = txs.map(\.model)
        let adjustment = GroupBridgeStatsAdjustment.build(from: allTx, context: context, converter: converter)

        let chat = FullFinancialContextBuilder().buildFromArrays(
            transactions: allTx,
            budgets: [],  // `buildBudgets` usa `Date.now` para el periodo: el gasto se calcula aparte, abajo.
            accounts: accounts.map(\.model),
            tags: tags.map(\.model),
            scheduledPayments: payments.map(\.model),
            currencyCode: scenario.preferredCurrency,
            currencyDisplay: scenario.preferredCurrency,
            converter: converter,
            language: "es",
            country: "PE",
            includeAnomalies: false,
            adjustment: adjustment,
            now: now
        )

        // El saldo de HOY corta en el `now` del escenario (`LiveBalanceCalculator.TodayCutoff`): lo fechado después no
        // cuenta, como en el Panel y en la lista de cuentas.
        let live = LiveBalanceCalculator.liveBalanceBreakdown(
            // Las cuentas que suma el Panel (archivar no decide la suma, 2026-10-03), que es también lo que el
            // chat lista en `balances` y lo que porta `computeBalances` del conector.
            accounts: PanelTotalAccountsLogic.countableAccounts(accounts.map(\.model)),
            transactions: allTx,
            preferredCurrencyCode: scenario.preferredCurrency,
            asOf: now,
            converter: converter
        )

        // El saldo por cuenta que enseña la app (lista de cuentas, Panel, widgets): `AccountBalanceCalculator`, con el
        // corte de hoy. Hasta el 2026-11-05 el golden usaba `InitialBalanceService.currentBalance`, que suma todo y que
        // ninguna pantalla usa.
        var perAccount: [String: Any] = [:]
        for (id, account) in accounts {
            let balance = AccountBalanceCalculator.currentBalance(
                for: account, allTransactions: allTx, asOf: now, converter: converter)
            perAccount[id] = round6(NSDecimalNumber(decimal: balance).doubleValue)
        }

        func period(_ p: FullFinancialContext.PeriodSummary) -> [String: Any] {
            [
                "ingresos": round6(p.income),
                "gastos": round6(p.expense),
                "neto": round6(p.balance),
                "gasto_medio_diario": round6(p.dailyAvg),
                "tasa_de_ahorro_pct": p.savingsRatePercent.map { round6($0) as Any } ?? NSNull(),
                "aproximado": [
                    "ingresos": p.incomeIsApproximate,
                    "gastos": p.expenseIsApproximate,
                    "neto": p.balanceIsApproximate,
                ],
            ]
        }

        let interval = try budgetInterval(scenario.budgetPeriod)
        var spent: [String: Any] = [:]
        for (id, budget) in budgets {
            spent[id] = round6(BudgetsViewModel.calculateSpending(
                budget: budget, transactions: allTx, interval: interval, adjustment: adjustment, converter: converter))
        }

        var groups: [String: Any] = [:]
        for (id, tx) in txs where tx.splitExpenseID != nil {
            groups[id] = [
                "amount": round6(adjustment.amount(tx)),
                "amountInPreferred": round6(adjustment.amountInPreferredCurrency(tx)),
                "suppressed": adjustment.isSuppressed(tx),
            ]
        }

        // El `tipo` de `buscar_movimientos`, con las reglas de la app: la pata de transferencia es transferencia (como
        // `TransactionDetailSheetLogic.kind`), otro ajuste de saldo es ajuste, y el resto decide
        // `TransactionClassificationLogic` (sin categoría, el signo).
        var kinds: [String: Any] = [:]
        for (id, tx) in txs {
            if tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer || tx.transferPairID != nil {
                kinds[id] = "transferencia"
            } else if tx.balanceAdjustmentType != nil {
                kinds[id] = "ajuste_de_saldo"
            } else {
                kinds[id] = TransactionClassificationLogic.isIncome(tx) ? "ingreso" : "gasto"
            }
        }

        var conversions: [Any] = []
        for c in scenario.conversions {
            guard let day = dayStartUTC(c.dateKey) else { throw GoldenError.bad("[\(scenario.id)] dateKey \(c.dateKey)") }
            let out = converter.convertChecked(
                Decimal(c.amount), from: c.from, to: c.to, on: day.addingTimeInterval(12 * 3600))
            let quality: String
            switch out.quality {
            case .exact: quality = "exact"
            case .carriedForward: quality = "carried"
            case .staticFallback: quality = "static"
            }
            conversions.append([
                "value": round6(NSDecimalNumber(decimal: out.amount).doubleValue),
                "quality": quality,
            ])
        }

        let categories = try context.fetch(FetchDescriptor<Yala.Category>())
        let estadisticas = try webStatistics(
            allTx: allTx, accounts: accounts.map(\.model), categories: categories,
            currency: scenario.preferredCurrency, now: now, adjustment: adjustment, converter: converter)
        let pagos = try webPayments(payments, now: now)

        return [
            "estadisticas": estadisticas,
            "pagos": pagos,
            "balances": [
                "accounts": perAccount,
                "total": round6(NSDecimalNumber(decimal: live.convertedTotal).doubleValue),
                "aproximado": live.amountsAreApproximate,
            ],
            "periods": [
                "mes_actual": period(chat.periods.currentMonth),
                "mes_pasado": period(chat.periods.lastMonth),
                "anio_actual": period(chat.periods.currentYear),
            ],
            "budgets": spent,
            "recurring": [
                "suscripciones_mensual": round6(chat.recurring.totals.subscriptionsMonthly),
                "recurrentes_mensual": round6(chat.recurring.totals.recurringMonthly),
            ],
            "groups": groups,
            "kinds": kinds,
            "conversions": conversions,
        ]
    }

    // MARK: - Yala web, lote 2: Estadísticas y Pagos planificados

    /// Las tres pestañas de Estadísticas que porta la web, con los calculadores de las pantallas. Los días se escriben con
    /// `Calendar.current` (la zona del test); los escenarios fechan a las 12:00 UTC, el mismo día civil en cualquier zona
    /// de UTC−11 a UTC+11.
    private func webStatistics(
        allTx: [TransactionItem],
        accounts: [Account],
        categories: [Yala.Category],
        currency: String,
        now: Date,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverter
    ) throws -> [String: Any] {
        func opt(_ v: Double?) -> Any { v.map { round6($0) as Any } ?? NSNull() }
        func slices(_ list: [CategorySpendingSummary]) -> [[String: Any]] {
            list.map { slice in
                [
                    "categoria": slice.category.map { $0.name as Any } ?? NSNull(),
                    "importe": round6(slice.amount),
                    "porcentaje": round6(slice.percentage),
                ]
            }
        }
        // Lo que filtra la pantalla antes de calcular (cuentas excluidas de estadísticas, Grupos según su interruptor).
        let filtered = FilterService.filterForTrends(
            transactions: allTx, accounts: accounts, criteria: FilterCriteria(), includeBridgedGroupTx: true)

        var periods: [String: Any] = [:]
        let kinds: [(String, DetailPeriod)] = [("mes_actual", .thisMonth), ("mes_pasado", .lastMonth), ("anio_actual", .thisYear)]
        for (key, period) in kinds {
            let data = InsightsCalculator.calculate(
                transactions: allTx, accounts: accounts, categories: categories, budgets: [], scheduledPayments: [],
                period: period, criteria: FilterCriteria(), currencyCode: currency, customRange: nil,
                converter: converter, includeBridgedGroupTx: true, adjustment: adjustment, now: now)
            let summary = data.periodSummary
            let distribution = TopSpendingCategoriesCalculator.calculateTopSpending(
                transactions: filtered, interval: period.dateInterval(now: now), currencyCode: currency,
                adjustment: adjustment, converter: converter)
            periods[key] = [
                "ingresos": round6(summary.totalIncome),
                "gastos": round6(summary.totalExpense),
                "neto": round6(summary.netBalance),
                "variacion": [
                    "ingresos": opt(summary.incomeVariation),
                    "gastos": opt(summary.expenseVariation),
                    "neto": opt(summary.balanceVariation),
                    "gasto_medio_diario": opt(summary.dailyAverageVariation),
                ],
                "gasto_medio_diario": round6(summary.dailyAverageExpense),
                "dias": Double(summary.dayCount),
                "gasto_mas_alto": data.quickStats.highestExpense.map { round6($0.amount) as Any } ?? NSNull(),
                "top_categorias": slices(Array(data.quickStats.topCategories.prefix(5))),
                "distribucion": slices(distribution),
            ]
        }

        // Tendencias › Entradas y salidas: seis meses, el actual hasta el último segundo de hoy.
        let calendar = Calendar.current
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            throw GoldenError.bad("sin mes para \(now)")
        }
        let endOfToday = DetailPeriod.thisMonth.dateInterval(now: now).end
        var trend: [[String: Any]] = []
        for back in stride(from: 5, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .month, value: -back, to: thisMonth),
                  let next = calendar.date(byAdding: .month, value: 1, to: start)
            else { throw GoldenError.bad("mes \(back) atrás") }
            let end = back == 0 ? endOfToday : next.addingTimeInterval(-1)
            let interval = DateInterval(start: start, end: end)
            // `CashFlowCalculator` agrupa lo que recibe: el recorte por el intervalo lo hace quien llama
            // (`TrendDataProcessor`), como aquí.
            let flow = CashFlowCalculator.calculateCashFlow(
                transactions: filtered.filter { interval.contains($0.date) }, interval: interval, grouping: .month,
                currencyCode: currency, adjustment: adjustment, converter: converter)
            trend.append([
                "mes": dayKey(start, calendar).prefix(7).description,
                "ingresos": round6(flow.totalIncome),
                "gastos": round6(flow.totalExpense),
                "neto": round6(flow.netFlow),
            ])
        }
        return ["periodos": periods, "tendencias": trend]
    }

    /// Las fechas de cobro de cada pago en los seis meses desde el de `now`, y los próximos cobros (de hoy a 29 días
    /// después, pagos activos, sin las fechas saltadas) como `"<id> <día>"` ordenados.
    private func webPayments(_ payments: [(id: String, model: ScheduledPayment)], now: Date) throws -> [String: Any] {
        // La semana empieza el lunes, como la preferencia por defecto que lee la web (`firstWeekday`): con `.current` el
        // semanal «cada 2» dependería del idioma del simulador. La zona es la del test, como en el resto del golden.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let lastUpcoming = calendar.date(byAdding: .day, value: 29, to: calendar.startOfDay(for: now))
        else { throw GoldenError.bad("sin mes para \(now)") }
        let today = calendar.startOfDay(for: now)
        var dates: [String: Any] = [:]
        var upcoming: [String] = []
        for (id, payment) in payments {
            var all: [String] = []
            for offset in 0..<6 {
                guard let month = calendar.date(byAdding: .month, value: offset, to: thisMonth) else { continue }
                let days = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams, month: month, calendar: calendar
                ).sorted()
                all.append(contentsOf: days.map { dayKey($0, calendar) })
                if offset <= 1 && payment.isActive {
                    for day in days where day >= today && day <= lastUpcoming && !payment.isDateSkipped(day) {
                        upcoming.append("\(id) \(dayKey(day, calendar))")
                    }
                }
            }
            dates[id] = all
        }
        return ["fechas": dates, "proximos": upcoming.sorted()]
    }

    private func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Filas → modelos por el camino del pull

    /// Columnas que el golden trae y que la app no aplica a propósito. Cualquier otra sin applier es un error de
    /// escritura del golden: el conector la leería y la app no, y el golden dejaría de medir lo mismo en los dos lados.
    private static let columnsWithoutApplier: Set<String> = ["sync_id", "local_day"]

    private func apply<M: PersistentModel>(
        _ entity: EntityApply<M>,
        _ scenario: Scenario,
        _ table: String,
        _ context: ModelContext
    ) throws -> [(id: String, model: M)] {
        var out: [(id: String, model: M)] = []
        for row in scenario.rows[table] ?? [] {
            guard case .string(let raw)? = row["sync_id"], let syncID = UUID(uuidString: raw) else {
                throw GoldenError.bad("[\(scenario.id)] \(table): fila sin sync_id válido")
            }
            let model = entity.make(context)
            entity.setSyncID(model, syncID)
            for (column, value) in row {
                if let applier = entity.appliers[column] {
                    try applier.apply(model, value, context)
                } else if !Self.columnsWithoutApplier.contains(column) {
                    Issue.record("[\(scenario.id)] \(table).\(column): la app no aplica esa columna")
                }
            }
            out.append((raw, model))
        }
        return out
    }

    // MARK: - Utilidades

    private func dayStartUTC(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    /// Días inclusivos del conector → el intervalo de la app, cerrado en el último segundo del último día.
    private func budgetInterval(_ p: Period) throws -> DateInterval {
        guard let start = dayStartUTC(p.desde), let lastDay = dayStartUTC(p.hasta) else {
            throw GoldenError.bad("budgetPeriod no válido")
        }
        return DateInterval(start: start, end: lastDay.addingTimeInterval(86_400 - 1))
    }

    private func round6(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        let r = (v * 1_000_000).rounded() / 1_000_000
        return r == 0 ? 0 : r  // sin «-0»
    }

    private func compare(_ got: Any?, _ want: Any?, path: String) {
        switch (got, want) {
        case (let g as [String: Any], let w as [String: Any]):
            let keys = Set(g.keys).union(w.keys)
            for key in keys.sorted() { compare(g[key], w[key], path: "\(path).\(key)") }
        case (let g as [Any], let w as [Any]):
            guard g.count == w.count else {
                Issue.record("\(path): \(g.count) elementos, el golden tiene \(w.count)")
                return
            }
            for i in g.indices { compare(g[i], w[i], path: "\(path)[\(i)]") }
        case (let g as Bool, let w as NSNumber) where CFGetTypeID(w) == CFBooleanGetTypeID():
            #expect(g == w.boolValue, "\(path): la app da \(g), el golden \(w.boolValue)")
        case (is Double, let w as NSNumber) where CFGetTypeID(w) == CFBooleanGetTypeID():
            Issue.record("\(path): la app da un número y el golden un booleano")
        case (let g as Double, let w as NSNumber):
            #expect(abs(g - w.doubleValue) <= Self.tolerance, "\(path): la app da \(g), el golden \(w.doubleValue)")
        case (let g as String, let w as String):
            #expect(g == w, "\(path): la app da \(g), el golden \(w)")
        case (is NSNull, is NSNull):
            break
        default:
            Issue.record("\(path): la app da \(String(describing: got)), el golden \(String(describing: want))")
        }
    }
}
