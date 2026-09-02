//
//  DevSeedScheduledPayments.swift
//  Yala
//
//  Creates 8 scheduled payments for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedScheduledPayments {

    struct Result {
        let payments: [ScheduledPayment]
    }

    /// Nombre fijo (no localizado) del pago que vence hoy, para que los XCUITests lo
    /// localicen igual en cualquier locale — mismo criterio que `DevSeedDrafts.draftNoteA`.
    static let dueTodayName = "Recibo vence hoy"

    @MainActor
    static func create(
        account: Account,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) -> Result {
        let calendar = Calendar.current
        let today = Date.now

        func nextOccurrence(dayOfMonth day: Int) -> Date {
            // Always return THIS month's date if it hasn't passed,
            // otherwise next month — ensures current month has active payments
            var comps = calendar.dateComponents([.year, .month], from: today)
            comps.day = min(day, 28) // Safe for all months
            if let date = calendar.date(from: comps), date >= calendar.startOfDay(for: today) {
                return date
            }
            // Already passed this month → next month
            let currentMonth = comps.month ?? 1
            if currentMonth >= 12 {
                comps.month = 1
                comps.year = (comps.year ?? 2026) + 1
            } else {
                comps.month = currentMonth + 1
            }
            return calendar.date(from: comps) ?? today
        }

        // Days spread across month so most are still upcoming from any seed date
        let definitions: [(name: String, amount: Double, subKey: String, day: Int, category: String, variable: Bool)] = [
            // Subscriptions
            ("Netflix", 45, L10n.Subcategory.streaming, 20, "subscription", false),
            ("Spotify", 18, L10n.Subcategory.streaming, 18, "subscription", false),
            (L10n.DevSeed.spGym, 150, L10n.Subcategory.fitness, 3, "subscription", false),
            ("iCloud+", 10, L10n.Subcategory.utilitySubs, 22, "subscription", false),
            // Recurring
            (L10n.DevSeed.spRent, 2200, L10n.Subcategory.rent, 5, "recurring", false),
            (L10n.DevSeed.spPhone, 60, L10n.Subcategory.phone, 15, "recurring", false),
            (L10n.DevSeed.spInternet, 90, L10n.Subcategory.utilities, 25, "recurring", true),
            (L10n.DevSeed.spInsurance, 180, L10n.Subcategory.insurance, 28, "recurring", true),
        ]

        var payments: [ScheduledPayment] = []

        // `-uitest-scheduled-due-today`: un pago que vence HOY, que los 8 de arriba nunca
        // garantizan (se reparten por el mes y `min(day, 28)` capa los días 29-31).
        //
        // Por qué es un SEAM y no una fila más del fixture: un pago que vence hoy se ordena
        // el PRIMERO de la lista, y `ScheduledPaymentSkipUITests` opera sobre
        // `app.buttons["scheduled_payment_row"].firstMatch` ⇒ meterlo siempre le cambiaría el
        // sujeto a un test verde. Aditivo y apagado por defecto.
        //
        // Es «una sola vez» (`isRecurring: false`) a propósito: replica el resultado de elegir
        // esa opción en el segmentado de Recurrencia, que es la interacción que el QA por
        // árbol de accesibilidad NO puede hacer (los `Picker` segmentados no se enumeran como
        // tapeables). Con esto el escenario se alcanza sin tocar el segmentado.
        //
        // OJO al verificarlo en pantalla: la fila lo rotula «Mensual», no «Una sola vez».
        // No es este seam fallando. `RecurrenceType` no tiene caso `once` —«una sola vez» se
        // modela SOLO con `isRecurring: false`— y `ScheduledPaymentRowView.recurrenceBadge`
        // pinta `recurrenceType` sin mirar `isRecurring`. El `recurrenceType: "monthly"` de
        // abajo es el valor por defecto del modelo, inerte mientras `isRecurring` sea false.
        if UITestHooks.scheduledDueToday {
            // Mediodía, no `startOfDay`: una fecha a medianoche exacta cae en la frontera
            // cerrada de `DateInterval` (CLAUDE.md → «Cálculos con fechas»).
            let dueToday = calendar.startOfDay(for: today).addingTimeInterval(12 * 3600)
            let oneOff = ScheduledPayment(
                name: Self.dueTodayName,
                amount: 75,
                currencyCode: "PEN",
                transactionType: TransactionType.expense.rawValue,
                account: account,
                subcategory: subcategoryLookup[L10n.Subcategory.utilities],
                isRecurring: false,
                recurrenceType: "monthly",
                recurrenceInterval: 1,
                nextDueDate: dueToday,
                dayOfMonth: calendar.component(.day, from: dueToday),
                paymentCategory: "recurring",
                notifyOnDueDate: true,
                notifyDaysBefore: 0,
                isVariableAmount: false
            )
            context.insert(oneOff)
            payments.append(oneOff)
        }

        for def in definitions {
            let sub = subcategoryLookup[def.subKey]
            let payment = ScheduledPayment(
                name: def.name,
                amount: def.amount,
                currencyCode: "PEN",
                transactionType: TransactionType.expense.rawValue,
                account: account,
                subcategory: sub,
                isRecurring: true,
                recurrenceType: "monthly",
                recurrenceInterval: 1,
                nextDueDate: nextOccurrence(dayOfMonth: def.day),
                dayOfMonth: def.day,
                paymentCategory: def.category,
                notifyOnDueDate: true,
                notifyDaysBefore: 3,
                isVariableAmount: def.variable
            )
            context.insert(payment)
            payments.append(payment)
        }

        return Result(payments: payments)
    }
}
#endif
