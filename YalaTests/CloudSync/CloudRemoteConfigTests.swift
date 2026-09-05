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


// MARK: - El cliente: coalescencia y `force`

/// **Comportamiento de `RemoteConfigClient.refreshIfDue`, que hasta el 2026-09-05 no tenía ninguno.**
///
/// Cinco source-scans (`GroupInviteChannelRoutingLogicTests`, `GroupCreateRoutingLogicTests`,
/// `GroupsOrganizerBranchTests`, `GroupsGateLogicTests`) afirman que los call-sites pasan
/// `force: true`, y ninguno ejercita QUÉ hace ese `force`: los cinco estaban verdes con el bug vivo
/// —el `force` salía por el guard `inFlight` sin tocar la red— y seguirían verdes si el arreglo se
/// hiciera mal. Esta suite es la red que faltaba.
///
/// Defaults AISLADOS y cliente propio: nunca `.standard`, nunca `RemoteConfigClient.shared`.
@Suite("RemoteConfigClient — el `force` no se rinde ante un refresco en vuelo")
@MainActor
struct RemoteConfigClientRefreshTests {

    private static let baseURL = URL(string: "https://config.test.invalid")!

    private func makeClient(_ session: SyncHTTPSession, _ defaults: UserDefaults) -> RemoteConfigClient {
        RemoteConfigClient(baseURL: Self.baseURL, urlSession: session, defaults: defaults)
    }

    /// **El bug, tal cual.** Recién instalado: el arranque deja un `GET /config` en vuelo y el
    /// invitado tapea el enlace encima. El `force` del camino del invite salía por `guard !inFlight`
    /// SIN tocar la red y volvía al instante; su call-site releía el flag —todavía apagado, porque
    /// nadie escribió el snapshot— y le enseñaba «no pudimos abrir esta invitación» con el canal
    /// perfectamente encendido.
    ///
    /// El aserto es el que el bug no puede pasar: **cuando el `force` vuelve, el snapshot YA existe**.
    /// Un no-op vuelve con `nil` y falla aquí. Y `callCount == 1` fija la otra mitad: esperar, no
    /// abrir una segunda petición idéntica.
    @Test func force_waitsForTheInFlightFetch_insteadOfReturningEmptyHanded() async throws {
        let defaults = makeIsolatedDefaults(prefix: "remoteconfig-force")
        let session = GatedConfigSession(groupsPercent: 100)
        let client = makeClient(session, defaults)

        // Paso 14.56 del arranque: `refreshIfDue()` sin force. Queda suspendido dentro del transporte.
        let boot = Task { @MainActor in await client.refreshIfDue() }
        await session.waitUntilFirstRequestStarted()
        #expect(CloudRemoteConfigStore.readSnapshot(defaults) == nil,
                "precondición: el fetch del arranque está en vuelo y todavía no escribió nada")

        // El tap del enlace, encima. Devuelve lo que su call-site leería justo después.
        let forced = Task { @MainActor () -> RemoteFlagsSnapshot? in
            await client.refreshIfDue(force: true)
            return CloudRemoteConfigStore.readSnapshot(defaults)
        }

