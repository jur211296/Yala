//
//  InboxOldPendingDraftTests.swift
//  YalaTests
//
//  Lote 03 de las necesarias 2.3, punto 2 (ticket `inbox-list-capped-at-500-may-hide-old-pending-drafts`): la lista de la
//  Bandeja leía como mucho los 500 borradores más recientes de todos los estados, y un pendiente creado antes de esos 500
//  no salía ni en la lista ni en su contador. Es la medida que pedía el ticket: 600 archivados más nuevos que un
//  pendiente. Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bandeja — un pendiente antiguo sale aunque haya muchos archivados", .serialized)
struct InboxOldPendingDraftTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func anOldPendingDraft_behind600ResolvedOnes_staysInTheList() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")

        let oldPending = InboxDraft(note: "Pendiente viejo", amount: -10, date: start, account: account, needsUserInput: [])
        oldPending.createdAt = start
        context.insert(oldPending)

        for index in 1...600 {
            let resolved = InboxDraft(note: "Archivado \(index)", amount: -1, date: start, account: account, needsUserInput: [])
            resolved.createdAt = start.addingTimeInterval(TimeInterval(index * 60))
            resolved.status = index.isMultiple(of: 2) ? .approved : .rejected
            resolved.cachedAccountName = "Cuenta"
            context.insert(resolved)
        }
        try context.save()

        let viewModel = InboxViewModel()
        viewModel.setContext(context)

        let pending = viewModel.filteredDrafts(for: .pending)
        #expect(pending.map(\.note) == ["Pendiente viejo"], "El pendiente viejo quedó fuera de la lista.")
        #expect(viewModel.countForFilter(.pending) == 1)
        // Los resueltos siguen con su tope.
        #expect(viewModel.countForFilter(.archived) == InboxViewModel.resolvedDraftsLimit)
    }

    /// La lista junta las dos lecturas en el orden de siempre: lo más nuevo primero.
    @Test func merge_keepsNewestFirst() {
        let older = InboxDraft(note: "Viejo", needsUserInput: [])
        older.createdAt = start
        let newer = InboxDraft(note: "Nuevo", needsUserInput: [])
        newer.createdAt = start.addingTimeInterval(60)
        let newest = InboxDraft(note: "Más nuevo", needsUserInput: [])
        newest.createdAt = start.addingTimeInterval(120)

        let merged = InboxDraftListMerge.newestFirst(pending: [older, newest], resolved: [newer])
        #expect(merged.map(\.note) == ["Más nuevo", "Nuevo", "Viejo"])
    }
}
