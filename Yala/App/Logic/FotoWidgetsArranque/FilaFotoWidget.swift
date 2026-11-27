//
//  FilaFotoWidget.swift
//  Yala
//
//  Lote 7 de eficiencia (27-nov-2026). Lo que la foto de los widgets lee de un movimiento, leído UNA vez por foto.
//
//  Con 16.004 movimientos en el iPhone 14 la foto ocupaba 5,7 s de hilo principal en cada arranque en frío, 3,2 s de
//  ellos en los ocho resúmenes de período (Sentry YALA-IOS-16: `buildPeriodSummary` → `amountInPreferredCurrency`). No
//  porque una lectura sea cara, sino porque se repetía: cada período volvía a leer de SwiftData la fecha de los 16 mil,
//  su cuenta, su categoría y su importe convertido, cuatro o cinco veces (el filtro del período, los totales, el saldo,
//  las categorías, las subcategorías y el flujo por día). La fila lo lee una vez; los ocho períodos suman sobre filas.
//
//  **Es la misma regla, no una copia.** `WidgetDataCache.buildPeriodSummary(transactions:…)` y sus piezas leen filas
//  (`LectorFilasFotoWidget.leer`) y llaman al mismo cuerpo que la foto, así que la cifra sale de un solo sitio. Cada
//  campo dice de qué función compartida sale: si esa función cambia, la fila cambia con ella.
//

import Foundation
import SwiftData

struct FilaFotoWidget {
    /// `tx.date`.
    let fecha: Date
    /// `tx.balanceAdjustmentType != nil`: un ajuste de saldo no es ingreso ni gasto.
    let esAjusteDeSaldo: Bool
    /// `adjustment.isSuppressed(tx)`: la pata de préstamo derivada de un gasto de grupo.
    let suprimida: Bool
    /// `TransactionClassificationLogic.isIncome(tx)`, la regla de toda la app.
    let esIngreso: Bool
    /// `CashFlowCalculator.resolvedAmount(tx, …)`. Solo se resuelve si la fila cuenta como ingreso o gasto (ni ajuste de
    /// saldo ni suprimida), que es cuando lo leía cada recorrido; si no, `(0, 0)` y nadie lo lee.
    let resuelto: (value: Double, approximateMagnitude: Double)
    /// `tx.account` y su identidad.
    let cuenta: Account?
    let cuentaID: PersistentIdentifier?
    /// `LiveBalanceCalculator.entersBalance(tx)`.
    let entraEnSaldo: Bool
    /// Lo que `LiveBalanceCalculator.addNative(tx, to:)` suma: `tx.currencyCode` y `Decimal(tx.amount)`.
    let monedaNativa: String
    let montoNativo: Decimal
    /// `tx.category` y `tx.subcategory`, con su nombre (leído una vez por objeto, no por fila).
    let categoria: Category?
    let categoriaNombre: String?
    let subcategoria: Subcategory?
    let subcategoriaNombre: String?

    /// Lo que `LiveBalanceCalculator.addNative` haría con esta fila.
    func sumarNativo(a saldos: inout [String: Decimal]) {
        saldos[monedaNativa, default: 0] += montoNativo
    }
}

/// Lee filas, con los nombres de categoría y subcategoría leídos una vez por objeto.
@MainActor
final class LectorFilasFotoWidget {
    let currencyCode: String
    let adjustment: GroupBridgeStatsAdjustment
    let converter: CurrencyConverting
    /// `false` para las filas que solo entran en un saldo: no hace falta su importe convertido.
    let resuelveImportes: Bool

    private var nombresCategoria: [ObjectIdentifier: String] = [:]
    private var nombresSubcategoria: [ObjectIdentifier: String] = [:]

    init(currencyCode: String, adjustment: GroupBridgeStatsAdjustment, converter: CurrencyConverting,
         resuelveImportes: Bool = true) {
        self.currencyCode = currencyCode
        self.adjustment = adjustment
        self.converter = converter
        self.resuelveImportes = resuelveImportes
    }

