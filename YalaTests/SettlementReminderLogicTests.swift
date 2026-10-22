//
//  SettlementReminderLogicTests.swift
//  YalaTests
//
//  Los AC del recordatorio amable de liquidación, pinneados sin `ModelContext` ni `Date.now`.
//
//  Cubre las tres piezas de decisión del feature: la lógica pura (`SettlementReminderLogic`), el
//  dedup (`SettlementReminderTracker`, con `UserDefaults` aislado) y la extracción de actividad
//  (`GroupSettlementReminderService.activities`, que es `static` y no toca el contexto).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Helpers

private let ME = "AAAAAAAA-0000-0000-0000-000000000001"
private let ANA = "BBBBBBBB-0000-0000-0000-000000000002"
private let CARLOS = "CCCCCCCC-0000-0000-0000-000000000003"

private let NOW = Date(timeIntervalSince1970: 1_757_000_000)   // 2025-09-04, fijo

private func daysAgo(_ days: Double) -> Date {
    NOW.addingTimeInterval(-days * 24 * 60 * 60)
}

private func debt(from: String, to: String, amount: Double = 50, currency: String = "PEN") -> Debt {
    Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
}

@Suite("Recordatorio de liquidación · lógica pura")
struct SettlementReminderLogicTests {

    // MARK: - Par canónico

    @Test("la clave del par no depende del orden en que se nombren")
    func pairKeyIsOrderIndependent() {
        #expect(SettlementReminderLogic.pairKey(ME, ANA) == SettlementReminderLogic.pairKey(ANA, ME))
        #expect(SettlementReminderLogic.pairKey(ME, ANA) != SettlementReminderLogic.pairKey(ME, CARLOS))
    }

    @Test("de cada par se queda la actividad MÁS RECIENTE")
    func lastActivityKeepsTheMostRecent() {
        let activities = [
            DebtActivity(memberA: ME, memberB: ANA, at: daysAgo(40)),
            DebtActivity(memberA: ANA, memberB: ME, at: daysAgo(2)),    // orden invertido a propósito
            DebtActivity(memberA: ME, memberB: ANA, at: daysAgo(30)),
        ]
        let byPair = SettlementReminderLogic.lastActivityByPair(activities, now: NOW)
        #expect(byPair.count == 1)
        #expect(byPair[SettlementReminderLogic.pairKey(ME, ANA)] == daysAgo(2))
    }

    // MARK: - AC · solo al deudor

    @Test("AC · avisa al DEUDOR y jamás al acreedor")
    func onlyTheDebtorIsNudged() {
        let debts = [debt(from: ME, to: ANA), debt(from: CARLOS, to: ME)]
        let activity = [
            SettlementReminderLogic.pairKey(ME, ANA): daysAgo(40),
            SettlementReminderLogic.pairKey(ME, CARLOS): daysAgo(40),
        ]
        let due = SettlementReminderLogic.dueReminders(
            debts: debts, currentMemberID: ME, lastActivityByPair: activity,
            lastNotifiedByDebt: [:], now: NOW)

        #expect(due.count == 1)
        // La que me deben A MÍ (Carlos → yo) no genera nudge: el acreedor ya lo sabe.
        #expect(due.first?.toMemberID == ANA)
    }

