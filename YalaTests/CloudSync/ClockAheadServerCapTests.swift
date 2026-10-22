//
//  ClockAheadServerCapTests.swift
//  YalaTests / CloudSync
//
//  Tickets `personal-clock-ahead-wins-every-conflict-until-real-time-catches-up` y
//  `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`. Un teléfono con la hora adelantada ganaba todos
//  los conflictos, y el OTRO dispositivo podía quedarse divergente: veía la fila del adelantado, su reloj no la integraba
//  (deriva > 5 min), editaba con un HLC más bajo, perdía en el servidor (`noop`), purgaba su cambio y seguía mostrando un
//  valor que el servidor no tenía.
//
//  El arreglo tiene dos mitades. La del servidor (`qa/cloud/hlc01_cap_future_hlc.sql`, banco `hlc01-cap-test.sh`) acota
//  todo HLC guardado a `now() + 60 s`. La del cliente, que es la que se prueba aquí, hace que los tres pulls INTEGREN lo que
//  bajan (`HLCClock.observePulled`): el personal ya lo hacía y fallaba por la deriva; Grupos y preferencias no lo hacían.
//  Con las dos, el cambio que un teléfono hace tras VER una fila se estampa por encima de ella y gana en el servidor.
//
//  «Lo más adelantado que el servidor deja guardar» se modela con un HLC a `ahora + 50 s` (dentro del tope de 60 s). El
//  control de cada canal usa un HLC un día por delante —lo que el servidor guardaba antes del tope—: ahí el reloj no
//  integra y el cambio siguiente queda por DEBAJO, que es la divergencia del ticket.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

private let oneDay: TimeInterval = 86_400

/// Un HLC c1 a `offset` segundos de `base` (por defecto, ahora), de un nodo AJENO.
///
/// Dos HLC que solo deben diferir en el contador se construyen con la MISMA `base`: con `Date()` en cada llamada, la
/// segunda puede caer un milisegundo después y su física gana al contador. Así salía rojo en CI
/// `pure_sortsByHLC_notByCreatedAt_andMalformedLast`.
private func remoteHLC(offset: TimeInterval, counter: UInt16 = 0, node: String = "00000000000000aa",
                       base: Date = Date()) throws -> HLC {
    try HLC(physicalMs: CanonicalTime.physicalMillis(from: base.addingTimeInterval(offset)),
            counter: counter, nodeID: NodeID(validating: node))
}

// MARK: - HLCClock.observePulled

@Suite("HLC · integrar lo que baja del servidor")
struct HLCObservePulledTests {

    /// Un remoto dentro de la guarda se integra: el reloj queda por encima de él.
    @Test func remoteWithinTheGuard_isIntegrated() throws {
        var clock = HLCClock(nodeID: NodeID.generate())
        let remote = try remoteHLC(offset: 50)
        #expect(clock.observePulled(remote, now: .now) == .integrated)
        #expect(try #require(clock.latest) > remote)
    }

    /// El reloj PROPIO va un día por delante y el remoto no lo supera: no hay nada que integrar, y no es un rechazo (ese
    /// era el canario que ensuciaba todo el adelanto). El reloj no se mueve.
    @Test func ownClockAhead_remoteBelowIt_isAlreadyAhead_andTheClockStays() throws {
        let ahead = try HLC(physicalMs: CanonicalTime.physicalMillis(from: Date().addingTimeInterval(oneDay)),
                            counter: 3, nodeID: NodeID.generate())
        var clock = HLCClock(nodeID: ahead.nodeID, latest: ahead)
        #expect(clock.observePulled(try remoteHLC(offset: 0), now: .now) == .alreadyAhead)
        #expect(clock.latest == ahead)
    }