        session.release()
        let visto = try #require(await forced.value, """
            El `force` volvió con el snapshot todavía AUSENTE: se rindió ante el fetch en vuelo en \
            vez de esperarlo. Su call-site relee `CloudSyncFlags.groupsBackendEnabled` en la línea \
            siguiente, así que eso es exactamente la alerta falsa «Hubo un problema con el grupo» en \
            el primer minuto del recién instalado.
            """)
        #expect(visto.groupsBackendRolloutPercent == 100)
        #expect(session.callCount == 1, """
            El `force` abrió una SEGUNDA petición en vez de reutilizar la respuesta del fetch que \
            esperaba. Dos fetches simultáneos pueden escribir el snapshot fuera de orden (la \
            respuesta más vieja aterriza la última) — es justo la carrera que esperar evita.
            """)
        await boot.value
    }

    /// La otra mitad del arreglo: si el fetch esperado NO trae config (no-200, red caída, decode
    /// roto), el snapshot no avanza y conformarse cambiaría un fallo por otro — la misma alerta
    /// falsa cada vez que el refresco del arranque falle. El `force` lanza entonces el suyo.
    @Test func force_launchesItsOwnFetch_whenTheAwaitedOneFailed() async throws {
        let defaults = makeIsolatedDefaults(prefix: "remoteconfig-force-retry")
        let session = GatedConfigSession(groupsPercent: 100, statuses: [500, 200])
        let client = makeClient(session, defaults)

        let boot = Task { @MainActor in await client.refreshIfDue() }
        await session.waitUntilFirstRequestStarted()

        let forced = Task { @MainActor () -> RemoteFlagsSnapshot? in
            await client.refreshIfDue(force: true)
            return CloudRemoteConfigStore.readSnapshot(defaults)
        }

        session.release()
        let visto = try #require(await forced.value, """
            El fetch esperado devolvió 500 y el `force` se conformó con eso. El snapshot sigue \
            ausente ⇒ fail-closed ⇒ la misma alerta falsa, ahora cada vez que el refresco del \
            arranque falle.
            """)
        #expect(visto.groupsBackendRolloutPercent == 100)
        #expect(session.callCount == 2, "el force tiene que haber pedido el suyo tras el 500 ajeno")
        await boot.value
    }

    /// **Dos puertas despiertas a la vez.** El enlace de invitación y la puerta del Welcome pueden
    /// forzar sobre el MISMO fetch del arranque; si ése falla, las dos despiertan a la vez y sin la
    /// re-comprobación de `inFlight` cada una abriría la suya — N peticiones y N escrituras del
    /// snapshot, que es justo la carrera que esperar existe para evitar. La segunda se engancha a la
    /// del primero.
    @Test func twoForcesWakingFromTheSameFailure_shareASingleRetry() async throws {
        let defaults = makeIsolatedDefaults(prefix: "remoteconfig-force-fanout")
        let session = GatedConfigSession(groupsPercent: 100, statuses: [500, 200])
        let client = makeClient(session, defaults)

        let boot = Task { @MainActor in await client.refreshIfDue() }
        await session.waitUntilFirstRequestStarted()

        let puertaA = Task { @MainActor in await client.refreshIfDue(force: true) }
        let puertaB = Task { @MainActor in await client.refreshIfDue(force: true) }

        session.release()
        await boot.value
        await puertaA.value
        await puertaB.value

        #expect(session.callCount == 2, """
            Las dos puertas abrieron su propia petición tras el fallo compartido (\(session.callCount) \
            en total, se esperaban 2: el fetch del arranque y UN reintento). La segunda tiene que \
            engancharse al reintento de la primera, no lanzar el suyo.
            """)
        #expect(CloudRemoteConfigStore.readSnapshot(defaults)?.groupsBackendRolloutPercent == 100,
                "las dos puertas acaban viendo la config, que es lo que fueron a buscar")
    }

    /// La regla vieja, INTACTA: un kick normal (boot, `onAppear`) que llega con un fetch en vuelo
    /// sigue haciendo no-op. Es la coalescencia de la que depende que las cuatro entradas puedan
    /// re-verificar el canal sin spamear la red.
    @Test func normalKick_stillCoalescesWithTheInFlightFetch() async throws {
        let defaults = makeIsolatedDefaults(prefix: "remoteconfig-coalesce")
        let session = GatedConfigSession(groupsPercent: 100)
        let client = makeClient(session, defaults)

        let primero = Task { @MainActor in await client.refreshIfDue() }
        await session.waitUntilFirstRequestStarted()

        await client.refreshIfDue()      // segundo kick SIN force: vuelve al momento, sin pedir nada
        #expect(session.callCount == 1, """
            La coalescencia se perdió: un kick sin `force` abrió una segunda petición sobre el fetch \
            en vuelo. El `force` es la excepción a esa regla, no su sustituto.
            """)

        session.release()
        await primero.value
        #expect(CloudRemoteConfigStore.readSnapshot(defaults)?.groupsBackendRolloutPercent == 100)
    }

    /// Sin nada en vuelo, `force` sigue saltando el min-interval de 6 h y un kick normal sigue
    /// respetándolo. Es la semántica original del parámetro y ningún test la sostenía.
    @Test func withoutAnythingInFlight_forceSkipsTheMinInterval_andAPlainKickDoesNot() async throws {
        let defaults = makeIsolatedDefaults(prefix: "remoteconfig-mininterval")
        let ahora = Date(timeIntervalSince1970: 1_800_000_000)
        CloudRemoteConfigStore.writeSnapshot(
            RemoteFlagsSnapshot(
                cloudModeRolloutPercent: nil,
                cloudOnboardingChoiceRolloutPercent: nil,
                groupsBackendRolloutPercent: 0,
                fetchedAt: ahora.addingTimeInterval(-60)),   // fetcheado hace un minuto
            defaults: defaults)

        let session = GatedConfigSession(groupsPercent: 100, gateFirstRequest: false)
        let client = makeClient(session, defaults)

        await client.refreshIfDue(now: ahora)
        #expect(session.callCount == 0, "un kick normal con snapshot de hace un minuto no toca la red")
        #expect(CloudRemoteConfigStore.readSnapshot(defaults)?.groupsBackendRolloutPercent == 0)

        await client.refreshIfDue(force: true, now: ahora)
        #expect(session.callCount == 1, "el `force` salta el min-interval: es la cohorte exacta del bug")
        #expect(CloudRemoteConfigStore.readSnapshot(defaults)?.groupsBackendRolloutPercent == 100)
    }
}

/// Sesión que SUSPENDE la primera petición hasta `release()` y responde las siguientes al momento —
/// el molde exacto del bug: el fetch del arranque queda en vuelo mientras el tap del enlace fuerza el
/// suyo. Determinista: `waitUntilFirstRequestStarted()` señala la entrada, sin sleeps ni timeouts.
/// Molde de `GatedSession` (CloudSyncRuntimeTests): sus métodos corren en el actor del caller
/// (MainActor en estos tests) → el estado mutable no se toca concurrentemente.
private final class GatedConfigSession: SyncHTTPSession, @unchecked Sendable {
    private let body: Data
    /// Status HTTP por número de llamada; la última entrada se repite si hay más llamadas.
    private let statuses: [Int]
    private let gateFirstRequest: Bool
    private(set) var callCount = 0
    private var started = false
    private var released = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var gateContinuation: CheckedContinuation<Void, Never>?

    init(groupsPercent: Int, statuses: [Int] = [200], gateFirstRequest: Bool = true) {
        self.body = Data(#"{"v":1,"flags":{"groupsBackendRolloutPercent":\#(groupsPercent)}}"#.utf8)
        self.statuses = statuses
        self.gateFirstRequest = gateFirstRequest
    }

    /// Suspende hasta que la PRIMERA petición haya entrado en `data(for:)` (el fetch está en vuelo).
    func waitUntilFirstRequestStarted() async {
        if started { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    /// Libera la petición retenida (el transporte «responde»).
    func release() {
        released = true
        gateContinuation?.resume()
        gateContinuation = nil
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        let call = callCount
        if call == 1 && gateFirstRequest {
            started = true
            startedContinuation?.resume()
            startedContinuation = nil
            if !released {
                await withCheckedContinuation { gateContinuation = $0 }
            }
        }
        let status = statuses[min(call - 1, statuses.count - 1)]
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status,
                                             httpVersion: nil, headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return (body, response)
    }
}
