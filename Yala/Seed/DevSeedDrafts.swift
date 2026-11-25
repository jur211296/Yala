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

        if UITestHooks.seedInboxPlannedMatch {
            seedPlannedMatch(account: account, subcategory: subcategory, in: context)
        }
    }

    /// `-uitest-inbox-planned-match` (lote 4 de la Bandeja sin duplicados). Los cargos entran por la unión de producción.
    @MainActor
    private static func seedPlannedMatch(account: Account, subcategory: Subcategory, in context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        func planned(_ name: String, _ amount: Double, estimate: Bool, dueIn days: Int) -> ScheduledPayment {
            let due = calendar.date(byAdding: .day, value: days, to: today) ?? today
            let payment = ScheduledPayment(
                name: name, amount: amount, currencyCode: account.currencyCode, account: account, subcategory: subcategory,
                nextDueDate: due, dayOfMonth: calendar.component(.day, from: due), isVariableAmount: estimate)
            context.insert(payment)
            return payment
        }
        // Lo aprendido de un mes anterior: un borrador aprobado del planificado con un cargo de ese comercio unido.
        func learn(_ alias: String, for payment: ScheduledPayment) {
            let past = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let fields = InboxJoinRecord.Fields(note: payment.name, amount: -payment.amount, date: past,
                                                accountShortcutID: nil, subcategoryShortcutID: nil,
                                                cachedCurrencyCode: account.currencyCode)
            var member = fields
            member.note = alias
            let record = InboxJoinRecord(
                version: InboxJoinRecord.currentVersion,
                holderSource: InboxJoinRecord.SourceFacts(source: "planned", currencyCode: account.currencyCode,
                                                          last4: nil, hasExactTime: false),
                holderBefore: fields, holderAfter: fields,
                members: [InboxJoinRecord.Member(
                    facts: InboxJoinRecord.SourceFacts(source: "bankEmail", currencyCode: account.currencyCode,
                                                       last4: "4821", hasExactTime: false),
                    fields: member, sourceTypeRaw: DraftSourceType.emailAlert.rawValue, createdAt: past, rawText: nil,
                    evidence: nil, confidenceAmount: nil, confidenceDate: nil, confidenceMerchant: nil,
                    confidenceSubcategory: nil, joinedAt: past)])
            let approved = InboxDraft(note: payment.name, amount: -payment.amount, date: past, account: account,
                                      subcategory: subcategory, sourceType: .scheduledPayment, status: .approved)
            approved.sourceScheduledPaymentID = payment.id.uuidString
            approved.joinRecordRaw = record.encoded()
            context.insert(approved)
        }
        func emailDraft(_ note: String, _ amount: Double) -> InboxDraft {
            let draft = InboxDraft(
                note: note, amount: amount, date: today.addingTimeInterval(12 * 3600), account: account,
                sourceType: .emailAlert, rawText: "BCP · ****4821", evidence: "BCP · ****4821", confidenceAmount: 0.9,
                confidenceDate: 0.9, needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
            context.insert(draft)
            return draft
        }

        // Luz del Sur: estimado, vence hoy, la primera vez que llega su correo: la Bandeja pregunta.
        let luz = planned("Luz del Sur", 120, estimate: true, dueIn: 0)
        _ = ScheduledPaymentDraftService.createDraftForOccurrence(from: luz, date: luz.nextDueDate, context: context)
        _ = emailDraft("LUZ DEL SUR SAA", -134.80)

        // Sedapal: estimado, vence en dos días, ya aprendido: el correo adelanta su borrador con el monto real.
        let sedapal = planned("Sedapal", 60, estimate: true, dueIn: 2)
        learn("SEDAPAL", for: sedapal)
        let water = emailDraft("SEDAPAL", -72.40)
        _ = InboxArrivalJoin.joinBeforeSave(
            [InboxArrivalJoin.Arrival(draft: water, currencyCode: account.currencyCode, last4: "4821")], context: context)

        // Netflix: fijo, vence hoy, ya aprendido: su Apple Pay completa el borrador del planificado.
        let netflix = planned("Netflix", 44.90, estimate: false, dueIn: 0)
        learn("NETFLIX.COM", for: netflix)
        _ = ScheduledPaymentDraftService.createDraftForOccurrence(from: netflix, date: netflix.nextDueDate,
                                                                  context: context)
        let applePay = InboxDraft(
            note: "Netflix.com", amount: -44.90, date: today.addingTimeInterval(8 * 3600 + 40 * 60), account: account,
            sourceType: .applePay, rawText: "S/44.90", evidence: "Netflix.com", confidenceAmount: 1, confidenceDate: 1,
            needsUserInput: [DraftInputRequirement.subcategory], status: .pending)
        context.insert(applePay)
        _ = InboxArrivalJoin.joinBeforeSave(
            [InboxArrivalJoin.Arrival(draft: applePay, currencyCode: account.currencyCode)], context: context)
    }
}
#endif