    /// Un remoto un día por delante, con el reloj propio en hora: no se integra y SÍ es un rechazo (el canario se queda
    /// para esto). El reloj no se mueve.
    @Test func remoteFarAhead_isRejected_andTheClockStays() throws {
        var clock = HLCClock(nodeID: NodeID.generate())
        let outcome = clock.observePulled(try remoteHLC(offset: oneDay), now: .now)
        guard case .rejected = outcome else {
            Issue.record("un remoto un día por delante tenía que rechazarse: \(outcome)")
            return
        }
        #expect(clock.latest == nil)
    }

    /// El remoto IGUAL al reloj propio adelantado (la fila que este mismo teléfono subió y vuelve a bajar sin acotar, de un
    /// servidor sin el tope): no hay nada que integrar. Fija la igualdad de `remote <= latest`; con `<` saldría rechazo.
    @Test func ownClockAhead_remoteEqualToIt_isAlreadyAhead() throws {
        let ahead = try HLC(physicalMs: CanonicalTime.physicalMillis(from: Date().addingTimeInterval(oneDay)),
                            counter: 2, nodeID: NodeID.generate())
        var clock = HLCClock(nodeID: ahead.nodeID, latest: ahead)
        #expect(clock.observePulled(ahead, now: .now) == .alreadyAhead)
        #expect(clock.latest == ahead)
    }

    /// Los dos adelantados y el remoto POR ENCIMA del propio: es un remoto adelantado de verdad, no deriva propia. Fija el
    /// orden de la comparación (`remote <= latest`), que es lo único que separa los dos casos.
    @Test func bothAhead_remoteAboveTheOwnClock_isRejected_notAlreadyAhead() throws {
        let ahead = try HLC(physicalMs: CanonicalTime.physicalMillis(from: Date().addingTimeInterval(oneDay)),
                            counter: 0, nodeID: NodeID.generate())
        var clock = HLCClock(nodeID: ahead.nodeID, latest: ahead)
        let outcome = clock.observePulled(try remoteHLC(offset: 2 * oneDay), now: .now)
        guard case .rejected = outcome else {
            Issue.record("un remoto por encima del reloj propio adelantado es un rechazo: \(outcome)")
            return
        }
        #expect(clock.latest == ahead)
    }
}

// MARK: - Canal personal (el otro dispositivo)

@Suite("Canal personal · el otro dispositivo integra la fila del adelantado y su edición gana", .serialized)
@MainActor
struct PersonalPullIntegratesTheCappedClockTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCCap-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PCCap-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PCCap-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PCCap-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// B baja la etiqueta que A escribió con `remote`, la renombra y drena. Devuelve el HLC con que sale la edición de B.
    private func pullThenEdit(remote: HLC) throws -> HLC {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let tagID = UUID()
        let page = PulledPage(deltas: [PulledDelta(
            entityType: "tags", syncID: tagID, op: .upsert,
            fields: ["name": .string("Viaje"), "color_hex": .string("#FF0000"), "icon_name": .string("tag"),
                     "is_active": .bool(true)],
            fieldHlcs: ["name": remote.description, "color_hex": remote.description,
                        "icon_name": remote.description, "is_active": remote.description],
            hlc: remote.description, serverSeq: 7, schemaVersion: 1, rawDelta: "{}")], maxServerSeq: 7)
        #expect(engine.applyPage(page, context: context, now: .now), "control: la página se aplicó")

        let tag = try #require(try context.fetch(FetchDescriptor<Yala.Tag>()).first { $0.id == tagID })
        #expect(tag.name == "Viaje", "control: B ve el valor de A")
        tag.name = "Viaje a Cusco"
        try context.save()
        #expect(engine.drainOnce(context: context))

        let row = try #require(try context.fetch(FetchDescriptor<SyncOutbox>()).first { $0.syncID == tagID })
        return try HLC.parse(row.hlc)
    }

    /// **El caso del ticket, cerrado.** Lo más adelantado que el servidor deja guardar (≤ `now() + 60 s`) se integra al
    /// bajar, así que la edición que B hace DESPUÉS de verlo sale por encima: gana en el servidor y B no se queda
    /// divergente.
    @Test func otherDevice_editAfterSeeingTheCappedRow_isStampedAboveIt() throws {
        let remote = try remoteHLC(offset: 50)
        #expect(try pullThenEdit(remote: remote) > remote)
    }

    /// **Control: sin el tope del servidor.** Con la fila guardada un día por delante el reloj de B no la integra (deriva)
    /// y su edición sale por DEBAJO: el servidor la da por perdida (`all_units_stale`), B purga y sigue mostrando su valor.
    /// Es por qué la mitad del servidor hace falta: el cliente solo no lo cierra.
    @Test func control_withoutTheCap_theEditAfterSeeingTheRowIsStampedBelowIt() throws {
        let remote = try remoteHLC(offset: oneDay)
        #expect(try pullThenEdit(remote: remote) < remote)
    }
}

