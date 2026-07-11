//
//  CloudSyncE2EStagingTests.swift
//  YalaTests / CloudSync
//
//  E2E REAL del ciclo productor→consumidor (I8e + I8f-1) contra el Worker de STAGING y Supabase
//  staging: write local → drain → push → pull en un segundo store fresco → apply materializa.
//  Verifica el decoder Swift contra los BYTES REALES del wire (NUMERIC de PostgREST como número
//  JSON, timestamptz con offset, uuid[] null/[]) — lo que ningún fixture local puede garantizar.
//
//  GATEADO por la env var `YALA_CLOUD_E2E=1` (correr con `TEST_RUNNER_YALA_CLOUD_E2E=1 xcodebuild
//  test …`): necesita red + el usuario de test sembrado en I5. NO corre en CI ni en /test-smart
//  (aparece como skipped). Mismo target/credenciales que gateway/test/sync.goldens.test.ts y
//  qa/cloud/push-e2e-test.sh (anon key + password grant del user A; NUNCA service_role). Los
//  sync_id son ÚNICOS por run — sin cleanup posible (DELETE revocado por diseño en staging).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct CloudSyncE2EStagingTests {

    private nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_CLOUD_E2E"] == "1"
    }

    // Staging (mismo target que qa/cloud/push-e2e-test.sh).
    private static let supabaseURL = "https://fostjbbwstyuunmmefuk.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
    private static let workerURL = URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!

    // MARK: - Helpers

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-e2e-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("freshDir: \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch {
            #if DEBUG
            print("CloudSyncE2EStagingTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "E2E-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "E2E-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "E2E-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Password-grant contra Supabase staging (mismo flujo que el harness del gateway).
    private func login() async throws -> String {
        var request = URLRequest(url: URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=password")!)
        request.httpMethod = "POST"
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"email":"i5-user-a@test.yala","password":"I5-Passw0rd-A!"}"#.utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable { let access_token: String? }
        guard let token = try JSONDecoder().decode(TokenResponse.self, from: data).access_token else {
            throw CocoaError(.coderValueNotFound)
        }
        return token
    }

    // MARK: - Round-trip completo

    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func roundTrip_pushFromA_pullMaterializesInB_editInB_pullConvergesInA() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }

        // ---------- Device A: write local → drain → push ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()

        let marker = "i8f1-e2e-\(UUID().uuidString.prefix(8))"
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_751_900_000),
                                 amount: -37.25, currencyCode: "PEN")
        tx.note = marker
        tx.amountInPreferredCurrency = -37.25
        tx.preferredCurrencyCode = "PEN"
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false
        tx.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
        contextA.insert(tx)
        try contextA.save()

        engineA.drainOnce(context: contextA)
        let rowsA = try contextA.fetch(FetchDescriptor<SyncOutbox>())
        #expect(!rowsA.isEmpty, "el drain de A debe producir filas de outbox")
        guard let pushedSyncID = rowsA.first?.syncID else { return }

        let pushClient = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushOutcome = await pushClient.push(rowsA)
        guard case .completed(let results) = pushOutcome else {
            Issue.record("push A no completó: \(pushOutcome)")
            return
        }
        #expect(results.allSatisfy { $0.status == .applied || $0.status == .noop },
                "todos los deltas de A deben aplicar: \(results)")
        await pushClient.applyResults(results, rows: rowsA, engine: engineA, context: contextA)

        // ---------- Device B (store fresco): pull → apply materializa ----------
        let dirB = freshDir(); defer { cleanup(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let pullClientB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        let outcomeB = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB)
        guard case .completed(let pages) = outcomeB else {
            Issue.record("pull B no completó: \(outcomeB)")
            return
        }
        #expect(pages >= 1, "B debe haber aplicado al menos una página")

        // La TX de A materializada en B con la MISMA identidad y el grupo money verbatim.
        let materialized = try contextB.fetch(FetchDescriptor<TransactionItem>())
            .first { $0.syncID == pushedSyncID }
        guard let txB = materialized else {
            Issue.record("la TX \(pushedSyncID) de A no se materializó en B")
            return
        }
        #expect(txB.note == marker)
        #expect(txB.amount == -37.25)
        #expect(txB.currencyCode == "PEN")
        #expect(txB.amountInPreferredCurrency == -37.25)
        #expect(txB.exchangeRate == 1.0)
        #expect(txB.isExchangeRateProvisional == false)

        // (I12 completa: las 16 tablas de dominio están cableadas → ya NO queda tabla que caiga en
        // cuarentena por diseño; el assert de cuarentena se retiró — la mecánica del upgrade-path queda
        // cubierta por los unit tests de SyncQuarantineDrainTests con `LegacyUnmappedEntity`.)

        // El cursor de B avanzó de forma durable.
        let cursorB = try contextB.fetch(FetchDescriptor<SyncCursor>()).first
        #expect((cursorB?.serverSeqCursor ?? 0) > 0)

        // ---------- B edita → push; A pullea → converge ----------
        let editedMarker = marker + "-edited"
        txB.note = editedMarker
        try contextB.save()
        engineB.drainOnce(context: contextB)
        let rowsB = try contextB.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.rejectedReason == nil }
        #expect(!rowsB.isEmpty, "el drain de B debe capturar la edición")

        let pushClientB = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushOutcomeB = await pushClientB.push(rowsB)
        guard case .completed(let resultsB) = pushOutcomeB else {
            Issue.record("push B no completó: \(pushOutcomeB)")
            return
        }
        await pushClientB.applyResults(resultsB, rows: rowsB, engine: engineB, context: contextB)

        let pullClientA = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let outcomeA = await engineA.pullAndApplyOnce(using: pullClientA, context: contextA)
        guard case .completed = outcomeA else {
            Issue.record("pull A no completó: \(outcomeA)")
            return
        }
        #expect(tx.note == editedMarker, "A debe converger a la edición de B (nota: \(tx.note ?? "nil"))")
        // Y el apply en A no debe haber re-encolado nada (echo-suppression del drain, D-4).
        engineA.drainOnce(context: contextA)
        let echoRows = try contextA.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.rejectedReason == nil }
        #expect(echoRows.isEmpty, "el apply de A no debe producir eco en el outbox: \(echoRows.count)")

        // ---------- Merkle (I8f-3): B verifica integridad contra staging ----------
        // Assert FUERTE de fidelidad del apply I8f-1: B tiene TODA la historia del user de staging
        // (incl. filas de runs previos) — cualquier decode con pérdida rompe el entityHash de su tabla.
        // Pull final en B (recoge su propio push — echo idempotente) para satisfacer el guard A-3.
        let outcomeB2 = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB)
        guard case .completed = outcomeB2 else {
            Issue.record("pull final de B no completó: \(outcomeB2)")
            return
        }
        let merkleClient = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let verdict = await engineB.verifyIntegrity(using: merkleClient, context: contextB)
        switch verdict {
        case .converged:
            break  // las 6 cableadas convergen byte a byte (las tablas con cuarentena se saltan, regla 5)
        case .diverged(let entities):
            // DIVERGENCIA CONOCIDA de ESTE dataset (medida 2026-07-08): el user A de staging arrastra
            // ~77 tx_items HAND-CRAFTED por los goldens del gateway (pushes parciales pre-I8f: `date`/
            // `amount`/`currency_code` NULL server-side) que son DOMAIN-INVALID para el cliente (props
            // non-optional → defaults del init) → el leaf local JAMÁS puede reproducirlas. Es una
            // divergencia VERDADERA (el cliente NO pudo materializar todo fielmente), no un fallo del
            // verificador: el canario haciendo exactamente su trabajo contra datos fuera del dominio.
            // Las refs colgadas (subcategory_ref a targets inexistentes) SÍ convergen vía el override
            // de SyncDanglingRef. Cualquier OTRA tabla divergente = infidelidad real del apply → falla.
            // MASKING ACEPTADO (hallazgo 5 del review, decisión owner): la divergencia permanente de
            // tx_items podría ENMASCARAR una infidelidad real del apply en ESA tabla dentro de este e2e.
            // Se acepta porque (a) el assert campo-a-campo de NUESTRA fila (arriba: note/amount/money
            // group verbatim) ya cubre la fidelidad del path fresco, y (b) un assert por count sería
            // frágil: el dataset de staging CRECE con cada run (sin cleanup por diseño).
            #expect(entities == ["tx_items"],
                    "solo tx_items puede divergir (filas parciales hand-crafted de staging): \(entities)")
        case .skipped(let reason):
            Issue.record("Merkle no se verificó (\(reason)) — el guard A-3 debía estar satisfecho")
        }
    }

    // MARK: - Runtime completo (I9): syncCycle drain→push→pull→apply contra staging

    /// Corre el `syncCycle()` del ORQUESTADOR (no los componentes sueltos) contra staging real: write
    /// local → un ciclo (drain+push+pull+apply) → segundo ciclo (recoge su propio push, echo idempotente,
    /// para satisfacer el guard A-3) → verificación Merkle. Conserva el assert `diverged == ["tx_items"]`
    /// (mismas filas parciales hand-crafted del dataset de staging; ver el test de round-trip).
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func runtimeSyncCycle_pushPullMerkle_againstStaging() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let push = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pull = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let merkle = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let runtime = CloudSyncRuntime(
            engine: engine, pushClient: push, pullClient: pull, merkleClient: merkle,
            mirror: nil,
            coordinator: SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud }),
            session: E2ECloudSession(userID: "i9-e2e"),
            onRemoteChangesApplied: nil
        )

        // Write local: una TX nueva con marcador único.
        let marker = "i9-e2e-\(UUID().uuidString.prefix(8))"
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_751_900_000),
                                 amount: -21.75, currencyCode: "PEN")
        tx.note = marker
        tx.amountInPreferredCurrency = -21.75
        tx.preferredCurrencyCode = "PEN"
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false
        tx.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
        context.insert(tx)
        try context.save()

        // Ciclo 1: drena la TX, la sube, pullea el historial y aplica.
        _ = await runtime.syncCycle(context: context)
        // Ciclo 2: recoge su propio push (echo idempotente) → outbox vivo vacío + pull completado.
        _ = await runtime.syncCycle(context: context)

        // La TX sigue en el store (no se perdió) y el outbox quedó limpio (todo confirmado).
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).contains { $0.note == marker })
        let liveOutbox = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(liveOutbox.isEmpty, "el outbox vivo debe quedar vacío tras el ciclo: \(liveOutbox.count)")

        // Merkle: mismo veredicto que el round-trip (solo tx_items puede divergir por el dataset staging).
        let verdict = await engine.verifyIntegrity(using: merkle, context: context)
        switch verdict {
        case .converged:
            break
        case .diverged(let entities):
            #expect(entities == ["tx_items"],
                    "solo tx_items puede divergir (filas parciales hand-crafted de staging): \(entities)")
        case .skipped(let reason):
            Issue.record("Merkle no se verificó (\(reason)) — el guard A-3 debía estar satisfecho")
        }
    }

    // MARK: - Round-trip budgets + scheduled_payments (I12 commit A)

    /// A crea un Budget con filtros POBLADOS (CSV mirror uuid[]) y otro con filtros VACÍOS + un
    /// ScheduledPayment con split configurado (`amount` = MI-PARTE) → push → B (store fresco) materializa
    /// las 3 filas → B edita el pago planificado → A converge → Merkle `diverged == ["tx_items"]` SE
    /// CONSERVA (mismas filas parciales hand-crafted del dataset de staging; ver el round-trip de tx).
    ///
    /// **NOTA para el owner (D7) — ACCIÓN PENDIENTE (medido 2026-07-08)**: al cablear `budgets` el Merkle
    /// reporta `diverged == ["budgets","tx_items"]`. La divergencia de `budgets` la causan 3 filas LEGACY
    /// hand-crafted del golden 10 en staging con `name`/`period_type`/`created_at` = NULL server-side
    /// (DOMAIN-INVALID: props non-optional → el cliente materializa defaults del init → su leaf jamás las
    /// reproduce; idéntico al caso de los ~77 tx_items). `scheduled_payments` NO diverge (limpia). El assert
    /// se mantiene ESTRICTO (`== ["tx_items"]`, NUNCA relajar) → estos 3 tests fallan hasta que el owner haga
    /// `UPDATE budgets SET deleted=true WHERE sync_id IN (...)` en staging:
    ///     0800943b-80a3-4c1c-a4c6-5de4f3373d67
    ///     316a26fd-4657-4bc0-aa7b-04593a04f8a8
    ///     3a86674e-c3b1-4780-a00e-5977bfb714db
    /// Tras tombstonearlas, los 3 tests convergen a `["tx_items"]`. Los sync_id nuevos de este run son
    /// ÚNICOS (sin cleanup); las 2 filas i12-filled/i12-empty son DOMAIN-VALID y convergen.
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func roundTrip_budgetAndScheduledPayment_pushFromA_materializesInB_convergesInA() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }

        // ---------- Device A: write local (budget con filtros + budget vacío + pago con split) ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()
        let run = String(UUID().uuidString.prefix(8))

        // Budget con filtros POBLADOS: los uuid[] viajan como CSV mirror (los destinos no están cableados
        // en commit A → en B quedan como CSV sin M2M, pero el leaf usa el CSV = wire-completo → converge).
        let budgetFilled = Budget(currencyCode: "PEN", limitAmount: 500)
        budgetFilled.name = "i12-filled-\(run)"
        let subShortcut = UUID(); let accShortcut = UUID(); let tagID = UUID()
        budgetFilled.subcategoryIDs = CSVMirrorCodec.encode([subShortcut])
        budgetFilled.accountIDs = CSVMirrorCodec.encode([accShortcut])
        budgetFilled.tagIDs = CSVMirrorCodec.encode([tagID])
        budgetFilled.natures = "essential,priority"
        budgetFilled.alertEnabled = true
        budgetFilled.alertThresholds = "50,75,100"
        contextA.insert(budgetFilled)

        // Budget con filtros VACÍOS.
        let budgetEmpty = Budget(currencyCode: "PEN", limitAmount: 100)
        budgetEmpty.name = "i12-empty-\(run)"
        contextA.insert(budgetEmpty)

        // ScheduledPayment con split — `amount` = MI-PARTE (100), `splitTotalAmount` = total (250).
        let sp = ScheduledPayment(name: "i12-sp-\(run)", amount: 100, currencyCode: "PEN",
                                  nextDueDate: Date(timeIntervalSince1970: 1_751_900_000))
        sp.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
        sp.groupZoneID = "zone-\(run)"
        sp.splitTotalAmount = 250
        sp.splitType = "equal"
        sp.splitParticipantIDsRaw = "\(UUID().uuidString):1"
        sp.splitValuesRaw = "\(UUID().uuidString):1"
        sp.selectedWeekdays = "1,3,5"
        contextA.insert(sp)
        try contextA.save()

        let budgetFilledID = budgetFilled.id
        let budgetEmptyID = budgetEmpty.id
        let spID = sp.id

        engineA.drainOnce(context: contextA)
        let rowsA = try contextA.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(rowsA.count >= 3, "el drain de A debe producir ≥3 filas (2 budgets + 1 pago): \(rowsA.count)")

        let pushClient = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushOutcome = await pushClient.push(rowsA)
        guard case .completed(let results) = pushOutcome else {
            Issue.record("push A no completó: \(pushOutcome)"); return
        }
        #expect(results.allSatisfy { $0.status == .applied || $0.status == .noop },
                "todos los deltas de A deben aplicar: \(results)")
        await pushClient.applyResults(results, rows: rowsA, engine: engineA, context: contextA)

        // ---------- Device B (store fresco): pull → apply materializa las 3 filas ----------
        let dirB = freshDir(); defer { cleanup(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let pullClientB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        let outcomeB = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB)
        guard case .completed = outcomeB else { Issue.record("pull B no completó: \(outcomeB)"); return }

        let bFilled = try contextB.fetch(FetchDescriptor<Budget>()).first { $0.id == budgetFilledID }
        #expect(bFilled?.limitAmount == 500)
        #expect(bFilled?.natures == "essential,priority")
        #expect(bFilled?.alertThresholds == "50,75,100")
        // CSV mirror wire-completo (los destinos no cableados → M2M vacía, CSV preservado).
        #expect(bFilled?.subcategoryIDsSet == Set([subShortcut]))
        #expect(bFilled?.accountIDsSet == Set([accShortcut]))
        #expect(bFilled?.tagIDsSet == Set([tagID]))

        let bEmpty = try contextB.fetch(FetchDescriptor<Budget>()).first { $0.id == budgetEmptyID }
        #expect(bEmpty?.limitAmount == 100)
        #expect(bEmpty?.subcategoryIDs == nil)   // grupo vacío → CSV nil (sin filtro)

        let bSP = try contextB.fetch(FetchDescriptor<ScheduledPayment>()).first { $0.id == spID }
        #expect(bSP?.amount == 100)              // MI-PARTE preservada verbatim (no el total)
        #expect(bSP?.splitTotalAmount == 250)
        #expect(bSP?.splitType == "equal")
        #expect(bSP?.selectedWeekdays == "1,3,5")

        // ---------- B edita el pago → push; A pullea → converge ----------
        bSP?.amount = 130
        try contextB.save()
        engineB.drainOnce(context: contextB)
        let rowsB = try contextB.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(!rowsB.isEmpty, "el drain de B debe capturar la edición del pago")
        let pushClientB = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed(let resultsB) = await pushClientB.push(rowsB) else {
            Issue.record("push B no completó"); return
        }
        await pushClientB.applyResults(resultsB, rows: rowsB, engine: engineB, context: contextB)

        let pullClientA = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed = await engineA.pullAndApplyOnce(using: pullClientA, context: contextA) else {
            Issue.record("pull A no completó"); return
        }
        #expect(sp.amount == 130, "A debe converger a la edición de B (amount: \(sp.amount))")

        // ---------- Merkle: B verifica integridad; el veredicto se CONSERVA en ["tx_items"] ----------
        guard case .completed = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB) else {
            Issue.record("pull final de B no completó"); return
        }
        let merkleClient = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        switch await engineB.verifyIntegrity(using: merkleClient, context: contextB) {
        case .converged:
            break
        case .diverged(let entities):
            // Ver la NOTA de D7 arriba: solo `tx_items` puede divergir (filas parciales hand-crafted).
            // Si aparece `budgets`/`scheduled_payments`, son filas legacy de staging → tombstonearlas,
            // NUNCA relajar el assert.
            #expect(entities == ["tx_items"],
                    "solo tx_items puede divergir; si hay budgets/scheduled_payments, tombstonear en staging: \(entities)")
        case .skipped(let reason):
            Issue.record("Merkle no se verificó (\(reason)) — el guard A-3 debía estar satisfecho")
        }
    }

    // MARK: - Round-trip "las 8" restantes (I12 commit B)

    /// A crea UNA fila de cada una de las 8 entidades de commit B (accounts, subcategories, tags,
    /// notification_items, cashflow_plans, cashflow_lines, cashflow_overrides, group_bridge_prefs) CON
    /// refs cruzadas reales (subcategory→category, cashflow_line→plan+scheduled_payment+category+
    /// subcategory, override→line) + una TX que referencia account/subcategory/tag (prueba el auto-cure de
    /// refs) → push → B (store fresco) materializa TODO con las refs re-resueltas → Merkle
    /// `diverged == ["tx_items"]` ESTRICTO (staging LIMPIO en las 8; solo las filas parciales hand-crafted
    /// de tx_items divergen — ver el round-trip de tx). Si aparece cualquier otra tabla divergente son
    /// filas legacy de staging → tombstonearlas, NUNCA relajar el assert.
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func roundTrip_theEight_pushFromA_materializesInB_merkleConverges() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }

        // ---------- Device A: grafo con refs cruzadas ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()
        let run = String(UUID().uuidString.prefix(8))

        let category = Category(name: "cat-\(run)", colorHex: "#222222", isIncome: false, isDefaultSeed: false)
        contextA.insert(category)
        let account = Account(name: "acc-\(run)", currencyCode: "PEN", colorHex: "#111111",
                              iconName: "creditcard", type: "checking")
        contextA.insert(account)
        let subcategory = Subcategory(name: "sub-\(run)", category: category)
        contextA.insert(subcategory)
        let tag = Tag(name: "tag-\(run)")
        contextA.insert(tag)
        let notif = NotificationItem(name: "notif-\(run)", text: "", hour: 21, minute: 0,
                                     type: .dailyReport,
                                     reportConfig: ReportConfig(dataType: .income, dayPreference: .monday))
        contextA.insert(notif)
        let sp = ScheduledPayment(name: "sp-\(run)", amount: 50, currencyCode: "PEN",
                                  nextDueDate: Date(timeIntervalSince1970: 1_751_900_000))
        sp.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
        contextA.insert(sp)
        let plan = CashFlowPlan(name: "plan-\(run)")
        contextA.insert(plan)
        let line = CashFlowLine(name: "line-\(run)", isIncome: true, estimationMethod: .manual,
                                manualAmount: 1000, category: category, subcategory: subcategory,
                                scheduledPayment: sp)
        line.plan = plan
        line.customMonthsRaw = "2026-01,2026-02"
        contextA.insert(line)
        let override = CashFlowOverride(monthKey: "2026-04", amount: 12, note: "n")
        override.line = line
        contextA.insert(override)
        let pref = GroupBridgePreference(groupZoneID: "zone-\(run)", bridgeOverride: false)
        contextA.insert(pref)
        // TX que referencia account/subcategory/tag → prueba el auto-cure de refs al cablear.
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_751_900_000), amount: -9,
                                 currencyCode: "PEN")
        tx.note = "tx8-\(run)"
        tx.amountInPreferredCurrency = -9
        tx.preferredCurrencyCode = "PEN"
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false
        tx.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
        tx.account = account
        tx.subcategory = subcategory
        tx.setTags(from: [tag])
        contextA.insert(tx)
        try contextA.save()

        let accShortcut = account.shortcutID
        let subShortcut = subcategory.shortcutID
        let tagID = tag.id
        let notifID = notif.id
        let planID = plan.id
        let lineID = line.id
        let overrideID = override.id
        let prefID = pref.id
        let txSID: UUID?

        engineA.drainOnce(context: contextA)
        let rowsA = try contextA.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        txSID = rowsA.first { $0.entityType == SyncEntityType.transactionItem }?.syncID
        #expect(rowsA.count >= 10, "≥10 filas (8 nuevas + Category + ScheduledPayment + TX): \(rowsA.count)")

        let pushClient = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed(let results) = await pushClient.push(rowsA) else {
            Issue.record("push A no completó"); return
        }
        #expect(results.allSatisfy { $0.status == .applied || $0.status == .noop },
                "todos los deltas de A deben aplicar: \(results)")
        await pushClient.applyResults(results, rows: rowsA, engine: engineA, context: contextA)

        // ---------- Device B (store fresco): pull → materializa TODO ----------
        let dirB = freshDir(); defer { cleanup(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let pullClientB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB) else {
            Issue.record("pull B no completó"); return
        }

        let bAcc = try contextB.fetch(FetchDescriptor<Account>()).first { $0.shortcutID == accShortcut }
        #expect(bAcc?.name == "acc-\(run)")
        let bSub = try contextB.fetch(FetchDescriptor<Subcategory>()).first { $0.shortcutID == subShortcut }
        #expect(bSub?.name == "sub-\(run)")
        #expect(bSub?.category != nil)  // subcategory→category re-resuelto
        let bTag = try contextB.fetch(FetchDescriptor<Yala.Tag>()).first { $0.id == tagID }
        #expect(bTag?.name == "tag-\(run)")
        let bNotif = try contextB.fetch(FetchDescriptor<NotificationItem>()).first { $0.id == notifID }
        #expect(bNotif?.reportConfig.dataType == .income)
        #expect(bNotif?.reportConfig.dayPreference == .monday)
        let bPlan = try contextB.fetch(FetchDescriptor<CashFlowPlan>()).first { $0.id == planID }
        #expect(bPlan?.name == "plan-\(run)")
        let bLine = try contextB.fetch(FetchDescriptor<CashFlowLine>()).first { $0.id == lineID }
        #expect(bLine?.manualAmount == 1000)
        #expect(bLine?.plan?.id == planID)              // line→plan
        #expect(bLine?.scheduledPayment?.id == sp.id)   // line→scheduled_payment
        #expect(bLine?.category != nil)                 // line→category
        #expect(bLine?.subcategory?.shortcutID == subShortcut)
        #expect(bLine?.customMonthsRaw == "2026-01,2026-02")
        let bOverride = try contextB.fetch(FetchDescriptor<CashFlowOverride>()).first { $0.id == overrideID }
        #expect(bOverride?.line?.id == lineID)          // override→line
        let bPref = try contextB.fetch(FetchDescriptor<GroupBridgePreference>()).first { $0.id == prefID }
        #expect(bPref?.groupZoneID == "zone-\(run)")    // opaco byte a byte
        #expect(bPref?.bridgeOverride == false)
        // La TX auto-cura sus refs a account/subcategory/tag (todas ahora cableadas).
        if let txSID {
            let bTx = try contextB.fetch(FetchDescriptor<TransactionItem>()).first { $0.syncID == txSID }
            #expect(bTx?.account?.shortcutID == accShortcut)
            #expect(bTx?.subcategory?.shortcutID == subShortcut)
            #expect((bTx?.resolvedTagIDs() ?? []).contains(tagID))
        }

        // ---------- Merkle: veredicto CONSERVADO en ["tx_items"] ----------
        guard case .completed = await engineB.pullAndApplyOnce(using: pullClientB, context: contextB) else {
            Issue.record("pull final de B no completó"); return
        }
        let merkleClient = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        switch await engineB.verifyIntegrity(using: merkleClient, context: contextB) {
        case .converged:
            break
        case .diverged(let entities):
            #expect(entities == ["tx_items"],
                    "solo tx_items puede divergir; cualquier otra tabla = filas legacy de staging a tombstonear: \(entities)")
        case .skipped(let reason):
            Issue.record("Merkle no se verificó (\(reason)) — el guard A-3 debía estar satisfecho")
        }
    }

    // MARK: - Snapshot upload REAL (I10-wiring w4/w5)

    /// Dataset local propio multi-entidad (Category/Account/Subcategory/Tag — tablas LIMPIAS en staging) →
    /// `backfillIdentities` → `MigrationSnapshotUploader` REAL contra staging → pull final (guard A-3) →
    /// `verifyIntegrity` REAL (`/sync/merkle`). CONSERVA ESTRICTO el assert `diverged == ["tx_items"]` (la
    /// divergencia legacy hand-crafted es PERMANENTE server-side) y comprueba que NINGUNA tabla del dataset
    /// aparece divergente tras el snapshot. Se evita `budgets` a propósito (D7: 3 filas legacy divergen
    /// hasta que el owner las tombstonee — NUNCA relajar el assert).
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func snapshotUpload_backfillThenVerify_datasetTablesConverge() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let push = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pull = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let merkle = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        // Dataset propio (tablas limpias en staging; se EVITA tx_items/budgets por la divergencia legacy).
        let run = String(UUID().uuidString.prefix(8))
        let category = Category(name: "snap-cat-\(run)", colorHex: "#333333", isIncome: false, isDefaultSeed: false)
        context.insert(category)
        let account = Account(name: "snap-acc-\(run)", currencyCode: "PEN", colorHex: "#111111",
                              iconName: "creditcard", type: "checking")
        context.insert(account)
        let subcategory = Subcategory(name: "snap-sub-\(run)", category: category)
        context.insert(subcategory)
        let tag = Tag(name: "snap-tag-\(run)")
        context.insert(tag)
        try context.save()

        // Backfill de identidades (la migración lo hace ANTES del snapshot).
        SyncIdentityService.backfillIdentities(context: context)

        // Snapshot upload REAL, página a página hasta completar.
        let uploader = MigrationSnapshotUploader(engine: engine, pushClient: push, context: context)
        var cursor: String?
        var done = false
        for _ in 0..<500 {
            switch await uploader.uploadPage(cursor: cursor) {
            case .completed:
                done = true
            case .pageConfirmed(let c):
                cursor = c
            case .transient:
                Issue.record("snapshot .transient contra staging"); return
            }
            if done { break }
        }
        #expect(done, "el snapshot no completó contra staging")
        let liveOutbox = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(liveOutbox.isEmpty, "el outbox vivo debe quedar vacío tras el snapshot: \(liveOutbox.count)")

        // Pull final (satisface el guard A-3 de la verificación: recoge nuestro propio push, echo idempotente).
        guard case .completed = await engine.pullAndApplyOnce(using: pull, context: context) else {
            Issue.record("pull final no completó"); return
        }

        // verify REAL: el veredicto CONSERVA ["tx_items"] y NINGUNA tabla del dataset diverge.
        switch await engine.verifyIntegrity(using: merkle, context: context) {
        case .converged:
            break
        case .diverged(let entities):
            #expect(entities == ["tx_items"],
                    "solo tx_items (legacy hand-crafted) puede divergir; nada del dataset: \(entities)")
            for table in ["categories", "accounts", "subcategories", "tags"] {
                #expect(!entities.contains(table),
                        "la tabla \(table) del dataset divergió tras el snapshot: \(entities)")
            }
        case .skipped(let reason):
            Issue.record("Merkle no se verificó (\(reason)) — el guard A-3 debía estar satisfecho")
        }
    }

    // MARK: - Merge de entidades de SISTEMA (política v1, residual gate de flags)

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// Drena la History, pushea el outbox vivo, aplica resultados. `true` si todo aplicó/noop.
    @discardableResult
    private func drainAndPush(_ engine: CloudSyncEngine, _ context: ModelContext,
                              _ push: SyncPushClient) async throws -> Bool {
        engine.drainOnce(context: context)
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        guard !rows.isEmpty else { return true }
        guard case .completed(let results) = await push.push(rows) else { return false }
        await push.applyResults(results, rows: rows, engine: engine, context: context)
        return results.allSatisfy { $0.status == .applied || $0.status == .noop }
    }

    /// Tombstonea (delete local, autor default) TODAS las filas del `run` (cuentas por nombre, TXs por note).
    /// `.contains` en Swift SOBRE ARRAYS ya fetcheados (NUNCA `#Predicate localizedStandardContains` — gotcha
    /// CLAUDE.md variante 2).
    private func tombstoneRunRows(run: String, context: ModelContext) throws {
        for acc in try context.fetch(FetchDescriptor<Account>()).filter({ $0.name.contains(run) }) {
            context.delete(acc)
        }
        for tx in try context.fetch(FetchDescriptor<TransactionItem>()).filter({ ($0.note ?? "").contains(run) }) {
            context.delete(tx)
        }
        if context.hasChanges { try context.save() }
    }

    /// Dos devices acuñan la cuenta de sistema `Grupos PEN` con NOMBRES distintos (idiomas distintos) → el
    /// DUPLICADO server-side se demuestra a nivel de WIRE (pull read-only sin apply — el merge corre DENTRO
    /// de `pullAndApplyOnce`, así que post-apply ya no es observable) → el pase interno colapsa AMBOS devices
    /// al MISMO ganador determinista (`(name, shortcutID)` asc → "Groups" < "Grupos"), re-apunta las TXs y
    /// tombstonea la perdedora; el reconcile manual posterior asserta idempotencia (no-op). **RP-1: cleanup a
    /// 0 VIVAS del run** (el Merkle es por user; una fila `accounts` viva rompería el
    /// `diverged == ["tx_items"]` del test de snapshot, mismo user A). Verificado en un 3er store fresco.
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func systemAccountMerge_twoDevices_convergeToDeterministicWinner_thenCleanup() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }
        let run = String(UUID().uuidString.prefix(8))
        let pushA = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pullA = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushB = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pullB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        func systemAccount(_ name: String) -> Account {
            Account(name: name, currencyCode: "PEN", colorHex: "#7C3AED",
                    iconName: "person.2.circle.fill", type: "system", isSystemAccount: true)
        }
        func makeTx(_ note: String, account: Account) -> TransactionItem {
            let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_751_900_000), amount: -11, currencyCode: "PEN")
            tx.note = note
            tx.amountInPreferredCurrency = -11
            tx.preferredCurrencyCode = "PEN"
            tx.exchangeRate = 1.0
            tx.isExchangeRateProvisional = false
            tx.createdAt = Date(timeIntervalSince1970: 1_751_900_000)
            tx.account = account
            return tx
        }

        // ---------- Device A: "Grupos PEN (run)" ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()
        let accA = systemAccount("Grupos PEN (\(run))")
        contextA.insert(accA)
        let txA = makeTx("sysmerge-a-\(run)", account: accA)
        contextA.insert(txA)
        try contextA.save()
        #expect(try await drainAndPush(engineA, contextA, pushA), "push A")

        // ---------- Device B: "Groups PEN (run)" (idioma distinto) ----------
        let dirB = freshDir(); defer { cleanup(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let accB = systemAccount("Groups PEN (\(run))")   // "Groups" < "Grupos" → GANADOR
        contextB.insert(accB)
        let txB = makeTx("sysmerge-b-\(run)", account: accB)
        contextB.insert(txB)
        try contextB.save()
        #expect(try await drainAndPush(engineB, contextB, pushB), "push B")
        let winnerShortcut = accB.shortcutID

        // El escenario va en closure y su error se RE-LANZA tras el cleanup: un `guard…return` aquí saltaría
        // el cleanup RP-1 y una fila `accounts` viva del user A rompería el `diverged == ["tx_items"]` del
        // test de snapshot hasta limpieza manual. (`defer` no admite `await` — de ahí la estructura.)
        struct PullIncomplete: Error, CustomStringConvertible {
            let which: String
            var description: String { "pull \(which) no completó" }
        }
        var scenarioError: Error?
        do {
            // ---------- DUPLICADO server-side demostrado a nivel de WIRE ----------
            // El merge corre DENTRO de `pullAndApplyOnce` (runPostPullReconcilers) — post-apply el duplicado
            // ya no es observable en el store (ESO es el wiring de producción funcionando). Se demuestra con
            // un pull read-only SIN apply (idiom del sweep de zombies de I11-2): 2 filas `accounts` vivas
            // del run en el stream.
            var wireAccountsOfRun = 0
            var wireCursor: Int64 = 0
            paging: while true {
                switch await pullA.pull(since: wireCursor, limit: 500) {
                case .page(let page):
                    for d in page.deltas where d.entityType == "accounts" && d.op == .upsert {
                        if case .string(let n) = d.fields["name"] ?? .null, n.contains(run) {
                            wireAccountsOfRun += 1
                        }
                    }
                    if page.deltas.isEmpty || page.maxServerSeq <= wireCursor { break paging }
                    wireCursor = page.maxServerSeq
                case .sessionExpired, .accountUnavailable, .transient:
                    throw PullIncomplete(which: "wire A (read-only)")
                }
            }
            #expect(wireAccountsOfRun == 2, "el backend debe tener 2 cuentas sistema PEN del run en el wire")

            // ---------- A pull+apply → el merge INTERNO del apply converge ----------
            guard case .completed = await engineA.pullAndApplyOnce(using: pullA, context: contextA) else {
                throw PullIncomplete(which: "A")
            }
            // El reconcile manual post-apply debe ser no-op (idempotencia: el pase interno ya mergeó).
            let statsA = CloudSyncReconciler.reconcileSystemEntities(context: contextA, lastUsedDefaults: isolatedDefaults())
            #expect(statsA.accountsMerged == 0, "el merge ya corrió dentro del apply; el manual es no-op")
            let aliveA = try contextA.fetch(FetchDescriptor<Account>(
                predicate: #Predicate { $0.isSystemAccount == true })).filter { $0.name.contains(run) }
            #expect(aliveA.count == 1)
            #expect(aliveA.first?.shortcutID == winnerShortcut, "ganador determinista = 'Groups PEN'")
            #expect(txA.account?.shortcutID == winnerShortcut, "TX de A re-apuntada al ganador")
            #expect(try await drainAndPush(engineA, contextA, pushA), "push del tombstone de A")

            // ---------- B pull (tombstone + update) + reconcile → MISMO ganador ----------
            guard case .completed = await engineB.pullAndApplyOnce(using: pullB, context: contextB) else {
                throw PullIncomplete(which: "B")
            }
            _ = CloudSyncReconciler.reconcileSystemEntities(context: contextB, lastUsedDefaults: isolatedDefaults())
            let aliveB = try contextB.fetch(FetchDescriptor<Account>(
                predicate: #Predicate { $0.isSystemAccount == true })).filter { $0.name.contains(run) }
            #expect(aliveB.count == 1, "B converge a 1 cuenta: \(aliveB.map(\.name))")
            #expect(aliveB.first?.shortcutID == winnerShortcut)
            #expect(try await drainAndPush(engineB, contextB, pushB), "push residual de B")
        } catch {
            scenarioError = error
        }

        // ---------- RP-1: cleanup a 0 VIVAS del run — corre SIEMPRE, incluso con el escenario fallido.
        // A y B tombstonean cada uno sus filas LOCALES (accA/txA viven en A; accB/txB en B), así el cleanup
        // no depende de que los pulls cruzados hayan completado. Residual aceptado: si el propio push del
        // cleanup falla (red caída total), las filas quedan — remedio manual en qa/cloud/README.
        try tombstoneRunRows(run: run, context: contextA)
        #expect(try await drainAndPush(engineA, contextA, pushA), "push cleanup A")
        try tombstoneRunRows(run: run, context: contextB)
        #expect(try await drainAndPush(engineB, contextB, pushB), "push cleanup B")
        if let scenarioError { throw scenarioError }

        // Verificación en un 3er store FRESCO: 0 cuentas + 0 TXs del run vivas en el backend.
        let dirC = freshDir(); defer { cleanup(dirC) }
        let contextC = try makeContext(dirC)
        let engineC = CloudSyncEngine()
        let pullC = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed = await engineC.pullAndApplyOnce(using: pullC, context: contextC) else {
            Issue.record("pull C no completó"); return
        }
        let liveAccC = try contextC.fetch(FetchDescriptor<Account>()).filter { $0.name.contains(run) }
        #expect(liveAccC.isEmpty, "0 cuentas vivas del run tras cleanup: \(liveAccC.map(\.name))")
        let liveTxC = try contextC.fetch(FetchDescriptor<TransactionItem>()).filter { ($0.note ?? "").contains(run) }
        #expect(liveTxC.isEmpty, "0 TXs vivas del run tras cleanup: \(liveTxC.count)")
    }

    // MARK: - Adopt-reconcile de huérfanas (DIFERIDOS #30)

    private struct AdoptWirePullFailed: Error, CustomStringConvertible {
        var description: String { "pull read-only del wire no completó" }
    }
    private struct AdoptReconcileNotCompleted: Error, CustomStringConvertible {
        let outcome: String
        var description: String { "runAdoptOrphanReconcile no completó: \(outcome)" }
    }

    /// Cuenta las cuentas VIVAS del `run` a nivel de WIRE (pull read-only SIN apply, idiom I11-2): identidades
    /// distintas de `accounts` con `op == .upsert` cuyo `name` porta el marcador del run.
    private func countRunAccountsAtWire(run: String, pull: SyncPullClient) async throws -> Int {
        var ids: Set<UUID> = []
        var cursor: Int64 = 0
        while true {
            switch await pull.pull(since: cursor, limit: 500) {
            case .page(let page):
                for d in page.deltas where d.entityType == "accounts" && d.op == .upsert {
                    if case .string(let n) = d.fields["name"] ?? .null, n.contains(run) {
                        ids.insert(d.syncID)
                    }
                }
                if page.deltas.isEmpty || page.maxServerSeq <= cursor { return ids.count }
                cursor = page.maxServerSeq
            case .sessionExpired, .accountUnavailable, .transient:
                throw AdoptWirePullFailed()
            }
        }
    }

    /// Device A (líder simulado) pushea 1 cuenta del run. Device B (adoptador, store propio) materializa el
    /// backend por pull, CREA una cuenta local que JAMÁS pushea (la "huérfana de ventana") y corre
    /// `runAdoptOrphanReconcile()`. A nivel de WIRE (read-only): antes = 1 cuenta del run, después = 2 → el
    /// backend GANÓ exactamente la huérfana, y B NO re-subió el corpus pulleado (el guard anti mass-upload
    /// funciona en la práctica). 2ª pasada = no-op. **RP-1: cleanup a 0 VIVAS del run** en closure con re-throw
    /// (una cuenta viva del user A rompería el `diverged == ["tx_items"]` estricto del snapshot test).
    @Test(.enabled(if: CloudSyncE2EStagingTests.isEnabled))
    func adoptOrphanReconcile_twoDevices_uploadsOnlyTheOrphanRow() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }
        let run = String(UUID().uuidString.prefix(8))
        let pushA = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushB = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pullB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let merkleB = SyncMerkleClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        func makeAccount(_ name: String) -> Account {
            Account(name: name, currencyCode: "PEN", colorHex: "#111111", iconName: "creditcard", type: "checking")
        }

        // ---------- Device A: pushea 1 cuenta del run ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()
        let accA = makeAccount("adopt-a-\(run)")
        contextA.insert(accA)
        try contextA.save()
        #expect(try await drainAndPush(engineA, contextA, pushA), "push A")

        // ---------- Device B: adoptador — materializa por pull + huérfana local jamás pusheada ----------
        let dirB = freshDir(); defer { cleanup(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        guard case .completed = await engineB.pullAndApplyOnce(using: pullB, context: contextB) else {
            Issue.record("pull inicial de B no completó"); return
        }
        let orphan = makeAccount("adopt-orphan-\(run)")
        contextB.insert(orphan)
        try contextB.save()
        let orphanShortcut = orphan.shortcutID

        var scenarioError: Error?
        do {
            // Pre-reconcile: el backend tiene 1 cuenta del run (la de A).
            #expect(try await countRunAccountsAtWire(run: run, pull: pullB) == 1,
                    "pre-reconcile: solo la cuenta de A en el wire")

            let sessionB = E2ECloudSession(userID: "adopt-b-\(run)")
            let executorB = MigrationWorkExecutor(
                engine: engineB, pushClient: pushB, pullClient: pullB, merkleClient: merkleB,
                accountClient: CloudAccountClient(baseURL: Self.workerURL), session: sessionB,
                context: contextB, storageDefaults: isolatedDefaults())

            // Reconcile: uploaded == 1 EXACTO — B no drena y su outbox solo lleva el enqueue del diff, así
            // que ==1 prueba que en ESTE push no viajó nada más que la huérfana. (La selectividad exacta del
            // diff — conocidas/tombstones fuera — la prueban los unit tests del executor.)
            switch await executorB.runAdoptOrphanReconcile() {
            case .completed(let uploaded, _):
                #expect(uploaded == 1, "exactamente la huérfana de ventana debe subirse")
            case .abortedEmptyBackend:
                throw AdoptReconcileNotCompleted(outcome: "abortedEmptyBackend")
            case .transient:
                throw AdoptReconcileNotCompleted(outcome: "transient")
            }

            // Wire (read-only): el backend GANÓ la huérfana → 2 cuentas del run.
            #expect(try await countRunAccountsAtWire(run: run, pull: pullB) == 2,
                    "post-reconcile: A + huérfana de B en el wire")

            // La huérfana viva en el wire porta el shortcutID de B (identidad preservada).
            var wireHasOrphanShortcut = false
            var cursor: Int64 = 0
            paging: while true {
                switch await pullB.pull(since: cursor, limit: 500) {
                case .page(let page):
                    for d in page.deltas where d.entityType == "accounts" && d.op == .upsert && d.syncID == orphanShortcut {
                        wireHasOrphanShortcut = true
                    }
                    if page.deltas.isEmpty || page.maxServerSeq <= cursor { break paging }
                    cursor = page.maxServerSeq
                case .sessionExpired, .accountUnavailable, .transient:
                    throw AdoptWirePullFailed()
                }
            }
            #expect(wireHasOrphanShortcut, "la huérfana viaja con el shortcutID de B")

            // 2ª pasada: la ex-huérfana ya está en el backend → diff vacío → no-op.
            #expect(await executorB.runAdoptOrphanReconcile() == .completed(uploaded: 0, identityAssigned: 0),
                    "2ª pasada idempotente = no-op")
        } catch {
            scenarioError = error
        }

        // ---------- RP-1: cleanup a 0 VIVAS del run — corre SIEMPRE (incl. escenario fallido). ----------
        try tombstoneRunRows(run: run, context: contextA)
        #expect(try await drainAndPush(engineA, contextA, pushA), "push cleanup A")
        try tombstoneRunRows(run: run, context: contextB)
        #expect(try await drainAndPush(engineB, contextB, pushB), "push cleanup B")
        if let scenarioError { throw scenarioError }

        // Verificación en un 3er store FRESCO: 0 cuentas del run vivas en el backend.
        let dirC = freshDir(); defer { cleanup(dirC) }
        let contextC = try makeContext(dirC)
        let engineC = CloudSyncEngine()
        let pullC = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        guard case .completed = await engineC.pullAndApplyOnce(using: pullC, context: contextC) else {
            Issue.record("pull C no completó"); return
        }
        let liveAccC = try contextC.fetch(FetchDescriptor<Account>()).filter { $0.name.contains(run) }
        #expect(liveAccC.isEmpty, "0 cuentas del run vivas tras cleanup: \(liveAccC.map(\.name))")
    }
}

// MARK: - Sesión e2e (seam I7c stub para el runtime)

/// Sesión mínima para el `CloudSyncRuntime` en e2e: identidad + renovable, sin attest (el JWT viaja por
/// los `tokenProvider` de los clients). `@MainActor` (el seam lo es).
@MainActor
private final class E2ECloudSession: CloudSyncSessionProviding {
    let currentUserID: String?
    let canRenewSession = true
    init(userID: String) { self.currentUserID = userID }
    func accessToken() async -> String? { nil }
    func attestToken() async throws -> String? { nil }
}
