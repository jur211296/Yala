//
//  GroupNotificationService.swift
//  Yala
//
//  Notificaciones locales para eventos de grupo (GC-06).
//  Disparado por SplitSyncManager cuando llegan cambios remotos.
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
        guard let item, item.isActive else { return }

        // Group changes by groupID
        var changesByGroup: [UUID: GroupChangeSummary] = [:]

        for entry in changes.newExpenses {
            changesByGroup[entry.groupID, default: GroupChangeSummary()].newExpenseIDs.append(entry.id)
        }
        for entry in changes.modifiedExpenses {
            changesByGroup[entry.groupID, default: GroupChangeSummary()].modifiedExpenseIDs.append(entry.id)
        }
        for entry in changes.newSettlements {
            changesByGroup[entry.groupID, default: GroupChangeSummary()].newSettlementIDs.append(entry.id)
        }
        for entry in changes.newMembers {
            changesByGroup[entry.groupID, default: GroupChangeSummary()].newMemberIDs.append(entry.id)
        }
        for entry in changes.newPendingMembers {
            changesByGroup[entry.groupID, default: GroupChangeSummary()].newPendingMemberIDs.append(entry.id)
        }

        // Send notification per group (with rate limiting)
        for (groupID, summary) in changesByGroup {
            guard !isRateLimited(groupID: groupID) else { continue }

            if let (title, body) = buildNotification(groupID: groupID, summary: summary) {
                let deepLink = "groups/\(groupID.uuidString)"
                lastNotifiedDates[groupID] = Date.now
                persistTimestamp(for: groupID)
                Task {
                    await NotificationService.shared.sendNotification(
                        title: title, body: body, deepLink: deepLink
                    )
                }
            }
        }
    }

    // MARK: - Private

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

        if let expenseID = summary.newExpenseIDs.first {
            return buildExpenseNotification(expenseID: expenseID, groupName: groupName, isNew: true)
        }
        if let expenseID = summary.modifiedExpenseIDs.first {
            return buildExpenseNotification(expenseID: expenseID, groupName: groupName, isNew: false)
        }
        if let settlementID = summary.newSettlementIDs.first {
            return buildSettlementNotification(settlementID: settlementID, groupName: groupName)
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

    private func buildExpenseNotification(expenseID: UUID, groupName: String, isNew: Bool) -> (String, String)? {
        guard let modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseID })
            guard let expense = try modelContext.fetch(descriptor).first else { return nil }

            let memberName = resolveMemberName(memberID: expense.paidByMemberID)
            let symbol = CurrencyCode.symbol(for: expense.currencyCode)
            let amount = expense.amount.formatted(.number.precision(.fractionLength(0...2)))
            let formattedAmount = "\(symbol)\(amount)"

            if isNew {
                if expense.expenseDescription.isEmpty {
                    return (groupName, L10n.Notifications.Group.newExpenseNoDesc(memberName, formattedAmount))
                }
                return (groupName, L10n.Notifications.Group.newExpense(memberName, formattedAmount, expense.expenseDescription))
            } else {
                let desc = expense.expenseDescription.isEmpty ? L10n.Notifications.Group.fallbackGroup : expense.expenseDescription
                return (groupName, L10n.Notifications.Group.modifiedExpense(memberName, desc))
            }
        } catch {
            return nil
        }
    }

    private func buildSettlementNotification(settlementID: UUID, groupName: String) -> (String, String)? {
        guard let modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == settlementID })
            guard let settlement = try modelContext.fetch(descriptor).first else { return nil }

            let memberName = resolveMemberName(memberID: settlement.fromMemberID)
            let symbol = CurrencyCode.symbol(for: settlement.currencyCode)
            let amount = settlement.amount.formatted(.number.precision(.fractionLength(0...2)))
            return (groupName, L10n.Notifications.Group.settlement(memberName, "\(symbol)\(amount)"))
        } catch {
            return nil
        }
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

    /// notificación local "X quiere unirse a [grupo]" — solo recibida por admins (filtrado en SplitSyncManager).
    private func buildPendingMemberNotification(memberID: UUID, groupName: String) -> (String, String)? {
        guard let modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == memberID })
            guard let member = try modelContext.fetch(descriptor).first else { return nil }
            return (groupName, L10n.Groups.Notifications.newPendingRequest(member.displayName, groupName))
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

// MARK: - GroupChangeSummary

private struct GroupChangeSummary {
    var newExpenseIDs: [UUID] = []
    var modifiedExpenseIDs: [UUID] = []
    var newSettlementIDs: [UUID] = []
    var newMemberIDs: [UUID] = []
    var newPendingMemberIDs: [UUID] = []

    var totalCount: Int {
        newExpenseIDs.count + modifiedExpenseIDs.count
            + newSettlementIDs.count + newMemberIDs.count
            + newPendingMemberIDs.count
    }
}
