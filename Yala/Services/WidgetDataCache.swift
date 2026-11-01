//
//  WidgetDataCache.swift
//  Yala
//
//  Service to cache data for widgets in shared App Group container.
//  This runs in the main app and pushes data to UserDefaults for widget access.
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - Codable DTOs for Widget Data

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
    /// `true` si el `amountInPreferredCurrency` de arriba se selló con una tasa que no era la de su
    /// día. Viaja al widget porque su camino de emergencia (`WidgetDataService.buildPeriodSummary`)
    /// recalcula los totales desde estas filas y, sin el flag, los declararía exactos sin saberlo.
    ///
    /// **Opcional aunque este lado solo escriba**: esta struct y su gemela de `YalaWidgets` tienen
    /// que decodificar el MISMO payload, y en los discos de hoy hay snapshots sin esta clave. Un
    /// `Bool` a secas los rompería enteros.
    ///
    /// Lo fija `WidgetSnapshotLegacyDecodeTests`, y con una salvedad que importa: **ese test solo
    /// alcanza a ESTA copia**. El target `YalaTests` sincroniza el grupo `YalaTests` y compila `Yala`,
    /// no `YalaWidgets` (`project.pbxproj`), así que su `decode(WidgetDataSnapshot.self, …)` resuelve
    /// aquí. A la copia del widget —la que de verdad lee en producción— la vigila el source-scan
    /// de `ApproximateMarkSecondarySurfacesWiringTests`.
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
    let iconName: String
    let colorHex: String
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
    let iconName: String
    let colorHex: String
    let isVariableAmount: Bool

    init(id: String, name: String, amount: Double, currencyCode: String, nextDueDate: Date, isOverdue: Bool, paymentCategory: String, isIncome: Bool, iconName: String, colorHex: String, isVariableAmount: Bool = false) {
        self.id = id; self.name = name; self.amount = amount; self.currencyCode = currencyCode
        self.nextDueDate = nextDueDate; self.isOverdue = isOverdue; self.paymentCategory = paymentCategory
        self.isIncome = isIncome; self.iconName = iconName; self.colorHex = colorHex
        self.isVariableAmount = isVariableAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        nextDueDate = try container.decode(Date.self, forKey: .nextDueDate)
        isOverdue = try container.decode(Bool.self, forKey: .isOverdue)
        paymentCategory = try container.decode(String.self, forKey: .paymentCategory)
        isIncome = try container.decode(Bool.self, forKey: .isIncome)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isVariableAmount = try container.decodeIfPresent(Bool.self, forKey: .isVariableAmount) ?? false
    }
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
    /// For current periods: current total balance
    /// For past periods: balance as it was at the end of that period
    let periodBalance: Double?

    /// Las marcas «≈» de los cuatro números de arriba, una por número.
    ///
    /// **Van por lado y no como señal única**, por lo mismo que en `CashFlowSummary`: los widgets
    /// pintan los totales por separado (`ExpenseWidget` solo el gasto, los pies solo el gasto), y
    /// una señal común le pondría «≈» a un número en el que no hubo esa conversión. El criterio es
    /// `ApproximateMarkThreshold`, el mismo umbral del 5 % que usa la app: dos umbrales para el
    /// mismo problema es como divergen.
    ///
    /// **Opcionales aunque este lado solo escriba**, igual que `periodBalance`: esta struct y su
    /// gemela de `YalaWidgets` decodifican el mismo payload del App Group, y los snapshots ya
    /// escritos no traen estas claves. Con `Bool` a secas, decodificar uno de esos lanza
    /// `keyNotFound` y se pierde el snapshot ENTERO —no solo el campo—, porque la clave cuelga de
    /// `thisMonthSummary`, que no es opcional. Lo fija `WidgetSnapshotLegacyDecodeTests` **para esta
    /// copia**; la del widget, el source-scan (ver `isExchangeRateProvisional` arriba).
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
    let allTimeSummary: WidgetPeriodSummary

    // Precalculated summaries for all periods (keyed by period rawValue)
    let periodSummaries: [String: WidgetPeriodSummary]

    /// El mes de los pagos planificados (extragrande vertical de «Pagos planificados»). **Opcional y con default**,
    /// por la misma razón que `accountFlows`: una clave obligatoria nueva apagaría todos los widgets.
    var paymentsMonth: WidgetPaymentsMonth? = nil

}

// MARK: - WidgetDataCache

@MainActor
enum WidgetDataCache {

    nonisolated static let cacheKey = "widget_data_cache"

    /// **«Esta sesión es solo grupos»**, publicado para el widget en una clave PROPIA del App Group.
    ///
    /// El widget no ve las preferencias de la app, así que el eje 1 (`PrivateSessionMark`) tiene que viajar por el App
    /// Group. Va FUERA del snapshot a propósito: `WidgetDataSnapshot` está duplicado en los dos targets y se decodifica
    /// entero, así que un campo nuevo mal declarado apaga TODOS los widgets (regla del App Group en
    /// `swiftdata-cloudkit.md`). Una clave suelta no puede romper el decode, y un widget de una versión anterior la ignora.
    /// Ausente se lee `false`: sin dato, el widget enseña lo de siempre. Decisión de Jürgen del 2026-09-09 (ticket
    /// `after-session-redesign-review-widgets-siri-applepay-and-web-copy`): en solo grupos invita a activar Yala completo.
    /// El lector espejo es `WidgetDataService.groupsOnlySessionKey`, y `WidgetGroupsOnlyInviteParityTests` los compara.
    nonisolated static let groupsOnlySessionKey = "widget_groupsOnlySession"

    /// **«Comparar con el período anterior»** (`AppPreferences.showVariations`) para los widgets, que con ella apagada no
    /// enseñan variaciones (la píldora de Saldo, la comparación de Gastos y la de Entradas y salidas), como la app apaga
    /// sus `VariationChip`. Ausente = activada, su default. El lector es `WidgetDataService.showsVariations`.
    nonisolated static let showVariationsKey = AppPreferences.Keys.showVariations

    /// Copia la preferencia al App Group si cambió. Devuelve si escribió.
    @discardableResult
    nonisolated static func publishShowVariations(_ value: Bool, in defaults: UserDefaults?) -> Bool {
        guard let defaults, defaults.object(forKey: showVariationsKey) as? Bool != value else { return false }
        defaults.set(value, forKey: showVariationsKey)
        return true
    }

