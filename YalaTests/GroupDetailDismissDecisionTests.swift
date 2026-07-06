//
//  GroupDetailDismissDecisionTests.swift
//  YalaTests
//
//  Regresión del dismiss-first del detalle de grupo (commit 063f6aff) — lógica pura,
//  sin UI ni SwiftData.
//

import Testing

@testable import Yala

struct GroupDetailDismissDecisionTests {

    @Test func contextNil_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: true, isDeleted: false, isArchived: false, wasArchivedOnAppear: false) == true)
    }

    @Test func deleted_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: true, isArchived: false, wasArchivedOnAppear: false) == true)
    }

    @Test func becameArchivedThisSession_dismisses() {
        // Estaba activo al abrir (wasArchivedOnAppear=false) y ahora está archivado → cerrar.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isArchived: true, wasArchivedOnAppear: false) == true)
    }

    @Test func alreadyArchivedOnOpen_doesNotDismiss() {
        // El usuario entró a propósito a un grupo YA archivado → NO cerrar.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isArchived: true, wasArchivedOnAppear: true) == false)
    }

    @Test func activeAndPresent_doesNotDismiss() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isArchived: false, wasArchivedOnAppear: false) == false)
    }

    @Test func deletedTakesPrecedenceEvenIfWasArchived() {
        // Borrado gana sobre cualquier estado de archivado.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: true, isArchived: true, wasArchivedOnAppear: true) == true)
    }
}
