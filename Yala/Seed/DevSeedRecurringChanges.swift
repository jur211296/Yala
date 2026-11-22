//
//  DevSeedRecurringChanges.swift
//  Yala
//
//  Fixture de QA del lote S2 de pagos recurrentes (`-uitest-seed-s2-changes`): dos pagos planificados con sus cobros
//  para que Pagos planificados enseñe los dos avisos.
//
//  - «Disney+» planificado a S/ 39,90 y los dos últimos cobros a S/ 44,90 → «Disney+ subió a S/ 44,90».
//  - «Spotify» planificado a S/ 18,90 con cobros hasta hace tres meses → «¿Dejaste de pagar Spotify?».
//
//  Disney+ y no Netflix: los perfiles `minimal` y `realista` ya traen un Netflix de S/ 45 con sus cobros, y los cobros
//  de una marca van al pago de monto más cercano.
//
//  Aditivo al perfil, como `-uitest-seed-foreign-account`, y solo en DEBUG. Discrimina: sin la detección de S2 la
//  página no enseña ninguna de las dos tarjetas, y con un pago que cuadra (o con un solo cobro distinto) tampoco.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DevSeedRecurringChanges {

    static func create(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.isSystemAccount == false }))
        } catch {
            print("DevSeedRecurringChanges: Error fetching accounts: \(error)")
            return
        }
        let account = accounts.first { $0.currencyCode == "PEN" } ?? accounts.first
        let today = calendar.startOfDay(for: now)
        let created = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let monthsAgo = { (months: Int, day: Int) -> Date in
            let month = calendar.date(byAdding: .month, value: -months, to: today) ?? today
            var parts = calendar.dateComponents([.year, .month], from: month)
            parts.day = day
            parts.hour = 12
            return calendar.date(from: parts) ?? month
        }

        let disney = payment("Disney+", amount: 39.90, day: 14, account: account, created: created, today: today)
        context.insert(disney)
        for (months, amount) in [(3, 39.90), (2, 44.90), (1, 44.90)] {
            context.insert(charge("Disney+", amount: amount, date: monthsAgo(months, 14), account: account))
        }

        let spotify = payment("Spotify", amount: 18.90, day: 5, account: account, created: created, today: today)
        context.insert(spotify)
        for months in [5, 4, 3] {
            context.insert(charge("Spotify", amount: 18.90, date: monthsAgo(months, 5), account: account))
        }

        do {
            try context.save()
        } catch {
            print("DevSeedRecurringChanges: Error saving: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }

    private static func payment(
        _ name: String, amount: Double, day: Int, account: Account?, created: Date, today: Date
    ) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: name,
            amount: amount,
            currencyCode: "PEN",
            transactionType: TransactionType.expense.rawValue,
            account: account,
            subcategory: nil,
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: today,
            dayOfMonth: day,
            paymentCategory: "subscription",
            notifyOnDueDate: false,
            notifyDaysBefore: 0,
            isVariableAmount: false
        )
        payment.createdAt = created
        return payment
    }

    private static func charge(_ name: String, amount: Double, date: Date, account: Account?) -> TransactionItem {
        let tx = TransactionItem(date: date, amount: -amount, currencyCode: "PEN", note: name, category: nil,
                                 subcategory: nil, account: account)
        tx.createdAt = date
        return tx
    }
}
#endif
