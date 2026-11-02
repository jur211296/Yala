//
//  DevSeedEarlyMonthHousingTests.swift
//  YalaTests
//
//  `AdaptiveNavigationUITests.test_switchingBudgets_showsTheNewBudgetsSpentAmount` abre «Comidas fuera» y «Fijos
//  casa» con la semilla `realista` y exige que gasten distinto. Vivienda no recibía nada hasta el alquiler del día 5, y
//  Comida puede salir a 0 un día 1 de fin de semana: del 1 al 4 podían salir los dos en S/ 0 (card 04ek). Aquí se fija,
//  con `now` inyectado y sin esperar al día 1, que el gasto de vivienda de esos días cae en el mes en curso y nunca en
//  el futuro, y que la premisa que lo hace distinto de Comida (céntimos contra soles enteros) sigue siendo verdad.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

@Suite("Semilla realista · vivienda de principio de mes", .serialized)
@MainActor
struct DevSeedEarlyMonthHousingTests {

    private typealias Housing = DevSeedTransactions.EarlyMonthHousing
    private let calendar = Calendar.current

    /// Todos los días de 2026 a las 00:30 (el primer tramo del día) y a las 23:30, más febrero de 2028 (bisiesto).
    private func everyMomentToCheck() -> [Date] {
        var moments: [Date] = []
        var day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
        let end = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? .now
        while day < end {
            for (hour, minute) in [(0, 30), (23, 30)] {
                if let moment = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) {
                    moments.append(moment)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for leapDay in 25...29 {
            if let moment = calendar.date(from: DateComponents(year: 2028, month: 2, day: leapDay, hour: 0, minute: 30)) {
                moments.append(moment)
            }
        }
        return moments
    }

    @Test func housingDate_daysOneToFour_staysInTheMonth_andNeverInTheFuture() {
        var problems: [String] = []
        for now in everyMomentToCheck() {
            let day = calendar.component(.day, from: now)
            let date = Housing.date(now: now, calendar: calendar)
            if day < Housing.rentDay {
                guard let date else {
                    problems.append("\(now): sin gasto de vivienda antes del alquiler")
                    continue
                }
                if !calendar.isDate(date, equalTo: now, toGranularity: .month) || date > now {
                    problems.append("\(now) → \(date)")
                }
            } else if let date {
                problems.append("\(now): gasto de vivienda el día \(day) (\(date)); desde el alquiler no hace falta")
            }
        }
        #expect(problems.isEmpty, "Vivienda de principio de mes fuera de sitio: \(problems.prefix(5))")
    }

    @Test func housingDate_onTheFirst_landsOnTheFirstAtMidnight() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30)))
        #expect(Housing.date(now: now, calendar: calendar) == calendar.startOfDay(for: now))
    }

    /// Lo que hace distintos los dos presupuestos: el gasto de vivienda lleva céntimos y todo gasto de Comida de la
    /// semilla va en soles enteros. Si alguien quita el redondeo del generador, esto avisa antes que el XCUITest.
    @Test func realistaSeed_foodIsWholeSoles_andHousingAmountIsNot() async throws {
        #expect(Housing.amount.rounded() != Housing.amount, "El gasto de vivienda tiene que llevar céntimos.")

        // El centinela de la semilla de categorías vive en `UserDefaults.standard` y sobrevive entre corridas: puesto, la
        // semilla sale sin categorías y sin subcategorías (medido: la segunda corrida veía el corpus vacío). Molde de
        // `YalaIABankDumpTests`: se baja para sembrar y se devuelve como estaba.
        let sentinelKey = CategorySeedSentinel.currentKey
        let previousSentinel = UserDefaults.standard.object(forKey: sentinelKey)
        UserDefaults.standard.removeObject(forKey: sentinelKey)
        defer { UserDefaults.standard.set(previousSentinel, forKey: sentinelKey) }

        let context = try makeTestContext()
        await DevSeedService().seed(in: context, profile: .realista)
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let food = transactions.filter { $0.category?.name == L10n.Category.food && $0.amount < 0 }
        #expect(!food.isEmpty, "La semilla realista no trae gastos de Comida.")
        let fractional = food.filter { $0.amountInPreferredCurrency.rounded() != $0.amountInPreferredCurrency }
        #expect(fractional.isEmpty, "Gastos de Comida con céntimos: \(fractional.prefix(3).map(\.amount))")

        // Y hoy, el mismo día que corra: los dos meses en curso no gastan lo mismo.
        guard let month = calendar.dateInterval(of: .month, for: .now) else { return }
        func spent(_ categoryName: String) -> Double {
            transactions
                .filter { $0.category?.name == categoryName && $0.amount < 0 && month.contains($0.date) && $0.date <= .now }
                .reduce(0) { $0 + $1.amountInPreferredCurrency }
        }
        #expect(spent(L10n.Category.food) != spent(L10n.Category.housing),
                "«Comidas fuera» y «Fijos casa» gastan lo mismo este mes: el XCUITest no discrimina.")
        if calendar.component(.day, from: .now) < Housing.rentDay {
            #expect(transactions.contains { $0.amount == Housing.amount && month.contains($0.date) },
                    "Hoy es día \(calendar.component(.day, from: .now)) y la semilla no trae el gasto de vivienda.")
        }
    }
}

#endif
