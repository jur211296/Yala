//
//  EliminarCuentaICloudTests.swift
//  YalaTests / EliminarCuentaICloud
//
//  Card «iCloud privado no tiene “Eliminar mi cuenta”» (Jürgen, 2026-11-19): la cuenta de iCloud privado sin cuenta de
//  Yala (celda C) también lo ofrece. Vacía los datos, deja limpio su iCloud y vuelve al Welcome. No hay servidor que
//  borrar: primero la zona de Yala en su iCloud, después lo de este teléfono, como la celda D sin sus pasos de servidor.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Qué hoja y dónde

@Suite("Eliminar mi cuenta en iCloud privado · la hoja y la fila")
struct EliminarCuentaICloudLogicTests {
    typealias Op = DestructiveScopeLogic.Operation

    @Test("sin cuenta de Yala en iCloud privado, la operación es la de iCloud")
    func operation_cellC() {
        #expect(DestructiveScopeLogic.deleteAccountOperation(
            storageMode: .icloud, hasPrivateSession: true, hasYalaAccount: false, deviceHasGroupRows: false)
            == .deleteAccountICloud)
        #expect(DestructiveScopeLogic.deleteAccountOperation(
            storageMode: .icloud, hasPrivateSession: true, hasYalaAccount: false, deviceHasGroupRows: true)
            == .deleteAccountICloudWithGroups)
    }

    @Test("con cuenta de Yala nada cambia: nube, equipo y solo grupos")
    func operation_cellsWithAccount_unchanged() {
        for groups in [false, true] {
            #expect(DestructiveScopeLogic.deleteAccountOperation(
                storageMode: .cloud, hasPrivateSession: true, hasYalaAccount: true, deviceHasGroupRows: groups)
                == .deleteAccountCloud)
            #expect(DestructiveScopeLogic.deleteAccountOperation(
                storageMode: .icloud, hasPrivateSession: true, hasYalaAccount: true, deviceHasGroupRows: groups)
                == .deleteAccountGroupsOnly)
            #expect(DestructiveScopeLogic.deleteAccountOperation(
                storageMode: .icloud, hasPrivateSession: false, hasYalaAccount: true, deviceHasGroupRows: groups)
                == .deleteAccountGroupsOnlyNoPrivate)
        }
    }

    @Test("la fila sale solo en iCloud privado sin cuenta de Yala, junto a su «Cerrar sesión»")
    func row_onlyInCellC() {
        #expect(DestructiveScopeLogic.offersICloudAccountDeletion(path: .privateSignOut, hasYalaAccount: false))
        // Con cuenta de Yala vive dentro de «Tu cuenta de Yala»: aquí no se repite.
        #expect(!DestructiveScopeLogic.offersICloudAccountDeletion(path: .privateSignOut, hasYalaAccount: true))
        for path in [CloudSignOutFlowLogic.Path.privateWithGroupsSignOut, .cloudSecureSignOut, .groupsOnlySignOut] {
            #expect(!DestructiveScopeLogic.offersICloudAccountDeletion(path: path, hasYalaAccount: false), "\(path)")
        }
    }

    @Test("la hoja dice que se borra de este teléfono y de su iCloud, y ofrece exportar antes")
    func sheet_model() {
        for op in [Op.deleteAccountICloud, .deleteAccountICloudWithGroups] {
            let label = DestructiveScopeLogic.cloudLabel(for: op, storageMode: .icloud)
            #expect(label == .icloud, "la fila ☁️ es su iCloud, no una cuenta de Yala que no existe")
            let m = DestructiveScopeLogic.model(operation: op, cloudLabel: label)
            #expect(m.rows.map(\.tone) == [.destructive, .destructive,
                                          op == .deleteAccountICloudWithGroups ? .neutral : .preserved])
            #expect(!m.hasConservationNote)
            #expect(m.extraLines.isEmpty)
            #expect(m.secondaryActions == [.exportBefore])
            #expect(DestructiveScopeLogic.wipeDescription(for: op) == nil)
            #expect(!DestructiveScopeLogic.requiresNoCopyConfirmation(op))
        }
    }

    @Test("misma hoja que «Eliminar mi cuenta» de la nube: título, botón e identificadores")
    @MainActor
    func sheet_sameTextsAsTheOtherDeletions() {
        let cloud = DestructiveScopeSheet.Config.make(operation: .deleteAccountCloud, cloudLabel: .cloudAccount,
                                                      onConfirm: {}, onExport: {})
        for op in [Op.deleteAccountICloud, .deleteAccountICloudWithGroups] {
            let c = DestructiveScopeSheet.Config.make(operation: op, cloudLabel: .icloud, onConfirm: {}, onExport: {})
            #expect(c.title == cloud.title)
            #expect(c.confirmLabel == cloud.confirmLabel)
            #expect(c.confirmIdentifier == "delete_account_continue")
            #expect(c.secondaries.map(\.identifier) == ["delete_account_export_before"])
            #expect(c.secondaries.first?.caption == nil, "sin cuenta de Yala no hay «En modo nube…»")
            #expect(c.rows.map(\.detail) == [
                L10n.Settings.deleteAccountScopeDeviceCloud,
                L10n.Settings.wipeScopeCloudICloudPersonal,
                op == .deleteAccountICloudWithGroups ? L10n.Settings.scopeForgetGroups : L10n.Settings.scopeUntouchedShort])
        }
        #expect(DestructiveScopeSheet.Config.scenarioIdentifier(for: .deleteAccountICloud)
                == "destructive_scope_sheet_delete_account_icloud")
    }
}

