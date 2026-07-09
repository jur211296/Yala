//
//  PrefsSyncE2EStagingTests.swift
//  YalaTests / CloudSync
//
//  E2E REAL del sync de preferencias (I13) contra el Worker de STAGING: enqueue → push (POST /prefs/push,
//  RPC apply_pref LWW server-side) → pull en un "device B" (GET /prefs/pull) → merge produce los valores.
//  Verifica el decoder Swift contra los BYTES REALES del wire (value:string|null, server_seq numérico) y
//  el LWW por HLC (push stale → noop, espeja el golden 8 de sync.goldens.test.ts desde Swift).
//
//  GATEADO por `YALA_CLOUD_E2E=1` (correr con `TEST_RUNNER_YALA_CLOUD_E2E=1 xcodebuild test …`). NO corre
//  en CI ni en /test-smart (aparece skipped). Mismo user/credenciales que CloudSyncE2EStagingTests (anon
//  key + password grant del user A). En staging `ENFORCE != "enforce"` → el JWT basta (sin attest), igual
//  que `/sync/*`. Los values llevan un marker único por run — sin cleanup posible (DELETE revocado).
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct PrefsSyncE2EStagingTests {

    private nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_CLOUD_E2E"] == "1"
    }

    // Staging (mismo target que CloudSyncE2EStagingTests / qa/cloud).
    private static let supabaseURL = "https://fostjbbwstyuunmmefuk.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
    private static let workerURL = URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("prefs-e2e-\(UUID().uuidString)", isDirectory: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

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

    // MARK: - Round-trip: push 3 keys (string/bool/int) → pull en B → merge produce los valores

    @Test(.enabled(if: PrefsSyncE2EStagingTests.isEnabled))
    func roundTrip_pushThreeKinds_pullMaterializesInB() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }
        let marker = "i13-\(UUID().uuidString.prefix(8))"

        // ---------- Device A: enqueue + push ----------
        let dirA = freshDir(); defer { cleanup(dirA) }
        let outboxA = PrefsOutbox(directoryURL: dirA)
        // 3 keys representativas: string (userName) · bool (colorfulIcons) · int (decimalPlaces).
        try outboxA.enqueue(key: PrefSyncKey.userName.rawValue, userID: "u", value: .string(String(marker)))
        try outboxA.enqueue(key: PrefSyncKey.colorfulIcons.rawValue, userID: "u", value: .bool(true))
        // Int NO-CERO: con local ausente (=0 por paridad UserDefaults), un 0 daría `.skip` (diff-check
        // correcto) → usamos 2 para que el merge produzca `.set` de forma observable.
        try outboxA.enqueue(key: PrefSyncKey.decimalPlaces.rawValue, userID: "u", value: .int(2))

        let entriesA = outboxA.entries(forUserID: "u")
        let wireA = entriesA.map { WirePref(key: $0.key, value: $0.entry.value, hlc: $0.entry.hlc) }
        let clientA = PrefsSyncClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pushA = await clientA.push(wireA)
        guard case .completed(let resultsA) = pushA else { Issue.record("push A: \(pushA)"); return }
        #expect(resultsA.count == 3)
        #expect(resultsA.allSatisfy { $0.reason == nil }, "todos aplican/noop sin error: \(resultsA)")

        // ---------- Device B: pull → merge ----------
        let clientB = PrefsSyncClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)
        let pullB = await clientB.pull(since: 0)
        guard case .page(let page) = pullB else { Issue.record("pull B: \(pullB)"); return }

        let byKey = Dictionary(page.prefs.map { ($0.key, $0) }, uniquingKeysWith: { _, b in b })
        // Los valores del backend (LWW: nuestro run tiene el HLC más alto de este proceso).
        #expect(byKey[PrefSyncKey.userName.rawValue]?.value == String(marker))
        #expect(byKey[PrefSyncKey.colorfulIcons.rawValue]?.value == "true")
        #expect(byKey[PrefSyncKey.decimalPlaces.rawValue]?.value == "2")

        // El merge (client-side) produce los valores tipados (sobre un local vacío → set).
        for pref in page.prefs where [PrefSyncKey.userName.rawValue, PrefSyncKey.colorfulIcons.rawValue,
                                       PrefSyncKey.decimalPlaces.rawValue].contains(pref.key) {
            guard let key = PrefSyncKey(rawValue: pref.key), let value = pref.value else { continue }
            let remote = PrefValueCodec.decode(value, as: key.kind)
            let decision = PreferenceMergeLogic.decide(key: key, remote: remote, local: nil)
            #expect(decision.write == .set(remote), "merge de \(key) debe producir \(remote)")
        }

        // El cursor de B avanza de forma durable.
        try outboxA.setPullCursor(page.maxServerSeq)
        #expect(outboxA.pullCursor == page.maxServerSeq)
        #expect(page.maxServerSeq > 0)
    }

    // MARK: - LWW: push stale (HLC menor) → noop (espeja golden 8 TS)

    @Test(.enabled(if: PrefsSyncE2EStagingTests.isEnabled))
    func lww_stalePush_isNoop() async throws {
        let jwt = try await login()
        let tokenProvider: () async -> String? = { jwt }
        let client = PrefsSyncClient(baseURL: Self.workerURL, tokenProvider: tokenProvider)

        // Key propia de este test para no cruzarse con el round-trip.
        let key = PrefSyncKey.voiceLanguage.rawValue
        let node = NodeID.generate()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let fresh = try HLC(physicalMs: nowMs, counter: 0, nodeID: node)
        let stale = try HLC(physicalMs: nowMs - 60_000, counter: 0, nodeID: node)  // 60s más viejo

        // 1) Push FRESH → debe ganar (applied) contra lo que hubiera.
        let freshMarker = "fresh-\(UUID().uuidString.prefix(6))"
        let r1 = await client.push([WirePref(key: key, value: String(freshMarker), hlc: fresh.description)])
        guard case .completed(let res1) = r1 else { Issue.record("push fresh: \(r1)"); return }
        #expect(res1.first?.reason == nil)

        // 2) Push STALE (HLC menor) → noop (LWW server-side lo descarta).
        let staleMarker = "stale-\(UUID().uuidString.prefix(6))"
        let r2 = await client.push([WirePref(key: key, value: String(staleMarker), hlc: stale.description)])
        guard case .completed(let res2) = r2 else { Issue.record("push stale: \(r2)"); return }
        #expect(res2.first?.status == .noop, "el push stale debe ser noop: \(res2)")

        // 3) Pull → el valor sigue siendo el FRESH (el stale no lo pisó).
        let pull = await client.pull(since: 0)
        guard case .page(let page) = pull else { Issue.record("pull: \(pull)"); return }
        let value = page.prefs.first { $0.key == key }?.value
        #expect(value == String(freshMarker), "el valor debe seguir en fresh, no stale (got: \(value ?? "nil"))")
    }
}
