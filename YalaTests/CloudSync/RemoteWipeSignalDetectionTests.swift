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

    private func detect(_ store: WipeSignalSpyStore, _ local: UserDefaults, mode: StorageMode) -> Outcome {
        CloudSyncFlags.storageMode = mode
        defer { CloudSyncFlags._testResetStorageModeOverride() }
        var outcome = Outcome()
        PreferenceSyncService.checkForRemoteWipeSignal(
            iKV: store, local: local, isWipingData: false,
            submit: { outcome.intents.append($0) },
            postRemoteOnboardingCompleted: { outcome.remoteOnboardingPosts += 1 })
        return outcome
    }

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
        let outcome = detect(store, local, mode: .icloud)
        #expect(outcome.intents == [.remoteWipe(skipOnboarding: false)])
        #expect(local.double(forKey: "lastKnownWipeTimestamp") == 2_000)

        // Y la misma señal no vuelve a encolarse en la pasada siguiente.
        #expect(detect(store, local, mode: .icloud).intents.isEmpty)
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
}
