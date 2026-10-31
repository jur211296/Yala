//
//  AccountDeletionPendingCloseWiringTests.swift
//  YalaTests / CloudSync
//
//  Ticket `account-deletion-private-close-has-no-durable-intent`: «Eliminar cuenta» con iCloud privado (celda D) deja una
//  marca durable tras el `200` del servidor, y si la app se cierra antes de armar el borrado, el arranque retoma el cierre
//  local. La lógica la fijan `AccountDeletionServiceTests` (dos instancias = antes y después de cerrar la app) y
//  `SignOutWipeHookTests` (quién la retira). Aquí, lo que solo se puede leer en la fuente: que la dependencia viva lee la key
//  que retira el boot-wipe, y que el arranque, la vuelta a primer plano y `-uitest-reset` la consultan o la retiran.
//

import Foundation
import Testing

@testable import Yala

@Suite("Eliminar cuenta (D) · cierre local retomado tras cerrar la app (cableado)")
struct AccountDeletionPendingCloseWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función: desde su firma hasta la siguiente declaración del mismo nivel.
    private static func body(of signature: String, in src: String) -> String? {
        guard let start = src.range(of: signature) else { return nil }
        let rest = src[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    private static func ", "\n    static func ",
                    "\n    @MainActor\n", "\n    nonisolated static func "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        guard let end = ends.min() else { return String(rest) }
        return String(rest[..<end])
    }

    /// La dependencia viva lee, escribe y retira la MISMA key que el boot-wipe retira. Si apuntara a otra, el arranque
    /// retomaría un cierre ya hecho o nunca vería el pendiente.
    @Test func liveDependencies_useTheStorageModePersistenceMark() throws {
        let src = try Self.source("Yala/Services/CloudSync/AccountDeletionService.swift")
        #expect(src.contains("pendingPrivateClose: { StorageModePersistence.isAccountDeletedAwaitingLocalClose() },"))
        #expect(src.contains(
            "StorageModePersistence.markAccountDeletedAwaitingLocalClose(owner: CloudAuthService.shared.currentUserID)"))
        #expect(src.contains("clearPendingPrivateClose: { StorageModePersistence.clearAccountDeletedAwaitingLocalClose() },"))
        #expect(src.contains("CloudSessionSignOut.shared.phase != .idle || CloudSessionSignOut.shared.freshStartDrainInFlight"))
    }

    /// El boot-wipe retira la marca DESPUÉS de borrar los archivos (tras el guard abort-S3): si el store sobrevive, el
    /// cierre no ocurrió y la marca tiene que quedarse para retomarlo.
    @Test func bootWipe_clearsTheMarkOnlyAfterTheFilesAreGone() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let hook = try #require(Self.body(of: "static func performSignOutWipeIfArmed(\n", in: src))
        let guardFiles = try #require(hook.range(of: "guard deleteFiles(databaseName, personalSchema)"))
        let clear = try #require(hook.range(of: "StorageModePersistence.clearAccountDeletedAwaitingLocalClose(defaults)"))
        #expect(guardFiles.lowerBound < clear.lowerBound)
        #expect(hook.components(separatedBy: "clearAccountDeletedAwaitingLocalClose").count == 2,
                "una sola retirada, y fuera de la rama del abort")
    }

    /// El arranque y la vuelta a primer plano retoman el cierre; los dos exigen el bootstrap terminado antes de mirar la marca.
    @Test func contentView_resumesOnLaunchAndOnForeground() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        // El `.task` del ARRANQUE (el que corre `checkInitialSyncState`), no el del splash.
        #expect(src.contains(
            ".task {\n            Task { await resumeAccountDeletionCloseIfPending() }\n            await checkInitialSyncState()"),
                "el `.task` del arranque lanza el cierre retomado")

        let foreground = try #require(Self.body(of: "private func handleAppBecameActive()", in: src))
        #expect(foreground.contains("Task { await resumeAccountDeletionCloseIfPending() }"))

        let resume = try #require(Self.body(of: "private func resumeAccountDeletionCloseIfPending() async", in: src))
        let wait = try #require(resume.range(of: "guard SessionState.shared.isBootstrapSettled,"))
        let mark = try #require(resume.range(of: "StorageModePersistence.isAccountDeletedAwaitingLocalClose()"))
        let call = try #require(resume.range(
            of: "await AccountDeletionService.shared.resumePendingPrivateClose(context: modelContext)"))
        #expect(wait.lowerBound < mark.lowerBound)
        #expect(mark.lowerBound < call.lowerBound)
    }

    /// «Empiezo de cero» releva a la persona sin relanzar, así que no pasa por el boot-wipe: retira la marca él mismo, o
    /// el cierre retomado borraría lo de la persona nueva.
    @Test func handoverToANewPerson_clearsTheMark() throws {
        let src = try Self.source("Yala/Utils/DataWipeService.swift")
        let handover = try #require(Self.body(of: "static func clearHandoverPrivateSessionMark(from defaults: UserDefaults)", in: src))
        #expect(handover.contains("StorageModePersistence.clearAccountDeletedAwaitingLocalClose(defaults)"))
    }

    /// `-uitest-reset` retira la marca antes de que el seam la siembre: pegada, la corrida siguiente borraría el store al
    /// arrancar sin que nadie lo pidiera.
    @Test func uitestReset_clearsTheMark_andTheSeamPlantsItAfterwards() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let early = try #require(Self.body(of: "func applyUITestHooksEarly(context: ModelContext)", in: src))
        #expect(early.contains("StorageModePersistence.clearAccountDeletedAwaitingLocalClose()"))
        let seed = try #require(Self.body(of: "private func applyUITestSeed(context: ModelContext) async", in: src))
        #expect(seed.contains(
            "if UITestHooks.accountDeletionPendingClose {\n            StorageModePersistence.markAccountDeletedAwaitingLocalClose()"))
    }
}
