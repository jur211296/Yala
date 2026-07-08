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

        // Bonus: las tablas no cableadas del historial de staging (p.ej. budgets del golden 10 del
        // gateway) deben haber caído en cuarentena con los bytes reales del wire, nunca descartadas.
        let quarantined = try contextB.fetch(FetchDescriptor<SyncQuarantine>())
        #expect(quarantined.allSatisfy { !$0.rawDelta.isEmpty })

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
