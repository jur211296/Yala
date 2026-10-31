//
//  OpeningBalanceServerRejectionNotices.swift
//  Yala
//
//  Card 6n1o (2026-10-31) · el buzón entre la subida de Grupos y el detalle del grupo. `GroupsSyncClient.applyResults`
//  deja aquí, por grupo, el motivo con que el servidor rechazó un saldo inicial (`OpeningBalanceServerRejectionLogic`),
//  y `GroupDetailView` lo recoge y lo enseña con el aviso de errores de siempre. Uno por grupo: diez repartos rechazados
//  del mismo gesto son un solo aviso.
//
//  Vive en memoria a propósito, y caduca a los 30 minutos (`maxAge`). El rechazo llega segundos después de guardar,
//  con la persona normalmente aún en el grupo; contado horas después, al abrir ese grupo, hablaría de un gesto que ya
//  no recuerda y quizá de una causa que ya no existe (le devolvieron el admin). La fila sigue en dead-letter igual.
//

import Foundation
import Observation

@MainActor
@Observable
final class OpeningBalanceServerRejectionNotices {

    static let shared = OpeningBalanceServerRejectionNotices()

    static let maxAge: TimeInterval = 30 * 60

    /// Sube con cada motivo nuevo: es lo que observa el detalle del grupo.
    private(set) var revision = 0
    private var pending: [String: (reason: OpeningBalanceServerRejectionLogic.Reason, at: Date)] = [:]

    func record(groupID: String, reason: OpeningBalanceServerRejectionLogic.Reason, now: Date = .now) {
        pending[groupID] = (OpeningBalanceServerRejectionLogic.merged(pending[groupID]?.reason, with: reason), now)
        revision += 1
    }

    /// Entrega y olvida el motivo pendiente de ese grupo; uno caducado se olvida sin entregarse.
    func consume(groupID: String, now: Date = .now) -> OpeningBalanceServerRejectionLogic.Reason? {
        guard let entry = pending.removeValue(forKey: groupID) else { return nil }
        return now.timeIntervalSince(entry.at) <= Self.maxAge ? entry.reason : nil
    }

    func peek(groupID: String) -> OpeningBalanceServerRejectionLogic.Reason? {
        pending[groupID]?.reason
    }

    static func title() -> String { L10n.Groups.OpeningBalance.serverRejectedTitle }

    static func message(for reason: OpeningBalanceServerRejectionLogic.Reason) -> String {
        switch reason {
        case .notAdmin: L10n.Groups.OpeningBalance.serverRejectedNotAdmin
        case .locked: L10n.Groups.OpeningBalance.serverRejectedLocked
        case .groupClosed: L10n.Groups.OpeningBalance.serverRejectedGroupClosed
        }
    }

    #if DEBUG
    func _testReset() {
        pending = [:]
        revision = 0
    }
    #endif
}
