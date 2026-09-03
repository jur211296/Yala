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
}
