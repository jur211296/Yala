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
    /// Member en estado `.pendingApproval`: chip "Esperando aprobación" + el tap NO abre el detalle
    /// (decisión owner 2026-09-06): presenta el aviso de «solicitud en revisión».
    ///
    /// Hasta el 2026-09-06 el tap estaba `.disabled` y no hacía NADA. Eso cumplía media decisión —no
    /// entra— y fallaba la otra media: un muro mudo, el mismo defecto que C-10 ya había arreglado para
    /// los grupos congelados. Ahora el tap tiene destino.
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

    /// ¿Se le puede abrir el detalle del grupo a este miembro? **SSOT de la puerta** (decisión owner
    /// 2026-09-06: se cierra solo en el cliente; el servidor sigue entregando grupo y roster al
    /// pendiente vía `is_group_member`, y el endurecimiento que reserva gastos/repartos/saldos a
    /// `active` —`is_group_writer`— no se toca).
    ///
    /// **Se DERIVA de `displayMode`, no lo duplica**, y eso es la mitad del valor: si mañana alguien
    /// añade un estado que no deba abrir, lo decide en un solo sitio. De regalo hereda la prioridad del
    /// freeze — un grupo congelado SÍ abre el detalle aunque el miembro esté pendiente, porque es ahí
    /// donde C-10 puso la explicación y la única salida que ese build puede cumplir.
    ///
    /// Existe porque la tarjeta **no era la única puerta**: `openPendingGroupIfAvailable` (el deep link
    /// de una notificación) y la acción `.openGroupDetail` de un nudge llaman a `openDetail` sin pasar
    /// por ella. Cerrar solo la tarjeta habría dejado el AC cumplido en el camino que se probó a mano y
    /// abierto en los dos que no.
    static func allowsDetailEntry(
        memberStatus: SplitMemberStatus?,
        migrationState: GroupMigrationState = .normal
    ) -> Bool {
        displayMode(memberStatus: memberStatus, migrationState: migrationState) != .pendingApproval
    }
}
