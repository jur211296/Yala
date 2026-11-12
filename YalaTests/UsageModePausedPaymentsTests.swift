//
//  UsageModePausedPaymentsTests.swift
//  YalaTests
//
//  Encargo S11e (decisión de Jürgen del 2026-10-27): al volver de «Solo grupos» a Yala completo, los pagos programados
//  que vencieron durante la pausa no salen de golpe en la Bandeja; cada pago recurrente sigue en su próxima fecha, los de
//  grupo y los personales. La vuelta llama a `skipOccurrencesMissedDuringPause` y después a `processDuePayments`, que es
//  lo que hacen estos tests (y lo que el cableado de `UsageModeTests` fija en `UsageModeService.returnToFull`).
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID` ⇒ `.serialized`. Modelan el momento DESPUÉS de
//  levantar la marca: `processDuePayments` lee la pausa de `UserDefaults.standard`, que en un simulador limpio está apagada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Solo grupos · los pagos vencidos en la pausa no salen de golpe al volver", .serialized)
@MainActor
struct UsageModePausedPaymentsTests {

    private let calendar = Calendar.current

    init() {
        // Quiescencia: status .idle + sin import ⇒ ni el salto ni `processDuePayments` difieren.
        iCloudSyncService.shared._testReset()
    }

    private var today: Date { calendar.startOfDay(for: .now) }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    /// Semanal a propósito: desde `dueDaysAgo` que no sea múltiplo de 7, el salto nunca cae HOY, así que tras él
    /// `processDuePayments` no tiene nada que sacar, sea el día que sea.
    private func insertPayment(_ context: ModelContext, dueDaysAgo: Int, recurrence: String = "weekly",
                               isRecurring: Bool = true, endDate: Date? = nil, groupZoneID: String? = nil)
        -> ScheduledPayment {
        let due = daysAgo(dueDaysAgo)
        let payment = ScheduledPayment(
            name: "Alquiler",
            amount: 1200,
            currencyCode: "PEN",
            isRecurring: isRecurring,
            recurrenceType: recurrence,
            nextDueDate: due,
            dayOfMonth: calendar.component(.day, from: due),
            endDate: endDate,
            isActive: true
        )
        payment.groupZoneID = groupZoneID
        context.insert(payment)
        return payment
    }

    private func pendingDrafts(of payment: ScheduledPayment, _ context: ModelContext) throws -> [InboxDraft] {
        let id = payment.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>())
            .filter { $0.sourceScheduledPaymentID == id && $0.status == .pending }
    }

    // MARK: - Lo que venció en la pausa no sale

    @Test func personal_vencidoEnLaPausa_saltaASuProximaFecha_ySinBorrador() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40)
        try context.save()

        let moved = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(60))
        let created = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(moved == 1)
        #expect(created == 0)
        #expect(try pendingDrafts(of: payment, context).isEmpty)
        let next = calendar.startOfDay(for: payment.nextDueDate)
        #expect(next > today, "la próxima fecha tiene que ser el primer vencimiento desde hoy")
        #expect(next <= calendar.date(byAdding: .day, value: 7, to: today) ?? today, "saltó de más")
        #expect(payment.lastPaidDate == nil, "saltar no es pagar")
        #expect(payment.skippedDatesRaw.isEmpty, "las fechas saltadas viajan y archivarían borradores de otro dispositivo")
    }

    @Test func deGrupo_vencidoEnLaPausa_tambienSalta() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40, groupZoneID: "zona-grupo")
        try context.save()

        ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: daysAgo(60))

        #expect(calendar.startOfDay(for: payment.nextDueDate) > today)
        #expect(payment.isActive)
    }

    /// Control: sin el salto, la vuelta de antes sacaba el vencido más antiguo. Es lo que demuestra que el salto es el que
    /// lo contiene, y no otra cosa del entorno.
    @Test func control_sinElSalto_laVueltaSacaElVencido() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40)
        try context.save()

        let created = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(created == 1)
        #expect(try pendingDrafts(of: payment, context).count == 1)
    }

    @Test func sinFechaDeInicio_saltaTodoLoAnteriorAHoy() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40)
        try context.save()

        let moved = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: nil)

        #expect(moved == 1)
        #expect(calendar.startOfDay(for: payment.nextDueDate) > today)
    }

    @Test func laSerieQueTerminoEnLaPausa_quedaApagada() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40, endDate: daysAgo(10))
        try context.save()

        ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: daysAgo(60))
        let created = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(!payment.isActive)
        #expect(created == 0)
    }

    // MARK: - Lo que no se toca

    @Test func elDeHoy_esElCicloNormal_ySale() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 0)
        try context.save()

        let moved = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(60))
        let created = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(moved == 0)
        #expect(created == 1)
        #expect(try pendingDrafts(of: payment, context).count == 1)
    }

    @Test func elDePagoUnico_noTieneProximaFecha_ySale() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 20, isRecurring: false)
        try context.save()

        let moved = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(60))
        let created = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(moved == 0)
        #expect(payment.isActive)
        #expect(created == 1)
    }

    /// Review adversarial de S11e: el borrador de antes de la pausa se queda; lo de la pausa que venía detrás se salta,
    /// y aprobar ese borrador no lo vuelve a sacar uno a uno.
    @Test func conUnBorradorPendiente_seQueda_yLoDeLaPausaNoSaleDetras() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 40)
        try context.save()
        ScheduledPaymentDraftService.processDuePayments(context: context)
        let draft = try #require(try pendingDrafts(of: payment, context).first)

        let moved = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(60))

        #expect(moved == 1)
        #expect(calendar.startOfDay(for: payment.nextDueDate) > today)
        #expect(try pendingDrafts(of: payment, context).map(\.persistentModelID) == [draft.persistentModelID],
                "el borrador que ya estaba no se toca")

        draft.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)
        #expect(calendar.startOfDay(for: payment.nextDueDate) > today, "aprobarlo se comió la ocurrencia siguiente")
        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 0, "lo de la pausa sale en cascada")
    }

    /// El vencimiento de antes de la pausa que nunca salió: la vuelta lo saca (primera pasada sin tocarlo, luego
    /// `processDuePayments`) y la segunda pasada salta lo de la pausa que venía detrás.
    @Test func vencidoAntesDeLaPausa_sale_yLoDeLaPausaNo() throws {
        let context = try makeTestContext()
        let payment = insertPayment(context, dueDaysAgo: 25)
        try context.save()
        let due = payment.nextDueDate

        let first = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(20))
        #expect(first == 0)
        #expect(payment.nextDueDate == due)

        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 1)
        let second = ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(
            context: context, pausedSince: daysAgo(20))
        #expect(second == 1)
        let draft = try #require(try pendingDrafts(of: payment, context).first)
        #expect(calendar.isDate(try #require(draft.date), inSameDayAs: due))

        draft.status = .approved
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)
        #expect(ScheduledPaymentDraftService.processDuePayments(context: context) == 0)
    }
}
