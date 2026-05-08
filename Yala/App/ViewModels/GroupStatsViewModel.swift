//
//  GroupStatsViewModel.swift
//  Yala
//
//  Calcula estadísticas de un grupo: totales, quién paga más, categorías, tendencia.
//

import Foundation

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

    // MARK: - Load

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
        categoryBreakdown = catTotals
            .sorted { $0.total > $1.total }
            .map { GroupCategoryBreakdown(subcategoryName: $0.name, amount: $0.total, percentage: ($0.total / grandTotal) * 100) }

        let calendar = Calendar.current
        let monthGrouped = Dictionary(grouping: filtered, by: { calendar.startOfMonth(for: $0.date) })
        monthlyTrend = monthGrouped
            .map { GroupMonthlyTrend(month: $0.key, totalSpent: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }
    }

    // MARK: - Helpers

    private func filteredExpenses() -> [SplitExpense] {
        // Filter by group currency
        var result = allExpenses.filter { $0.currencyCode == currencyCode }

        // Filter by period
        if let interval = selectedPeriod.dateInterval() {
            result = result.filter { interval.contains($0.date) }
        }

        return result
    }
}

