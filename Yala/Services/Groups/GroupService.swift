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
        if cachedDisplayName == nil {
            Task { await refreshUserDisplayName() }
        }
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
        membersCanInvite: Bool = true
    ) throws -> SplitGroup {
        let context = try requireContext()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyName }

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
        SplitZoneManager().createZone(for: group)

        // Add current user as admin member
        let member = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: currentUserDisplayName(),
            role: "admin",
            isCurrentUser: true
        )
        context.insert(member)
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()

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
    func deleteGroup(_ group: SplitGroup) throws {
        let context = try requireContext()

        guard group.isOwner else { throw GroupServiceError.notOwner }

        // Delete CK zone (cascade deletes all remote records)
        SplitZoneManager().deleteZone(for: group)

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

        // Cannot remove the last admin
        if member.role == "admin" {
            let zoneName = group.cloudKitZoneID
            let adminDesc = FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneName && $0.role == "admin" }
            )
            let adminCount = try context.fetch(adminDesc).count
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        SplitSyncManager.shared.enqueueDeletion(modelID: member.id, group: group)
        context.delete(member)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Change a member's role.
    func changeRole(_ member: SplitMember, to newRole: String, in group: SplitGroup) throws {
        let context = try requireContext()

        guard newRole == "admin" || newRole == "member" else { throw GroupServiceError.invalidRole }

        // Cannot demote the last admin
        if member.role == "admin" && newRole == "member" {
            let zoneName = group.cloudKitZoneID
            let adminDesc = FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneName && $0.role == "admin" }
            )
            let adminCount = try context.fetch(adminDesc).count
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
    func leaveGroup(_ group: SplitGroup) throws {
        let context = try requireContext()

        guard !group.isOwner else { throw GroupServiceError.ownerCannotLeave }

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

    // MARK: - Cascade Delete

    /// Delete all local models for a group zone (members, expenses, shares, settlements).
    /// Does NOT delete the group itself or save the context.
    private func cascadeDeleteGroupData(zoneName: String, context: ModelContext) throws {
        let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for member in try context.fetch(memberDesc) { context.delete(member) }

        let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
        let expenses = try context.fetch(expenseDesc)

        // SplitShare has no groupZoneID — filter in memory (Set.contains not supported in #Predicate)
        let expenseIDs = Set(expenses.map(\.id))
        if !expenseIDs.isEmpty {
            let allShares = try context.fetch(FetchDescriptor<SplitShare>())
            for share in allShares where expenseIDs.contains(share.expenseID) {
                context.delete(share)
            }
        }
        for expense in expenses { context.delete(expense) }

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
        return try context.fetch(descriptor)
    }

    // MARK: - User Display Name

    private var cachedDisplayName: String?

    /// Get display name for current user. Returns cached value or "Yo" fallback.
    private func currentUserDisplayName() -> String {
        cachedDisplayName ?? "Yo"
    }

    /// Fetch the user's real name from iCloud. Call once during setup.
    func refreshUserDisplayName() async {
        do {
            let container = CKContainer.default()
            let recordID = try await container.userRecordID()
            let identity = try await container.userIdentity(forUserRecordID: recordID)
            if let components = identity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                formatter.style = .default
                let name = formatter.string(from: components)
                if !name.isEmpty {
                    cachedDisplayName = name
                    #if DEBUG
                    logger.info("User display name resolved: \(name)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            logger.info("Could not resolve user display name: \(error.localizedDescription)")
            #endif
            // Fallback stays as "Yo" — non-critical
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
    case ownerCannotLeave
    case lastAdmin
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
            return "GroupService: Only the group owner can delete the group"
        case .ownerCannotLeave:
            return "GroupService: Owner must delete the group instead of leaving"
        case .lastAdmin:
            return "GroupService: Cannot remove or demote the last admin"
        case .saveFailed(let error):
            return "GroupService: Save failed - \(error.localizedDescription)"
        }
    }
}