// MARK: - Orden de subida

/// Con el reloj más de un minuto adelantado, el servidor solo conserva el orden propio si los cambios LLEGAN en orden de
/// HLC: decide con el HLC sin acotar y guarda el acotado, así que un cambio viejo que llegue después del nuevo le gana.
/// El caso del ticket: un cambio drenado con la hora adelantada (`createdAt` de mañana) y otro drenado cuando la hora
/// volvió (`createdAt` de hoy, HLC mayor). Por `createdAt` subía primero el nuevo.
@Suite("Orden de subida · por HLC, no por la hora de drenado", .serialized)
@MainActor
struct UploadOrderTests {

    /// Un único instante por prueba. «Viejo» y «nuevo» comparten la física (un día por delante de `now`) y solo difieren
    /// en el contador, que es lo que fija el orden por HLC. Leer el reloj en cada fila hacía que el orden esperado
    /// dependiera de la velocidad de la máquina.
    private let now = Date()
    private var tomorrow: Date { now.addingTimeInterval(oneDay) }

    private func hlcString(_ offset: TimeInterval, _ counter: UInt16) throws -> String {
        try remoteHLC(offset: offset, counter: counter, node: "00000000000000aa", base: now).description
    }

    @Test func pure_sortsByHLC_notByCreatedAt_andMalformedLast() throws {
        struct Row { let id: String; let hlc: String; let createdAt: Date }
        let rows = [
            Row(id: "nuevo", hlc: try hlcString(oneDay, 1), createdAt: now),
            Row(id: "malformado-b", hlc: "zz", createdAt: now.addingTimeInterval(5)),
            Row(id: "viejo", hlc: try hlcString(oneDay, 0), createdAt: tomorrow),
            Row(id: "malformado-a", hlc: "", createdAt: now.addingTimeInterval(1)),
        ]
        let ordered = HLC.uploadOrder(rows, hlc: \.hlc, createdAt: \.createdAt).map(\.id)
        #expect(ordered == ["viejo", "nuevo", "malformado-a", "malformado-b"])
    }

