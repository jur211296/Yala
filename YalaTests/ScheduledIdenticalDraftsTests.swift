//
//  ScheduledIdenticalDraftsTests.swift
//  YalaTests
//
//  Ticket `scheduled-payment-identical-drafts-in-the-inbox` (reporte de Jürgen del 2026-10-26, producción 2.1): algunos
//  pagos planificados dejaban varios borradores idénticos en la Bandeja, y descartar uno se llevaba todos.
//
//  Causa medida aquí: cada dispositivo materializa el vencimiento con lo que ve, y el borrador del otro llega después
//  por iCloud o la nube (en un solo dispositivo las guardas lo impiden: primer caso). Descartar archivaba a propósito
//  todos los pendientes de la misma ocurrencia. Ahora `processDuePayments` funde los idénticos en uno, el mismo en
//  todos los dispositivos, y descartar quita solo el borrador descartado.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Un vencimiento, un borrador en la Bandeja", .serialized)
@MainActor
struct ScheduledIdenticalDraftsTests {

    init() {
        // Quiescencia: status .idle + sin import ⇒ `processDuePayments` no difiere.
        iCloudSyncService.shared._testReset()
    }

    private let calendar = Calendar.current

    private func daysAgo(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    private func insertAccount(_ context: ModelContext) -> Account {
        let account = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "debit")
        context.insert(account)
        return account
    }

    private func insertDuePayment(_ context: ModelContext, name: String = "Alquiler", account: Account) -> ScheduledPayment {
        let due = daysAgo(3)
        let payment = ScheduledPayment(
            name: name,
            amount: 1200,
            currencyCode: "PEN",
            account: account,
            nextDueDate: due,
            dayOfMonth: calendar.component(.day, from: due),
            paymentCategory: "recurring",
            isActive: true
        )
        context.insert(payment)
        return payment
    }

    /// El borrador que crea OTRO dispositivo para el mismo vencimiento, tal como llega por el espejo: los mismos campos
    /// que `createDraft`, con su propio `createdAt`.
    private func otherDevicesCopy(of draft: InboxDraft, createdAt: Date) -> InboxDraft {
        let copy = InboxDraft(
            note: draft.note, amount: draft.amount, date: draft.date, account: draft.account,
            subcategory: draft.subcategory, sourceType: draft.sourceType, evidence: draft.evidence,
            needsUserInput: draft.needsUserInput, status: .pending
        )
        copy.sourceScheduledPaymentID = draft.sourceScheduledPaymentID
        copy.createdAt = createdAt
        return copy
    }

