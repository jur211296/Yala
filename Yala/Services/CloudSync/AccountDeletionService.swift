//
//  AccountDeletionService.swift
//  Yala
//
//  Coordinador de "Eliminar mi cuenta" (G5-D1b, DARK). @MainActor @Observable, singleton `shared` para la
//  UI + `init(deps:)` inyectable para tests. Orquesta el borrado GDPR en un ORDEN CONGELADO anti
//  corpus-zombie (C1 del review): los teardowns paran los loops de sync ANTES del borrado personal —
//  SIN matar la auth, que se necesita VIVA para los RPCs.
//
//    1. `groups_forget_user` (SOLO si el canal de grupos está activo — ver la decisión abajo). Falla ⇒
//       `.failed(.groups)`, NADA local tocado, reintentable.
//    2. Teardowns (`CloudSyncRuntime.teardownGuestSession` + `GroupsSyncClient.teardownForSignOut`): paran
//       los ciclos; sin esto un push en vuelo RE-SUBIRÍA filas al backend recién vaciado.
//    3. `POST /account/delete` (attest). Falla ⇒ `.failed(.delete)`, reintentable (teardowns idempotentes).
//    4. Éxito ⇒ 4a SIWA revoke REAL (B1, 5.1.1(v) — `SIWATokenRevocation.revokeIfNeeded()`) + 4b Google
//       disconnect (sesión 3 Google Sign-In — `GoogleTokenRevocation.revokeIfNeeded()`, match doble;
//       ambos best-effort: jamás bloquean el borrado, cada uno con skip natural — a lo sumo UNO tiene
//       par cuyo sub/user matchea) + 4c cierre LOCAL por modo, reusando la red terminal de
//       `CloudSessionSignOut` (fase viva `.awaitingRelaunch` ⇒ cero red duplicada). SIN push-all (los
//       datos ya murieron server-side).
//
//  DECISIÓN de sesión (documentada): el paso 1 es CONDICIONAL a `groupsBackendEnabled`. Con el flag OFF el
//  usuario no tiene datos de grupos en el backend ⇒ no hay nada que anonimizar/transferir; además
//  `GroupBackendMembershipService.forgetUser()` lanza `sessionExpired` por su gate `ensureEligible` con el
//  flag OFF (un falso fallo que bloquearía el borrado). Saltarlo es correcto en AMBOS modos (en solo-grupos
//  el flag está ON por construcción).
//

import Foundation
import SwiftData

/// Lógica PURA de visibilidad de la fila destructiva (testeable sin UI).
enum AccountDeletionRowLogic {
    /// La fila "Eliminar mi cuenta" solo se ofrece con una sesión backend VIVA y fuera de la sesión
    /// secundaria (M1, RESIDUAL v1) y del modo group-invite (onboarding de CKShare, sin sesión backend).
    static func shouldShow(hasSession: Bool, secondaryActive: Bool, isGroupInviteMode: Bool) -> Bool {
        hasSession && !secondaryActive && !isGroupInviteMode
    }
}

@MainActor
@Observable
final class AccountDeletionService {

    static let shared = AccountDeletionService()

    enum Step: String, Equatable {
        case groups         // groups_forget_user falló
        case delete         // POST /account/delete falló
        case localClose     // la quiescencia del cierre solo-grupos no llegó
    }

    enum Phase: Equatable {
        case idle
        /// Borrado en curso (spinner + fila deshabilitada).
        case working
        /// Un paso falló: NADA local se armó, la sesión sigue viva → el usuario reintenta.
        case failed(step: Step)
        /// Borrado completo + cierre local armado → el cover terminal (de `CloudSessionSignOut`) manda.
        case awaitingRelaunch
    }

    private(set) var phase: Phase = .idle

    // MARK: - Dependencias inyectables

    struct Dependencies {
        var canDelete: @MainActor () -> Bool
        var groupsBackendEnabled: () -> Bool
        var storageModeIsCloud: () -> Bool
        var forgetGroupsUser: @MainActor () async throws -> Void
        var teardown: @MainActor () -> Void
        var deletePersonalAccount: @MainActor () async -> DeleteOutcome
        var revokeSIWA: @MainActor () async -> Void
        var revokeGoogle: @MainActor () async -> Void
        var closeLocalCloud: @MainActor () async -> Void
        var closeLocalGroupsOnly: @MainActor (ModelContext) async -> Bool

        /// Attest de producción para los dos clientes con attest (delete + groups RPC). `nonisolated` para
        /// poder referenciarlo desde el init nonisolated de `shared` (default-actor-isolation = MainActor);
        /// el closure `@MainActor` se FORMA aquí sin ejecutarse.
        nonisolated static let liveAttest: @MainActor () async -> String? = {
            try? await AppAttestClient.shared.currentSessionToken()
        }

