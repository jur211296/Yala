import Foundation

/// En qué moneda se filtra por monto en Registros › Filtros.
///
/// El monto compara el importe de cada registro en su propia moneda, así que solo tiene sentido si lo que queda a la
/// vista es de UNA moneda. En «Mostrar solo» es la marcada (o la única que tienen los registros); en «Ocultar» es la
/// única que queda sin ocultar. Hasta el 2026-10-25 «Ocultar» con una moneda marcada filtraba en esa misma moneda, la
/// que se estaba ocultando (ticket `hidden-single-currency-still-filters-the-amount-in-it`).
enum RecordsAmountFilterCurrencyLogic {
    /// - Parameters:
    ///   - selected: monedas marcadas en la sección Moneda.
    ///   - available: monedas que tienen registros, en el orden de los chips.
    ///   - isExcludeMode: `true` en «Ocultar».
    /// - Returns: la moneda del monto, o `nil` si lo que queda a la vista mezcla monedas (o no queda ninguna).
    static func currency(
        selected: Set<CurrencyCode>,
        available: [CurrencyCode],
        isExcludeMode: Bool
    ) -> CurrencyCode? {
        let visible: [CurrencyCode]
        if isExcludeMode {
            visible = available.filter { !selected.contains($0) }
        } else if selected.isEmpty {
            visible = available
        } else {
            // Una marcada sin registros todavía cuenta: es la que pidió la persona.
            return selected.count == 1 ? selected.first : nil
        }
        return visible.count == 1 ? visible.first : nil
    }
}
