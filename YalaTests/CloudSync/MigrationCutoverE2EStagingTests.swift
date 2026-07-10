//
//  MigrationCutoverE2EStagingTests.swift
//  YalaTests / CloudSync
//
//  E2E REAL del cutover server-side (I10-wiring w6) contra el Worker de STAGING + Supabase staging:
//  `CloudAccountClient.claim(migration:)` + `migrationProgress('cutover'|'complete')` end-to-end (verifica
//  el JWT ES256 + los RPC `claim_account`/`migration_progress` con RLS del usuario). Usa el 2º usuario de
//  test (B) para NO ensuciar el estado del user A que consumen los otros e2e. Deja la fila de B en estado
//  estable (mip=false); la limpieza pre-run de la suite de goldens la resetea si hace falta.
//
//  GATEADO por `YALA_CLOUD_E2E=1` (correr con `TEST_RUNNER_YALA_CLOUD_E2E=1 xcodebuild test …`). NO corre
//  en CI ni en /test-smart (aparece skipped). anon key + password grant de B; NUNCA service_role.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct MigrationCutoverE2EStagingTests {

    private nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_CLOUD_E2E"] == "1"
    }

    private static let supabaseURL = "https://fostjbbwstyuunmmefuk.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
    private static let workerURL = URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!
    private static let device = "i10-cutover-e2e-device"

    // MARK: - Helpers

    private func login() async throws -> (jwt: String, sub: String) {
        var request = URLRequest(url: URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=password")!)
        request.httpMethod = "POST"
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"email":"i5-user-b@test.yala","password":"I5-Passw0rd-B!"}"#.utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable { let access_token: String? }
        guard let token = try JSONDecoder().decode(TokenResponse.self, from: data).access_token else {
            throw CutoverE2EError.loginFailed
        }
        return (token, Self.decodeSub(token))
    }

    private nonisolated static func decodeSub(_ jwt: String) -> String {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return "" }
        var p = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while p.count % 4 != 0 { p += "=" }
        guard let data = Data(base64Encoded: p),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = obj["sub"] as? String else { return "" }
        return sub
    }

    /// PATCH directo a `profiles` con el JWT del dueño (RLS UPDATE lo permite) — fija estado de líder.
    @discardableResult
    private func patchProfile(jwt: String, sub: String, patch: [String: Any]) async throws -> Int {
        var request = URLRequest(url: URL(string: "\(Self.supabaseURL)/rest/v1/profiles?id=eq.\(sub)")!)
        request.httpMethod = "PATCH"
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: patch)
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    private func readProfile(jwt: String, sub: String) async throws -> [String: Any]? {
        var request = URLRequest(url: URL(string:
            "\(Self.supabaseURL)/rest/v1/profiles?id=eq.\(sub)&select=migrated_at,migration_in_progress,leader_device_id")!)
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first
    }

    private func makeClient() -> CloudAccountClient {
        CloudAccountClient(baseURL: Self.workerURL)
    }

    private enum CutoverE2EError: Error { case loginFailed }

    // MARK: - Tests

    @Test("cutover→complete: migration_progress avanza el journal server-side (user B)",
          .enabled(if: MigrationCutoverE2EStagingTests.isEnabled))
    func cutoverThenComplete() async throws {
        let (jwt, sub) = try await login()
        let client = makeClient()

        // Asegura una cuenta con ESTE device como líder (migrated_at limpio).
        #expect(try await patchProfile(jwt: jwt, sub: sub, patch: [
            "migration_in_progress": true, "leader_device_id": Self.device,
            "migration_updated_at": ISO8601DateFormatter().string(from: Date()), "migrated_at": NSNull(),
        ]) < 300)

        // cutover → ok + migrated_at estampado.
        #expect(await client.migrationProgress(jwt: jwt, deviceID: Self.device, action: "cutover") == .ok)
        let afterCutover = try await readProfile(jwt: jwt, sub: sub)
        #expect(afterCutover?["migrated_at"] is String, "migrated_at estampado tras cutover")

        // complete → ok + migration_in_progress=false.
        #expect(await client.migrationProgress(jwt: jwt, deviceID: Self.device, action: "complete") == .ok)
        let afterComplete = try await readProfile(jwt: jwt, sub: sub)
        #expect((afterComplete?["migration_in_progress"] as? Bool) == false)

        // Limpia el estado in-progress.
        _ = try await patchProfile(jwt: jwt, sub: sub, patch: [
            "migration_in_progress": false, "leader_device_id": NSNull(),
        ])
    }

    @Test("other_leader: un device que NO es el líder registrado → .otherLeader (user B)",
          .enabled(if: MigrationCutoverE2EStagingTests.isEnabled))
    func otherLeaderRejected() async throws {
        let (jwt, sub) = try await login()
        let client = makeClient()

        #expect(try await patchProfile(jwt: jwt, sub: sub, patch: [
            "migration_in_progress": true, "leader_device_id": "some-other-device",
            "migration_updated_at": ISO8601DateFormatter().string(from: Date()),
        ]) < 300)

        #expect(await client.migrationProgress(jwt: jwt, deviceID: Self.device, action: "cutover") == .otherLeader)

        _ = try await patchProfile(jwt: jwt, sub: sub, patch: [
            "migration_in_progress": false, "leader_device_id": NSNull(),
        ])
    }
}
