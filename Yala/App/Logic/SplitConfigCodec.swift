//
//  SplitConfigCodec.swift
//  Yala
//
//  Codec puro para la plantilla de división de un pago planificado de grupo
//  (`ScheduledPayment` con `groupZoneID != nil`). Pure-logic, sin SwiftData ni UI
//  → testeable sin contexto.
//
//  - Participantes: CSV de UUIDs (SplitMember.id). El orden no importa (se reconstruye
//    como Set), así que se ordena para estabilidad.
//  - Valores por participante: CSV de pares "uuid:value" (%/monto/partes). El pareo es
//    EXPLÍCITO (uuid→valor) para no depender del orden — NO usar dos CSV paralelos.
//    Solo aplica a modos no-equal; en `.equal` no hay valor por miembro.
//

import Foundation

enum SplitConfigCodec {

    // MARK: - Participants

    /// Codifica los UUIDs de participantes como CSV ordenado y deduplicado.
    /// Retorna nil para colección vacía.
    static func encodeParticipants(_ ids: some Collection<UUID>) -> String? {
        guard !ids.isEmpty else { return nil }
        return Set(ids).map(\.uuidString).sorted().joined(separator: ",")
    }

    /// Decodifica un CSV de UUIDs. Tokens inválidos se descartan.
    static func decodeParticipants(_ csv: String?) -> [UUID] {
        guard let csv, !csv.isEmpty else { return [] }
        return csv.split(separator: ",").compactMap {
            UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces))
        }
    }

    // MARK: - Per-participant values ("uuid:value" pairs)

    /// Codifica el mapa miembro→valor como CSV de pares "uuid:value" (ordenado).
    /// Retorna nil para mapa vacío (modo equal).
    static func encodeValues(_ map: [UUID: Double]) -> String? {
        guard !map.isEmpty else { return nil }
        return map
            .map { "\($0.key.uuidString):\($0.value)" }
            .sorted()
            .joined(separator: ",")
    }

    /// Decodifica el CSV de pares "uuid:value". El uuidString usa "-" (no ":") y el
    /// valor es un Double ("." decimal), así que split(":") da exactamente 2 partes.
    /// Pares malformados se descartan.
    static func decodeValues(_ csv: String?) -> [UUID: Double] {
        guard let csv, !csv.isEmpty else { return [:] }
        var result: [UUID: Double] = [:]
        for token in csv.split(separator: ",") {
            let parts = token.split(separator: ":")
            guard parts.count == 2,
                  let id = UUID(uuidString: parts[0].trimmingCharacters(in: .whitespaces)),
                  let value = Double(parts[1].trimmingCharacters(in: .whitespaces))
            else { continue }
            result[id] = value
        }
        return result
    }
}
