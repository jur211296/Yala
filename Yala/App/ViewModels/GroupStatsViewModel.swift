//
//  GroupStatsViewModel.swift
//  Yala
//
//  Calcula estadísticas de un grupo: totales, quién paga más, categorías, tendencia.
//

import Foundation
import SwiftData

// MARK: - Data Models

struct MemberSpending: Identifiable {
    let id: String
    let displayName: String
    let totalPaid: Double
}

struct GroupCategoryBreakdown: Identifiable {
    var id: String { subcategoryName }
    let subcategoryName: String
    let amount: Double
    let percentage: Double
    let iconName: String
    let colorHex: String
}

struct GroupMonthlyTrend: Identifiable {
    var id: Date { month }
    let month: Date
    let totalSpent: Double
}

/// Estadísticas de UNA moneda (alimenta el carrusel del modo "Todas":
/// una página por moneda con su "quién paga" + su tendencia, sin mezclar montos).
struct GroupStatsByCurrency: Identifiable {
    var id: String { currencyCode }
    let currencyCode: String
    let memberSpending: [MemberSpending]
    let monthlyTrend: [GroupMonthlyTrend]
}

enum GroupStatsPeriod: String, CaseIterable, Identifiable {
    case thisMonth
    case last3Months
    case last6Months
    case thisYear
    case allTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thisMonth: L10n.Groups.Stats.thisMonth
        case .last3Months: L10n.Groups.Stats.last3Months
        case .last6Months: L10n.Groups.Stats.last6Months
        case .thisYear: L10n.Groups.Stats.thisYear
        case .allTime: L10n.Groups.Stats.allTime
        }
    }

    func dateInterval() -> DateInterval? {
        let calendar = Calendar.current
        let now = Date.now
        switch self {
        case .thisMonth:
            let start = calendar.startOfMonth(for: now)
            return DateInterval(start: start, end: now)
        case .last3Months:
            guard let start = calendar.date(byAdding: .month, value: -3, to: calendar.startOfMonth(for: now)) else { return nil }
            return DateInterval(start: start, end: now)
        case .last6Months:
            guard let start = calendar.date(byAdding: .month, value: -6, to: calendar.startOfMonth(for: now)) else { return nil }
            return DateInterval(start: start, end: now)
        case .thisYear:
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            return DateInterval(start: start, end: now)
        case .allTime:
            return nil
        }
    }
}

/// Filtro de moneda de las estadísticas. `.all` agrega todas las monedas
/// (donut convertido + carrusel por moneda); `.currency` filtra a una sola.
enum GroupStatsCurrencySelection: Hashable {
    case all
    case currency(String)
}

// MARK: - ViewModel

@MainActor
@Observable
final class GroupStatsViewModel {

    // MARK: - Output

    private(set) var totalSpent: Double = 0
    private(set) var myPortion: Double = 0
    private(set) var memberSpending: [MemberSpending] = []
    private(set) var categoryBreakdown: [GroupCategoryBreakdown] = []
    private(set) var monthlyTrend: [GroupMonthlyTrend] = []
    /// Stats por moneda para el carrusel del modo "Todas" (vacío en `.currency`).
    private(set) var perCurrencyStats: [GroupStatsByCurrency] = []
    /// True cuando el donut del modo "Todas" convirtió montos de otra moneda (prefijo "≈").
    private(set) var categoriesWereConverted = false
    var selectedPeriod: GroupStatsPeriod = .thisMonth

    /// Monedas con gastos en el grupo (principal primero). Con ≤1 no se muestra el selector.
    private(set) var availableCurrencies: [String] = []
    /// Filtro de moneda activo. Default: la principal del grupo (`.currency`).
    var currencySelection: GroupStatsCurrencySelection = .currency("")

    /// Código de la moneda seleccionada, o `nil` cuando el filtro es `.all`.
    var selectedCurrencyCode: String? {
        if case .currency(let code) = currencySelection { return code }
        return nil
    }

    /// True cuando el filtro es "Todas" (modo agregado multi-moneda).
    var isAllCurrencies: Bool { selectedCurrencyCode == nil }

