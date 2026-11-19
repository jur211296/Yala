//
//  FlujoCrearPlanArmadoTests.swift
//  YalaTests
//
//  S5 del replanteo, de punta a punta con el almacén: el armado propone solo subcategorías (y la categoría sin
//  subcategorías), crea el plan con límites fijos, y «Agregar línea › Desde mis gastos» siembra el límite como el
//  motor (meses completos anteriores, con signo). Fichero propio: pide `makeTestContext()`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Flujo de caja · crear plan · armado y semilla", .serialized)
@MainActor
struct FlujoCrearPlanArmadoTests {

    private static func inicioDeMes(_ offset: Int, desde ahora: Date = .now) -> Date {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: ahora)) ?? ahora
        return calendar.date(byAdding: .day, value: 9, to: calendar.date(byAdding: .month, value: offset, to: start) ?? start) ?? start
    }

    private static func tx(
        _ context: ModelContext, _ amount: Double, _ date: Date, _ category: YalaCategory, sub: Subcategory? = nil
    ) -> TransactionItem {
        let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN", category: category,
                                   subcategory: sub, amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN")
        context.insert(item)
        return item
    }

    @Test func elArmado_proponeSubcategorias_yCreaLimitesFijos() throws {
        let context = try makeTestContext()
        let sueldo = YalaCategory(name: "Sueldo", colorHex: "#000000", isIncome: true)
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        let gym = YalaCategory(name: "Gym", colorHex: "#000000", isIncome: false)
        [sueldo, comida, gym].forEach(context.insert)
        let super_ = Subcategory(name: "Supermercado", category: comida)
        let resto = Subcategory(name: "Restaurantes", category: comida)
        [super_, resto].forEach(context.insert)
        var all: [TransactionItem] = []
        for offset in -6 ... -1 {
            let date = Self.inicioDeMes(offset)
            all.append(Self.tx(context, 4_000, date, sueldo))
            all.append(Self.tx(context, -300, date, comida, sub: super_))
            all.append(Self.tx(context, -50, date, comida))
            all.append(Self.tx(context, -80, date, gym))
            if offset >= -4 { all.append(Self.tx(context, -100, date, comida, sub: resto)) }
        }
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)

        viewModel.generateSuggestions(transactions: all, scheduledPayments: [], categories: [sueldo, comida, gym],
                                      currencyCode: "PEN")
        #expect(viewModel.suggestedLines.contains { $0.name == "Comida" && $0.subcategory == nil },
                "control: sin el filtro el armado propone la categoría madre")
        viewModel.suggestedLines = FlujoCrearPlanLogica.porSubcategoria(viewModel.suggestedLines)
        #expect(Set(viewModel.suggestedLines.map(\.name)) == ["Sueldo", "Supermercado", "Restaurantes", "Gym"])

        viewModel.selectAllSuggestedLines()
        viewModel.suggestedLines = FlujoCrearPlanLogica.conLimiteFijo(viewModel.suggestedLines)
        viewModel.createPlan(startingBalance: 0)

        let lines = try #require(viewModel.plan?.lines)
        #expect(lines.count == 4)
        #expect(lines.allSatisfy { $0.method == .manual }, "el límite queda fijo")
        let porNombre = Dictionary(uniqueKeysWithValues: lines.map { ($0.name, $0) })
        #expect(porNombre["Supermercado"]?.manualAmount == 300)
        #expect(porNombre["Supermercado"]?.subcategory?.name == "Supermercado")
        #expect(porNombre["Supermercado"]?.category?.name == "Comida", "la categoría sale de la subcategoría")
        #expect(porNombre["Restaurantes"]?.manualAmount == 100)
        #expect(porNombre["Gym"]?.manualAmount == 80)
        #expect(porNombre["Gym"]?.subcategory == nil, "sin subcategorías, la línea es de la categoría")
        #expect(porNombre["Sueldo"]?.manualAmount == 4_000)
    }

    @Test func laSemilla_cuentaMesesCompletosConSigno_ySigueElMetodo() throws {
        let context = try makeTestContext()
        let calendar = Calendar.current
        let ahora = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12)))
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        context.insert(comida)
        let super_ = Subcategory(name: "Supermercado", category: comida)
        context.insert(super_)
        var all: [TransactionItem] = []
        func en(_ offset: Int, _ amount: Double) {
            all.append(Self.tx(context, amount, Self.inicioDeMes(offset, desde: ahora), comida, sub: super_))
        }
        en(-1, -400)
        en(-2, -200); en(-2, 50)   // una devolución resta
        en(-3, -300)
        en(-6, -600)
        en(0, -999)                // el mes en curso, a medias, no cuenta
        try context.save()
        let index = TransactionIndex(transactions: FlujoCrearPlanLogica.movimientosDelPlan(all), currencyCode: "PEN",
                                     converter: CurrencyConverter.shared, calendar: calendar)

        func semilla(_ metodo: EstimationMethod) -> Double {
            FlujoCrearPlanLogica.semilla(metodo: metodo, categoria: comida, subcategoria: super_, esIngreso: false,
                                         indice: index, ahora: ahora, calendario: calendar)
        }

        #expect(semilla(.average6m) == 1_450.0 / 4)
        #expect(abs(semilla(.average3m) - 850.0 / 3) < 0.001)
        #expect(semilla(.lastMonth) == 400)
        #expect(FlujoCrearPlanLogica.semilla(metodo: .average6m, categoria: nil, subcategoria: nil, esIngreso: false,
                                             indice: index, ahora: ahora, calendario: calendar) == 0)
    }
}
