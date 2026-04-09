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

    var activeSheet: GroupSheet?

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

    func confirmSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.confirmSettlement(settlement, in: group)
            TelemetryService.track(.groupSettlementConfirmed)
            DS.Haptic.success()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error confirming settlement: \(error)")
            #endif
        }
    }

    func rejectSettlement(_ settlement: SplitSettlement) {
        do {
            try GroupExpenseService.shared.deleteSettlement(settlement, in: group)
            TelemetryService.track(.groupSettlementRejected)
            DS.Haptic.warning()
            loadData()
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error rejecting settlement: \(error)")
            #endif
        }
    }

    func sharesForExpense(_ expense: SplitExpense) -> [SplitShare] {
        shares.filter { $0.expenseID == expense.id }
    }

    // MARK: - Share Link

    private(set) var shareURL: URL?
    var isCreatingShare = false

    func createShareLink() async {
        guard !isCreatingShare else { return }
        if shareURL != nil { return }
        isCreatingShare = true
        do {
            let (_, ckURL) = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            if let ckURL {
                shareURL = buildBrandedInviteURL(from: ckURL)
            }
        } catch {
            #if DEBUG
            print("GroupDetailViewModel: Error creating share: \(error)")
            #endif
        }
        isCreatingShare = false
    }

    private func buildBrandedInviteURL(from ckURL: URL) -> URL {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let inviterName = name.isEmpty ? L10n.Profile.defaultName : name
        return InviteLinkService.buildInviteURL(
            shareURL: ckURL,
            group: group,
            members: members,
            inviterName: inviterName
        ) ?? ckURL
    }
}

// MARK: - Sheet Enum

enum GroupSheet: Identifiable {
    case settings
    case addExpense
    case editExpense(SplitExpense)
    case settlement(Debt)

    var id: String {
        switch self {
        case .settings: "settings"
        case .addExpense: "addExpense"
        case .editExpense(let e): "editExpense-\(e.id)"
        case .settlement(let d): "settlement-\(d.id)"
        }
    }
}
