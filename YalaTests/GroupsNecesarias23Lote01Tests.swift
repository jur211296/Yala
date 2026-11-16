//
//  GroupsNecesarias23Lote01Tests.swift
//  YalaTests
//
//  Lote 01 de las mejoras necesarias de la 2.3 (Grupos, 10-nov): la lógica pura de tres puntos y el cableado que la usa.
//  - Un grupo archivado no ofrece apuntar gastos ni pagos nuevos desde dentro.
//  - El error de un saldo inicial con pagos confirmados ya no habla de borrar un gasto.
//  - «Importar todo el historial» sale al encender el puente si hay gastos, no solo si ya había algo reflejado.
//
//  El cableado se fija leyendo el código (sin comentarios): la vista no se puede montar aquí.
//

import Foundation
import Testing

@testable import Yala

@Suite("Mejoras necesarias 2.3 · Grupos, lote 01")
@MainActor
struct GroupsNecesarias23Lote01Tests {

    // MARK: - Grupo archivado

    @Test("Archivado: ni «+» ni «Saldar»; sin archivar y pudiendo escribir, sí")
    func archivedGroup_offersNoNewEntries() {
        typealias L = GroupArchivedEntryLogic
        #expect(L.allowsNewEntries(canParticipate: true, isArchived: false))
        #expect(!L.allowsNewEntries(canParticipate: true, isArchived: true))
        #expect(!L.allowsNewEntries(canParticipate: false, isArchived: false))
        #expect(!L.allowsNewEntries(canParticipate: false, isArchived: true))
    }

    @Test("El «+» y «Saldar» del detalle preguntan por el archivado; confirmar y rechazar, no")
    func groupDetail_gatesNewEntriesOnTheArchivedFlag() throws {
        let code = try Self.code("Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(code.contains("selectedTab == .records && viewModel.canRecordNewEntries && !group.isMigratedFrozen"))
        #expect(code.contains("onSettleDebt: viewModel.canRecordNewEntries ?"))
        #expect(code.contains("onConfirmSettlement: viewModel.canCurrentUserParticipate ?"))
        #expect(code.contains("onRejectSettlement: viewModel.canCurrentUserParticipate ?"))

        let vm = try Self.code("Yala/App/ViewModels/GroupDetailViewModel.swift")
        #expect(vm.contains("GroupArchivedEntryLogic.allowsNewEntries( canParticipate: canCurrentUserParticipate, isArchived: !isGroupGone && group.isArchived )"))
    }

    // MARK: - Saldo inicial con pagos

    @Test("Con pagos confirmados, el aviso del saldo inicial no habla de borrar un gasto")
    func lockedOpeningBalance_saysWhatHappened() {
        let message = OpeningBalanceErrorCopyLogic.message(for: GroupExpenseServiceError.expenseHasAssociatedSettlements)
        #expect(message == L10n.Groups.OpeningBalance.errorLockedBySettlements)
        #expect(message != L10n.Groups.Bridge.deleteExpenseBlocked)
        // El resto de errores sigue con su texto de siempre.
        #expect(OpeningBalanceErrorCopyLogic.message(for: GroupExpenseServiceError.notAdmin)
                == L10n.Groups.OpeningBalance.errorNotAdmin)
    }

    @Test("El formulario y quitar un saldo inicial usan el texto nuevo; el formulario pregunta antes de reemplazar")
    func openingBalance_wiring() throws {
        let form = try Self.code("Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift")
        #expect(form.contains("if expenseToEdit == nil, askBeforeReplacing() { return }"))
        #expect(form.contains("openingBalanceThatAddingWouldReplace("))
        #expect(form.contains("Button(L10n.Groups.OpeningBalance.replaceConfirm) { performSave(afterConfirmation: true) }"))
        // El aviso de error tras «Reemplazar» espera a que se cierre el de la pregunta (comparten ancla).
        #expect(form.contains("guard afterConfirmation else { showError = true return }"))
        #expect(form.contains("try await Task.sleep(for: .milliseconds(600))"))
        #expect(!form.contains("GroupsUserFacingErrorLogic.message(for: error)"))

        let vm = try Self.code("Yala/App/ViewModels/GroupDetailViewModel.swift")
        let remove = try #require(vm.range(of: "func removeOpeningBalance("))
        let body = vm[remove.upperBound...].prefix(700)
        #expect(body.contains("L10n.Groups.OpeningBalance.errorLockedBySettlements"))
        #expect(!body.contains("deleteExpenseBlocked"))
    }

    // MARK: - Importar el historial

    @Test("Encender por primera vez, con gastos y nada reflejado, ofrece importar el historial")
    func firstActivation_offersTheImport() {
        typealias L = BridgeToggleSheetLogic
        #expect(L.sheet(turningOn: true, hasGroupExpenses: true, hasBridgedTransactions: false) == .activation)
        #expect(L.sheet(turningOn: true, hasGroupExpenses: true, hasBridgedTransactions: true) == .activation)
        // Sin gastos no hay nada que importar.
        #expect(L.sheet(turningOn: true, hasGroupExpenses: false, hasBridgedTransactions: false) == nil)
        // Apagar no cambia: la hoja de desactivar sale solo con movimientos reflejados.
        #expect(L.sheet(turningOn: false, hasGroupExpenses: true, hasBridgedTransactions: true) == .deactivation)
        #expect(L.sheet(turningOn: false, hasGroupExpenses: true, hasBridgedTransactions: false) == nil)
    }

    @Test("Ajustes de Grupos y los de cada grupo deciden la hoja con la misma regla")
    func bridgeToggles_useTheSameRule() throws {
        let global = try Self.code("Yala/App/Views/Groups/GroupsGlobalSettingsView.swift")
        #expect(global.contains("BridgeToggleSheetLogic.sheet( turningOn: newValue, hasGroupExpenses: newValue && hasGroupExpenses(),"))
        #expect(!global.contains("let hasBridged = hasBridgedTransactions()"))

        let perGroup = try Self.code("Yala/App/Views/Groups/GroupSettingsView.swift")
        #expect(perGroup.contains("BridgeToggleSheetLogic.sheet( turningOn: newValue, hasGroupExpenses: newValue && hasExpensesInGroup(),"))
        #expect(perGroup.contains(".sheet(isPresented: $showPerGroupActivationSheet) { BridgeActivationSheet( scope: .perGroup("))
        #expect(perGroup.contains("onCancel: { setPerGroupOverride(false) }"))
    }

    // MARK: - Infra

    /// El fichero sin comentarios, con las líneas recortadas y unidas por un espacio.
    private static func code(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") && !$0.isEmpty }
            .joined(separator: " ")
    }
}
