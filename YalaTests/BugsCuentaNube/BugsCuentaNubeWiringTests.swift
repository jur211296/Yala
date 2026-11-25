//
//  BugsCuentaNubeWiringTests.swift
//  YalaTests / BugsCuentaNube
//
//  El cableado de los arreglos de los bugs de cuenta (25-nov-2026), leído del código. La lógica está en
//  `BugsCuentaNubeLogicTests`; aquí, que cada pieza se use donde tiene que usarse.
//

import Foundation
import Testing

@Suite("Bugs cuenta nube · cableado (source-scan)")
struct BugsCuentaNubeWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Solo código: un comentario que nombre la pieza no cuenta como usarla.
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// El tramo entre dos marcas (la primera aparición de `start` y la siguiente de `end`).
    private static func slice(_ text: String, from start: String, to end: String) throws -> String {
        let lower = try #require(text.range(of: start))
        let upper = try #require(text.range(of: end, range: lower.upperBound..<text.endIndex))
        return String(text[lower.lowerBound..<upper.upperBound])
    }

    // MARK: A

    /// El ciclo compacta la cola ANTES de subir, y sube con el tope de la primera bajada.
    @Test func runtimeCycle_dropsSupersededUpserts_thenPushesWithTheFirstPullCap() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSyncRuntime.swift")
        let drop = try #require(src.range(of: "engine.dropSupersededUpserts(from: buildable, context: context)"))
        let push = try #require(src.range(of: "pushClient.push(buildable, continueWhile:"))
        #expect(drop.lowerBound < push.lowerBound)
        let closure = try Self.slice(src, from: "pushClient.push(buildable, continueWhile:", to: "})")
        #expect(closure.contains("SyncOutboxBacklogLogic.uploadsChunk(chunkIndex, firstPullCompleted: firstPullCompleted)"))
        #expect(closure.contains("chunkIndex += 1"))
        // La primera bajada se lee del coordinador del ciclo, no de otra fuente.
        #expect(src.contains("let firstPullCompleted = coordinator.hasCompletedFirstPull"))
    }

    /// La retirada borra también el espejo de la cola (si no, el arranque la repone).
    @Test func engineDrop_removesTheMirrorEntries_afterTheSave() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSyncEngine.swift")
        let body = try Self.slice(src, from: "func dropSupersededUpserts(", to: "return dropped")
        let save = try #require(body.range(of: "saveWithAuthor(context, Self.outboxSaveAuthor)"))
        let mirror = try #require(body.range(of: "outboxMirror?.remove(syncID: key.syncID, hlc: key.hlc)"))
        #expect(save.lowerBound < mirror.lowerBound)
        #expect(body.contains("SyncOutboxBacklogLogic.supersededUpserts("))
    }

    /// La subida pide el token dentro del bucle de trozos.
    @Test func push_asksForTheTokenInsideTheChunkLoop() throws {
        let src = try Self.source("Yala/Services/CloudSync/SyncPushClient.swift")
        let loop = try Self.slice(src, from: "while index < deltas.count {", to: "let upper = min(index + pushChunkSize")
        #expect(loop.contains("await tokenProvider()"))
        #expect(loop.contains("attest = await attestProvider()"))
    }

    /// El Panel pasa a la espera si el motor espera la sesión.
    @Test func panelWait_readsTheEngineWaitingForSignIn() throws {
        let src = try Self.source("Yala/App/ViewModels/PanelViewModel.swift")
        let body = try Self.slice(src, from: "private func nextAccountDataWait(", to: "return next")
        #expect(body.contains("engineWaitsForSignIn: waitsForSignIn"))
        #expect(src.contains("SyncSignInBannerLogic.engineWaitsForSignIn("))
    }

    // MARK: B

    /// Los dos botones de la alerta («Eliminar» y «Reintentar») pasan por la confirmación que pide entrar antes, y el
    /// servicio se llama solo desde ahí.
    @Test func deleteAlert_goesThroughTheSignInFirstConfirmation() throws {
        let src = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.components(separatedBy: "Task { await confirmAccountDeletion() }").count - 1 == 2)
        #expect(src.components(separatedBy: "AccountDeletionService.shared.deleteAccount(context:").count - 1 == 1)
        let body = try Self.slice(src, from: "private func confirmAccountDeletion()", to: "deleteAccount(context: modelContext)")
        #expect(body.contains("AccountDeletionRowLogic.needsSignInBeforeDeleting("))
        #expect(body.contains("await controller.signInToResumeSync()"))
    }

    /// «Tu cuenta de Yala» (y con ella «Eliminar mi cuenta») sale con los datos en la nube aunque no haya sesión.
    @Test func yalaAccountRow_andScreen_readTheCloudStorage() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        let row = try Self.slice(profile, from: "private var deleteAccountRowHasSession: Bool {", to: "}\n")
        #expect(row.contains("storageIsCloud: CloudSyncFlags.storageMode == .cloud"))
        let screen = try Self.source("Yala/App/Views/Profile/YalaAccountView.swift")
        #expect(screen.contains("storageIsCloud: CloudSyncFlags.storageMode == .cloud"))
    }

    // MARK: C

    /// El efecto de alta nueva apunta la marca, dentro de la rama `marksNewInstall` (no en la re-entrada).
    @Test func freshEntry_marksTheInstallAsStartedWithTheWelcome() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let block = try Self.slice(src, from: "if EntryOnboardingEffects.marksNewInstall(kind) {", to: "}")
        #expect(block.contains("SetupChecklistManager.shared.markAsNewInstall()"))
        #expect(block.contains("TabBarDefaultsMigration.markStartedWithWelcome23()"))
        #expect(src.components(separatedBy: "markStartedWithWelcome23()").count - 1 == 1)
    }
}
