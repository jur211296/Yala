//
//  RemoteWipeSignalDetectionTests.swift
//  YalaTests
//
//  Card os7l (2026-11-05), ticket `remote-wipe-receiver-has-no-behaviour-test`. El camino que DETECTA el vaciado remoto
//  —llega `lastWipeTimestamp` al iCloud-KV del Apple ID— se ejercita de verdad: `PreferenceSyncService.checkForRemoteWipeSignal`
//  con un iCloud-KV y un dominio local propios, y el encolado recogido en un array. Hasta ese día solo lo cubrían el
//  decisor puro y los scans de `RemoteWipeSignalWiringTests`, que prueban el cableado, no lo que hace.
//
//  `.serialized`: fija `CloudSyncFlags.storageMode`, que es estático.
//

import Foundation
import Testing
@testable import Yala

private final class WipeSignalSpyStore: OwnerKeyValueWriting {
    var values: [String: Any] = [:]
    func setBool(_ value: Bool, forKey key: String) { values[key] = value }
    func setString(_ value: String, forKey key: String) { values[key] = value }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value }
    func setInt(_ value: Int, forKey key: String) { values[key] = Int64(value) }
    func removeObject(forKey key: String) { values[key] = nil }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func longLong(forKey key: String) -> Int64 { values[key] as? Int64 ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    @discardableResult func synchronize() -> Bool { true }
}

@MainActor
@Suite("Vaciado remoto · la detección real, por sesión", .serialized)
struct RemoteWipeSignalDetectionTests {

    /// Lo que encoló y avisó una pasada de la detección.
    private struct Outcome {
        var intents: [RouterIntent] = []
        var remoteOnboardingPosts = 0
        /// Las vueltas que pidió para cerrar la espera de la marca, en segundos.
        var rechecks: [TimeInterval] = []
    }

    /// Un teléfono con el onboarding hecho y una señal de vaciado de otro dispositivo sin procesar. `privateMark`: `nil`
    /// deja la marca del eje ausente.
    private func phone(privateMark: Bool?) throws -> (store: WipeSignalSpyStore, local: UserDefaults) {
        let local = try #require(testDefaults(suiteName: "RemoteWipeSignalDetectionTests.\(UUID().uuidString)"))
        local.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        local.set(1_000.0, forKey: "lastKnownWipeTimestamp")
        if let privateMark { PrivateSessionMark.set(privateMark, local) }
        let store = WipeSignalSpyStore()
        store.values["lastWipeTimestamp"] = 2_000.0
        return (store, local)
    }

    /// El «ahora» de la detección: fijo, y cada caso lo mueve a mano para cruzar la espera de la marca.
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func detect(_ store: WipeSignalSpyStore, _ local: UserDefaults, mode: StorageMode,
                        now: Date? = nil) -> Outcome {
        CloudSyncFlags.storageMode = mode
        defer { CloudSyncFlags._testResetStorageModeOverride() }
        var outcome = Outcome()
        PreferenceSyncService.checkForRemoteWipeSignal(
            iKV: store, local: local, isWipingData: false,
            submit: { outcome.intents.append($0) },
            postRemoteOnboardingCompleted: { outcome.remoteOnboardingPosts += 1 },
            now: now ?? t0,
            scheduleRecheck: { outcome.rechecks.append($0) })
        return outcome
    }

    /// Pasada la espera de la marca, con un segundo de margen.
    private var afterTheWait: Date { t0.addingTimeInterval(PreferenceSyncService.wipeMarkWait + 1) }

