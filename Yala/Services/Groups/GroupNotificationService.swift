//
//  GroupNotificationService.swift
//  Yala
//
//  Notificaciones locales para eventos de grupo (GC-06).
//  Disparado por SplitSyncManager cuando llegan cambios remotos.
//
//  Filtro por participación: un gasto/liquidación solo notifica a quien le
//  concierne (ver GroupNotificationRecipientLogic). El autor NUNCA se notifica
//  de lo que él mismo registró (cubre también el caso de un 2º device con el
//  mismo iCloud, que sí hace fetch de su propio cambio).
//

import Foundation
import SwiftData

// MARK: - RemoteChangeSet

/// Tracks remote changes classified by type for notification dispatch.
struct RemoteChangeSet {
    var newExpenses: [(id: UUID, groupID: UUID)] = []
    var modifiedExpenses: [(id: UUID, groupID: UUID)] = []
    var newSettlements: [(id: UUID, groupID: UUID)] = []
    var newMembers: [(id: UUID, groupID: UUID)] = []
    /// members nuevos con status `pendingApproval`. Solo se appendea cuando current user es admin del grupo.
    var newPendingMembers: [(id: UUID, groupID: UUID)] = []

    var isEmpty: Bool {
        newExpenses.isEmpty && modifiedExpenses.isEmpty
            && newSettlements.isEmpty && newMembers.isEmpty
            && newPendingMembers.isEmpty
    }
}

// MARK: - GroupNotificationService

@MainActor
final class GroupNotificationService {

    static let shared = GroupNotificationService()

    private var modelContext: ModelContext?

    /// Rate limiting: max 1 notification per group every 5 minutes.
    /// In-memory cache + UserDefaults persistence to survive app restarts.
    private var lastNotifiedDates: [UUID: Date] = [:]
    private let rateLimitInterval: TimeInterval = 300
    private static let rateKeyPrefix = "GroupNotifications.lastNotified."

