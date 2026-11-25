//
//  SyncOutboxBacklogLogic.swift
//  Yala
//
//  Lo que decide el motor de la nube con una cola de subida GRANDE (bugs de cuenta nube, 2026-11-25). Medido en el
//  iPhone 14: «Recargar datos de prueba» y «Vaciar datos» en una cuenta de Yala dejaron 7.166 cambios en la cola, 3.148
//  de ellos filas con su alta y su baja pendientes a la vez. El motor subía toda la cola antes de bajar nada (media hora)
//  y el Panel esperaba esa primera bajada con su esqueleto, que vencía su techo de 60 s en cada arranque.
//

import Foundation

enum SyncOutboxBacklogLogic {

    /// Una fila de la cola, lo que hace falta para compactarla.
    struct Entry: Equatable {
        let key: AnyHashable
        let syncID: UUID
        let hlc: String
        let isTombstone: Bool
    }

    /// **Las altas que ya no hace falta subir: las de una fila cuya última operación pendiente es una baja.**
    ///
    /// La baja gana por LWW a todo lo anterior de esa fila, en el servidor y en cualquier otro teléfono, así que el alta
    /// que la precede no aporta nada. La baja se queda SIEMPRE, también si el servidor nunca vio la fila: no se sabe desde
    /// aquí si un alta llegó al servidor y perdió la respuesta, y en ese caso solo la baja la borra (el servidor guarda
    /// como borrada una identidad que no conoce, medido el 2026-09-25). Un alta POSTERIOR a la última baja se queda: puede
    /// ser una baja deshecha, y sube con la fila entera. Las altas de antes de esa baja sí salen.
    ///
    /// El orden es el del HLC, el mismo de la subida (`HLC.uploadOrder`): con dos operaciones del mismo instante, la baja
    /// cuenta como la última.
    static func supersededUpserts(_ entries: [Entry]) -> [AnyHashable] {
        let latestTombstone: [UUID: String] = entries.reduce(into: [:]) { acc, entry in
            guard entry.isTombstone else { return }
            if let current = acc[entry.syncID], current >= entry.hlc { return }
            acc[entry.syncID] = entry.hlc
        }
        guard !latestTombstone.isEmpty else { return [] }
        return entries.compactMap { entry in
            guard !entry.isTombstone, let tombstoneHLC = latestTombstone[entry.syncID],
                  entry.hlc <= tombstoneHLC else { return nil }
            return entry.key
        }
    }

    /// Trozos que se suben antes de la PRIMERA bajada del proceso. Con la cola grande, el ciclo sube dos trozos (100
    /// cambios, ~30 s de Worker en el peor caso) y baja: el Panel deja de esperar en cuanto la cuenta llega, y el resto de
    /// la cola sube en el ciclo siguiente, sin tope. Tras la primera bajada no hay tope: es la subida de siempre.
    static let chunksBeforeFirstPull = 2

    /// ¿Se sube el trozo `chunkIndex` (desde 0) en este ciclo?
    static func uploadsChunk(_ chunkIndex: Int, firstPullCompleted: Bool) -> Bool {
        firstPullCompleted || chunkIndex < chunksBeforeFirstPull
    }
}
