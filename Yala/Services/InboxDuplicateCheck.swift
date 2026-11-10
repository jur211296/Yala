//
//  InboxDuplicateCheck.swift
//  Yala
//
//  «Posible duplicado» de la Bandeja: un registro ya guardado con el mismo día, importe y cuenta. Hasta el lote 03 de
//  las necesarias 2.3 solo lo miraba el borrador abierto; «Guardar los N listos», «Aprobar» de la selección y deslizar
//  para guardar guardaban sin mirar, y el pago que llegaba por el correo del banco y por Apple Pay contaba dos veces
//  (ticket `inbox-bulk-save-and-swipe-skip-the-duplicate-check`). Un solo criterio para los cuatro caminos.
//

import Foundation
import SwiftData

@MainActor
enum InboxDuplicateCheck {

    /// El registro ya guardado que se parece: mismo día de calendario, mismo importe (con signo) y misma cuenta.
    /// Incluye lo insertado y aún sin guardar en el contexto (`includePendingChanges`, el valor por defecto): así un lote
    /// ve también los que acaba de crear él mismo. Lanza si no puede leer; cada llamador decide qué hace entonces.
    static func findDuplicate(
        amount: Double,
        date: Date,
        account: Account,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> TransactionItem? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.date >= startOfDay &&
                transaction.date < endOfDay &&
                transaction.amount == amount
            }
        )
        let accountID = account.persistentModelID
        return try context.fetch(descriptor).first { $0.account?.persistentModelID == accountID }
    }

    /// El posible duplicado de un borrador que se va a guardar de un toque. Solo los borradores PERSONALES: los de grupo
    /// se guardan por sus propias hojas y su puente, y nunca tuvieron esta comprobación (el borrador abierto tampoco la
    /// hace con ellos). `nil` si al borrador le falta cuenta o importe: entonces no se guarda de un toque.
    static func possibleDuplicate(
        of draft: InboxDraft,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> TransactionItem? {
        guard !draft.isFromGroup, let account = draft.account, let amount = draft.amount else { return nil }
        return try findDuplicate(
            amount: amount,
            date: draft.effectiveDate,
            account: account,
            in: context,
            calendar: calendar
        )
    }
}