    /// Al cambiarla en la app: la copia y recarga los widgets, que no esperan a la próxima foto.
    static func mirrorShowVariations(_ value: Bool) {
        if publishShowVariations(value, in: sharedDefaults) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Shared UserDefaults for App Group
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)
    }

    // MARK: - Public API

    /// Updates the widget cache with current data from SwiftData
    /// Call this after any data change that should reflect in widgets
    ///
    /// LA PUERTA. Con un wipe ARMADO el store montado está a punto de morir y sus datos ya no son de
    /// nadie: repoblar el snapshot en esa ventana deja en la pantalla de inicio los saldos de la cuenta
    /// que acaba de cerrar sesión, y ahí se quedan si nadie vuelve a abrir la app. Va AQUÍ y no en los
    /// **48** call-sites de producción (22 ficheros — el conteo de ficheros decía 18 y estaba desfasado;
    /// medido el 2026-09-08) por la razón que el gemelo de notificaciones ya dejó
    /// escrita en `NotificationService.isPersonalWipeArmed`: evaluarlo en el choke-point cierra la ventana
    /// para cualquier productor, presente o futuro, sin rastrear tareas ni mantener una lista.
    ///
    /// `clearCache()` NO lleva guard — retirar siempre es seguro, y es lo que los caminos de cierre piden.
    static func updateCache(context: ModelContext) {
        guard !isWipeArmed else {
            #if DEBUG
            print("WidgetDataCache: updateCache SUSPENDIDO — wipe armado")
            #endif
            return
        }

        // Lo que tarda en estar la foto que leen los widgets (y Siri): la extensión solo la decodifica.
        let built = LoadTimeMarks.measure(.widgetCache) { buildSnapshot(context: context) }
        saveSnapshot(built.widget)
        // La hora de la foto, no la de ahora: una foto de las 23:59:59 guardada pasada la medianoche es de ayer, y
        // `refreshIfBuiltOnAnotherDay` tiene que rehacerla al volver a primer plano.
        lastBuiltAt = built.widget.lastUpdated
        // La foto de Siri sale de los MISMOS números, en su propia clave (`SiriFinanceSnapshot`): así Siri y los widgets
        // dicen lo mismo y viven y mueren juntos (ver `clearCache`).
        SiriFinanceSnapshotStore.write(built.siri, to: sharedDefaults)
        // El índice de Spotlight (cuentas y movimientos, card ste6) se reconcilia con los mismos cambios y detrás de la
        // misma puerta del borrado armado; se vacía en `clearCache()`.
        SpotlightIndexService.scheduleReconcile(context: context)
        publishSessionShell(hasPrivateSession: PrivateSessionMark.hasPrivateSession(),
                            prefersGroupsOnlyView: GroupsOnlyViewMark.isOn())

        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Cuándo se construyó la última foto en este proceso.
    private(set) static var lastBuiltAt: Date?

    /// Recalcula la foto al volver a primer plano si se construyó otro día.
    ///
    /// El saldo de hoy deja fuera los movimientos con fecha futura (`LiveBalanceCalculator.TodayCutoff`). La extensión no
    /// recalcula nada: solo relee esta foto. Sin esto, cuando un movimiento de mañana llegaba a su fecha el widget seguía
    /// sin él hasta la siguiente edición o el siguiente arranque en frío.
    static func refreshIfBuiltOnAnotherDay(context: ModelContext, now: Date = .now) {
        guard needsDayRefresh(lastBuiltAt: lastBuiltAt, now: now, calendar: .current) else { return }
        updateCache(context: context)
    }

    /// `true` si hay una foto de este proceso y es de otro día. Sin foto no decide: el arranque en frío ya la construye.
    static func needsDayRefresh(lastBuiltAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let lastBuiltAt else { return false }
        return !calendar.isDate(lastBuiltAt, inSameDayAs: now)
    }

    /// El predicado de la puerta, ESPEJO EXACTO de `NotificationService.isPersonalWipeArmed`. NO incluye
    /// `groupsOnlyWipeArmed`, misma asimetría deliberada que allí — en ese camino el store personal
    /// sobrevive y lo que pinta el widget sigue siendo legítimo.
    static var isWipeArmed: Bool {
        StorageModePersistence.isSignOutWipeArmed()
    }

    /// Clears the widget cache
    static func clearCache() {
        clearCache(in: sharedDefaults)
        // Lo que la foto de Siri deja de saber, Spotlight deja de enseñarlo (card ste6). Va aquí y no en la variante con
        // el store inyectado: esa la usan los tests de las purgas, y el índice es del teléfono.
        SpotlightIndexService.clear()
    }

    /// Variante con el store inyectado: la usan los tests de las purgas para medir el vaciado sin tocar el App Group real.
    /// No toca `groupsOnlySessionKey`: vaciar los datos no cambia QUIÉN usa el teléfono.
    static func clearCache(in defaults: UserDefaults?) {
        defaults?.removeObject(forKey: cacheKey)
        SiriFinanceSnapshotStore.clear(in: defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Publica para el widget si esta sesión es solo grupos (`!hasPrivateSession`, la MISMA lectura laxa que decide la
    /// shell en `ShellModeLogic`: sin marca no se invita, que es enseñar lo de siempre). Solo escribe y recarga si cambia.
    ///
    /// Dos llamadores, y los dos hacen falta: `updateCache` (cubre el arranque, y con él al que actualiza la app ya en
    /// solo grupos) y el `didSet` de `SessionState.hasPrivateSession`, el embudo del eje, que cubre activar Yala completo
    /// o entrar por un grupo con la app abierta. Sin el segundo, el widget seguiría invitando hasta el siguiente arranque.
    ///
    /// Desde la card p0iu cuenta también «Solo grupos» elegido sobre Yala completo: el widget enseña lo mismo que la shell.
    static func publishSessionShell(hasPrivateSession: Bool, prefersGroupsOnlyView: Bool) {
        publishSessionShell(hasPrivateSession: hasPrivateSession, prefersGroupsOnlyView: prefersGroupsOnlyView,
                            in: sharedDefaults)
    }

    @discardableResult
    static func publishSessionShell(hasPrivateSession: Bool, prefersGroupsOnlyView: Bool,
                                    in defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        let groupsOnly = ShellModeLogic.effective(
            hasPrivateSession: hasPrivateSession, prefersGroupsOnlyView: prefersGroupsOnlyView) == .groupsFocused
        guard defaults.object(forKey: groupsOnlySessionKey) as? Bool != groupsOnly else { return false }
        defaults.set(groupsOnly, forKey: groupsOnlySessionKey)
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// La divisa en la que la caché calcula los widgets: la de `CurrencyDefaults.preferred`, como la app.
    static func preferredCurrencyCode(defaults: UserDefaults = .standard) -> String {
        CurrencyDefaults.preferred(in: defaults).rawValue
    }

    // MARK: - Private Helpers

    /// `now` es el «ahora» de la foto: los ocho períodos, el mes de los pagos, Siri y `lastUpdated` salen de él. Los
    /// widgets miden los períodos a la hora de la foto (`lastUpdated`), así que un segundo reloj para ella haría que una
    /// foto empezada a las 23:59:59 del último día del mes y guardada pasada la medianoche leyera «Este mes» como el
    /// siguiente. Solo los tests lo fijan.
    static func buildSnapshot(
        context: ModelContext, now: Date = .now
    ) -> (widget: WidgetDataSnapshot, siri: SiriFinanceSnapshot) {
        // Fetch ALL transactions for correct balance calculation
        let allTransactionsDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )

        var allTransactions: [TransactionItem] = []
        do {
            // Lo que espera su borrado con «Deshacer» no cuenta en los widgets (`RecordPendingDeletion`).
            allTransactions = RecordPendingDeletion.shared.visible(try context.fetch(allTransactionsDescriptor))
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching transactions: \(error)")
            #endif
        }

        // Filter to last 90 days for widget display (max 500)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date.now) ?? Date.now
        let recentTransactions = Array(allTransactions.filter { $0.date >= ninetyDaysAgo }.prefix(500))

        // Fetch active budgets
        let budgetDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )

        var budgets: [Budget] = []
        do {
            budgets = try context.fetch(budgetDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching budgets: \(error)")
            #endif
        }

        // Fetch active scheduled payments
        let paymentDescriptor = FetchDescriptor<ScheduledPayment>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        var scheduledPayments: [ScheduledPayment] = []
        do {
            // Un pago que espera su borrado con «Deshacer» no cuenta en los widgets (`ScheduledPaymentPendingDeletion`).
            scheduledPayments = ScheduledPaymentPendingDeletion.shared.visible(try context.fetch(paymentDescriptor))
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching scheduled payments: \(error)")
            #endif
        }

        // Fetch ALL accounts (including archived) — archived still count for total balance
        let accountDescriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )

        var accounts: [Account] = []
        do {
            accounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching accounts: \(error)")
            #endif
        }

        // Pre-filter: exclude transactions from accounts excluded from statistics
        let excludedAccountIDs = Set(
            accounts.filter { $0.excludeFromStatistics }.map { $0.persistentModelID }
        )
        let isEligible: (TransactionItem) -> Bool = { tx in
            countsForWidgets(tx, excludedAccountIDs: excludedAccountIDs)
        }
        let eligibleTransactions = allTransactions.filter(isEligible)
        let eligibleRecentTransactions = recentTransactions.filter(isEligible)

        // Netea los gastos de grupo bridgeados a "mi parte" en las superficies de stats.
        // Se construye del set MÁS AMPLIO (`allTransactions`, antes del filtro de elegibilidad)
        // para garantizar AMBAS hermanas del bridge; el consumo usa el subset elegible.
        let adjustment = GroupBridgeStatsAdjustment.build(from: allTransactions, context: context)

        // La divisa principal, con la regla de toda la app si falta (`CurrencyDefaults.preferred`, card 2jj6). Hasta el
        // 2026-10-30 caía a dólares y reconvertía todo el histórico mientras la app pintaba soles.
        let preferredCurrency = preferredCurrencyCode()
        // Reconvierte las filas guardadas con otra divisa principal (`CashFlowCalculator.resolvedAmount`).
        // Memoizado para este snapshot: cada fila se resuelve en hasta ~20 superficies (8 períodos,
        // saldo, curva) y cada conversión del converter compartido lee sus tasas del store.
        let converter: CurrencyConverting = SnapshotMemoizedConverter(base: CurrencyConverter.shared)

        // Total balance: TC actual sobre saldo nativo (LiveBalanceCalculator).
        // El widget consume este Double ya convertido — el calculator NO se
        // expone al target widget extension.
        let totalBalance = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: eligibleTransactions,
            preferredCurrencyCode: preferredCurrency
        )

        // Build widget transactions (last 10 for display, from recent 90 days, excluyendo cuentas excluidas de stats)
        let widgetTransactions = Array(eligibleRecentTransactions.prefix(10)).map { tx in
            widgetTransaction(tx, currencyCode: preferredCurrency, converter: converter)
        }

        // Build widget budgets with spent calculation
        // For yearly/unique budgets, use allTransactions (90-day window is insufficient)
        let widgetBudgets = budgets.map { budget in
            let transactionsForBudget: [TransactionItem]
            let periodType = BudgetPeriodType(rawValue: budget.periodType)
            if periodType == .yearly || periodType == .unique {
                transactionsForBudget = allTransactions
            } else {
                transactionsForBudget = recentTransactions
            }
            let spent = calculateBudgetSpent(budget: budget, transactions: transactionsForBudget, adjustment: adjustment)
            let percentUsed = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100 : 0
            // CSV mirror SSOT con fallback M2M para legacy budgets pre-deploy.
            let (icon, color) = Budget.computeDisplayProperties(for: budget, in: context)

            return WidgetBudget(
                id: budget.id.uuidString,
                name: budget.name,
                limitAmount: budget.limitAmount,
                spentAmount: spent,
                currencyCode: budget.currencyCode,
                periodType: budget.periodType,
                percentUsed: percentUsed,
                iconName: icon,
                colorHex: color
            )
        }

        // Build widget scheduled payments
        let today = Calendar.current.startOfDay(for: Date.now)
        let widgetPayments = scheduledPayments.map { payment in
            let (icon, color) = getPaymentDisplayProperties(payment: payment)

            return WidgetScheduledPayment(
                id: payment.id.uuidString,
                name: payment.name,
                amount: payment.amount,
                currencyCode: payment.currencyCode,
                nextDueDate: payment.nextDueDate,
                isOverdue: payment.nextDueDate < today,
                paymentCategory: payment.paymentCategory,
                isIncome: payment.transactionType == "income",
                iconName: icon,
                colorHex: color,
                isVariableAmount: payment.isVariableAmount
            )
        }

        // Build trend data with multiple granularities (uses eligible transactions)
        let trendData = buildTrendData(
            transactions: eligibleTransactions,
            totalBalance: totalBalance,
            currencyCode: preferredCurrency,
            converter: converter
        )

        // Build account balances for widgets (only visible accounts shown as cards).
        // Cada card muestra el saldo en moneda NATIVA de la cuenta. Una sola
        // pasada O(N+M) sobre transactions vía batchCalculateBalances.
        let visibleAccounts = filterVisibleAccountsForWidget(accounts)
        let nativeBalancesByAccount = AccountBalanceCalculator.batchCalculateBalances(
            accounts: visibleAccounts, transactions: allTransactions
        )
        let widgetAccountBalances = visibleAccounts.map { account in
            let nativeBalance = nativeBalancesByAccount[account.persistentModelID] ?? 0
            return WidgetAccountBalance(
                id: account.persistentModelID.hashValue.description,
                name: account.name,
                balance: NSDecimalNumber(decimal: nativeBalance).doubleValue,
                currencyCode: account.currencyCode,
                isExcludedFromStats: account.excludeFromStatistics
            )
        }

        // Get currency display format preference
        let currencyDisplayFormat = UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "symbol"

        // Build summaries for ALL widget periods using DetailPeriod (source of truth)
        // Uses allTransactions to ensure correct data for past periods like lastYear
        var periodSummaries: [String: WidgetPeriodSummary] = [:]

        // Widget periods aligned with DetailPeriod (excluding custom)
        let widgetPeriods: [DetailPeriod] = [
            .thisWeek, .last7Days, .last30Days, .thisMonth,
            .lastMonth, .thisYear, .lastYear, .allTime
        ]

        // Un solo «ahora» para los ocho períodos y para la foto de Siri, que guarda el inicio de cada uno: con dos
        // relojes, un cálculo a caballo de medianoche del día 1 etiquetaría los totales de septiembre como de octubre.
        let periodsNow = now
        for period in widgetPeriods {
            let interval = period.dateInterval(now: periodsNow)
            let summary = buildPeriodSummary(
                transactions: eligibleTransactions,
                periodStart: interval.start,
                periodEnd: interval.end,
                currencyCode: preferredCurrency,
                allTransactionsForBalance: eligibleTransactions,
                adjustment: adjustment,
                converter: converter
            )
            periodSummaries[period.rawValue] = summary
        }

        // Legacy fields for backwards compatibility
        let thisMonthSummary = periodSummaries[DetailPeriod.thisMonth.rawValue] ?? buildPeriodSummary(
            transactions: eligibleRecentTransactions,
            periodStart: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: periodsNow)) ?? periodsNow,
            periodEnd: periodsNow,
            currencyCode: preferredCurrency,
            adjustment: adjustment,
            converter: converter
        )

        let allTimeSummary = periodSummaries[DetailPeriod.allTime.rawValue] ?? buildPeriodSummary(
            transactions: eligibleTransactions,
            periodStart: Date.distantPast,
            periodEnd: periodsNow,
            currencyCode: preferredCurrency,
            adjustment: adjustment,
            converter: converter
        )

        // El mes de los pagos para el calendario del extragrande vertical de «Pagos planificados». Mismo «ahora» que
        // los períodos: a caballo de medianoche del día 1 no puede salir el calendario de un mes y los totales de otro.
        let paymentsMonth = buildPaymentsMonth(
            payments: scheduledPayments,
            paid: ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                for: scheduledPayments, month: periodsNow, context: context
            ),
            month: periodsNow,
            currencyCode: preferredCurrency,
            converter: converter
        )

        let widgetSnapshot = WidgetDataSnapshot(
            lastUpdated: periodsNow,
            preferredCurrencyCode: preferredCurrency,
            currencyDisplayFormat: currencyDisplayFormat,
            accountBalances: widgetAccountBalances,
            totalBalance: totalBalance,
            transactions: widgetTransactions,
            budgets: widgetBudgets,
            scheduledPayments: widgetPayments,
            trendData: trendData,
            thisMonthSummary: thisMonthSummary,
            allTimeSummary: allTimeSummary,
            periodSummaries: periodSummaries,
            paymentsMonth: paymentsMonth
        )

        // Siri: todas las cuentas (las archivadas hacen falta para leer bien las líneas de una tarjeta), con el saldo
        // nativo de las que el Panel enseña. `SiriFinanceSnapshotBuilder` decide cuáles salen.
        let siriAccounts = accounts.map { account in
            SiriAccountInput(
                node: AccountLineNode(account),
                name: account.name,
                excludedFromStatistics: account.excludeFromStatistics,
                nativeBalance: NSDecimalNumber(decimal: nativeBalancesByAccount[account.persistentModelID] ?? 0).doubleValue
            )
        }
        let siriSnapshot = SiriFinanceSnapshotBuilder.make(
            widget: widgetSnapshot,
            accounts: siriAccounts,
            now: periodsNow,
            calendar: userConfiguredCalendar()
        )
        return (widgetSnapshot, siriSnapshot)
    }

    /// Spent del budget vía SSOT `BudgetsViewModel.calculateSpending`.
    static func calculateBudgetSpent(
        budget: Budget,
        transactions: [TransactionItem],
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Double {
        let calendar = Calendar.current
        let now = Date.now
        let interval: DateInterval

        let periodType = BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        switch periodType {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .yearly:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .unique:
            // Días enteros, como en Presupuestos: la hora guardada en las fechas no decide nada.
            interval = BudgetPeriodInterval.unique(
                start: budget.startDate ?? now, end: budget.endDate ?? now, calendar: calendar
            )
        }

        return BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: transactions,
            interval: interval,
            adjustment: adjustment
        )
    }

    /// Si un movimiento entra en los widgets de inicio: con cuenta, y de una cuenta que cuenta para estadísticas. Es el
    /// filtro de cuentas elegibles de la app (Panel, Registros, Estadísticas), que deja fuera los movimientos sin cuenta.
    /// Hasta el 2026-10-23 los widgets sí los contaban y su «Este mes» no coincidía con el de la app.
    static func countsForWidgets(_ tx: TransactionItem, excludedAccountIDs: Set<PersistentIdentifier>) -> Bool {
        guard let account = tx.account else { return false }
        return !excludedAccountIDs.contains(account.persistentModelID)
    }

    /// Ingreso o gasto con la regla de toda la app (`TransactionClassificationLogic`: la categoría manda; sin
    /// categoría, el signo). Hasta el 2026-10-23 aquí un movimiento sin categoría era siempre gasto, y los widgets
    /// contaban otro mes que Registros (ticket `records-standalone-amount-discrepancy`).
    static func isIncomeTx(_ tx: TransactionItem) -> Bool {
        TransactionClassificationLogic.isIncome(tx)
    }

    /// Cuentas visibles para widgets: no archivadas y no excluidas de stats.
    static func filterVisibleAccountsForWidget(_ accounts: [Account]) -> [Account] {
        accounts.filter { !$0.isArchived && !$0.excludeFromStatistics }
    }

    /// La fila tal como la ve la pantalla de inicio.
    ///
    /// `amountInPreferredCurrency` lleva el importe YA RESUELTO en la divisa principal vigente
    /// (`CashFlowCalculator.resolvedAmount`, fila entera), no el monto guardado: el camino de
    /// emergencia del widget (`WidgetDataService.buildPeriodSummary`) suma este campo, y la fila no
    /// viaja con la divisa en que se guardó. Así no hace falta un campo nuevo en el DTO, que está
    /// duplicado en dos targets. `isExchangeRateProvisional` dice si ESA resolución es aproximada.
    /// El widget de últimos registros pinta el importe nativo y no lee ninguno de los dos.
    static func widgetTransaction(
        _ tx: TransactionItem,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> WidgetTransaction {
        let resolved = CashFlowCalculator.resolvedAmount(
            tx, currencyCode: currencyCode, adjustment: .none, converter: converter
        )
        return WidgetTransaction(
            id: tx.persistentModelID.hashValue.description,
            date: tx.date,
            amount: tx.amount,
            currencyCode: tx.currencyCode,
            note: tx.note,
            categoryName: tx.category?.name,
            categoryColor: tx.category?.colorHex,
            categoryIcon: tx.category?.iconName,
            subcategoryIcon: tx.subcategory?.iconName ?? tx.category?.iconName,
            subcategoryName: tx.subcategory?.name,
            isIncome: isIncomeTx(tx),
            amountInPreferredCurrency: resolved.value,
            isExchangeRateProvisional: resolved.approximateMagnitude > 0
        )
    }

    /// Extracts display properties (icon, color) from a budget based on its subcategories
    /// Extracts display properties (icon, color) from a scheduled payment
    private static func getPaymentDisplayProperties(payment: ScheduledPayment) -> (icon: String, color: String) {
        if let subcategory = payment.subcategory {
            // Use subcategory icon/color, or fallback to category
            let icon = subcategory.iconName ?? subcategory.safeCategory.iconName ?? "creditcard.fill"
            let color = subcategory.colorHex ?? subcategory.safeCategory.colorHex
            return (icon, color)
        }

        // No subcategory: use icon based on payment category
        if payment.paymentCategory == "subscription" {
            return ("creditcard.and.123", "#6366F1")
        }
        return ("arrow.trianglehead.2.clockwise.rotate.90", "#6366F1")
    }

    static func buildTrendData(
        transactions: [TransactionItem],
        totalBalance: Double,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> WidgetTrendData {
        let calendar = Calendar.current

        // Lo que cambió cada día, en divisa NATIVA. Cada punto es el saldo al cierre de su día (o de su semana o
        // mes) valorado con el tipo de cambio de esa fecha, la regla de la curva de la app (`BalanceValuation`,
        // `panel-balance-chart-contradicts-its-own-figure`). El punto de hoy es `totalBalance`, el saldo vivo.
        var nativeByDay: [Date: [String: Decimal]] = [:]
        var totalNative: [String: Decimal] = [:]
        // Solo las filas que entran en un saldo, como el saldo vivo (`LiveBalanceCalculator.entersBalance`): si no, el
        // punto de hoy —que es ese saldo— y los de antes contarían filas distintas y la curva pintaría un escalón en hoy.
        for tx in transactions where LiveBalanceCalculator.entersBalance(tx) {
            let day = calendar.startOfDay(for: tx.date)
            LiveBalanceCalculator.addNative(tx, to: &nativeByDay[day, default: [:]])
            LiveBalanceCalculator.addNative(tx, to: &totalNative)
        }

        // Find the earliest transaction date to avoid showing flat line before data exists
        let earliestTransactionDate = transactions.map(\.date).min()
        let daysOfData: Int
        if let earliest = earliestTransactionDate {
            daysOfData = calendar.dateComponents([.day], from: earliest, to: Date.now).day ?? 90
        } else {
            daysOfData = 0
        }

        let dailyDays = min(daysOfData + 1, 90)  // +1 to include the first transaction day
        let weeklyPeriods = min((daysOfData / 7) + 1, 104)
        let monthlyPeriods = min((daysOfData / 30) + 1, 120)

        let dailyClosings = dailyTrendClosings(days: dailyDays, calendar: calendar)
        let weeklyClosings = aggregatedTrendClosings(periods: weeklyPeriods, component: .weekOfYear, calendar: calendar)
        let monthlyClosings = aggregatedTrendClosings(periods: monthlyPeriods, component: .month, calendar: calendar)
        let valuation = BalanceValuation(
            currencies: Set(totalNative.keys),
            to: currencyCode,
            closingDates: (dailyClosings + weeklyClosings + monthlyClosings).map(\.closing),
            converter: converter,
            calendar: calendar
        )

        func points(_ closings: [(date: Date, closing: Date)]) -> [WidgetTrendPoint] {
            closings.map { entry in
                // El primero es hoy: el saldo vivo tal cual, que es el número que pinta el widget al lado.
                if entry.closing >= calendar.startOfDay(for: Date.now) {
                    return WidgetTrendPoint(date: entry.date, balance: totalBalance)
                }
                var native = totalNative
                for (day, delta) in nativeByDay where day > entry.closing {
                    for (code, amount) in delta { native[code, default: 0] -= amount }
                }
                return WidgetTrendPoint(date: entry.date, balance: valuation.doubleValue(native, at: entry.closing))
            }.reversed()
        }

        return WidgetTrendData(
            dailyPoints: points(dailyClosings),
            weeklyPoints: points(weeklyClosings),
            monthlyPoints: points(monthlyClosings)
        )
    }

    /// Los días de la curva diaria, de hoy hacia atrás: cada punto lleva la fecha del día y cierra al final de él.
    private static func dailyTrendClosings(days: Int, calendar: Calendar) -> [(date: Date, closing: Date)] {
        (0..<days).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date.now) else { return nil }
            let day = calendar.startOfDay(for: date)
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return (day, min(next.addingTimeInterval(-1), Date.now))
        }
    }

    /// Las semanas o meses de la curva, del actual hacia atrás: cada punto lleva la fecha de inicio del periodo y
    /// cierra al final de él (el actual, ahora).
    private static func aggregatedTrendClosings(
        periods: Int, component: Calendar.Component, calendar: Calendar
    ) -> [(date: Date, closing: Date)] {
        let today = Date.now
        let currentPeriodStart: Date
        if component == .weekOfYear {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        } else {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        }
        return (0..<periods).compactMap { periodIndex in
            guard let periodStart = calendar.date(byAdding: component, value: -periodIndex, to: currentPeriodStart),
                  let periodEnd = calendar.date(byAdding: component, value: 1, to: periodStart)
            else { return nil }
            return (periodStart, min(periodEnd.addingTimeInterval(-1), today))
        }
    }

    private static func saveSnapshot(_ snapshot: WidgetDataSnapshot) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("WidgetDataCache: Failed to access shared UserDefaults")
            #endif
            return
        }

        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: cacheKey)

            // Sync firstWeekday preference for widget calendar calculations
            let firstWeekday = UserDefaults.standard.integer(forKey: "firstWeekday")
            defaults.set(firstWeekday > 0 ? firstWeekday : 2, forKey: "firstWeekday")

            // Sync defaultPeriod preference for "Same as app" option in widgets
            let defaultPeriod = UserDefaults.standard.string(forKey: "defaultPeriod") ?? "allTime"
            defaults.set(defaultPeriod, forKey: "defaultPeriod")

            // Y «Comparar con el período anterior», por si cambió sin pasar por `AppPreferences` (o antes de 2.2).
            let showVariations = UserDefaults.standard.object(forKey: AppPreferences.Keys.showVariations) as? Bool ?? true
            publishShowVariations(showVariations, in: defaults)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error encoding snapshot: \(error)")
            #endif
        }
    }

    // MARK: - Mes de pagos (extragrande vertical de Pagos planificados)

    /// El mes de `month` para el calendario del widget: días con pago pendiente y pagado, y lo que falta pagar en
    /// `currencyCode`.
    ///
    /// La misma cuenta que la tarjeta de Pagos del Panel (`PanelViewModel`, total menos pagado): solo pagos de gasto,
    /// cada ocurrencia del mes, las saltadas fuera, las pagadas al importe real del movimiento (las primeras del mes por
    /// fecha) y las pendientes al importe planificado, convertido con la última tasa. El widget no podría: no tiene las
    /// recurrencias ni los tipos de cambio.
    static func buildPaymentsMonth(
        payments: [ScheduledPayment],
        paid: [String: [PaidOccurrenceInfo]],
        month: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar = .current
    ) -> WidgetPaymentsMonth {
        let monthStart = calendar.dateInterval(of: .month, for: month)?.start ?? calendar.startOfDay(for: month)
        var pendingDays: Set<Int> = []
        var paidDays: Set<Int> = []
        var remaining: Double = 0

        func converted(_ amount: Double, from currency: String) -> Double {
            guard currency != currencyCode, amount > 0 else { return amount }
            let value = converter.convertWithLatestRate(Decimal(amount), from: currency, to: currencyCode)
            return NSDecimalNumber(decimal: value).doubleValue
        }

        for payment in payments where payment.transactionType != "income" {
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: monthStart
            ).sorted()
            var paidInfos = paid[payment.id.uuidString] ?? []
            for date in dates {
                if payment.isDateSkipped(date) { continue }
                let day = calendar.component(.day, from: date)
                if !paidInfos.isEmpty {
                    paidInfos.removeFirst()
                    paidDays.insert(day)
                } else {
                    pendingDays.insert(day)
                    remaining += converted(payment.amount, from: payment.currencyCode)
                }
            }
        }

        return WidgetPaymentsMonth(
            monthStart: monthStart,
            pendingDays: pendingDays.sorted(),
            paidDays: paidDays.sorted(),
            remainingToPay: remaining
        )
    }

    // MARK: - Period Summary Calculations

    static func buildPeriodSummary(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        currencyCode: String,
        allTransactionsForBalance: [TransactionItem]? = nil,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> WidgetPeriodSummary {
        // Filter transactions for the period, excluding balance adjustments
        let periodTransactions = transactions.filter { tx in
            tx.date >= periodStart && tx.date <= periodEnd && tx.balanceAdjustmentType == nil
        }

        // Calculate totals (income-aware): suprime la pata de préstamo derivada y
        // proyecta el gasto de grupo Caso A a "mi parte".
        var totalIncome: Double = 0
        var totalExpense: Double = 0
        // Magnitudes de la parte aproximada, por lado. Suman |contribución|, nunca netos: los
        // errores de dos conversiones distintas no se cancelan entre sí (mismo razonamiento que
        // `ApproximateMarkThreshold` documenta y que `CashFlowCalculator` aplica).
        var incomeApproximateMagnitude: Double = 0
        var expenseApproximateMagnitude: Double = 0
        // Denominadores del umbral y de los porcentajes de categorías: magnitudes por lado, como `CashFlowCalculator`.
        // Los totales van con signo desde el 2026-10-23, y una devolución que los encoge disparaba el cociente (la marca)
        // y pasaba de 100 % los porcentajes de las categorías, que suman magnitudes (lo cazó la review).
        var incomeTotalMagnitude: Double = 0
        var expenseTotalMagnitude: Double = 0
        // El reparto por cuenta (extragrande vertical de «Entradas y salidas») se acumula en el MISMO bucle y con la
        // misma suma, para que las cuentas sumen el neto. Las filas de producción llegan filtradas por
        // `countsForWidgets`, que exige cuenta; una sin cuenta (solo en tests que llaman aquí a pelo) no entra.
        var flowsByAccount: [PersistentIdentifier: (name: String, income: Double, expense: Double)] = [:]

        for tx in periodTransactions {
            if adjustment.isSuppressed(tx) { continue }
            // La regla de la app (`CashFlowCalculator.resolvedAmount`): el monto guardado si se
            // guardó en la divisa vigente —y entonces la señal es la del `adjustment`, que en un
            // gasto de grupo cuenta todas las patas—; si no, el nativo reconvertido con la tasa de
            // su fecha, y la señal es la de esa conversión.
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
            let amount = resolved.value
            let approximate = resolved.approximateMagnitude
            // Con signo, como el Flujo de caja de la app: una devolución en una categoría de gasto resta del gasto.
            let isIncome = isIncomeTx(tx)
            if isIncome {
                totalIncome += amount
                incomeApproximateMagnitude += approximate
                incomeTotalMagnitude += abs(amount)
            } else {
                totalExpense -= amount
                expenseApproximateMagnitude += approximate
                expenseTotalMagnitude += abs(amount)
            }
            if let account = tx.account {
                var flow = flowsByAccount[account.persistentModelID] ?? (account.name, 0, 0)
                if isIncome { flow.income += amount } else { flow.expense -= amount }
                flowsByAccount[account.persistentModelID] = flow
            }
        }

        let netCashFlow = totalIncome - totalExpense
        let accountFlows = flowsByAccount
            .map { id, flow in
                WidgetAccountFlow(
                    id: id.hashValue.description,
                    name: flow.name,
                    income: flow.income,
                    expense: flow.expense,
                    net: flow.income - flow.expense
                )
            }
            // De más a menos movimiento; a igualdad, por nombre, para que el orden no dependa del diccionario.
            .sorted {
                let lhs = abs($0.income) + abs($0.expense), rhs = abs($1.income) + abs($1.expense)
                return lhs != rhs ? lhs > rhs : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

        // Calculate historical balance at end of period
        // This is the sum of ALL transactions up to periodEnd (not just period transactions)
        // Matches TrendDataProcessor.fillBalanceBuckets logic: la fila ENTERA en su divisa nativa, y el saldo por
        // divisa valorado al cierre del período con el tipo de cambio de ese día —o, si el período llega a hoy,
        // con la regla del saldo vivo— (`BalanceValuation`). Así el saldo de un período en el widget es el último
        // punto de la curva de la app (ticket `panel-balance-chart-contradicts-its-own-figure`).
        var periodBalance: Double = 0
        // Numerador en MAGNITUDES aunque el saldo sea una resta: los errores de dos conversiones
        // distintas no se cancelan entre sí. El denominador, en cambio, es el saldo mismo — ver el
        // comentario del `return`.
        var balanceApproximateMagnitude: Double = 0
        if let allTx = allTransactionsForBalance {
            var native: [String: Decimal] = [:]
            // Las mismas filas que el saldo vivo y que la curva del widget (`LiveBalanceCalculator.entersBalance`): un
            // movimiento sin cuenta no está en ningún saldo, y contarlo aquí separaba la cifra del último punto de la
            // curva (card `tablero-la-cifra-y-la-curva-del-widget-de-saldo-zyah`).
            // Fin exclusivo: un período que cierra en 23:59:59 (todos los de `WidgetPeriod`, los en curso desde el
            // 2026-10-25) cuenta ese último segundo; uno que cierra en medianoche, no cuenta la medianoche.
            let nextSecond = periodEnd.addingTimeInterval(1)
            let exclusiveEnd = Calendar.current.startOfDay(for: nextSecond) == nextSecond ? nextSecond : periodEnd
            for tx in allTx where tx.date < exclusiveEnd && LiveBalanceCalculator.entersBalance(tx) {
                LiveBalanceCalculator.addNative(tx, to: &native)
            }
            let closing = min(periodEnd, Date.now)
            let valuation = BalanceValuation(
                currencies: Set(native.keys), to: currencyCode, closingDates: [closing], converter: converter
            )
            let converted = valuation.value(native, at: closing)
            periodBalance = (converted.total as NSDecimalNumber).doubleValue
            balanceApproximateMagnitude = (converted.approximateMagnitude as NSDecimalNumber).doubleValue
        }

        // Build top categories (expenses only, top 20 for Large widgets)
        let topCategories = buildTopCategories(
            transactions: periodTransactions,
            totalExpense: expenseTotalMagnitude,
            limit: 20,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )

        // Build top subcategories (expenses only, top 20 for Large widgets)
        let topSubcategories = buildTopSubcategories(
            transactions: periodTransactions,
            totalExpense: expenseTotalMagnitude,
            limit: 20,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )

        // Build cash flow by day
        let cashFlowPoints = buildCashFlowByDay(
            transactions: periodTransactions,
            periodStart: periodStart,
            periodEnd: periodEnd,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )

        return WidgetPeriodSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashFlow: netCashFlow,
            topCategories: topCategories,
            topSubcategories: topSubcategories,
            cashFlowPoints: cashFlowPoints,
            periodBalance: allTransactionsForBalance != nil ? periodBalance : nil,
            incomeIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude, total: incomeTotalMagnitude
            ),
            expenseIsApproximate: ApproximateMarkThreshold.marks(
                approximate: expenseApproximateMagnitude, total: expenseTotalMagnitude
            ),
            // El neto lleva la incertidumbre de los DOS lados contra el número que se muestra, no
            // el OR de las dos marcas: un ingreso grande con un 4,9 % dudoso y un gasto grande
            // exacto dejan un neto pequeño cuya incertidumbre puede superarlo, y ninguna de las
            // dos marcas por lado lo habría dicho.
            netCashFlowIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude + expenseApproximateMagnitude,
                total: netCashFlow
            ),
            // El denominador es el SALDO, no la facturación bruta que lo formó. `periodBalance` es
            // una resta —ingresos menos gastos de todo el histórico— y el contrato de
            // `ApproximateMarkThreshold` es explícito: cuando el número es una resta, el
            // denominador honesto es lo que el usuario ve. Con `Σ|monto|` la marca no salía casi
            // nunca y fallaba justo en quien más historial tiene: 400 dudosos sobre un saldo de 500
            // dan un 80 %, pero sobre una facturación de 300.000 dan un 0,13 %.
            periodBalanceIsApproximate: allTransactionsForBalance != nil
                ? ApproximateMarkThreshold.marks(
                    approximate: balanceApproximateMagnitude, total: periodBalance
                )
                // Sin `periodBalance` no hay número que marcar.
                : false,
            accountFlows: accountFlows
        )
    }

    static func buildTopCategories(
        transactions: [TransactionItem],
        totalExpense: Double,
        limit: Int,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [WidgetCategory] {
        // Group expenses by category. `category == nil` es el trozo «Sin categoría»: un gasto sin categoría (por su
        // signo) entra ahí para que el desglose sume el gasto del período (decisión A de Jürgen, 2026-10-23).
        var categoryTotals: [String: (category: Category?, amount: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !isIncomeTx(tx) else { continue }
            let category = tx.category

            let amount = abs(CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value)
            // Una clave que ningún nombre de categoría puede tener (el nombre es texto del usuario).
            let key = category?.name ?? uncategorizedWidgetKey

            if var existing = categoryTotals[key] {
                existing.amount += amount
                categoryTotals[key] = existing
            } else {
                categoryTotals[key] = (category: category, amount: amount)
            }
        }

        // Sort by amount and take top N
        let sorted = categoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.map { item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            guard let category = item.category else {
                return WidgetCategory(
                    id: uncategorizedWidgetKey,
                    name: L10n.Report.uncategorized,
                    iconName: AppConstants.uncategorizedIconName,
                    colorHex: AppConstants.uncategorizedColorHex,
                    amount: item.amount,
                    percentage: percentage
                )
            }
            return WidgetCategory(
                id: category.persistentModelID.hashValue.description,
                name: category.name,
                iconName: category.iconName ?? "folder",
                colorHex: category.colorHex,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    /// Clave y `id` del trozo «Sin categoría» en las categorías del widget. Lleva un carácter de control para que no
    /// coincida con el nombre de ninguna categoría.
    static let uncategorizedWidgetKey = "\u{1}uncategorized"

    static func buildTopSubcategories(
        transactions: [TransactionItem],
        totalExpense: Double,
        limit: Int,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [WidgetSubcategory] {
        // Group expenses by subcategory
        var subcategoryTotals: [String: (subcategory: Subcategory, category: Category, amount: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !isIncomeTx(tx) else { continue }
            guard let subcategory = tx.subcategory,
                  let category = tx.category else { continue }

            let amount = abs(CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value)
            let key = "\(category.name)_\(subcategory.name)"

            if var existing = subcategoryTotals[key] {
                existing.amount += amount
                subcategoryTotals[key] = existing
            } else {
                subcategoryTotals[key] = (subcategory: subcategory, category: category, amount: amount)
            }
        }

        // Sort by amount and take top N
        let sorted = subcategoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.map { item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetSubcategory(
                id: item.subcategory.persistentModelID.hashValue.description,
                name: item.subcategory.name,
                categoryName: item.category.name,
                iconName: item.subcategory.iconName ?? item.category.iconName,
                colorHex: item.category.colorHex,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    static func buildCashFlowByDay(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group transactions by day
        var dailyData: [Date: (income: Double, expense: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Suprime la pata de préstamo derivada (bridge): mata el ingreso fantasma +lent.
            if adjustment.isSuppressed(tx) { continue }

            let day = calendar.startOfDay(for: tx.date)
            let rawAmount = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value

            var existing = dailyData[day] ?? (income: 0, expense: 0)
            // Con signo, como los totales del período (`buildPeriodSummary`).
            if isIncomeTx(tx) {
                existing.income += rawAmount
            } else {
                existing.expense -= rawAmount
            }
            dailyData[day] = existing
        }

        // Build points for each day in period
        // For very long periods (allTime), only include days with actual transactions
        // to avoid generating millions of empty points
        var points: [WidgetCashFlowPoint] = []

        // Aquí no es un denominador sino un umbral, así que el día perdido solo importa en la
        // frontera exacta; se normaliza igual porque es la misma instancia del patrón y dejar una suelta
        // es lo que hace que el próximo barrido la encuentre como si fuera nueva.
        let daysBetween = DateIntervalDayCount.days(
            from: periodStart, to: periodEnd, calendar: calendar)
        let isLongPeriod = daysBetween > 365  // More than 1 year

        if isLongPeriod {
            // For long periods, only include days that have data
            for (day, data) in dailyData {
                points.append(WidgetCashFlowPoint(
                    date: day,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))
            }
            points.sort { $0.date < $1.date }
        } else {
            // For short periods, fill in all days (including empty ones)
            var currentDate = calendar.startOfDay(for: periodStart)
            let endDay = calendar.startOfDay(for: periodEnd)

            while currentDate <= endDay {
                let data = dailyData[currentDate] ?? (income: 0, expense: 0)
                points.append(WidgetCashFlowPoint(
                    date: currentDate,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDay
            }
        }

        return points
    }
}

/// Memo de conversiones para UN snapshot del widget.
///
/// `buildSnapshot` resuelve la misma fila en muchas superficies, y la rama de reconversión de
/// `CashFlowCalculator.resolvedAmount` llama al converter con los mismos argumentos cada vez. El
/// converter compartido lee las tasas de esa fecha del store en cada llamada, en el hilo principal.
/// Vive lo que vive el snapshot: no puede servir una tasa vieja a otro.
private final class SnapshotMemoizedConverter: CurrencyConverting {
    private struct Key: Hashable {
        let amount: Decimal
        let from: String
        let to: String
        let date: Date
    }

    private let base: CurrencyConverting
    private var checked: [Key: (amount: Decimal, quality: RateQuality)] = [:]

    init(base: CurrencyConverting) {
        self.base = base
    }

    func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
        -> (amount: Decimal, quality: RateQuality)
    {
        let key = Key(amount: amount, from: from, to: to, date: date)
        if let hit = checked[key] { return hit }
        let result = base.convertChecked(amount, from: from, to: to, on: date)
        checked[key] = result
        return result
    }

    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        convertChecked(amount, from: from, to: to, on: date).amount
    }

    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        base.convertWithLatestRate(amount, from: from, to: to)
    }

    func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
        -> (amount: Decimal, quality: RateQuality)
    {
        base.convertCheckedWithLatestRate(amount, from: from, to: to)
    }

    /// Al converter de base, que las lee en bloque: la curva del widget pide la tasa de ~300 días, y el default del
    /// protocolo las pediría una a una.
    func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]] {
        base.rateFactors(for: codes, to: to, on: dates)
    }
}
