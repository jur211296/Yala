//
//  AccountLineSyncTests.swift
//  YalaTests / CloudSync
//
//  Tarjeta con varias divisas, entrega 1, por el Modo Nube: la columna `accounts.parent_account_id` y el gate
//  por versión del manifest (`SyncCapability`). Lo que fija:
//   - el teléfono declara la menor versión entre la suya (2) y la que anuncia el Worker; un Worker que no anuncia
//     es 1;
//   - con `v1` la columna ni se emite ni se hashea (un Worker viejo rechazaría la fila entera y el Merkle
//     divergiría); con `v2`, sí;
//   - ida y vuelta: lo que un teléfono emite, otro lo aplica con el enlace intacto, aunque la principal no
//     haya llegado;
//   - un teléfono sin el applier de la columna (2.1) la ignora y sus saldos no cambian;
//   - dos líneas (tarjeta, divisa) que bajan de dos teléfonos acaban en una tras el pull, y el desvínculo sube;
//   - al subir a `v2`, los enlaces que se crearon en `v1` se reemiten.
//
//  Container ON-DISK temp con los 3 stores + `.serialized` (patrón `CloudSyncWiredEntitiesTests`).
//  `SyncCapability.defaults` se aísla en cada caso y se restaura en `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · tarjeta con varias divisas (parent_account_id + SyncCapability)", .serialized)
@MainActor
struct AccountLineSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccLine-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "AL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "AL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "AL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Aísla `SyncCapability` en un `UserDefaults` propio y, si se pide, con el backend en `level`. Devuelve la
    /// restauración, para un `defer` (un cierre `rethrows` alrededor del cuerpo tumba al compilador con los
    /// `filter` que capturan dentro).
    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite) ?? previous
        SyncCapability.defaults = isolated
        if let level { isolated.set(level, forKey: SyncCapability.backendManifestVersionKey) }
        return {
            isolated.removePersistentDomain(forName: suite)
            SyncCapability.defaults = previous
        }
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private func account(_ context: ModelContext, _ name: String, _ currency: String, id: UUID? = nil) -> Account {
        let a = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard", type: "creditCard")
        if let id { a.shortcutID = id }
        context.insert(a)
        return a
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    private func accountFieldsJSON(_ name: String, _ currency: String, parent: UUID?) -> String {
        let parentJSON = parent.map { "\"\($0.uuidString.lowercased())\"" } ?? "null"
        return """
        {"name":"\(name)","currency_code":"\(currency)","color_hex":"#6366F1","icon_name":"creditcard",\
        "type":"creditCard","account_number":null,"adjustment_mode":"manual","exclude_from_statistics":false,\
        "is_archived":false,"is_system_account":false,"credit_card_payment_reminder":false,\
        "credit_card_payment_day":5,"parent_account_id":\(parentJSON)}
        """
    }

    private func accountDelta(_ sid: UUID, fields: String, seq: Int) -> String {
        let h = hlc(seq)
        return """
        {"entity_type":"accounts","sync_id":"\(sid.uuidString.lowercased())","op":"upsert","fields":\(fields),\
        "field_hlcs":{"name":"\(h)","currency_code":"\(h)","type":"\(h)","parent_account_id":"\(h)"},\
        "hlc":"\(h)","server_seq":\(seq),"schema_version":1}
        """
    }

    private func page(_ deltas: [String], maxSeq: Int, manifestVersion: Int? = 2) -> PulledPage? {
        let mv = manifestVersion.map { ",\"manifest_version\":\($0)" } ?? ""
        let json = "{\"deltas\":[\(deltas.joined(separator: ","))],\"max_server_seq\":\(maxSeq)\(mv)}"
        do { return try SyncPullClient.decodePage(Data(json.utf8)) } catch {
            Issue.record("la página no decodifica: \(error)"); return nil
        }
    }

    // MARK: - SyncCapability

    @Test func capability_withoutAnnouncement_isV1() {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        #expect(SyncCapability.declaredLevel == 1)
        #expect(SyncCapability.declaredHeader == "v1")
        #expect(SyncPullClient.capabilitySet == "v1")
        SyncCapability.recordBackendManifestVersion(nil)
        #expect(SyncCapability.declaredLevel == 1)
        #expect(!SyncCapability.upgradePending)
    }

    @Test func capability_backendAnnouncesV2_upgrades_andAsksForTheUpgrade() {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        SyncCapability.recordBackendManifestVersion(2)
        #expect(SyncCapability.declaredLevel == 2)
        #expect(SyncPullClient.capabilitySet == "v2")
        #expect(SyncCapability.upgradePending)
        // Solo en la TRANSICIÓN: anunciar otra vez la misma versión no la vuelve a pedir.
        SyncCapability.upgradePending = false
        SyncCapability.recordBackendManifestVersion(2)
        #expect(!SyncCapability.upgradePending)
    }

    @Test func capability_isCappedByWhatThisBuildUnderstands() {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        SyncCapability.recordBackendManifestVersion(7)
        #expect(SyncCapability.declaredLevel == SyncCapability.clientManifestVersion)
        #expect(SyncCapability.declaredLevel == 2)
    }

    @Test func capability_workerRolledBack_goesBackToV1() {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        #expect(SyncCapability.declaredLevel == 2)
        SyncCapability.recordBackendManifestVersion(nil)
        #expect(SyncCapability.declaredLevel == 1)
    }

    @Test func pullClient_recordsWhatTheWorkerAnnounces() async {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        let session = HeaderCapturingSession(body: Data(#"{"deltas":[],"max_server_seq":0,"manifest_version":2}"#.utf8))
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        _ = await client.pull(since: 0)
        #expect(session.capabilityHeaders == ["v1"], "la primera petición sale con lo que se sabía")
        #expect(SyncCapability.declaredLevel == 2)
        _ = await client.pull(since: 0)
        #expect(session.capabilityHeaders == ["v1", "v2"])
    }

    // MARK: - Paridad con el manifest

    @Test func sinceOfEachColumn_matchesTheManifest_andTheClientSpeaksTheManifestVersion() throws {
        struct Manifest: Decodable {
            struct Column: Decodable { let since: Int? }
            struct Entity: Decodable { let columns: [String: Column] }
            let manifest_version: Int
            let entities: [String: Entity]
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: root.appendingPathComponent("capability_manifest.json")))
        var fromManifest: [String: [String: Int]] = [:]
        for (table, entity) in manifest.entities {
            for (column, spec) in entity.columns where (spec.since ?? 1) > 1 {
                fromManifest[table, default: [:]][column] = spec.since
            }
        }
        #expect(fromManifest == EntityEmissionMap.sinceCatalog)
        #expect(fromManifest == ["accounts": ["parent_account_id": 2]], "control: el test lee algo")
        #expect(manifest.manifest_version == SyncCapability.clientManifestVersion,
                "subir el manifest sin subir lo que entiende el cliente (o al revés) deja una columna sin gate")
    }

    // MARK: - Emisión y hoja del Merkle

    @Test func emission_v2_carriesTheLink_v1_doesNot() throws {
        let dir = freshDir()
        let context = try makeContext(dir)
        let principal = account(context, "Visa", "PEN")
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = principal.shortcutID
        let emission = EntityEmissionMap.account

        let v2 = DeltaEmitter.emit(model: line, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 2)
        #expect(v2.fields["parent_account_id"] == .uuid(principal.shortcutID))
        #expect(v2.fieldHlcs["parent_account_id"] == hlc(1))

        let v1 = DeltaEmitter.emit(model: line, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 1)
        #expect(v1.fields["parent_account_id"] == nil)
        #expect(v1.fieldHlcs["parent_account_id"] == nil)
        #expect(v1.fields["name"] == .string("Visa USD"), "el resto de la fila sí viaja")

        let onlyLink = DeltaEmitter.emit(model: line, emission: emission, changedColumns: ["parent_account_id"],
                                         hlc: hlc(1), capabilityLevel: 1)
        #expect(onlyLink.fields.isEmpty && onlyLink.fieldHlcs.isEmpty)
    }

    @Test func merklePayload_v1_isTheOldOne_v2_hashesTheLink() throws {
        let dir = freshDir()
        let context = try makeContext(dir)
        let loose = account(context, "Efectivo", "PEN")
        let emission = EntityEmissionMap.account

        let v1 = try SyncMerkle.channel1Payload(model: loose, emission: emission, capabilityLevel: 1)
        #expect(!v1.contains("parent_account_id"), "con v1 la hoja es la de un teléfono 2.1")
        let v2 = try SyncMerkle.channel1Payload(model: loose, emission: emission, capabilityLevel: 2)
        #expect(v2.contains("\"parent_account_id\":null"), "con v2 el servidor serializa el NULL como key:null")

        loose.parentAccountID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")
        let linked = try SyncMerkle.channel1Payload(model: loose, emission: emission, capabilityLevel: 2)
        #expect(linked.contains("\"parent_account_id\":\"11111111-2222-4333-8444-555555555555\""))
    }

    // MARK: - Drain

    @Test func drain_v1_neverSendsTheColumn_andALinkOnlyEditEmitsNothing() throws {
        let restoreCapability = isolateCapability(backend: 1)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let principal = account(context, "Visa", "PEN")
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = principal.shortcutID
        try context.save()
        engine.drainOnce(context: context)

        let inserts = try outbox(context).filter { $0.entityType == SyncEntityType.account }
        #expect(inserts.count == 2)
        for row in inserts { #expect(try fields(row)["parent_account_id"] == nil) }
        #expect(SyncCapability.suppressedAccountLinks == [line.shortcutID],
                "el alta CON enlace queda apuntada; la principal, sin enlace, no (nace NULL en el servidor)")

        let other = account(context, "Efectivo", "USD")
        try context.save()
        engine.drainOnce(context: context)
        other.parentAccountID = principal.shortcutID
        try context.save()
        engine.drainOnce(context: context)
        line.parentAccountID = nil
        try context.save()
        engine.drainOnce(context: context)
        #expect(try outbox(context).filter { $0.entityType == SyncEntityType.account }.count == 3,
                "cambiar solo el enlace con v1 no saca ninguna fila: el Worker no conoce la columna")
        #expect(SyncCapability.suppressedAccountLinks == [line.shortcutID, other.shortcutID],
                "vincular y DESVINCULAR en v1 quedan apuntados para subirlos al pasar a v2")
    }

    @Test func drain_v2_sendsTheLink_onInsertAndOnALinkOnlyEdit() throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let principal = account(context, "Visa", "PEN")
        let line = account(context, "Visa USD", "USD")
        line.parentAccountID = principal.shortcutID
        try context.save()
        engine.drainOnce(context: context)

        let lineID = line.shortcutID
        let afterInsert = try outbox(context)
        let insert = try #require(afterInsert.first { $0.syncID == lineID })
        #expect(try fields(insert)["parent_account_id"] as? String == principal.shortcutID.uuidString.lowercased())

        line.parentAccountID = nil
        try context.save()
        engine.drainOnce(context: context)
        let afterEdit = try outbox(context)
        let rows = afterEdit.filter { $0.syncID == lineID }
        #expect(rows.count == 2)
        let update = try #require(rows.last)
        let updateFields = try fields(update)
        #expect(Set(updateFields.keys) == ["parent_account_id"])
        #expect(updateFields["parent_account_id"] is NSNull, "desvincular viaja como NULL explícito")
    }

    // MARK: - Ida y vuelta

    @Test func roundTrip_lineEmittedOnOnePhone_keepsItsLinkOnTheOther() throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dirA = freshDir()
        let phoneA = try makeContext(dirA)
        let principal = account(phoneA, "Visa", "PEN")
        let line = account(phoneA, "Visa USD", "USD")
        line.parentAccountID = principal.shortcutID
        try phoneA.save()
        let emission = EntityEmissionMap.account
        let emitted = DeltaEmitter.emit(model: line, emission: emission, changedColumns: emission.columns, hlc: hlc(2))
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))

        // Teléfono B: la línea llega ANTES que su principal.
        let dirB = freshDir()
        let phoneB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let linePage = try #require(page([accountDelta(line.shortcutID, fields: fieldsJSON, seq: 2)], maxSeq: 2))
        #expect(engineB.applyPage(linePage, context: phoneB, now: applyNow))
        let lineID = line.shortcutID
        let accountsB = try phoneB.fetch(FetchDescriptor<Account>())
        let arrived = try #require(accountsB.first { $0.shortcutID == lineID })
        #expect(arrived.parentAccountID == principal.shortcutID, "el UUID se guarda aunque la principal no esté")
        var roles = AccountLineLogic.resolve(try phoneB.fetch(FetchDescriptor<Account>()).map(AccountLineNode.init))
        #expect(roles[line.shortcutID] == .brokenLine(.orphan), "mientras tanto, cuenta suelta")

        let principalPage = try #require(page([accountDelta(principal.shortcutID,
            fields: accountFieldsJSON("Visa", "PEN", parent: nil), seq: 3)], maxSeq: 3))
        #expect(engineB.applyPage(principalPage, context: phoneB, now: applyNow))
        roles = AccountLineLogic.resolve(try phoneB.fetch(FetchDescriptor<Account>()).map(AccountLineNode.init))
        #expect(roles[line.shortcutID] == .line(principalID: principal.shortcutID))
        #expect(roles[principal.shortcutID] == .principal(lineIDs: [line.shortcutID]))
    }

    @Test func oldPhone_withoutTheColumnsApplier_ignoresIt_andKeepsItsBalances() throws {
        // Un 2.1 no tiene applier de `parent_account_id`. El apply salta toda columna sin applier
        // (`SyncApplyEngine`, `guard let applier`), así que se prueba con una columna que ESTE build tampoco conoce.
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()
        let category = YalaCategory(name: "Comida", colorHex: "#EF4444", isIncome: false)
        context.insert(category)
        let local = account(context, "Visa USD", "USD", id: sid)
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -42.5, currencyCode: "USD",
                                 note: "cena", category: category, account: local)
        context.insert(tx)
        try context.save()

        let fieldsJSON = """
        {"name":"Visa dólares","currency_code":"USD","zz_column_from_the_future":"\(UUID().uuidString.lowercased())"}
        """
        let h = hlc(9)
        let delta = """
        {"entity_type":"accounts","sync_id":"\(sid.uuidString.lowercased())","op":"upsert","fields":\(fieldsJSON),\
        "field_hlcs":{"name":"\(h)","currency_code":"\(h)","zz_column_from_the_future":"\(h)"},\
        "hlc":"\(h)","server_seq":9,"schema_version":1}
        """
        let p = try #require(page([delta], maxSeq: 9))
        #expect(engine.applyPage(p, context: context, now: applyNow))

        #expect(local.name == "Visa dólares", "lo que conoce, lo aplica")
        let txs = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(txs.count == 1)
        #expect(txs.first?.amount == -42.5)
        #expect(txs.first?.account?.shortcutID == sid)
        #expect(try context.fetch(FetchDescriptor<SyncQuarantine>()).isEmpty, "no la aparta: solo la ignora")
    }

    // MARK: - Dos teléfonos, misma línea, tras el pull

    @Test func postPull_twoLinesFromTwoPhones_readAsOne_withoutWritingAnything() throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let principal = account(context, "Visa", "PEN")
        try context.save()
        engine.drainOnce(context: context)
        let before = try outbox(context).count

        let low = UUID(uuidString: "20000000-0000-4000-8000-00000000000A")!
        let high = UUID(uuidString: "90000000-0000-4000-8000-00000000000B")!
        let p = try #require(page([
            accountDelta(high, fields: accountFieldsJSON("Visa dólares", "USD", parent: principal.shortcutID), seq: 4),
            accountDelta(low, fields: accountFieldsJSON("Visa USD", "USD", parent: principal.shortcutID), seq: 5),
        ], maxSeq: 5))
        #expect(engine.applyPage(p, context: context, now: applyNow))
        engine.runPostPullReconcilers(context: context)
        engine.drainOnce(context: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        #expect(roles[low] == .line(principalID: principal.shortcutID), "el menor shortcutID tiene la ranura")
        #expect(roles[high] == .brokenLine(.duplicateCurrency(keptLineID: low)), "la otra se lee suelta")
        #expect(accounts.first { $0.shortcutID == high }?.parentAccountID == principal.shortcutID,
                "no se desvincula: la deduplicación es de lectura y no viaja")
        #expect(try outbox(context).count == before, "nada que subir")
    }

    // MARK: - La subida de versión dentro del bucle del pull

    @Test func pull_upgrade_suppressedLinksGoFirst_thenEverythingIsRepulledInV2() async throws {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // Este teléfono vinculó `mine` hablando v1: no subió y quedó apuntado.
        let principal = account(context, "Visa", "PEN")
        let mine = account(context, "Visa USD", "USD")
        mine.parentAccountID = principal.shortcutID
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }  // ya subió (sin la columna)
        try context.save()
        #expect(SyncCapability.suppressedAccountLinks == [mine.shortcutID])

        // Otro teléfono vinculó `theirs`. La 1.ª respuesta (pedida en v1) la trae SIN la columna y anuncia v2; la
        // 2.ª (pedida en v2, desde 0) la trae con el enlace.
        let theirs = UUID()
        let v1Fields = """
        {"name":"Visa EUR","currency_code":"EUR","color_hex":"#6366F1","icon_name":"creditcard","type":"creditCard",\
        "account_number":null,"adjustment_mode":"manual","exclude_from_statistics":false,"is_archived":false,\
        "is_system_account":false,"credit_card_payment_reminder":false,"credit_card_payment_day":5}
        """
        let first = "{\"deltas\":[\(accountDelta(theirs, fields: v1Fields, seq: 7))],\"max_server_seq\":7,\"manifest_version\":2}"
        let second = "{\"deltas\":[\(accountDelta(theirs, fields: accountFieldsJSON("Visa EUR", "EUR", parent: principal.shortcutID), seq: 7))],\"max_server_seq\":7,\"manifest_version\":2}"
        let empty = "{\"deltas\":[],\"max_server_seq\":7,\"manifest_version\":2}"
        let session = HeaderCapturingSession(bodies: [first, second, empty].map { Data($0.utf8) })
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)

        let outcome = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(outcome == .completed(pagesApplied: 2), "la página que anunció la subida no termina el pull")
        #expect(session.capabilityHeaders == ["v1", "v2"])
        #expect(session.sinceValues == ["0", "0"], "tras la página que anunció la subida, la re-bajada empezó en 0")
        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.first { $0.shortcutID == theirs }?.parentAccountID == principal.shortcutID,
                "el enlace del otro teléfono llega, aunque la primera página lo trajera sin la columna")
        #expect(mine.parentAccountID == principal.shortcutID, "el re-pull no pisa el enlace propio que estaba sin subir")
        let mineID = mine.shortcutID
        let rows = try outbox(context).filter { $0.syncID == mineID }
        let reemitted = try #require(rows.last)
        #expect(Set(try fields(reemitted).keys) == ["parent_account_id"], "solo la columna del enlace, no la fila")
        #expect(!SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedAccountLinks.isEmpty)
    }

    @Test func pull_upgradeAnnouncedOnAnEmptyPage_isCompletedInTheSamePull() async throws {
        let restoreCapability = isolateCapability(backend: nil)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // Un teléfono al día: su primera respuesta del Worker nuevo no trae filas, solo la versión.
        let session = HeaderCapturingSession(bodies: [Data(#"{"deltas":[],"max_server_seq":0,"manifest_version":2}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)
        #expect(session.capabilityHeaders == ["v1", "v2"], "no termina con la subida pendiente: la cumple y re-pide")
        #expect(!SyncCapability.upgradePending)
    }

    @Test func pull_upgradePendingButWorkerRolledBack_doesNotLoop_andWaits() async throws {
        let restoreCapability = isolateCapability(backend: 1)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // La subida se pidió y, antes de cumplirse, el Worker volvió atrás: el teléfono ya habla v1 otra vez.
        SyncCapability.upgradePending = true
        let session = HeaderCapturingSession(bodies: [Data(#"{"deltas":[],"max_server_seq":0}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        let outcome = await engine.pullAndApplyOnce(using: client, context: context)
        #expect(outcome == .completed(pagesApplied: 0))
        #expect(session.capabilityHeaders.count <= 2, "no gira: con v1 no hay subida que cumplir")
        #expect(SyncCapability.declaredLevel == 1)
        #expect(SyncCapability.upgradePending, "la petición espera a que el Worker vuelva a anunciar v2")
    }

    @Test func pull_upgrade_doesNotReemitALinkThatIsNotSuppressed() async throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let principal = account(context, "Visa", "PEN")
        let stale = account(context, "Visa USD", "USD")
        stale.parentAccountID = principal.shortcutID   // copia de lo que bajó: el servidor ya lo tiene
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }
        try context.save()
        SyncCapability.defaults.set(1, forKey: SyncCapability.backendManifestVersionKey)
        SyncCapability.recordBackendManifestVersion(2)   // un rollback del Worker y vuelta: hay subida pendiente
        #expect(SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedAccountLinks.isEmpty)

        let session = HeaderCapturingSession(bodies: [Data(#"{"deltas":[],"max_server_seq":0,"manifest_version":2}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(!SyncCapability.upgradePending)
        #expect(try outbox(context).isEmpty,
                "una cuenta con enlace que NO está apuntada no se reemite: subiría con HLC fresco una copia vieja")
    }

    // MARK: - Merkle contra un Worker que no anuncia

    @Test func merkle_v2AgainstAWorkerThatDoesNotAnnounce_skips_andFallsBackToV1() async throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true
        let session = HeaderCapturingSession(body: Data("""
        {"canon_version":"c1","capability_set":"v2","root":"r","entities":{},"channel2_root":"x"}
        """.utf8))
        let client = SyncMerkleClient(baseURL: URL(string: "https://example.test")!,
                                      tokenProvider: { "jwt" }, urlSession: session)
        let verdict = await engine.verifyIntegrity(using: client, context: context)
        #expect(session.capabilityHeaders == ["v2"])
        #expect(verdict == .skipped(reason: MerkleSkipReason.capabilitySetMismatch))
        #expect(SyncCapability.declaredLevel == 1, "el ciclo siguiente ya pide v1")
    }

    @Test func merkle_v2_hashesTheLocalTreeInV2_andConvergesWithAV2Server() async throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true
        _ = account(context, "Visa", "PEN")
        try context.save()

        // El servidor en v2 hashea `accounts` CON la columna. La hoja de v1 no la lleva: los dos árboles difieren.
        let v2 = try SyncMerkle.computeLocalMerkle(context: context, capabilityLevel: 2)
        let v1 = try SyncMerkle.computeLocalMerkle(context: context, capabilityLevel: 1)
        #expect(v2.entities["accounts"]?.hashHex != v1.entities["accounts"]?.hashHex)

        let entities = v2.entities.map { "\"\($0.key)\":{\"count\":\($0.value.count),\"hash\":\"\($0.value.hashHex)\"}" }
            .joined(separator: ",")
        let session = HeaderCapturingSession(body: Data("""
        {"canon_version":"c1","capability_set":"v2","manifest_version":2,"root":"\(v2.rootHex)","entities":{\(entities)},"channel2_root":"x"}
        """.utf8))
        let client = SyncMerkleClient(baseURL: URL(string: "https://example.test")!,
                                      tokenProvider: { "jwt" }, urlSession: session)
        let verdict = await engine.verifyIntegrity(using: client, context: context)
        #expect(session.capabilityHeaders == ["v2"])
        #expect(verdict == .converged, "pide v2 y hashea en v2: la cabecera y el árbol local van a la par")
    }
}

// MARK: - Stub

private final class HeaderCapturingSession: SyncHTTPSession, @unchecked Sendable {
    /// Respuestas en orden; la última se repite.
    let bodies: [Data]
    private(set) var capabilityHeaders: [String] = []
    private(set) var sinceValues: [String] = []
    init(body: Data) { self.bodies = [body] }
    init(bodies: [Data]) { self.bodies = bodies }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capabilityHeaders.append(request.value(forHTTPHeaderField: "X-Yala-Capability-Set") ?? "-")
        let since = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == "since" }?.value
        sinceValues.append(since ?? "-")
        let body = bodies[min(capabilityHeaders.count - 1, bodies.count - 1)]
        let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200,
                                       httpVersion: nil, headerFields: nil)
        return (body, response ?? URLResponse())
    }
}
