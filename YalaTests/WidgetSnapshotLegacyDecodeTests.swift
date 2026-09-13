//
//  WidgetSnapshotLegacyDecodeTests.swift
//  YalaTests
//
//  **La red que impide apagar TODOS los widgets con un campo nuevo.**
//
//  `WidgetDataSnapshot` viaja de la app al widget por el App Group como una struct Codable ENTERA y sin
//  versionado. Una clave nueva que NO sea opcional y falte en el payload ya escrito lanza `keyNotFound`,
//  `loadSnapshot()` devuelve `nil` y los widgets de la pantalla de inicio se quedan en cero hasta que la
//  persona abra la app — en un widget eso pueden ser horas. Y si la clave cuelga de `thisMonthSummary`,
//  que tampoco es opcional, revienta el snapshot entero y no solo su campo.
//
//  **Estos dos casos vivían en `WidgetSessionSealTests` hasta el 2026-09-13**, escritos para otra cosa
//  (el sello de identidad de sesión, retirado con la sesión de visita). Se mudan aquí en vez de irse con
//  aquel fichero porque lo que miden no tiene nada que ver con el sello: miden que el DTO siga siendo
//  retrocompatible. La lección de método es del propio traslado — **al borrar una suite, mira si alguno
//  de sus casos estaba sosteniendo un invariante ajeno**; éste lo estaba, y se descubre leyéndolos, no
//  leyendo el nombre del fichero.
//
//  Aviso de alcance, medido: esto resuelve a la copia de la APP (`Yala/Services/WidgetDataCache.swift`),
//  porque el target `YalaTests` compila `Yala` y no `YalaWidgets`. A la copia del LECTOR —la que de
//  verdad sirve al widget en producción— la vigila un source-scan
//  (`ApproximateMarkSecondarySurfacesWiringTests`), que es más débil y se elige a conciencia.
//
//  `.claude/rules/swiftdata-cloudkit.md` · «Un campo Codable NUEVO y no opcional…».
//

import Foundation
import Testing
@testable import Yala

/// `@MainActor` porque la conformidad `Decodable` de `WidgetDataSnapshot` está aislada al main actor
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION`) y decodificarla desde un contexto nonisolated avisa —error en
/// modo Swift 6—. La suite de la que se mudaron estos dos casos arrastraba ese aviso; se cierra al
/// mudarlos en vez de heredarlo.
@Suite("Widget · el snapshot legacy decodifica entero")
@MainActor
struct WidgetSnapshotLegacyDecodeTests {

    /// La forma exacta que hay hoy en los discos: sin ninguna de las claves añadidas después.
    @Test func snapshotLegacyMinimo_decodifica() throws {
        let legacy = """
        {"lastUpdated":0,"preferredCurrencyCode":"PEN","currencyDisplayFormat":"symbol",
         "accountBalances":[],"totalBalance":0,"transactions":[],"budgets":[],"scheduledPayments":[],
         "trendData":{"dailyPoints":[],"weeklyPoints":[],"monthlyPoints":[]},
         "thisMonthSummary":{"totalIncome":0,"totalExpense":0,"netCashFlow":0,"topCategories":[],
           "topSubcategories":[],"cashFlowPoints":[]},
         "allTimeSummary":{"totalIncome":0,"totalExpense":0,"netCashFlow":0,"topCategories":[],
           "topSubcategories":[],"cashFlowPoints":[]},
         "periodSummaries":{}}
        """
        let decoded = try JSONDecoder().decode(WidgetDataSnapshot.self, from: Data(legacy.utf8))

        #expect(decoded.preferredCurrencyCode == "PEN")
        #expect(decoded.thisMonthSummary.periodBalance == nil, """
            Ausente y no 0: el snapshot viejo no traía este campo, y el decode tiene que sobrevivirlo.
            """)
    }

    /// El mismo compromiso, un escalón más abajo: un snapshot legacy **con transacciones dentro** y sin
    /// las claves de la marca de aproximado.
    ///
    /// **Lo que añade de verdad es `WidgetTransaction`**: el caso de arriba ya lleva un
    /// `thisMonthSummary` sin las cuatro claves nuevas, así que ése cubre `WidgetPeriodSummary`. Lo que
    /// no cubre es una FILA, porque su `transactions` va vacío — y es justo donde el primer intento de
    /// aquel ticket habría roto.
    @Test func snapshotLegacyConTransacciones_decodificaSinLasClavesDeAproximado() throws {
        let legacy = """
        {"lastUpdated":0,"preferredCurrencyCode":"PEN","currencyDisplayFormat":"symbol",
         "accountBalances":[],"totalBalance":0,
         "transactions":[{"id":"1","date":0,"amount":-45.5,"currencyCode":"PEN","note":null,
           "categoryName":"Comida","categoryColor":"#FF0000","categoryIcon":"fork.knife",
           "subcategoryIcon":null,"subcategoryName":null,"isIncome":false,
           "amountInPreferredCurrency":-45.5}],
         "budgets":[],"scheduledPayments":[],
         "trendData":{"dailyPoints":[],"weeklyPoints":[],"monthlyPoints":[]},
         "thisMonthSummary":{"totalIncome":0,"totalExpense":45.5,"netCashFlow":-45.5,
           "topCategories":[],"topSubcategories":[],"cashFlowPoints":[]},
         "allTimeSummary":{"totalIncome":0,"totalExpense":45.5,"netCashFlow":-45.5,
           "topCategories":[],"topSubcategories":[],"cashFlowPoints":[]},
         "periodSummaries":{}}
        """
        let decoded = try JSONDecoder().decode(WidgetDataSnapshot.self, from: Data(legacy.utf8))

        #expect(decoded.transactions.count == 1)
        #expect(decoded.transactions.first?.isExchangeRateProvisional == nil, """
            Ausente y no `false`: el snapshot viejo no sabía nada de la calidad de aquella tasa, y
            fingir que la sabía es lo que este campo NO debe hacer.
            """)
        #expect(decoded.thisMonthSummary.expenseIsApproximate == nil)
        #expect(decoded.thisMonthSummary.periodBalanceIsApproximate == nil)
        #expect(decoded.thisMonthSummary.totalExpense == 45.5, """
            Y el snapshot llega ENTERO: si las claves nuevas no fueran opcionales, este `decode`
            habría lanzado y no habría ningún número que leer.
            """)
    }
}
