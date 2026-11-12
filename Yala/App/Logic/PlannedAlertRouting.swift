//
//  PlannedAlertRouting.swift
//  Yala
//
//  Auditoría UX 2.2 · lote 10 (L10-13, L10-14). Tocar el aviso de un pago planificado abría la lista en el mes de
//  siempre, y el de la tarjeta de crédito no abría nada (`accounts` no lo reconocía `parseDestination`). Ahora cada aviso
//  lleva el id de lo que avisa: `scheduledPayments/<uuid>` abre el detalle de ese pago y `accounts/<uuid>` la ficha de
//  esa tarjeta.
//
//  El mismo molde que `BudgetAlertRouting` (L9-5): el destino del router sigue siendo el de siempre —que ya sabe esperar
//  al arranque en frío— y el id espera aquí, en el proceso, hasta que la VENTANA que drena ese destino lo pasa a su
//  `SceneNavigation`. Así se abre en esa ventana y no en otra.
//

import Foundation
import Observation

/// Los dos enlaces con id de este lote. Sin estado, para leerlos desde cualquier aislamiento (el servicio de avisos y
/// el parseo del toque).
nonisolated enum AlertDeepLink: Sendable {
    case scheduledPayment
    case account

    var prefix: String {
        switch self {
        case .scheduledPayment: return "scheduledPayments/"
        case .account: return "accounts/"
        }
    }

    func deepLink(for id: UUID) -> String { prefix + id.uuidString }

    /// El id de `<prefijo><uuid>`, o `nil` si el enlace no es de este tipo o no trae id.
    func id(fromDeepLink link: String) -> UUID? {
        guard link.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(link.dropFirst(prefix.count)))
    }
}

/// El id que un aviso pidió abrir, esperando a la ventana que drene su destino.
@MainActor
@Observable
final class AlertDeepLinkTarget {
    /// El pago planificado de un recordatorio (L10-13).
    static let scheduledPayment = AlertDeepLinkTarget()
    /// La tarjeta de crédito del aviso de pago (L10-14). El id es su `shortcutID`.
    static let account = AlertDeepLinkTarget()

    private(set) var pendingID: UUID?
    private var requestedAt: Date?

    /// Un id que nadie recoge (la shell de solo grupos, un buffer caducado) no puede abrir algo horas después.
    static let maxAge: TimeInterval = 10 * 60

    func request(_ id: UUID, now: Date = .now) {
        pendingID = id
        requestedAt = now
    }

    /// Lo devuelve una sola vez, y nada si lleva más de `maxAge` esperando.
    func consume(now: Date = .now) -> UUID? {
        defer {
            pendingID = nil
            requestedAt = nil
        }
        guard let id = pendingID, let requestedAt, now.timeIntervalSince(requestedAt) <= Self.maxAge else { return nil }
        return id
    }
}
