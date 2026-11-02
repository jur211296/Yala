//
//  GroupSplitLineEntryGroupLogic.swift
//  Yala
//
//  Grupos B · card oibr: la ENTRADA de una recarga de tu parte (Pía te recarga 500 a Sip) no lleva puntero de grupo a
//  propósito (D4 del diseño técnico, `tickets/in-progress/grupos-tu-parte-en-lineas.md`), así que en Registros salía sin
//  la insignia del grupo y, con «Incluir movimientos de grupos» apagado, sola: su salida en «Grupos» se ocultaba y ella no.
//
//  De qué grupo es lo dice su SALIDA: la pata de «Grupos» con el mismo `transferPairID`, que sí lleva el puntero. Sin
//  cambio de modelo ni de cifras: solo cómo se lee en Registros.
//
//  Lógica pura: sin SwiftData.
//

import Foundation

nonisolated enum GroupSplitLineEntryGroupLogic {

    /// Una pata con puntero de grupo que forma parte de un par de transferencia.
    struct BridgedPairLeg: Equatable, Sendable {
        let transferPairID: String
        let groupZoneID: String?
    }

    /// La zona del grupo de cada par de transferencia que sale de un gasto de grupo. Un par repetido (no debería) se queda
    /// con la primera zona no vacía.
    static func zoneByTransferPair(_ legs: [BridgedPairLeg]) -> [String: String] {
        var result: [String: String] = [:]
        for leg in legs {
            guard let zone = leg.groupZoneID, !zone.isEmpty, result[leg.transferPairID] == nil else { continue }
            result[leg.transferPairID] = zone
        }
        return result
    }

    /// La zona del grupo de un registro SIN puntero que es la entrada de una recarga, o `nil`. Un registro con puntero ya
    /// dice su grupo por sí mismo.
    static func entryZone(hasGroupPointer: Bool, transferPairID: String?, zoneByTransferPair: [String: String]) -> String? {
        guard !hasGroupPointer, let transferPairID else { return nil }
        return zoneByTransferPair[transferPairID]
    }

    /// Con los movimientos de grupos ocultos en Registros, la entrada se va con su salida.
    static func hiddenWithItsExit(
        hasGroupPointer: Bool, transferPairID: String?, bridgedTransferPairs: Set<String>, includeGroups: Bool
    ) -> Bool {
        guard !includeGroups, !hasGroupPointer, let transferPairID else { return false }
        return bridgedTransferPairs.contains(transferPairID)
    }
}