    @Test("sin identidad resuelta no se avisa de nada")
    func noIdentityMeansNoReminder() {
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA)], currentMemberID: nil,
            lastActivityByPair: [SettlementReminderLogic.pairKey(ME, ANA): daysAgo(90)],
            lastNotifiedByDebt: [:], now: NOW)
        #expect(due.isEmpty)
    }

    // MARK: - AC · antigüedad

    @Test("AC · por debajo del umbral no molesta; por encima sí")
    func staleThresholdIsRespected() {
        let debts = [debt(from: ME, to: ANA)]
        func due(idleDays: Double) -> [Debt] {
            SettlementReminderLogic.dueReminders(
                debts: debts, currentMemberID: ME,
                lastActivityByPair: [SettlementReminderLogic.pairKey(ME, ANA): daysAgo(idleDays)],
                lastNotifiedByDebt: [:], now: NOW)
        }
        #expect(due(idleDays: 20).isEmpty)      // 3 semanas es el umbral por defecto
        #expect(due(idleDays: 21).count == 1)   // el borde exacto SÍ entra (>=)
        #expect(due(idleDays: 60).count == 1)
    }

    @Test("AC · un gasto o una liquidación reciente entre los dos RESETEA el contador")
    func recentActivityResetsTheClock() {
        // La deuda es vieja, pero las dos personas se movieron ayer: no se molesta a nadie.
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA)], currentMemberID: ME,
            lastActivityByPair: [SettlementReminderLogic.pairKey(ME, ANA): daysAgo(1)],
            lastNotifiedByDebt: [:], now: NOW)
        #expect(due.isEmpty)
    }

    @Test("la actividad de OTRO par no calla la deuda propia")
    func activityWithSomeoneElseDoesNotSilenceThisDebt() {
        // Un piso compartido con gastos constantes: si el reloj fuera del GRUPO, el nudge no
        // saltaría nunca. Se mide por par justo para que sí salte.
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA)], currentMemberID: ME,
            lastActivityByPair: [
                SettlementReminderLogic.pairKey(ME, ANA): daysAgo(40),
                SettlementReminderLogic.pairKey(ME, CARLOS): daysAgo(1),
            ],
            lastNotifiedByDebt: [:], now: NOW)
        #expect(due.count == 1)
        #expect(due.first?.toMemberID == ANA)
    }

    @Test("sin evidencia de actividad no se afirma antigüedad (fail-closed)")
    func noActivityEvidenceMeansNoReminder() {
        // Ocurre de verdad con `simplifyDebts`: el acreedor puede ser alguien con quien nunca
        // se compartió un gasto directo.
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA)], currentMemberID: ME,
            lastActivityByPair: [:], lastNotifiedByDebt: [:], now: NOW)
        #expect(due.isEmpty)
    }

    @Test("una deuda ya saldada (importe 0) no genera nudge")
    func zeroAmountIsNotADebt() {
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA, amount: 0)], currentMemberID: ME,
            lastActivityByPair: [SettlementReminderLogic.pairKey(ME, ANA): daysAgo(90)],
            lastNotifiedByDebt: [:], now: NOW)
        #expect(due.isEmpty)
    }

    // MARK: - AC · rate-limit

    @Test("AC · no se repite antes del rate-limit, aunque el chequeo corra a diario")
    func rateLimitSuppressesRepeats() {
        let d = debt(from: ME, to: ANA)
        let activity = [SettlementReminderLogic.pairKey(ME, ANA): daysAgo(90)]
        func due(notifiedDaysAgo: Double) -> [Debt] {
            SettlementReminderLogic.dueReminders(
                debts: [d], currentMemberID: ME, lastActivityByPair: activity,
                lastNotifiedByDebt: [d.id: daysAgo(notifiedDaysAgo)], now: NOW)
        }
        #expect(due(notifiedDaysAgo: 1).isEmpty)    // avisado ayer
        #expect(due(notifiedDaysAgo: 6).isEmpty)
        #expect(due(notifiedDaysAgo: 7).count == 1) // una semana después, otra vez
    }

    @Test("el rate-limit es POR DEUDA: avisar de una no calla la otra")
    func rateLimitIsPerDebt() {
        let toAna = debt(from: ME, to: ANA)
        let toCarlos = debt(from: ME, to: CARLOS)
        let due = SettlementReminderLogic.dueReminders(
            debts: [toAna, toCarlos], currentMemberID: ME,
            lastActivityByPair: [
                SettlementReminderLogic.pairKey(ME, ANA): daysAgo(90),
                SettlementReminderLogic.pairKey(ME, CARLOS): daysAgo(90),
            ],
            lastNotifiedByDebt: [toAna.id: daysAgo(1)], now: NOW)
        #expect(due.count == 1)
        #expect(due.first?.toMemberID == CARLOS)
    }

    // MARK: - A quién nombra el aviso

    @Test("dos monedas con la MISMA persona no son «varias personas»")
    func twoCurrenciesSameCreditorIsStillOneCreditor() {
        // Viaje con Ana: le debo 50 PEN y 30 USD. Son dos `Debt` (la clave lleva la divisa) pero UNA
        // sola acreedora — contar deudas diría «tienes cuentas pendientes con varias personas» en un
        // grupo que puede tener dos miembros.
        let due = [debt(from: ME, to: ANA, amount: 50, currency: "PEN"),
                   debt(from: ME, to: ANA, amount: 30, currency: "USD")]
        #expect(due.count == 2)
        #expect(SettlementReminderLogic.namesASingleCreditor(due))
    }

    @Test("dos acreedores distintos sí son «varias personas»")
    func twoDifferentCreditorsAreMany() {
        #expect(!SettlementReminderLogic.namesASingleCreditor(
            [debt(from: ME, to: ANA), debt(from: ME, to: CARLOS)]))
    }

    // MARK: - Fechas imposibles

    @Test("una fecha FUTURA no puede silenciar el recordatorio durante años")
    func futureActivityIsClampedToNow() {
        // La fecha de un gasto y la de una liquidación las teclea el usuario en un `DatePicker` sin
        // rango: un dedo gordo en el año es alcanzable. Como aquí se toma el MÁXIMO, sin clamp esa
        // fecha ganaría a todas las reales y el aviso moriría en silencio hasta 2027.
        let byPair = SettlementReminderLogic.lastActivityByPair(
            [DebtActivity(memberA: ME, memberB: ANA, at: NOW.addingTimeInterval(600 * 24 * 60 * 60)),
             DebtActivity(memberA: ME, memberB: ANA, at: daysAgo(90))],
            now: NOW)
        #expect(byPair[SettlementReminderLogic.pairKey(ME, ANA)] == NOW)

        // Y el efecto medible: se recupera un ciclo de umbral después, no dentro de dos años.
        let due = SettlementReminderLogic.dueReminders(
            debts: [debt(from: ME, to: ANA)], currentMemberID: ME,
            lastActivityByPair: [SettlementReminderLogic.pairKey(ME, ANA): NOW],
            lastNotifiedByDebt: [:], now: NOW.addingTimeInterval(22 * 24 * 60 * 60))
        #expect(due.count == 1)
    }

    // MARK: - Orden

    @Test("el orden es determinista: la deuda más quieta va primero")
    func orderIsStableAndOldestFirst() {
        let toAna = debt(from: ME, to: ANA)
        let toCarlos = debt(from: ME, to: CARLOS)
        let activity = [
            SettlementReminderLogic.pairKey(ME, ANA): daysAgo(30),
            SettlementReminderLogic.pairKey(ME, CARLOS): daysAgo(90),
        ]
        // El caller manda UNA notificación por grupo y toma la primera: sin orden estable, dos
        // corridas con los mismos datos nombrarían a personas distintas.
        for input in [[toAna, toCarlos], [toCarlos, toAna]] {
            let due = SettlementReminderLogic.dueReminders(
                debts: input, currentMemberID: ME, lastActivityByPair: activity,
                lastNotifiedByDebt: [:], now: NOW)
            #expect(due.map(\.toMemberID) == [CARLOS, ANA])
        }
    }
}

