//
//  GroupJoinIntentTracker.swift
//  Yala
//
//  Fachada @Observable del join intent para la UI (GroupInviteOnboardingView y
//  el banner de GroupsContainerView). La alimenta
//  (fases de accept) y `GroupJoinReconciler` (fases de member). La vista computa
//  su step con `GroupInviteOnboardingLogic.step(...)` — pure logic; este tracker
//  solo publica la fase real.
//
//  Nota: `SessionState.dataVersion` NO sirve como señal aquí — su bump se difiere
//  a navegación/onAppear (`applyPendingChangesIfNeeded`), que con un
//  fullScreenCover abierto y el usuario quieto puede no correr nunca.
//
//  Trackea UNA zona (el accept más reciente): el onboarding fresh solo maneja un
//  invite a la vez. Los callbacks de otras zonas se ignoran salvo que no haya
//  zona trackeada.
//

import Foundation
import OSLog

@MainActor
@Observable
final class GroupJoinIntentTracker {

    static let shared = GroupJoinIntentTracker()

    private(set) var phase: JoinIntentPhase = .idle
    private(set) var zoneName: String?

    private let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    private init() {}

    // MARK: - Ciclo de vida

    /// Consumido/limpiado: al ver `.active` en UI, al descartar el banner de
    /// expirado, y en `AppRouter.resetAll()`.
    func clear() {
        phase = .idle
        zoneName = nil
    }

    /// Re-deriva la fase en boot a partir del intent persistido + estado local.
    /// Llamado por el reconciliador (trigger .boot) vía los callbacks note*.
    func rehydrate(zoneName: String) {
        guard self.zoneName == nil else { return }
        self.zoneName = zoneName
        if phase == .idle { phase = .waitingForZone }
    }

    // MARK: - Callbacks del lado sync (acceptShare)

    func noteAcceptStarted(zoneName: String) {
        self.zoneName = zoneName
        phase = .accepting
    }

    func noteAcceptSucceeded(zoneName: String) {
        guard tracks(zoneName) else { return }
        self.zoneName = zoneName
        phase = .waitingForZone
    }

    func noteAcceptFailed(zoneName: String, recoverable: Bool) {
        guard tracks(zoneName) else { return }
        self.zoneName = zoneName
        phase = .failed(.acceptFailed(recoverable: recoverable))
    }

    // MARK: - Callbacks del lado sync (reconciliador)

    func noteGroupInserted(zoneName: String) {
        guard tracks(zoneName) else { return }
        // Monotonía: no retroceder desde estados terminales/confirmados.
        switch phase {
        case .pendingApproval, .active: return
        default: phase = .creatingMember
        }
    }

    func noteMemberResolved(zoneName: String, status: SplitMemberStatus) {
        guard tracks(zoneName) else { return }
        switch status {
        case .active:
            phase = .active
        case .pendingApproval:
            phase = .pendingApproval
        case .rejected, .left, .removed:
            // Estados terminales del member: no son fases del join. El tracker vuelve a
            // idle. **Nadie los recoge hoy**: la UI de reconexión que los manejaba se podó
            // con el recorrido muerto del invitado, así que un miembro rechazado/removido que
            // vuelve a tocar el link se queda sin salida — es el bug abierto
            // `tickets/backlog/rejected-member-cold-tap-does-nothing.md`.
            clear()
        }
    }

    func noteMemberSaveFailed(zoneName: String) {
        guard tracks(zoneName) else { return }
        phase = .failed(.memberSaveFailed)
    }

    func noteExpired(zoneName: String) {
        guard tracks(zoneName) else { return }
        phase = .failed(.expired)
    }

    // MARK: - Retry

    /// Re-dirige según la razón del fallo. `.memberSaveFailed` → reconcile
    /// directo (el ensure es idempotente).
    ///
    /// **`.acceptFailed` perdió su recuperación en la Fase 3**, y es la mitad de S3c que el compilador SÍ
    /// caza: re-resolvía el share desde `PendingInviteStore` y llamaba a `SplitSyncManager.acceptShare`,
    /// y los dos murieron con el transporte. No hay forma de reaceptar un CKShare, así que cae a
    /// `.expired` —«el usuario necesita un enlace nuevo»—, que además es la verdad: el enlace nuevo será
    /// del canal backend. Sus tres escritores también se fueron (los dos emisores de `noteAcceptStarted`
    /// eran del transporte; queda el hook `#if DEBUG` de XCUITest), así que en un binario de RELEASE
    /// ningún camino de producción escribe ya esta fase.
    func retry() async {
        guard case .failed(let reason) = phase else { return }
        switch reason {
        case .memberSaveFailed:
            phase = .creatingMember
            await GroupJoinReconciler.reconcile(trigger: .acceptShare)
        case .acceptFailed:
            phase = .failed(.expired)
        case .expired:
            break  // sin recovery — el usuario necesita un enlace nuevo
        }
    }

    // MARK: - Helpers

    private func tracks(_ zone: String) -> Bool {
        zoneName == nil || zoneName == zone
    }

    // MARK: - UITest hooks

    #if DEBUG
    /// Congela una fase por nombre (`-uitest-join-phase`). Solo XCUI: en sim no
    /// hay CKShare real, así que los steps del onboarding se testean forzados.
    func _uitestForcePhase(named name: String, zoneName: String = "SplitGroup-UITEST") {
        self.zoneName = zoneName
        switch name {
        case "accepting": phase = .accepting
        case "waitingForZone": phase = .waitingForZone
        case "creatingMember": phase = .creatingMember
        case "pendingApproval": phase = .pendingApproval
        case "active": phase = .active
        case "failed": phase = .failed(.acceptFailed(recoverable: true))
        case "failedMemberSave": phase = .failed(.memberSaveFailed)
        case "expired": phase = .failed(.expired)
        default: break
        }
    }
    #endif
}
