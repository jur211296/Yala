//
//  ExchangeRateCoverageLogic.swift
//  Yala
//
//  ¿La fila de tasas de un día trae las divisas que hacen falta?
//  Ticket `repair-queue-has-no-exit-for-partial-rate-rows`.
//

import Foundation

/// La pregunta que decide si una fecha necesita refetch de tasas.
///
/// **Existe porque en este repo esa pregunta se hacía de tres formas distintas y solo una era
/// correcta.** `rateExists` preguntaba si la FILA existía; `rateHasAllCurrencies` preguntaba por las
/// 48 divisas sin mirar si servían; y `CurrencyConverter.resolveRates` —el único que decide de verdad
/// si una conversión sale `.exact`— pregunta por las dos divisas concretas de la conversión Y descarta
/// las tasas inservibles (`isUsableRate`). Mientras la primera pregunta gobernaba el refetch y la
/// tercera gobernaba la calidad, el reparador de arranque no tenía salida: `ensureRates` respondía
/// «no falta nada» sobre una fila a la que sí le faltaba la divisa, la conversión volvía a degradar y
/// la transacción se re-marcaba provisional. Para siempre.
///
/// Aquí la pregunta es UNA y la comparten los tres sitios, así que la decisión de refetch y la
/// decisión de calidad no pueden volver a divergir.
enum ExchangeRateCoverageLogic {

    /// ¿`available` trae, con una tasa **servible**, todas las divisas de `needed`?
    ///
    /// **El filtro de servible no es decorativo y es la mitad que se olvida.** Una tasa `0` guardada
    /// tiene su clave presente: una cobertura que preguntara solo por la clave respondería «cubierta»
    /// mientras `resolveRates` la trata como ausente y degrada. Esa asimetría es exactamente la forma
    /// del bug original —una pregunta más laxa que la que de verdad decide— y reproducirla en el
    /// arreglo dejaría el bucle vivo para el subconjunto de filas con ceros.
    ///
    /// `needed` vacío = «que la fila traiga algo servible». Es la semántica que necesita quien no sabe
    /// qué divisas le van a pedir después, y espeja el `needing: []` de `resolveRates`.
    static func covers(_ available: [String: Double], needing needed: Set<String>) -> Bool {
        let usable = usableCurrencies(in: available)
        guard !needed.isEmpty else { return !usable.isEmpty }
        return needed.isSubset(of: usable)
    }

    /// Las divisas de la fila cuya tasa se puede usar de verdad.
    ///
    /// Una sola definición de «servible», tomada de `CurrencyConverter`, para que la cobertura no
    /// pueda desincronizarse de la conversión. Si esa definición cambia, cambia en un sitio.
    static func usableCurrencies(in available: [String: Double]) -> Set<String> {
        Set(available.filter { CurrencyConverter.isUsableRate($0.value) }.keys)
    }

    /// De un rango ya resuelto (`dateKey → divisas servibles`), qué claves de `dateKeys` **no** están
    /// cubiertas y hay que volver a pedir.
    ///
    /// Separado del fetch a propósito: el recorrido día a día es donde se colaba el coste de arranque
    /// —un `context.fetch` por día del rango, ~1.100 en tres años de histórico— y aquí no hay ningún
    /// acceso a disco que pueda volver a colarse dentro del bucle.
    static func uncoveredDateKeys(
        among dateKeys: [String],
        coverage: [String: Set<String>],
        needing needed: Set<String>
    ) -> [String] {
        dateKeys.filter { key in
            guard let usable = coverage[key] else { return true }  // sin fila: falta entera
            guard !needed.isEmpty else { return usable.isEmpty }
            return !needed.isSubset(of: usable)
        }
    }
}
