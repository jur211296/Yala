//
//  OpeningBalanceServerRejectionLogic.swift
//  Yala
//
//  Card 6n1o (2026-10-31) · el servidor exige lo mismo que `OpeningBalancePermissionLogic` y el bloqueo por pago
//  confirmado (migración `qa/cloud/g27_01_opening_balance_managers.sql`). Cuando rechaza una subida de un saldo inicial
//  lo hace con uno de estos tres códigos, y la fila se queda en dead-letter (`upstream_400:<código>`).
//
//  La app ya bloquea lo mismo antes de guardar, así que el rechazo solo llega en una carrera: a alguien le quitaron el
//  admin, o se confirmó un pago, mientras su teléfono aún no lo sabía. Lo que la persona tiene que oír es que su cambio
//  no llegó al grupo y por qué, no un error genérico.
//

nonisolated enum OpeningBalanceServerRejectionLogic {

    enum Reason: String, Equatable, Sendable, CaseIterable {
        case notAdmin = "yala_opening_balance_not_admin"
        case locked = "yala_opening_balance_locked"
        case groupClosed = "yala_opening_balance_group_closed"
    }

    /// El motivo de un código ya saneado (`GroupsSyncClient.sanitizedYalaSlug`); `nil` para cualquier otro rechazo.
    static func reason(forSlug slug: String?) -> Reason? {
        guard let slug else { return nil }
        return Reason(rawValue: slug)
    }

    /// Prioridad cuando una misma subida trae varios motivos para un grupo: el que más explica gana. Un grupo cerrado
    /// lo explica todo; un permiso perdido, más que un saldo bloqueado.
    static func merged(_ current: Reason?, with incoming: Reason) -> Reason {
        guard let current else { return incoming }
        return rank(incoming) > rank(current) ? incoming : current
    }

    /// Card e6fd (2026-11-01) · ¿Esta fila del outbox es un saldo inicial que el servidor rechazó para siempre y que este
    /// teléfono tiene que descartar? Solo los tres códigos (`rejectedReason` tal como lo guarda `applyResults`) y solo filas
    /// de la sesión: una dead-letter de otra cuenta no se toca, y sin sesión no se toca ninguna. El resto de rechazos sigue
    /// como estaba (`yala_not_authorized` revive al aprobar al miembro; 5xx/429 nunca llegan a dead-letter).
    static func settlesDeadLetter(rejectedReason: String?, rowOwner: String?, sessionOwner: String?) -> Bool {
        guard let rejectedReason, rejectedReason.hasPrefix(storedPrefix),
              reason(forSlug: String(rejectedReason.dropFirst(storedPrefix.count))) != nil else { return false }
        guard let sessionOwner, !sessionOwner.isEmpty else { return false }
        return rowOwner == sessionOwner
    }

    /// Prefijo con que `GroupsSyncClient.applyResults` guarda un rechazo P0001 del servidor (`upstream_400:<código>`).
    static let storedPrefix = "upstream_400:"

    private static func rank(_ reason: Reason) -> Int {
        switch reason {
        case .groupClosed: 3
        case .notAdmin: 2
        case .locked: 1
        }
    }
}
