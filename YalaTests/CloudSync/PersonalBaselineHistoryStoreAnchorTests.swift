//
//  PersonalBaselineHistoryStoreAnchorTests.swift
//  YalaTests / CloudSync
//
//  El ancla del BASELINE del cutover (`fastForwardHistoryBaseline`) y el store al que pertenece.
//
//  Hermano de `PersonalDrainHistoryStoreAnchorTests` por el otro camino: el baseline es un one-shot que
//  avanza el token del `SyncCursor` SIN emitir, para cerrar la ventana de escrituras concurrentes antes de
//  enumerar el snapshot (`MigrationSnapshotUploader.uploadPage`) y para que el primer drain del adoptador no
//  re-emita el corpus importado de CloudKit (`MigrationWorkExecutor.runAdoptFlow`, contrato (ii)).
//
//  Filtraba solo por AUTOR (`author != outboxSaveAuthor`) y no por STORE, y su comentario lo autorizaba por
//  escrito: afirmaba que anclar en `syncMeta` era «SEGURO por la misma monotonía global de tokens […]
//  device-probado», citando el save de captura de `SyncIdentity` como ejemplo bueno. **Medido el 2026-08-03:
//  falso.** `DefaultHistoryToken` es POR-STORE y oculta los demás stores del container, así que con el ancla
//  en `syncMeta` el write personal posterior al baseline no surfacea: el baseline deja de cerrar la ventana.
//  Y el fallo no se ve como un write perdido, porque `recoverIfHistoryTokenIncomparable` lo rescata
//  re-procesando la UNIÓN — o sea RE-EMITIENDO filas PRE-baseline (2 donde toca 1) más un canario
//  `historyTokenIncomparable` FALSO. Por eso la aserción que carga el peso en esta suite es el CONTEO del
//  outbox junto al contador de incomparables, no «¿se capturó el write posterior?»: eso último sale verde
//  con el defecto puesto.
//
//  Los dos casos alcanzables se sondearon y los dos fallaban: la última transacción no-motor siendo
//  `GroupSyncCursor` (autor `GroupsSyncOutbox`, EXTERNO para este canal — con el rollout de Grupos al 100 %
//  su loop de cadencia lo escribe periódicamente, así que es el caso DOMINANTE) y siendo `SyncIdentity`,
//  precisamente el ejemplo que el comentario daba por bueno.
//
//  QUÉ TEST CARGA EL PESO, y por qué NO es el que parece. `fetchHistory` sin predicado agrupa las
//  transacciones POR STORE, y **el orden de esos grupos NO es estable entre corridas del MISMO escenario**
//  (medido: 8 corridas idénticas → 5 con `syncMeta` al final, 3 con el store personal al final). Como el
//  defecto es «elige la última del fetch», en las corridas donde el grupo personal cae al final el código
//  con defecto y el correcto eligen LA MISMA transacción ⇒ **ningún test de escenario puede cazarlo de forma
//  determinista**: los dos tests de caso alcanzable de abajo detectan el mutante ~5 de cada 8 veces. Se
//  conservan porque documentan los escenarios REALES de producción y son estables en verde con el fix, pero
//  la red determinista es `baseline_withoutPersonalTx_writesNothing_andLaterWriteStillCaptured`: sin ninguna
//  transacción personal no-motor, el filtro correcto no encuentra nada (no escribe) y el defectuoso siempre
//  encuentra algo (escribe un ancla de otro store) ⇒ difieren en el 100 % de los órdenes. Es el único que
//  cae con la mutación, y por eso es el que hay que mirar si alguien toca esta función.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Personal · ancla del History por-store (baseline del cutover)", .serialized)
@MainActor
struct PersonalBaselineHistoryStoreAnchorTests {

    // MARK: - Infra (molde de `PersonalDrainHistoryStoreAnchorTests`)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PSBase-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PSB-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PSB-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PSB-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// `Account` y NO `TransactionItem`: insertar una TX dispara el backfill asíncrono del CSV mirror
    /// (`Task { @MainActor in save() }`), que salva bajo el autor por DEFECTO y mete una transacción EXTERNA
    /// espuria en la ventana — con eso la medición mide el backfill y no el ancla.
    @discardableResult
    private func addAccount(_ context: ModelContext, _ name: String) throws -> Account {
        let account = Account(name: name, currencyCode: "USD", colorHex: "#6366F1",
                              iconName: "creditcard", type: "checking")
        context.insert(account)
        try context.save()
        return account
    }

    private func history(_ context: ModelContext) throws -> [DefaultHistoryTransaction] {
        try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
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

    /// La transacción de History en la que quedó anclado el baseline.
    private func anchoredTransaction(_ context: ModelContext) throws -> DefaultHistoryTransaction {
        let token = try #require(decodedToken(try cursorRow(context).historyTokenData),
                                 "el baseline no escribió el token")
        return try #require(try history(context).first { $0.token == token })
    }

