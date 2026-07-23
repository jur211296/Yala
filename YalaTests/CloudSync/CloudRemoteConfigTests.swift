//
//  CloudRemoteConfigTests.swift
//  YalaTests / CloudSync
//
//  Store del remote-config (defaults AISLADOS — nunca `.standard`), flags efectivos vía
//  override, y la composición `compilado && remoto` de `CloudSyncFlags.groupsBackendEnabled`
//  (DIFERIDOS #34). `.serialized`: toca overrides estáticos, siempre con `defer { restore }`.
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudRemoteConfig — store, flags efectivos y composición de groupsBackend", .serialized)
struct CloudRemoteConfigTests {

    // MARK: - Store (defaults aislados)

    @Test func store_roundTrip_andCorruptSnapshot() {
        let defaults = makeIsolatedDefaults()
        #expect(CloudRemoteConfigStore.readSnapshot(defaults) == nil)

        let snapshot = RemoteFlagsSnapshot(
            cloudModeRolloutPercent: 25,
            cloudOnboardingChoiceRolloutPercent: nil,
            groupsBackendRolloutPercent: 100,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        CloudRemoteConfigStore.writeSnapshot(snapshot, defaults: defaults)
        #expect(CloudRemoteConfigStore.readSnapshot(defaults) == snapshot)

        // Snapshot corrupto (bit-rot / schema viejo) → como ausente, sin crash.
        defaults.set(Data("garbage".utf8), forKey: CloudRemoteConfigStore.snapshotKey)
        #expect(CloudRemoteConfigStore.readSnapshot(defaults) == nil)
    }

    @Test func store_bucketSeed_createdOnce_thenStable() {
        let defaults = makeIsolatedDefaults()
        let first = CloudRemoteConfigStore.bucketSeed(defaults)
        #expect(UUID(uuidString: first) != nil)
        // Estable: la cohorte de rollout no se re-baraja entre lecturas/launches.
        #expect(CloudRemoteConfigStore.bucketSeed(defaults) == first)
    }

    @Test func wireDecode_tolerant() throws {
        // Campo desconocido + flag ausente → decodifica y el ausente queda nil (→ absentDefault).
        let json = Data(#"{"v":1,"flags":{"cloudModeRolloutPercent":50,"futureUnknownFlag":7}}"#.utf8)
        let wire = try JSONDecoder().decode(RemoteConfigWireResponse.self, from: json)
        #expect(wire.flags?.cloudModeRolloutPercent == 50)
        #expect(wire.flags?.groupsBackendRolloutPercent == nil)
        // forceUpdate ausente → nil (fail-open); snapshots viejos no rompen.
        #expect(wire.forceUpdate?.minSupportedBuild == nil)
    }

    @Test func wireDecode_forceUpdate() throws {
        let json = Data(#"{"v":1,"flags":{},"forceUpdate":{"minSupportedBuild":137}}"#.utf8)
        let wire = try JSONDecoder().decode(RemoteConfigWireResponse.self, from: json)
        #expect(wire.forceUpdate?.minSupportedBuild == 137)
    }

    @Test func snapshot_roundTrip_withMinSupportedBuild() {
        let defaults = makeIsolatedDefaults()
        let snapshot = RemoteFlagsSnapshot(
            cloudModeRolloutPercent: nil,
            cloudOnboardingChoiceRolloutPercent: nil,
            groupsBackendRolloutPercent: nil,
            minSupportedBuild: 200,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        CloudRemoteConfigStore.writeSnapshot(snapshot, defaults: defaults)
        #expect(CloudRemoteConfigStore.readSnapshot(defaults)?.minSupportedBuild == 200)
    }

    // MARK: - Flags efectivos (overrides; bajo tests el snapshot persistido se IGNORA)

    @Test func remoteFlags_underTests_useAbsentDefault_neverStandardDefaults() {
        // Ajuste A2 del review: bajo `isRunningTests` los getters devuelven el default (DEV=ON en
        // el host de tests) sin leer `.standard` — un snapshot real del sim host no contamina.
        CloudRemoteFlags._testResetOverrides()
        #expect(CloudRemoteFlags.cloudModeEnabled == CloudRemoteFlags.absentDefault)
        #expect(CloudRemoteFlags.groupsBackendEnabled == CloudRemoteFlags.absentDefault)
        #expect(CloudRemoteFlags.cloudOnboardingChoiceEnabled == CloudRemoteFlags.absentDefault)
    }

    @Test func remoteFlags_testOverrides_win() {
        CloudRemoteFlags._testSetOverrides(cloudMode: false, onboardingChoice: true, groupsBackend: false)
        defer { CloudRemoteFlags._testResetOverrides() }
        #expect(!CloudRemoteFlags.cloudModeEnabled)
        #expect(CloudRemoteFlags.cloudOnboardingChoiceEnabled)
        #expect(!CloudRemoteFlags.groupsBackendEnabled)
    }

    // MARK: - Composición groupsBackend (compilado && remoto)

    @Test func groupsBackend_compiledFalse_staysOff_evenWithRemoteOn() {
        // El remoto solo puede MATAR, nunca encender solo: con el compilado `false` (HOY,
        // producción) la composición corta aunque el remoto diga 100%.
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        CloudRemoteFlags._testSetOverrides(groupsBackend: true)
        defer { CloudRemoteFlags._testResetOverrides() }
        #expect(!CloudSyncFlags.groupsBackendEnabled)
    }

    @Test func groupsBackend_testSetter_isSourceCompatibleOverride() {
        // Idiom vigente en decenas de tests: `= true; defer { = false }` — el setter guarda un
        // override en memoria y el getter lo respeta por encima de la composición.
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        #expect(CloudSyncFlags.groupsBackendEnabled)
        CloudSyncFlags.groupsBackendEnabled = false
        #expect(!CloudSyncFlags.groupsBackendEnabled)
    }

    // MARK: - Entrada secundaria (composición con el flag remoto)

    @Test func secondaryEntry_killedByRemoteOff() {
        // La ENTRADA secundaria es superficie de alta nueva → el kill-switch la corta.
        CloudSyncFlags.secondarySessionEnabled = true
        defer {
            CloudSyncFlags._testResetSecondarySessionEnabledOverride()
            CloudRemoteFlags._testResetOverrides()
        }
        // Control POSITIVO primero (fix del review: sin él, cualquier otro conjunct en false
        // haría pasar el negativo sin probar el AND remoto). Host DEV ⇒ isConfigured=true.
        CloudRemoteFlags._testSetOverrides(cloudMode: true)
        #expect(CloudSyncFlags.secondarySessionEntryAvailable)
        CloudRemoteFlags._testSetOverrides(cloudMode: false)
        #expect(!CloudSyncFlags.secondarySessionEntryAvailable)
    }
}
