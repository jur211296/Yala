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
        #expect(CloudRemoteFlags.secondarySessionEnabled == CloudRemoteFlags.absentDefault)
    }

    @Test func remoteFlags_testOverrides_win() {
        CloudRemoteFlags._testSetOverrides(
            cloudMode: false, onboardingChoice: true, groupsBackend: false, secondarySession: true)
        defer { CloudRemoteFlags._testResetOverrides() }
        #expect(!CloudRemoteFlags.cloudModeEnabled)
        #expect(CloudRemoteFlags.cloudOnboardingChoiceEnabled)
        #expect(!CloudRemoteFlags.groupsBackendEnabled)
        #expect(CloudRemoteFlags.secondarySessionEnabled)
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

    // MARK: - Entrada secundaria (composición con los DOS flags remotos)

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
        // Desde el chip M2 hay que fijar los DOS términos remotos: dejar el propio sin override lo
        // haría caer en `absentDefault`, que es `false` bajo el scheme `Yala`.
        CloudRemoteFlags._testSetOverrides(cloudMode: true, secondarySession: true)
        #expect(CloudSyncFlags.secondarySessionEntryAvailable)
        CloudRemoteFlags._testSetOverrides(cloudMode: false, secondarySession: true)
        #expect(!CloudSyncFlags.secondarySessionEntryAvailable)
    }

    // MARK: - Chip M2 · el percent PROPIO de la sesión secundaria

    /// **La razón de ser del chip, en dos aserciones.** Hasta M2 la entrada secundaria tomaba prestado
    /// el kill-switch de `cloudModeEnabled`, que no se puede mover sin mover también las superficies
    /// de alta del Modo Nube. El AND se CONSERVA (doble kill-switch), pero cada palanca corta sola.
    @Test func secondaryEntry_hasItsOwnRemoteLever_andKeepsTheCloudModeAnd() {
        CloudSyncFlags.secondarySessionEnabled = true
        defer {
            CloudSyncFlags._testResetSecondarySessionEnabledOverride()
            CloudRemoteFlags._testResetOverrides()
        }
        // Control POSITIVO: los dos ON ⇒ entrada disponible.
        CloudRemoteFlags._testSetOverrides(cloudMode: true, secondarySession: true)
        #expect(CloudSyncFlags.secondarySessionEntryAvailable)
        // El percent PROPIO corta sin tocar el Modo Nube. Sin esta mitad, el flag nuevo podría estar
        // declarado y no compuesto, y todo lo demás seguiría en verde.
        CloudRemoteFlags._testSetOverrides(cloudMode: true, secondarySession: false)
        #expect(!CloudSyncFlags.secondarySessionEntryAvailable)
    }

    /// La capacidad COMPILADA nace en `true` (palanca de release del binario) y aun así la entrada es
    /// DARK en producción, porque el percent la decide. Es el patrón de `bornCloudChoiceEnabled`.
    @Test func secondaryEntry_compiledCapabilityIsOn_butTheRolloutDecides() {
        CloudSyncFlags._testResetSecondarySessionEnabledOverride()
        defer { CloudRemoteFlags._testResetOverrides() }
        #expect(CloudSyncFlags.secondarySessionEnabled, """
            La capacidad compilada volvió a `false`: el flip del percent (chip M5) dejaría de encender \
            nada y encender M1 volvería a exigir recompilar, que es el bug que M2 arregla.
            """)
        CloudRemoteFlags._testSetOverrides(cloudMode: true, secondarySession: false)
        #expect(!CloudSyncFlags.secondarySessionEntryAvailable)
    }

    /// **FAIL-CLOSED en fresh install, hasta la celda del guard.** Sin snapshot (producción antes del
    /// primer fetch) el percent es ausente ⇒ `absentDefault` fail-closed ⇒ el guard cross-cuenta
    /// degrada a `blockedForeignData`: la pantalla honesta de hoy, jamás un error.
    @Test func absentPercent_failsClosed_andTheGuardDegradesToBlocked() {
        #expect(RemoteFlagDecisionLogic.isEnabled(percent: nil, bucket: 0, absentDefault: false) == false)
        #expect(RemoteFlagDecisionLogic.isEnabled(percent: 0, bucket: 0, absentDefault: true) == false)
        #expect(RemoteFlagDecisionLogic.isEnabled(percent: 100, bucket: 99, absentDefault: false))

        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            accountExists: true, secondarySessionEnabled: false,
            restoreInProgress: false) == .blockedForeignData)
        // Control positivo de la celda: con la entrada disponible, la MISMA fila enruta a secundaria.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            accountExists: true, secondarySessionEnabled: true,
            restoreInProgress: false) == .proceedSecondarySession)
    }

    /// **LA MUTACIÓN DEL CHIP: hacer el campo del snapshot no-opcional.** Un snapshot cacheado por un
    /// build anterior no trae la key; si el campo no fuera opcional el decode LANZA, `readSnapshot`
    /// lo trata como ausente y el device pierde también los otros tres percents hasta el próximo
    /// fetch — un flag nuevo apagando flags viejos.
    @Test func oldCachedSnapshot_decodesAsAbsentPercent_neverAsAnError() throws {
        let viejo = Data(#"""
        {"cloudModeRolloutPercent":100,"groupsBackendRolloutPercent":100,\#
        "fetchedAt":768614400}
        """#.utf8)
        let snapshot = try JSONDecoder().decode(RemoteFlagsSnapshot.self, from: viejo)
        #expect(snapshot.secondarySessionRolloutPercent == nil)
        #expect(snapshot.cloudModeRolloutPercent == 100, "el snapshot viejo conserva lo que SÍ traía")
    }

    /// El wire del gateway: campo presente se lee, ausente queda nil (tolerancia de shape en las dos
    /// direcciones — un cliente nuevo contra un gateway sin desplegar).
    @Test func wireDecode_secondarySessionPercent() throws {
        let conCampo = Data(#"{"v":1,"flags":{"secondarySessionRolloutPercent":100}}"#.utf8)
        #expect(try JSONDecoder().decode(RemoteConfigWireResponse.self, from: conCampo)
            .flags?.secondarySessionRolloutPercent == 100)

        let sinCampo = Data(#"{"v":1,"flags":{"cloudModeRolloutPercent":100}}"#.utf8)
        #expect(try JSONDecoder().decode(RemoteConfigWireResponse.self, from: sinCampo)
            .flags?.secondarySessionRolloutPercent == nil)
    }
}

/// Cableado del flag (source-scan). Que la key DEBUG siga mandando en `DEV_BUILD` y que el getter
/// componga la capacidad con el percent PROPIO son afirmaciones sobre la FORMA del getter: los tests
/// de comportamiento corren con overrides (y no pueden tocar `.standard` para la key DEV), así que
/// sin este scan un getter que perdiera la key DEV, o que se dejara el término remoto, pasaría verde.
@Suite("M2 · cableado del percent propio de la sesión secundaria (source-scan)")
struct SecondarySessionFlagWiringTests {

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("la key DEBUG sigue mandando en DEV_BUILD y el compuesto lleva los DOS términos remotos")
    func entryAvailable_composesOwnPercent_andKeepsTheDevKey() throws {
        let src = try Self.code("Yala/Services/CloudSync/CloudSyncFlags.swift")

        let getter = try #require(src.range(of: "static var secondarySessionEnabled: Bool {"))
        let capability = try #require(src.range(of: "secondarySessionCompiledDefault", range: getter.upperBound..<src.endIndex))
        let devKey = try #require(src.range(of: "debugSecondarySessionEnabledKey", range: getter.upperBound..<src.endIndex))
        #expect(devKey.lowerBound < capability.lowerBound, """
            La key DEBUG dejó de tener prioridad sobre el compilado: el QA en device volvería a \
            necesitar un build nuevo para encender la entrada.
            """)

        let compuesto = try #require(src.range(of: "static var secondarySessionEntryAvailable: Bool {"))
        let cuerpo = String(src[compuesto.upperBound...].prefix(400))
        #expect(cuerpo.contains("CloudRemoteFlags.secondarySessionEnabled"), """
            El compuesto perdió el percent PROPIO: el flip del chip M5 no encendería nada y el feature \
            volvería a depender del kill-switch prestado de CLOUD_MODE.
            """)
        #expect(cuerpo.contains("CloudRemoteFlags.cloudModeEnabled"),
                "el AND con el Modo Nube es el segundo kill-switch y no se sustituye por el nuevo")
    }

    /// El percent viaja de punta a punta: la var del Worker, el campo del wire y el del snapshot tienen
    /// que existir los tres. Que el gateway lo publique lo cubre `gateway/test/config.test.ts`; esto es
    /// la mitad del cliente, que ningún test del gateway puede ver.
    @Test("el percent se mapea del wire al snapshot al refrescar")
    func wirePercent_isMappedIntoTheSnapshot() throws {
        let src = try Self.code("Yala/Services/CloudSync/CloudRemoteConfig.swift")
        #expect(src.contains("secondarySessionRolloutPercent: wire.flags?.secondarySessionRolloutPercent"), """
            `refreshIfDue` no copia el percent nuevo al snapshot: el campo existiría, el gateway lo \
            publicaría y el device leería SIEMPRE «ausente» ⇒ fail-closed permanente en producción.
            """)
    }
}
