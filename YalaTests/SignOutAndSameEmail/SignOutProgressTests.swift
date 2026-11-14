//
//  SignOutProgressTests.swift
//  YalaTests
//
//  Card p9q0 (recorrido de la bienvenida, 13-nov-2026): cerrar sesión, quitar los datos y eliminar la cuenta tienen su
//  propia pantalla mientras trabajan, y no piden reabrir salvo con iCloud montado.
//

import Foundation
import Testing
@testable import Yala

@Suite("Cerrar sesión con pantalla propia · qué enseña la pantalla")
struct SignOutProgressLogicTests {

    private typealias L = SignOutProgressLogic

    @Test("trabajando: el verbo que se confirmó")
    func working_showsTheConfirmedVerb() {
        #expect(L.screen(signOutWorking: true, signOutAwaitingRelaunch: false, swapInFlight: false,
                         deletionWorking: false, deletionFinishedInPlace: false,
                         presentedActivity: .signingOut) == .working(.signingOut))
        #expect(L.screen(signOutWorking: true, signOutAwaitingRelaunch: false, swapInFlight: false,
                         deletionWorking: false, deletionFinishedInPlace: false,
                         presentedActivity: .removingData) == .working(.removingData))
    }

    /// Lo que veía Jürgen en E04: con el borrado armado la fase pasa a `.awaitingRelaunch` ANTES del cambio en caliente, y
    /// la ventana enseñaba «Ya casi está — vuelve a abrir Yala» mientras el cambio seguía en vuelo.
    @Test("durante el cambio en caliente la pantalla se queda; sin él, deja ver la de reabrir")
    func inPlaceSwap_keepsTheScreen_untilItIsKnownWhetherToReopen() {
        #expect(L.screen(signOutWorking: false, signOutAwaitingRelaunch: true, swapInFlight: true,
                         deletionWorking: false, deletionFinishedInPlace: false,
                         presentedActivity: .signingOut) == .working(.signingOut))
        #expect(L.screen(signOutWorking: false, signOutAwaitingRelaunch: true, swapInFlight: false,
                         deletionWorking: false, deletionFinishedInPlace: false,
                         presentedActivity: .signingOut) == .hidden)
    }

    @Test("el borrado manda sobre el cierre y termina diciendo que la cuenta se eliminó")
    func deletion_winsAndEndsWithItsOwnScreen() {
        #expect(L.screen(signOutWorking: true, signOutAwaitingRelaunch: false, swapInFlight: false,
                         deletionWorking: true, deletionFinishedInPlace: false,
                         presentedActivity: .signingOut) == .working(.deletingAccount))
        #expect(L.screen(signOutWorking: false, signOutAwaitingRelaunch: false, swapInFlight: false,
                         deletionWorking: false, deletionFinishedInPlace: true,
                         presentedActivity: .deletingAccount) == .accountDeleted)
    }

    @Test("bloqueado, en reposo o pidiendo reabrir: no tapa nada")
    func notWorking_hides() {
        for awaiting in [true, false] {
            #expect(L.screen(signOutWorking: false, signOutAwaitingRelaunch: awaiting, swapInFlight: false,
                             deletionWorking: false, deletionFinishedInPlace: false,
                             presentedActivity: .signingOut) == .hidden)
        }
    }

    @Test("la actividad: el borrado manda, si no el verbo de la fila")
    func activity() {
        #expect(L.activity(deletionWorking: true, removesDeviceData: true) == .deletingAccount)
        #expect(L.activity(deletionWorking: false, removesDeviceData: true) == .removingData)
        #expect(L.activity(deletionWorking: false, removesDeviceData: false) == .signingOut)
    }
}

@Suite("Cerrar sesión con pantalla propia · cableado (source-scan)")
struct SignOutSwapInFlightWiringTests {

    static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func squashed(_ text: String) -> String {
        text.replacing(/\s+/, with: " ")
    }

    /// Sin el testigo, la pantalla de progreso se retira al pasar a `.awaitingRelaunch` y deja ver «Ya casi está» mientras
    /// el cambio en caliente sigue en vuelo, que es lo que la card pidió quitar.
    @Test("los cuatro cambios en caliente del cierre encienden el testigo justo antes, y lo apaga su defer")
    func everyInPlaceSwap_raisesTheWitness() throws {
        let src = Self.squashed(try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
        let calls = src.components(separatedBy: "await PersonalContainerSwap.attemptSignOutSwap() == .swapped").count - 1
        #expect(calls == 4)
        let guarded = src.components(
            separatedBy: "inPlaceSwapInFlight = true defer { inPlaceSwapInFlight = false } "
                + "if await PersonalContainerSwap.attemptSignOutSwap() == .swapped").count - 1
        let guardedGuard = src.components(
            separatedBy: "inPlaceSwapInFlight = true defer { inPlaceSwapInFlight = false } "
                + "guard await PersonalContainerSwap.attemptSignOutSwap() == .swapped").count - 1
        #expect(guarded + guardedGuard == calls, "un cambio en caliente sin su testigo")
    }

    @Test("Ajustes presenta la pantalla, con el verbo que se confirmó")
    func settings_presentsTheScreen() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains(
            ".presentsSignOutProgress(removesDeviceData: exitInProgressRemovesDeviceData ?? signOutRowRemovesDeviceData)"))
    }

    @Test("la pantalla de reabrir dice «Cuenta eliminada» tras el borrado y explica iCloud cuando lo hay")
    func relaunchScreen_saysWhatHappened() throws {
        let view = Self.squashed(try Self.source("Yala/App/Views/Settings/SignOutRelaunchView.swift"))
        #expect(view.contains("done: [doneLine]"))
        #expect(view.contains("AccountDeletionService.shared.phase == .awaitingRelaunch ? L10n.UXCS.relaunchAccountDeleted"))
        #expect(view.contains("CloudSessionSignOut.personalMountAttachesMirror ? L10n.UXCS.relaunchAfterSignOutICloud"))
    }
}
