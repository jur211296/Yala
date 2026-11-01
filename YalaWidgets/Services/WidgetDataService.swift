//
//  WidgetDataService.swift
//  YalaWidgets
//
//  Service to read cached data from the main app via shared App Group.
//  This runs in the widget extension and reads from UserDefaults.
//

import Foundation

// MARK: - Codable DTOs (must match WidgetDataCache.swift)

/// Lightweight transaction data for widgets
struct WidgetTransaction: Codable {
    let id: String
    let date: Date
    let amount: Double
    let currencyCode: String
    let note: String?
    let categoryName: String?
    let categoryColor: String?
    let categoryIcon: String?
    let subcategoryIcon: String?
    let subcategoryName: String?
    let isIncome: Bool
    let amountInPreferredCurrency: Double
    /// `true` si el monto convertido se selló con una tasa que no era la de su día.
    ///
    /// **Opcional a propósito, y no es estilo: es lo único que evita apagar los widgets.** Este
    /// snapshot se decodifica con `JSONDecoder().decode(WidgetDataSnapshot.self, …)`, struct
    /// entera y sin versionado; una clave nueva NO opcional que falte en el payload escrito por la
    /// versión anterior lanza `keyNotFound`, `loadSnapshot()` devuelve nil y **todos** los widgets
    /// de la pantalla de inicio se quedan en cero hasta que el usuario abra la app. Mismo motivo
    /// que `periodBalance`, que ya lo es.
    ///
    /// **Y este fichero no lo cubre ningún test de decodificación**, porque `YalaTests` no compila
    /// `YalaWidgets`: lo único que impide quitarle el `?` es el source-scan de
    /// `ApproximateMarkSecondarySurfacesWiringTests`, que exige el texto `let <campo>: Bool?` para
    /// éste y para los cuatro de `WidgetPeriodSummary`. Es más débil que un test de comportamiento
    /// y se elige a conciencia; sin él, «limpiar» este `?` deja la suite entera en verde y apaga los
    /// widgets del parque que aún no ha reescrito su snapshot.
    let isExchangeRateProvisional: Bool?
}

/// Lightweight budget data for widgets
struct WidgetBudget: Codable {
    let id: String
    let name: String
    let limitAmount: Double
    let spentAmount: Double
    let currencyCode: String
    let periodType: String
    let percentUsed: Double
    let iconName: String?   // Optional for backwards compatibility - fallback: "chart.pie.fill"
    let colorHex: String?   // Optional for backwards compatibility - fallback: "#6366F1"
}

/// Lightweight scheduled payment data for widgets
struct WidgetScheduledPayment: Codable {
    let id: String
    let name: String
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date
    let isOverdue: Bool
    let paymentCategory: String  // "recurring" or "subscription"
    let isIncome: Bool
    let iconName: String?   // Optional for backwards compatibility - fallback based on paymentCategory
    let colorHex: String?   // Optional for backwards compatibility - fallback: "#6366F1"
    var isVariableAmount: Bool?  // Optional for backwards compatibility - fallback: false
}

/// Balance trend data point for widgets
struct WidgetTrendPoint: Codable {
    let date: Date
    let balance: Double
}

/// Multi-granularity trend data for different periods
struct WidgetTrendData: Codable {
    /// Daily points for short periods (last 90 days)
    let dailyPoints: [WidgetTrendPoint]
    /// Weekly points for medium periods (last 2 years, ~104 points max)
    let weeklyPoints: [WidgetTrendPoint]
    /// Monthly points for long periods (all time, ~120 points max for 10 years)
    let monthlyPoints: [WidgetTrendPoint]
}

/// Account balance for widget calculations
struct WidgetAccountBalance: Codable {
    let id: String
    let name: String
    let balance: Double
    let currencyCode: String
    let isExcludedFromStats: Bool
}

/// Category with aggregated data for widgets
struct WidgetCategory: Codable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let amount: Double
    let percentage: Double
}

