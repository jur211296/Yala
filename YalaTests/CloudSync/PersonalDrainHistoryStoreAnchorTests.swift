//
//  PersonalDrainHistoryStoreAnchorTests.swift
//  YalaTests / CloudSync
//
//  El ancla del high-water del drain PERSONAL: qué la mueve (el store) y qué no (el eco).
//
//  Gemelo de `GroupsDrainHistoryStoreAnchorTests` §«Device que solo RECIBE» para el canal personal del Modo
//  Nube. El drain descartaba el ECO (`tx.author == outboxSaveAuthor`) con un `continue` colocado ANTES del
//  avance, así que UNA línea decidía dos cosas distintas: «es mía, no la re-emitas» (que habla de TRADUCIR) y
//  «no es de mi store» (que habla de ANCLAR). En un device que solo RECIBE, lo único que escribe en su store
//  personal es `SyncApplyEngine.applyPage`, que persiste bajo ese mismo autor ⇒ `advancedToken` se quedaba
//  nil, NINGUNA de las tres ramas escribía el cursor y el fetch re-barría una ventana que CRECÍA una
//  transacción por página aplicada, indefinidamente y en silencio. Medido el 2026-08-02: `avanzo=false` en
//  las cuatro vueltas, token nunca escrito.
//
//  Y la razón por la que el fix de Grupos NO se pudo copiar tal cual: allí el ancla ya estaba acotada al
//  store, aquí no lo estaba, y sin acotarla el bucle que temía el comentario original SÍ existe. Eso lo fija
//  `anchorWithoutStoreGuard_wouldLandOnSyncMeta_andNeverConverge`, que es el test de contrato de este fichero.
//
//  Nota de método (heredada, y aplicada aquí): las páginas se materializan sobre `Account` y NO sobre
//  `TransactionItem`. Insertar una TX dispara el backfill asíncrono del CSV mirror (`Task { @MainActor in
//  save() }`), que salva bajo el autor por DEFECTO y mete una transacción EXTERNA en la ventana — con eso la
//  primera sonda medía `avanzo=true` y ocultaba el defecto. Elegir una entidad sin escrituras laterales es
//  parte del test, no un detalle.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Personal · ancla del History por-store (drain)", .serialized)
@MainActor
struct PersonalDrainHistoryStoreAnchorTests {

