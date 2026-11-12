//
//  InboxPendingRemovalTests.swift
//  YalaTests
//
//  Crash de TestFlight 2.2 (2), 2026-10-29 (card f8rj): borrar dos borradores seguidos en la Bandeja cerraba Yala con un
//  SIGTRAP de SwiftData desde el `body` de `InboxDraftRowView`, que leía un `InboxDraft` ya borrado. El trap solo sale
//  en el iPhone (iOS 27.2); el simulador 27.0 no lo reproduce. Estos tests fijan los MECANISMOS que lo evitan, en
//  cualquier runtime:
//  - la retirada optimista de `InboxView` (borrado 400 ms después) no vuelve a la lista con una recarga en esa espera;
//  - la lista no ofrece a la vista un borrador que ya no se puede leer.
//  La poda de `deleteDraft`/`bulkDelete` vive en `InboxRowPruneCoordinatorTests`.
//
//  `makeTestContext()` reusa el store por fichero y se llama varias veces ⇒ `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bandeja — lo que espera borrarse no vuelve y lo borrado no se lee", .serialized)
struct InboxPendingRemovalTests {

    private func contains(_ drafts: [InboxDraft], _ draft: InboxDraft) -> Bool {
        drafts.contains { $0.persistentModelID == draft.persistentModelID }
    }

    /// Dos borrados seguidos: el primero termina y recarga mientras el segundo aún espera. La recarga no devuelve el
    /// segundo; con el código de antes volvía a la lista y su fila leía el borrador al borrarse.
    @Test func reloadWhileTheSecondRemovalWaits_doesNotBringItBack() throws {
        let context = try makeTestContext()
        let first = makeTestInboxDraft(context: context, note: "Primero")
        let second = makeTestInboxDraft(context: context, note: "Segundo")
        try context.save()

        let vm = InboxViewModel()
        vm.setContext(context)
        #expect(contains(vm.pendingDrafts, second))

        vm.beginRemoval(first)
        vm.beginRemoval(second)

        // El primero termina su espera: se borra y la Bandeja recarga (`removeDraftWithAnimation`).
        context.delete(first)
        try context.save()
        vm.endRemoval(id: first.persistentModelID)
        vm.loadData()

        #expect(!contains(vm.allDrafts, second), "La recarga del primer borrado devolvió el segundo a la lista.")
        #expect(!contains(vm.pendingDrafts, second))
        #expect(vm.filteredDrafts(for: .pending).isEmpty)
        // Control: el segundo sigue en la base, así que lo que lo deja fuera es la espera y no el fetch.
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).count == 1)
    }

    /// Un descarte o borrado que no llega a hacerse (falla al guardar) devuelve la fila al terminar la espera.
    @Test func removalThatEndsWithoutPersisting_comesBackOnReload() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, note: "Vuelve")
        try context.save()

        let vm = InboxViewModel()
        vm.setContext(context)
        vm.beginRemoval(draft)
        #expect(!contains(vm.pendingDrafts, draft))

        vm.loadData()
        #expect(!contains(vm.pendingDrafts, draft), "Mientras espera, una recarga no lo devuelve.")

        vm.endRemoval(id: draft.persistentModelID)
        vm.loadData()
        #expect(contains(vm.pendingDrafts, draft), "Terminada la espera sin borrarlo, no volvió a la lista.")
    }

    /// Un borrador borrado por otro camino (un servicio, la sincronización) sigue en el array cacheado hasta la próxima
    /// recarga: la lista no lo ofrece a la vista ni lo cuenta.
    @Test func draftDeletedElsewhere_isNotOfferedToTheList() throws {
        let context = try makeTestContext()
        let kept = makeTestInboxDraft(context: context, note: "Se queda")
        let gone = makeTestInboxDraft(context: context, note: "Se va")
        try context.save()

        let vm = InboxViewModel()
        // Sin cablear el coordinador de poda: el borrado llega sin avisar a la Bandeja.
        vm.setContext(context)
        InboxRowPruneCoordinator.shared.viewModel = nil
        #expect(vm.countForFilter(.pending) == 2)

        context.delete(gone)
        #expect(!gone.isReadableInInbox, "Marcado para borrar, todavía sin guardar, ya no se puede leer.")
        try context.save()
        #expect(!gone.isReadableInInbox, "Borrado y guardado, no se puede leer.")
        #expect(kept.isReadableInInbox)
        #expect(contains(vm.allDrafts, gone), "Control: el array cacheado aún lo tiene (nadie recargó).")

        let shown = vm.filteredDrafts(for: .pending)
        #expect(shown.count == 1)
        #expect(contains(shown, kept))
        #expect(vm.countForFilter(.pending) == 1)
        #expect(vm.groupedDrafts(for: .pending).flatMap(\.drafts).count == 1)
    }
}
