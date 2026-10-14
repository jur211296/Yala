//
//  RecordBulkActionLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 8. El modo selección de Registros borraba y editaba registros de grupo sin mirar nada: borrar
//  en lote la pata real de un gasto de grupo dejaba al grupo diciendo «Pagaste S/ 80» y a Registros sin el gasto. Ahora el
//  lote pregunta lo mismo que el menú contextual y el editor (`RecordBulkActionLogic`).
//
//  Dos suites: la lógica pura, y el ViewModel con un store de verdad, que es donde vive el borrado y donde un guard en
//  la vista se podría saltar.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct RecordBulkActionLogicTests {

    private func shape(
        splitExpense: Bool = false,
        splitSettlement: Bool = false,
        accountIsNil: Bool = false,
        accountIsSystem: Bool = false,
        subcategoryIsSystem: Bool = false
    ) -> RecordContextActionLogic.Shape {
        RecordContextActionLogic.Shape(
            hasBalanceAdjustmentType: false,
            hasSplitExpenseID: splitExpense,
            hasSplitSettlementID: splitSettlement,
            accountIsNil: accountIsNil,
            accountIsSystem: accountIsSystem,
            subcategoryIsSystem: subcategoryIsSystem)
    }

    private func allowed(_ s: RecordContextActionLogic.Shape) -> Set<String> {
        Set(RecordBulkActionLogic.Operation.allCases.filter { RecordBulkActionLogic.allows($0, s) }.map { "\($0)" })
    }

    @Test func personalRecord_allowsEverything() {
        #expect(allowed(shape()) == ["delete", "amount", "note", "account", "subcategory", "tags"])
    }

    /// Caso A (yo pagué, cuenta real): lo personal sí —cuenta, categoría, etiquetas, como el editor—; borrar, el monto y
    /// la nota son del grupo.
    @Test func groupExpenseOnARealAccount_keepsOnlyThePersonalFields() {
        #expect(allowed(shape(splitExpense: true)) == ["account", "subcategory", "tags"])
    }

    /// Caso B (pagó otro, cuenta virtual del grupo): la cuenta tampoco, es la del grupo por diseño.
    @Test func groupExpenseOnTheGroupAccount_keepsCategoryAndTags() {
        #expect(allowed(shape(splitExpense: true, accountIsSystem: true)) == ["subcategory", "tags"])
    }

    /// La pata de préstamo (cuenta y subcategoría de sistema) y las liquidaciones: nada. Y sin cuenta hidratada, lo
    /// conservador: nada.
    @Test func derivedLegsSettlementsAndUnhydrated_allowNothing() {
        #expect(allowed(shape(splitExpense: true, accountIsSystem: true, subcategoryIsSystem: true)).isEmpty)
        #expect(allowed(shape(splitSettlement: true)).isEmpty)
        #expect(allowed(shape(splitExpense: true, accountIsNil: true)).isEmpty)
    }

    /// El borrado en lote dice lo mismo que el menú contextual en todo registro.
    @Test func delete_matchesTheContextMenu() {
        let shapes = [
            shape(), shape(splitExpense: true), shape(splitExpense: true, accountIsSystem: true),
            shape(splitExpense: true, accountIsSystem: true, subcategoryIsSystem: true), shape(splitSettlement: true),
            shape(splitExpense: true, accountIsNil: true),
        ]
        for s in shapes {
            #expect(RecordBulkActionLogic.allows(.delete, s) == RecordContextActionLogic.actions(s).canDelete)
        }
    }

    @Test func deleteDialog_plainSelection() {
        let dialog = RecordBulkActionLogic.deleteDialog(deletable: 3, groupRecords: 0)
        #expect(dialog == .init(title: .deleteCount(3), message: .cannotUndo, offersDelete: true))
    }

    @Test func deleteDialog_mixedSelection_saysWhatStays() {
        let dialog = RecordBulkActionLogic.deleteDialog(deletable: 2, groupRecords: 1)
        #expect(dialog == .init(title: .deleteCount(2), message: .cannotUndoKeepingGroupRecords(1), offersDelete: true))
    }

    /// Nada elegido: no habla de grupos ni ofrece borrar.
    @Test func deleteDialog_emptySelection() {
        let dialog = RecordBulkActionLogic.deleteDialog(deletable: 0, groupRecords: 0)
        #expect(dialog == .init(title: .deleteCount(0), message: .cannotUndo, offersDelete: false))
    }

    /// Todo de grupo: nada que borrar, y la confirmación no ofrece «Eliminar».
    @Test func deleteDialog_onlyGroupRecords_offersNoDelete() {
        let dialog = RecordBulkActionLogic.deleteDialog(deletable: 0, groupRecords: 2)
        #expect(dialog == .init(title: .onlyGroupRecords, message: .deleteFromGroup, offersDelete: false))
    }
}

