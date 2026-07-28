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
    /// G6-3: grupo migrado y CONGELADO en este device (member no re-joineado), y este build PUEDE volver
    /// a entrar: chip "Se movió" + tap abre el detalle, donde vive el CTA "Volver a entrar".
    case migratedFrozen
    /// C-10: congelado y este build NO puede volver a entrar (canal no compilado / backend sin
    /// configurar): chip "Actualiza la app" + tap abre el detalle, donde vive el CTA al App Store.
    case migratedNeedsUpdate
    /// C-10: congelado y el canal está en pausa (kill remoto): chip "En pausa" + tap abre el detalle,
    /// que explica y NO ofrece ningún botón que no pueda terminar.
    case migratedPaused
}

enum GroupCardDisplayLogic {
    /// Decide el modo de display según el status del current member en el grupo y el estado de migración
    /// presentable. El freeze tiene PRIORIDAD sobre el status en los TRES estados congelados (un grupo
    /// migrado ya no acepta la interacción normal). `.left` y `.removed` se tratan como `.active` (caso
    /// edge: el grupo igual debe ser navegable por si tiene historial; el filtro upstream debe evitar que
    /// aparezcan, pero la card NO bloquea por defensa-en-profundidad).
    ///
    /// C-10: el parámetro era un `Bool` (`isMigratedFrozen`) que cargaba tres consecuencias distintas —
    /// no escribas / no abras / toca para volver a entrar. Esa fusión ERA el bug: en un build incapaz,
    /// "toca para volver a entrar" no llevaba a ninguna parte. Ahora el estado dice cuál de las tres
    /// salidas existe de verdad.
    static func displayMode(
        memberStatus: SplitMemberStatus?,
        migrationState: GroupMigrationState = .normal
    ) -> GroupCardDisplayMode {
        switch migrationState {
        case .frozenRejoinable:  return .migratedFrozen
        case .frozenNeedsUpdate: return .migratedNeedsUpdate
        case .frozenPaused:      return .migratedPaused
        case .normal:            break
        }
        switch memberStatus {
        case .pendingApproval: return .pendingApproval
        case .rejected: return .rejected
        case .active, .left, .removed, .none: return .active
        }
    }
}