// MARK: - El borrado

@MainActor
@Suite("Eliminar mi cuenta en iCloud privado · el orden del borrado", .serialized)
struct EliminarCuentaICloudServiceTests {

    final class Ctrl {
        var events: [String] = []
        var wipeICloudResult = true
        var closePrivateResult = true
        var hasPrivateSession = true
        var isCloud = false
        var canDelete = false
        var pendingPrivateClose = false
        var block: CloudSignOutFlowLogic.BlockReason?
    }

    private func makeService(_ c: Ctrl) -> AccountDeletionService {
        AccountDeletionService(deps: .init(
            canDelete: { c.canDelete },
            groupsBackendEnabled: { true },
            storageModeIsCloud: { c.isCloud },
            hasPrivateSession: { c.hasPrivateSession },
            forgetGroupsUser: { c.events.append("forget") },
            teardown: { c.events.append("teardown") },
            deletePersonalAccount: { c.events.append("delete"); return .success },
            revokeSIWA: { c.events.append("siwa") },
            revokeGoogle: { c.events.append("google") },
            closeLocalCloud: { c.events.append("closeCloud"); return false },
            wipePrivateICloud: { c.events.append("wipeICloud"); return c.wipeICloudResult },
            closeLocalPrivate: { _ in c.events.append("closePrivate"); return c.closePrivateResult },
            iCloudDeletionBlock: { _ in c.events.append("groupsCheck"); return c.block },
            clearCloudBeacon: { c.events.append("clearBeacon") },
            deleteCloudKitMarker: { _ in c.events.append("deleteMarker") },
            pendingPrivateClose: { c.pendingPrivateClose },
            markPendingPrivateClose: { c.events.append("markPending"); c.pendingPrivateClose = true },
            clearPendingPrivateClose: { c.events.append("clearPending"); c.pendingPrivateClose = false },
            pendingCloseIsForAnotherLiveSession: { false },
            anotherCloseInFlight: { false }))
    }

