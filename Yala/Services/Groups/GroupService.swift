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

        // Propaga la flag por dos canales convergentes: (a) SplitGroup record vía enqueueSave
        // + sync (path normal para invitados con app abierta — F2 propagation), (b) CKShare
        // custom key zone-wide (race-tolerant fallback para invitados pre-accept retap link).
        // Ambos llegan eventualmente al device del invitado y resetean su SplitGroup.isArchived local.
        SplitSyncManager.shared.enqueueSave(modelID: group.id, group: group)
        let zoneID = group.cloudKitZoneID
        Task {
            await Self.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isArchived, value: isArchived)
        }
    }

    /// Escribe una bool custom key (codificada como Int 0/1) en el CKShare zone-wide.
    /// Solo el owner del CKShare puede modificarlo (admin = owner por construcción).
    /// Failure mode: silent fail en DEBUG log; red de seguridad es el sync del SplitGroup record.
    /// `static` (no private) para que `SplitSyncManager.handleConflict` re-propague tras race.
    static func propagateBoolCustomKey(zoneID: String, key: String, value: Bool) async {
        let zoneIDObj = CKRecordZone.ID(zoneName: zoneID, ownerName: CKCurrentUserDefaultName)
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneIDObj)
        let database = CKContainer(identifier: CKConstants.containerID).privateCloudDatabase
        do {
            let record = try await database.record(for: shareRecordID)
            guard let share = record as? CKShare else { return }
            share[key] = value ? 1 : 0
            _ = try await database.modifyRecords(saving: [share], deleting: [])
        } catch {
            #if DEBUG
            print("GroupService.propagateBoolCustomKey(\(key)): failed for zone \(zoneID): \(error)")
            #endif
        }
    }

    /// Soft-delete del grupo. Owner-only. Bloquea si cualquier miembro tiene balance pendiente.
    /// Propaga `isHiddenForAll` por dos canales (idem setArchived): SplitGroup record sync +
    /// CKShare custom key. Invisible para todos los miembros al próximo sync; el CKShare custom
    /// key gateá retap link al modo `.deletedForAll` para devices sin SplitGroup local.
    /// Irreversible desde la app — recovery solo vía CloudKit Dashboard (ver apuntes-grupos.md).
    /// Adicional: dispara `freezeForSoftDelete` para limpiar TX/drafts personales bridgeadas.
    func softDelete(_ group: SplitGroup) throws {
        let context = try requireContext()
        guard group.isOwner else { throw GroupServiceError.notOwner }

        // Recalcular balances internamente (defensa en profundidad — no confía en UI).
        let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
        let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
        let members = try fetchMembers(for: group)
        let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements
        )
        guard balances.allSatisfy({ abs($0.netBalance) <= 0.01 }) else {
            throw GroupServiceError.outstandingBalance
        }

        group.isHiddenForAll = true

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()

        // Sube el SplitGroup record con isHiddenForAll=true para que el sync lo propague
        // a los devices de los invitados (el CKShare custom key abajo es solo race-tolerant
        // fallback para el flow de retap link).
        SplitSyncManager.shared.enqueueSave(modelID: group.id, group: group)

        // Libera TX cuenta real (preserva rastro financiero) + convierte drafts a manual.
        // No-bloqueante: el observer del sync y la red de seguridad boot-time cubren
        // con idempotency si esta llamada falla.
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("softDelete: freezeForSoftDelete failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }

        let zoneID = group.cloudKitZoneID
        Task {
            await Self.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isHiddenForAll, value: true)
        }

        TelemetryService.track(.groupSoftDeleted)
    }

    /// Delete a group permanently (owner only).
    /// Cascades: deletes zone, all local models, and unbridges personal records.
    func deleteGroup(_ group: SplitGroup, allowDestructiveDelete: Bool = false) throws {
        #if !DEBUG
        throw GroupServiceError.deleteDisabled
        #else
        let context = try requireContext()

        guard allowDestructiveDelete else { throw GroupServiceError.deleteDisabled }
        guard group.isOwner else { throw GroupServiceError.notOwner }

        // Delete CK zone (cascade deletes all remote records)
        SplitZoneManager(syncManager: .shared).deleteZone(for: group)

        // Libera TX cuenta real (preserva rastro) + convierte drafts a manual.
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                logger.error("Failed to freeze for soft-delete: \(error)")
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
        #endif
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

        // Cannot remove the last admin
        if member.role == "admin" {
            let adminCount = try activeAdminCount(in: group, context: context)
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        member.memberStatus = .removed
        // NOTE: `isCurrentUser` no se setea aquí — es device-local, no se sincroniza vía
        // CKRecord. `refreshCurrentUserFlags` lo reescribe en cada device basándose en el
        // matching de `cloudKitUserRecordID` con el current iCloud user.

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
    }

    /// members awaiting admin approval (status `.pendingApproval`).
    func pendingMembers(in group: SplitGroup) throws -> [SplitMember] {
        try fetchMembers(for: group).filter { $0.isPendingApproval }
    }

    /// admin approves a pending member, marking them as active and enqueuing sync.
    func approveMember(_ member: SplitMember, in group: SplitGroup) throws {
        try transitionPendingMember(member, to: .active, in: group)
    }

    /// admin rejects a pending member's request, marking them as rejected and enqueuing sync.
    func rejectMember(_ member: SplitMember, in group: SplitGroup) throws {
        try transitionPendingMember(member, to: .rejected, in: group)
    }

    private func transitionPendingMember(
        _ member: SplitMember,
        to newStatus: SplitMemberStatus,
        in group: SplitGroup
    ) throws {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard member.isPendingApproval else { throw GroupServiceError.notPendingApproval }

        member.memberStatus = newStatus

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

        // El usuario puede salir aunque tenga saldo pendiente. La UI muestra warning
        // explícito en el confirmation dialog antes de invocar este método.
        let currentMember = try await ensureCurrentUserMemberExists(in: group, reactivateInactive: false)

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

        // Captura (zoneName, ownerName) ANTES de borrar el SplitGroup local para que el
        // retry persistente funcione si la red falla durante `leaveShare`.
        let leaveShareZoneName = group.cloudKitZoneID
        let leaveShareOwnerName = SplitZoneManager(syncManager: .shared).ownerName(for: group)
        do {
            try await SplitZoneManager(syncManager: .shared).leaveShare(for: group)
        } catch {
            #if DEBUG
            logger.error("leaveShare failed for \(leaveShareZoneName, privacy: .public): \(error.localizedDescription, privacy: .public). Persistiendo retry en tracker.")
            #endif
            PendingLeaveShareTracker.add(PendingLeaveShareEntry(zoneName: leaveShareZoneName, zoneOwnerName: leaveShareOwnerName))
        }

        try performLocalCleanupAndDelete(group: group, context: context)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Flow simétrico a `leaveGroup` disparado por observer (`SplitSyncManager.applyMember`
    /// cuando el current user pasa a `.removed` vía admin remoto). Idempotente: si el
    /// SplitGroup local ya fue borrado (e.g. leaveGroup previo en otro device del mismo
    /// user), no-op.
    func performRemovedSelfCleanup(zoneName: String) async {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneName })
        guard let group = try? context.fetch(descriptor).first else { return }

        let leaveShareZoneName = group.cloudKitZoneID
        let leaveShareOwnerName = SplitZoneManager(syncManager: .shared).ownerName(for: group)

        do {
            try performLocalCleanupAndDelete(group: group, context: context)
            try context.save()
        } catch {
            #if DEBUG
            logger.error("performRemovedSelfCleanup: local cleanup failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        SessionState.shared.incrementDataVersion()

        do {
            try await SplitZoneManager(syncManager: .shared).leaveShareByZone(
                zoneName: leaveShareZoneName,
                ownerName: leaveShareOwnerName
            )
        } catch {
            #if DEBUG
            logger.error("performRemovedSelfCleanup: leaveShareByZone failed for \(leaveShareZoneName, privacy: .public): \(error.localizedDescription, privacy: .public). Persistiendo retry en tracker.")
            #endif
            PendingLeaveShareTracker.add(
                PendingLeaveShareEntry(zoneName: leaveShareZoneName, zoneOwnerName: leaveShareOwnerName)
            )
        }
    }

    /// Bloque común de cleanup local al salir o ser removido de un grupo: libera TX cuenta
    /// real (preserva rastro financiero), convierte drafts a manual, borra expenses/shares/
    /// settlements/members de la zone, limpia prefs personales del grupo y elimina el
    /// SplitGroup local. NO hace save() — caller controla cuándo flushear.
    private func performLocalCleanupAndDelete(group: SplitGroup, context: ModelContext) throws {
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("freezeForSoftDelete failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
        try cascadeDeleteGroupData(zoneName: group.cloudKitZoneID, context: context)
        GroupPersonalPreferences.removeAll(for: group.cloudKitZoneID)
        context.delete(group)
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
                if existing.memberStatus == .pendingApproval {
                    // No-op: solo el admin puede sacar a un member de pending.
                } else if group.isOwner {
                    existing.memberStatus = .active
                    changed = true
                } else if existing.memberStatus == .rejected || existing.memberStatus == .removed {
                    existing.memberStatus = .pendingApproval
                    changed = true
                } else {
                    // Legacy left → active (preserva semántica previa para users que se fueron voluntariamente).
                    existing.memberStatus = .active
                    changed = true
                }
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

        // A9: NO heuristic fallbacks (nameMatch / admin-único). If the current user
        // doesn't match any existing SplitMember by `cloudKitUserRecordID` and no
        // legacy member is flagged with `isCurrentUser=true`, we create a new
        // SplitMember below. Identity must be authoritative — assuming by name or
        // role can mis-assign `isCurrentUser` in groups with two members of the
        // same name or with unrelated admins.

        guard reactivateInactive else { throw GroupServiceError.currentUserMemberNotFound }

        // Create a new member record for the current user.
        // invitados entran como pendingApproval; owner siempre active.
        let zoneID = group.cloudKitZoneID
        let initialStatus: SplitMemberStatus = group.isOwner ? .active : .pendingApproval
        let member = SplitMember(
            groupZoneID: zoneID,
            displayName: currentUserDisplayName(),
            cloudKitUserRecordID: recordName,
            role: "member",
            status: initialStatus,
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

    /// A13: Updates the current user's `displayName` across all groups they belong to,
    /// and enqueues sync for each updated SplitMember. Called after the user finishes
    /// their initial onboarding (e.g. `GroupInviteOnboardingView.performSilentSetup`)
    /// or as part of boot-time reconciliation if a previous attempt was interrupted.
    /// - Parameter newName: the user's chosen display name (will be trimmed).
    /// - Note: Idempotent — when no member needs update, returns without saving.
    func updateCurrentUserDisplayName(_ newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let context = try requireContext()

        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        let myMembers = try context.fetch(memberDescriptor)
        let pending = myMembers.filter { $0.displayName != trimmed }
        guard !pending.isEmpty else { return }

        // Cache groups by zoneID — typical user has 1-3 groups, fetch once.
        // `uniquingKeysWith` evita crash si CloudKit sync trae duplicados con el
        // mismo zoneID (no hay @Attribute(.unique) por compat CloudKit). Cualquier
        // duplicado sirve igual para enqueueSave — todos apuntan al mismo zone.
        let allGroups = try fetchAllGroups()
        let groupByZoneID = Dictionary(allGroups.map { ($0.cloudKitZoneID, $0) },
                                       uniquingKeysWith: { first, _ in first })
        if groupByZoneID.count < allGroups.count {
            let conflictCount = allGroups.count - groupByZoneID.count
            #if DEBUG
            print("GroupService: \(conflictCount) duplicate SplitGroups detected during updateCurrentUserDisplayName")
            #endif
            TelemetryService.cloudkitDuplicateDetected(
                model: "SplitGroup",
                count: conflictCount,
                context: .uniquingFallback,
                keySuffix: "updateDisplayName:\(conflictCount)"
            )
        }

        for member in pending {
            member.displayName = trimmed
            if let group = groupByZoneID[member.groupZoneID] {
                SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
            }
        }

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }
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
            if groupsByZone.count < allGroups.count {
                let conflictCount = allGroups.count - groupsByZone.count
                #if DEBUG
                print("GroupService: \(conflictCount) duplicate SplitGroups detected during refreshCurrentUserFlags")
                #endif
                TelemetryService.cloudkitDuplicateDetected(
                    model: "SplitGroup",
                    count: conflictCount,
                    context: .uniquingFallback,
                    keySuffix: "refreshFlags:\(conflictCount)"
                )
            }

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
        case .pendingApproval: 1
        case .left: 2
        case .removed: 3
        case .rejected: 4
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
    case inactiveMember
    case memberNotInGroup
    case cannotRemoveSelf
    case ownerMemberImmutable
    case currentUserMemberNotFound
    case deleteDisabled
    case notPendingApproval
    case currentUserPendingApproval
    case outstandingBalance
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
        case .notPendingApproval:
            return "GroupService: Member is not awaiting approval"
        case .currentUserPendingApproval:
            return "GroupService: Your membership is pending admin approval"
        case .outstandingBalance:
            return "GroupService: Cannot proceed while members have outstanding balances"
        case .saveFailed(let error):
            return "GroupService: Save failed - \(error.localizedDescription)"
        }
    }
}
