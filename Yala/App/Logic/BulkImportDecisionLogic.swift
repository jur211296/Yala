//
//  BulkImportDecisionLogic.swift
//  Yala
//
//  Pure-logic: partición de candidatos a import bridge histórico según estrategia
//  bulk elegida por el user en `BridgeActivationSheet` (D3 incluido).
//

import Foundation

enum BulkImportDecisionLogic {

    /// Estrategias disponibles para el bulk approve del import histórico.
    enum Strategy: Equatable {
        /// Importar todos sin importar matches.
        case importAll
        /// Saltar todos los high-confidence matches; importar el resto.
        case skipAllMatches
        /// Revisar uno por uno (default — flow normal por Inbox).
        case reviewOneByOne
    }

    /// Resultado de la partición.
    struct Plan<ID: Hashable>: Equatable {
        let toImport: [ID]
        let toSkip: [ID]
    }

    /// Particiona `candidates` en (toImport, toSkip) según `strategy`.
    /// - Parameters:
    ///   - candidates: IDs de expenses a procesar.
    ///   - highConfidenceMatchIDs: IDs cuyo match es high-confidence (D4 scoring).
    ///   - strategy: estrategia elegida por el user.
    static func partition<ID: Hashable>(
        candidates: [ID],
        highConfidenceMatchIDs: Set<ID>,
        strategy: Strategy
    ) -> Plan<ID> {
        switch strategy {
        case .importAll:
            return Plan(toImport: candidates, toSkip: [])
        case .skipAllMatches:
            let toImport = candidates.filter { !highConfidenceMatchIDs.contains($0) }
            let toSkip = candidates.filter { highConfidenceMatchIDs.contains($0) }
            return Plan(toImport: toImport, toSkip: toSkip)
        case .reviewOneByOne:
            // Todos van por Inbox: el "import" aquí significa "crear draft para review".
            return Plan(toImport: candidates, toSkip: [])
        }
    }
}