        nonisolated static let live = Dependencies(
            canDelete: { CloudAuthService.shared.hasSession && !SecondarySessionStore.isActive() },
            groupsBackendEnabled: { CloudSyncFlags.groupsBackendEnabled },
            storageModeIsCloud: { CloudSyncFlags.storageMode == .cloud },
            forgetGroupsUser: {
                let client = GroupsMembershipClient(attestProvider: Dependencies.liveAttest)
                _ = try await GroupBackendMembershipService(client: client).forgetUser()
            },
            teardown: {
                CloudSyncRuntime.shared?.teardownGuestSession()
                GroupsSyncClient.shared.teardownForSignOut()
            },
            deletePersonalAccount: {
                guard let jwt = await CloudAuthService.shared.accessToken(), !jwt.isEmpty else {
                    return .sessionExpired(detail: "no jwt")
                }
                let client = CloudAccountClient(attestProvider: Dependencies.liveAttest)
                return await client.deleteAccount(jwt: jwt)
            },
            revokeSIWA: { await SIWATokenRevocation.revokeIfNeeded() },
            revokeGoogle: { await GoogleTokenRevocation.revokeIfNeeded() },
            closeLocalCloud: { await CloudSessionSignOut.shared.closeLocalAfterAccountDeletionCloud() },
            closeLocalGroupsOnly: { await CloudSessionSignOut.shared.closeLocalAfterAccountDeletionGroupsOnly(context: $0) }
        )
    }

    private let deps: Dependencies

    init(deps: Dependencies = .live) {
        self.deps = deps
    }

    /// Vuelve a `.idle` tras un `.failed` (el usuario cerró el alert sin reintentar).
    func acknowledgeFailure() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: - Flujo

    /// `context`: el cierre local solo-grupos purga el outbox/cursor de grupos (viven en el store sync-meta,
    /// alcanzable por el mainContext compartido). Reentrante desde `.failed` (retry); no-op si ya en curso o
    /// terminal.
    func deleteAccount(context: ModelContext) async {
        switch phase {
        case .working, .awaitingRelaunch: return
        case .idle, .failed: break
        }
        guard deps.canDelete() else { return }  // defensivo: sin sesión backend no hay nada que borrar

        phase = .working

        // 1) Anonimizar/transferir grupos server-side — SOLO con el canal activo (ver la decisión del header).
        if deps.groupsBackendEnabled() {
            do {
                try await deps.forgetGroupsUser()
            } catch {
                TelemetryService.accountDeletionFailed(step: Step.groups.rawValue)
                phase = .failed(step: .groups)
                return
            }
        }

        // 2) Parar los loops de sync (auth AÚN viva para el RPC de borrado).
        deps.teardown()

        // 3) HARD DELETE del corpus personal server-side.
        switch await deps.deletePersonalAccount() {
        case .success:
            break
        case .sessionExpired, .transient:
            TelemetryService.accountDeletionFailed(step: Step.delete.rawValue)
            phase = .failed(step: .delete)
            return
        }

        // 4a) SIWA revoke REAL (B1, 5.1.1(v)) — best-effort: jamás lanza ni bloquea el cierre. El orden
        // congelado (revoke DESPUÉS del delete: jamás revocar si el borrado falló) SIGUE siendo válido con
        // B2 (el RPC `delete_personal_account` ahora borra también `auth.users`): la verificación del JWT
        // en el Worker es STATELESS (jose + JWKS, `gateway/src/sync/userauth.ts` — no consulta GoTrue) y
        // el revoke contra Apple no toca Supabase; borrar la fila de GoTrue NO invalida el JWT en vuelo.
        // Matiz del retry (INFO #7 del review): si el revoke falla pero el cierre local COMPLETA
        // (`.awaitingRelaunch`), no hay retry — el par queda custodiado en el Keychain (jamás filtrado) y
        // el próximo sign-in lo sobreescribe; el retry solo existe si el flujo cae a `.failed(.localClose)`.
        await deps.revokeSIWA()

        // 4b) Google disconnect (sesión 3 — simetría 5.1.1(v)): mismo contrato best-effort que 4a, con
        // MATCH DOBLE (par de ESTA cuenta + sesión SDK del MISMO humano — hazards §0 del plan). Cada
        // revoke tiene skip natural: a lo sumo uno tiene par cuyo sub matchea la sesión que se borra.
        await deps.revokeGoogle()

        // 4c) Cierre LOCAL por modo, reusando la red terminal de CloudSessionSignOut.
        if deps.storageModeIsCloud() {
            await deps.closeLocalCloud()
            TelemetryService.accountDeletionCompleted(step: "cloud")
            phase = .awaitingRelaunch
        } else {
            if await deps.closeLocalGroupsOnly(context) {
                TelemetryService.accountDeletionCompleted(step: "groupsOnly")
                phase = .awaitingRelaunch
            } else {
                // El borrado server-side YA ocurrió; la quiescencia local no llegó. Reintentable
                // (forgetUser/delete/teardowns idempotentes); el cierre local se completa en el retry.
                TelemetryService.accountDeletionFailed(step: Step.localClose.rawValue)
                phase = .failed(step: .localClose)
            }
        }
    }
}
