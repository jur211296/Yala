//
//  GroupArchivedEntryLogic.swift
//  Yala
//
//  Ticket `archived-group-still-allows-expenses-and-payments-from-inside` (lote 2.3 de Grupos, 10-nov).
//  Un grupo archivado no ofrece apuntar gastos ni pagos nuevos desde dentro, igual que la lista no lo ofrece en
//  «Nuevo gasto». Para volver a apuntar, se desarchiva (el aviso de dentro lo ofrece a quien administra).
//

import Foundation

enum GroupArchivedEntryLogic {

    /// ¿Se enseñan el «+» de Gastos y «Saldar»? Hace falta poder escribir en el grupo y que no esté archivado.
    static func allowsNewEntries(canParticipate: Bool, isArchived: Bool) -> Bool {
        canParticipate && !isArchived
    }
}
