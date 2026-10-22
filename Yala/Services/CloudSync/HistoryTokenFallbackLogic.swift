//
//  HistoryTokenFallbackLogic.swift
//  Yala
//
//  DIFERIDOS #33 (D-fullrescan-token-indecodificable): decisión PURA de la rama de fetch de History
//  del drain cuando el token del cursor está roto (in-decodificable o cuyo fetch por token lanza —
//  la clase "expired" de I3). Antes del fix, AMBOS casos degradaban a re-escaneo COMPLETO de la
//  History; con purga activa (`historyPurgeEnabled`) eso re-emitiría el corpus entero que siga vivo
//  en History con HLC fresco (el reloj persistido ya avanzó → el dedup por (syncID,hlc,op) NO lo
//  absorbe) → carga masiva al backend y, en multi-device, pisado LWW de writes ajenos más nuevos.
//
//  El fix re-ancla por `SyncCursor.lastDrainedTxAt` — la MISMA ancla comparable cross-mount del
//  guard del Hallazgo 2 (`recoverIfHistoryTokenIncomparable`, corrida device 2026-07-11): acota el
//  re-escaneo a la ventana `> ancla − slack` (todo lo anterior ya fue drenado, invariante del ancla)
//  en vez de re-emitir el corpus. La ejecución (fetches, breadcrumbs, reanchor) vive en
//  `CloudSyncEngine.fetchHistoryResolvingToken`; aquí SOLO la tabla de decisión, testeable por tabla
//  (`HistoryTokenFallbackLogicTests`).
//

import Foundation

nonisolated enum HistoryTokenFallbackLogic {

    /// Estado del token persistido del cursor tras el intento de decode.
    enum TokenState: Equatable {
        /// `historyTokenData == nil` — cursor recién creado (bootstrap) o jamás avanzado.
        case absent
        /// Token decodificado con éxito (el fetch por token puede aún lanzar → el motor re-decide
        /// con `.broken`).
        case valid
        /// Token in-decodificable (o su fetch por token lanzó): la clase del hazard #33.
        case broken
    }

    /// Rama de fetch que el drain debe ejecutar esta vuelta.
    enum Branch: Equatable {
        /// Token válido → fetch por token (camino normal).
        case tokenFetch
        /// Token ausente → escaneo completo LEGÍTIMO de bootstrap (sin breadcrumb — es el primer
        /// drain de la instalación o un cursor que nunca avanzó; no hay nada drenado que re-emitir).
        case fullRescanBootstrap
        /// Token roto + ancla presente → re-escaneo ACOTADO por timestamp (`> cutoff`). La frontera
        /// del slack se re-emite con HLC fresco (LWW la colapsa — coste acotado, mismo residual T3
        /// del guard); el corpus por debajo del cutoff NO se re-emite.
        case boundedRescan(cutoff: Date)
        /// Token roto SIN ancla (cursor pre-schema) → full-rescan CONSERVADO (semántica (a) del
        /// cierre de #33): sin ancla no hay forma de acotar sin arriesgar pérdida de writes.
        case fullRescanNoAnchor
    }

    /// Tabla de decisión. `slack` = `CloudSyncEngine.historyTokenSlack` (60s): ensancha la ventana
    /// del fetch acotado para no perder txs de la ventana del último drain (misma semántica que el
    /// guard del Hallazgo 2 — el cutoff NUNCA usa `Date()`, solo el ancla persistida).
    static func decide(
        tokenState: TokenState, lastDrainedTxAt: Date?, slack: TimeInterval
    ) -> Branch {
        switch tokenState {
        case .absent:
            return .fullRescanBootstrap
        case .valid:
            return .tokenFetch
        case .broken:
            guard let anchor = lastDrainedTxAt else { return .fullRescanNoAnchor }
            return .boundedRescan(cutoff: anchor.addingTimeInterval(-slack))
        }
    }
}
