//
//  RecurringProposalPreferencesTests.swift
//  YalaTests
//
//  Lo que la persona contesta a una propuesta (lote S1): «No es fijo» descarta hasta «Volver a proponer», «Ahora no»
//  oculta hasta un cobro nuevo, el interruptor apaga todo, y todo sobrevive a reabrir la app (mismo `UserDefaults`).
//  También el paso de propuesta a pago planificado (`RecurringProposalPlan`).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Pagos que se repiten · respuestas y plan")
struct RecurringProposalPreferencesTests {

    nonisolated private static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    nonisolated private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    private static func proposal(
        key: String = "brand:netflix|PEN",
        name: String = "Netflix",
        brandID: String? = "netflix",
        cadence: RecurringPaymentDetector.Cadence = .monthly(day: 14, isApproximate: false),
        lastCharge: Date = date(2026, 11, 14),
        isVariable: Bool = false
    ) -> RecurringPaymentDetector.Proposal {
        RecurringPaymentDetector.Proposal(
            key: key, displayName: name, brandID: brandID, currencyCode: "PEN", cadence: cadence,
            chargeCount: 5, firstChargeDate: date(2026, 7, 14), lastChargeDate: lastCharge, amount: 44.90,
            isVariableAmount: isVariable, nextDueDate: date(2026, 12, 14), lastChargeRef: 4, chargeRefs: [0, 1, 2, 3, 4]
        )
    }

    // MARK: - Respuestas

    @Test func porDefecto_encendidoYSinNadaContestado() {
        let prefs = RecurringProposalPreferences(defaults: makeIsolatedDefaults())
        let netflix = Self.proposal()
        #expect(prefs.isEnabled)
        #expect(prefs.visible([netflix]) == [netflix])
        #expect(prefs.hasSomethingToManage == false)
    }

    @Test func noEsFijo_descartaHastaVolverAProponer_ySobreviveAReabrir() throws {
        let defaults = makeIsolatedDefaults()
        let prefs = RecurringProposalPreferences(defaults: defaults)
        let netflix = Self.proposal()
        let uber = Self.proposal(key: "name:uber eats|PEN", name: "Uber Eats", brandID: nil)

        prefs.dismiss(netflix, now: Self.date(2026, 11, 2))
        #expect(prefs.visible([netflix, uber]) == [uber])
        #expect(prefs.hasSomethingToManage)

        // Otra instancia con el mismo almacén: es lo que ve la app al volver a abrirse.
        let reopened = RecurringProposalPreferences(defaults: defaults)
        let entry = try #require(reopened.dismissed.first)
        #expect(entry.name == "Netflix")
        #expect(entry.dismissedAt == Self.date(2026, 11, 2))
        // Un cobro nuevo no lo devuelve: descartado es descartado.
        #expect(reopened.visible([Self.proposal(lastCharge: Self.date(2026, 12, 14))]).isEmpty)

        reopened.restore(entry)
        #expect(reopened.visible([netflix]) == [netflix])
        #expect(RecurringProposalPreferences(defaults: defaults).dismissed.isEmpty)
    }

    @Test func ahoraNo_ocultaHastaUnCobroNuevo() {
        let defaults = makeIsolatedDefaults()
        let prefs = RecurringProposalPreferences(defaults: defaults)
        let netflix = Self.proposal()

        prefs.snooze(netflix)
        #expect(prefs.visible([netflix]).isEmpty)
        #expect(prefs.hasSomethingToManage == false) // lo pospuesto no se gestiona: vuelve solo
        #expect(RecurringProposalPreferences(defaults: defaults).visible([netflix]).isEmpty)

        let nextMonth = Self.proposal(lastCharge: Self.date(2026, 12, 14))
        #expect(prefs.visible([nextMonth]) == [nextMonth])
    }

    @Test func interruptorApagado_noEnsenaNada_yQuedaParaGestionar() {
        let defaults = makeIsolatedDefaults()
        let prefs = RecurringProposalPreferences(defaults: defaults)
        prefs.setEnabled(false)
        #expect(prefs.visible([Self.proposal()]).isEmpty)
        #expect(prefs.hasSomethingToManage)
        #expect(RecurringProposalPreferences(defaults: defaults).isEnabled == false)
        prefs.setEnabled(true)
        #expect(prefs.visible([Self.proposal()]).count == 1)
    }