    /// Código de moneda para formatear las secciones de moneda única.
    /// En `.all` esas secciones no se renderizan; cae a la principal como fallback.
    var activeCurrencyCode: String {
        selectedCurrencyCode ?? availableCurrencies.first ?? currencyCode
    }
    /// Total gastado y "mi parte" POR moneda (período actual, todas las monedas) — tarjetas duales.
    private(set) var totalsByCurrency: [(currencyCode: String, total: Double)] = []
    private(set) var myPortionsByCurrency: [(currencyCode: String, amount: Double)] = []

    /// True cuando el desglose tiene un único bucket "Sin categoría" (todos los
    /// gastos sin clasificar). El view muestra un hint explicativo en vez del
    /// pie chart de un solo segmento.
    var allUncategorized: Bool {
        categoryBreakdown.count == 1
            && categoryBreakdown[0].subcategoryName == L10n.Groups.Stats.uncategorized
    }

    // MARK: - Private

    private var allExpenses: [SplitExpense] = []
    private var allShares: [SplitShare] = []
    private var allMembers: [SplitMember] = []
    private var currentUserMemberID: String?
    private var currencyCode: String = ""
    /// Moneda destino del donut convertido en modo "Todas" (la preferida del usuario).
    private(set) var targetCurrency: String = ""
    private var modelContext: ModelContext?

    /// Conversor de tasas para el donut del modo "Todas". Inyectable en tests.
    @ObservationIgnored
    var converter: CurrencyConverting = CurrencyConverter.shared