// MARK: - Tracker

@Suite("Recordatorio de liquidación · dedup")
struct SettlementReminderTrackerTests {

    @MainActor
    @Test("una deuda sin avisar no aparece en el mapa; una avisada sí")
    func marksAndReadsBack() {
        let tracker = SettlementReminderTracker(defaults: makeIsolatedDefaults(prefix: "settlement"))
        let d = debt(from: ME, to: ANA)

        #expect(tracker.lastNotified(forDebtIDs: [d.id]).isEmpty)
        tracker.markNotified(debtID: d.id, at: NOW)
        #expect(tracker.lastNotified(forDebtIDs: [d.id])[d.id] == NOW)
    }

    @MainActor
    @Test("el dedup es por deuda, no por grupo ni por persona")
    func trackingIsPerDebt() {
        let tracker = SettlementReminderTracker(defaults: makeIsolatedDefaults(prefix: "settlement"))
        let toAna = debt(from: ME, to: ANA)
        let toCarlos = debt(from: ME, to: CARLOS)
        let sameCounterpartyOtherCurrency = debt(from: ME, to: ANA, currency: "USD")

        tracker.markNotified(debtID: toAna.id, at: NOW)
        let seen = tracker.lastNotified(forDebtIDs: [toAna.id, toCarlos.id, sameCounterpartyOtherCurrency.id])
        #expect(seen.count == 1)
        #expect(seen[toAna.id] == NOW)
    }

    @MainActor
    @Test("la limpieza suelta lo viejo y conserva lo que aún suprime")
    func cleanupDropsOnlyStaleEntries() {
        let tracker = SettlementReminderTracker(defaults: makeIsolatedDefaults(prefix: "settlement"))
        let old = debt(from: ME, to: ANA)
        let recent = debt(from: ME, to: CARLOS)

        tracker.markNotified(debtID: old.id, at: NOW.addingTimeInterval(-60 * 24 * 60 * 60))
        tracker.markNotified(debtID: recent.id, at: NOW.addingTimeInterval(-2 * 24 * 60 * 60))
        tracker.cleanupOldEntries(now: NOW)

        let seen = tracker.lastNotified(forDebtIDs: [old.id, recent.id])
        #expect(seen[old.id] == nil)
        #expect(seen[recent.id] != nil)
    }
}

// MARK: - Extracción de actividad

@Suite("Recordatorio de liquidación · qué cuenta como actividad")
struct SettlementReminderActivityTests {

