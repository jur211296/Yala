//
//  SpotlightAlVolver.swift
//  Yala
//
//  ¿Hace falta reconciliar el índice de Spotlight al volver a primer plano? Lote 1 de eficiencia, 26-nov-2026.
//
//  La reconciliación lee TODOS los movimientos con sus relaciones (`SpotlightIndexService.desiredEntries`): ~1,8 s de
//  hilo principal con 16.004 movimientos en el iPhone 14, en cada vuelta, y uno de los dos cierres del vigilante de iOS
//  (`0x8BADF00D`) cayó dentro. La vuelta solo reconcilia si algo pudo cambiar el índice desde la última reconciliación:
//  un guardado de SwiftData (`StoreSaveCounter`), `dataVersion` (lo que baja CloudKit se aplica así al volver, antes de
//  esta pregunta) o lo que decide qué entra (`SpotlightIndexLogic.Context`). Lo que la app cambia con ella delante ya
//  reconcilia por `WidgetDataCache.updateCache`.
//
//  La firma se apunta en la propia reconciliación (venga de donde venga) y se borra si falla, así que tras un fallo la
//  vuelta siguiente vuelve a reconciliar.
//

import Foundation

struct SpotlightFirma: Equatable {
    let dataVersion: Int
    let storeSaves: Int
    let isGroupsFocusedShell: Bool
    let isExpensesOnlyMode: Bool
    let includeGroupTransactions: Bool
}

@MainActor
enum SpotlightAlVolver {

    /// Lo que leyó la última reconciliación. `nil`: ninguna en este proceso, o la última falló.
    private(set) static var ultima: SpotlightFirma?

    nonisolated static func debeReconciliar(ultima: SpotlightFirma?, ahora: SpotlightFirma) -> Bool {
        ultima != ahora
    }

    static func debeReconciliar(ahora: SpotlightFirma) -> Bool {
        debeReconciliar(ultima: ultima, ahora: ahora)
    }

    /// Una reconciliación empieza a leer con este mundo.
    static func anotarReconciliacion(_ firma: SpotlightFirma) {
        ultima = firma
    }

    /// La reconciliación no llegó a escribir el índice (lectura fallida, error de Core Spotlight) o el índice se vació.
    static func olvidar() {
        ultima = nil
    }

    #if DEBUG
    static func _testReset() { ultima = nil }
    #endif
}
