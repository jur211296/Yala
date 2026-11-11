//
//  RecordsBulkUndo23Tests.swift
//  YalaTests
//
//  Registros, decisión 18 de la revisión 2.3 (E1 + E2): el borrado y la edición en lote se pueden deshacer, y la
//  pregunta de borrar dice de qué fechas y por cuánto. Con el código de antes, `deleteSelected` borraba en el acto y
//  `applyBulkEdit` no guardaba nada que devolver: los casos de abajo salían rojos.
//
//  Los textos (separador de miles, «Ahora:») van en `RecordsBulkUndo23TextosTests`, en su propio fichero: necesitan el
//  idioma aislado y esta suite necesita contexto (regla de `testing.md`: dos suites con contexto, dos ficheros).
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Registros · lote con «Deshacer» (decisión 18 de 2.3)", .serialized)
struct RecordsBulkUndo23Tests {

    private func exists(_ tx: TransactionItem, in context: ModelContext) throws -> Bool {
        let id = tx.id
        return try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.id == id })) == 1
    }

    private func manualTimer(_ pending: RecordPendingDeletion) -> ManualBatchTimer {
        let timer = ManualBatchTimer()
        pending.batchSleep = { try await timer.sleep($0) }
        return timer
    }

    private func restoreTimer(_ pending: RecordPendingDeletion) {
        pending.undoAll()
        pending.commitDelayForBatch = RecordPendingDeletion.commitDelay
        pending.batchSleep = { try await Task.sleep(for: $0) }
    }

    // MARK: - Borrar en lote se puede deshacer

    /// Punto 1: borrar lo elegido ya no borra en el acto. Espera escondido, «Deshacer» lo devuelve todo y nada se tocó en
    /// la base (por eso no hay nada que subir a iCloud).
    @Test func bulkDelete_waitsHidden_andUndoBringsEverythingBack() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let b = TransactionItem(date: .now, amount: -45, currencyCode: account.currencyCode, note: "Taxi aeropuerto", account: account)
        let leg = TransactionItem(date: .now, amount: -50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let otherLeg = TransactionItem(date: .now, amount: 50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        for tx in [leg, otherLeg] {
            tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            tx.transferPairID = "pair-bulk"
        }
        for tx in [a, b, leg, otherLeg] { context.insert(tx) }
        try context.save()
        let pending = RecordPendingDeletion.shared
        defer { restoreTimer(pending) }

        let vm = RecordsViewModel()
        vm.isSelectionMode = true
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID, leg.persistentModelID]
        vm.deleteSelected(context: context)

        #expect(!vm.isSelectionMode)
        #expect(try exists(a, in: context), "el lote se borró en el acto: no se puede deshacer")
        #expect(try exists(leg, in: context))
        #expect(pending.hides(a.persistentModelID, transferPairID: nil))
        #expect(pending.hides(b.persistentModelID, transferPairID: nil))
        #expect(pending.hides(otherLeg.persistentModelID, transferPairID: "pair-bulk"), "la otra pata también se esconde")

        pending.undoAll()
        #expect(!pending.hides(a.persistentModelID, transferPairID: nil))
        #expect(!pending.hides(otherLeg.persistentModelID, transferPairID: "pair-bulk"))
        #expect(try exists(a, in: context) && exists(b, in: context) && exists(leg, in: context) && exists(otherLeg, in: context))
    }

    /// Sin «Deshacer», al vencer el aviso se borra todo lo elegido y la pareja de la transferencia, con UN guardado; un
    /// registro devuelto suelto (`undo(_:)`) se queda.
    @Test func bulkDelete_commitsWhatIsStillPending_includingThePair() async throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let kept = TransactionItem(date: .now, amount: -9, currencyCode: account.currencyCode, note: "Café", account: account)
        let leg = TransactionItem(date: .now, amount: -50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let otherLeg = TransactionItem(date: .now, amount: 50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        for tx in [leg, otherLeg] {
            tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            tx.transferPairID = "pair-commit"
        }
        for tx in [a, kept, leg, otherLeg] { context.insert(tx) }
        try context.save()
        let pending = RecordPendingDeletion.shared
        let timer = manualTimer(pending)
        defer { restoreTimer(pending) }

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, kept.persistentModelID, leg.persistentModelID, otherLeg.persistentModelID]
        vm.deleteSelected(context: context)
        pending.undo(kept.persistentModelID)

        #expect(await timer.settle { timer.pendingCount == 1 })
        timer.fireAll()
        #expect(await timer.settle { !pending.hides(a.persistentModelID, transferPairID: nil) })
        #expect(try !exists(a, in: context))
        #expect(try !exists(leg, in: context))
        #expect(try !exists(otherLeg, in: context))
        #expect(try exists(kept, in: context), "lo devuelto suelto no se borra con el lote")
    }

    /// Lo de un grupo no entra en el lote que espera (lo dice la pregunta) y no se borra al vencer.
    @Test func bulkDelete_leavesGroupRecordsOut() async throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let personal = TransactionItem(date: .now, amount: -20, currencyCode: account.currencyCode, note: "Almuerzo", account: account)
        let group = TransactionItem(date: .now, amount: -80, currencyCode: account.currencyCode, note: "Taxi aeropuerto", account: account)
        group.splitExpenseID = UUID().uuidString
        context.insert(personal)
        context.insert(group)
        try context.save()
        let pending = RecordPendingDeletion.shared
        let timer = manualTimer(pending)
        defer { restoreTimer(pending) }

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [personal.persistentModelID, group.persistentModelID]
        vm.deleteSelected(context: context)
        #expect(!pending.hides(group.persistentModelID, transferPairID: nil))

        #expect(await timer.settle { timer.pendingCount == 1 })
        timer.fireAll()
        #expect(await timer.settle { !pending.hides(personal.persistentModelID, transferPairID: nil) })
        #expect(try !exists(personal, in: context))
        #expect(try exists(group, in: context))
    }

    // MARK: - Editar en lote se puede deshacer

    /// Punto 1, edición: «Deshacer» devuelve la categoría, la nota y las etiquetas de antes.
    @Test func bulkEdit_undoRestoresWhatEachRecordHad() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let category = makeTestCategory(context: context, name: "Transporte")
        let taxis = makeTestSubcategory(context: context, name: "Taxis y apps", category: category)
        let publicTransport = makeTestSubcategory(context: context, name: "Transporte público", category: category)
        let trip = makeTestTag(context: context, name: "Viaje")
        let work = makeTestTag(context: context, name: "Trabajo")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", category: category, subcategory: taxis, account: account)
        let b = TransactionItem(date: .now, amount: -45, currencyCode: account.currencyCode, note: nil, category: category, subcategory: taxis, account: account)
        a.setTags(from: [trip])
        context.insert(a)
        context.insert(b)
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID]
        var changes = BulkEditChanges()
        changes.subcategory = publicTransport
        changes.tagsToAdd = [work]
        changes.note = "Movilidad"
        #expect(vm.applyBulkEdit(changes, context: context))
        #expect(a.subcategory?.name == "Transporte público")
        #expect(b.note == "Movilidad")
        #expect(a.resolvedTagIDs() == [trip.id, work.id])

        #expect(vm.undoLastBulkEdit(context: context) == 2)
        #expect(a.subcategory?.name == "Taxis y apps")
        #expect(b.subcategory?.name == "Taxis y apps")
        #expect(a.note == "Taxi")
        #expect(b.note == nil)
        #expect(a.resolvedTagIDs() == [trip.id])
        #expect((b.resolvedTagIDs() ?? []).isEmpty)
        #expect(!context.hasChanges, "deshacer guarda: si no, el cambio no sube y se pierde al cerrar")
    }

    /// Un registro que otro camino cambió en los segundos del aviso no se pisa; los demás sí vuelven.
    @Test func bulkEdit_undoSkipsARecordChangedMeanwhile() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let b = TransactionItem(date: .now, amount: -45, currencyCode: account.currencyCode, note: "Aeropuerto", account: account)
        context.insert(a)
        context.insert(b)
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID]
        var changes = BulkEditChanges()
        changes.note = "Movilidad"
        #expect(vm.applyBulkEdit(changes, context: context))
        b.note = "Lo cambié en su editor"
        try context.save()

        #expect(vm.undoLastBulkEdit(context: context) == 1)
        #expect(a.note == "Taxi")
        #expect(b.note == "Lo cambié en su editor")
    }

    /// Mover a una cuenta en otra divisa convierte el importe; deshacer devuelve cuenta, divisa e importe de antes.
    @Test func bulkEdit_undoRestoresAccountCurrencyAndAmount() throws {
        let context = try makeTestContext()
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let dollars = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let a = TransactionItem(date: .now, amount: -100, currencyCode: "PEN", note: "Compra", account: soles)
        let b = TransactionItem(date: .now, amount: -50, currencyCode: "PEN", note: "Otra", account: soles)
        context.insert(a)
        context.insert(b)
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID]
        var changes = BulkEditChanges()
        changes.account = dollars
        #expect(vm.applyBulkEdit(changes, context: context))
        #expect(a.account?.name == "Dólares")
        #expect(a.currencyCode == "USD")

        #expect(vm.undoLastBulkEdit(context: context) == 2)
        #expect(a.account?.name == "Soles")
        #expect(a.currencyCode == "PEN")
        #expect(a.amount == -100)
        #expect(b.amount == -50)
    }

    /// Un lote que no cambia nada (la nota ya era esa) no ofrece «Deshacer»: no hay nada que devolver.
    @Test func bulkEdit_withNothingChanged_offersNoUndo() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let b = TransactionItem(date: .now, amount: -45, currencyCode: account.currencyCode, note: "Taxi", account: account)
        context.insert(a)
        context.insert(b)
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [a.persistentModelID, b.persistentModelID]
        var changes = BulkEditChanges()
        changes.note = "Taxi"
        #expect(vm.applyBulkEdit(changes, context: context))
        #expect(vm.lastBulkEditUndo?.changedCount == 0, "nada cambió: no hay aviso que deshacer")
    }

    // MARK: - La pregunta de borrar dice qué se va (E2)

    @Test func deleteSummary_saysTheDatesAndTheTotalInOneCurrency() {
        let first = Date(timeIntervalSince1970: 1_731_024_000)   // 8 nov 2024
        let last = Date(timeIntervalSince1970: 1_762_473_600)    // 7 nov 2025
        let summary = RecordBulkActionLogic.summary(of: [
            (date: last, amount: -12, currencyCode: "PEN", amountInPreferred: -12),
            (date: first, amount: -45.5, currencyCode: "pen", amountInPreferred: -45.5),
            (date: first.addingTimeInterval(86_400), amount: 100, currencyCode: "PEN", amountInPreferred: 100),
        ], preferredCurrencyCode: "USD")
        #expect(summary?.firstDate == first)
        #expect(summary?.lastDate == last)
        #expect(summary?.total == 157.5, "suma sin signo: es cuánto se va, no un saldo")
        #expect(summary?.currencyCode == "PEN", "todo en soles: en soles, aunque la principal sea otra")
        #expect(summary?.isApproximate == false)
        #expect(RecordBulkActionLogic.summary(of: [], preferredCurrencyCode: "PEN") == nil)
    }

    /// Soles con dólares no se suman tal cual: van en la moneda principal y con «≈».
    @Test func deleteSummary_withSeveralCurrencies_isApproximateInThePreferredOne() {
        let day = Date(timeIntervalSince1970: 1_731_024_000)
        let mixed = RecordBulkActionLogic.summary(of: [
            (date: day, amount: -12, currencyCode: "PEN", amountInPreferred: -12),
            (date: day, amount: -5, currencyCode: "USD", amountInPreferred: -18.75),
        ], preferredCurrencyCode: "PEN")
        #expect(mixed?.total == 30.75)
        #expect(mixed?.currencyCode == "PEN")
        #expect(mixed?.isApproximate == true)
    }

    @Test func deleteDialog_offersUndo_andSummarisesOnlyWithMoreThanOne() {
        let summary = RecordBulkActionLogic.Summary(firstDate: .now, lastDate: .now, total: 10, currencyCode: "PEN")
        let many = RecordBulkActionLogic.deleteDialog(deletable: 2334, groupRecords: 0, summary: summary)
        #expect(many.message == .undoable)
        #expect(many.summary == summary)
        let one = RecordBulkActionLogic.deleteDialog(deletable: 1, groupRecords: 0, summary: summary)
        #expect(one.summary == nil, "con uno, la pregunta ya lo nombra")
        let withGroup = RecordBulkActionLogic.deleteDialog(deletable: 2, groupRecords: 1, summary: summary)
        #expect(withGroup.message == .undoableKeepingGroupRecords(1))
    }

    // MARK: - «Seleccionar día» (E2)

    @Test func selectDay_marksTheDay_andASecondTapUnmarksIt() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let a = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let b = TransactionItem(date: .now, amount: -45, currencyCode: account.currencyCode, note: "Taxi", account: account)
        let other = TransactionItem(date: .now, amount: -9, currencyCode: account.currencyCode, note: "Café", account: account)
        for tx in [a, b, other] { context.insert(tx) }
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [other.persistentModelID, a.persistentModelID]
        #expect(!vm.isDayFullySelected([a, b]))
        vm.toggleDaySelection([a, b])
        #expect(vm.selectedRecordIDs == [a.persistentModelID, b.persistentModelID, other.persistentModelID])
        #expect(vm.isDayFullySelected([a, b]))
        vm.toggleDaySelection([a, b])
        #expect(vm.selectedRecordIDs == [other.persistentModelID], "quitar el día no toca lo elegido de otros días")
    }

    // MARK: - El «antes» de miles (medido)

    /// La decisión pedía medir cuánto cuesta guardar el «antes» de miles de registros. 3.000 registros (más que los
    /// 2.334 de la semilla realista): foto + lote + deshacer, y el borrado en lote (pedirlo y vencer). Imprime las cifras
    /// y pone un techo holgado para que un cambio que lo dispare (un fetch por registro, un guardado por registro) se vea.
    @Test func thousandsOfRecords_captureAndUndoStayCheap() async throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let category = makeTestCategory(context: context, name: "Transporte")
        let taxis = makeTestSubcategory(context: context, name: "Taxis y apps", category: category)
        let publicTransport = makeTestSubcategory(context: context, name: "Transporte público", category: category)
        var records: [TransactionItem] = []
        for index in 0..<3_000 {
            let tx = TransactionItem(
                date: Date(timeIntervalSince1970: 1_731_024_000 + Double(index) * 20_000),
                amount: -Double(index % 90 + 1), currencyCode: account.currencyCode, note: "Taxi \(index)",
                category: category, subcategory: taxis, account: account)
            context.insert(tx)
            records.append(tx)
        }
        try context.save()
        let clock = ContinuousClock()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = Set(records.map(\.persistentModelID))
        var changes = BulkEditChanges()
        changes.subcategory = publicTransport
        var applied = false
        let applyTime = clock.measure { applied = vm.applyBulkEdit(changes, context: context) }
        #expect(applied)
        let captureOnly = clock.measure {
            _ = RecordBulkEditUndo.capture(records, context: context)
        }
        var restored = 0
        let undoTime = clock.measure { restored = vm.undoLastBulkEdit(context: context) }
        #expect(restored == 3_000)
        #expect(records.allSatisfy { $0.subcategory?.name == "Taxis y apps" })

        let pending = RecordPendingDeletion.shared
        let timer = manualTimer(pending)
        defer { restoreTimer(pending) }
        vm.selectedRecordIDs = Set(records.map(\.persistentModelID))
        let requestTime = clock.measure { vm.deleteSelected(context: context) }
        #expect(pending.pendingIDs.count == 3_000)
        // «Deshacer» con los 3.000 esperando (review del lote: era cuadrático y congelaba la pantalla).
        let undoDeleteTime = clock.measure { pending.undoAll() }
        #expect(pending.pendingIDs.isEmpty)
        vm.selectedRecordIDs = Set(records.map(\.persistentModelID))
        vm.deleteSelected(context: context)
        #expect(await timer.settle { timer.pendingCount == 1 })
        let commitStart = clock.now
        timer.fireAll()
        #expect(await timer.settle { pending.pendingIDs.isEmpty })
        let commitTime = clock.now - commitStart
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)

        print("RecordsBulkUndo23 · 3.000 registros: foto del antes \(captureOnly), lote con foto \(applyTime), deshacer \(undoTime), pedir el borrado \(requestTime), deshacer el borrado \(undoDeleteTime), borrar al vencer \(commitTime)")
        #expect(captureOnly < .seconds(3))
        #expect(undoTime < .seconds(10))
        #expect(requestTime < .seconds(5))
        #expect(undoDeleteTime < .seconds(1))
    }

    // MARK: - Lo que cazó la review adversarial

    /// Una transferencia con sus dos patas elegidas cuenta una vez en la cifra de la pregunta.
    @Test func deleteDialog_countsATransferOnceInTheTotal() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let leg = TransactionItem(date: .now, amount: -100, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let otherLeg = TransactionItem(date: .now, amount: 100, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let taxi = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        for tx in [leg, otherLeg] {
            tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            tx.transferPairID = "pair-total"
        }
        for tx in [leg, otherLeg, taxi] { context.insert(tx) }
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [leg.persistentModelID, otherLeg.persistentModelID, taxi.persistentModelID]
        let dialog = vm.selectionDeleteDialog(context: context)
        #expect(dialog.summary?.total == 112, "la transferencia de 100 se sumó dos veces")
    }

    /// El aviso de la edición cuenta lo ELEGIDO, no la otra pata de cada transferencia que el lote también toca.
    @Test func bulkEditNotice_countsOnlyTheChosenRecords() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let tag = makeTestTag(context: context, name: "Viaje")
        let leg = TransactionItem(date: .now, amount: -100, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let otherLeg = TransactionItem(date: .now, amount: 100, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let taxi = TransactionItem(date: .now, amount: -12, currencyCode: account.currencyCode, note: "Taxi", account: account)
        for tx in [leg, otherLeg] {
            tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            tx.transferPairID = "pair-tags"
        }
        for tx in [leg, otherLeg, taxi] { context.insert(tx) }
        try context.save()

        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [leg.persistentModelID, taxi.persistentModelID]
        var changes = BulkEditChanges()
        changes.tagsToAdd = [tag]
        #expect(vm.applyBulkEdit(changes, context: context))
        #expect(otherLeg.resolvedTagIDs() == [tag.id], "la etiqueta se propaga a la otra pata")
        #expect(vm.lastBulkEditUndo?.changedCount == 2, "«Cambiaste 2», como «Aplicar a 2»")
        #expect(vm.undoLastBulkEdit(context: context) == 3)
        #expect((otherLeg.resolvedTagIDs() ?? []).isEmpty, "deshacer devuelve también la otra pata")
    }
}
