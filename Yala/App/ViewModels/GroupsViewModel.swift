//
//  GroupsViewModel.swift
//  Yala
//
//  ViewModel for the Groups tab — list, global summary, per-group balances.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var groups: [SplitGroup] = []
    private(set) var membersByGroup: [String: [SplitMember]] = [:]       // zoneID → members
    private(set) var balancesByGroup: [String: [MemberBalance]] = [:]    // zoneID → balances
    private(set) var globalSummary: GroupGlobalSummary?

    // MARK: - UI State

    var showCreateGroup: Bool = false
    var selectedGroup: SplitGroup?
    var showGroupDetail: Bool = false
    var searchText: String = ""

    // MARK: - Computed

    var activeGroups: [SplitGroup] {
        groups.filter { !$0.isArchived }
    }

    var archivedGroups: [SplitGroup] {
        groups.filter { $0.isArchived }
    }

    var filteredGroups: [SplitGroup] {
        let base = activeGroups
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { $0.name.lowercased().contains(query) }
    }

    var showArchived: Bool = false

    // MARK: - Context

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard modelContext != nil else { return }

        do {
            groups = try GroupService.shared.fetchAllGroups()

            // Per-group data
            var allExpenses: [SplitExpense] = []
            var allShares: [SplitShare] = []
            var allSettlements: [SplitSettlement] = []
            var currentUserMemberIDs = Set<String>()

            for group in groups {
                let members = try GroupService.shared.fetchMembers(for: group)
                membersByGroup[group.cloudKitZoneID] = members

                // Skip heavy data loading for archived groups
                guard !group.isArchived else { continue }

                let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
                let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
                let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

                let balances = GroupBalanceService.calculateBalances(
                    expenses: expenses,
                    shares: shares,
                    members: members,
                    settlements: settlements
                )
                balancesByGroup[group.cloudKitZoneID] = balances

                allExpenses.append(contentsOf: expenses)
                allShares.append(contentsOf: shares)
                allSettlements.append(contentsOf: settlements)

                for member in members where member.isCurrentUser && member.isActive {
                    currentUserMemberIDs.insert(member.id.uuidString)
                }
            }

            // Global summary
            if !groups.isEmpty {
                globalSummary = GroupBalanceService.globalSummary(
                    allExpenses: allExpenses,
                    allShares: allShares,
                    allSettlements: allSettlements,
                    currentUserMemberIDs: currentUserMemberIDs
                )
            } else {
                globalSummary = nil
            }
        } catch {
            #if DEBUG
            print("GroupsViewModel: Error loading data: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Get the current user's net balance for a specific group.
    func currentUserBalance(for group: SplitGroup) -> MemberBalance? {
        guard let balances = balancesByGroup[group.cloudKitZoneID],
              let members = membersByGroup[group.cloudKitZoneID],
              let currentMember = members.first(where: { $0.isCurrentUser }) else {
            return nil
        }
        let memberID = currentMember.id.uuidString
        return balances.first { $0.memberID == memberID }
    }

    /// Member count for a group.
    func memberCount(for group: SplitGroup) -> Int {
        membersByGroup[group.cloudKitZoneID]?.filter(\.isActive).count ?? 0
    }

    /// Pending approval member count for a group. Returns 0 for archived groups
    /// (UX: nadie aprueba pending en un grupo archivado; mostrar el badge sobre
    /// card opacity-0.6 sería confuso).
    func pendingMemberCount(for group: SplitGroup) -> Int {
        guard !group.isArchived else { return 0 }
        return membersByGroup[group.cloudKitZoneID]?.filter(\.isPendingApproval).count ?? 0
    }

    /// Status del current user en el grupo. Drives `GroupCardView.displayMode`
    /// para mostrar chip pending/rejected en lugar del balance trailing.
    func currentMemberStatus(for group: SplitGroup) -> SplitMemberStatus? {
        membersByGroup[group.cloudKitZoneID]?
            .first(where: { $0.isCurrentUser })?
            .memberStatus
    }

    // MARK: - Actions

    func archiveGroup(_ group: SplitGroup) {
        do {
            try GroupService.shared.setArchived(group, isArchived: true)
            loadData()
        } catch {
            #if DEBUG
            print("GroupsViewModel: Error archiving group: \(error)")
            #endif
        }
    }

    /// Open group detail via isPresented binding.
    func openDetail(for group: SplitGroup) {
        selectedGroup = group
        showGroupDetail = true
    }
}
