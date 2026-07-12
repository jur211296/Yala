//
//  LiveCloudSessionProvider.swift
//  Yala
//
//  Implementación VIVA de `CloudSyncSessionProviding` (I7c): reemplaza al `NoopCloudSessionProvider`
//  de I9 cuando `CloudBackendConfig.isConfigured`. Puentea la sesión real de `CloudAuthService.shared`
//  (JWT de Supabase + identidad) y el token de App Attest (`AppAttestClient.shared`, REUSO — ya produce
//  el token de sesión del Worker) al `CloudSyncRuntime`.
//
//  DARK: el runtime sigue apagado tras `CloudSyncFlags.syncRuntimeEnabled == false`. Aunque se encendiera,
//  sin sign-in `currentUserID == nil` → el runtime cae en `idleSignedOut` (ya probado en I9). El sign-in
//  real (via el panel DEBUG o I14) lo despierta.
//

import Foundation

@MainActor
final class LiveCloudSessionProvider: CloudSyncSessionProviding {

    private let auth: CloudAuthService
    private let claimStore: CloudClaimActionStore

    /// Producción: usa la instancia `shared` (MainActor-aislada — el default no puede vivir en la firma).
    init() {
        self.auth = .shared
        self.claimStore = .shared
    }

    /// Inyectable para tests. `claimStore` nil → `.shared` (resuelto en el cuerpo @MainActor: un default
    /// `.shared` en la firma se evalúa nonisolated → warning Swift 6).
    init(auth: CloudAuthService, claimStore: CloudClaimActionStore? = nil) {
        self.auth = auth
        self.claimStore = claimStore ?? .shared
    }

    /// El `sub` de la sesión de Supabase (lowercase). `nil` = sin sesión.
    var currentUserID: String? { auth.currentUserID }

    /// JWT vigente (el SDK auto-refresca). `nil` = sin sesión / refresh fallido.
    func accessToken() async -> String? { await auth.accessToken() }

    /// Contrato I7c: `true` mientras HAY sesión almacenada (token vigente/renovable). Ver `CloudAuthService`.
    var canRenewSession: Bool { auth.canRenewSession }

    /// Token de sesión de App Attest (REUSO `AppAttestClient`). Lanza `AppAttestError` — el runtime lo
    /// clasifica transient/terminal con `AttestSyncGate`.
    func attestToken() async throws -> String? {
        try await AppAttestClient.shared.currentSessionToken()
    }

    /// I14 (P6): el `AuthAction` resuelto tras el claim post-sign-in (§f.1), LEÍDO del `CloudClaimActionStore`
    /// para el `currentUserID` actual. Los write-sites lo estampan (`MigrationWorkExecutor.performClaim` en
    /// la migración; `runAdoptFlow` en el adopt). `nil` = sin sesión O identidad no-claimeada → en `.cloud`
    /// el guard de identidad del runtime lo deja `.idle` (regla C4: el sync no arranca sin pasar por el
    /// contrato de claim; un Apple ID distinto en un device migrado no pushea el corpus del dueño).
    var claimAction: AccountClaimDecision.AuthAction? {
        guard let userID = auth.currentUserID else { return nil }
        return claimStore.action(forUserID: userID)
    }
}
