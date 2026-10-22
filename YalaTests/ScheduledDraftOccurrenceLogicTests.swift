//
//  ScheduledDraftOccurrenceLogicTests.swift
//  YalaTests
//
//  Lógica pura de `ScheduledDraftOccurrenceLogic` (ticket `inbox-dismiss-x-does-not-delete-the-draft-for-good`):
//  qué ocurrencia retiene un borrador de un pago programado, cuál se salta al descartarlo, cuál se deshace al
//  devolverlo a pendientes y cuándo aprobarlo avanza la próxima fecha. El cableado con el store lo prueba
//  `InboxDismissScheduledDraftTests`.
//

import Foundation
import Testing

@testable import Yala

struct ScheduledDraftOccurrenceLogicTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func monthly(
        next: Date, dayOfMonth: Int? = nil, interval: Int = 1, lastPaid: Date? = nil, recurring: Bool = true
    ) -> ScheduledDraftOccurrenceLogic.Schedule {
        .init(isRecurring: recurring, recurrenceType: "monthly", recurrenceInterval: interval,
              dayOfMonth: dayOfMonth, nextDueDate: next, lastPaidDate: lastPaid)
    }

    private func never(_: Date) -> Bool { false }

    // MARK: - holdsAnOccurrence

    @Test func onlyScheduledSourcesHoldAnOccurrence() {
        let holding: Set<DraftSourceType> = [.scheduledPayment, .subscription, .groupScheduledExpense]
        let all: [DraftSourceType] = [.voice, .receiptPhoto, .screenshotList, .screenshotSingle, .emailAlert,
                                      .scheduledPayment, .subscription, .applePay, .automation, .siri,
                                      .groupExpense, .groupSettlement, .manual, .groupScheduledExpense]
        for source in all {
            #expect(ScheduledDraftOccurrenceLogic.holdsAnOccurrence(source) == holding.contains(source), "\(source)")
        }
    }

    // MARK: - heldOccurrence

    @Test func draftOfTheNextDueDate_holdsIt() {
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1)
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 10, 1), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    @Test func draftWithAnEditedDate_stillHoldsTheNextDueDate() {
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1)
        // Editada hacia atrás (no cae en el calendario) y hacia delante.
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 9, 28), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 10, 5), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    @Test func advancedDraft_holdsTheNextDueDate() {
        // «Pagar ahora» el 27-sep para el vencimiento del 1-oct.
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 9, 27), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    @Test func draftOfAnOccurrenceLeftBehind_holdsItsOwn() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1)
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 10, 1), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
        // Dos ocurrencias atrás también.
        let later = monthly(next: day(2026, 12, 1), dayOfMonth: 1)
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 10, 1), schedule: later, calendar: calendar)
                == day(2026, 10, 1))
    }

    @Test func monthEndClamping_isOnTheSchedule() {
        // Día 31: feb-28 → ene-31 hacia atrás, igual que `advanceToNextDueDate` hacia delante.
        let s = monthly(next: day(2026, 3, 31), dayOfMonth: 31)
        #expect(ScheduledDraftOccurrenceLogic.isOccurrence(day(2026, 2, 28), before: day(2026, 3, 31), schedule: s, calendar: calendar))
        #expect(ScheduledDraftOccurrenceLogic.isOccurrence(day(2026, 1, 31), before: day(2026, 3, 31), schedule: s, calendar: calendar))
        #expect(!ScheduledDraftOccurrenceLogic.isOccurrence(day(2026, 1, 30), before: day(2026, 3, 31), schedule: s, calendar: calendar))
    }

    @Test(arguments: [("daily", 2, 4), ("weekly", 1, 7), ("yearly", 1, 365)])
    func otherRecurrences_walkBackWithTheirStep(type: String, interval: Int, daysBack: Int) {
        let next = day(2027, 1, 1)
        let s = ScheduledDraftOccurrenceLogic.Schedule(isRecurring: true, recurrenceType: type,
                                                       recurrenceInterval: interval, dayOfMonth: nil,
                                                       nextDueDate: next, lastPaidDate: nil)
        let previous = calendar.date(byAdding: .day, value: -daysBack, to: next)!
        #expect(ScheduledDraftOccurrenceLogic.isOccurrence(previous, before: next, schedule: s, calendar: calendar))
        let offSchedule = calendar.date(byAdding: .day, value: -1, to: previous)!
        #expect(!ScheduledDraftOccurrenceLogic.isOccurrence(offSchedule, before: next, schedule: s, calendar: calendar))
    }

    @Test func oneTimePayment_onlyHoldsItsDate() {
        let s = monthly(next: day(2026, 10, 1), recurring: false)
        #expect(!ScheduledDraftOccurrenceLogic.isOccurrence(day(2026, 9, 1), before: day(2026, 10, 1), schedule: s, calendar: calendar))
        #expect(ScheduledDraftOccurrenceLogic.heldOccurrence(draftDate: day(2026, 9, 1), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    // MARK: - occurrenceToSkipOnDismiss

    @Test func dismissingTheDueDraft_skipsTheNextDueDate() {
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.occurrenceToSkipOnDismiss(draftDate: day(2026, 10, 1), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    @Test func dismissingADuplicateOfAPaidOccurrence_skipsNothing() {
        // El otro teléfono creó su borrador del 1-oct; aquí ya se pagó y la próxima fecha es el 1-nov.
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 10, 1))
        #expect(ScheduledDraftOccurrenceLogic.occurrenceToSkipOnDismiss(draftDate: day(2026, 10, 1), schedule: s, calendar: calendar)
                == nil)
    }

    @Test func dismissingAnOccurrenceLeftBehindUnpaid_skipsThatOne_notTheNext() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.occurrenceToSkipOnDismiss(draftDate: day(2026, 10, 1), schedule: s, calendar: calendar)
                == day(2026, 10, 1))
    }

    // MARK: - occurrenceToRestoreOnReturn / belongsToADismissedOccurrence

    @Test func returningToPending_restoresOnlyASkippedHeldOccurrence() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1)
        let skipped: Set<Date> = [day(2026, 10, 1)]
        #expect(ScheduledDraftOccurrenceLogic.occurrenceToRestoreOnReturn(
            draftDate: day(2026, 10, 1), schedule: s, isSkipped: { skipped.contains($0) }, calendar: calendar) == day(2026, 10, 1))
        #expect(ScheduledDraftOccurrenceLogic.occurrenceToRestoreOnReturn(
            draftDate: day(2026, 10, 1), schedule: s, isSkipped: never, calendar: calendar) == nil)
    }

    @Test func aPendingDraftBelongsToADismissedOccurrence_onlyIfItsOwnIsSkipped() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1)
        let skipped: Set<Date> = [day(2026, 10, 1)]
        #expect(ScheduledDraftOccurrenceLogic.belongsToADismissedOccurrence(
            draftDate: day(2026, 10, 1), schedule: s, isSkipped: { skipped.contains($0) }, calendar: calendar))
        // El borrador de la próxima fecha no se toca por un salto anterior.
        #expect(!ScheduledDraftOccurrenceLogic.belongsToADismissedOccurrence(
            draftDate: day(2026, 11, 1), schedule: s, isSkipped: { skipped.contains($0) }, calendar: calendar))
    }

    // MARK: - approvalAdvancesPointer

    @Test func approvingTheDueDraft_advances() {
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: s, isAccountedFor: never, calendar: calendar))
    }

    @Test func approvingAnAdvancedDraft_advances() {
        let s = monthly(next: day(2026, 10, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 9, 27), schedule: s, isAccountedFor: never, calendar: calendar))
    }

    @Test func approvingAnAdvanceMadeOnAPaidOccurrenceDay_advances() {
        // Pagó el alquiler del 1-oct y ese mismo día adelanta el del 1-nov.
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 10, 1))
        #expect(ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: s, isAccountedFor: never, calendar: calendar))
    }

    @Test func approvingAnOccurrenceLeftBehindUnpaid_doesNotAdvance() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(!ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: s, isAccountedFor: never, calendar: calendar))
        // Dos ocurrencias atrás, con la intermedia pagada, tampoco.
        let twoBehind = monthly(next: day(2026, 12, 1), dayOfMonth: 1, lastPaid: day(2026, 11, 1))
        #expect(!ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: twoBehind, isAccountedFor: never, calendar: calendar))
    }

    @Test func approvingAnAdvanceMadeOnAnOccurrenceCoveredByAnotherTransaction_advances() {
        // La del 1-oct se cubrió con una transacción del 30-sep (fecha de pago 30-sep); el 1-oct adelanta noviembre.
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 30))
        #expect(ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: s, isAccountedFor: { $0 == day(2026, 10, 1) }, calendar: calendar))
    }

    @Test func approvingAnAdvanceMadeOnASkippedOccurrenceDay_advances() {
        let s = monthly(next: day(2026, 11, 1), dayOfMonth: 1, lastPaid: day(2026, 9, 1))
        #expect(ScheduledDraftOccurrenceLogic.approvalAdvancesPointer(
            draftDate: day(2026, 10, 1), schedule: s, isAccountedFor: { $0 == day(2026, 10, 1) }, calendar: calendar))
    }
}