    @Test("primero su iCloud, después este teléfono; ningún paso de servidor")
    func cellC_wipesICloudThenTheDevice_withoutServer() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl()
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events == ["groupsCheck", "wipeICloud", "closePrivate", "clearPending"])
        #expect(sut.phase == .awaitingRelaunch)
        #expect(!c.pendingPrivateClose, "sin servidor no hay marca durable que dejar")
    }

    @Test("si su iCloud no se deja borrar, este teléfono no se toca y se puede reintentar")
    func cellC_iCloudFails_touchesNothingLocal() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.wipeICloudResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["groupsCheck", "wipeICloud"])
        #expect(sut.phase == .failed(step: .personalWipe))

        c.wipeICloudResult = true
        c.events = []
        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["groupsCheck", "wipeICloud", "closePrivate", "clearPending"])
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test("si el cierre local no llega, el reintento repite el gesto entero, también su iCloud")
    func cellC_localCloseFails_retryRepeatsEverything() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.closePrivateResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .failed(step: .localClose))

        c.closePrivateResult = true
        c.events = []
        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["groupsCheck", "wipeICloud", "closePrivate", "clearPending"])
    }

    @Test("con cambios de grupos sin subir no se borra nada, ni su iCloud: lo de grupos es de más gente")
    func cellC_groupsPending_touchesNothing() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.block = .sessionExpired
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["groupsCheck"])
        #expect(sut.phase == .failed(step: .iCloudPrivateBlocked))
        #expect(sut.iCloudPrivateBlockReason == .sessionExpired)

        // Al volver a entrar se suben; entonces el gesto sigue entero.
        c.block = nil
        c.events = []
        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["groupsCheck", "wipeICloud", "closePrivate", "clearPending"])
    }

    @Test("sin sesión privada ni cuenta de Yala no hay nada que borrar")
    func noPrivateSession_noAccount_isNoOp() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.hasPrivateSession = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.isEmpty)
        #expect(sut.phase == .idle)
    }

    @Test("en la nube sin sesión tampoco: ahí borrar la cuenta exige la cuenta")
    func cloudWithoutSession_isNoOp() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.isEmpty)
    }

    @Test("con cuenta de Yala sigue el camino de siempre, servidor incluido")
    func cellD_unchanged() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.canDelete = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.contains("delete"))
        #expect(c.events.first == "wipeICloud")
        #expect(!c.events.contains("groupsCheck"), "en la D el servidor ya se encarga de la cuenta de grupos")
    }
}

// MARK: - El cableado de Ajustes

/// La lógica de arriba no sirve si Ajustes no la usa. Lee el código sin comentarios (molde `DestructiveScopeLogicTests`).
@Suite("Eliminar mi cuenta en iCloud privado · cableado de Ajustes")
struct EliminarCuentaICloudWiringTests {
    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("la fila va en la tarjeta del final, debajo de «Cerrar sesión», y abre la hoja de eliminar la cuenta")
    func profile_rowInTheLastCard() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains(
            "signOutRow\n            if offersICloudAccountDeletion {\n                SubsectionDivider()\n                deleteICloudAccountRow\n            }"))
        #expect(src.contains("DestructiveScopeLogic.offersICloudAccountDeletion(\n            path: signOutRowPath, hasYalaAccount: deleteAccountRowHasSession)"))
        #expect(src.components(separatedBy: "\"profile_delete_account_icloud\"").count - 1 == 1)
        #expect(src.contains("deleteAccountScope = DeleteAccountScope(summary: GroupService.shared.accountDeletionGroupsSummary())"))
    }

    @Test("la hoja elige la operación y la etiqueta de la nube con la cuenta y los grupos del teléfono")
    func profile_sheetUsesTheCell() throws {
        let src = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains("hasYalaAccount: deleteAccountRowHasSession,"))
        #expect(src.contains("deviceHasGroupRows: CloudSessionSignOut.hasAnyGroupRows(context: modelContext))"))
        #expect(src.contains("cloudLabel: DestructiveScopeLogic.cloudLabel(for: operation, storageMode: CloudSyncFlags.storageMode),"))
        #expect(!src.contains("cloudLabel: .cloudAccount,  // eliminar-cuenta"),
                "La hoja vuelve a decir «tu cuenta de Yala» en la fila de la nube a quien solo tiene iCloud.")
    }
}

// MARK: - El freno de grupos, sobre un almacén de verdad

