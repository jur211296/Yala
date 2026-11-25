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

        // Los dos importes llevan céntimos a propósito. El generador de la semilla pone todo gasto en soles ENTEROS
        // (`DevSeedTransactions`, `.rounded()`), en la misma cuenta: con «Taxi aeropuerto» a −18,00, el día que salía un
        // transporte de −18 en hoy−3 el borrador tenía gemelo («Posible duplicado», `InboxDuplicateCheck`: mismo día,
        // importe y cuenta) y caían los cuatro XCUITest que lo guardan (nocturna del 18-nov, 3 de 3). Con céntimos no
        // puede igualar nada que genere la semilla; el gemelo que un test SÍ quiere lo siembra
        // `-uitest-inbox-duplicate-draft`.
        let defs: [(note: String, amount: Double, date: Date)] = [
            (draftNoteA, -42.50, Date.now),
            (draftNoteB, -18.40, pastDate),
        ]

        if UITestHooks.seedInboxEmpty { return }
        let aiNames = ["Claude", "ChatGPT"]
        for (index, def) in defs.enumerated() {
            let draft = InboxDraft(
                note: def.note,
                amount: def.amount,
                date: def.date,
                account: account,
                subcategory: subcategory,
                sourceType: UITestHooks.seedInboxAIDrafts ? .aiConnector : .manual,
                evidence: UITestHooks.seedInboxAIDrafts ? aiNames[index % aiNames.count] : nil,
                needsUserInput: [],
                status: .pending
            )
            context.insert(draft)
        }

        // `-uitest-inbox-duplicate-draft`: el registro gemelo del borrador A (mismo día, importe y cuenta), como si el
        // mismo pago hubiera llegado ya por otro camino y estuviera guardado.
        if UITestHooks.seedInboxDuplicateDraft, let first = defs.first {
            let twin = TransactionItem(date: first.date, amount: first.amount, currencyCode: account.currencyCode)
            twin.note = first.note
            twin.account = account
            twin.subcategory = subcategory
            twin.category = subcategory.safeCategory
            context.insert(twin)
        }

        // `-uitest-inbox-joined-draft`: el mismo café por Apple Pay y por el correo del banco, unidos al llegar
        // (`InboxArrivalJoin`, lote 2 de la Bandeja sin duplicados). Con céntimos que la semilla no genera.
        if UITestHooks.seedInboxJoinedDraft {
            let paidAt = Calendar.current.startOfDay(for: Date.now).addingTimeInterval(9 * 3600 + 5 * 60)
            let applePay = InboxDraft(
                note: "Starbucks", amount: -27.30, date: paidAt, account: account, sourceType: .applePay,
                rawText: "S/27.30", evidence: "Starbucks", confidenceAmount: 1, confidenceDate: 1,
                needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
            context.insert(applePay)
            let email = InboxDraft(
                note: "STARBUCKS MIRAFLORES", amount: -27.30,
                date: Calendar.current.startOfDay(for: Date.now).addingTimeInterval(12 * 3600), account: account,
                sourceType: .emailAlert, rawText: "BCP · ****4821", evidence: "BCP · ****4821", confidenceAmount: 0.9,
                confidenceDate: 0.9, needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
            context.insert(email)
            _ = InboxArrivalJoin.joinBeforeSave(
                [InboxArrivalJoin.Arrival(draft: email, currencyCode: account.currencyCode, last4: "4821")],
                context: context)
        }

        // `-uitest-inbox-same-expense-pair`: el mismo delivery por Apple Pay ayer a las 23:50 y por el correo del banco hoy,
        // con un importe un 2,8 % mayor (propina): coincidencia dudosa, así que no se une al llegar y la Bandeja pregunta.
        if UITestHooks.seedInboxSameExpensePair {
            let today = Calendar.current.startOfDay(for: Date.now)
            let applePay = InboxDraft(
                note: "Rappi", amount: -89.90, date: today.addingTimeInterval(-10 * 60), account: account,
                sourceType: .applePay, rawText: "S/89.90", evidence: "Rappi", confidenceAmount: 1, confidenceDate: 1,
                needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
            applePay.createdAt = today.addingTimeInterval(-9 * 60)
            context.insert(applePay)
            let email = InboxDraft(
                note: "RAPPI*PE", amount: -92.40, date: today.addingTimeInterval(12 * 3600), account: account,
                sourceType: .emailAlert, rawText: "BCP · ****4821", evidence: "BCP · ****4821", confidenceAmount: 0.9,
                confidenceDate: 0.9, needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
            context.insert(email)
        }
    }
}
#endif
