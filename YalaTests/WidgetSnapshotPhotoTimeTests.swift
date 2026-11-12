//
//  WidgetSnapshotPhotoTimeTests.swift
//  YalaTests
//
//  Los widgets miden los períodos a la hora de la foto (`lastUpdated`). La foto tiene que llevar
//  el MISMO «ahora» con el que se calcularon sus períodos: con dos relojes, una foto empezada a
//  las 23:59:59 del último día del mes y guardada pasada la medianoche leía «Este mes» como el
//  mes siguiente (barras de Entradas y salidas vacías, comparaciones contra el mes equivocado).
//  Card `tablero-widgets-la-hora-de-la-foto-lastupdated-n-v8ou`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct WidgetSnapshotPhotoTimeTests {

    /// 31 de enero de 2026, 23:59:59 en el calendario del dispositivo: el último segundo del mes.
    private static var lastSecondOfJanuary: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? .distantPast
    }

    @Test("La foto lleva el «ahora» de sus períodos aunque se construya a caballo de medianoche")
    func lastUpdated_isTheNowOfThePeriods() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: SwiftDataConfiguration.schema, configurations: [config]))

        let currency = WidgetDataCache.preferredCurrencyCode()
        let account = Account(
            name: "Cuenta", currencyCode: currency, colorHex: "#000000", iconName: "banknote", type: "Efectivo"
        )
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        context.insert(account)
        context.insert(food)
        // Un gasto de enero: la foto del 31 a las 23:59:59 lo cuenta en «Este mes».
        let january15 = Calendar.current.date(byAdding: .day, value: -16, to: Self.lastSecondOfJanuary) ?? .distantPast
        context.insert(TransactionItem(
            date: january15, amount: -50, currencyCode: currency, category: food, account: account,
            amountInPreferredCurrency: -50
        ))
        try context.save()

        let now = Self.lastSecondOfJanuary
        let snapshot = WidgetDataCache.buildSnapshot(context: context, now: now).widget

        // El contrato: la hora de la foto es la de sus períodos, no la del reloj al terminar de construirla.
        #expect(snapshot.lastUpdated == now)

        // Y por eso el widget, que mide «Este mes» a la hora de la foto, lee el mismo mes que la caché calculó.
        let widgetThisMonth = DetailPeriod.thisMonth.dateInterval(now: snapshot.lastUpdated)
        let cachedThisMonth = DetailPeriod.thisMonth.dateInterval(now: now)
        #expect(widgetThisMonth == cachedThisMonth)
        #expect(widgetThisMonth.contains(january15))

        let thisMonth = try #require(snapshot.periodSummaries[DetailPeriod.thisMonth.rawValue])
        #expect(thisMonth.totalExpense == 50)
        #expect(snapshot.thisMonthSummary.totalExpense == 50)
    }
}
