//
//  GroupsLote19FixesTests.swift
//  YalaTests
//
//  Bugs claros del lote 19 de la auditoría UX 2.2 (Grupos III: administrar, salir y modos). Rechazar y
//  «Cambiar rol» se prueban contra el servicio en `GroupChannelRoutingTests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Lote 19 · Grupos III")
@MainActor
struct GroupsLote19FixesTests {

    // MARK: - B3 · «Cancelar» a la vista en los diálogos de administrar el grupo

    /// Con `role: .cancel`, el diálogo (sale como globo en iOS 26) no pinta la salida: medido en el simulador en
    /// aprobar, rechazar, quitar presupuesto, eliminar grupo y, sin ningún botón, en salir, archivar y quitar
    /// miembro. El molde es el del lote 13: un «Cancelar» sin rol, con su identificador.
    @Test(arguments: [
        ("Yala/App/Views/Groups/GroupMembersView.swift",
         ["group_member_remove_cancel", "group_member_approve_cancel", "group_member_reject_cancel",
          "opening_balance_prompt_skip"]),
        ("Yala/App/Views/Groups/GroupSettingsView.swift",
         ["group_settings_leave_cancel", "group_settings_archive_cancel", "group_budget_remove_cancel",
          "group_settings_delete_cancel", "group_settings_transfer_cancel"]),
        ("Yala/App/Views/Settings/GroupsAssociationSection.swift", ["storage_groups_detach_cancel"]),
    ])
    func dialogs_showAPlainCancel(path: String, cancelIDs: [String]) throws {
        let source = try Self.source(path)
        // El único `role: .cancel` que queda es el de la ALERTA del presupuesto: una `.alert` sí pinta sus dos
        // salidas. En un `confirmationDialog`, no.
        let alertCancel = "Button(L10n.Action.save) { saveBudgetLimitFromInput() }\n                Button(L10n.Common.cancel, role: .cancel) {}"
        let withoutAlert = source.replacingOccurrences(of: alertCancel, with: "")
        #expect(!withoutAlert.contains("Button(L10n.Common.cancel, role: .cancel)"),
                "\(path) vuelve a esconder la salida de un diálogo")
        #expect(!source.contains("approvalPromptSkip, role: .cancel"))
        for id in cancelIDs {
            #expect(source.contains("\"\(id)\""), "\(path) sin el «Cancelar» \(id)")
        }
    }

    // MARK: - B4 · Ninguna pantalla de Grupos enseña el error en crudo

    @Test(arguments: [
        ("Yala/App/Views/Groups/GroupSettingsView.swift", "GroupActionErrorLogic.message(for: error)"),
        ("Yala/App/Views/Inbox/GroupExpenseAccountFinalizationSheet.swift", "GroupsUserFacingErrorLogic.message(for: error)"),
        ("Yala/App/Views/Inbox/GroupExpenseAccountAndSubcategoryFinalizationSheet.swift", "GroupsUserFacingErrorLogic.message(for: error)"),
    ])
    func screens_doNotShowTheRawError(path: String, logic: String) throws {
        let source = try Self.source(path)
        #expect(!source.contains("= error.localizedDescription"), "\(path) vuelve a enseñar el error en crudo")
        #expect(source.contains(logic))
    }

    // MARK: - B5 · El presupuesto del grupo habla en «S/» o «PEN» según la preferencia

    @Test func budget_labelsTheCurrencyWithThePreference() throws {
        let source = try Self.source("Yala/App/Views/Groups/GroupSettingsView.swift")
        #expect(!source.contains("Budget.hint(group.currencyCode)"))
        #expect(!source.contains("TextField(group.currencyCode"))
        let uses = source.components(separatedBy: "currencyDisplayFormat.label(for: group.currencyCode)").count - 1
        #expect(uses == 3, "La pista de la fila, la de la alerta y el campo: \(uses)")
    }

    // MARK: - B6 · «Saliste de algunos grupos» solo si saliste de alguno

    @Test(arguments: [
        (false, 0, 2, GroupBatchLeaveLogic.ResultHeadline.noneLeft),
        (false, 1, 2, .someNeedDecision),
        (false, 3, 0, .allDone),
        (false, 0, 0, .allDone),
        (true, 0, 2, .stopped),
        (true, 2, 0, .stopped),
    ])
    func batchLeave_headlineSaysWhatHappened(
        wasStopped: Bool, left: Int, needsDecision: Int, expected: GroupBatchLeaveLogic.ResultHeadline
    ) {
        #expect(GroupBatchLeaveLogic.resultHeadline(
            wasStopped: wasStopped, leftOrTransferred: left, needsDecision: needsDecision) == expected)
    }

    @Test func batchLeave_noneLeftHasItsOwnText() {
        #expect(L10n.Settings.batchLeaveNoneLeft != L10n.Settings.batchLeaveSomeNeedDecision)
        #expect(!L10n.Settings.batchLeaveNoneLeft.hasPrefix("settings."))
    }

    // MARK: - B7 · El aviso de un gasto editado sin descripción no lo llama «Grupo»

    @Test func editedExpenseWithoutDescription_isNotNamedAfterTheGroupFallback() {
        let body = GroupNotificationService.expenseBody(
            isNew: false, memberName: "Ana", description: "", formattedShare: "S/ 30.00")
        #expect(body == L10n.Notifications.Group.modifiedExpenseNoDesc("Ana", "S/ 30.00"))
        #expect(!body.contains(L10n.Notifications.Group.fallbackGroup))
        #expect(body.contains("Ana") && body.contains("S/ 30.00"))
    }

    @Test func expenseBody_keepsTheOtherThreeCases() {
        #expect(GroupNotificationService.expenseBody(isNew: true, memberName: "Ana", description: "", formattedShare: "1")
                == L10n.Notifications.Group.newExpenseNoDesc("Ana", "1"))
        #expect(GroupNotificationService.expenseBody(isNew: true, memberName: "Ana", description: "Taxi", formattedShare: "1")
                == L10n.Notifications.Group.newExpense("Ana", "Taxi", "1"))
        #expect(GroupNotificationService.expenseBody(isNew: false, memberName: "Ana", description: "Taxi", formattedShare: "1")
                == L10n.Notifications.Group.modifiedExpense("Ana", "Taxi", "1"))
    }

    // MARK: - Helpers

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
    }
}
