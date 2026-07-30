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

    /// Contrato del kill-switch DESPUÉS del flip de D-R1 paso 2 (`groupsBackendCompiledDefault = true`).
    /// Antes este test afirmaba lo contrario —que la composición cortaba por el compilado aunque el
    /// remoto dijera 100%—, y con el flip pasó a rojo en los DOS schemes: correcto, era el test que
    /// pinneaba el estado pre-flip.
    ///
    /// Las dos mitades importan. La (b) es el CONTROL POSITIVO y es lo que ata este test al flip: sin
    /// ella, un compilado que volviera a `false` pasaría inadvertido. Nada de esto depende de
    /// `absentDefault`: el término remoto está fijado por override en las dos mitades, así que la
    /// aserción es idéntica bajo `Yala` y bajo `Yala Dev`.
    @Test func groupsBackend_remoteKillSwitch_cutsChannel_withCompiledOn() {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()  // composición REAL, sin override
        defer { CloudRemoteFlags._testResetOverrides() }

        // (a) El remoto solo puede MATAR: con el compilado ON, un kill apaga el canal.
        CloudRemoteFlags._testSetOverrides(groupsBackend: false)
        #expect(!CloudSyncFlags.groupsBackendEnabled)

        // (b) Compilado ON + remoto ON = canal ON. Esta es la mitad que cae si el flip se revierte.
        CloudRemoteFlags._testSetOverrides(groupsBackend: true)
        #expect(CloudSyncFlags.groupsBackendEnabled)

        // Y la capacidad del BINARIO no la toca el kill: es lo que leen los paths de teardown.
        CloudRemoteFlags._testSetOverrides(groupsBackend: false)
        #expect(CloudSyncFlags.groupsBackendCompiledCapability)
    }

    /// `absentDefault` es, desde el flip, lo ÚNICO que separa `CloudSyncFlags.groupsBackendEnabled`
    /// entre los dos schemes en el host de tests (`decide()` cortocircuita en `isRunningTests`). El test
    /// de arriba lo neutraliza con overrides a propósito; este lo pinnea de frente, porque un cambio en
    /// `absentDefault` movería en silencio el default de media suite.
    @Test func groupsBackend_defaultUnderTests_followsAbsentDefaultPerScheme() {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        CloudRemoteFlags._testResetOverrides()
        #if DEV_BUILD
        #expect(CloudSyncFlags.groupsBackendEnabled)   // Yala Dev: absentDefault ON
        #else
        #expect(!CloudSyncFlags.groupsBackendEnabled)  // Yala: absentDefault fail-closed
        #endif
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
        // haría pasar el negativo sin probar el AND remoto). `isConfigured` es `true` en los DOS
        // schemes desde D-R1 paso 1 — antes, con el scheme `Yala`, este control positivo fallaba.
        CloudRemoteFlags._testSetOverrides(cloudMode: true)
        #expect(CloudSyncFlags.secondarySessionEntryAvailable)
        CloudRemoteFlags._testSetOverrides(cloudMode: false)
        #expect(!CloudSyncFlags.secondarySessionEntryAvailable)
    }
}
