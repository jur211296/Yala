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

        let defs: [(note: String, amount: Double)] = [
            (draftNoteA, -42.50),
            (draftNoteB, -18.00),
        ]

        for def in defs {
            let draft = InboxDraft(
                note: def.note,
                amount: def.amount,
                date: Date.now,
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
