//
//  GroupCardDisplayLogic.swift
//  Yala
//
//  Pure-logic helper para decidir cómo se renderiza una card de grupo en la
//  lista según el estado del current member en ese grupo.
//
//  #26 — cards de pending/rejected muestran chip en lugar de balance + tap
//  comportamiento distinto. Logic extraído en archivo separado para tests
//  pure-logic sin SwiftData/ModelContext (evita flake R8 documentado en
//  CLAUDE.md → makeTestContext).
//

import Foundation

enum GroupCardDisplayMode: Equatable {
    /// Member activo (o current user no es member del grupo — ej. owner sin
    /// SplitMember asociado): comportamiento normal con balance + tap abre
    /// GroupDetailView.
    case active
    /// Member en estado `.pendingApproval`: chip "Esperando aprobación" + tap
    /// disabled (no abre el detalle, no hay nada actionable allí).
    case pendingApproval
    /// Member en estado `.rejected`: chip "Solicitud rechazada" + tap dispara
    /// alert "¿Salir del grupo?" en lugar de abrir el detalle.
    case rejected
}

enum GroupCardDisplayLogic {
    /// Decide el modo de display según el status del current member en el grupo.
    /// `.left` y `.removed` se tratan como `.active` (caso edge: el grupo igual
    /// debe ser navegable por si tiene historial; el filtro upstream debe
    /// evitar que aparezcan, pero la card NO bloquea por defensa-en-profundidad).
    static func displayMode(memberStatus: SplitMemberStatus?) -> GroupCardDisplayMode {
        switch memberStatus {
        case .pendingApproval: return .pendingApproval
        case .rejected: return .rejected
        case .active, .left, .removed, .none: return .active
        }
    }
}
