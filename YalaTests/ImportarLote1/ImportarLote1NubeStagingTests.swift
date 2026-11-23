//
//  ImportarLote1NubeStagingTests.swift
//  YalaTests
//
//  Mide un import de miles de filas en modo nube contra STAGING (ticket
//  `import-of-thousands-of-rows-in-cloud-mode-is-unmeasured`, H15 de la auditoría del import 2.2): el import en el
//  dispositivo A, el drain y la subida, la bajada en un dispositivo B que ya estaba al día, y lo mismo con «Deshacer
//  importación». No afirma tiempos: imprime `MEDIDA-NUBE …` para el ticket. Sí afirma que B ve las filas y que, tras
//  deshacer, deja de verlas.
//
//  GATEADO como `CloudSyncE2EStagingTests`: `YALA_CLOUD_E2E=1` y la contraseña del usuario sintético A
//  (`TEST_RUNNER_YALA_CLOUD_E2E=1 TEST_RUNNER_USER_A_PASS=… TEST_RUNNER_YALA_NUBE_FILAS=3000`). Staging, nunca
//  producción. Cada corrida deja sus filas borradas en el usuario A (staging no admite DELETE).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Importar lote 1 · miles de filas en modo nube (staging)", .serialized)
@MainActor
struct ImportarLote1NubeStagingTests {

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_CLOUD_E2E"] == "1" && StagingTestCredentials.areAvailable(.a)
    }

    private static let supabaseURL = "https://fostjbbwstyuunmmefuk.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
    private static let workerURL = URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!

    private var rows: Int {
        Int(ProcessInfo.processInfo.environment["YALA_NUBE_FILAS"] ?? "") ?? 3_000
    }

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nube-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "ImportNube-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "ImportNube-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "ImportNube-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func login() async throws -> String {
        var request = URLRequest(url: URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=password")!)
        request.httpMethod = "POST"
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try StagingTestCredentials.passwordGrantBody(for: .a)
        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable { let access_token: String? }
        guard let token = try JSONDecoder().decode(TokenResponse.self, from: data).access_token else {
            throw CocoaError(.coderValueNotFound)
        }
        return token
    }

    /// Baja hasta vaciar la cola: `pullAndApplyOnce` para en 50 páginas.
    private func pullUntilDrained(_ engine: CloudSyncEngine, _ client: SyncPullClient, _ context: ModelContext)
        async -> Int {
        var pages = 0
        for _ in 0..<40 {
            let outcome = await engine.pullAndApplyOnce(using: client, context: context)
            guard case .completed(let applied) = outcome else {
                Issue.record("pull no completó: \(outcome)")
                return pages
            }
            pages += applied
            if outcome.drainedTheQueue() { break }
        }
        return pages
    }

    /// Sube todo lo que haya en el outbox de A y devuelve cuántas filas subió.
    private func drainAndPush(
        _ engine: CloudSyncEngine, _ client: SyncPushClient, _ context: ModelContext
    ) async throws -> Int {
        #expect(engine.drainOnce(context: context))
        let outbox = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        let outcome = await client.push(outbox)
        guard case .completed(let results) = outcome else {
            Issue.record("push no completó: \(outcome)")
            return 0
        }
        await client.applyResults(results, rows: outbox, engine: engine, context: context)
        return outbox.count
    }

    private func marked(_ marker: String, in context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<TransactionItem>()).filter { ($0.note ?? "").hasPrefix(marker) }.count
    }

    @Test(.enabled(if: ImportarLote1NubeStagingTests.isEnabled))
    func importAndUndo_inCloudMode_reachTheOtherDevice() async throws {
        let jwt = try await login()
        let tokens: () async -> String? = { jwt }
        let clock = ContinuousClock()
        let marker = "import-nube-\(UUID().uuidString.prefix(8))"

        // B se pone al día ANTES, para medir solo lo que trae el import.
        let dirB = try freshDir(); defer { discardTestStoreDirectory(dirB) }
        let contextB = try makeContext(dirB)
        let engineB = CloudSyncEngine()
        let pullB = SyncPullClient(baseURL: Self.workerURL, tokenProvider: tokens)
        let catchUp = await clock.measure { _ = await pullUntilDrained(engineB, pullB, contextB) }

        // A: una cuenta, una categoría y el import.
        let dirA = try freshDir(); defer { discardTestStoreDirectory(dirA) }
        let contextA = try makeContext(dirA)
        let engineA = CloudSyncEngine()
        let pushA = SyncPushClient(baseURL: Self.workerURL, tokenProvider: tokens)
        let account = Account(name: "Banco \(marker)", currencyCode: "PEN", colorHex: "#6366F1",
                              iconName: "creditcard", type: "General")
        contextA.insert(account)
        try contextA.save()

        var lines = ["date,amount,currency,category,subcategory,tags,note"]
        for index in 0..<rows {
            lines.append("2026-\(String(format: "%02d", 1 + index % 10))-\(String(format: "%02d", 1 + index % 28)),"
                         + "-\(1 + index % 90).50,PEN,Comida \(marker),Café,,\(marker) \(index)")
        }
        let table = try ImportFileReader.parseCSV(lines.joined(separator: "\n"))
        let importTime = try clock.measure {
            _ = try TransactionCSVImportService.importTable(
                table, destination: .account(account), in: contextA, allowCreatingNewCategories: true,
                skippingInvalidRows: true)
            try contextA.save()
        }
        #expect(try marked(marker, in: contextA) == rows)

        var pushed = 0
        let pushTime = try await clock.measure { pushed = try await drainAndPush(engineA, pushA, contextA) }
        var pagesB = 0
        let pullTime = await clock.measure { pagesB = await pullUntilDrained(engineB, pullB, contextB) }
        #expect(try marked(marker, in: contextB) == rows, "B no ve todas las filas importadas en A.")

        // Deshacer en A: borrar por tandas, subir los borrados y bajarlos en B.
        let imported = try contextA.fetch(FetchDescriptor<TransactionItem>())
            .filter { ($0.note ?? "").hasPrefix(marker) }
        let undoTime = try await clock.measure {
            _ = try await ImportUndoService.undoInBatches(in: contextA, matching: imported)
        }
        var pushedUndo = 0
        let pushUndoTime = try await clock.measure { pushedUndo = try await drainAndPush(engineA, pushA, contextA) }
        var pagesUndo = 0
        let pullUndoTime = await clock.measure { pagesUndo = await pullUntilDrained(engineB, pullB, contextB) }
        #expect(try marked(marker, in: contextB) == 0, "B sigue viendo filas que A deshizo.")

        print("MEDIDA-NUBE filas=\(rows) ponerAlDiaB=\(catchUp) importarA=\(importTime) "
              + "drenarYSubirA=\(pushTime) filasSubidas=\(pushed) bajarB=\(pullTime) paginasB=\(pagesB) "
              + "deshacerA=\(undoTime) drenarYSubirBorrados=\(pushUndoTime) borradosSubidos=\(pushedUndo) "
              + "bajarBorradosB=\(pullUndoTime) paginasBorradosB=\(pagesUndo)")
    }
}
