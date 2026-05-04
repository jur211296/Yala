//
//  GroupService.swift
//  Yala
//
//  CRUD for groups and members.
//  Creates CKRecordZones via SplitZoneManager and enqueues sync via SplitSyncManager.
//

import CloudKit
import Foundation
import SwiftData
import os.log

@MainActor
@Observable
final class GroupService {

    // MARK: - Singleton

    static let shared = GroupService()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.yala", category: "GroupService")

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw GroupServiceError.noContext
        }
        return context
    }

    // MARK: - Group CRUD

    /// Create a new group with the current user as admin.
    @discardableResult
    func createGroup(
        name: String,
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String = "PEN",
        simplifyDebts: Bool = false,
        showDebtsInSingleCurrency: Bool = false,
        defaultSplitType: String = "equal",
        membersCanInvite: Bool = false
    ) async throws -> SplitGroup {
        let context = try requireContext()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyName }

        let recordName = try await GroupUserIdentityService.shared.currentUserRecordName()

        let group = SplitGroup(
            name: trimmedName,
            iconName: iconName,
            colorHex: colorHex,
            currencyCode: currencyCode,
            simplifyDebts: simplifyDebts,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
            defaultSplitType: defaultSplitType,
            membersCanInvite: membersCanInvite
        )
        group.isOwner = true
        context.insert(group)

        // Create CK zone + GroupMeta root record
        SplitZoneManager(syncManager: .shared).createZone(for: group)

        // Add current user as admin member
        let member = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: currentUserDisplayName(),
            cloudKitUserRecordID: recordName,
            role: "admin",
            isGroupOwner: true,
            isCurrentUser: true
        )
        member.id = GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember",
            name: "\(group.cloudKitZoneID):\(recordName)"
        )
        context.insert(member)
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        TelemetryService.track(.groupCreated, parameters: ["memberCount": "1"])
        NudgeService.shared.recordGroupJoinIfNeeded()

        #if DEBUG
        logger.info("Created group '\(trimmedName)' with zone \(group.cloudKitZoneID)")
        #endif

        return group
    }

    /// Update group metadata.
    func updateGroup(
        _ group: SplitGroup,
        name: String,
        iconName: String,
        colorHex: String,
        currencyCode: String,
        simplifyDebts: Bool,
        showDebtsInSingleCurrency: Bool,
        defaultSplitType: String,
        membersCanInvite: Bool
    ) throws {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyName }

        group.name = trimmedName
        group.iconName = iconName
        group.colorHex = colorHex
        group.currencyCode = currencyCode
        group.simplifyDebts = simplifyDebts
        group.showDebtsInSingleCurrency = showDebtsInSingleCurrency
        group.defaultSplitType = defaultSplitType
        group.membersCanInvite = membersCanInvite

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: group.id, group: group)
    }

    /// Archive or unarchive a group.
    func setArchived(_ group: SplitGroup, isArchived: Bool) throws {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)
        group.isArchived = isArchived

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Delete a group permanently (owner only).
    /// Cascades: deletes zone, all local models, and unbridges personal records.
    func deleteGroup(_ group: SplitGroup, allowDestructiveDelete: Bool = false) throws {
        let context = try requireContext()

        #if DEBUG
        guard allowDestructiveDelete else { throw GroupServiceError.deleteDisabled }
        #else
        throw GroupServiceError.deleteDisabled
        #endif

        guard group.isOwner else { throw GroupServiceError.notOwner }

        // Delete CK zone (cascade deletes all remote records)
        SplitZoneManager(syncManager: .shared).deleteZone(for: group)

        // Unbridge personal TX/Drafts before deleting expenses
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.unbridgeExpenses(for: group)
            } catch {
                #if DEBUG
                logger.error("Failed to unbridge expenses: \(error)")
                #endif
            }
        }

        try cascadeDeleteGroupData(zoneName: group.cloudKitZoneID, context: context)
        GroupPersonalPreferences.removeAll(for: group.cloudKitZoneID)
        context.delete(group)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        TelemetryService.track(.groupDeleted)
    }

    // MARK: - Member Management

    /// Add a member to a group.
    @discardableResult
    func addMember(
        to group: SplitGroup,
        displayName: String,
        role: String = "member"
    ) throws -> SplitMember {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyMemberName }
        guard role == "admin" || role == "member" else { throw GroupServiceError.invalidRole }

        let member = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: trimmedName,
            role: role
        )
        context.insert(member)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)

        return member
    }

    /// Remove a member from a group.
    func removeMember(_ member: SplitMember, from group: SplitGroup) throws {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard !member.isCurrentUser else { throw GroupServiceError.cannotRemoveSelf }
        guard !member.isGroupOwner else { throw GroupServiceError.ownerMemberImmutable }
        guard member.isActive else { return }

        if try memberHasOutstandingBalance(member, in: group) {
            throw GroupServiceError.outstandingBalance
        }

        // Cannot remove the last admin
        if member.role == "admin" {
            let adminCount = try activeAdminCount(in: group, context: context)
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        member.memberStatus = .removed
        member.isCurrentUser = false

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
    }

    /// Change a member's role.
    func changeRole(_ member: SplitMember, to newRole: String, in group: SplitGroup) throws {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard newRole == "admin" || newRole == "member" else { throw GroupServiceError.invalidRole }
        guard member.isActive else { throw GroupServiceError.inactiveMember }
        guard !member.isGroupOwner || newRole == "admin" else { throw GroupServiceError.ownerMemberImmutable }

        // Cannot demote the last admin
        if member.role == "admin" && newRole == "member" {
            let adminCount = try activeAdminCount(in: group, context: context)
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        member.role = newRole

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
    }

    /// Current user leaves a group they were invited to (non-owner).
    func leaveGroup(_ group: SplitGroup) async throws {
        let context = try requireContext()

        guard !group.isOwner else { throw GroupServiceError.ownerCannotLeave }

        // Splitwise-like rule: only allow leaving once the user's balance is 0 in the group.
        let currentMember = try await ensureCurrentUserMemberExists(in: group, reactivateInactive: false)
        let balances = try memberBalances(in: group, memberID: currentMember.id.uuidString)
        if balances.contains(where: { abs($0.netBalance) > 0.01 }) {
            throw GroupServiceError.outstandingBalance
        }

        if currentMember.isActive {
            currentMember.memberStatus = .left
            currentMember.isCurrentUser = true
            SplitSyncManager.shared.enqueueSave(modelID: currentMember.id, group: group)
            do {
                try context.save()
            } catch {
                throw GroupServiceError.saveFailed(error)
            }
            try await SplitSyncManager.shared.sendPendingChanges(for: group)
        }

        // Stop receiving future updates by leaving the CloudKit share (shared DB).
        try await SplitZoneManager(syncManager: .shared).leaveShare(for: group)

        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.unbridgeExpenses(for: group)
            } catch {
                #if DEBUG
                logger.error("Failed to unbridge expenses: \(error)")
                #endif
            }
        }

        try cascadeDeleteGroupData(zoneName: group.cloudKitZoneID, context: context)
        GroupPersonalPreferences.removeAll(for: group.cloudKitZoneID)
        context.delete(group)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Current User Identity / Membership

    /// Ensures there is a SplitMember for the current iCloud user in the given group.
    /// Returns the member representing the current user.
    func ensureCurrentUserMemberExists(in group: SplitGroup, reactivateInactive: Bool = true) async throws -> SplitMember {
        let context = try requireContext()
        let recordName = try await GroupUserIdentityService.shared.currentUserRecordName()

        let members = try fetchMembers(for: group)
        if let existing = members.first(where: { !$0.cloudKitUserRecordID.isEmpty && $0.cloudKitUserRecordID == recordName }) {
            var changed = false
            if !existing.isCurrentUser {
                existing.isCurrentUser = true
                changed = true
            }
            if reactivateInactive && !existing.isActive {
                existing.memberStatus = .active
                changed = true
            }
            if group.isOwner && !existing.isGroupOwner {
                existing.isGroupOwner = true
                existing.role = "admin"
                changed = true
            }
            if changed {
                SplitSyncManager.shared.enqueueSave(modelID: existing.id, group: group)
                do {
                    try context.save()
                } catch {
                    throw GroupServiceError.saveFailed(error)
                }
            }
            return existing
        }

        // Legacy fallback: if a local member is marked as current user but missing a record ID, backfill it.
        if let legacy = members.first(where: { $0.isCurrentUser }) {
            guard reactivateInactive || legacy.isActive else { return legacy }
            if legacy.cloudKitUserRecordID.isEmpty {
                legacy.cloudKitUserRecordID = recordName
                if reactivateInactive {
                    legacy.memberStatus = .active
                }
                if group.isOwner {
                    legacy.isGroupOwner = true
                    legacy.role = "admin"
                }
                SplitSyncManager.shared.enqueueSave(modelID: legacy.id, group: group)
                do {
                    try context.save()
                } catch {
                    throw GroupServiceError.saveFailed(error)
                }
            }
            return legacy
        }

        // Migration fallback: infer the current user member from legacy records with missing identity.
        let candidates = members.filter { $0.cloudKitUserRecordID.isEmpty }
        if !candidates.isEmpty {
            let localDisplayName = currentUserDisplayName()
            let nameMatches = candidates.filter { $0.displayName == localDisplayName }
            if nameMatches.count == 1, let candidate = nameMatches.first {
                guard reactivateInactive || candidate.isActive else { return candidate }
                candidate.cloudKitUserRecordID = recordName
                candidate.isCurrentUser = true
                if reactivateInactive {
                    candidate.memberStatus = .active
                }
                SplitSyncManager.shared.enqueueSave(modelID: candidate.id, group: group)
                do {
                    try context.save()
                } catch {
                    throw GroupServiceError.saveFailed(error)
                }
                return candidate
            }

            if group.isOwner {
                let admins = candidates.filter { $0.role == "admin" }
                let candidate = (admins.count == 1 ? admins.first : candidates.min(by: { $0.joinedAt < $1.joinedAt }))
                if let candidate {
                    guard reactivateInactive || candidate.isActive else { return candidate }
                    candidate.cloudKitUserRecordID = recordName
                    candidate.isCurrentUser = true
                    candidate.isGroupOwner = true
                    candidate.role = "admin"
                    if reactivateInactive {
                        candidate.memberStatus = .active
                    }
                    SplitSyncManager.shared.enqueueSave(modelID: candidate.id, group: group)
                    do {
                        try context.save()
                    } catch {
                        throw GroupServiceError.saveFailed(error)
                    }
                    return candidate
                }
            }
        }

        guard reactivateInactive else { throw GroupServiceError.currentUserMemberNotFound }

        // Create a new member record for the current user.
        let zoneID = group.cloudKitZoneID
        let member = SplitMember(
            groupZoneID: zoneID,
            displayName: currentUserDisplayName(),
            cloudKitUserRecordID: recordName,
            role: "member",
            isCurrentUser: true
        )
        member.id = GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember",
            name: "\(zoneID):\(recordName)"
        )

        context.insert(member)
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
        try context.save()
        SessionState.shared.incrementDataVersion()
        return member
    }

    /// Recomputes `SplitMember.isCurrentUser` across all groups from `cloudKitUserRecordID`.
    func refreshCurrentUserFlags() async {
        guard let context = modelContext else { return }
        let recordName: String
        if let cached = GroupUserIdentityService.shared.cachedRecordName, !cached.isEmpty {
            recordName = cached
        } else if let fetched = try? await GroupUserIdentityService.shared.currentUserRecordName(), !fetched.isEmpty {
            recordName = fetched
        } else {
            return
        }

        do {
            let allGroups = try context.fetch(FetchDescriptor<SplitGroup>())
            let groupsByZone = Dictionary(allGroups.map { ($0.cloudKitZoneID, $0) }, uniquingKeysWith: { first, _ in first })

            let members = try context.fetch(FetchDescriptor<SplitMember>())
            let membersByZone = Dictionary(grouping: members, by: \.groupZoneID)
            var changed = false

            // Migration: older builds could create current-user members without `cloudKitUserRecordID`.
            // Try to infer and backfill once per group, so other devices can identify the same user.
            let localDisplayName = currentUserDisplayName()
            for group in allGroups {
                guard let zoneMembers = membersByZone[group.cloudKitZoneID] else { continue }
                guard !zoneMembers.contains(where: { $0.cloudKitUserRecordID == recordName }) else { continue }

                let candidates = zoneMembers.filter { $0.cloudKitUserRecordID.isEmpty }
                guard !candidates.isEmpty else { continue }

                // Safe heuristic for any group: unique displayName match.
                let nameMatches = candidates.filter { $0.displayName == localDisplayName }
                if nameMatches.count == 1, let candidate = nameMatches.first {
                    candidate.cloudKitUserRecordID = recordName
                    SplitSyncManager.shared.enqueueSave(modelID: candidate.id, group: group)
                    changed = true
                    continue
                }

                // Owner groups: prefer the single admin, else earliest join.
                guard group.isOwner else { continue }
                let admins = candidates.filter { $0.role == "admin" }
                let candidate = (admins.count == 1 ? admins.first : candidates.min(by: { $0.joinedAt < $1.joinedAt }))
                if let candidate {
                    candidate.cloudKitUserRecordID = recordName
                    SplitSyncManager.shared.enqueueSave(modelID: candidate.id, group: group)
                    changed = true
                }
            }

            for member in members {
                // Backfill legacy "current user" members that were created without a CloudKit identity.
                if member.isCurrentUser && member.cloudKitUserRecordID.isEmpty {
                    member.cloudKitUserRecordID = recordName
                    if let group = groupsByZone[member.groupZoneID] {
                        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
                    }
                    changed = true
                }

                let shouldBeCurrent = !recordName.isEmpty && member.cloudKitUserRecordID == recordName
                if member.isCurrentUser != shouldBeCurrent {
                    member.isCurrentUser = shouldBeCurrent
                    changed = true
                }

                if shouldBeCurrent,
                   let group = groupsByZone[member.groupZoneID],
                   group.isOwner,
                   !member.isGroupOwner
                {
                    member.isGroupOwner = true
                    member.role = "admin"
                    SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
                    changed = true
                }
            }
            if changed {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
        } catch {
            #if DEBUG
            logger.error("refreshCurrentUserFlags: Failed: \(error)")
            #endif
        }
    }

    private func memberBalances(in group: SplitGroup, memberID: String) throws -> [MemberBalance] {
        let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
        let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
        let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)
        let members = try fetchMembers(for: group)

        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements
        )

        return balances.filter { $0.memberID == memberID }
    }

    private func memberHasOutstandingBalance(_ member: SplitMember, in group: SplitGroup) throws -> Bool {
        let balances = try memberBalances(in: group, memberID: member.id.uuidString)
        return balances.contains { abs($0.netBalance) > 0.01 }
    }

    private func requireCurrentUserAdmin(in group: SplitGroup, context: ModelContext) throws {
        let members = try fetchMembers(for: group)
        if let current = members.first(where: { $0.isCurrentUser }) {
            guard current.isActive else { throw GroupServiceError.inactiveMember }
            guard current.role == "admin" else { throw GroupServiceError.adminRequired }
            return
        }
        guard group.isOwner else { throw GroupServiceError.adminRequired }
    }

    private func activeAdminCount(in group: SplitGroup, context: ModelContext) throws -> Int {
        let zoneName = group.cloudKitZoneID
        let adminDesc = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName && $0.role == "admin" }
        )
        return try context.fetch(adminDesc).filter(\.isActive).count
    }

    // MARK: - Cascade Delete

    /// Delete all local models for a group zone (members, expenses, shares, settlements).
    /// Does NOT delete the group itself or save the context.
    private func cascadeDeleteGroupData(zoneName: String, context: ModelContext) throws {
        let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for member in try context.fetch(memberDesc) { context.delete(member) }

        let shareDesc = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for share in try context.fetch(shareDesc) { context.delete(share) }

        let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for expense in try context.fetch(expenseDesc) { context.delete(expense) }

        let settlementDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for settlement in try context.fetch(settlementDesc) { context.delete(settlement) }
    }

    // MARK: - Fetch Helpers

    /// Fetch all non-archived groups.
    func fetchActiveGroups() throws -> [SplitGroup] {
        let context = try requireContext()
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch all groups (including archived).
    func fetchAllGroups() throws -> [SplitGroup] {
        let context = try requireContext()
        let descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch members for a group.
    func fetchMembers(for group: SplitGroup) throws -> [SplitMember] {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor).sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            if lhs.memberStatus != rhs.memberStatus {
                return statusSortOrder(lhs.memberStatus) < statusSortOrder(rhs.memberStatus)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    // MARK: - User Display Name

    private func currentUserDisplayName() -> String {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        return name.isEmpty ? "Usuario" : name
    }

    private func statusSortOrder(_ status: SplitMemberStatus) -> Int {
        switch status {
        case .active: 0
        case .left: 1
        case .removed: 2
        }
    }
}

// MARK: - Errors

enum GroupServiceError: LocalizedError {
    case noContext
    case emptyName
    case emptyMemberName
    case invalidRole
    case notOwner
    case adminRequired
    case ownerCannotLeave
    case lastAdmin
    case outstandingBalance
    case inactiveMember
    case memberNotInGroup
    case cannotRemoveSelf
    case ownerMemberImmutable
    case currentUserMemberNotFound
    case deleteDisabled
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupService: No ModelContext available"
        case .emptyName:
            return "GroupService: Group name cannot be empty"
        case .emptyMemberName:
            return "GroupService: Member name cannot be empty"
        case .invalidRole:
            return "GroupService: Role must be 'admin' or 'member'"
        case .notOwner:
            return "GroupService: Only the group owner can perform this action"
        case .adminRequired:
            return "GroupService: Only group admins can perform this action"
        case .ownerCannotLeave:
            return "GroupService: Owner cannot leave their own group"
        case .lastAdmin:
            return "GroupService: Cannot remove or demote the last admin"
        case .outstandingBalance:
            return "GroupService: Cannot leave or remove a member with a non-zero balance"
        case .inactiveMember:
            return "GroupService: Inactive members cannot perform this action"
        case .memberNotInGroup:
            return "GroupService: Member does not belong to this group"
        case .cannotRemoveSelf:
            return "GroupService: Use leave group instead of removing yourself"
        case .ownerMemberImmutable:
            return "GroupService: The group owner cannot be removed or demoted"
        case .currentUserMemberNotFound:
            return "GroupService: Current user member was not found in this group"
        case .deleteDisabled:
            return "GroupService: Permanent group deletion is disabled; archive groups instead"
        case .saveFailed(let error):
            return "GroupService: Save failed - \(error.localizedDescription)"
        }
    }
}
