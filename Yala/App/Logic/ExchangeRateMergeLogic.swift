//
//  ExchangeRateMergeLogic.swift
//  Yala
//
//  Cómo se combina una fila de tasas ya guardada con una escritura nueva.
//  Ticket `fx-partial-rate-rows-silent-1to1` (H3).
//

import Foundation

/// Decide qué queda en la fila de tasas de un día cuando llega una escritura nueva.
///
/// **Por qué es lógica pura y no dos líneas dentro de `persistRate`.** El defecto que arregla no se
/// veía en ninguna pantalla ni lo cazaba ningún test: era `existing.rates = data`, un reemplazo total
/// donde hacía falta una fusión. Aquí es comprobable con una tabla, y su cableado lo pinnea un
/// source-scan — las dos mitades por separado, porque una fusión correcta que nadie llama no arregla
/// nada.
enum ExchangeRateMergeLogic {

    /// Las claves entrantes ganan; las que ya estaban y no vienen en la escritura **se conservan**.
    ///
    /// El caso que lo motiva ocurre en CADA arranque: `updateTodayIfNeeded` persiste hoy con las 54
    /// divisas y, unas líneas después, `preloadHistoricalIfNeeded` vuelve a persistir hoy —su primer
    /// chunk termina en la fecha de hoy— con solo las 2-4 de `getRequiredCurrencies`. Con reemplazo,
    /// la fila del día acababa parcial siempre; y una fila parcial no es «información incompleta»,
    /// es información que TAPA la que había (ver `CurrencyConverter.resolveRates`).
    ///
    /// Que ganen las entrantes es deliberado: vienen de una respuesta de la API más reciente que lo
    /// guardado, así que sobre una divisa presente en las dos, la nueva es la buena.
    static func merged(
        existing: [String: Double],
        incoming: [String: Double]
    ) -> [String: Double] {
        existing.merging(incoming) { _, new in new }
    }

    /// El `timestamp` entrante solo pisa al guardado **si trae valor**.
    ///
    /// `persistRate` lo declara `Date? = nil` y lo asignaba incondicionalmente, así que un llamador
    /// que no lo pasara —`fetchAndPersistRates`, que es el del preload— BORRABA el timestamp que la
    /// llamada anterior había puesto con el dato real de la API. Perder la hora de una fila no cambia
    /// ninguna conversión, pero deja sin saber cuándo se midió esa tasa, que es justo lo que hace
    /// falta para decidir si merece la pena refrescarla.
    static func mergedTimestamp(existing: Date?, incoming: Date?) -> Date? {
        incoming ?? existing
    }
}