    // MARK: - Semántica de la plataforma (el contrato que refuta el comentario viejo)

    /// CONTRATO MEDIDO: las dos transacciones que este método puede elegir por error —el cursor del canal de
    /// GRUPOS y la captura de `SyncIdentity`— son de `syncMeta`, y desde un ancla ahí el store PERSONAL no
    /// surfacea. Es la refutación directa de «monotonía global de tokens»: si Apple cambiara esto, el filtro
    /// por store podría simplificarse y este test avisa.
    @Test func syncMetaAnchors_hidePersonalStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        try addAccount(context, "Personal-1")
        GroupsSyncClient().drainOnce(context: context)          // GroupSyncCursor, autor del canal de Grupos
        context.insert(SyncIdentity(syncID: UUID(), entityType: "accounts", localAnchor: "a"))
        try context.save()                                      // SyncIdentity, autor por DEFECTO

        func transaction(touching entity: String) throws -> DefaultHistoryTransaction {
            try #require(try history(context).last { tx in
                tx.changes.contains { $0.changedPersistentIdentifier.entityName == entity }
            })
        }
        let groupsCursorTx = try transaction(touching: "GroupSyncCursor")
        let identityTx = try transaction(touching: "SyncIdentity")

        // Las dos son EXTERNAS para este canal (una por autor ajeno, la otra por autor default)…
        #expect(groupsCursorTx.author != CloudSyncEngine.outboxSaveAuthor)
        #expect(identityTx.author != CloudSyncEngine.outboxSaveAuthor)
        // …y NINGUNA es del store personal, así que el filtro por autor SOLO no las descarta.
        #expect(!CloudSyncEngine.isPersonalStoreTransaction(groupsCursorTx))
        #expect(!CloudSyncEngine.isPersonalStoreTransaction(identityTx))

        // Y anclado en cualquiera de las dos, un write personal posterior NO surfacea.
        try addAccount(context, "Personal-2")
        for anchor in [groupsCursorTx.token, identityTx.token] {
            let window = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > anchor }))
            #expect(!window.contains { CloudSyncEngine.isPersonalStoreTransaction($0) },
                    "un ancla en syncMeta oculta el store personal: no hay monotonía global de tokens")
        }
    }

    // MARK: - Regresión del baseline

    /// EL CASO DOMINANTE: con el rollout de Grupos al 100 %, el loop de cadencia de `GroupsSyncClient`
    /// escribe su cursor periódicamente, así que la última transacción no-motor de la History es suya. El
    /// baseline tiene que saltarla y anclar en la última PERSONAL.
    ///
    /// La aserción de fondo es el CONTEO del outbox, no «¿se capturó el write posterior?»: con el defecto
    /// puesto el write también salía —lo rescataba el guard del token— pero arrastrando la fila PRE-baseline
    /// que este método existe para suprimir, y emitiendo un canario `historyTokenIncomparable` falso.
    ///
    /// PODER DE DETECCIÓN PARCIAL (ver el header): este escenario solo distingue el fix del defecto en las
    /// corridas donde el grupo de `syncMeta` cae al final del `fetchHistory`, y ese orden no es estable
    /// (~5/8 medido). Documenta el caso de producción; la red determinista es el test del `return`.
    @Test func baseline_lastNonEngineTxIsGroupsChannelCursor_anchorsOnPersonalStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        try addAccount(context, "Pre-baseline")
        GroupsSyncClient().drainOnce(context: context)          // ← la última no-motor, y es de syncMeta

        engine.fastForwardHistoryBaseline(context: context)
        #expect(CloudSyncEngine.isPersonalStoreTransaction(try anchoredTransaction(context)),
                "el baseline ancló fuera del store personal")

        try addAccount(context, "Post-baseline")
        engine.drainOnce(context: context)

        let rows = try outbox(context)
        #expect(rows.count == 1, "la fila PRE-baseline se re-emitió: el baseline no cerró la ventana")
        #expect(rows.first?.syncID != nil)
        #expect(engine.historyTokenIncomparableCount == 0,
                "el guard tuvo que rescatar el token → canario falso y re-emisión")
        #expect(engine.historyTokenRecoveredCount == 0)
    }

    /// EL EJEMPLO QUE EL COMENTARIO DABA POR BUENO: `SyncIdentity` (store `syncMeta`, autor por DEFECTO).
    /// El comentario lo citaba como prueba de que anclar en `syncMeta` era seguro; falla igual.
    @Test func baseline_lastNonEngineTxIsSyncIdentity_anchorsOnPersonalStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        try addAccount(context, "Pre-baseline")
        context.insert(SyncIdentity(syncID: UUID(), entityType: "accounts", localAnchor: "a"))
        try context.save()

        engine.fastForwardHistoryBaseline(context: context)
        #expect(CloudSyncEngine.isPersonalStoreTransaction(try anchoredTransaction(context)))

        try addAccount(context, "Post-baseline")
        engine.drainOnce(context: context)

        #expect(try outbox(context).count == 1)
        #expect(engine.historyTokenIncomparableCount == 0)
    }

    /// Tráfico del store de GRUPOS por entidad de dominio (`SplitGroup` bajo autor por defecto). Pasa incluso
    /// con el defecto puesto —el `fetchHistory` sin predicado agrupa por store, así que `txns.last` cayó en el
    /// personal por el orden y no por criterio— y está aquí justamente por eso: fija que el resultado ya no
    /// dependa de ese orden.
    @Test func baseline_groupsDomainTrafficPresent_anchorsOnPersonalStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        try addAccount(context, "Pre-baseline")
        context.insert(SplitGroup(name: "Viaje"))
        try context.save()

        engine.fastForwardHistoryBaseline(context: context)
        #expect(CloudSyncEngine.isPersonalStoreTransaction(try anchoredTransaction(context)))

        try addAccount(context, "Post-baseline")
        engine.drainOnce(context: context)
        #expect(try outbox(context).count == 1)
        #expect(engine.historyTokenIncomparableCount == 0)
    }

    /// NO-REGRESIÓN de lo que el baseline existe para hacer: suprimir el corpus PRE-baseline. Varias filas
    /// personales antes y una después → solo sale la de después.
    @Test func baseline_suppressesPreBaselineCorpus() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        for i in 1...4 { try addAccount(context, "Pre-\(i)") }
        engine.fastForwardHistoryBaseline(context: context)

        let post = try addAccount(context, "Post")
        engine.drainOnce(context: context)

        let rows = try outbox(context)
        #expect(rows.count == 1, "el baseline debe suprimir las 4 filas anteriores")
        #expect(rows.first?.syncID == post.shortcutID)
    }

    /// **LA RED DETERMINISTA de esta suite** (ver el header: es el ÚNICO test que puede cazar el defecto en el
    /// 100 % de los órdenes, porque no hay ninguna transacción personal que el orden inestable del
    /// `fetchHistory` pueda poner al final). Sin transacción PERSONAL no-motor no hay ventana personal que
    /// cerrar → el baseline no escribe: el filtro correcto no encuentra candidata y el defectuoso SIEMPRE
    /// encuentra una de otro store.
    ///
    /// Y el `return` sigue siendo la semántica correcta, no una rendición: lo que este método suprime son
    /// writes del store personal, así que su ausencia en la History implica que no hay nada que suprimir. Las
    /// dos mitades de fondo son que el token quede intacto y que el primer write personal POSTERIOR se capture
    /// —con el defecto puesto el token queda anclado en otro store y ese write no surfacea, así que solo lo
    /// rescata el guard, re-emitiendo y disparando un canario falso—.
    @Test func baseline_withoutPersonalTx_writesNothing_andLaterWriteStillCaptured() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        context.insert(SplitGroup(name: "Solo grupos"))
        try context.save()
        GroupsSyncClient().drainOnce(context: context)

        // Premisa del determinismo: hay candidatas no-motor, pero NINGUNA del store personal.
        let candidates = try history(context).filter { $0.author != CloudSyncEngine.outboxSaveAuthor }
        #expect(!candidates.isEmpty, "el escenario necesita candidatas que el filtro por autor SÍ acepte")
        #expect(!candidates.contains { CloudSyncEngine.isPersonalStoreTransaction($0) },
                "y ninguna puede ser del store personal, o el orden volvería el test no determinista")

        engine.fastForwardHistoryBaseline(context: context)
        #expect(try cursorRow(context).historyTokenData == nil,
                "sin transacción personal el baseline no tiene dónde anclar y no debe escribir el token")
        #expect(try cursorRow(context).lastDrainedTxAt == nil,
                "y tampoco el ancla temporal: token y suelo van SIEMPRE juntos")

        let post = try addAccount(context, "Primera personal")
        engine.drainOnce(context: context)
        let rows = try outbox(context)
        #expect(rows.count == 1)
        #expect(rows.first?.syncID == post.shortcutID)
        #expect(engine.historyTokenIncomparableCount == 0,
                "el guard tuvo que rescatar un ancla puesta en el store equivocado")
    }

    /// El invariante S1 que ya existía y que este cambio no puede romper: token y `lastDrainedTxAt` avanzan
    /// SIEMPRE en el mismo save, y apuntan a la MISMA transacción.
    @Test func baseline_stampsTokenAndFloorFromTheSameTransaction() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        try addAccount(context, "Personal-1")
        GroupsSyncClient().drainOnce(context: context)
        engine.fastForwardHistoryBaseline(context: context)

        let cursor = try cursorRow(context)
        let anchored = try anchoredTransaction(context)
        #expect(cursor.lastDrainedTxAt == anchored.timestamp,
                "el ancla temporal tiene que ser la de la MISMA tx del token, no la de otra")
    }
}
