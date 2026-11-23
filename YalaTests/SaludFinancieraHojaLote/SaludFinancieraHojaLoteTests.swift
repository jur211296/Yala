//
//  SaludFinancieraHojaLoteTests.swift
//  YalaTests
//
//  Lote de la hoja «Tu salud financiera» (23-nov-2026), tres cards:
//   • Un presupuesto creado a mitad de período cuenta en la nota desde ya y, si ya se pasó, la baja (decisión de Jürgen
//     del 22-nov-2026). Antes la nota salía 100 y decía «empieza a contar en tu nota el 1 de diciembre».
//   • El resumen de Yala IA pinta sus negritas en vez de enseñar los asteriscos.
//   • Las tarjetas de la hoja llevan el estilo de las del Panel y las cápsulas no llevan la flecha de desplegar.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct SaludFinancieraHojaLoteTests {

    private typealias L = SaludFinancieraDetalleLogica
    private typealias T = L10n.SaludFinancieraDetalle

    private let calendar = Calendar.current

    /// Lunes 23 de noviembre de 2026, 12:00: el día en que Jürgen lo vio en su iPhone.
    private var now: Date { date(2026, 11, 23) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func tx(_ amount: Double, _ date: Date) -> TransactionItem {
        let category = YalaCategory(name: amount < 0 ? "Comidas fuera" : "Sueldo", colorHex: "#FF0000",
                                    isIncome: amount >= 0)
        return TransactionItem(
            date: date, amount: amount, currencyCode: "PEN", note: nil, category: category, account: nil,
            tags: [], amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    private func budget(limit: Double, createdAt: Date, period: BudgetPeriodType = .monthly) -> Budget {
        let budget = Budget(currencyCode: "PEN", limitAmount: limit, name: "Comidas fuera", periodType: period.rawValue)
        budget.createdAt = createdAt
        return budget
    }

    /// Una semana con un registro por día: el ritmo da nota y, con presupuestos, ya hay dos partes.
    private var unaSemana: [TransactionItem] {
        (17...23).map { tx(-10, date(2026, 11, $0)) }
    }

    private func score(_ transactions: [TransactionItem], budgets: [Budget],
                       period: DetailPeriod = .thisMonth) -> FinancialScore {
        FinancialScoreCalculator.calculate(
            transactions: transactions, budgets: budgets, scheduledPayments: [], accounts: [],
            paidAmounts: [:], period: period, preferredCurrencyCode: "PEN", converter: MockCurrencyConverter(),
            now: now, calendar: calendar
        )
    }

    // MARK: - Un presupuesto nuevo cuenta desde ya

    @Test("Un solo presupuesto creado hoy y ya pasado baja la nota (antes, 100 y «empieza a contar el 1 dic»)")
    func presupuestoNuevoPasado_bajaLaNota() throws {
        // El caso de Jürgen: «Comidas fuera se pasó por S/ 306.88», creado a mitad de mes.
        let comidas = budget(limit: 400, createdAt: date(2026, 11, 20))
        let result = score(unaSemana + [tx(-656.88, date(2026, 11, 5))], budgets: [comidas])
        let parte = try #require(result.budget, "El presupuesto creado este mes tiene que contar ya.")
        #expect(parte < 100)
        #expect(parte == FinancialScoreCalculator.overspendScore(ratio: 726.88 / 400))
        let total = try #require(result.total)
        #expect(total < 100, "Con un solo presupuesto pasado la nota no puede salir 100.")
        #expect(result.alerts.unseen(isExpensesOnlyMode: false).isEmpty, "La nota ya lo cuenta: no va en «no ve».")
    }

    @Test("Un presupuesto creado hoy que va dentro del límite cuenta con 100")
    func presupuestoNuevoDentro_cuentaCon100() {
        let comidas = budget(limit: 400, createdAt: date(2026, 11, 20))
        #expect(score(unaSemana, budgets: [comidas]).budget == 100)
    }

    @Test("Los períodos enteros anteriores a la creación siguen sin contar")
    func periodoAnteriorALaCreacion_noCuenta() {
        // «Mes pasado» con un presupuesto creado este mes: no se gastó contra ese límite.
        let comidas = budget(limit: 100, createdAt: date(2026, 11, 20))
        let octubre = (20...26).map { tx(-50, date(2026, 10, $0)) }
        #expect(score(octubre, budgets: [comidas], period: .lastMonth).budget == nil)
    }

    @Test("El período en que se creó cuenta; el anterior, no (mensual, semanal)", arguments: [
        BudgetPeriodType.monthly, .weekly,
    ])
    func bucketIsValid_desdeElPeriodoDeCreacion(_ tipo: BudgetPeriodType) throws {
        let creado = date(2026, 11, 20)
        let b = budget(limit: 100, createdAt: creado, period: tipo)
        let componente: Calendar.Component = tipo == .monthly ? .month : .weekOfYear
        let actual = try #require(calendar.dateInterval(of: componente, for: creado))
        let anterior = try #require(calendar.dateInterval(of: componente, for: actual.start.addingTimeInterval(-1)))
        #expect(FinancialScoreCalculator.bucketIsValid(actual, for: b, calendar: calendar))
        #expect(!FinancialScoreCalculator.bucketIsValid(anterior, for: b, calendar: calendar))
    }

    @Test("Creado justo a medianoche del día 1: el mes anterior, que acaba en ese instante, no cuenta")
    func creadoALaMedianoche_elMesAnteriorNoCuenta() throws {
        let b = budget(limit: 100, createdAt: date(2026, 11, 1, hour: 0))
        let octubre = try #require(calendar.dateInterval(of: .month, for: date(2026, 10, 15)))
        #expect(!FinancialScoreCalculator.bucketIsValid(octubre, for: b, calendar: calendar))
    }

    @Test("La hoja explica por qué bajó: el consejo nombra el presupuesto pasado")
    func consejo_nombraElPresupuestoPasado() {
        let pasado = L.Presupuesto(id: UUID(), nombre: "Comidas fuera", icono: "fork.knife", color: "FF9500",
                                   gastado: 706.88, limite: 400, moneda: "PEN")
        let consejo = L.consejo(
            score: FinancialScore(total: 80, budget: 59, activity: 100, bills: nil), presupuestos: [pasado], pagos: [],
            comparacion: nil, tienePagos: true, isExpensesOnlyMode: false, finDeMes: now
        )
        #expect(consejo == .presupuestoPasado(nombre: "Comidas fuera"))
        #expect(T.consejo(consejo).contains("Comidas fuera"))
    }

    // MARK: - Negritas de Yala IA

    @Test("El resumen de Yala IA pinta las negritas y no enseña los asteriscos")
    func resumenIA_pintaNegritas() {
        let cuerpo = T.iaCuerpo(L.TarjetaIA(texto: "Este mes gastaste **S/ 11,821** en total.",
                                            consejo: "Prueba con **un tope** por semana."))
        let plano = String(cuerpo.characters)
        #expect(!plano.contains("*"), "Quedaron asteriscos: \(plano)")
        #expect(plano == "Este mes gastaste S/ 11,821 en total. Prueba con un tope por semana.")
        let negritas = cuerpo.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
            .map { String(cuerpo[$0.range].characters) }
        #expect(negritas == ["S/ 11,821", "un tope"])
    }

    @Test("Un resumen sin formato sale tal cual")
    func resumenIA_sinFormato() {
        let cuerpo = T.iaCuerpo(L.TarjetaIA(texto: "Gastaste menos.", consejo: "Sigue así."))
        #expect(String(cuerpo.characters) == "Gastaste menos. Sigue así.")
    }

    // MARK: - Estilo del Panel (cableado)

    private static func fuenteDeLaHoja(file: StaticString = #filePath) throws -> String {
        let raiz = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = raiz.appendingPathComponent("Yala/App/Views/Panel/Sheets/SaludFinanciera/SaludFinancieraDetalleView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("Las tarjetas de la hoja usan la tarjeta del Panel y las cápsulas no llevan flecha de desplegar")
    func hoja_usaElEstiloDelPanel() throws {
        let fuente = try Self.fuenteDeLaHoja()
        #expect(!fuente.contains("Color.primary.opacity(0.05)"), "Queda una tarjeta con el gris de antes.")
        #expect(fuente.contains(".solidCard(radius: DS.Panel.widgetRadius)"))
        #expect(fuente.contains(".solidCard(padding: DS.Spacing.md, radius: DS.Panel.widgetRadius)"))
        let capsula = try #require(fuente.range(of: "private func capsula("))
        let finCapsula = try #require(fuente.range(of: "// MARK: - Sección", range: capsula.upperBound..<fuente.endIndex))
        let cuerpo = fuente[capsula.upperBound..<finCapsula.lowerBound]
        #expect(!cuerpo.contains("chevron.down"), "La cápsula vuelve a parecer un desplegable.")
        #expect(cuerpo.contains(".background(.thCard, in: Capsule())"))
    }
}
