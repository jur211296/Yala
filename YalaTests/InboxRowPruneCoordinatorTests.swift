//
//  InboxRowPruneCoordinatorTests.swift
//  YalaTests
//
//  Regresión DETERMINISTA (cualquier iOS) del fix del crash 2.0.5/iOS 27: la capa de servicio
//  debe PODAR la fila del `InboxViewModel` ANTES de borrar el `InboxDraft`, para que
//  `InboxDraftRowView` no re-renderice leyendo un @Model invalidado (SIGTRAP de SwiftData que
//  solo dispara en iOS 27+, irreproducible en un sim 26.x). Estos tests verifican el MECANISMO
//  (poda vía `InboxRowPruneCoordinator`), no el trap: revertir la poda en `DraftService`/
//  `ScheduledPaymentDraftService` deja estos tests ROJOS en cualquier OS — la red que el XCUITest
//  no puede dar en un sim 26.x.
//
//  Usa `makeTestContext()` (store in-memory reusado por archivo) + singletons
//  (`DraftService.shared`, `InboxRowPruneCoordinator.shared`, `SessionState.shared`) → la suite
//  DEBE ser `@Suite(.serialized)`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("InboxRowPruneCoordinator — poda de fila antes de borrar", .serialized)
struct InboxRowPruneCoordinatorTests {

    /// `removeDraft(id:)` poda la fila de AMBOS arrays cacheados del VM.
    @Test func removeDraftById_prunesBothArrays() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, note: "A podar")
        try context.save()

        let vm = InboxViewModel()
        vm.setContext(context)
        #expect(vm.allDrafts.contains { $0.persistentModelID == draft.persistentModelID })
        #expect(vm.pendingDrafts.contains { $0.persistentModelID == draft.persistentModelID })

        vm.removeDraft(id: draft.persistentModelID)

        #expect(!vm.allDrafts.contains { $0.persistentModelID == draft.persistentModelID })
        #expect(!vm.pendingDrafts.contains { $0.persistentModelID == draft.persistentModelID })
    }

    /// `setContext` cablea el coordinador → `pruneRow` poda la fila del VM activo.
    @Test func coordinatorPruneRow_prunesWiredViewModel() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, note: "Coordinador")
        try context.save()

        let vm = InboxViewModel()
        vm.setContext(context)  // cablea InboxRowPruneCoordinator.shared.viewModel = vm
        #expect(vm.allDrafts.contains { $0.persistentModelID == draft.persistentModelID })

        InboxRowPruneCoordinator.shared.pruneRow(draft.persistentModelID)

        #expect(!vm.allDrafts.contains { $0.persistentModelID == draft.persistentModelID })
    }

    /// END-TO-END: convertir a gasto de grupo poda la fila del VM ANTES de borrar el draft del
    /// store (misma poda que usan los 4 sheets de finalización + el path scheduled, todos vía
    /// `deleteInboxDraftPruningRow` / el coordinador). Revertir la poda deja el draft en el array
    /// del VM → este `#expect` falla.
    @Test func convert_prunesInboxRowBeforeStoreDelete() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, amount: 42.5, note: "Convertir")
        try context.save()

        let vm = InboxViewModel()
        vm.setContext(context)
        #expect(vm.pendingDrafts.contains { $0.persistentModelID == draft.persistentModelID })

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        // Podado del VM (fila desmontada antes del delete → sin re-render del @Model invalidado).
        #expect(!vm.allDrafts.contains { $0.persistentModelID == draft.persistentModelID })
        #expect(!vm.pendingDrafts.contains { $0.persistentModelID == draft.persistentModelID })
        // Y borrado del store.
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).isEmpty)
    }

    /// Sin Inbox montado (coordinador sin VM), el borrado procede igual (poda = no-op, sin crash).
    @Test func convert_withNoInboxMounted_stillDeletes() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, note: "Sin bandeja")
        try context.save()

        // Desconectar cualquier VM previo (otro test de la suite pudo cablear el coordinador).
        InboxRowPruneCoordinator.shared.viewModel = nil

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).isEmpty)
    }
}
