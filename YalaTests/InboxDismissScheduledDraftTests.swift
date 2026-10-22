//
//  InboxDismissScheduledDraftTests.swift
//  YalaTests
//
//  Ticket `inbox-dismiss-x-does-not-delete-the-draft-for-good`. Jürgen descartaba con la x de la Bandeja el
//  borrador de un pago programado personal y volvía a aparecer: `DraftService` no saltaba la ocurrencia (solo
//  lo hacía para `.groupScheduledExpense`), `nextDueDate` no avanzaba y `processDuePayments` —que corre en
//  cada arranque y en cada vuelta a primer plano— creaba un borrador idéntico.
//
//  El «arranque» de estos tests es `processDuePayments`, lo mismo que corre `AppBootstrapper` al arrancar y al
//  volver a primer plano. El «espejo de iCloud» de otro dispositivo es una fila que aparece en el store, que es
//  todo lo que el espejo hace. El modo nube va en `CloudSync/InboxDismissScheduledDraftCloudTests`.
//
//  `makeTestContext()` reusa el container por fichero ⇒ `.serialized`. `DraftService.shared` es un singleton:
//  cada test le pone el contexto y lo quita al salir.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct InboxDismissScheduledDraftTests {

    init() {
        // Quiescencia: status .idle + sin import ⇒ `processDuePayments` no difiere.
        iCloudSyncService.shared._testReset()
    }

    // MARK: - Fixtures

    private let calendar = Calendar.current

    private func daysAgo(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    enum Category: String, CaseIterable, Sendable {
        case recurring, subscription
    }

    /// Cómo descarta la persona el borrador. La x de la hoja y el swipe «Rechazar» llaman a `rejectDraft`;
    /// las acciones en lote a `bulkReject`/`bulkDelete`; la papelera y el swipe «Eliminar» a `deleteDraft`.
    enum Dismissal: String, CaseIterable, Sendable {
        case xOrSwipeReject, bulkReject, delete, bulkDelete

        @MainActor
        func perform(on draft: InboxDraft) throws {
            switch self {
            case .xOrSwipeReject: try DraftService.shared.rejectDraft(draft)
            case .bulkReject: try DraftService.shared.bulkReject([draft])
            case .delete: try DraftService.shared.deleteDraft(draft)
            case .bulkDelete: try DraftService.shared.bulkDelete([draft])
            }
        }
    }

    @discardableResult
    private func insertAccount(_ context: ModelContext) -> Account {
        let account = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "debit")
        context.insert(account)
        return account
    }

    /// Pago mensual vencido hace `dueDaysAgo` días (por defecto, una sola ocurrencia vencida: la siguiente cae
    /// dentro de unas cuatro semanas).
    @discardableResult
    private func insertDuePayment(
        _ context: ModelContext,
        name: String = "Alquiler",
        category: Category = .recurring,
        dueDaysAgo: Int = 3,
        account: Account? = nil
    ) -> ScheduledPayment {
        let due = daysAgo(dueDaysAgo)
        let payment = ScheduledPayment(
            name: name,
            amount: 1200,
            currencyCode: "PEN",
            account: account,
            nextDueDate: due,
            dayOfMonth: calendar.component(.day, from: due),
            paymentCategory: category.rawValue,
            isActive: true
        )
        context.insert(payment)
        return payment
    }

    private func drafts(of payment: ScheduledPayment, _ context: ModelContext) throws -> [InboxDraft] {
        let id = payment.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.sourceScheduledPaymentID == id }
    }

    private func pending(of payment: ScheduledPayment, _ context: ModelContext) throws -> [InboxDraft] {
        try drafts(of: payment, context).filter { $0.status == .pending }
    }

    /// Lo que pasa al abrir la app o volver a ella (`AppBootstrapper`: arranque y primer plano).
    @discardableResult
    private func relaunch(_ context: ModelContext) -> Int {
        ScheduledPaymentDraftService.processDuePayments(context: context)
    }

    private func withDraftService<T>(_ context: ModelContext, _ body: () throws -> T) rethrows -> T {
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        return try body()
    }

    // MARK: - El bug: lo descartado vuelve en el arranque siguiente

    @Test(arguments: Category.allCases, Dismissal.allCases)
    func dismissedScheduledDraft_doesNotComeBack(category: Category, dismissal: Dismissal) throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, category: category)
        try context.save()

        #expect(relaunch(context) == 1)
        let draft = try #require(try pending(of: payment, context).first)
        #expect(draft.sourceType == (category == .subscription ? .subscription : .scheduledPayment))

        try withDraftService(context) { try dismissal.perform(on: draft) }

        // Arranque y dos vueltas a primer plano: nada vuelve.
        relaunch(context)
        relaunch(context)
        relaunch(context)
        #expect(try pending(of: payment, context).isEmpty, "el borrador descartado volvió a la Bandeja")
        // La ocurrencia quedó saltada y el pago siguió a la siguiente.
        #expect(payment.nextDueDate > daysAgo(3))
    }

    @Test(arguments: [Dismissal.xOrSwipeReject, .delete])
    func dismissedGroupScheduledDraft_doesNotComeBack(dismissal: Dismissal) throws {
        let context = try makeTestContext()
        let zone = "SplitGroup-DISMISS"
        let group = SplitGroup(name: "Casa", isOwner: true)
        group.cloudKitZoneID = zone
        context.insert(group)
        context.insert(SplitMember(groupZoneID: zone, displayName: "Yo", status: .active, isCurrentUser: true))
        let payment = insertDuePayment(context, name: "Internet")
        payment.groupZoneID = zone
        payment.splitTotalAmount = 2400
        payment.splitType = "equal"
        try context.save()

        #expect(relaunch(context) == 1)
        let draft = try #require(try pending(of: payment, context).first)
        #expect(draft.sourceType == .groupScheduledExpense)

        try withDraftService(context) { try dismissal.perform(on: draft) }
        relaunch(context)
        relaunch(context)
        #expect(try pending(of: payment, context).isEmpty)
    }

    // MARK: - Controles: lo que NO se descartó sigue llegando

    @Test func nextOccurrence_stillArrives_afterDismissingTheCurrentOne() throws {
        let context = try makeTestContext()
        // Vencido hace 45 días: la ocurrencia siguiente (≈ hace 15 días) también está vencida.
        let payment = insertDuePayment(context, dueDaysAgo: 45)
        try context.save()
        let firstOccurrence = payment.nextDueDate

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }

        relaunch(context)   // crea la siguiente (la próxima fecha avanzó al descartar)
        relaunch(context)

        let next = try pending(of: payment, context)
        #expect(next.count == 1, "la ocurrencia siguiente tiene que llegar, y una sola vez")
        let nextDate = try #require(next.first?.date)
        #expect(!calendar.isDate(nextDate, inSameDayAs: firstOccurrence))
        #expect(calendar.isDate(nextDate, inSameDayAs: try #require(calendar.date(byAdding: .month, value: 1, to: firstOccurrence))))
    }

    @Test func twoIdenticalScheduledPayments_dismissingOne_keepsTheOther() throws {
        let context = try makeTestContext()
        let first = insertDuePayment(context, name: "Gimnasio")
        let second = insertDuePayment(context, name: "Gimnasio")
        try context.save()

        #expect(relaunch(context) == 2)
        let draft = try #require(try pending(of: first, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }
        relaunch(context)

        #expect(try pending(of: first, context).isEmpty)
        #expect(try pending(of: second, context).count == 1, "el gasto idéntico de otro pago no se toca")
        #expect(!second.isDateSkipped(second.nextDueDate))
    }

    @Test func twoIdenticalCapturedExpenses_dismissingOne_keepsTheOther() throws {
        let context = try makeTestContext()
        let a = InboxDraft(note: "Starbucks", amount: -18, date: daysAgo(0), sourceType: .applePay)
        let b = InboxDraft(note: "Starbucks", amount: -18, date: daysAgo(0), sourceType: .applePay)
        context.insert(a)
        context.insert(b)
        try context.save()

        try withDraftService(context) { try DraftService.shared.rejectDraft(a) }
        relaunch(context)

        #expect(a.status == .rejected)
        #expect(b.status == .pending, "dos gastos idénticos reales siguen siendo dos")
    }

    @Test func returnToPending_afterTheAppMovedOn_approvingDoesNotSkipTheNextOccurrence() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 3)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }
        relaunch(context)   // la app pasa de largo: la próxima fecha ya es la del mes siguiente
        let nextOccurrence = payment.nextDueDate
        #expect(nextOccurrence > occurrence)

        // Desde Archivados, «Volver a pendientes».
        try withDraftService(context) { try DraftService.shared.returnToPending(draft) }
        #expect(draft.status == .pending)
        #expect(!payment.isDateSkipped(occurrence), "volver a pendientes deshace el salto")

        // Arrancar otra vez no lo vuelve a archivar ni crea otro.
        relaunch(context)
        #expect(draft.status == .pending)
        #expect(try pending(of: payment, context).count == 1)

        // Aprobarlo no se come la ocurrencia siguiente.
        draft.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: nextOccurrence),
                "aprobar una ocurrencia ya dejada atrás avanzó otra vez y se perdió la siguiente")
        #expect(calendar.isDate(try #require(payment.lastPaidDate), inSameDayAs: occurrence))
    }

    @Test func returnToPending_rightAway_restoresTheOccurrence_andApprovingPaysItOnce() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 3)
        try context.save()
        let occurrence = payment.nextDueDate
        let next = try #require(calendar.date(byAdding: .month, value: 1, to: occurrence))

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        try withDraftService(context) {
            try DraftService.shared.rejectDraft(draft)
            #expect(payment.isDateSkipped(occurrence))
            // La próxima fecha avanza en el acto, como haría el arranque siguiente con una fecha saltada.
            #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: next))
            try DraftService.shared.returnToPending(draft)
        }
        #expect(!payment.isDateSkipped(occurrence))
        relaunch(context)
        #expect(try pending(of: payment, context).count == 1)

        draft.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: next), "aprobar la devuelta avanzó dos veces")
    }

    @Test func dismissingThenPayingTheNextOneEarly_inTheSameSession_paysItOnce() throws {
        // Review adversarial, hallazgo 1: sin avanzar la próxima fecha al descartar, «Adelantar» en Planificación en
        // la misma sesión pagaba la siguiente y el arranque la volvía a crear.
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 3)
        try context.save()
        let occurrence = payment.nextDueDate
        let next = try #require(calendar.date(byAdding: .month, value: 1, to: occurrence))
        let afterNext = try #require(calendar.date(byAdding: .month, value: 2, to: occurrence))

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }

        let advanced = try #require(ScheduledPaymentDraftService.createAdvancedDraft(from: payment, context: context))
        try context.save()
        relaunch(context)
        #expect(advanced.status == .pending, "el barrido archivó el adelanto")

        advanced.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: advanced, context: context)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: afterNext))
        #expect(!payment.isDateSkipped(next))
        relaunch(context)
        #expect(try pending(of: payment, context).isEmpty)
    }

    @Test func dismissingAfterEditingTheDate_returnsWithTheOccurrenceDate_andApprovingPaysItOnce() throws {
        // Review adversarial, hallazgo 2: la x guarda antes la fecha editada.
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 3)
        try context.save()
        let occurrence = payment.nextDueDate
        let next = try #require(calendar.date(byAdding: .month, value: 1, to: occurrence))

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        draft.date = calendar.date(byAdding: .day, value: 2, to: occurrence)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }
        #expect(calendar.isDate(try #require(draft.date), inSameDayAs: occurrence))
        relaunch(context)

        try withDraftService(context) { try DraftService.shared.returnToPending(draft) }
        #expect(!payment.isDateSkipped(occurrence))
        draft.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: next))
    }

    @Test func payingEarlyOnTheDayOfAnOccurrenceCoveredByAnotherTransaction_advances() throws {
        // Review adversarial, hallazgo 3: la ocurrencia de hoy ya la cubrió una transacción asociada de ayer.
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 0)
        try context.save()
        let today = payment.nextDueDate
        let yesterday = daysAgo(1)
        let tx = TransactionItem(date: yesterday, amount: -1200, currencyCode: "PEN")
        tx.scheduledPaymentID = payment.id.uuidString
        context.insert(tx)
        payment.lastPaidDate = yesterday
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)
        try context.save()
        let next = payment.nextDueDate

        let advanced = try #require(ScheduledPaymentDraftService.createAdvancedDraft(from: payment, context: context))
        #expect(calendar.isDate(try #require(advanced.date), inSameDayAs: today))
        advanced.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: advanced, context: context)
        #expect(calendar.isDate(payment.nextDueDate,
                                inSameDayAs: try #require(calendar.date(byAdding: .month, value: 1, to: next))),
                "el adelanto no avanzó y la siguiente se pagaría dos veces")
    }

    @Test func deletingAnArchivedDraft_doesNotSkipAnotherOccurrence() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, dueDaysAgo: 45)
        try context.save()

        relaunch(context)
        let draft = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(draft) }
        // Al descartar, la próxima fecha (≈ hace 15 días, también vencida) ya es la siguiente.
        relaunch(context)
        let next = payment.nextDueDate

        // La papelera de Archivados borra el rechazado: no puede saltar la ocurrencia siguiente.
        try withDraftService(context) { try DraftService.shared.deleteDraft(draft) }
        #expect(!payment.isDateSkipped(next))
        relaunch(context)
        #expect(try pending(of: payment, context).count == 1)
    }

    @Test func advancedPayment_dismissed_skipsTheOccurrenceItWasPayingEarly() throws {
        let context = try makeTestContext()
        // Pago con la próxima fecha en el futuro y un adelanto («Pagar ahora», fechado hoy) pendiente.
        let future = try #require(calendar.date(byAdding: .day, value: 5, to: daysAgo(0)))
        let payment = ScheduledPayment(name: "Netflix", amount: 30, currencyCode: "PEN", nextDueDate: future,
                                       dayOfMonth: calendar.component(.day, from: future),
                                       paymentCategory: "subscription", isActive: true)
        context.insert(payment)
        try context.save()
        let advanced = try #require(ScheduledPaymentDraftService.createAdvancedDraft(from: payment, context: context))
        try context.save()

        // Descartar el adelanto descarta ese vencimiento: el día que llegue, `processDuePayments` lo salta
        // (lo mismo que fija `dismissedScheduledDraft_doesNotComeBack` con una ocurrencia ya vencida).
        try withDraftService(context) { try DraftService.shared.rejectDraft(advanced) }
        #expect(payment.isDateSkipped(future))
        #expect(!payment.isDateSkipped(daysAgo(0)), "el día del adelanto no es una ocurrencia")

        try withDraftService(context) { try DraftService.shared.returnToPending(advanced) }
        #expect(!payment.isDateSkipped(future))
    }

    // MARK: - Dos dispositivos con iCloud: el espejo trae el borrador del otro

    @Test func otherDevicesDraftOfTheDismissedOccurrence_isArchivedWhenItArrives() throws {
        let context = try makeTestContext()
        let account = insertAccount(context)
        let payment = insertDuePayment(context, account: account)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let mine = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(mine) }

        // El otro iPhone corrió `processDuePayments` antes de saber del rechazo: su borrador llega por el espejo.
        let theirs = InboxDraft(note: payment.name, amount: -1200, date: occurrence, account: account,
                                sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        theirs.sourceScheduledPaymentID = payment.id.uuidString
        theirs.createdAt = Date.now.addingTimeInterval(-60)
        context.insert(theirs)
        try context.save()

        relaunch(context)
        #expect(try pending(of: payment, context).isEmpty, "el borrador del otro dispositivo reapareció")
        #expect(theirs.status == .rejected)
        #expect(theirs.isShownInArchive, "se archiva, no se borra: tiene que verse en Archivados")
    }

    @Test func otherDevicesDraftAlreadyHere_isArchivedTogetherWithMine_withoutWaitingForARelaunch() throws {
        let context = try makeTestContext()
        let account = insertAccount(context)
        let payment = insertDuePayment(context, account: account)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let mine = try #require(try pending(of: payment, context).first)
        // Los dos borradores de la misma ocurrencia ya están en la Bandeja cuando la persona descarta uno.
        let theirs = InboxDraft(note: payment.name, amount: -1200, date: occurrence, account: account,
                                sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        theirs.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(theirs)
        // Y uno de OTRO pago idéntico, que no se toca.
        let other = insertDuePayment(context, account: account)
        let otherDraft = InboxDraft(note: other.name, amount: -1200, date: occurrence, account: account,
                                    sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        otherDraft.sourceScheduledPaymentID = other.id.uuidString
        context.insert(otherDraft)
        try context.save()

        try withDraftService(context) { try DraftService.shared.rejectDraft(mine) }
        #expect(theirs.status == .rejected, "el gemelo de la misma ocurrencia seguía en la Bandeja tras descartar")
        #expect(theirs.isShownInArchive)
        #expect(otherDraft.status == .pending)
    }

    @Test func otherDevicesDraft_arrivingAfterTheAppMovedOn_isArchivedToo() throws {
        let context = try makeTestContext()
        let account = insertAccount(context)
        let payment = insertDuePayment(context, account: account)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let mine = try #require(try pending(of: payment, context).first)
        try withDraftService(context) { try DraftService.shared.rejectDraft(mine) }
        relaunch(context)   // consume el salto

        let theirs = InboxDraft(note: payment.name, amount: -1200, date: occurrence, account: account,
                                sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        theirs.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(theirs)
        try context.save()

        relaunch(context)
        #expect(theirs.status == .rejected)
        #expect(try pending(of: payment, context).isEmpty)
    }

    @Test func theOtherDevice_archivesItsOwnDraft_whenTheSkipArrives() throws {
        let context = try makeTestContext()   // este es el OTRO teléfono
        let account = insertAccount(context)
        let payment = insertDuePayment(context, account: account)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let theirs = try #require(try pending(of: payment, context).first)

        // Llega por el espejo el pago con la ocurrencia saltada en el primer teléfono.
        payment.skipDate(occurrence)
        try context.save()

        relaunch(context)
        #expect(theirs.status == .rejected)
        #expect(try pending(of: payment, context).isEmpty)
        // Y no tira nada más: la ocurrencia siguiente sigue esperando su día.
        #expect(!payment.isDateSkipped(payment.nextDueDate))
    }

    @Test func otherDevicesDuplicateOfAPaidOccurrence_isNotSwept() throws {
        let context = try makeTestContext()
        let account = insertAccount(context)
        let payment = insertDuePayment(context, account: account)
        try context.save()
        let occurrence = payment.nextDueDate

        relaunch(context)
        let mine = try #require(try pending(of: payment, context).first)
        mine.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: mine, context: context)
        try context.save()

        // Duplicado de una ocurrencia PAGADA: no es un descarte, el barrido no lo toca.
        let theirs = InboxDraft(note: payment.name, amount: -1200, date: occurrence, account: account,
                                sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        theirs.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(theirs)
        try context.save()
        relaunch(context)
        #expect(theirs.status == .pending)

        // Y descartarlo no salta la ocurrencia siguiente.
        let next = payment.nextDueDate
        try withDraftService(context) { try DraftService.shared.rejectDraft(theirs) }
        #expect(!payment.isDateSkipped(next))
    }
}
