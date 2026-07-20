//
//  AccountDeletionServiceTests.swift
//  YalaTests
//
//  G5-D1b: coordinador de "Eliminar mi cuenta". Verifica el ORDEN CONGELADO de efectos (anti corpus-zombie),
//  la matriz por modo (.cloud vs solo-grupos), el skip de `groups_forget_user` con el flag OFF, y que un fallo
//  en CUALQUIER paso deja el estado local INTACTO + reintentable. Con dependencias inyectadas (mocks) — sin
//  red ni singletons.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AccountDeletionServiceTests {

    /// Control mutable compartido por los closures mock (permite ejercitar el retry cambiando flags entre
    /// corridas).
    final class Ctrl {
        var events: [String] = []
        var forgetThrows = false
        var deleteOutcome: DeleteOutcome = .success
        var closeGroupsResult = true
        var canDelete = true
        var groupsEnabled = false
        var isCloud = true
        var deleteMarkerThrows = false
    }

    private func makeService(_ c: Ctrl) -> AccountDeletionService {
        let deps = AccountDeletionService.Dependencies(
            canDelete: { c.canDelete },
            groupsBackendEnabled: { c.groupsEnabled },
            storageModeIsCloud: { c.isCloud },
            forgetGroupsUser: {
                c.events.append("forget")
                if c.forgetThrows { throw GroupsRPCError.transient(status: 500) }
            },
            teardown: { c.events.append("teardown") },
            deletePersonalAccount: { c.events.append("delete"); return c.deleteOutcome },
            revokeSIWA: { c.events.append("siwa") },
            revokeGoogle: { c.events.append("google") },
            closeLocalCloud: { c.events.append("closeCloud") },
            closeLocalGroupsOnly: { _ in c.events.append("closeGroupsOnly"); return c.closeGroupsResult },
            clearCloudBeacon: { c.events.append("clearBeacon") },
            deleteCloudKitMarker: { _ in
                c.events.append("deleteMarker")
                if c.deleteMarkerThrows { throw GroupsRPCError.transient(status: 500) }
            }
        )
        return AccountDeletionService(deps: deps)
    }

    // MARK: - Orden de efectos + matriz por modo

    @Test func cloud_groupsEnabled_ordersEffects_forgetFirst() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // D7: higiene post-delete (clearBeacon → deleteMarker) entre el delete y los revokes.
        #expect(c.events == [
            "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func cloud_groupsDisabled_skipsForget() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.isCloud = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // groups_forget_user NO se llama (sin datos de grupos en el backend con el flag OFF).
        #expect(c.events == [
            "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func groupsOnly_usesGroupsOnlyLocalClose() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events == [
            "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeGroupsOnly",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    // MARK: - Fallos por paso (local intacto + reintentable)

    @Test func forgetFails_stopsBeforeTeardown_failedGroups() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // NADA local tocado: ni teardown ni delete.
        #expect(c.events == ["forget"])
        #expect(sut.phase == .failed(step: .groups))
    }

    @Test func deleteFails_transient_stopsBeforeClose_failedDelete() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .transient(detail: "500")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // Teardown corrió (idempotente), pero ni SIWA ni cierre local.
        #expect(c.events == ["teardown", "delete"])
        #expect(sut.phase == .failed(step: .delete))
    }

    @Test func deleteFails_sessionExpired_failedDelete() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .sessionExpired(detail: "401")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events == ["teardown", "delete"])
        #expect(sut.phase == .failed(step: .delete))
    }

    @Test func groupsOnlyClose_quiescenceFails_failedLocalClose() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false; c.closeGroupsResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // El borrado server-side YA ocurrió; el cierre local no cerró la sesión → reintentable.
        #expect(c.events == [
            "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeGroupsOnly",
        ])
        #expect(sut.phase == .failed(step: .localClose))
    }

    // MARK: - Guards / retry

    @Test func noSession_isNoOp() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.canDelete = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.isEmpty)
        #expect(sut.phase == .idle)
    }

    @Test func retry_afterFailure_reentersAndCompletes() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .failed(step: .groups))

        // El usuario reintenta y esta vez forget pasa.
        c.forgetThrows = false
        await sut.deleteAccount(context: ctx)

        #expect(sut.phase == .awaitingRelaunch)
        #expect(c.events == [
            "forget", "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
    }

    @Test func awaitingRelaunch_isTerminal_noReentry() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl()
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .awaitingRelaunch)

        c.events.removeAll()
        await sut.deleteAccount(context: ctx)  // no-op en estado terminal
        #expect(c.events.isEmpty)
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func acknowledgeFailure_resetsToIdle() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .failed(step: .groups))

        sut.acknowledgeFailure()
        #expect(sut.phase == .idle)
    }

    // MARK: - D7: higiene post-delete best-effort (faro/marcador)

    /// Si la limpieza del marcador LANZA, el flujo NO se rompe: el borrado se completa igual
    /// (`.awaitingRelaunch`). El faro ya se limpió (crítico para R9) y los revokes + cierre corren después.
    @Test func hygieneMarkerThrows_doesNotBreakFlow() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.isCloud = true; c.deleteMarkerThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // El fallo del marcador se traga: clearBeacon + deleteMarker (intentado) + revokes + cierre corren.
        #expect(c.events == [
            "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    /// La higiene NUNCA corre si el borrado server-side no fue exitoso (jamás limpiar el faro/marcador de
    /// una cuenta que sigue viva).
    @Test func hygiene_notRun_whenDeleteFails() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .transient(detail: "500")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(!c.events.contains("clearBeacon"))
        #expect(!c.events.contains("deleteMarker"))
        #expect(sut.phase == .failed(step: .delete))
    }

    // MARK: - D7: closure REAL de deleteCloudKitMarker (guard !isEmpty = red del invariante (b))

    /// Store SIN marcador (caso solo-grupos 5b: el personal nunca migró): el `guard !markers.isEmpty`
    /// retorna ANTES de cualquier `save()` — jamás toca el mainContext compartido con el mirror `.icloud`
    /// vivo (invariante de quiescencia (b)). No lanza.
    @Test func liveDeleteMarker_emptyStore_returnsWithoutSaveOrThrow() throws {
        let ctx = try makeTestContext()
        try AccountDeletionService.Dependencies.live.deleteCloudKitMarker(ctx)
        // Sin marcadores antes y después; no hay throw (el guard corta antes del save).
        let count = try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>())
        #expect(count == 0)
    }

    /// Store CON marcador (caso `.cloud`): la closure lo borra y persiste.
    @Test func liveDeleteMarker_presentMarker_deletesIt() throws {
        let ctx = try makeTestContext()
        ctx.insert(CloudMigrationMarker(accountHash: "abc", serverSeqCut: 42))
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 1)

        try AccountDeletionService.Dependencies.live.deleteCloudKitMarker(ctx)

        #expect(try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 0)
    }
}

@Suite
struct AccountDeletionRowLogicTests {

    @Test func shows_onlyWithLiveSession_notSecondary_notGroupInvite() {
        #expect(AccountDeletionRowLogic.shouldShow(
            hasSession: true, secondaryActive: false, isGroupInviteMode: false))
    }

    @Test func hidden_withoutSession() {
        #expect(!AccountDeletionRowLogic.shouldShow(
            hasSession: false, secondaryActive: false, isGroupInviteMode: false))
    }

    @Test func hidden_inSecondarySession() {
        #expect(!AccountDeletionRowLogic.shouldShow(
            hasSession: true, secondaryActive: true, isGroupInviteMode: false))
    }

    @Test func hidden_inGroupInviteMode() {
        #expect(!AccountDeletionRowLogic.shouldShow(
            hasSession: true, secondaryActive: false, isGroupInviteMode: true))
    }
}
