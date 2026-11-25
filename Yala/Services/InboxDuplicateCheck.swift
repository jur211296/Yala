//
//  InboxDuplicateCheck.swift
//  Yala
//
//  «Posible duplicado» de la Bandeja: un registro ya guardado que parece el mismo pago. Hasta el lote 03 de las
//  necesarias 2.3 solo lo miraba el borrador abierto; «Guardar los N listos», «Aprobar» de la selección y deslizar
//  para guardar guardaban sin mirar, y el pago que llegaba por el correo del banco y por Apple Pay contaba dos veces
//  (ticket `inbox-bulk-save-and-swipe-skip-the-duplicate-check`). Un solo criterio para los cuatro caminos.
//
//  Desde el 24-nov-2026 (lote 0 de `docs/propuestas/bandeja-sin-duplicados/`) mira también el día anterior y el
//  siguiente —Apple Pay a las 23:50 y el correo del banco fechado al día siguiente son el mismo pago—, y el aviso nombra
//  el gemelo. Dos compras iguales de una fuente que manda cada pago una sola vez no son gemelas entre sí (E8).
//

import Foundation
import SwiftData

@MainActor
enum InboxDuplicateCheck {

    /// Diferencia de importe que todavía es el mismo pago (redondeos entre fuentes).
    static let amountTolerance = 0.01

    /// Fuentes que cuentan cada pago una sola vez: dos registros suyos iguales son dos compras reales, no un duplicado.
    /// Apple Pay no manda dos veces el mismo pago, y el correo repetido ya lo filtra su id antes de la Bandeja. La IA, la
    /// web, Siri, la voz y lo escrito a mano pueden repetir un pago y siguen avisando entre sí. El aviso del banco no
    /// entra porque comparte `automation` con la web.
    static let oncePerPaymentSources: Set<DraftSourceType> = [.applePay, .emailAlert]

    /// El registro ya guardado que se parece: del día anterior al siguiente, mismo signo, misma moneda que la cuenta,
    /// importe ±0,01 y la misma cuenta o ninguna. Con varios, el más cercano en el tiempo. Incluye lo insertado y aún sin
    /// guardar en el contexto (`includePendingChanges`, el valor por defecto): así un lote ve también los que acaba de
    /// crear él mismo. Lanza si no puede leer; cada llamador decide qué hace entonces.
    static func findDuplicate(
        amount: Double,
        date: Date,
        account: Account,
        fromSource source: DraftSourceType? = nil,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> TransactionItem? {
        let day = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .day, value: -1, to: day),
              let windowEnd = calendar.date(byAdding: .day, value: 2, to: day) else { return nil }
        // Un pelo por encima del céntimo: −42,50 y −42,51 en coma flotante no restan exactamente 0,01.
        let lowest = amount - amountTolerance - 1e-9
        let highest = amount + amountTolerance + 1e-9
        let currencyCode = account.currencyCode

        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.date >= windowStart &&
                transaction.date < windowEnd &&
                transaction.amount >= lowest &&
                transaction.amount <= highest &&
                transaction.currencyCode == currencyCode
            }
        )
        let accountID = account.persistentModelID
        let isExpense = amount < 0
        let candidates = try context.fetch(descriptor).filter { transaction in
            guard (transaction.amount < 0) == isExpense else { return false }
            if let other = transaction.account, other.persistentModelID != accountID { return false }
            return !isSamePaymentSource(transaction, as: source)
        }
        return candidates.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
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
            fromSource: draft.sourceType,
            in: context,
            calendar: calendar
        )
    }

    /// El registro vino de un borrador de la misma fuente, y esa fuente manda cada pago una sola vez.
    private static func isSamePaymentSource(_ transaction: TransactionItem, as source: DraftSourceType?) -> Bool {
        guard let source, oncePerPaymentSources.contains(source) else { return false }
        return transaction.approvedDraft?.sourceType == source
    }

    // MARK: - Lo que dice el aviso

    /// «Ya hay uno parecido: Wong · S/ 89.90 · 15 oct. ¿Guardarlo de todas formas?»
    static func warningMessage(naming twin: TransactionItem) -> String {
        L10n.Inbox.duplicateWarningNamed(twinSummary(twin))
    }

    /// Comercio (o subcategoría) · importe · fecha. Se lee al detectar el gemelo, no al pintar el aviso: el registro
    /// puede borrarse con el aviso abierto.
    static func twinSummary(_ twin: TransactionItem) -> String {
        let note = twin.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = note.isEmpty ? (twin.subcategory?.name ?? "") : note
        let amount = YalaFormatterStatic.currency(value: abs(twin.amount), currencyCode: twin.currencyCode, forceFullPrecision: true)
        return [name, amount, twinDateText(twin.date)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func twinDateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.current))
    }
}
