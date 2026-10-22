//
//  DraftFutureDateLogicTests.swift
//  YalaTests
//
//  Un registro de «hoy» leído de una foto o de una nota de voz se puede guardar a cualquier hora (2026-10-12). La foto y
//  la voz fijan la fecha a las 12:00; comparada por instante, era futura hasta el mediodía y «Guardar» salía apagado.
//  Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Fecha futura de un borrador — por día, no por instante", .serialized)
struct DraftFutureDateLogicTests {

    // MARK: - El criterio, con reloj y zona fijos

    private func calendar(_ identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    private func date(_ calendar: Calendar, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
    }

    /// El caso del ticket: el seam y el modelo fechan «hoy» a las 12:00, y a las 00:53 de Lima era futuro.
    @Test(arguments: ["America/Lima", "UTC", "Asia/Tokyo"])
    func todayAtNoon_isNotFuture_beforeNoon(zone: String) throws {
        let calendar = try calendar(zone)
        let noonToday = try date(calendar, 12, 12)
        for now in [try date(calendar, 12, 0, 0), try date(calendar, 12, 0, 53), try date(calendar, 12, 11, 59)] {
            #expect(!DraftFutureDateLogic.isFuture(noonToday, now: now, calendar: calendar), "now = \(now) en \(zone)")
        }
    }

    @Test func todayAtNoon_isNotFuture_afterNoon() throws {
        let calendar = try calendar("America/Lima")
        #expect(!DraftFutureDateLogic.isFuture(try date(calendar, 12, 12), now: try date(calendar, 12, 18), calendar: calendar))
    }

    @Test func endOfToday_isNotFuture() throws {
        let calendar = try calendar("America/Lima")
        let endOfToday = try date(calendar, 12, 23, 59)
        #expect(!DraftFutureDateLogic.isFuture(endOfToday, now: try date(calendar, 12, 0, 1), calendar: calendar))
    }

    /// Control: lo que sí es futuro lo sigue siendo, también a un minuto de la medianoche.
    @Test func tomorrow_isFuture_evenAMinuteBeforeMidnight() throws {
        let calendar = try calendar("America/Lima")
        let now = try date(calendar, 12, 23, 59)
        #expect(DraftFutureDateLogic.isFuture(try date(calendar, 13, 0, 0), now: now, calendar: calendar))
        #expect(DraftFutureDateLogic.isFuture(try date(calendar, 13, 12), now: now, calendar: calendar))
    }

    @Test func yesterday_isNotFuture() throws {
        let calendar = try calendar("America/Lima")
        #expect(!DraftFutureDateLogic.isFuture(try date(calendar, 11, 23, 59), now: try date(calendar, 12, 0, 1), calendar: calendar))
    }

    /// El día lo decide el calendario que se pasa: el mismo instante es «hoy» en Lima y «mañana» en Tokio.
    @Test func theDayIsTheCalendarsDay() throws {
        let lima = try calendar("America/Lima")
        let now = try date(lima, 12, 12) // 17:00 UTC · 02:00 del 13 en Tokio
        let laterToday = try date(lima, 12, 20) // 01:00 UTC del 13 · 10:00 del 13 en Tokio
        #expect(!DraftFutureDateLogic.isFuture(laterToday, now: now, calendar: lima))
        #expect(!DraftFutureDateLogic.isFuture(laterToday, now: now, calendar: try calendar("Asia/Tokyo")))
        #expect(DraftFutureDateLogic.isFuture(laterToday, now: now, calendar: try calendar("UTC")))
    }

    // MARK: - La Bandeja aprueba lo de hoy a cualquier hora

    /// Final de hoy: futuro por instante a cualquier hora del día, hoy por día. Así el test no depende de cuándo corre.
    private var endOfToday: Date {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return startOfTomorrow.addingTimeInterval(-1)
    }

    private var noonTomorrow: Date {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return startOfTomorrow.addingTimeInterval(12 * 3600)
    }

    private func makeDraft(dated date: Date, in context: ModelContext) throws -> InboxDraft {
        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)
        let draft = InboxDraft(note: "Cena", amount: -25, date: date, account: account, subcategory: subcategory, needsUserInput: [])
        context.insert(draft)
        try context.save()
        return draft
    }

    @Test func approveDraft_approvesARecordFromLaterToday() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }

        let draft = try makeDraft(dated: endOfToday, in: context)
        let transaction = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())
        #expect(transaction.date == endOfToday)
    }

    @Test func approveDraft_stillRejectsTomorrow() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }

        let draft = try makeDraft(dated: noonTomorrow, in: context)
        do {
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())
            Issue.record("Un borrador de mañana no se tenía que aprobar.")
        } catch DraftServiceError.futureDateNotAllowed {
            // Lo esperado.
        }
    }

    @Test func bulkApprove_approvesARecordFromLaterToday_andSkipsTomorrow() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }

        let today = try makeDraft(dated: endOfToday, in: context)
        let tomorrow = try makeDraft(dated: noonTomorrow, in: context)
        let transactions = try DraftService.shared.bulkApprove([today, tomorrow], currencyConverter: CurrencyConverter())
        #expect(transactions.map(\.date) == [endOfToday])
    }
}