@MainActor
@Suite("Eliminar mi cuenta en iCloud privado · cambios de grupos sin subir", .serialized)
struct EliminarCuentaICloudGroupsGateTests {
    private func makeContext() throws -> (ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EliminarICloudGrupos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations:
                ModelConfiguration("EG-Personal", schema: SwiftDataConfiguration.personalSchema,
                                   url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none),
                ModelConfiguration("EG-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                   url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none),
                ModelConfiguration("EG-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
                                   url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (context, dir)
    }

    private final class Calls { var captures = 0 }

    /// Una captura que no termina deja cambios fuera que no se dejan leer: es la pasajera (`.unfinished`), no el atasco.
    private func witness(captureCompletes: Bool, mirror: Int = 0, calls: Calls) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in calls.captures += 1; return captureCompletes },
            mirrorPending: { _, _ in mirror },
            mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in nil }
        return witness
    }

    private static func reading(_ journal: JournaledPhaseRead) -> MigrationRestReading {
        MigrationRestReading(controllerState: nil, controllerIsWorking: false, journalRead: journal,
                             journalHasPendingEffects: false, persistedStorageMode: .icloud,
                             mirrorOffArmed: false, mountedDecision: .iCloudMirror)
    }

    /// Con la migración en reposo (como cualquier teléfono que nunca migró): aquí se prueba el freno de grupos.
    private func block(_ context: ModelContext, _ witness: CloudSessionSignOut.GroupsExitWitness) async -> Bool {
        let coordinator = CloudSessionSignOut.shared
        coordinator.migrationRestReadingOverride = { Self.reading(.phase(.notStarted)) }
        coordinator.exitCaptureDelayOverride = .zero  // los mismos reintentos, sin esperar
        defer {
            coordinator.migrationRestReadingOverride = nil
            coordinator.exitCaptureDelayOverride = nil
        }
        return await coordinator.iCloudAccountDeletionBlock(context: context, witness: witness) != nil
    }

    @Test("una migración entre iCloud y la nube a medias para el borrado, como para «Cerrar sesión»")
    func migrationNotAtRest_blocks() async throws {
        let (context, dir) = try makeContext(); defer { discardTestStoreDirectory(dir) }
        let coordinator = CloudSessionSignOut.shared
        defer { coordinator.migrationRestReadingOverride = nil }
        coordinator.migrationRestReadingOverride = { Self.reading(.phase(.uploadingSnapshot)) }
        #expect(await coordinator.iCloudAccountDeletionBlock(
            context: context, witness: witness(captureCompletes: true, calls: Calls())) == .migrationInFlight)
        coordinator.migrationRestReadingOverride = { Self.reading(.unreadable) }
        #expect(await coordinator.iCloudAccountDeletionBlock(
            context: context, witness: witness(captureCompletes: true, calls: Calls())) == .migrationUnreadable)
        // Control: en reposo, nada lo para.
        coordinator.migrationRestReadingOverride = { Self.reading(.phase(.notStarted)) }
        #expect(await coordinator.iCloudAccountDeletionBlock(
            context: context, witness: witness(captureCompletes: true, calls: Calls())) == nil)
    }

    @Test("sin grupos en el teléfono no espera, no guarda y no bloquea")
    func noGroups_doesNotBlock_norCapture() async throws {
        let (context, dir) = try makeContext(); defer { discardTestStoreDirectory(dir) }
        let calls = Calls()
        #expect(await block(context, witness(captureCompletes: false, calls: calls)) == false)
        #expect(calls.captures == 0)
    }

    @Test("una fila viva en el outbox de grupos bloquea")
    func liveOutboxRow_blocks() async throws {
        let (context, dir) = try makeContext(); defer { discardTestStoreDirectory(dir) }
        context.insert(GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                                       fieldsJSON: "{\"amount\":300}", author: "a", rejectedReason: nil, ownerUserID: "sub-a"))
        try context.save()
        #expect(await block(context, witness(captureCompletes: true, calls: Calls())) == true)
    }

    @Test("una fila rechazada (dead-letter) no bloquea: nunca va a subir")
    func deadLetter_doesNotBlock() async throws {
        let (context, dir) = try makeContext(); defer { discardTestStoreDirectory(dir) }
        context.insert(GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                                       fieldsJSON: "{}", author: "a", rejectedReason: "rejected", ownerUserID: "sub-a"))
        try context.save()
        #expect(await block(context, witness(captureCompletes: true, calls: Calls())) == false)
    }

    @Test("grupos del canal backend: bloquea si la captura no termina o si queda algo en el espejo")
    func backendGroups_dependOnTheCapture() async throws {
        let (context, dir) = try makeContext(); defer { discardTestStoreDirectory(dir) }
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        context.insert(group)
        try context.save()

        let calls = Calls()
        #expect(await block(context, witness(captureCompletes: true, calls: calls)) == false)
        #expect(calls.captures == 1, "con grupos del canal se captura antes de decidir (y a la primera termina)")
        #expect(await block(context, witness(captureCompletes: false, calls: Calls())) == true)
        #expect(await block(context, witness(captureCompletes: true, mirror: 2, calls: Calls())) == true)
    }
}
