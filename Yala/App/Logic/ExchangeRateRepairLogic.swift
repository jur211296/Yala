//
//  ExchangeRateRepairLogic.swift
//  Yala
//
//  Qué transacción ya guardada quedó con un 1:1 envenenado y hay que volver a mirar.
//  Ticket `fx-partial-rate-rows-silent-1to1` (paso 2).
//

import Foundation

/// Decide si una transacción **ya persistida** tiene pinta de haberse guardado con el 1:1 silencioso.
///
/// **El barrido no reconvierte: solo REABRE la marca.** Podría recalcular él mismo el monto, pero ya
/// existe un reparador que corre en cada arranque (`TransactionUpdateService`), cuyo `#Predicate` solo
/// busca `isExchangeRateProvisional == true`. Las transacciones envenenadas están selladas en `false`
/// —ése es justamente el daño— así que basta con devolverlas a la cola: el reparador, ya probado,
/// hace el resto con la lógica buena. Menos código nuevo en un camino que toca dinero, y una sola
/// implementación de la conversión en vez de dos que se desincronizan.
enum ExchangeRateRepairLogic {

    /// `exchangeRate == 1.0` **NO basta como criterio**, y confundirlo arruinaría el barrido: es el
    /// valor legítimo cuando origen y destino son la misma divisa, que es el caso de la inmensa mayoría
    /// de transacciones de cualquier usuario. Reconvertirlas todas sería un barrido masivo e inútil
    /// —y con `exchangeRate` viajando por el canal nube en el grupo de coherencia `money`, un
    /// aluvión de emisiones por nada.
    ///
    /// El segundo falso positivo que el ticket avisa y que aquí NO se filtra a propósito: un monto
    /// prácticamente cero también deriva `effectiveRate == 1.0` por su propia rama (`abs(amount) >
    /// 0.0001`). Marcar ésas como provisionales es inofensivo —el reparador las recalcula, obtiene lo
    /// mismo y las vuelve a sellar— y filtrarlas exigiría replicar aquí ese umbral, que es justo el
    /// tipo de duplicado que se desincroniza.
    static func needsRepair(
        exchangeRate: Double,
        currencyCode: String,
        preferredCurrencyCode: String
    ) -> Bool {
        guard exchangeRate == 1.0 else { return false }
        return currencyCode.caseInsensitiveCompare(preferredCurrencyCode) != .orderedSame
    }

    /// La tasa que se deduce de los DOS montos ya guardados, o `nil` si de ahí no se deduce ninguna.
    ///
    /// **Existe porque las filas envenenadas no son todas iguales, y tratarlas igual hace daño**
    /// (medido el 2026-09-08 por la review adversarial de
    /// `chat-rows-sealed-before-the-fix-have-no-repair-path`). Hay dos poblaciones bajo el mismo
    /// criterio de `needsRepair`, y se distinguen por si el monto convertido guardado es el resultado
    /// de una conversión o el monto crudo:
    ///
    /// - **La tasa miente, el monto NO** (el corpus del chat): `saveDraft` convertía de verdad y
    ///   plantaba `exchangeRate: 1.0` al lado. El cociente devuelve la tasa que se usó, así que la fila
    ///   se arregla **en el sitio**, escribiendo solo esa columna. Reabrirla para que el reparador la
    ///   reconvirtiera sería estrictamente peor: `recalculatePreferredCurrency` pisa
    ///   `amountInPreferredCurrency` con lo que dé la conversión de HOY, y si la tasa de aquella fecha
    ///   ya no está en disco baja los escalones —tasa arrastrada, y al final la tabla estática, que es
    ///   un snapshot congelado— y **cambia un número que estaba bien**.
    /// - **Mienten los dos** (el corpus de `fx-partial-rate-rows-silent-1to1`): la conversión falló y
    ///   se guardó el monto crudo, así que el cociente vale 1 y no dice nada. Ahí sí hace falta volver
    ///   a convertir, y eso es lo que hace el reparador de arranque cuando la fila vuelve a la cola.
    ///   Devolver `nil` es lo que las manda por ese camino.
    ///
    /// Una paridad REAL de 1:1 entre dos divisas distintas cae en el segundo grupo y se reabre: el
    /// reparador la recalcula, obtiene lo mismo y la vuelve a sellar. Inofensivo — la conversión es la
    /// identidad, así que no hay monto que empeorar.
    ///
    /// El umbral del monto es el de `TransactionItem.recalculatePreferredCurrency`, y la paridad no es
    /// estética: es lo que hace que la tasa escrita aquí sea **reproducible por el proceso que existe
    /// para repararla**. Si divergieran, la fila cambiaría de número al pasar por él.
    ///
    /// **La tasa deducida se pasa por `isUsableRate` antes de devolverla**, y no es defensa de más:
    /// una fila con el monto convertido en `0` da cociente `0`, y escribir eso reproduciría DENTRO de
    /// este arreglo la forma exacta del bug que las rules de divisas describen —una tasa inservible
    /// que pasa por dato y en el destino devuelve `0`, que parece un número real—. Una fila así no
    /// tiene tasa deducible: se reabre, que es el camino que sabe reconvertirla.
    static func rateFromStoredAmounts(
        amount: Double,
        amountInPreferredCurrency: Double
    ) -> Double? {
        guard abs(amount) > 0.0001 else { return nil }
        let rate = abs(amountInPreferredCurrency / amount)
        guard CurrencyConverter.isUsableRate(rate) else { return nil }
        // Un cociente indistinguible de 1 significa que el monto convertido ES el monto crudo: la
        // conversión no llegó a ocurrir y de esta fila no se puede deducir ninguna tasa.
        guard abs(rate - 1.0) > 0.0001 else { return nil }
        return rate
    }
}
