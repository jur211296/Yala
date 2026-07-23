//
//  GroupNotificationServiceTests.swift
//  YalaTests
//
//  Tests for GroupNotificationService: notification generation,
//  rate limiting, aggregation, and deep link parsing.
//

import Foundation
import Testing

@testable import Yala

struct GroupNotificationServiceTests {

    // MARK: - RemoteChangeSet

    @Test func changeSet_empty_returnsTrueWhenNoChanges() {
        let set = RemoteChangeSet()
        #expect(set.isEmpty)
    }

    @Test func changeSet_withNewExpense_isNotEmpty() {
        var set = RemoteChangeSet()
        set.newExpenses.append((UUID(), UUID()))
        #expect(!set.isEmpty)
    }

    @Test func changeSet_withModifiedExpense_isNotEmpty() {
        var set = RemoteChangeSet()
        set.modifiedExpenses.append((UUID(), UUID()))
        #expect(!set.isEmpty)
    }

    @Test func changeSet_withSettlement_isNotEmpty() {
        var set = RemoteChangeSet()
        set.newSettlements.append((UUID(), UUID()))
        #expect(!set.isEmpty)
    }

    @Test func changeSet_withNewMember_isNotEmpty() {
        var set = RemoteChangeSet()
        set.newMembers.append((UUID(), UUID()))
        #expect(!set.isEmpty)
    }

    // MARK: - NotificationType.groups Properties

    @Test func groupsType_hasCorrectIcon() {
        #expect(NotificationType.groups.defaultIcon == "person.2.fill")
    }

    @Test func groupsType_hasCorrectColor() {
        #expect(NotificationType.groups.defaultColor == "#8B5CF6")
    }

    @Test func groupsType_requiresDynamicContent() {
        #expect(NotificationType.groups.requiresDynamicContent)
    }

    @Test func groupsType_isEventDriven() {
        #expect(NotificationType.groups.isEventDriven)
    }

    @Test func groupsType_isNotEditable() {
        #expect(!NotificationType.groups.isEditable)
    }

    @Test func groupsType_isNotDeletable() {
        #expect(!NotificationType.groups.isDeletable)
    }

    @Test func groupsType_isNotTextCustomizable() {
        #expect(!NotificationType.groups.isTextCustomizable)
    }

    @Test func groupsType_isNotNameCustomizable() {
        #expect(!NotificationType.groups.isNameCustomizable)
    }

    // MARK: - Deep Link Parsing

    @Test func parseDestination_groups_returnsGroups() {
        let dest = NotificationService.parseDestination("groups")
        #expect(dest == .groups)
    }

    @Test func parseDestination_groupDetail_returnsGroupDetail() {
        let uuid = UUID().uuidString
        let dest = NotificationService.parseDestination("groups/\(uuid)")
        #expect(dest == .groupDetail(groupID: uuid))
    }

    @Test func parseDestination_existingDestinations_stillWork() {
        #expect(NotificationService.parseDestination("statistics") == .statistics)
        #expect(NotificationService.parseDestination("planning") == .planning)
        #expect(NotificationService.parseDestination("budgets") == .budgets)
        #expect(NotificationService.parseDestination("records") == .records)
        #expect(NotificationService.parseDestination("categories") == .categories)
        #expect(NotificationService.parseDestination("inbox") == .inbox)
        #expect(NotificationService.parseDestination("scheduledPayments") == .scheduledPayments)
        #expect(NotificationService.parseDestination("recordsStandalone") == .recordsStandalone)
    }

    @Test func parseDestination_unknown_returnsNil() {
        #expect(NotificationService.parseDestination("unknown") == nil)
    }

    // MARK: - DeepLinkDestination Equatable

    @Test func deepLinkDestination_groupDetail_equatable() {
        let id = UUID().uuidString
        #expect(DeepLinkDestination.groupDetail(groupID: id) == DeepLinkDestination.groupDetail(groupID: id))
        #expect(DeepLinkDestination.groupDetail(groupID: "a") != DeepLinkDestination.groupDetail(groupID: "b"))
    }

    @Test func deepLinkDestination_groups_notEqualToGroupDetail() {
        #expect(DeepLinkDestination.groups != DeepLinkDestination.groupDetail(groupID: "x"))
    }

    // MARK: - E2E Deep Link Flow

    @Test @MainActor func deepLink_groupDetail_enqueuesRouterIntent() {
        let router = AppRouter.shared
        router._testReset()

        let groupID = UUID().uuidString
        let destination = NotificationService.parseDestination("groups/\(groupID)")
        #expect(destination == .groupDetail(groupID: groupID))

        // Simulate NotificationService.didReceive routing via AppRouter
        router.enqueue(.navigate(destination!))

        router.markReady(.mainTab)
        let intent = router.drainNext(for: .mainTab)
        if case .navigate(.groupDetail(let id)) = intent {
            #expect(id == groupID)
        } else {
            Issue.record("Expected .navigate(.groupDetail) intent")
        }
    }

    // MARK: - Cableado del fix de atribución/eco (source-scan)
    //
    // Los métodos de participación de GroupNotificationService son privados y requieren un ModelContext
    // (makeTestContext flakea, regla R8). La LÓGICA pura (autor/eco/atribución) la cubren por mutantes los
    // GroupNotificationRecipientLogicTests; este source-scan fija el CABLEADO — que el servicio REALMENTE
    // pasa los campos nuevos a la lógica pura y atribuye vía el helper — para que un revert silencioso
    // (p.ej. volver a `resolveMemberName(memberID: expense.paidByMemberID)`, que compila con los params
    // `= nil`) rompa el build de tests en vez de reintroducir el bug en silencio.

    private static var serviceSource: String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Yala/Services/Groups/GroupNotificationService.swift")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    @Test func wiring_expenseDecision_receivesLastEditedByMemberID() {
        let src = Self.serviceSource
        #expect(!src.isEmpty, "No se pudo leer GroupNotificationService.swift por #filePath")
        #expect(src.contains("lastEditedByMemberID: expense.lastEditedByMemberID"),
                "participatingExpense DEBE pasar el autor a expenseDecision — sin esto el eco no se autoexcluye")
    }

    @Test func wiring_settlement_receivesRecordedByMemberID() {
        #expect(Self.serviceSource.contains("recordedByMemberID: settlement.recordedByMemberID"),
                "participatingSettlement DEBE pasar el registrador a shouldNotifySettlement — sin esto el eco Caso D no se autoexcluye")
    }

    @Test func wiring_attribution_usesEditorHelper() {
        #expect(Self.serviceSource.contains("expenseAttributionMemberID("),
                "buildExpenseNotification DEBE atribuir vía expenseAttributionMemberID (editor∨proxy), no por el pagador crudo")
    }
}
