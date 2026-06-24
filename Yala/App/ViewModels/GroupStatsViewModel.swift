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
    var selectedPeriod: GroupStatsPeriod = .thisMonth

    /// Monedas con gastos en el grupo (principal primero). Con ≤1 no se muestra el selector.
    private(set) var availableCurrencies: [String] = []
    /// Moneda activa para donut / quién paga / tendencia. Default: la principal del grupo.
    var selectedCurrency: String = ""
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
    private var modelContext: ModelContext?

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
        currencyCode: String
    ) {
        self.allExpenses = expenses
        self.allShares = shares
        self.allMembers = members
        self.currentUserMemberID = currentUserMemberID
        self.currencyCode = currencyCode
        availableCurrencies = orderedCurrencies(Set(expenses.map(\.currencyCode)))
        // Preserva la selección del usuario si sigue siendo válida; si no, la principal
        // (o la primera con gastos si la principal no tiene movimientos).
        if selectedCurrency.isEmpty || !availableCurrencies.contains(selectedCurrency) {
            selectedCurrency = availableCurrencies.first ?? currencyCode
        }
        recalculate()
    }

    func recalculate() {
        let filtered = filteredExpenses()

        totalSpent = filtered.reduce(0) { $0 + $1.amount }

        if let myID = currentUserMemberID {
            let expenseIDs = Set(filtered.map(\.id))
            myPortion = allShares
                .filter { $0.memberID == myID && expenseIDs.contains($0.expenseID) }
                .reduce(0) { $0 + $1.amount }
        } else {
            myPortion = 0
        }

        let memberNameLookup = Dictionary(
            allMembers.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        let grouped = Dictionary(grouping: filtered, by: \.paidByMemberID)
        memberSpending = grouped.map { memberID, expenses in
            MemberSpending(
                id: memberID,
                displayName: memberNameLookup[memberID] ?? memberID,
                totalPaid: expenses.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.totalPaid > $1.totalPaid }

        let catGrouped = Dictionary(grouping: filtered, by: { $0.subcategoryName ?? L10n.Groups.Stats.uncategorized })
        let catTotals = catGrouped.map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        let grandTotal = max(totalSpent, 0.01)
        let lookup = subcategoryLookup()
        var fallbackColors: [String: String] = [:]
        categoryBreakdown = catTotals
            .sorted { $0.total > $1.total }
            .map { entry in
                let resolved = lookup[entry.name]
                return GroupCategoryBreakdown(
                    subcategoryName: entry.name,
                    amount: entry.total,
                    percentage: (entry.total / grandTotal) * 100,
                    iconName: resolved?.icon ?? "tag.fill",
                    colorHex: resolved?.colorHex ?? fallbackColor(for: entry.name, assigned: &fallbackColors)
                )
            }

        let calendar = Calendar.current
        let monthGrouped = Dictionary(grouping: filtered, by: { calendar.startOfMonth(for: $0.date) })
        monthlyTrend = monthGrouped
            .map { GroupMonthlyTrend(month: $0.key, totalSpent: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }

        recalculateDualTotals()
    }

    /// Total gastado y "mi parte" por moneda (período actual, TODAS las monedas) → tarjetas duales.
    private func recalculateDualTotals() {
        let period = periodExpenses()
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

    /// Gastos del período en la moneda seleccionada (alimenta donut / quién paga / tendencia).
    private func filteredExpenses() -> [SplitExpense] {
        periodExpenses().filter { $0.currencyCode == selectedCurrency }
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