    private func expense(paidBy: String, createdAt: Date, date: Date? = nil) -> SplitExpense {
        let e = SplitExpense(groupZoneID: "z", amount: 100, currencyCode: "PEN",
                             expenseDescription: "Cena", paidByMemberID: paidBy)
        e.createdAt = createdAt
        e.date = date ?? createdAt
        return e
    }

    @Test("un gasto cuenta desde que se REGISTRÓ, no desde la fecha del gasto")
    func expenseActivityUsesCreatedAt() {
        // Un gasto retroactivo (fecha del mes pasado, registrado hoy) ES actividad de hoy: con
        // `date` el usuario recibiría un aviso justo después de tocar la deuda.
        let e = expense(paidBy: ME, createdAt: daysAgo(1), date: daysAgo(45))
        let shares = [SplitShare(expenseID: e.id, memberID: ANA, amount: 50)]

        let activities = GroupSettlementReminderService.activities(
            me: ME, expenses: [e], shares: shares, settlements: [])

        #expect(activities.count == 1)
        #expect(activities.first?.at == daysAgo(1))
    }

    @Test("un gasto entre otras dos personas no es actividad MÍA")
    func expenseWithoutMeIsNotMyActivity() {
        let e = expense(paidBy: ANA, createdAt: daysAgo(1))
        let shares = [SplitShare(expenseID: e.id, memberID: CARLOS, amount: 50)]

        let activities = GroupSettlementReminderService.activities(
            me: ME, expenses: [e], shares: shares, settlements: [])
        #expect(activities.isEmpty)
    }

    @Test("un gasto con varios participantes marca actividad con CADA uno")
    func expenseWithSeveralParticipantsMarksEachPair() {
        let e = expense(paidBy: ME, createdAt: daysAgo(3))
        let shares = [
            SplitShare(expenseID: e.id, memberID: ANA, amount: 30),
            SplitShare(expenseID: e.id, memberID: CARLOS, amount: 30),
        ]
        let activities = GroupSettlementReminderService.activities(
            me: ME, expenses: [e], shares: shares, settlements: [])

        #expect(activities.count == 2)
        #expect(Set(activities.map(\.memberB)) == [ANA, CARLOS])
    }

    @Test("una liquidación SIN confirmar también cuenta como actividad")
    func unconfirmedSettlementCountsAsActivity() {
        // No mueve el saldo, pero registrar un pago ES movimiento: recordarle la deuda a quien
        // acaba de decir que la pagó y espera confirmación es justo el tono que se evita.
        let s = SplitSettlement(groupZoneID: "z", fromMemberID: ME, toMemberID: ANA,
                                amount: 50, currencyCode: "PEN")
        s.isConfirmed = false
        s.date = daysAgo(2)

        let activities = GroupSettlementReminderService.activities(
            me: ME, expenses: [], shares: [], settlements: [s])

        #expect(activities.count == 1)
        #expect(activities.first?.at == daysAgo(2))
    }

    @Test("AC · varios gastos con la misma persona son UNA deuda con UNA fecha, no una por gasto")
    func manyExpensesCollapseIntoOneReminder() {
        // Fixture COHERENTE a propósito: 100 de gasto repartido 50/50 entre Ana (pagadora) y yo. Un
        // fixture donde el importe no cuadra con las shares pasa igual —`rawDebts` solo mira shares—
        // pero fija un modelo mental falso para quien escriba el caso siguiente.
        let old = expense(paidBy: ANA, createdAt: daysAgo(90))
        let newer = expense(paidBy: ANA, createdAt: daysAgo(40))
        let shares = [
            SplitShare(expenseID: old.id, memberID: ME, amount: 50),
            SplitShare(expenseID: old.id, memberID: ANA, amount: 50),
            SplitShare(expenseID: newer.id, memberID: ME, amount: 50),
            SplitShare(expenseID: newer.id, memberID: ANA, amount: 50),
        ]

        let activities = GroupSettlementReminderService.activities(
            me: ME, expenses: [old, newer], shares: shares, settlements: [])
        let byPair = SettlementReminderLogic.lastActivityByPair(activities, now: NOW)

        let debts = GroupBalanceService.calculateDebts(
            expenses: [old, newer], shares: shares, settlements: [], simplifyDebts: false)

        let due = SettlementReminderLogic.dueReminders(
            debts: debts, currentMemberID: ME, lastActivityByPair: byPair,
            lastNotifiedByDebt: [:], now: NOW)

        // Dos gastos, un solo recordatorio — y el reloj lo marca el gasto MÁS RECIENTE.
        #expect(due.count == 1)
        #expect(due.first?.amount == 100)
        #expect(byPair[SettlementReminderLogic.pairKey(ME, ANA)] == daysAgo(40))
    }
}