    /// Captura el cuerpo de cada subida y responde 200 sin resultados (nada se purga).
    private final class CapturingSession: SyncHTTPSession, @unchecked Sendable {
        var bodies: [[String: Any]] = []
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            if let body = request.httpBody,
               let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] { bodies.append(json) }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"results":[]}"#.utf8), response)
        }
        var uploadedHLCs: [String] {
            bodies.flatMap { ($0["deltas"] as? [[String: Any]] ?? []).compactMap { $0["hlc"] as? String } }
        }
    }

    /// Canal personal: `SyncPushClient.push` sube en orden de HLC aunque le lleguen las filas al revés.
    @Test func personalPush_uploadsInHLCOrder() async throws {
        let session = CapturingSession()
        let client = SyncPushClient(tokenProvider: { "jwt" }, urlSession: session)
        let tag = UUID()
        let viejo = try hlcString(oneDay, 0), nuevo = try hlcString(oneDay, 1)
        let rows = [
            SyncOutbox(syncID: tag, entityType: SyncEntityType.tag, op: .upsert, hlc: nuevo,
                       fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "", createdAt: now),
            SyncOutbox(syncID: tag, entityType: SyncEntityType.tag, op: .upsert, hlc: viejo,
                       fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "", createdAt: tomorrow),
        ]
        _ = await client.push(rows)
        #expect(session.uploadedHLCs == [viejo, nuevo])
    }

    /// Grupos: `pushPending` leía el outbox por `createdAt`; ahora sube en orden de HLC.
    @Test func groupsPush_uploadsInHLCOrder_notInDrainOrder() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UploadOrder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations:
                ModelConfiguration("UO-Personal", schema: SwiftDataConfiguration.personalSchema,
                                   url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none),
                ModelConfiguration("UO-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                   url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none),
                ModelConfiguration("UO-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
                                   url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none))
        let context = ModelContext(container)
        let share = UUID()
        let viejo = try hlcString(oneDay, 0), nuevo = try hlcString(oneDay, 1)
        // Insertadas en el orden de drenado: el viejo, drenado con la hora adelantada, lleva `createdAt` de mañana.
        context.insert(GroupSyncOutbox(syncID: share, groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitShare,
                                       op: .upsert, hlc: viejo, fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "",
                                       createdAt: tomorrow, ownerUserID: "sub-b"))
        context.insert(GroupSyncOutbox(syncID: share, groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitShare,
                                       op: .upsert, hlc: nuevo, fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "",
                                       createdAt: now, ownerUserID: "sub-b"))
        try context.save()

        let session = CapturingSession()
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: session, sessionCheck: { true },
            currentUserIDProvider: { "sub-b" },
            signInLogProvider: { SessionSignInLog(entries: [.init(sub: "sub-b", at: .distantPast)]) },
            outboxMirror: nil, forceRefreshTokenProvider: { nil }, canRenewSession: { true },
            onRemoteChangesApplied: {}, onRemoteChanges: { _ in })
        _ = await client.pushPending(context: context)
        #expect(session.uploadedHLCs == [viejo, nuevo])
    }
}

// MARK: - Grupos