    @Test("una sesión en la nube no encola el vaciado remoto del Apple ID, y da la señal por procesada")
    func cloudSession_doesNotEnqueue() throws {
        let (store, local) = try phone(privateMark: true)
        let outcome = detect(store, local, mode: .cloud)
        #expect(outcome.intents.isEmpty, "una sesión en la nube vaciaría sus datos —y sus borrados subirían a SU cuenta— por un vaciado de otro iCloud")
        #expect(local.double(forKey: "lastKnownWipeTimestamp") == 2_000,
                "la señal tiene que quedar procesada aunque no se obedezca: si no, se re-evalúa en cada arranque")
    }

    @Test("control: la sesión privada confirmada SÍ encola el vaciado, una vez")
    func confirmedPrivateSession_enqueuesOnce() throws {
        let (store, local) = try phone(privateMark: true)
        // Sin la marca del parque, la primera pasada aparca la señal (ver los casos de orden de llegada, abajo).
        let first = detect(store, local, mode: .icloud)
        #expect(first.intents.isEmpty)
        #expect(local.double(forKey: "lastKnownWipeTimestamp") == 2_000)
        let outcome = detect(store, local, mode: .icloud, now: afterTheWait)
        #expect(outcome.intents == [.remoteWipe(skipOnboarding: false)])

        // Y la misma señal no vuelve a encolarse en la pasada siguiente.
        #expect(detect(store, local, mode: .icloud, now: afterTheWait.addingTimeInterval(60)).intents.isEmpty)
    }

    @Test("la marca del eje ausente falla CERRADO: no encola")
    func absentPrivateMark_doesNotEnqueue() throws {
        let (store, local) = try phone(privateMark: nil)
        #expect(detect(store, local, mode: .icloud).intents.isEmpty)
    }

    @Test("con otro dispositivo que ya terminó el onboarding tras el vaciado, el intent lo dice")
    func onboardingAlreadyDoneElsewhere_isCarried() throws {
        let (store, local) = try phone(privateMark: true)
        store.values["lastOnboardingTimestamp"] = 3_000.0
        #expect(detect(store, local, mode: .icloud).intents == [.remoteWipe(skipOnboarding: true)])
    }

    @Test("el onboarding remoto tras un vaciado ya procesado avisa y encola su intent, en las dos sesiones")
    func remoteOnboardingAfterProcessedWipe() throws {
        for mode in [StorageMode.icloud, .cloud] {
            let (store, local) = try phone(privateMark: true)
            local.set(2_000.0, forKey: "lastKnownWipeTimestamp")
            store.values["lastOnboardingTimestamp"] = 3_000.0
            let outcome = detect(store, local, mode: mode)
            #expect(outcome.intents == [.remoteOnboardingCompleted], "\(mode)")
            #expect(outcome.remoteOnboardingPosts == 1, "\(mode)")
        }
    }

    // MARK: - Orden de llegada: la señal antes que la marca del parque

    /// **El caso del ticket** `wipe-signal-arriving-before-the-fleet-mark-takes-the-origin-seed`. «Vaciar datos» que se
    /// queda en el Panel sube la marca y la señal en el mismo `synchronize`, y el iCloud KV no garantiza el orden. Si la
    /// señal llega sola, el receptor no decide: la consume, la aparca y pide una vuelta. Cuando llega la marca, entra por
    /// «el parque sigue» (`skipOnboarding: true`): conserva sus ajustes, sus recordatorios y la semilla del origen.
    @Test("la señal que llega antes que la marca se aparca, y al llegar la marca el receptor se queda en la app")
    func signalBeforeMark_waits_thenKeepsSetup() throws {
        let (store, local) = try phone(privateMark: true)

        let alone = detect(store, local, mode: .icloud)
        #expect(alone.intents.isEmpty, "decidió con la señal sola: el receptor vuelve al onboarding y se lleva la semilla del origen")
        #expect(alone.rechecks == [PreferenceSyncService.wipeMarkWait], "aparcó la señal sin pedir la vuelta que cierra la espera")
        #expect(local.double(forKey: "lastKnownWipeTimestamp") == 2_000, "la señal se consume aunque espere")

        // Llega la marca, 3 s después: la otra mitad de la misma señal.
        store.values["lastOnboardingTimestamp"] = 2_000.001
        let withMark = detect(store, local, mode: .icloud, now: t0.addingTimeInterval(3))
        #expect(withMark.intents == [.remoteWipe(skipOnboarding: true)])
        #expect(withMark.remoteOnboardingPosts == 0, "la marca de esta señal no es un onboarding remoto de otro vaciado")

        // Cerrada la espera, la señal no vuelve a encolar el vaciado (el aviso de onboarding remoto que sigue es el de
        // siempre tras una señal con marca, y su manejador no hace nada fuera del onboarding).
        #expect(!detect(store, local, mode: .icloud, now: afterTheWait).intents.contains(.remoteWipe(skipOnboarding: true)))
        #expect(!detect(store, local, mode: .icloud, now: afterTheWait).intents.contains(.remoteWipe(skipOnboarding: false)))
    }

    @Test("control: si la marca no llega, al vencer la espera se decide como siempre (el parque empezó de cero)")
    func signalWithoutMark_afterTheWait_startsOver() throws {
        let (store, local) = try phone(privateMark: true)
        _ = detect(store, local, mode: .icloud)

        // Antes de vencer, una pasada (otro cambio del KV) sigue esperando y pide la vuelta por lo que falta.
        let halfway = detect(store, local, mode: .icloud, now: t0.addingTimeInterval(5))
        #expect(halfway.intents.isEmpty)
        #expect(halfway.rechecks == [PreferenceSyncService.wipeMarkWait - 5])

        #expect(detect(store, local, mode: .icloud, now: afterTheWait).intents == [.remoteWipe(skipOnboarding: false)])
    }

    @Test("la espera sobrevive a cerrar la app: el arranque siguiente la cierra con lo que haya")
    func awaitedSignal_survivesARelaunch() throws {
        let (store, local) = try phone(privateMark: true)
        _ = detect(store, local, mode: .icloud)
        // La app muere; al volver, la marca ya llegó.
        store.values["lastOnboardingTimestamp"] = 2_000.001
        #expect(detect(store, local, mode: .icloud, now: t0.addingTimeInterval(3_600)).intents
                == [.remoteWipe(skipOnboarding: true)])
    }

    @Test("con la marca ya presente, la señal no espera nada")
    func signalWithMark_doesNotWait() throws {
        let (store, local) = try phone(privateMark: true)
        store.values["lastOnboardingTimestamp"] = 2_000.001
        let outcome = detect(store, local, mode: .icloud)
        #expect(outcome.intents == [.remoteWipe(skipOnboarding: true)])
        #expect(outcome.rechecks.isEmpty)
    }

    @Test("una sesión que no obedece la señal no espera: la da por procesada en el acto")
    func cloudSession_doesNotWait() throws {
        let (store, local) = try phone(privateMark: true)
        let outcome = detect(store, local, mode: .cloud)
        #expect(outcome.rechecks.isEmpty)
        #expect(detect(store, local, mode: .cloud, now: afterTheWait).intents.isEmpty,
                "la espera de una sesión que no obedece acabó encolando el vaciado")
    }

    @Test("la espera se decide con la sesión de AL CERRARLA: si en ese rato pasó a la nube, no encola")
    func awaitedSignal_rechecksTheSessionWhenItCloses() throws {
        let (store, local) = try phone(privateMark: true)
        _ = detect(store, local, mode: .icloud)
        #expect(detect(store, local, mode: .cloud, now: afterTheWait).intents.isEmpty)
    }
}