    // MARK: - Infra (molde de `SyncApplyEngineTests`: 3 stores, un `ModelContext` que los abarca)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PSAnchor-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PSA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PSA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PSA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }
    /// `now` inyectado al `receive` del reloj — posterior a las HLC (past remote → sin drift).
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)

    /// Página con UN upsert born-remote de `accounts` (la entidad SIN escrituras laterales — ver el header).
    private func accountPage(seq: Int) throws -> PulledPage {
        let sid = UUID().uuidString.lowercased()
        let h = hlc(seq)
        let json = #"""
        {"deltas":[{"entity_type":"accounts","sync_id":"\#(sid)","op":"upsert",
        "fields":{"name":"Cuenta \#(seq)","currency_code":"USD","color_hex":"#6366F1",
        "icon_name":"creditcard","type":"checking","adjustment_mode":"balance",
        "exclude_from_statistics":false,"is_archived":false,"is_system_account":false,
        "credit_card_payment_reminder":false,"credit_card_payment_day":1},
        "field_hlcs":{"identity":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(seq),"schema_version":1}],"max_server_seq":\#(seq)}
        """#
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    private func cursorRow(_ context: ModelContext) throws -> SyncCursor {
        try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
    }

    private func decodedToken(_ data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(DefaultHistoryToken.self, from: data)
    }

    private func history(_ context: ModelContext) throws -> [DefaultHistoryTransaction] {
        try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    }

    private func lastTransaction(
        touching entity: String, _ context: ModelContext
    ) throws -> DefaultHistoryTransaction {
        try #require(try history(context).last { tx in
            tx.changes.contains { $0.changedPersistentIdentifier.entityName == entity }
        })
    }

    /// Inserta un `Account` LOCAL bajo el autor por DEFECTO (lo que hace el usuario al crear una cuenta).
    @discardableResult
    private func addLocalAccount(_ context: ModelContext, name: String = "Local") throws -> Account {
        let account = Account(name: name, currencyCode: "USD", colorHex: "#6366F1",
                              iconName: "creditcard", type: "checking")
        context.insert(account)
        try context.save()
        return account
    }

    // MARK: - Semántica de la plataforma (lo que obliga a la forma del fix)

    /// CONTRATO MEDIDO, y es lo que hace SEGURO mover el high-water con el eco: lo que escribe un PULL es una
    /// transacción del store PERSONAL bajo `outboxSaveAuthor` (⇒ hay dónde anclar), mientras que lo que
    /// escribe el propio DRAIN —`SyncCursor`, `SyncOutbox`— vive en `syncMetaSchema` y NO es del store
    /// personal (⇒ anclar no genera una transacción nueva de ese store ⇒ no hay bucle).
    /// Si SwiftData dejara de partir por store un `save()` que toca ambos, este test avisa.
    @Test func pullWritesArePersonalStoreEchoes_whileDrainWritesAreNot() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.applyPage(try accountPage(seq: 7), context: context, now: applyNow)

        let accountTx = try lastTransaction(touching: "Account", context)
        let cursorTx = try lastTransaction(touching: "SyncCursor", context)

        #expect(accountTx.author == CloudSyncEngine.outboxSaveAuthor,
                "el apply de un pull escribe bajo el autor del motor: es ECO por definición")
        #expect(CloudSyncEngine.isPersonalStoreTransaction(accountTx),
                "y aun siendo eco es del store PERSONAL: es lo que da dónde anclar")
        #expect(accountTx.storeIdentifier != cursorTx.storeIdentifier,
                "el cursor vive en syncMeta, no en el store personal: es lo que impide el bucle")
        #expect(!CloudSyncEngine.isPersonalStoreTransaction(cursorTx))
        #expect(!accountTx.changes.contains { $0.changedPersistentIdentifier.entityName == "SyncCursor" },
                "un save que toca dos stores tiene que producir DOS transacciones, una por store")
    }

    /// CONTRATO MEDIDO, y la razón por la que el fix de Grupos NO se podía copiar tal cual: en el canal
    /// personal el avance NO estaba acotado al store, y sin acotarlo el bucle que temía el comentario
    /// original («cada avance escribiría el cursor → loop») EXISTE. En la ventana cross-store del bootstrap
    /// (token ausente → full-rescan) de un device sin ni una transacción personal, la última es la del propio
    /// cursor: anclar ahí hace que cada escritura del cursor produzca en `syncMeta` una transacción NUEVA que
    /// el drain siguiente vuelve a ver ⇒ avanza ⇒ escribe, sin fin. Y el daño mayor no es el bucle: desde un
    /// ancla en `syncMeta` el store PERSONAL queda OCULTO por completo (punto fijo).
    @Test func anchorWithoutStoreGuard_wouldLandOnSyncMeta_andNeverConverge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)      // crea el cursor: su tx es de syncMeta, no del personal
        let window = try history(context)
        #expect(!window.isEmpty)
        #expect(!window.contains { CloudSyncEngine.isPersonalStoreTransaction($0) },
                "premisa: la History del bootstrap no tiene ni una transacción del store personal")

        // El ancla que elegiría el avance SIN guard de store: la última de la ventana.
        var anchor = try #require(window.last)
        #expect(anchor.author == CloudSyncEngine.outboxSaveAuthor)
        #expect(!CloudSyncEngine.isPersonalStoreTransaction(anchor),
                "sin guard de store el ancla caería FUERA del store personal")

        // Tres vueltas de «anclar ahí ⇒ escribir el cursor ⇒ re-fetch por el token nuevo». La ventana NUNCA
        // se vacía: eso es el bucle, y es por qué el eco solo no bastaba como criterio.
        let cursor = try cursorRow(context)
        for turn in 1...3 {
            let token = anchor.token
            try engine.saveWithAuthor(context, CloudSyncEngine.outboxSaveAuthor) {
                cursor.historyTokenData = try JSONEncoder().encode(token)
                cursor.lastDrainedTxAt = anchor.timestamp
            }
            let after = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
            #expect(!after.isEmpty,
                    "vuelta \(turn): anclado fuera del store personal, escribir el cursor se re-lee a sí mismo")
            anchor = try #require(after.last)
        }

        // Y la otra mitad: desde ese ancla, una fila NUEVA del store personal no surfacea nunca.
        let metaAnchor = anchor.token
        engine.applyPage(try accountPage(seq: 1), context: context, now: applyNow)
        let seenFromMeta = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > metaAnchor }))
        #expect(!seenFromMeta.contains { CloudSyncEngine.isPersonalStoreTransaction($0) },
                "un ancla fuera del store personal deja al canal CIEGO a su propio store: punto fijo")
    }

    // MARK: - Device que solo RECIBE (el defecto medido)

    /// EL DEFECTO: tras un pull, el drain de un device que solo recibe tiene que anclar en el store PERSONAL
    /// usando su propio eco. Sin eso no escribe el cursor NUNCA.
    @Test func drain_receiveOnlyDevice_anchorsOnItsOwnPullWrites() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)                  // arranque del canal (crea el cursor)
        let cursor = try cursorRow(context)
        #expect(cursor.historyTokenData == nil, "premisa: sin actividad personal no hay nada que anclar")

        engine.applyPage(try accountPage(seq: 7), context: context, now: applyNow)
        engine.drainOnce(context: context)

        let accountTx = try lastTransaction(touching: "Account", context)
        #expect(decodedToken(cursor.historyTokenData) == accountTx.token,
                "el eco del propio pull es del store personal: el ancla tiene que caer exactamente ahí")
        #expect(cursor.lastDrainedTxAt == accountTx.timestamp,
                "el ancla comparable cross-mount se persiste con el token, no aparte")
    }

    /// LA CONSECUENCIA MEDIDA: vuelta tras vuelta de «llega una página, drena», la ventana que el próximo
    /// drain volvería a barrer tiene que quedar VACÍA. Con el defecto puesto el token no se escribía nunca y
    /// el fetch caía al full-rescan del bootstrap, que crecía una transacción por página aplicada — coste de
    /// CPU y memoria subiendo sin tope, en silencio.
    @Test func drain_receiveOnlyDevice_scanWindowDoesNotGrow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)
        let cursor = try cursorRow(context)
        var previousFloor: Date?

        for seq in 1...4 {
            engine.applyPage(try accountPage(seq: seq), context: context, now: applyNow)
            engine.drainOnce(context: context)

            let token = try #require(decodedToken(cursor.historyTokenData),
                                     "vuelta \(seq): el cursor no se escribió → la ventana crece")
            let window = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
            #expect(window.isEmpty, "vuelta \(seq): quedan \(window.count) txs por re-barrer")

            let floor = try #require(cursor.lastDrainedTxAt)
            if let previousFloor { #expect(floor > previousFloor, "vuelta \(seq): el suelo no avanzó") }
            previousFloor = floor
        }
    }

    /// LA RAZÓN QUE DABA EL CÓDIGO VIEJO para no avanzar con el eco («cada avance escribiría el cursor →
    /// loop») era real mientras el ancla no estaba acotada al store. Esta es la prueba de que con el guard
    /// puesto no lo es: una vez anclado, un drain SIN novedades no escribe nada — ni una transacción de
    /// History por vuelta.
    @Test func drain_afterAnchoringOnEcho_idleTurnsWriteNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)
        engine.applyPage(try accountPage(seq: 7), context: context, now: applyNow)
        engine.drainOnce(context: context)                  // ← aquí ancla en el eco

        let afterAnchor = try history(context).count
        engine.drainOnce(context: context)
        engine.drainOnce(context: context)
        #expect(try history(context).count == afterAnchor,
                "un drain ocioso escribió el cursor: eso es exactamente el bucle que se temía")
    }

    /// NO-REGRESIÓN del eco, que es lo que este fix podía romper: mover el high-water con las filas del pull
    /// NO puede hacer que se re-emitan al backend como ediciones locales.
    @Test func drain_receiveOnlyDevice_neverReEmitsPulledRows() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)
        engine.applyPage(try accountPage(seq: 7), context: context, now: applyNow)
        engine.drainOnce(context: context)
        engine.drainOnce(context: context)

        #expect(try outbox(context).isEmpty, "el apply de un pull no se re-empuja al backend")
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1, "y la fila remota sigue ahí")
    }

    /// Y el device que DESPUÉS escribe: con el ancla ya puesta en el eco de su propio pull, su primera fila
    /// local tiene que salir igual (mismo store ⇒ el token la surfacea).
    @Test func drain_receiveOnlyThenLocalWrite_stillCapturesIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        engine.drainOnce(context: context)
        engine.applyPage(try accountPage(seq: 7), context: context, now: applyNow)
        engine.drainOnce(context: context)

        // Tráfico del store de GRUPOS entre medias (lo que en producción domina y roba el ancla sin guard).
        context.insert(SplitGroup(name: "G"))
        try context.save()
        engine.drainOnce(context: context)

        let local = try addLocalAccount(context, name: "Ahorros")
        engine.drainOnce(context: context)

        let rows = try outbox(context)
        #expect(rows.count == 1, "la fila local posterior al eco tiene que salir")
        #expect(rows.first?.syncID == local.shortcutID)
    }
}