    func leer(_ tx: TransactionItem) -> FilaFotoWidget {
        let esAjusteDeSaldo = tx.balanceAdjustmentType != nil
        let suprimida = adjustment.isSuppressed(tx)
        let resuelto: (value: Double, approximateMagnitude: Double)
        if resuelveImportes, !esAjusteDeSaldo, !suprimida {
            resuelto = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
        } else {
            resuelto = (0, 0)
        }
        let cuenta = tx.account
        let categoria = tx.category
        let subcategoria = tx.subcategory
        return FilaFotoWidget(
            fecha: tx.date,
            esAjusteDeSaldo: esAjusteDeSaldo,
            suprimida: suprimida,
            esIngreso: TransactionClassificationLogic.isIncome(tx),
            resuelto: resuelto,
            cuenta: cuenta,
            cuentaID: cuenta?.persistentModelID,
            entraEnSaldo: LiveBalanceCalculator.entersBalance(tx),
            monedaNativa: tx.currencyCode,
            montoNativo: Decimal(tx.amount),
            categoria: categoria,
            categoriaNombre: categoria.map(nombre),
            subcategoria: subcategoria,
            subcategoriaNombre: subcategoria.map(nombre)
        )
    }

    /// Todas, de una vez. Lo usan las funciones de siempre (`buildPeriodSummary(transactions:…)`), los tests y el
    /// camino de emergencia; la foto las lee por tramos (`WidgetDataCache.buildSnapshot(etapasDe:now:)`).
    func leer(_ transactions: [TransactionItem]) -> [FilaFotoWidget] {
        transactions.map { leer($0) }
    }

    private func nombre(_ categoria: Category) -> String {
        let clave = ObjectIdentifier(categoria)
        if let nombre = nombresCategoria[clave] { return nombre }
        let nombre = categoria.name
        nombresCategoria[clave] = nombre
        return nombre
    }

    private func nombre(_ subcategoria: Subcategory) -> String {
        let clave = ObjectIdentifier(subcategoria)
        if let nombre = nombresSubcategoria[clave] { return nombre }
        let nombre = subcategoria.name
        nombresSubcategoria[clave] = nombre
        return nombre
    }
}

/// Un recorrido largo hecho por tramos con reloj: cada llamada a `avanzar` procesa elementos hasta que el tramo pasa de
/// `limite` y dice si terminó. Es la pieza de las etapas reanudables de la foto (`WidgetDataCache.EtapaFoto`): la foto de
/// una vez lo llama hasta el final; la foto por etapas cede el hilo principal entre una llamada y otra. El resultado es el
/// mismo, elemento a elemento y en el mismo orden, se haga en un tramo o en cien.
@MainActor
final class RecorridoConReloj {
    /// Lo que puede durar un tramo. Por debajo de los 25 ms de `CesionDelHilo`, con margen para el elemento que cae justo
    /// al final.
    nonisolated static let limitePorDefecto: Duration = .milliseconds(20)

    private(set) var cursor = 0
    let total: Int
    private let limite: Duration
    private let cadaCuantos: Int
    private let reloj = ContinuousClock()

    init(total: Int, limite: Duration = RecorridoConReloj.limitePorDefecto, cadaCuantos: Int = 32) {
        self.total = total
        self.limite = limite
        self.cadaCuantos = max(cadaCuantos, 1)
    }

    var terminado: Bool { cursor >= total }

    /// Procesa desde donde se quedó. `true` si llegó al final.
    func avanzar(_ cuerpo: (Int) -> Void) -> Bool {
        let inicio = reloj.now
        while cursor < total {
            cuerpo(cursor)
            cursor += 1
            if cursor % cadaCuantos == 0, reloj.now - inicio >= limite { break }
        }
        return terminado
    }
}