    @Test func crearElPago_olvidaLoQueHabia() {
        let prefs = RecurringProposalPreferences(defaults: makeIsolatedDefaults())
        let netflix = Self.proposal()
        prefs.snooze(netflix)
        prefs.forget(netflix)
        #expect(prefs.snoozed.isEmpty)
        prefs.dismiss(netflix)
        prefs.forget(netflix)
        #expect(prefs.dismissed.isEmpty)
    }

    // MARK: - Plan del pago

    @Test func planMensual_tomaElDiaDeLaFechaElegida_yEsSuscripcionSiHayMarca() {
        let plan = RecurringProposalPlan(
            proposal: Self.proposal(), firstCharge: Self.date(2026, 12, 16), reminder: .default, calendar: Self.lima
        )
        #expect(plan.recurrenceType == .monthly)
        #expect(plan.dayOfMonth == 16)
        #expect(plan.weekdays.isEmpty)
        #expect(plan.paymentDate == Self.lima.startOfDay(for: Self.date(2026, 12, 16)))
        #expect(plan.paymentCategory == .subscription)
        #expect(plan.notifyOnDueDate)
        #expect(plan.notifyDaysBefore == 1)
    }

    @Test func planSemanal_sinMarca_esRecurrenteYDeMontoVariable() {
        let plan = RecurringProposalPlan(
            proposal: Self.proposal(key: "name:clases|PEN", name: "Clases", brandID: nil,
                                    cadence: .weekly(weekday: 3), isVariable: true),
            firstCharge: Self.date(2026, 11, 24), // martes
            reminder: .none,
            calendar: Self.lima
        )
        #expect(plan.recurrenceType == .weekly)
        #expect(plan.dayOfMonth == nil)
        #expect(plan.weekdays == [3])
        #expect(plan.paymentCategory == .recurring)
        #expect(plan.isVariableAmount)
        #expect(plan.notifyOnDueDate == false)
        #expect(plan.notifyDaysBefore == 0)
    }

    @Test func primerAviso() {
        let due = Self.date(2026, 12, 14)
        let now = Self.date(2026, 11, 20)
        #expect(RecurringProposalPlan.firstReminderDate(dueDate: due, reminder: .oneDay, now: now, calendar: Self.lima)
                == Self.lima.startOfDay(for: Self.date(2026, 12, 13)))
        #expect(RecurringProposalPlan.firstReminderDate(dueDate: due, reminder: .sameDay, now: now, calendar: Self.lima)
                == Self.lima.startOfDay(for: due))
        #expect(RecurringProposalPlan.firstReminderDate(dueDate: due, reminder: .none, now: now, calendar: Self.lima) == nil)
    }

    @Test func primerAviso_nuncaPrometeUnaFechaPasada() {
        // El cobro es hoy y el aviso era «1 semana antes»: el aviso que queda es el del día.
        let today = Self.date(2026, 11, 20)
        #expect(RecurringProposalPlan.firstReminderDate(dueDate: today, reminder: .oneWeek, now: today, calendar: Self.lima)
                == Self.lima.startOfDay(for: today))
    }

    @Test func diaDelMes_cobrosEl31_noSeQuedaEnEl30() {
        // Próximo cobro el 30 de noviembre (noviembre no tiene 31): se guarda el 31 y el calendario lo acorta.
        let plan = RecurringProposalPlan(
            proposal: Self.proposal(key: "name:alquiler|PEN", name: "Alquiler", brandID: nil,
                                    cadence: .monthly(day: 31, isApproximate: false)),
            firstCharge: Self.date(2026, 11, 30), reminder: .default, calendar: Self.lima
        )
        #expect(plan.dayOfMonth == 31)
        // Si la persona eligió otro día a propósito (el 29), se respeta.
        let moved = RecurringProposalPlan(
            proposal: Self.proposal(cadence: .monthly(day: 31, isApproximate: false)),
            firstCharge: Self.date(2026, 11, 29), reminder: .default, calendar: Self.lima
        )
        #expect(moved.dayOfMonth == 29)
    }
}