    private func pending(of payment: ScheduledPayment, _ context: ModelContext) throws -> [InboxDraft] {
        let id = payment.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>()).filter {
            $0.sourceScheduledPaymentID == id && $0.status == .pending && !$0.isDeleted
        }
    }

    /// La fusión espera con algo presentado, y el host de los tests tiene el Welcome montado: sin esto no correría nunca
    /// y los casos de «no se funde» pasarían en vacío.
    private func withNothingOnScreen<T>(_ body: () throws -> T) rethrows -> T {
        let saved = ScheduledPaymentDraftService.inboxIsOnScreen
        ScheduledPaymentDraftService.inboxIsOnScreen = { false }
        defer { ScheduledPaymentDraftService.inboxIsOnScreen = saved }
        return try body()
    }

    private func withDraftService<T>(_ context: ModelContext, _ body: () throws -> T) rethrows -> T {
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        return try body()
    }

    // MARK: - Creación

    /// En un solo dispositivo, abrir la app las veces que sea deja un borrador por vencimiento.
    @Test func oneDevice_relaunching_createsOneDraft() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()

        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 1)
        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 0)
        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 0)
        #expect(try pending(of: payment, context).count == 1)
    }

    /// El caso del reporte: el borrador de otros dos dispositivos llega por el espejo y la Bandeja tiene tres iguales. Al
    /// volver a la app queda uno, el más antiguo, y los otros se borran (no van a Archivados).
    @Test func identicalDraftsFromOtherDevices_mergeIntoTheOldest() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let mine = try #require(try pending(of: payment, context).first)
        let oldest = otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(-120))
        let newer = otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(60))
        context.insert(oldest)
        context.insert(newer)
        try context.save()
        #expect(try pending(of: payment, context).count == 3, "control: tres borradores iguales en la Bandeja")

        withNothingOnScreen { _ = ScheduledPaymentDraftService.processDuePayments(context: context) }
        let left = try pending(of: payment, context)
        #expect(left.count == 1)
        #expect(left.first?.persistentModelID == oldest.persistentModelID, "se queda el de menor createdAt")
        let archived = try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .rejected }
        #expect(archived.isEmpty, "las copias no van a Archivados")

        // Idempotente.
        #expect(!withNothingOnScreen { ScheduledPaymentDraftService.mergeIdenticalPendingDrafts(context: context) })
    }

    /// Los dos dispositivos eligen el MISMO superviviente: si cada uno conservara el suyo, entre los dos borrarían ambos.
    @Test func bothDevices_keepTheSameDraft() {
        let key = ScheduledDraftOccurrenceLogic.DuplicateKey(
            paymentID: "p", sourceTypeRaw: "scheduledPayment", occurrence: .distantPast, day: .distantPast,
            amount: -1200, note: "Alquiler", accountID: nil, subcategoryID: nil, tagIDs: "", evidence: nil, groupZoneID: nil)
        let a = Date(timeIntervalSince1970: 1_000), b = Date(timeIntervalSince1970: 1_005)
        // Dispositivo A: [el suyo (a), el de B (b)]. Dispositivo B: [el suyo (b), el de A (a)].
        let onA = ScheduledDraftOccurrenceLogic.duplicatesToRemove([
            .init(key: key, createdAt: a, index: 0), .init(key: key, createdAt: b, index: 1)])
        let onB = ScheduledDraftOccurrenceLogic.duplicatesToRemove([
            .init(key: key, createdAt: b, index: 0), .init(key: key, createdAt: a, index: 1)])
        #expect(onA == [1], "A borra el de B")
        #expect(onB == [0], "B borra el suyo: el mismo que A")
        // Empate dentro del redondeo de iCloud: no se sabe cuál elegiría el otro, no se toca.
        let tied = ScheduledDraftOccurrenceLogic.duplicatesToRemove([
            .init(key: key, createdAt: a, index: 0), .init(key: key, createdAt: a.addingTimeInterval(0.0004), index: 1)])
        #expect(tied.isEmpty)
    }

    /// Uno editado (otro importe) ya no es una copia: no se funde.
    @Test func editedDraft_isNotMerged() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let mine = try #require(try pending(of: payment, context).first)
        let edited = otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(-120))
        edited.amount = -1150
        context.insert(edited)
        try context.save()

        withNothingOnScreen { _ = ScheduledPaymentDraftService.processDuePayments(context: context) }
        #expect(try pending(of: payment, context).count == 2)
        // Control: sin la edición sí se fundirían.
        edited.amount = mine.amount
        try context.save()
        withNothingOnScreen { _ = ScheduledPaymentDraftService.processDuePayments(context: context) }
        #expect(try pending(of: payment, context).count == 1)
    }

    /// Con la Bandeja abierta el barrido espera: la persona podría tener abierto justo el que sobra.
    @Test func inboxOnScreen_waitsForTheNextPass() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let mine = try #require(try pending(of: payment, context).first)
        context.insert(otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(-120)))
        try context.save()

        let saved = ScheduledPaymentDraftService.inboxIsOnScreen
        ScheduledPaymentDraftService.inboxIsOnScreen = { true }
        defer { ScheduledPaymentDraftService.inboxIsOnScreen = saved }
        ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(try pending(of: payment, context).count == 2)

        ScheduledPaymentDraftService.inboxIsOnScreen = { false }
        ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(try pending(of: payment, context).count == 1)
    }

    // MARK: - Descartar

    /// El reporte: con dos borradores iguales en la Bandeja, descartar uno se llevaba el otro. Ahora se queda.
    @Test func dismissingOneOfTwo_keepsTheOther() throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let mine = try #require(try pending(of: payment, context).first)
        let theirs = otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(-120))
        context.insert(theirs)
        try context.save()

        try withDraftService(context) { try DraftService.shared.deleteDraft(mine) }
        #expect(theirs.status == .pending, "borrar uno se llevó el otro")
        #expect(!payment.isDateSkipped(payment.nextDueDate))
        // Y el vencimiento no se recrea encima: el que queda lo sigue cubriendo.
        withNothingOnScreen { _ = ScheduledPaymentDraftService.processDuePayments(context: context) }
        #expect(try pending(of: payment, context).count == 1)
    }

    /// Descartar las dos copias juntas (en lote) salta la ocurrencia con la última: el vencimiento no vuelve. Con el
    /// estado del primero solo en memoria, el segundo no puede contarlo como «otro pendiente».
    @Test(arguments: [false, true])
    func dismissingBothCopiesInOneBatch_skipsTheOccurrence(deleting: Bool) throws {
        let context = try makeTestContext()
        let payment = insertDuePayment(context, account: insertAccount(context))
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let mine = try #require(try pending(of: payment, context).first)
        let occurrence = calendar.startOfDay(for: mine.date ?? .now)
        let theirs = otherDevicesCopy(of: mine, createdAt: mine.createdAt.addingTimeInterval(-120))
        context.insert(theirs)
        try context.save()

        try withDraftService(context) {
            if deleting {
                try DraftService.shared.bulkDelete([mine, theirs])
            } else {
                try DraftService.shared.bulkReject([mine, theirs])
            }
        }
        #expect(payment.isDateSkipped(occurrence), "descartadas las dos copias, la ocurrencia no se saltó")
        ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(try pending(of: payment, context).isEmpty, "el vencimiento descartado volvió a la Bandeja")
    }

    /// Borradores DISTINTOS (otro pago, otra ocurrencia) no se tocan al descartar.
    @Test func dismissing_leavesDistinctDraftsAlone() throws {
        let context = try makeTestContext()
        let account = insertAccount(context)
        let rent = insertDuePayment(context, name: "Alquiler", account: account)
        let phone = insertDuePayment(context, name: "Teléfono", account: account)
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let rentDraft = try #require(try pending(of: rent, context).first)
        let phoneDraft = try #require(try pending(of: phone, context).first)
        // Uno del mes anterior del alquiler que volvió a pendientes desde Archivados: otra ocurrencia.
        let previousMonth = try #require(calendar.date(byAdding: .month, value: -1, to: rent.nextDueDate))
        let older = InboxDraft(note: rent.name, amount: -1200, date: previousMonth, account: account,
                               sourceType: .scheduledPayment, needsUserInput: [], status: .pending)
        older.sourceScheduledPaymentID = rent.id.uuidString
        context.insert(older)
        try context.save()

        try withDraftService(context) { try DraftService.shared.rejectDraft(rentDraft) }
        #expect(phoneDraft.status == .pending)
        #expect(older.status == .pending)
        #expect(rent.isDateSkipped(calendar.startOfDay(for: rentDraft.date ?? .now)))
    }
}
