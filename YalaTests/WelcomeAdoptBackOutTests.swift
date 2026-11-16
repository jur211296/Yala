//
//  WelcomeAdoptBackOutTests.swift
//  YalaTests
//
//  Card 0f7h (ticket `welcome-adopt-cancel-then-close-mounts-the-icloud-mirror`): cancelar la entrada a la cuenta en la
//  bienvenida y cerrar Yala montaba el espejo de iCloud y saltaba la bienvenida. Salir hacia atrás de un adopt que no
//  dejó nada devuelve el montaje neutro, el onboarding y la sesión a como estaban.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bienvenida · salir de un adopt sin huella deshace lo que marcó al empezar")
struct WelcomeAdoptBackOutTests {

    // MARK: - ¿Quedó algo que proteger?

    private static func trace(
        _ phase: MigrationPhase = .notStarted, effect: Bool = false, unreadable: Bool = false,
        exit: AdoptClaimExit? = .cancelled, localData: Bool = false
    ) -> Bool {
        WelcomeAdoptBackOut.leftNoTrace(
            journaledPhase: phase, adoptEffectJournaled: effect, journalUnreadable: unreadable,
            adoptClaimExit: exit, hasLocalData: localData)
    }

    /// El caso del ticket: instalación nueva, cancelar, nada en el teléfono.
    @Test func cancelledWithNothingLocal_leavesNoTrace() {
        #expect(Self.trace())
    }

    /// `.cancelled` vale también para el efecto, que puede haber subido huérfanas: con datos locales, no se deshace.
    @Test func cancelledWithLocalData_keepsTheAdoptMarks() {
        #expect(!Self.trace(localData: true))
    }

    /// El techo del CLAIM no sube ni baja filas: se deshace aunque haya datos locales.
    @Test(arguments: [AdoptClaimExit.stalled, .sessionExpired, .accountUnavailable])
    func claimCeilingExit_leavesNoTrace_evenWithLocalData(_ exit: AdoptClaimExit) {
        #expect(Self.trace(.failedRollback, exit: exit, localData: true))
    }

    /// El techo del EFECTO, o el relevo que sale por la subida (sin marca de claim), con datos locales: se queda.
    @Test(arguments: [AdoptClaimExit.effectStalled, .effectLocalFailure, .effectLineageUnproven, nil])
    func effectOrRelayExitWithLocalData_keepsTheAdoptMarks(_ exit: AdoptClaimExit?) {
        #expect(!Self.trace(.failedRollback, exit: exit, localData: true))
        #expect(Self.trace(.failedRollback, exit: exit, localData: false), "sin nada local no hubo nada que subir")
    }

    /// Con el efecto pendiente, un kill tiene que aterrizar en la app: no se deshace.
    @Test func pendingEffect_keepsTheAdoptMarks() {
        #expect(!Self.trace(effect: true))
    }

    /// El journal ilegible no prueba nada.
    @Test func unreadableJournal_keepsTheAdoptMarks() {
        #expect(!Self.trace(unreadable: true))
    }

    /// A mitad del adopt (aparcado tras un error) o terminado, tampoco.
    @Test(arguments: [MigrationPhase.claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying, .done])
    func adoptInProgressOrDone_keepsTheAdoptMarks(_ phase: MigrationPhase) {
        #expect(!Self.trace(phase, exit: .stalled))
    }

    // MARK: - El montaje neutro vuelve a como estaba

    /// Instalación nueva: el neutro lo armó el primer arranque. `onAdoptStarted` lo retira; al volver, regresa con su
    /// dueño, y el arranque siguiente vuelve a montar sin espejo.
    @Test func freshInstallNeutral_isRestoredWithItsOwner() {
        let defaults = makeIsolatedDefaults(prefix: "adopt-backout-fresh")
        StorageModePersistence.settleFreshInstallNeutralMount(
            freshInstall: true, hasCompletedOnboarding: false, defaults)
        let snapshot = WelcomeAdoptBackOut.Snapshot.capture(
            hasCompletedOnboarding: false, hasPrivateSession: false, defaults)

        StorageModePersistence.retireNeutralMountOnChoice(defaults)
        #expect(!StorageModePersistence.isNeutralMountArmed(defaults))

        snapshot.restoreNeutralMount(defaults)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
        #expect(defaults.bool(forKey: StorageModePersistence.freshInstallOwnsNeutralMountKey))
    }

    /// Sin neutro antes (un teléfono que ya había elegido), volver no arma nada.
    @Test func noNeutralBefore_restoresNothing() {
        let defaults = makeIsolatedDefaults(prefix: "adopt-backout-none")
        let snapshot = WelcomeAdoptBackOut.Snapshot.capture(
            hasCompletedOnboarding: true, hasPrivateSession: true, defaults)
        snapshot.restoreNeutralMount(defaults)
        #expect(!StorageModePersistence.isNeutralMountArmed(defaults))
        #expect(snapshot.hasCompletedOnboarding)
        #expect(snapshot.hasPrivateSession)
    }

    // MARK: - Cableado

    /// La salida hacia atrás del cover pasa por la restauración, y el arranque del adopt apunta la foto antes de marcar.
    @Test func contentView_wiresTheBackOut() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/ContentView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let started = try #require(source.range(of: "onAdoptStarted: {"))
        let afterStart = source[started.upperBound...]
        let capture = try #require(afterStart.range(of: "WelcomeAdoptBackOut.Snapshot.capture("))
        let marks = try #require(afterStart.range(of: "hasCompletedOnboarding = true"))
        #expect(capture.lowerBound < marks.lowerBound, "la foto va antes de marcar el onboarding")

        let signIn = try #require(source.range(of: "private var welcomeCloudSignIn: some View"))
        let tail = source[signIn.upperBound...]
        #expect(tail.range(of: "onBack: {\n                restoreStateIfAdoptLeftNoTrace()") != nil)
        // «Crear otra cuenta» también sale del cover al chooser: misma restauración.
        #expect(tail.range(of: "restoreStateIfAdoptLeftNoTrace()\n                hasShownWelcomeChooser = false\n                showWelcomeCloudSignIn = false\n                welcomeFlowInitialStep = .newChooser") != nil)
        // Un «Reintentar» no pisa la foto de antes del primer intento.
        let guardRange = try #require(afterStart.range(of: "if adoptStartSnapshot == nil {"))
        #expect(guardRange.lowerBound < capture.lowerBound)
        // Las salidas que dejan otro estado legítimo sueltan la foto.
        for exit in ["onFinishedToApp: {", "onBornCloudCompleted: {", "onEnterGroupsOnly: {"] {
            let start = try #require(tail.range(of: exit), "no está \(exit)")
            let body = tail[start.upperBound...].prefix(12000)
            let end = body.range(of: "\n            },")?.lowerBound ?? body.endIndex
            #expect(body[..<end].contains("adoptStartSnapshot = nil"), "\(exit) no suelta la foto")
        }
    }
}