@Suite("Grupos · el pull integra el HLC de lo que baja", .serialized)
@MainActor
struct GroupsPullIntegratesTheClockTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSCap-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSCap-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSCap-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSCap-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeClient() -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, sessionCheck: { true },
            currentUserIDProvider: { "sub-b" },
            signInLogProvider: { SessionSignInLog(entries: [.init(sub: "sub-b", at: .distantPast)]) },
            outboxMirror: nil, forceRefreshTokenProvider: { nil }, canRenewSession: { true },
            onRemoteChangesApplied: {}, onRemoteChanges: { _ in })
    }

    private func makeBackendGroup(_ context: ModelContext) throws {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = "SplitGroup-A"
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
    }

    /// Una cuota (no un gasto: el gasto puentea a lo personal y notifica, y aquí solo importa el reloj) que otro miembro
    /// escribió con `remote`.
    private func sharePage(id: UUID, remote: HLC) -> GroupPulledPage {
        GroupPulledPage(
            deltas: [GroupPulledDelta(
                entityType: GroupEntityEmissionMap.splitShare.table, groupID: "SplitGroup-A",
                rawSyncID: id.uuidString, syncID: id, op: .upsert,
                fields: ["expense_id": .string(UUID().uuidString), "member_key": .string("member-1"),
                         "amount": .number(10), "is_paid": .bool(false)],
                fieldHlcs: [:], hlc: remote.description, serverSeq: 4, schemaVersion: 1)],
            cursors: [:], memberships: nil)
    }

    /// B (con el reloj persistido a `nil`: lo que deja un cierre de sesión) baja la cuota, la edita y drena. Devuelve el
    /// HLC con que sale su edición.
    private func pullThenEdit(remote: HLC) throws -> HLC {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()
        try makeBackendGroup(context)
        let cursor = try client.loadOrCreateCursor(context)
        #expect(cursor.clockLatestHLC == nil, "control: el reloj persistido arranca borrado")

        let shareID = UUID()
        #expect(client.applyPulledPage(sharePage(id: shareID, remote: remote), cursor: cursor, context: context))
        let share = try #require(try context.fetch(FetchDescriptor<SplitShare>()).first { $0.id == shareID })
        share.isPaid = true
        try context.save()
        #expect(client.drainOnce(context: context))

        let type = GroupSyncEntityType.splitShare
        let row = try #require(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).first {
            $0.entityType == type && $0.rejectedReason == nil
        })
        return try HLC.parse(row.hlc)
    }

    /// **Criterio del ticket de Grupos.** Con el reloj persistido borrado tras un cierre de sesión, una edición de una fila
    /// sellada por delante (lo más que el tope deja: `now() + 60 s`) sale POR ENCIMA de ella: no se pierde en silencio.
    @Test func afterSignOutClearedTheClock_editOfARowSealedAhead_isStampedAboveIt() throws {
        let remote = try remoteHLC(offset: 50)
        #expect(try pullThenEdit(remote: remote) > remote)
    }

    /// **Control: sin el tope del servidor** la fila un día por delante no se integra (deriva) y la edición sale por debajo:
    /// `all_units_stale` en el servidor. El pull aplica la fila igual —eso no cambia—.
    @Test func control_withoutTheCap_theEditIsStampedBelowTheRow() throws {
        let remote = try remoteHLC(offset: oneDay)
        #expect(try pullThenEdit(remote: remote) < remote)
    }

    /// **El pull no baja un reloj adelantado.** Con el reloj persistido un día por delante y un cliente recién creado (sin
    /// drain previo en este proceso), la página escribe `clockLatestHLC` al guardar: tiene que seguir siendo el adelantado.
    /// Sin `adoptPersistedClockIfAhead` integraría el remoto sobre un reloj fresco y lo pisaría con uno más bajo, y el
    /// teléfono perdería el orden de sus propios cambios.
    @Test func pull_withAPersistedClockAhead_doesNotLowerIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()
        try makeBackendGroup(context)
        let cursor = try client.loadOrCreateCursor(context)
        let ahead = try HLC(physicalMs: CanonicalTime.physicalMillis(from: Date().addingTimeInterval(oneDay)),
                            counter: 0, nodeID: NodeID.generate())
        cursor.clockLatestHLC = ahead.description
        try context.save()

        #expect(client.applyPulledPage(sharePage(id: UUID(), remote: try remoteHLC(offset: 0)),
                                       cursor: cursor, context: context))
        let persisted = try HLC.parse(try #require(try client.loadOrCreateCursor(context).clockLatestHLC))
        #expect(persisted >= ahead)
    }
}

// MARK: - Preferencias

