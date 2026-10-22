//
//  CloudAccountClaimE2EStagingTests.swift
//  YalaTests / CloudSync
//
//  E2E REAL de `POST /account/claim` (I7c · gate de identidad §f.1) contra el Worker de STAGING con el
//  JWT del user A (password-grant, mismo harness que `CloudSyncE2EStagingTests` y los goldens del
//  gateway). Verifica el decoder Swift contra el WIRE REAL del RPC `claim_account`.
//
//  GATEADO por `YALA_CLOUD_E2E=1` **y** por `USER_A_PASS` en el entorno (credenciales vía
//  `StagingTestCredentials`, nunca literales en el árbol). TOLERANTE al estado de staging (AJUSTE review): asertamos SOLO que el
//  claim decodifica a UNO de los 3 estados válidos → `ClaimState` (el estado concreto depende de si la
//  fila `profiles` del sub preexiste, y NO se limpia aquí — un reset de staging no debe flakear). NO hay
//  e2e de Sign in with Apple en sim (imposible — device only; lo corre el owner por el panel DEBUG).
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct CloudAccountClaimE2EStagingTests {

    private nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_CLOUD_E2E"] == "1"
            && StagingTestCredentials.areAvailable(.a)
    }

    private static let supabaseURL = "https://fostjbbwstyuunmmefuk.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
    private static let workerURL = URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!

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

    @Test(.enabled(if: CloudAccountClaimE2EStagingTests.isEnabled))
    func claim_decodesToOneOfThreeValidStates() async throws {
        let jwt = try await login()
        let client = CloudAccountClient(baseURL: Self.workerURL)
        let outcome = await client.claim(jwt: jwt, deviceID: "i7c-e2e-device", provider: "apple")

        switch outcome {
        case .success(let state):
            // Estado concreto = función del estado vivo de staging (no se asserta duro). Se loguea.
            #expect([.created, .existingStable, .claimingInProgress].contains(state))
            #if DEBUG
            print("CloudAccountClaimE2E: claim → \(state)")
            #endif
        case .sessionExpired(let detail):
            Issue.record("claim 401 con JWT válido — attest/JWT del gate roto: \(detail)")
        case .accountUnavailable(let detail):
            Issue.record("claim 403 inesperado: \(detail)")
        case .transient(let detail):
            Issue.record("claim transient (red/Worker down): \(detail)")
        }

        // `exists` es un hint barato: no aserta el bool (depende del estado), solo que NO es error.
        let existsOutcome = await client.exists(jwt: jwt)
        if case .transient(let detail) = existsOutcome {
            Issue.record("exists transient: \(detail)")
        }
    }
}