    private func persistTimestamp(for groupID: UUID) {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970,
                                  forKey: Self.rateKeyPrefix + groupID.uuidString)
    }

    private func loadTimestamp(for groupID: UUID) -> Date? {
        let ts = UserDefaults.standard.double(forKey: Self.rateKeyPrefix + groupID.uuidString)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
    }

    // MARK: - Public

    /// Called by SplitSyncManager after processing remote changes.
    func processRemoteChanges(_ changes: RemoteChangeSet) {
        guard !changes.isEmpty, let modelContext else { return }

        // Check if .groups notification is active (typeRaw matches NotificationType.groups)
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == "groups" }
        )
        let item: NotificationItem?
        do {
            item = try modelContext.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupNotificationService: Error fetching notification setting: \(error)")
            #endif
            return
        }
        #if DEBUG
        let summarySig = "newExp=\(changes.newExpenses.count) modExp=\(changes.modifiedExpenses.count) newSet=\(changes.newSettlements.count) newMem=\(changes.newMembers.count) newPend=\(changes.newPendingMembers.count)"
        print("GroupNotif[#16-debug]: typeRaw=groups itemFound=\(item != nil) isActive=\(item?.isActive ?? false) changes={\(summarySig)}")
        #endif
        guard let item, item.isActive else { return }

        // Group RAW ids by group first (cheap, no fetch). We only pay for the
        // per-record fetches (participation filter) on groups that pass the
        // rate-limit — an initial history import would otherwise trigger N×2
        // fetches just to have the 5-min rate-limit collapse them to 1 notif.
        var rawByGroup: [UUID: RawGroupChanges] = [:]
        for entry in changes.newExpenses { rawByGroup[entry.groupID, default: RawGroupChanges()].newExpenseIDs.append(entry.id) }
        for entry in changes.modifiedExpenses { rawByGroup[entry.groupID, default: RawGroupChanges()].modifiedExpenseIDs.append(entry.id) }
        for entry in changes.newSettlements { rawByGroup[entry.groupID, default: RawGroupChanges()].newSettlementIDs.append(entry.id) }
        for entry in changes.newMembers { rawByGroup[entry.groupID, default: RawGroupChanges()].newMemberIDs.append(entry.id) }
        for entry in changes.newPendingMembers { rawByGroup[entry.groupID, default: RawGroupChanges()].newPendingMemberIDs.append(entry.id) }

        var memberIDCache: [String: String?] = [:]

        for (groupID, raw) in rawByGroup {
            let rateLimited = isRateLimited(groupID: groupID)
            #if DEBUG
            print("GroupNotif[#16-debug]: groupID=\(groupID) rateLimited=\(rateLimited) rawExp=\(raw.newExpenseIDs.count + raw.modifiedExpenseIDs.count) rawSet=\(raw.newSettlementIDs.count) pending=\(raw.newPendingMemberIDs.count)")
            #endif
            guard !rateLimited else { continue }

            // Participation filter (fetches SplitExpense/SplitShare/SplitSettlement).
            let summary = buildFilteredSummary(raw: raw, memberIDCache: &memberIDCache)
            #if DEBUG
            print("GroupNotif[#16-debug]: groupID=\(groupID) filtered total=\(summary.totalCount)")
            #endif
            guard summary.totalCount > 0 else { continue }

            if let (title, body) = buildNotification(groupID: groupID, summary: summary) {
                let deepLink = "groups/\(groupID.uuidString)"
                lastNotifiedDates[groupID] = Date.now
                persistTimestamp(for: groupID)
                #if DEBUG
                print("GroupNotif[#16-debug]: scheduling title=\"\(title)\" body=\"\(body)\" deepLink=\(deepLink)")
                #endif
                Task {
                    await NotificationService.shared.sendNotification(
                        title: title, body: body, deepLink: deepLink
                    )
                }
            }
        }
    }

    // MARK: - Participation Filter

    /// Filters raw ids to only what concerns the current user, resolving each
    /// record and my share. Builds the summary consumed by `buildNotification`.
    ///
    /// Por qué el filtro de participación vive aquí (consumidor) y NO en la clasificación
    /// de `SplitSyncManager` (donde sí vive el filtro pending-member→admin): el mismo
    /// `RemoteChangeSet` alimenta al bridge (`GroupTransactionBridge`), que necesita TODOS
    /// los expenses del grupo, no solo los míos. Filtrar en la clasificación rompería el bridge.
    private func buildFilteredSummary(raw: RawGroupChanges, memberIDCache: inout [String: String?]) -> GroupChangeSummary {
        var summary = GroupChangeSummary()

        for id in raw.newExpenseIDs {
            if let (expense, share) = participatingExpense(expenseID: id, memberIDCache: &memberIDCache) {
                summary.newExpenses.append((expense: expense, myShare: share))
            }
        }
        for id in raw.modifiedExpenseIDs {
            if let (expense, share) = participatingExpense(expenseID: id, memberIDCache: &memberIDCache) {
                summary.modifiedExpenses.append((expense: expense, myShare: share))
            }
        }
        for id in raw.newSettlementIDs {
            if let settlement = participatingSettlement(settlementID: id, memberIDCache: &memberIDCache) {
                summary.newSettlements.append(settlement)
            }
        }
        // Membership events concern the whole group — no participation filter.
        // (pending members already pre-filtered to admins in SplitSyncManager.)
        summary.newMemberIDs = raw.newMemberIDs
        summary.newPendingMemberIDs = raw.newPendingMemberIDs
        return summary
    }

    /// Returns `(expense, myShare)` if this expense should notify the current user, else nil.
    private func participatingExpense(expenseID: UUID, memberIDCache: inout [String: String?]) -> (SplitExpense, Double)? {
        guard let modelContext else { return nil }
        do {
            let descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseID })
            guard let expense = try modelContext.fetch(descriptor).first else { return nil }
            // Opening balances are Splitwise-migration seed rows, not an expense
            // "someone added" — never notify.
            if expense.isOpeningBalance { return nil }

            let cmid = currentMemberID(inZone: expense.groupZoneID, cache: &memberIDCache)
            // Only pay for the share fetch when it could possibly notify (not me, known identity).
            // The canonical decision still lives in the pure-logic helper below.
            var myShare: Double?
            if let cmid, cmid != expense.paidByMemberID {
                let shareDesc = FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == cmid }
                )
                myShare = try modelContext.fetch(shareDesc).first?.amount
            }

            switch GroupNotificationRecipientLogic.expenseDecision(
                currentMemberID: cmid,
                paidByMemberID: expense.paidByMemberID,
                lastEditedByMemberID: expense.lastEditedByMemberID,
                myShareAmount: myShare
            ) {
            case .notify(let share): return (expense, share)
            case .skip: return nil
            }
        } catch {
            #if DEBUG
            print("GroupNotificationService: Error resolving expense participation \(expenseID): \(error)")
            #endif
            return nil
        }
    }

    /// Returns the settlement if it should notify the current user (its receiver), else nil.
    private func participatingSettlement(settlementID: UUID, memberIDCache: inout [String: String?]) -> SplitSettlement? {
        guard let modelContext else { return nil }
        do {
            let descriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == settlementID })
            guard let settlement = try modelContext.fetch(descriptor).first else { return nil }
            let cmid = currentMemberID(inZone: settlement.groupZoneID, cache: &memberIDCache)
            return GroupNotificationRecipientLogic.shouldNotifySettlement(
                currentMemberID: cmid,
                toMemberID: settlement.toMemberID,
                recordedByMemberID: settlement.recordedByMemberID
            ) ? settlement : nil
        } catch {
            #if DEBUG
            print("GroupNotificationService: Error resolving settlement participation \(settlementID): \(error)")
            #endif
            return nil
        }
    }

    /// Resolves the current user's SplitMember id (uuidString) for a zone, cached per zone.
    /// `isCurrentUser` is refreshed by `refreshCurrentUserFlags` (awaited) right before this runs.
    /// Canonical resolution (oldest `joinedAt`, limit 1) mirrors `SplitSyncManager.currentUserMember`
    /// — deterministic if sync ever delivered duplicate `isCurrentUser` members for a zone.
    private func currentMemberID(inZone zoneName: String, cache: inout [String: String?]) -> String? {
        if let cached = cache[zoneName] { return cached }
        guard let modelContext else { return nil }
        do {
            var descriptor = FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneName && $0.isCurrentUser == true },
                sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
            )
            descriptor.fetchLimit = 1
            let result = try modelContext.fetch(descriptor).first?.id.uuidString
            cache[zoneName] = result   // cachea solo un resultado exitoso (incl. nil legítimo)
            return result
        } catch {
            // No cacheamos ante un error transitorio de fetch: cachear el nil envenenaría
            // toda la zona en este batch. Dejamos que el próximo record reintente.
            #if DEBUG
            print("GroupNotificationService: Error resolving current member for zone \(zoneName): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Notification Content

    private func isRateLimited(groupID: UUID) -> Bool {
        let last = lastNotifiedDates[groupID] ?? loadTimestamp(for: groupID)
        guard let last else { return false }
        return Date.now.timeIntervalSince(last) < rateLimitInterval
    }

    private func buildNotification(groupID: UUID, summary: GroupChangeSummary) -> (title: String, body: String)? {
        guard let modelContext else { return nil }

        // Resolve group name
        let groupName: String
        do {
            let gDescriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID })
            groupName = try modelContext.fetch(gDescriptor).first?.name ?? L10n.Notifications.Group.fallbackGroup
        } catch {
            groupName = L10n.Notifications.Group.fallbackGroup
        }

        let totalChanges = summary.totalCount

        if totalChanges > 1 {
            return (groupName, L10n.Notifications.Group.multipleChanges(totalChanges))
        }

        if let first = summary.newExpenses.first {
            return buildExpenseNotification(expense: first.expense, groupName: groupName, isNew: true, myShare: first.myShare)
        }
        if let first = summary.modifiedExpenses.first {
            return buildExpenseNotification(expense: first.expense, groupName: groupName, isNew: false, myShare: first.myShare)
        }
        if let settlement = summary.newSettlements.first {
            return buildSettlementNotification(settlement: settlement, groupName: groupName)
        }
        // prioridad sobre newMember para asegurar que admin vea solicitudes antes que joins normales.
        if let memberID = summary.newPendingMemberIDs.first {
            return buildPendingMemberNotification(memberID: memberID, groupName: groupName)
        }
        if let memberID = summary.newMemberIDs.first {
            return buildMemberNotification(memberID: memberID, groupName: groupName)
        }

        return nil
    }

    /// Builds the expense notification from the already-fetched expense (no re-fetch).
    /// `myShare` is the current user's portion — shown instead of the total.
    private func buildExpenseNotification(expense: SplitExpense, groupName: String, isNew: Bool, myShare: Double) -> (String, String)? {
        // Atribuir al EDITOR real (crear/editar), no al pagador. Proxy legado (pagador) si el campo es nil.
        let memberName = resolveMemberName(memberID: GroupNotificationRecipientLogic.expenseAttributionMemberID(
            lastEditedByMemberID: expense.lastEditedByMemberID,
            paidByMemberID: expense.paidByMemberID))
        // Formato canónico off-MainActor: respeta decimalPlaces / formato de moneda del usuario
        // (evita drift visual entre la notificación y el resto de la app).
        let formattedShare = YalaFormatterStatic.currency(value: myShare, currencyCode: expense.currencyCode)

        if isNew {
            if expense.expenseDescription.isEmpty {
                return (groupName, L10n.Notifications.Group.newExpenseNoDesc(memberName, formattedShare))
            }
            return (groupName, L10n.Notifications.Group.newExpense(memberName, expense.expenseDescription, formattedShare))
        } else {
            let desc = expense.expenseDescription.isEmpty ? L10n.Notifications.Group.fallbackGroup : expense.expenseDescription
            return (groupName, L10n.Notifications.Group.modifiedExpense(memberName, desc, formattedShare))
        }
    }

    /// Builds the settlement notification from the already-fetched settlement (no re-fetch).
    /// The full `settlement.amount` is correct — it's the payment the receiver got.
    private func buildSettlementNotification(settlement: SplitSettlement, groupName: String) -> (String, String)? {
        let memberName = resolveMemberName(memberID: settlement.fromMemberID)
        let formattedAmount = YalaFormatterStatic.currency(value: settlement.amount, currencyCode: settlement.currencyCode)
        return (groupName, L10n.Notifications.Group.settlement(memberName, formattedAmount))
    }

    private func buildMemberNotification(memberID: UUID, groupName: String) -> (String, String)? {
        guard let modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == memberID })
            guard let member = try modelContext.fetch(descriptor).first else { return nil }
            return (groupName, L10n.Notifications.Group.newMember(member.displayName))
        } catch {
            return nil
        }
    }

    /// notificación local "👋 X quiere unirse a [grupo]" — solo recibida por admins (filtrado en SplitSyncManager).
    private func buildPendingMemberNotification(memberID: UUID, groupName: String) -> (String, String)? {
        guard let modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == memberID })
            guard let member = try modelContext.fetch(descriptor).first else { return nil }
            let title = L10n.Groups.Notifications.newPendingRequest(member.displayName, groupName)
            return (title, L10n.Groups.Notifications.newPendingRequestBody)
        } catch {
            return nil
        }
    }

    /// Resolves member display name from a member ID string (UUID format).
    private func resolveMemberName(memberID: String) -> String {
        guard let modelContext,
              let uuid = UUID(uuidString: memberID) else {
            return L10n.Notifications.Group.fallbackMember
        }

        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == uuid })
            return try modelContext.fetch(descriptor).first?.displayName ?? L10n.Notifications.Group.fallbackMember
        } catch {
            return L10n.Notifications.Group.fallbackMember
        }
    }
}

// MARK: - RawGroupChanges

/// Raw ids grouped by group, before the participation filter (cheap; no fetch).
private struct RawGroupChanges {
    var newExpenseIDs: [UUID] = []
    var modifiedExpenseIDs: [UUID] = []
    var newSettlementIDs: [UUID] = []
    var newMemberIDs: [UUID] = []
    var newPendingMemberIDs: [UUID] = []
}

// MARK: - GroupChangeSummary

/// Filtered changes for one group — only what concerns the current user.
/// Expenses carry the already-fetched object + my share (avoids re-fetch in build).
private struct GroupChangeSummary {
    var newExpenses: [(expense: SplitExpense, myShare: Double)] = []
    var modifiedExpenses: [(expense: SplitExpense, myShare: Double)] = []
    var newSettlements: [SplitSettlement] = []
    var newMemberIDs: [UUID] = []
    var newPendingMemberIDs: [UUID] = []

    var totalCount: Int {
        newExpenses.count + modifiedExpenses.count
            + newSettlements.count + newMemberIDs.count
            + newPendingMemberIDs.count
    }
}
