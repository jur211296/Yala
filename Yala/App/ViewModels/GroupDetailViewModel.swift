//
//  GroupDetailViewModel.swift
//  Yala
//
//  ViewModel for a single group's detail — expenses, balances, debts, members.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupDetailViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    let group: SplitGroup

    // MARK: - Data

    private(set) var members: [SplitMember] = []
    private(set) var expenses: [SplitExpense] = []
    private(set) var shares: [SplitShare] = []
    private(set) var settlements: [SplitSettlement] = []
    private(set) var balances: [MemberBalance] = []
    private(set) var debts: [Debt] = []

    // MARK: - Computed

    /// memberID.uuidString → displayName (rebuilt in loadData)
    private(set) var memberNameLookup: [String: String] = [:]

    var currentUserMember: SplitMember? {
        members.first { $0.isCurrentUser }
    }

    var isCurrentUserAdmin: Bool {
        currentUserMember?.role == "admin"
    }

    // MARK: - UI State

    var showSettings: Bool = false
    var showAddExpense: Bool = false

    // MARK: - Init

    init(group: SplitGroup) {
        self.group = group
    }

    // MARK: - Context

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard modelContext != nil else { return }

        do {
            members = try GroupService.shared.fetchMembers(for: group)
            memberNameLookup = Dictionary(
                members.map { ($0.id.uuidString, $0.displayName) },
                uniquingKeysWith: { first, _ in first }
            )
            expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
            shares = try GroupExpenseService.shared.fetchAllShares(for: group)
            settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

            balances = GroupBalanceService.calculateBalances(
                expenses: expenses,
                shares: shares,
                members: members,
                settlements: settlements
            )

            debts = GroupBalanceService.calculateDebts(
                expenses: expenses,
                shares: shares,
                settlements: settlements,
                simplifyDebts: group.simplifyDebts
            )
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error loading data: \(error)")
            #endif
        }
    }

    // MARK: - Actions

    func deleteExpense(_ expense: SplitExpense) {
        do {
            try GroupExpenseService.shared.deleteExpense(expense, in: group)
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error deleting expense: \(error)")
            #endif
        }
    }

    /// Name for a member ID, with fallback.
    func memberName(for memberID: String) -> String {
        memberNameLookup[memberID] ?? memberID
    }
}
