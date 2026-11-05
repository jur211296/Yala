//
//  PanelReloadFreshness.swift
//  Yala
//
//  ¿Hace falta recargar el Panel al volver a él? (card `tablero-volver-al-panel-lo-recarga-y-recalcula-e-zpgm`)
//
//  Las seis páginas de pestaña siguen montadas, así que mientras el Panel está oculto sus observadores (`dataVersion`,
//  filtros, tasas, preferencias) ya recalculan. El `onAppear` volvía a traer TODOS los movimientos y a calcular todos los
//  widgets en cada vuelta: ~0,7 s de hilo principal con 2.337 movimientos (medido el 2026-10-30).
//
//  Quitarlo solo es seguro si nada cambió por un camino que el Panel no oye. La firma lo mide sin depender de que cada
//  escritor avise: además de `dataVersion`, cuenta CUALQUIER guardado de SwiftData en el proceso (`StoreSaveCounter`,
//  de cualquier contexto y de los dos almacenes), y el día (el «hoy» de los períodos y del saldo). Lo que esté en el
//  contexto sin guardar todavía se mira aparte (`hasUnsavedChanges`). Un recálculo que se canceló a medias (salir del
//  Panel en sus 150 ms de espera) también obliga.
//

import Foundation

/// Lo que tenía el mundo cuando el Panel cargó por última vez.
struct PanelDataStamp: Equatable {
    let dataVersion: Int
    let storeSaves: Int
    let day: Date
}

enum PanelReloadFreshness {

    /// `true` si al volver al Panel hay que recargar y recalcular.
    static func needsReload(
        lastLoad: PanelDataStamp?,
        now: PanelDataStamp,
        hasUnsavedChanges: Bool,
        hasInterruptedWork: Bool
    ) -> Bool {
        guard let lastLoad else { return true }
        return hasInterruptedWork || hasUnsavedChanges || lastLoad != now
    }

    static func stamp(dataVersion: Int, storeSaves: Int, now: Date, calendar: Calendar) -> PanelDataStamp {
        PanelDataStamp(dataVersion: dataVersion, storeSaves: storeSaves, day: calendar.startOfDay(for: now))
    }
}