/// El ViewModel con un store real: el guard vive en el escritor, así que se prueba ahí.
@MainActor
@Suite("Registros: el lote no toca lo que viene de un grupo", .serialized)
struct RecordsViewModelBulkGroupRecordsTests {

    /// Un gasto personal y la pata real de un gasto de grupo (caso A: mi cuenta, con `splitExpenseID`), los dos
    /// guardados y elegidos. Los ids se capturan tras el `save()`: antes son temporales y `context.model(for:)` no los
    /// resuelve (la selección saldría vacía y el test pasaría sin ejecutar nada).
    private func makeSelection(context: ModelContext) throws -> (RecordsViewModel, TransactionItem, TransactionItem) {
        let account = makeTestAccount(context: context, name: "Diaria")
        let personal = TransactionItem(date: .now, amount: -30, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let group = TransactionItem(date: .now, amount: -80, currencyCode: account.currencyCode, note: "Taxi aeropuerto", account: account)
        group.splitExpenseID = UUID().uuidString
        context.insert(personal)
        context.insert(group)
        try context.save()
        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [personal.persistentModelID, group.persistentModelID]
        return (vm, personal, group)
    }

    private func exists(_ tx: TransactionItem, in context: ModelContext) throws -> Bool {
        let id = tx.id
        return try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.id == id })) == 1
    }

    @Test("Borrar en lote se salta el registro de grupo y borra el resto")
    func bulkDelete_keepsTheGroupRecord() throws {
        let context = try makeTestContext()
        let (vm, personal, group) = try makeSelection(context: context)

        #expect(vm.selectionDeleteDialog(context: context)
                == .init(title: .deleteCount(1), message: .cannotUndoKeepingGroupRecords(1), offersDelete: true))

        vm.deleteSelected(context: context)

        #expect(try !exists(personal, in: context), "el gasto personal tenía que borrarse")
        #expect(try exists(group, in: context), "la pata del gasto de grupo se borró desde Registros")
    }

    @Test("Cambiar el monto en lote con un registro de grupo no toca ninguno y avisa")
    func bulkAmount_isBlockedWithAMessage() throws {
        let context = try makeTestContext()
        let (vm, personal, group) = try makeSelection(context: context)

        vm.bulkUpdateAmount(5, context: context)

        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords)
        #expect(personal.amount == -30, "todo o nada: el personal tampoco cambia")
        #expect(group.amount == -80)
    }

    @Test("La nota en lote con un registro de grupo, tampoco")
    func bulkNote_isBlocked() throws {
        let context = try makeTestContext()
        let (vm, personal, group) = try makeSelection(context: context)

        vm.bulkUpdateNote("Otra", context: context)

        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords)
        #expect(personal.note == "Taxi")
        #expect(group.note == "Taxi aeropuerto")
    }

    /// Control: lo personal del caso A sigue editable en lote (el editor también deja cambiar la cuenta).
    @Test("Cambiar la cuenta de un gasto de grupo pagado con mi cuenta sí se puede")
    func bulkAccount_caseA_isAllowed() throws {
        let context = try makeTestContext()
        let (vm, personal, group) = try makeSelection(context: context)
        let other = makeTestAccount(context: context, name: "Ahorros", currencyCode: personal.currencyCode)
        try context.save()

        vm.bulkUpdateAccount(other, context: context)

        #expect(vm.bulkUpdateError == nil)
        #expect(personal.account?.name == "Ahorros")
        #expect(group.account?.name == "Ahorros")
    }

    /// Pero no a una cuenta de OTRA divisa: el puente de grupos exige la del gasto y, si no casa, borra el registro y lo
    /// devuelve como borrador (review adversarial del lote 8). El editor tampoco lo ofrece.
    @Test("Mover un gasto de grupo a una cuenta de otra divisa no se puede")
    func bulkAccount_groupRecordToAnotherCurrency_isBlocked() throws {
        let context = try makeTestContext()
        let (vm, personal, group) = try makeSelection(context: context)
        let otherCode = normalizeCurrencyCode(personal.currencyCode) == "USD" ? "EUR" : "USD"
        let foreign = makeTestAccount(context: context, name: "Dólares", currencyCode: otherCode)
        try context.save()

        vm.bulkUpdateAccount(foreign, context: context)

        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords)
        #expect(group.account?.name == "Diaria")
        #expect(group.currencyCode == personal.currencyCode)
        #expect(personal.account?.name == "Diaria", "todo o nada")
    }

    /// El cableado de las otras operaciones: con una liquidación elegida (todo lo manda el grupo), ni categoría ni
    /// etiquetas; y una pata en la cuenta virtual del grupo (caso B) no cambia de cuenta.
    @Test("Categoría, etiquetas y cuenta del caso B también pasan por la regla")
    func otherOperations_areWired() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)
        let settlement = TransactionItem(date: .now, amount: -50, currencyCode: account.currencyCode, note: "Pago a Caro", account: account)
        settlement.splitSettlementID = UUID().uuidString
        let groupAccount = makeTestAccount(context: context, name: "Grupos PEN", currencyCode: account.currencyCode)
        groupAccount.isSystemAccount = true
        let caseB = TransactionItem(date: .now, amount: -40, currencyCode: account.currencyCode, note: "Cena", account: groupAccount)
        caseB.splitExpenseID = UUID().uuidString
        context.insert(settlement)
        context.insert(caseB)
        try context.save()

        let vm = RecordsViewModel()
        vm.updateSubcategory(subcategory, ids: [settlement.persistentModelID], context: context)
        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords, "categoría de una liquidación")
        #expect(settlement.subcategory == nil)

        vm.bulkUpdateError = nil
        vm.selectedRecordIDs = [settlement.persistentModelID]
        vm.bulkAddTags([], context: context)
        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords, "añadir etiquetas a una liquidación")
        vm.bulkUpdateError = nil
        vm.bulkRemoveTags([], context: context)
        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords, "quitar etiquetas a una liquidación")

        vm.bulkUpdateError = nil
        vm.selectedRecordIDs = [caseB.persistentModelID]
        vm.bulkUpdateAccount(account, context: context)
        #expect(vm.bulkUpdateError == L10n.BulkEdit.cannotEditGroupRecords, "cuenta del caso B")
        #expect(caseB.account?.name == "Grupos PEN")
    }

    /// Sin registros de grupo, el borrado en lote es el de siempre.
    @Test("Sin registros de grupo, el borrado en lote no cambia")
    func bulkDelete_withoutGroupRecords_deletesAll() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context)
        let a = TransactionItem(date: .now, amount: -1, currencyCode: account.currencyCode, note: "A", account: account)
        let b = TransactionItem(date: .now, amount: -2, currencyCode: account.currencyCode, note: "B", account: account)
        context.insert(a)
        context.insert(b)
        try context.save()
        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID]

        #expect(vm.selectionDeleteDialog(context: context) == .init(title: .deleteCount(2), message: .cannotUndo, offersDelete: true))
        vm.deleteSelected(context: context)

        #expect(try !exists(a, in: context))
        #expect(try !exists(b, in: context))
    }
}
