//
//  CorpusWipeCrossingTheZoneMountTests.swift
//  YalaTests
//
//  Ticket `late-icloud-wipe-can-re-export-between-its-two-halves`. El borrado del corpus de iCloud borra primero la zona
//  y después las filas del teléfono. Un kill entre las dos dejaba el corpus local entero y el arranque siguiente montaba
//  el espejo, que lo volvía a subir antes de que la reanudación borrara nada. Desde el 2026-11-06, mientras la marca de
//  la zona siga puesta, el store monta sin espejo; y si el borrado termina en ese proceso, se pide reabrir antes del
//  onboarding.
//
//  Tres capas, porque cada una puede romperse sola: el predicado puro, el adaptador que lee el store real (la pasarela
//  que nadie vigila, `.claude/rules/testing.md`) y el cableado del cierre del aviso tardío.
//

import Testing
import Foundation
@testable import Yala

@Suite("Borrado de iCloud entre sus dos mitades · el montaje")
struct CorpusWipeCrossingTheZoneMountTests {

    // MARK: El predicado

    @Test("con la zona cruzada, en .icloud sin armar, monta sin espejo")
    func crossedZone_mountsNeutral() {
        #expect(SwiftDataConfiguration.shouldMountNeutralForCorpusWipeCrossingTheZone(
            corpusWipeCrossedTheZone: true, persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!SwiftDataConfiguration.shouldMountNeutralForCorpusWipeCrossingTheZone(
            corpusWipeCrossedTheZone: false, persistedMode: .icloud, mirrorOffArmed: false),
                "control: sin la zona cruzada no hay nada que proteger")
    }

    /// SERIO-1 y la reversa: en la ventana del cutover el espejo TIENE que remontar para que el marcador exporte.
    @Test("fuera de .icloud virgen es inerte")
    func confinedToVirginICloud() {
        #expect(!SwiftDataConfiguration.shouldMountNeutralForCorpusWipeCrossingTheZone(
            corpusWipeCrossedTheZone: true, persistedMode: .cloud, mirrorOffArmed: false))
        #expect(!SwiftDataConfiguration.shouldMountNeutralForCorpusWipeCrossingTheZone(
            corpusWipeCrossedTheZone: true, persistedMode: .icloud, mirrorOffArmed: true))
    }

    @Test("la tabla de mounts lo convierte en .neutralNoMirror aunque haya iCloud")
    func decisionTable() {
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false, neutralDurable: true) == .neutralNoMirror)
    }

    // MARK: El adaptador, sobre el store real

    /// EL CRITERIO 1 DEL TICKET, al nivel del montaje: el aviso tardío arma su borrado con el chooser ya visto (por eso
    /// el neutro que arma el borrado era inerte), borra la zona y muere. El arranque siguiente no puede adjuntar el espejo.
    @Test("aviso tardío: arm + zona borrada + chooser visto → el arranque siguiente monta sin espejo")
    func lateNotice_killAfterTheZone_mountsNeutral() {
        let d = makeIsolatedDefaults(prefix: "ca5b.adapter.killed")
        d.set(true, forKey: "hasShownWelcomeChooser")
        StorageModePersistence.armICloudCorpusWipe(d)
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(d), """
            control: antes de borrar la zona no se toca el montaje (el neutro del borrado es inerte con el chooser visto, \
            y eso no cambia)
            """)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(d), """
            con la zona borrada y las filas aún aquí, un espejo adjunto re-exporta el corpus que la persona pidió borrar
            """)
    }

    @Test("al terminar el borrado, el espejo vuelve; «a medias» lo mantiene apagado hasta que la persona decide")
    func clearingTheArm_restoresTheMirror() {
        let done = makeIsolatedDefaults(prefix: "ca5b.adapter.done")
        done.set(true, forKey: "hasShownWelcomeChooser")
        StorageModePersistence.armICloudCorpusWipe(done)
        StorageModePersistence.markICloudCorpusWipeZoneDone(done)
        StorageModePersistence.clearICloudCorpusWipeArm(done)
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(done), "un borrado terminado no deja el espejo apagado")

        let halfway = makeIsolatedDefaults(prefix: "ca5b.adapter.halfway")
        halfway.set(true, forKey: "hasShownWelcomeChooser")
        StorageModePersistence.armICloudCorpusWipe(halfway)
        StorageModePersistence.markICloudCorpusWipeZoneDone(halfway)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(halfway)
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(halfway), """
            «a medias» es la zona ida y las filas aquí: con el espejo, el corpus vuelve a subir antes de que la persona \
            conteste (review adversarial: una reanudación parada en los grupos pasa aquí sin preguntar)
            """)
        StorageModePersistence.clearICloudCorpusWipeLeftHalfway(halfway)  // «Déjalo así» o borrado terminado
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(halfway), "decidido, el espejo vuelve")
    }

    @Test("la marca de la zona sin arm ni «a medias» no apaga el espejo")
    func orphanZoneMark_isInert() {
        let d = makeIsolatedDefaults(prefix: "ca5b.adapter.orphan")
        d.set(true, forKey: StorageModePersistence.icloudCorpusWipeZoneDoneKey)
        #expect(!StorageModePersistence.hasICloudCorpusWipeCrossedTheZone(d))
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(d))
    }

    @Test("en la nube, el adaptador lo ignora")
    func adapter_confinedToVirginICloud() {
        let d = makeIsolatedDefaults(prefix: "ca5b.adapter.cloud")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        d.set(true, forKey: "hasShownWelcomeChooser")
        StorageModePersistence.write(.cloud, defaults: d)
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(d))
    }

    /// El aviso «reabre Yala para sincronizar» no puede salir en cada arranque por un neutro que reabrir no quita.
    @Test("con la zona cruzada, no se ofrece reabrir por iCloud")
    func noICloudRestartOfferWhileCrossingTheZone() {
        #expect(SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .neutralNoMirror, mountedWithMirroring: false, iCloudAvailableNow: true,
            groupsOnlySessionArmed: false, corpusWipeCrossedTheZone: false), "control: el neutro de una instalación sí avisa")
        #expect(!SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .neutralNoMirror, mountedWithMirroring: false, iCloudAvailableNow: true,
            groupsOnlySessionArmed: false, corpusWipeCrossedTheZone: true))
    }

    // MARK: Lo que pasa al terminar en un proceso sin espejo

    /// El borrado reanudado en un montaje neutro no abre el onboarding sobre un store sin espejo: es la misma regla que
    /// la puerta del Welcome (`requiresMirror(.privateOnboarding)`).
    @Test("terminar en un montaje neutro pide reabrir; con espejo, no")
    func finishingOnANeutralMount_asksToRelaunch() {
        #expect(WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .privateOnboarding, mountedDecision: .neutralNoMirror))
        #expect(!WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .privateOnboarding, mountedDecision: .iCloudMirror))
    }
}