/// Subcategory with aggregated data for widgets
struct WidgetSubcategory: Codable {
    let id: String
    let name: String
    let categoryName: String
    let iconName: String?
    let colorHex: String
    let amount: Double
    let percentage: Double
}

/// Cash flow point for bidirectional charts
struct WidgetCashFlowPoint: Codable {
    let date: Date
    let income: Double
    let expense: Double
    let net: Double
}

/// Lo que entró y salió por UNA cuenta en un período: el reparto por cuenta del extragrande vertical de «Entradas y
/// salidas» (iOS 27). Sale de la MISMA suma que los totales del resumen (`WidgetDataCache.buildPeriodSummary`), así que
/// los netos de todas las cuentas suman `netCashFlow`. Ingresos y gastos van con signo, como los totales.
struct WidgetAccountFlow: Codable {
    let id: String
    let name: String
    let income: Double
    let expense: Double
    let net: Double
}

/// El mes de los pagos planificados para el calendario del extragrande vertical (iOS 27): qué días tienen un pago de
/// gasto pendiente o ya pagado y cuánto falta pagar, en la divisa principal. Lo calcula la app
/// (`WidgetDataCache.buildPaymentsMonth`) porque el widget no tiene las recurrencias ni los tipos de cambio.
struct WidgetPaymentsMonth: Codable {
    /// Inicio del mes al que se refiere: el widget no lo pinta si la foto es de otro mes.
    let monthStart: Date
    let pendingDays: [Int]
    let paidDays: [Int]
    let remainingToPay: Double
}

/// Precalculated summary for a period
struct WidgetPeriodSummary: Codable {
    let totalIncome: Double
    let totalExpense: Double
    let netCashFlow: Double
    let topCategories: [WidgetCategory]
    let topSubcategories: [WidgetSubcategory]
    let cashFlowPoints: [WidgetCashFlowPoint]
    /// Historical balance at the END of the period (sum of all transactions up to period end)
    /// Optional for backwards compatibility with old cache format
    let periodBalance: Double?

    /// Las marcas «≈» de los cuatro números, una por número, tal como las escribió
    /// `WidgetDataCache`. **Opcionales por compatibilidad del payload**, igual que `periodBalance`
    /// — un snapshot de la versión anterior no trae estas claves y el decoder es la struct entera.
    /// Se leen con `?? false`: ausente significa «esta versión no lo sabía», y el lado seguro ahí
    /// es no marcar un número que quizá era exacto.
    let incomeIsApproximate: Bool?
    let expenseIsApproximate: Bool?
    let netCashFlowIsApproximate: Bool?
    let periodBalanceIsApproximate: Bool?

    /// El reparto por cuenta (extragrande vertical de «Entradas y salidas»). **Opcional y con default**: las fotos
    /// escritas antes de 2.2 no lo traen y decodifican igual; el widget solo esconde ese bloque.
    var accountFlows: [WidgetAccountFlow]? = nil
}

/// Complete widget data snapshot
struct WidgetDataSnapshot: Codable {
    // Metadata
    let lastUpdated: Date
    let preferredCurrencyCode: String
    let currencyDisplayFormat: String  // "symbol" or "code"

    // Account data for real balance calculation
    let accountBalances: [WidgetAccountBalance]
    let totalBalance: Double

    // Raw transactions for dynamic calculations (last 90 days, max 500)
    let transactions: [WidgetTransaction]

    // Budgets and payments (not filtered by period)
    let budgets: [WidgetBudget]
    let scheduledPayments: [WidgetScheduledPayment]

    // Trend data with multiple granularities
    let trendData: WidgetTrendData

    // Precalculated for "This Month" (most common period)
    let thisMonthSummary: WidgetPeriodSummary

    // Precalculated for "All Time" using ALL transactions (not just 90 days)
    // Optional for backwards compatibility with old cache format
    let allTimeSummary: WidgetPeriodSummary?

    // Precalculated summaries for all periods (keyed by WidgetPeriod.rawValue)
    // Optional for backwards compatibility
    let periodSummaries: [String: WidgetPeriodSummary]?