    // MARK: - Load

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
    }

    func loadStats(
        expenses: [SplitExpense],
        shares: [SplitShare],
        members: [SplitMember],
        settlements: [SplitSettlement],
        currentUserMemberID: String?,
        currencyCode: String,
        preferredCurrency: String? = nil
    ) {
        self.allExpenses = expenses
        self.allShares = shares
        self.allMembers = members
        self.currentUserMemberID = currentUserMemberID
        self.currencyCode = currencyCode
        // Moneda destino del donut convertido (modo "Todas"): la preferida del usuario,
        // con la principal del grupo como fallback.
        self.targetCurrency = preferredCurrency.flatMap { $0.isEmpty ? nil : $0 } ?? currencyCode
        availableCurrencies = orderedCurrencies(Set(expenses.map(\.currencyCode)))
        // Default: "Todas" cuando hay >1 moneda; con una sola, esa moneda.
        // Preserva la selección previa del usuario si sigue siendo válida.
        currencySelection = resolvedSelection(from: currencySelection)
        recalculate()
    }

    func recalculate() {
        // Filtra por período UNA sola vez y reparte a las sub-rutinas (evita re-filtrar
        // `allExpenses` por fecha 2× en cada cambio de filtro — hot path de UI).
        let period = periodExpenses()
        if isAllCurrencies {
            recalculateAllCurrencies(period: period)
        } else {
            recalculateSingleCurrency(period: period)
        }
        recalculateDualTotals(period: period)
    }

    /// Modo `.currency`: una sola moneda (comportamiento clásico).
    private func recalculateSingleCurrency(period: [SplitExpense]) {
        let code = selectedCurrencyCode ?? currencyCode
        let filtered = period.filter { $0.currencyCode == code }
        totalSpent = filtered.reduce(0) { $0 + $1.amount }
        myPortion = computeMyPortion(in: filtered)
        memberSpending = computeMemberSpending(from: filtered)
        monthlyTrend = computeMonthlyTrend(from: filtered)
        // En moneda única todos los gastos comparten `code` → sin conversión real.
        categoryBreakdown = convertedCategoryBreakdown(filtered, target: code).breakdown
        categoriesWereConverted = false
        perCurrencyStats = []
    }

    /// Modo `.all`: donut convertido a la moneda preferida + carrusel por moneda.
    private func recalculateAllCurrencies(period: [SplitExpense]) {
        // Las secciones de moneda única no se renderizan en `.all`.
        totalSpent = 0
        myPortion = 0
        memberSpending = []
        monthlyTrend = []

        // Donut: convierte TODOS los gastos del período a la moneda preferida.
        let result = convertedCategoryBreakdown(period, target: targetCurrency)
        categoryBreakdown = result.breakdown
        categoriesWereConverted = result.wasConverted

        // Carrusel: una entrada por moneda del período, cada una con sus propios stats.
        let byCurrency = Dictionary(grouping: period, by: \.currencyCode)
        perCurrencyStats = orderedCurrencies(Set(byCurrency.keys)).map { code in
            let expensesInCurrency = byCurrency[code] ?? []
            return GroupStatsByCurrency(
                currencyCode: code,
                memberSpending: computeMemberSpending(from: expensesInCurrency),
                monthlyTrend: computeMonthlyTrend(from: expensesInCurrency)
            )
        }
    }

    /// Total gastado y "mi parte" por moneda (período actual, TODAS las monedas) → tarjetas duales.
    private func recalculateDualTotals(period: [SplitExpense]) {
        let totalsGrouped = Dictionary(grouping: period, by: \.currencyCode)
        totalsByCurrency = orderedCurrencies(Set(totalsGrouped.keys)).map { code in
            (currencyCode: code, total: totalsGrouped[code]?.reduce(0) { $0 + $1.amount } ?? 0)
        }

        guard let myID = currentUserMemberID else {
            myPortionsByCurrency = []
            return
        }
        let currencyByExpense = Dictionary(period.map { ($0.id, $0.currencyCode) }, uniquingKeysWith: { first, _ in first })
        let myShares = allShares.filter { $0.memberID == myID && currencyByExpense[$0.expenseID] != nil }
        let sharesGrouped = Dictionary(grouping: myShares, by: { currencyByExpense[$0.expenseID] ?? "" })
        myPortionsByCurrency = orderedCurrencies(Set(sharesGrouped.keys)).map { code in
            (currencyCode: code, amount: sharesGrouped[code]?.reduce(0) { $0 + $1.amount } ?? 0)
        }
    }

    // MARK: - Helpers

    /// Gastos del período (todas las monedas).
    private func periodExpenses() -> [SplitExpense] {
        guard let interval = selectedPeriod.dateInterval() else { return allExpenses }
        return allExpenses.filter { interval.contains($0.date) }
    }

    /// "Mi parte" sumada sobre un conjunto de gastos.
    private func computeMyPortion(in expenses: [SplitExpense]) -> Double {
        guard let myID = currentUserMemberID else { return 0 }
        let expenseIDs = Set(expenses.map(\.id))
        return allShares
            .filter { $0.memberID == myID && expenseIDs.contains($0.expenseID) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Gasto total pagado por cada miembro, descendente.
    private func computeMemberSpending(from expenses: [SplitExpense]) -> [MemberSpending] {
        let memberNameLookup = Dictionary(
            allMembers.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        let grouped = Dictionary(grouping: expenses, by: \.paidByMemberID)
        return grouped.map { memberID, expenses in
            MemberSpending(
                id: memberID,
                displayName: memberNameLookup[memberID] ?? memberID,
                totalPaid: expenses.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.totalPaid > $1.totalPaid }
    }

    /// Gasto agregado por mes, ascendente.
    private func computeMonthlyTrend(from expenses: [SplitExpense]) -> [GroupMonthlyTrend] {
        let calendar = Calendar.current
        let monthGrouped = Dictionary(grouping: expenses, by: { calendar.startOfMonth(for: $0.date) })
        return monthGrouped
            .map { GroupMonthlyTrend(month: $0.key, totalSpent: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }
    }

    /// Desglose por subcategoría con los montos convertidos a `target`.
    /// En moneda única (todos los gastos ya en `target`) no convierte nada y
    /// `wasConverted` es `false`; en modo "Todas" convierte cada gasto al TC actual
    /// (igual que `GroupBalanceService.consolidatedBalances`).
    private func convertedCategoryBreakdown(
        _ expenses: [SplitExpense],
        target: String
    ) -> (breakdown: [GroupCategoryBreakdown], wasConverted: Bool) {
        let wasConverted = expenses.contains { $0.currencyCode != target }
        var totalsByCategory: [String: Double] = [:]
        var grandTotal: Double = 0
        for expense in expenses {
            let name = expense.subcategoryName ?? L10n.Groups.Stats.uncategorized
            let converted = convertedAmount(expense.amount, from: expense.currencyCode, to: target)
            totalsByCategory[name, default: 0] += converted
            grandTotal += converted
        }
        let safeGrandTotal = max(grandTotal, 0.01)
        let lookup = subcategoryLookup()
        var fallbackColors: [String: String] = [:]
        let breakdown = totalsByCategory
            .map { (name: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
            .map { entry -> GroupCategoryBreakdown in
                let resolved = lookup[entry.name]
                return GroupCategoryBreakdown(
                    subcategoryName: entry.name,
                    amount: entry.total,
                    percentage: (entry.total / safeGrandTotal) * 100,
                    iconName: resolved?.icon ?? "tag.fill",
                    colorHex: resolved?.colorHex ?? fallbackColor(for: entry.name, assigned: &fallbackColors)
                )
            }
        return (breakdown, wasConverted)
    }

    /// Convierte un monto entre monedas con el TC actual (defensa contra no-finitos,
    /// igual que `GroupBalanceService`).
    private func convertedAmount(_ amount: Double, from: String, to: String) -> Double {
        if from == to { return amount }
        let safe = Decimal(amount.isFinite ? amount : 0)
        let result = converter.convertWithLatestRate(safe, from: from, to: to)
        return NSDecimalNumber(decimal: result).doubleValue
    }

    /// Resuelve el filtro de moneda al cargar: preserva la selección previa si es
    /// válida; si no, default a "Todas" con multi-moneda o a la única disponible.
    private func resolvedSelection(from current: GroupStatsCurrencySelection) -> GroupStatsCurrencySelection {
        switch current {
        case .all where availableCurrencies.count > 1:
            return .all
        case .currency(let code) where !code.isEmpty && availableCurrencies.contains(code):
            return .currency(code)
        default:
            return availableCurrencies.count > 1 ? .all : .currency(availableCurrencies.first ?? currencyCode)
        }
    }

    /// Ordena monedas con la principal del grupo primero, luego alfabético.
    private func orderedCurrencies(_ codes: Set<String>) -> [String] {
        codes.sorted { lhs, rhs in
            if lhs == currencyCode { return true }
            if rhs == currencyCode { return false }
            return lhs < rhs
        }
    }

    /// Lookup `[nombre de subcategoría: (icono, colorHex)]` desde las subcategorías locales,
    /// para colorear el donut con los mismos iconos/colores que el resto de la app.
    private func subcategoryLookup() -> [String: (icon: String, colorHex: String)] {
        guard let ctx = modelContext else { return [:] }
        do {
            let subs = try ctx.fetch(FetchDescriptor<Subcategory>())
            var dict: [String: (icon: String, colorHex: String)] = [:]
            for sub in subs where dict[sub.name] == nil {
                let icon = sub.iconName ?? sub.safeCategory.iconName ?? "tag.fill"
                dict[sub.name] = (icon, sub.colorHex ?? sub.safeCategory.colorHex)
            }
            return dict
        } catch {
            #if DEBUG
            print("GroupStatsViewModel: error fetching subcategories: \(error)")
            #endif
            return [:]
        }
    }

    /// Color de fallback determinístico para nombres sin subcategoría local (p. ej. del
    /// creador del gasto, que el usuario no tiene): paleta estable por orden de aparición.
    private static let fallbackPalette = ["#6366F1", "#EC4899", "#06B6D4", "#F59E0B", "#10B981", "#8B5CF6", "#EF4444", "#14B8A6"]
    private func fallbackColor(for name: String, assigned: inout [String: String]) -> String {
        if let existing = assigned[name] { return existing }
        let color = Self.fallbackPalette[assigned.count % Self.fallbackPalette.count]
        assigned[name] = color
        return color
    }
}

