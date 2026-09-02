//
//  DevSeedDrafts.swift
//  Yala
//
//  Creates a couple of pending Inbox drafts for dev seed data so the Inbox is
//  never empty in dev/uitest. The `inbox-crud` area needs drafts present to
//  exercise the approve/reject flow deterministically (XCUITest).
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedDrafts {

    // Notas fijas (no localizadas) → el accessibilityIdentifier de la fila
    // (`inbox_draft_row_<note>`) es estable entre locales para los XCUITests.
    static let draftNoteA = "Almuerzo equipo"
    static let draftNoteB = "Taxi aeropuerto"

    /// Días que el borrador B queda ATRÁS respecto de hoy. Expuesto para que un XCUITest
    /// pueda calcular la fecha esperada sin duplicar la constante.
    static let draftBDaysInThePast = 3

    @MainActor
    static func create(
        account: Account,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) {
        // Subcategoría determinista (primera por nombre): con cuenta + monto +
        // subcategoría y `needsUserInput` vacío, el draft es `isReadyToApprove`.
        guard let subcategory = subcategoryLookup.sorted(by: { $0.key < $1.key }).first?.value else {
            return
        }

        // Los DOS borradores se fechaban en `Date.now`, y eso hacía el fixture CIEGO para
        // cualquier AC sobre la fecha: al convertir un borrador se veía «Hoy» en el formulario
        // y se daba por buena una conversión que puede estar perdiendo la fecha original
        // (la plantilla usa `.now`). Con los dos iguales, un falso verde era indistinguible
        // de un verde real. Por eso el B nace con fecha PASADA: es el control negativo.
        //
        // Mediodía, no `startOfDay`: una fecha a medianoche exacta cae en la frontera cerrada
        // de `DateInterval` (ver CLAUDE.md → «Cálculos con fechas») y se contaría en dos
        // buckets adyacentes. A mediodía la fecha es inequívoca en cualquier período.
        let pastDate = Calendar.current.date(
            byAdding: .day,
            value: -draftBDaysInThePast,
            to: Calendar.current.startOfDay(for: Date.now).addingTimeInterval(12 * 3600)
        ) ?? Date.now

        let defs: [(note: String, amount: Double, date: Date)] = [
            (draftNoteA, -42.50, Date.now),
            (draftNoteB, -18.00, pastDate),
        ]

        for def in defs {
            let draft = InboxDraft(
                note: def.note,
                amount: def.amount,
                date: def.date,
                account: account,
                subcategory: subcategory,
                sourceType: .manual,
                needsUserInput: [],
                status: .pending
            )
            context.insert(draft)
        }
    }
}
#endif
