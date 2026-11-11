//
//  StatisticsEntryFreshness.swift
//  Yala
//
//  ¿Hace falta calcular Estadísticas al entrar o al cambiar de chip? (G1 de la decisión 28, revisión 2.3 problema 7.)
//
//  Medido el 2026-11-11 en el iPhone 14 (Release optimizado, diez años de datos, «Todo el tiempo»): la primera entrada
//  bloqueaba el hilo principal 7,5 s en el `onAppear` y, 150 ms después, el cambio de pestaña pedía OTRA pasada completa
//  de 2,4 s sobre los mismos datos; la segunda entrada, 1,9 s + otros 2,0 s; volver a Resumen o a Distribución, otra
//  pasada entera. El cálculo ya no mira qué chip se ve (`StatisticsRecalculation`), así que esas pasadas repetían lo mismo.
//
//  Las páginas de pestaña siguen montadas y sus observadores recalculan aunque Estadísticas esté oculta (filtros,
//  período, `dataVersion`, preferencias). Entrar solo tiene que calcular si algo pudo cambiar por un camino que no se oye:
//  un guardado sin `dataVersion` (`StoreSaveCounter`), el día, una entrada del cálculo que cambió sin que su observador
//  se enterara (la firma la incluye entera), o un cálculo que se quedó a medias. Molde: `PanelReloadFreshness`.
//

import Foundation
import SwiftData

/// Lo que leyó la última pasada completa de Estadísticas.
struct StatisticsCalculationStamp: Equatable {
    let dataVersion: Int
    let storeSaves: Int
    let day: Date
    /// Filtros de sesión y período (la misma clave que el Panel).
    let sessionFilters: PanelSessionFilterKey
    let comparisonMode: ComparisonMode
    let currencyCode: String
    let includeGroupTransactionsInStats: Bool
    let includeGroupTransactionsInFeed: Bool
    let insightsTone: InsightTone
    let insightsFocus: InsightFocus
    /// El primer día de la semana (`userConfiguredCalendar`): mueve «Esta semana» y el historial de Tendencias, y
    /// cambiarlo en Ajustes no avisa a Estadísticas (lo cazó la revisión del lote).
    let firstWeekday: Int
}

enum StatisticsEntryFreshness {

    /// `true` si al entrar (o al pasar a otro chip) hay que calcular.
    static func needsCalculation(
        last: StatisticsCalculationStamp?,
        now: StatisticsCalculationStamp,
        hasInterruptedWork: Bool
    ) -> Bool {
        guard let last else { return true }
        return hasInterruptedWork || last != now
    }

    /// `true` si hay que volver a traer los movimientos, no solo recalcular: algo se guardó o cambió `dataVersion` desde
    /// la última pasada (un guardado sin aviso puede traer altas y borrados que los arrays en memoria no tienen).
    static func needsReload(last: StatisticsCalculationStamp?, now: StatisticsCalculationStamp) -> Bool {
        guard let last else { return false }
        return last.dataVersion != now.dataVersion || last.storeSaves != now.storeSaves
    }
}

/// Cuánto espera la pasada de Estadísticas tras pedirse: lo justo para que la pestaña se pinte antes y para juntar en una
/// sola las peticiones que llegan seguidas (entrar dispara el `onAppear` y el cambio de pestaña a la vez).
enum StatisticsEntryTiming {
    static var calculationDelay: Duration {
        if let seconds = UITestHooks.statisticsCalculationDelaySeconds { return .milliseconds(Int(seconds * 1000)) }
        return .milliseconds(150)
    }
}
