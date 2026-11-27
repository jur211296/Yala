//
//  EmpujonFinDeArranque.swift
//  Yala
//
//  Lote 7 de eficiencia (27-nov-2026). La subida de `dataVersion` del final del arranque (`AppBootstrapper`, paso 19) es un
//  empujón, no un cambio de datos: existe para que una vista de Grupos montada antes de que sus servicios tuvieran
//  contexto vuelva a cargar. El Panel la oía como cualquier otra y recargaba y recalculaba entero: como su primera carga
//  ya estaba en marcha (lee por tramos y calcula por etapas), el arranque en frío hacía DOS cálculos completos seguidos,
//  ~16 s con 16.004 movimientos en el iPhone 14 (`docs/qa/rendimiento-iphone14-2026-11-26/`, lotes 1 y 4).
//
//  `dataVersion` no se puede ignorar en general: también avisa de cosas que no pasan por un guardado (un borrado con
//  «Deshacer» esconde la fila sin guardar nada). Por eso el Panel solo deja pasar ESTE empujón, y solo si desde que
//  empezó su carga no cambió nada más: ni otra subida de `dataVersion`, ni un guardado (`StoreSaveCounter`), ni un
//  cambio de la nube (`StoreRemoteChangeCounter`), ni cambios sin guardar, ni el día (`PanelReloadFreshness`). Si algo
//  de eso cambió —lo que el segundo cálculo corregía—, recarga como siempre.
//

import Foundation

@MainActor
enum EmpujonFinDeArranque {

    /// El `dataVersion` que dejó el último empujón del final del arranque.
    private(set) static var dataVersionTrasEmpujon: Int?

    /// Sube `dataVersion` como empujón del final del arranque y lo apunta.
    static func subir(_ sessionState: SessionState) {
        sessionState.incrementDataVersion()
        dataVersionTrasEmpujon = sessionState.dataVersion
    }

    /// Lo que tenía el mundo cuando una carga del Panel tomó su firma, y lo que tiene ahora.
    struct Firma: Equatable {
        let dataVersion: Int
        let guardados: Int
        let cambiosRemotos: Int
        let dia: Date
    }

    /// `true` si el cambio de `dataVersion` que llega es SOLO el empujón del final del arranque respecto de la carga
    /// `desde`: el empujón es la única subida desde entonces y nada más cambió.
    static func esSoloElEmpujon(
        desde carga: Firma?,
        ahora: Firma,
        dataVersionTrasEmpujon: Int?,
        hayCambiosSinGuardar: Bool
    ) -> Bool {
        guard let carga, let empujon = dataVersionTrasEmpujon, !hayCambiosSinGuardar else { return false }
        return ahora.dataVersion == empujon
            && carga.dataVersion == empujon - 1
            && carga.guardados == ahora.guardados
            && carga.cambiosRemotos == ahora.cambiosRemotos
            && carga.dia == ahora.dia
    }

    /// Lo que usa el Panel: con el empujón apuntado en este proceso.
    static func esSoloElEmpujon(desde carga: Firma?, ahora: Firma, hayCambiosSinGuardar: Bool) -> Bool {
        esSoloElEmpujon(desde: carga, ahora: ahora, dataVersionTrasEmpujon: dataVersionTrasEmpujon,
                        hayCambiosSinGuardar: hayCambiosSinGuardar)
    }

    #if DEBUG
    /// Solo los tests.
    static func debugOlvidar() { dataVersionTrasEmpujon = nil }
    #endif
}
