import Foundation

/// En qué moneda se filtra por monto en Registros › Filtros.
///
/// El monto compara el importe de cada registro en su propia moneda, así que solo tiene sentido si lo que queda a la
/// vista es de UNA moneda. Con monedas en «Mostrar solo» es la marcada (si no está también oculta); sin ellas, la única
/// que queda sin ocultar de las que tienen registros. Hasta el 2026-10-25 «Ocultar» con una moneda marcada filtraba en
/// esa misma moneda, la que se estaba ocultando (ticket `hidden-single-currency-still-filters-the-amount-in-it`). Desde
/// ese día las dos listas conviven (opción B) y la regla mira las dos.
enum RecordsAmountFilterCurrencyLogic {
    /// - Parameters:
    ///   - included: monedas de «Mostrar solo».
    ///   - excluded: monedas de «Ocultar».
    ///   - available: monedas que tienen registros, en el orden de los chips.
    /// - Returns: la moneda del monto, o `nil` si lo que queda a la vista mezcla monedas (o no queda ninguna).
    static func currency(
        included: Set<CurrencyCode>,
        excluded: Set<CurrencyCode>,
        available: [CurrencyCode]
    ) -> CurrencyCode? {
        if !included.isEmpty {
            // Una marcada sin registros todavía cuenta: es la que pidió la persona.
            let shown = included.subtracting(excluded)
            return shown.count == 1 ? shown.first : nil
        }
        let visible = available.filter { !excluded.contains($0) }
        return visible.count == 1 ? visible.first : nil
    }
}
