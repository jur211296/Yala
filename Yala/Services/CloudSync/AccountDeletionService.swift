//
//  AccountDeletionService.swift
//  Yala
//
//  Coordinador de "Eliminar mi cuenta" (G5-D1b, DARK). @MainActor @Observable, singleton `shared` para la
//  UI + `init(deps:)` inyectable para tests. Orquesta el borrado GDPR en un ORDEN CONGELADO anti
//  corpus-zombie (C1 del review): los teardowns paran los loops de sync ANTES del borrado personal —
//  SIN matar la auth, que se necesita VIVA para los RPCs.
//
//    1. `groups_forget_user` (SOLO si este binario es CAPAZ del canal de grupos — ver la decisión abajo).
//       Falla ⇒ `.failed(.groups)`, NADA local tocado, reintentable.
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
//  DECISIÓN, REVISADA EN D-R1 PASO 2 (2026-07-30): el paso 1 es condicional a
//  `groupsBackendCompiledCapability`, NO al getter compuesto.
//
//  La versión anterior lo condicionaba a `groupsBackendEnabled` con dos razones. (a) «Con el flag OFF el
//  usuario no tiene datos de grupos en el backend»: era cierto SOLO porque el compilado cortaba por
//  construcción. Con el compilado en `true` el término que queda es el remoto, que es un percent de
//  `GET /config` y no borra absolutamente nada del servidor — un usuario puede tener todo su corpus de
//  grupos en Supabase y leer el flag `false` por un kill, por un snapshot corrupto o por caer fuera del
//  bucket. Saltarse el paso ahí deja su `display_name` REAL vivo en `group_members` de OTRA gente, sin
//  `status='removed'` y sin bump de HLC (así que los devices de los co-members ni siquiera convergen por
//  LWW), y sus grupos con `owner_user_id = NULL`, que `transfer_group_ownership` clasifica como huérfano
//  y no auto-cura jamás. Eso es PII sobreviviendo a un borrado GDPR. El propio header de la migración
//  `g12_01` ya lo dejaba escrito: la cascada de `auth.users` es una belt INCOMPLETA que «NO sustituye a
//  groups_forget_user». (b) «`forgetUser()` lanza `sessionExpired` por su gate `ensureEligible`»: era y
//  sigue siendo real, y por eso las dos mitades son inseparables — cambiar solo esta lectura convertiría
//  una retención silenciosa en un BLOQUEO del borrado durante toda la ventana de kill. Lo resuelve el
//  gate propio de `forgetUser` (capacidad compilada + sesión), que deja `ensureEligible` COMPUESTO para
//  todo lo demás: las ENTRADAS (crear, unirse, invitar, aprobar, expulsar, salir) sí las corta el kill.
//
//  TRADE-OFF ACEPTADO, que conviene saber antes del incidente y no durante: el motivo más probable de un
//  kill remoto es que `/groups/*` esté roto, y con esta decisión el paso 1 pasa a ser obligatorio ⇒ el
//  RPC falla ⇒ el usuario no puede eliminar su cuenta mientras dure. Es retraso-de-borrado frente a
//  retención-permanente-de-PII, y la dirección elegida es la segunda. El RPC es no-op cuando no hay
//  filas, retry-safe y RPC-only (no toca el ModelContext), así que abrir su gate tiene radio de
//  explosión local cero.
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

        /// D7 (§3.3.4.2): higiene post-delete BEST-EFFORT. `clearCloudBeacon` no lanza (KV removeObject);
        /// `deleteCloudKitMarker` sí (fetch/save) y el flujo lo TRAGA — jamás condición del cierre.
        var clearCloudBeacon: @MainActor () -> Void
        var deleteCloudKitMarker: @MainActor (ModelContext) throws -> Void

        nonisolated static let live = Dependencies(
            canDelete: { CloudAuthService.shared.hasSession && !SecondarySessionStore.isActive() },
            // Capacidad COMPILADA (ver la DECISIÓN del header): el kill remoto apaga el canal, no borra
            // lo que el usuario ya subió al backend ni le quita el derecho de supresión.
            groupsBackendEnabled: { CloudSyncFlags.groupsBackendCompiledCapability },
            storageModeIsCloud: { CloudSyncFlags.storageMode == .cloud },
            forgetGroupsUser: {
                let client = GroupsMembershipClient(attestProvider: AttestSessionProvider.live)
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
                let client = CloudAccountClient(attestProvider: AttestSessionProvider.live)
                return await client.deleteAccount(jwt: jwt)
            },
            revokeSIWA: { await SIWATokenRevocation.revokeIfNeeded() },
            revokeGoogle: { await GoogleTokenRevocation.revokeIfNeeded() },
            closeLocalCloud: { await CloudSessionSignOut.shared.closeLocalAfterAccountDeletionCloud() },
            closeLocalGroupsOnly: { await CloudSessionSignOut.shared.closeLocalAfterAccountDeletionGroupsOnly(context: $0) },
            clearCloudBeacon: {
                CloudBeacon().clearCloudAccountLinked()
                CloudSyncBreadcrumb.accountDeletionBeaconCleared()
            },
            deleteCloudKitMarker: { context in
                // Borra el marcador local BEST-EFFORT. `guard !isEmpty` ANTES de cualquier save: en solo-grupos
                // (5b, mirror `.icloud` VIVO sobre el mainContext compartido) NO hay marcador → 0 filas → NO
                // se llama a save() (jamás flushea el grafo personal a medio importar — invariante quiescencia
                // (b)). En `.cloud` el marcador existe pero el mirror está OFF ⇒ el delete NO se exporta a
                // CloudKit (el file-wipe del boot borra el local; el record CloudKit queda como residual
                // documentado — R9 lee el FARO, no el marcador). El save() en `.cloud` es seguro: sin mirror
                // que replaye y el motor ya fue teardowneado.
                let markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
                guard !markers.isEmpty else { return }
                for marker in markers { context.delete(marker) }
                try context.save()
                CloudSyncBreadcrumb.accountDeletionMarkerDeleted(count: markers.count)
            }
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

        // 1) Anonimizar/transferir grupos server-side — con el binario CAPAZ, aunque el canal esté
        // apagado en remoto (ver la DECISIÓN del header).
        if deps.groupsBackendEnabled() {
            do {
                try await deps.forgetGroupsUser()
            } catch {
                MetricsService.accountDeletionFailed(step: Step.groups.rawValue)
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
            MetricsService.accountDeletionFailed(step: Step.delete.rawValue)
            phase = .failed(step: .delete)
            return
        }

        // 3.5) Higiene post-delete (D7, §3.3.4.2): limpiar el faro iCloud-KV + el marcador CloudKit locales,
        // para que un sign-in POSTERIOR del mismo Apple ID con OTRO provider vea `.notFound` honesto en vez
        // de un falso mismatch R9 (`ProviderMismatchLogic` lee SOLO el faro). BEST-EFFORT ABSOLUTO: jamás
        // condición del cierre local ni del arm (invariante kill-safety (d)) — si algo falla, breadcrumb y
        // el flujo sigue EXACTO como hoy (sin regresión posible). A diferencia del efecto homónimo de la
        // Reversa (que RE-throwea para quedar journaled-pendiente y reintentar con el mirror vivo), aquí NO
        // hay retry: la cuenta ya murió server-side y la higiene es cosmética. El faro (CRÍTICO para R9) se
        // limpia PRIMERO e incondicionalmente; el marcador después, con su fallo tragado. Corre tras el
        // teardown (paso 2) ⇒ sin push en vuelo que re-capture; jamás se alcanza si el delete falló (arriba).
        deps.clearCloudBeacon()
        do {
            try deps.deleteCloudKitMarker(context)
        } catch {
            CloudSyncBreadcrumb.accountDeletionMarkerCleanupFailed()
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
            MetricsService.accountDeletionCompleted(step: "cloud")
            phase = .awaitingRelaunch
        } else {
            if await deps.closeLocalGroupsOnly(context) {
                MetricsService.accountDeletionCompleted(step: "groupsOnly")
                phase = .awaitingRelaunch
            } else {
                // El borrado server-side YA ocurrió; la quiescencia local no llegó. Reintentable
                // (forgetUser/delete/teardowns idempotentes); el cierre local se completa en el retry.
                MetricsService.accountDeletionFailed(step: Step.localClose.rawValue)
                phase = .failed(step: .localClose)
            }
        }
    }
}