@Suite("Preferencias · el pull integra el HLC en el reloj del outbox")
struct PrefsPullIntegratesTheClockTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrefsCap-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func stampOfNextChange(_ outbox: PrefsOutbox) throws -> HLC {
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Bea"))
        let entry = try #require(outbox.entries(forUserID: "u1").first { $0.key == "userName" })
        return try HLC.parse(entry.entry.hlc)
    }

    /// **La divergencia de las preferencias, cerrada.** B ve la preferencia que A cambió (guardada a lo sumo en
    /// `now() + 60 s`) y la cambia después: su cambio sale por encima y gana en el servidor.
    @Test func changeAfterSeeingTheCappedPref_isStampedAboveIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        let remote = try remoteHLC(offset: 50)
        let rejected = try outbox.recordPull(newCursor: 5, pulledHLCs: [remote.description])
        #expect(rejected.isEmpty)
        #expect(outbox.pullCursor == 5, "el cursor avanza en la misma escritura")
        #expect(try stampOfNextChange(outbox) > remote)
    }

    /// **Control: sin integrar** (lo de antes: el pull no tocaba el reloj) el cambio siguiente sale por debajo de la
    /// preferencia que B acaba de ver.
    @Test func control_withoutIntegrating_theChangeIsStampedBelowIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        let remote = try remoteHLC(offset: 50)
        try outbox.recordPull(newCursor: 5, pulledHLCs: [])
        #expect(try stampOfNextChange(outbox) < remote)
    }

    /// Un remoto un día por delante (sin el tope) no se integra: se devuelve su motivo para el rastro y el reloj no salta
    /// un día.
    @Test func remoteFarAhead_isReported_andTheClockDoesNotJump() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        let remote = try remoteHLC(offset: oneDay)
        let rejected = try outbox.recordPull(newCursor: nil, pulledHLCs: [remote.description])
        #expect(rejected.count == 1)
        #expect(try stampOfNextChange(outbox) < remote)
    }

    /// Con el reloj propio adelantado (una preferencia cambiada con la hora puesta por delante), lo que baja no lo supera:
    /// ni se reporta como rechazo ni mueve el reloj, y el cambio siguiente sigue ordenado después del propio.
    @Test func ownClockAhead_isNotReported_andKeepsTheOwnOrder() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Ana"), now: Date().addingTimeInterval(oneDay))
        let own = try HLC.parse(try #require(outbox.entries(forUserID: "u1").first).entry.hlc)

        let rejected = try outbox.recordPull(newCursor: nil, pulledHLCs: [try remoteHLC(offset: 0).description])
        #expect(rejected.isEmpty)
        #expect(try stampOfNextChange(outbox) > own)
    }

    /// Sin cursor nuevo y sin nada que integrar no escribe: el ciclo de prefs no reescribe el archivo en cada vuelta vacía.
    @Test func nothingToRecord_writesNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.recordPull(newCursor: nil, pulledHLCs: [])
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(PrefsOutbox.fileName).path))
    }
}

// MARK: - Cableado del pull de prefs (source-scan)

/// `CloudSyncRuntime.syncPrefsOnce` cierra el pull con `PrefsOutbox.recordPull` y le pasa los HLC de la página. Se fija por
/// source-scan y no con un ciclo del runtime: bajar una preferencia hace correr `PreferenceSyncService.applyPulledPrefs`,
/// que copia `expensesOnlyMode` y `defaultPeriod` del `UserDefaults` del simulador a `SessionState.shared` aunque la key
/// sea desconocida, y eso contaminó `StatisticsRecalculationTests` en la suite completa (medido el 2026-10-07). El
/// comportamiento de `recordPull` lo cubre `PrefsPullIntegratesTheClockTests`.
@Suite("Preferencias · syncPrefsOnce integra los HLC del pull (source-scan)")
struct PrefsPullWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    @Test func syncPrefsOnce_closesThePullWithRecordPull_passingThePulledHLCs() throws {
        let body = try Self.body(of: "private func syncPrefsOnce(epoch: Int) async {",
                                 in: Self.source("Yala/Services/CloudSync/CloudSyncRuntime.swift"))
        let squashed = body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(squashed.contains("try prefsOutbox.recordPull( newCursor: page.maxServerSeq > since ? page.maxServerSeq : nil, pulledHLCs: page.prefs.map(\\.hlc) )"),
                "el pull tiene que pasar los HLC de la página a recordPull")
        #expect(!squashed.contains("setPullCursor"), "setPullCursor no integra el reloj")
        // Después de aplicar la página, no antes: el orden de siempre (aplicar, luego cerrar el cursor).
        let apply = try #require(squashed.range(of: "PreferenceSyncService.shared.applyPulledPrefs(page.prefs)"))
        let record = try #require(squashed.range(of: "prefsOutbox.recordPull("))
        #expect(apply.upperBound <= record.lowerBound)
    }
}