// MARK: - El cableado (source-scan)

@Suite("Borrado de iCloud entre sus dos mitades · el cableado")
struct CorpusWipeCrossingTheZoneWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// El destino va ANTES de bajar `hasCompletedOnboarding`, cuyo `onChange` llama a `presentNextOnboardingScreen`. El
    /// cierre NO presenta nada: la hoja del aviso tardío puede estar cerrándose (regla (4) de Presentaciones).
    @Test("el cierre del aviso tardío guarda el destino antes de bajar el onboarding, sin presentar nada")
    func settle_storesTheDestinationBeforeLoweringOnboarding() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let settle = try Self.body(of: "private func settleAfterLateICloudWipe() {", in: src)
        let check = try #require(settle.range(of: "WelcomeMirrorRelaunchLogic.shouldRelaunch("))
        #expect(settle.contains("destination: .privateOnboarding"))
        #expect(settle.contains("mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision"))
        let pending = try #require(settle.range(of: "WelcomePendingDestinationStore.set(.privateOnboarding)"))
        let lower = try #require(settle.range(of: "hasCompletedOnboarding = false"))
        #expect(check.lowerBound < pending.lowerBound)
        #expect(pending.lowerBound < lower.lowerBound)
        #expect(!settle.contains("showWelcomeFlow = true"))
    }

    /// Quien consume el destino no abre el onboarding privado sobre un montaje sin espejo: pide reabrir.
    @Test("el destino del onboarding privado con el montaje neutro pide reabrir")
    func pendingPrivateOnboarding_onANeutralMount_relaunches() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let route = try Self.body(of: "private func presentNextOnboardingScreen() {", in: src)
        let branch = try #require(route.range(of: "case .privateOnboarding:"))
        let tail = String(route[branch.upperBound...].prefix(700))
        let check = try #require(tail.range(of: "WelcomeMirrorRelaunchLogic.shouldRelaunch("))
        let relaunch = try #require(tail.range(of: "welcomeFlowInitialStep = .mirrorRelaunch"))
        let keep = try #require(tail.range(of: "WelcomePendingDestinationStore.set(.privateOnboarding)"))
        let onboarding = try #require(tail.range(of: "showOnboarding = true"))
        #expect(check.lowerBound < keep.lowerBound)
        #expect(keep.lowerBound < relaunch.lowerBound)
        #expect(relaunch.lowerBound < onboarding.lowerBound, "el onboarding queda en la rama `else`")
    }

    @Test("el arranque pasa la marca de la zona al aviso de reabrir")
    func bootstrapper_passesTheZoneTerm() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(src.contains("corpusWipeCrossedTheZone: StorageModePersistence.hasICloudCorpusWipeCrossedTheZone()"))
    }

    @Test("el adaptador de producción suma el término de la zona")
    func adapter_includesTheZoneTerm() throws {
        let src = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        let adapter = try Self.body(
            of: "static func shouldMountNeutralDurable(_ defaults: UserDefaults = .standard) -> Bool {", in: src)
        #expect(adapter.contains("shouldMountNeutralForCorpusWipeCrossingTheZone("))
        #expect(adapter.contains("StorageModePersistence.hasICloudCorpusWipeCrossedTheZone(defaults)"))
    }
}
