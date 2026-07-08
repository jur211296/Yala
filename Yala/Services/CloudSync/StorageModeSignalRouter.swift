//
//  StorageModeSignalRouter.swift
//  Yala
//
//  Enrutado PURO de la fuente de quiescencia según el `StorageMode` (Modo Nube, incremento I9, §i.2).
//  Es el punto único que decide, para un modo dado, QUIÉN es la autoridad de "¿el store personal está
//  quieto?": en `.icloud` el import de CloudKit (`iCloudSyncService`), en `.cloud` el propio motor
//  (`SyncQuiescenceCoordinator`). Aislar esta decisión en una función pura permite testear el enrutado
//  sin montar el motor y deja un ÚNICO sitio que revisar cuando la coexistencia (I10/I11) añada la fase
//  de reversa.
//
//  `nonisolated`: lógica pura sin estado ni I/O; se consulta desde el main actor (coordinator) y desde
//  el wiring de arranque.
//

import Foundation

/// Autoridad de quiescencia del store personal para un `StorageMode`.
nonisolated enum QuiescenceSource: Equatable {
    /// El import de NSPersistentCloudKitContainer (`iCloudSyncService.isImportQuiescent`).
    case icloudImport
    /// El apply del propio motor Modo Nube (`SyncQuiescenceCoordinator`).
    case cloudEngine
}

/// Enruta el modo a su fuente de quiescencia.
nonisolated enum StorageModeSignalRouter {

    /// Fuente de verdad de la quiescencia del store personal según el modo.
    ///
    /// COMENTARIO-GUARDIA (I11): la fase de REVERSA de la migración (cuando el store `.cloud` se
    /// re-monta sobre CloudKit y la autoridad vuelve a ser `icloudImport` AUNQUE `mode == .cloud`
    /// durante la ventana de remontaje) se modela añadiendo un parámetro `phase` a esta función en
    /// I11 — nadie debe asumir que el `mode` por sí solo basta para enrutar en esa transición.
    static func quiescenceSource(mode: StorageMode) -> QuiescenceSource {
        switch mode {
        case .icloud:
            return .icloudImport
        case .cloud:
            return .cloudEngine
        }
    }
}
