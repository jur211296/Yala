//
//  ScheduledPayment+SplitCSVMirror.swift
//  Yala
//
//  Helpers para la plantilla de división de un pago planificado de grupo.
//  La config viaja en campos planos del propio record (patrón espejo de
//  `ScheduledPayment+TagsCSVMirror.swift`), no en @Relationship — los SplitMember
//  viven en otra zona CloudKit. Codificación en `SplitConfigCodec` (pure-logic).
//

import Foundation
import SwiftData

extension ScheduledPayment {

    // MARK: - Read

    /// UUIDs de los miembros participantes en la división.
    func resolvedParticipantIDs() -> [UUID] {
        SplitConfigCodec.decodeParticipants(splitParticipantIDsRaw)
    }

    /// Valor por participante (%/monto/partes) para modos no-equal. Vacío en `.equal`.
    func resolvedSplitValues() -> [UUID: Double] {
        SplitConfigCodec.decodeValues(splitValuesRaw)
    }

    // MARK: - Write

    /// Dual-write de la plantilla de división. `values` vacío para el modo equal.
    /// Los campos `groupZoneID`, `splitType` y `splitTotalAmount` se setean aparte
    /// (son campos planos, no CSV) en el callsite de guardado.
    func setSplitConfig(participantIDs: [UUID], values: [UUID: Double]) {
        self.splitParticipantIDsRaw = SplitConfigCodec.encodeParticipants(participantIDs)
        self.splitValuesRaw = SplitConfigCodec.encodeValues(values)
    }
}
