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

    /// Producción: usa la instancia `shared` (MainActor-aislada — el default no puede vivir en la firma).
    init() {
        self.auth = .shared
    }

    /// Inyectable para tests.
    init(auth: CloudAuthService) {
        self.auth = auth
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

    /// COMENTARIO-GUARDIA (contrato I14): `nil` = "sin claim → proceed" para el gate de arranque del
    /// runtime. Aceptable SOLO mientras el runtime está DARK (`syncRuntimeEnabled == false`) — I14 DEBE
    /// cablear aquí el `AuthAction` resuelto por `AccountClaimDecision.decide(...)` tras el claim
    /// post-sign-in (regla C4: claim ANTES de cualquier save de onboarding). Encender el runtime en
    /// producción con este `nil` dejaría arrancar el sync sin pasar por el gate de claim. Override
    /// EXPLÍCITO (no la herencia silenciosa del default del protocolo) para que I14 lo encuentre.
    var claimAction: AccountClaimDecision.AuthAction? { nil }
}
