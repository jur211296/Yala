//
//  GroupMigrationReadinessLogic.swift
//  Yala
//
//  C-10: decide si un grupo PUEDE migrarse al backend sin dejar a nadie congelado sin salida.
//  Pure-logic, sin SwiftData/ModelContext → testeable en aislamiento (molde `GroupFreezeLogic`).
//
//  El problema que resuelve: `movedToBackendAt` viaja por CloudKit y CONGELA el grupo en el device de
//  cada miembro, pero la capacidad de volver a entrar depende de lo que ese binario tenga COMPILADO. En
//  un rollout escalonado el marcador llegaba antes que la capacidad. La regla que restablece esto:
//  **un marcador que congela no viaja antes que la capacidad de re-entrar**.
//
//  FAIL-CLOSED por diseño: la AUSENCIA de beacon cuenta como incapaz. Es lo que protege a los binarios
//  ya publicados, que no pueden cooperar porque este código no existe en ellos.
//

import Foundation

/// Fotografía de un member para decidir la readiness. Valores planos → sin `@Model` ni contexto.
nonisolated struct MemberCapabilitySnapshot: Equatable, Sendable {
    let memberKey: String
    let isGroupOwner: Bool
    let status: SplitMemberStatus
    /// `cloudKitUserRecordID` no vacío. Sin él, `GroupMigrationPayloadBuilder` salta al member al
    /// construir el payload del RPC → migrarlo lo dejaría fuera del backend igualmente.
    let hasRecordName: Bool
    let capability: String?
    let capabilityAt: Date?
}

nonisolated enum GroupMigrationReadinessLogic {
    enum Decision: Equatable {
        /// Todos los miembros que cuentan publicaron un beacon fresco y aceptado.
        case ready
        /// Faltan `pending` miembros. El grupo NO se migra: nadie se congela.
        case waiting(pending: Int)
    }

    /// Un beacon viejo no prueba capacidad viva (downgrade, fila huérfana, device que ya no se usa).
    /// 45 días: holgado frente al refresco de 7 días del beacon — hacen falta ~6 refrescos perdidos
    /// seguidos para caducar, así que un usuario que abre la app de vez en cuando no bloquea su grupo.
    static let beaconTTL: TimeInterval = 45 * 24 * 60 * 60

    /// Miembros que CUENTAN para la decisión. `.left`/`.removed`/`.rejected` se ignoran a propósito:
    /// ESA es la salida del owner cuando alguien ya no participa y no va a actualizar nunca. El owner
    /// no puede arrastrar a nadie al mundo nuevo, pero sí puede seguir sin quien ya se fue.
    static func countsForReadiness(_ member: MemberCapabilitySnapshot) -> Bool {
        guard !member.isGroupOwner else { return false }
        switch member.status {
        case .active, .pendingApproval: return true
        case .left, .removed, .rejected: return false
        }
    }

    /// ¿Este beacon acredita capacidad AHORA? Comparación por PERTENENCIA A UN SET, jamás numérica: el
    /// historial de `CURRENT_PROJECT_VERSION` del repo no es monótono, así que un `<` sobre versiones
    /// repetiría ese mismo rompe-umbral. Un token desconocido (de un build MÁS nuevo con otra capacidad)
    /// cuenta como no-capaz: fail-closed también hacia el futuro.
    static func isCapable(
        capability: String?,
        capabilityAt: Date?,
        now: Date,
        accepted: Set<String>,
        ttl: TimeInterval
    ) -> Bool {
        guard let capability, accepted.contains(capability) else { return false }
        guard let capabilityAt else { return false }
        // Un beacon con fecha en el FUTURO (reloj del device torcido) se acepta: la frescura solo busca
        // descartar beacons viejos, y castigar un reloj adelantado bloquearía un grupo sano.
        guard capabilityAt >= now.addingTimeInterval(-ttl) else { return false }
        return true
    }

    /// La decisión de EMITIR. `ready` solo si TODOS los que cuentan son capaces.
    static func decide(
        members: [MemberCapabilitySnapshot],
        now: Date,
        accepted: Set<String> = GroupCapability.acceptedForRejoin,
        ttl: TimeInterval = beaconTTL
    ) -> Decision {
        let pending = laggards(members: members, now: now, accepted: accepted, ttl: ttl).count
        return pending == 0 ? .ready : .waiting(pending: pending)
    }

    /// Los miembros que BLOQUEAN la migración, para poder nombrarlos al owner. Sin esta lista el owner
    /// vería "esperando" sin saber a quién esperar, que es otra forma de callejón sin salida.
    static func laggards(
        members: [MemberCapabilitySnapshot],
        now: Date,
        accepted: Set<String> = GroupCapability.acceptedForRejoin,
        ttl: TimeInterval = beaconTTL
    ) -> [MemberCapabilitySnapshot] {
        members
            .filter(countsForReadiness)
            .filter { member in
                guard member.hasRecordName else { return true }
                return !isCapable(
                    capability: member.capability,
                    capabilityAt: member.capabilityAt,
                    now: now,
                    accepted: accepted,
                    ttl: ttl
                )
            }
    }
}