    /// El mes de los pagos planificados (extragrande vertical de «Pagos planificados»). **Opcional y con default**,
    /// por la misma razón que `accountFlows`: una clave obligatoria nueva apagaría todos los widgets.
    var paymentsMonth: WidgetPaymentsMonth? = nil
}

// MARK: - WidgetDataService

enum WidgetDataService {

    private static let cacheKey = "widget_data_cache"

    /// Espejo de `WidgetDataCache.groupsOnlySessionKey` (target de la app): la escribe la app cuando la sesión de este
    /// teléfono es solo grupos. Va fuera del snapshot para no tocar su decode. Ausente ⇒ `false`.
    static let groupsOnlySessionKey = "widget_groupsOnlySession"

    /// ¿Esta sesión es solo grupos? Entonces no hay finanzas personales que pintar y el widget invita a activarlas.
    static var isGroupsOnlySession: Bool {
        sharedDefaults?.bool(forKey: groupsOnlySessionKey) ?? false
    }

    /// App Group identifier read from Info.plist
    private static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
            ?? "group.com.jurgenschmidt.yala"
    }

    /// Shared UserDefaults for App Group
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Calendar Helper

    /// Returns calendar configured with user's firstWeekday preference from App Group
    static func widgetConfiguredCalendar() -> Calendar {
        var calendar = Calendar.current
        if let defaults = sharedDefaults {
            let firstWeekday = defaults.integer(forKey: "firstWeekday")
            calendar.firstWeekday = firstWeekday > 0 ? firstWeekday : 2  // Default: Monday
        }
        return calendar
    }

    /// Returns the user's default period from the main app
    /// Falls back to .thisMonth if not set or invalid
    static func getAppDefaultPeriod() -> WidgetPeriod {
        guard let defaults = sharedDefaults,
              let rawValue = defaults.string(forKey: "defaultPeriod"),
              let period = WidgetPeriod(rawValue: rawValue) else {
            return .thisMonth
        }
        return period
    }

    // MARK: - Expenses Only Mode

    /// Whether the app is in expenses-only mode (synced via App Group UserDefaults)
    static var isExpensesOnlyMode: Bool {
        sharedDefaults?.bool(forKey: "expensesOnlyMode") ?? false
    }

    // MARK: - Public API

    /// ¿La app ya escribió sus datos en el App Group? Sin ellos todo widget de datos pintaría ceros (en dólares si no
    /// hay preferencia guardada), así que invita a abrir Yala (UX 2.2 · L15-2, `WidgetNoDataInviteModifier`). No
    /// decodifica: basta con que la clave exista.
    static var hasSnapshot: Bool {
        sharedDefaults?.data(forKey: cacheKey) != nil
    }

    /// Loads the cached widget data snapshot
    /// Returns nil if no data is available or data is corrupted
    ///
    /// **Hasta el 2026-09-13 este snapshot llevaba un SELLO de identidad de sesión**, y lo que lo hacía
    /// funcionar no era la limpieza sino el sello: la caché vive en el App Group, que sobrevive a casi
    /// todo, así que la única defensa que no dependía de que un borrado llegara a correr era que el
    /// snapshot dijera de quién era. Se retiró con la sesión de visita —el único caso de dos humanos en un
    /// teléfono— y la lección queda en `.claude/rules/swiftdata-cloudkit.md`: si algún día vuelve a haber
    /// dos identidades sobre esta caché, la defensa es el sello, no la purga.
    static func loadSnapshot() -> WidgetDataSnapshot? {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("WidgetDataService: Failed to access shared UserDefaults")
            #endif
            return nil
        }

        guard let data = defaults.data(forKey: cacheKey) else {
            #if DEBUG
            print("WidgetDataService: No cached data found")
            #endif
            return nil
        }

        // Un proveedor pregunta a la foto varias veces por entrada (saldo, curva, divisa, formato, fecha…) y cada
        // pregunta la decodificaba entera. Se decodifica una vez por contenido: si los bytes no cambiaron, la de antes.
        if let cached = SnapshotMemo.value(for: data) {
            return cached
        }
        do {
            let snapshot = try JSONDecoder().decode(WidgetDataSnapshot.self, from: data)
            SnapshotMemo.store(snapshot, for: data)
            return snapshot
        } catch {
            #if DEBUG
            print("WidgetDataService: Error decoding snapshot: \(error)")
            #endif
            return nil
        }
    }

    /// Returns the total balance, or 0 if no data
    static func getTotalBalance() -> Double {
        loadSnapshot()?.totalBalance ?? 0
    }

    /// Returns the historical balance for a specific period
    /// For current periods (thisMonth, thisWeek, etc.): returns current total balance
    /// For past periods (lastMonth, lastYear, etc.): returns balance as it was at the end of that period
    static func getBalance(for period: WidgetPeriod) -> Double {
        guard let snapshot = loadSnapshot() else { return 0 }

        // Try to get precalculated periodBalance from summary
        if let summaries = snapshot.periodSummaries,
           let summary = summaries[period.rawValue],
           let periodBalance = summary.periodBalance {
            return periodBalance
        }

        // Fallback to current total balance for current periods
        // (old cache format or current periods)
        return snapshot.totalBalance
    }

    /// La marca «≈» del número que devuelve `getBalance(for:)`.
    ///
    /// Hermano y no un cambio de firma: `getBalance` tiene callsites que solo quieren el número.
    /// Sigue **exactamente** las mismas dos ramas, y por eso no pueden divergir: si el saldo salió
    /// del `periodBalance` precalculado, la marca es la que se guardó con él; si salió del fallback
    /// a `totalBalance` —cache de formato viejo, o período en curso— no hay señal que leer y
    /// devuelve `false`, que aquí significa «esta versión no lo sabía», no «es exacto».
    static func getBalanceIsApproximate(for period: WidgetPeriod) -> Bool {
        guard let snapshot = loadSnapshot() else { return false }
        if let summaries = snapshot.periodSummaries,
           let summary = summaries[period.rawValue],
           summary.periodBalance != nil {
            return summary.periodBalanceIsApproximate ?? false
        }
        return false
    }

    /// Returns the preferred currency code, or "USD" if no data
    static func getPreferredCurrency() -> String {
        loadSnapshot()?.preferredCurrencyCode ?? "USD"
    }

    /// Returns recent transactions (up to limit)
    static func getRecentTransactions(limit: Int = 5) -> [WidgetTransaction] {
        guard let snapshot = loadSnapshot() else { return [] }
        var transactions = snapshot.transactions
        if isExpensesOnlyMode {
            transactions = transactions.filter { !$0.isIncome }
        }
        return Array(transactions.prefix(limit))
    }

    /// Returns active budgets sorted by percent used (most critical first)
    static func getBudgets(sortByCritical: Bool = true) -> [WidgetBudget] {
        guard let snapshot = loadSnapshot() else { return [] }

        if sortByCritical {
            return snapshot.budgets.sorted { $0.percentUsed > $1.percentUsed }
        }
        return snapshot.budgets
    }

    /// Returns upcoming scheduled payments
    static func getScheduledPayments(
        filter: ScheduledPaymentFilter = .all,
        limit: Int = 5
    ) -> [WidgetScheduledPayment] {
        guard let snapshot = loadSnapshot() else { return [] }

        var payments = snapshot.scheduledPayments

        // Filter income payments in expenses-only mode
        if isExpensesOnlyMode {
            payments = payments.filter { !$0.isIncome }
        }

        // Apply filter
        switch filter {
        case .recurring:
            payments = payments.filter { $0.paymentCategory == "recurring" }
        case .subscription:
            payments = payments.filter { $0.paymentCategory == "subscription" }
        case .all:
            break
        }

        // Sort by due date (overdue first, then closest)
        payments.sort { payment1, payment2 in
            if payment1.isOverdue != payment2.isOverdue {
                return payment1.isOverdue  // Overdue first
            }
            return payment1.nextDueDate < payment2.nextDueDate
        }

        return Array(payments.prefix(limit))
    }

    /// El mes de pagos planificados que calculó la app (extragrande vertical de «Pagos planificados»). `nil` sin foto o
    /// con una foto anterior a 2.2.
    static func getPaymentsMonth() -> WidgetPaymentsMonth? {
        loadSnapshot()?.paymentsMonth
    }

    /// Returns trend data for chart (full structure with all granularities)
    static func getTrendData() -> WidgetTrendData? {
        loadSnapshot()?.trendData
    }

    /// Returns trend data appropriate for the given period
    /// - Parameter period: The period to get trend data for
    /// - Returns: Array of trend points at appropriate granularity
    /// - Parameter asOf: el «ahora» del período; `nil` = el reloj. Los widgets de 2.2 pasan la hora de la foto, que es
    ///   cuando se calcularon los puntos.
    static func getTrendData(for period: WidgetPeriod, asOf: Date? = nil) -> [WidgetTrendPoint] {
        guard let trendData = getTrendData() else { return [] }

        switch period {
        case .thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth:
            // Short/medium periods: use daily points
            return filterPoints(trendData.dailyPoints, for: period, asOf: asOf)

        case .thisYear, .lastYear:
            // Long periods: use weekly points
            return filterPoints(trendData.weeklyPoints, for: period, asOf: asOf)

        case .allTime:
            // All time: use monthly points
            return trendData.monthlyPoints
        }
    }

    /// Filter points to match the requested period
    private static func filterPoints(_ points: [WidgetTrendPoint], for period: WidgetPeriod, asOf: Date?) -> [WidgetTrendPoint] {
        let interval = asOf.map { period.dateInterval(now: $0) } ?? period.dateInterval()
        return points.filter { interval.contains($0.date) }
    }

    /// Returns the last update timestamp
    static func getLastUpdated() -> Date? {
        loadSnapshot()?.lastUpdated
    }

    /// Checks if data is stale (older than specified hours)
    static func isDataStale(olderThanHours hours: Int = 24) -> Bool {
        guard let lastUpdated = getLastUpdated() else { return true }
        let staleThreshold = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        return lastUpdated < staleThreshold
    }

    /// Returns the currency display format preference ("symbol" or "code")
    static func getCurrencyDisplayFormat() -> String {
        loadSnapshot()?.currencyDisplayFormat ?? "symbol"
    }

    /// Returns account balances
    static func getAccountBalances() -> [WidgetAccountBalance] {
        loadSnapshot()?.accountBalances ?? []
    }

    /// Returns the thisMonth summary (precalculated)
    static func getThisMonthSummary() -> WidgetPeriodSummary? {
        loadSnapshot()?.thisMonthSummary
    }

    /// Returns precalculated summary for a specific period
    /// All summaries are precalculated in WidgetDataCache to ensure accuracy
    static func calculateSummary(for period: WidgetPeriod) -> WidgetPeriodSummary? {
        guard let snapshot = loadSnapshot() else { return nil }

        // First try the new periodSummaries dictionary (preferred)
        if let summaries = snapshot.periodSummaries,
           let summary = summaries[period.rawValue] {
            return summary
        }

        // Fallback to legacy fields for backwards compatibility
        if period == .thisMonth {
            return snapshot.thisMonthSummary
        }

        if period == .allTime, let allTimeSummary = snapshot.allTimeSummary {
            return allTimeSummary
        }

        // Last resort: calculate from raw transactions (only works for recent periods within 90 days)
        let interval = period.dateInterval()
        let filtered = snapshot.transactions.filter { interval.contains($0.date) }

        return buildPeriodSummary(from: filtered)
    }

    /// Réplica del `ApproximateMarkThreshold` de la app para el camino de emergencia.
    ///
    /// **Se replica porque no se puede importar**: el target `YalaWidgetsExtension` solo compila
    /// tres ficheros de `Yala/` por membership exception y ese helper no está entre ellos. Añadirlo
    /// al target por un `if` de dos líneas es peor negocio que replicarlo con un test de paridad
    /// que los compare (`WidgetApproximateThresholdParityTests`).
    ///
    /// Contrato idéntico al original: magnitudes sumadas, suelo de ruido a los dos lados, umbral
    /// inclusivo con tolerancia relativa.
    private static func marksApproximate(approximate: Double, total: Double) -> Bool {
        let noiseFloor = 0.01
        let fraction = 0.05
        let approximateMagnitude = abs(approximate)
        guard approximateMagnitude > noiseFloor else { return false }
        let totalMagnitude = abs(total)
        guard totalMagnitude > noiseFloor else { return true }
        return approximateMagnitude >= fraction * totalMagnitude * (1 - 1e-9)
    }

    /// Builds a period summary from filtered transactions
    private static func buildPeriodSummary(from transactions: [WidgetTransaction]) -> WidgetPeriodSummary {
        var totalIncome: Double = 0
        var totalExpense: Double = 0
        // Magnitudes de la parte aproximada, por lado. Este camino de emergencia recalcula los
        // totales desde las filas crudas: sin acumular esto, los declararía exactos sin saberlo,
        // que es exactamente el bug que este campo viene a cerrar.
        var incomeApproximateMagnitude: Double = 0
        var expenseApproximateMagnitude: Double = 0

        // `amountInPreferredCurrency` llega YA resuelto en la divisa principal vigente: la app lo
        // escribe así (`WidgetDataCache.widgetTransaction`), porque la fila no viaja con la divisa
        // en que se guardó y este camino no podría reconvertirla.
        // Con signo, como los totales que precalcula la app (`WidgetDataCache.buildPeriodSummary`): una devolución en una
        // categoría de gasto resta del gasto. `isIncome` ya llega con la regla de la app.
        // Denominadores del umbral y de los porcentajes de categorías: magnitudes por lado, como la app.
        var incomeTotalMagnitude: Double = 0
        var expenseTotalMagnitude: Double = 0
        for tx in transactions {
            let amount = tx.amountInPreferredCurrency
            let isApproximate = tx.isExchangeRateProvisional ?? false
            if tx.isIncome {
                totalIncome += amount
                incomeTotalMagnitude += abs(amount)
                if isApproximate { incomeApproximateMagnitude += abs(amount) }
            } else {
                totalExpense -= amount
                expenseTotalMagnitude += abs(amount)
                if isApproximate { expenseApproximateMagnitude += abs(amount) }
            }
        }

        let netCashFlow = totalIncome - totalExpense

        // Build top categories
        let topCategories = buildTopCategories(from: transactions, totalExpense: expenseTotalMagnitude)

        // Build top subcategories
        let topSubcategories = buildTopSubcategories(from: transactions, totalExpense: expenseTotalMagnitude)

        // Build cash flow by day
        let cashFlowPoints = buildCashFlowByDay(from: transactions)

        return WidgetPeriodSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashFlow: netCashFlow,
            topCategories: topCategories,
            topSubcategories: topSubcategories,
            cashFlowPoints: cashFlowPoints,
            periodBalance: nil,  // Fallback calculation doesn't have access to all transactions
            // `ApproximateMarkThreshold` no está en la membership del target del widget, así que
            // el umbral se replica aquí. Es el mismo 5 % y el mismo suelo, y hay un test que los
            // compara: si la app cambia el suyo y este no, se pone rojo.
            incomeIsApproximate: marksApproximate(
                approximate: incomeApproximateMagnitude, total: incomeTotalMagnitude
            ),
            expenseIsApproximate: marksApproximate(
                approximate: expenseApproximateMagnitude, total: expenseTotalMagnitude
            ),
            netCashFlowIsApproximate: marksApproximate(
                approximate: incomeApproximateMagnitude + expenseApproximateMagnitude,
                total: netCashFlow
            ),
            periodBalanceIsApproximate: nil  // sin `periodBalance` no hay número que marcar
        )
    }

    /// Espejo de `WidgetDataCache.uncategorizedWidgetKey` y de `AppConstants.uncategorizedIconName/ColorHex` (la
    /// extensión no compila esos ficheros). `WidgetExtensionUncategorizedParityTests` los compara.
    static let uncategorizedKey = "\u{1}uncategorized"
    static let uncategorizedIconName = "questionmark.folder.fill"
    static let uncategorizedColorHex = "#9CA3AF"

    private static func buildTopCategories(
        from transactions: [WidgetTransaction],
        totalExpense: Double,
        limit: Int = 20
    ) -> [WidgetCategory] {
        // Group expenses by category
        var categoryTotals: [String: (name: String, icon: String, color: String, amount: Double)] = [:]

        for tx in transactions where !tx.isIncome {
            let amount = abs(tx.amountInPreferredCurrency)
            // Sin categoría: el trozo «Sin categoría» en gris, como en la app (`WidgetDataCache.buildTopCategories`),
            // para que el desglose sume el gasto del período.
            guard let categoryName = tx.categoryName else {
                let key = uncategorizedKey
                if var existing = categoryTotals[key] {
                    existing.amount += amount
                    categoryTotals[key] = existing
                } else {
                    categoryTotals[key] = (
                        name: String(localized: "widget.ui.uncategorized", bundle: .main),
                        icon: uncategorizedIconName,
                        color: uncategorizedColorHex,
                        amount: amount
                    )
                }
                continue
            }

            if var existing = categoryTotals[categoryName] {
                existing.amount += amount
                categoryTotals[categoryName] = existing
            } else {
                categoryTotals[categoryName] = (
                    name: categoryName,
                    icon: tx.categoryIcon ?? "folder",
                    color: tx.categoryColor ?? "#808080",
                    amount: amount
                )
            }
        }

        // Sort by amount and take top N
        let sorted = categoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.enumerated().map { index, item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetCategory(
                id: "\(index)",
                name: item.name,
                iconName: item.icon,
                colorHex: item.color,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    private static func buildTopSubcategories(
        from transactions: [WidgetTransaction],
        totalExpense: Double,
        limit: Int = 20
    ) -> [WidgetSubcategory] {
        // Group expenses by subcategory
        var subcategoryTotals: [String: (name: String, categoryName: String, icon: String?, color: String, amount: Double)] = [:]

        for tx in transactions where !tx.isIncome {
            guard let subcategoryName = tx.subcategoryName,
                  let categoryName = tx.categoryName else { continue }
            let amount = abs(tx.amountInPreferredCurrency)
            let key = "\(categoryName)_\(subcategoryName)"

            if var existing = subcategoryTotals[key] {
                existing.amount += amount
                subcategoryTotals[key] = existing
            } else {
                subcategoryTotals[key] = (
                    name: subcategoryName,
                    categoryName: categoryName,
                    icon: tx.categoryIcon,  // Use category icon as fallback
                    color: tx.categoryColor ?? "#808080",
                    amount: amount
                )
            }
        }

        // Sort by amount and take top N
        let sorted = subcategoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.enumerated().map { index, item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetSubcategory(
                id: "\(index)",
                name: item.name,
                categoryName: item.categoryName,
                iconName: item.icon,
                colorHex: item.color,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    private static func buildCashFlowByDay(from transactions: [WidgetTransaction]) -> [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group transactions by day
        var dailyData: [Date: (income: Double, expense: Double)] = [:]

        for tx in transactions {
            let day = calendar.startOfDay(for: tx.date)
            let amount = tx.amountInPreferredCurrency

            var existing = dailyData[day] ?? (income: 0, expense: 0)
            if tx.isIncome {
                existing.income += amount
            } else {
                existing.expense -= amount
            }
            dailyData[day] = existing
        }

        // Sort by date and return
        return dailyData
            .map { day, data in
                WidgetCashFlowPoint(
                    date: day,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                )
            }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Memo de la foto

/// La última foto decodificada y los bytes de los que salió. Compara los bytes enteros (unos cientos de KB, mucho más
/// barato que decodificarlos): con otra foto en el App Group, se vuelve a decodificar. Los proveedores pueden correr a la
/// vez, de ahí el candado.
private enum SnapshotMemo {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var data: Data?
    nonisolated(unsafe) private static var snapshot: WidgetDataSnapshot?

    static func value(for bytes: Data) -> WidgetDataSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return data == bytes ? snapshot : nil
    }

    static func store(_ value: WidgetDataSnapshot, for bytes: Data) {
        lock.lock()
        defer { lock.unlock() }
        data = bytes
        snapshot = value
    }
}

// MARK: - Filter Types

enum ScheduledPaymentFilter: String, CaseIterable {
    case all = "all"
    case recurring = "recurring"
    case subscription = "subscription"

    var displayName: String {
        switch self {
        case .all: return String(localized: "widget.paymentCategory.all", bundle: .main)
        case .recurring: return String(localized: "widget.paymentCategory.recurring", bundle: .main)
        case .subscription: return String(localized: "widget.paymentCategory.subscription", bundle: .main)
        }
    }
}

// MARK: - Trend Period

/// Period options for widget trend data
/// Aligned with DetailPeriod from main app (8 cases, excluding custom)
enum WidgetPeriod: String, CaseIterable, Codable {
    case thisWeek
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    case lastYear
    case allTime

    var displayName: String {
        localizedDisplayName
    }

    var localizedDisplayName: String {
        switch self {
        case .thisWeek: return String(localized: "widget.period.thisWeek", bundle: .main)
        case .last7Days: return String(localized: "widget.period.last7Days", bundle: .main)
        case .last30Days: return String(localized: "widget.period.last30Days", bundle: .main)
        case .thisMonth: return String(localized: "widget.period.thisMonth", bundle: .main)
        case .lastMonth: return String(localized: "widget.period.lastMonth", bundle: .main)
        case .thisYear: return String(localized: "widget.period.thisYear", bundle: .main)
        case .lastYear: return String(localized: "widget.period.lastYear", bundle: .main)
        case .allTime: return String(localized: "widget.period.allTime", bundle: .main)
        }
    }

    /// Returns the date interval for this period
    /// Matches DetailPeriod.dateInterval() exactly for consistency with main app
    ///
    /// `now`: por defecto, el reloj. Los widgets rediseñados en 2.2 pasan la hora de la FOTO (`lastUpdated`): las cifras
    /// que leen se calcularon entonces, y medir el período con el reloj de ahora las descuadraba en cuanto la foto era de
    /// ayer (a medianoche del día 1, «Este mes» era el mes nuevo y la cifra la del anterior).
    func dateInterval(now: Date = Date()) -> DateInterval {
        let calendar = WidgetDataService.widgetConfiguredCalendar()
        let startOfToday = calendar.startOfDay(for: now)
        // 23:59:59 de hoy, como `DetailPeriod.dateInterval()`: con la medianoche de mañana, lo fechado mañana a las 00:00
        // contaba en el período en curso (`DateInterval` es cerrado).
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfToday = calendar.date(byAdding: .second, value: -1, to: startOfTomorrow) ?? startOfTomorrow

        switch self {
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? startOfToday
            return DateInterval(start: startOfWeek, end: endOfToday)

        // Hoy y los 6 (o 29) anteriores, como `DetailPeriod.dateInterval()`.
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            return DateInterval(start: startOfMonth, end: endOfToday)

        case .lastMonth:
            let startOfThisMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfToday
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) ?? startOfThisMonth
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)

        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            return DateInterval(start: startOfYear, end: endOfToday)

        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) ?? startOfToday
            let endOfLastYear = calendar.date(byAdding: .second, value: -1, to: startOfThisYear) ?? startOfThisYear
            return DateInterval(start: startOfLastYear, end: endOfLastYear)

        case .allTime:
            let start = calendar.date(byAdding: .year, value: -10, to: now) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)
        }
    }
}
