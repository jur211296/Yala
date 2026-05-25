//
//  CSVMirrorCodec.swift
//  Yala
//
//  CSV de UUIDs como SSOT para relaciones M2M sensibles a CloudKit lazy hydration.
//  Cuando una `@Relationship` M2M aparece nil/[] post cold start (race CloudKit),
//  el CSV mirror viaja en el mismo record y es legible eager. Patrón replicado en
//  `Budget.subcategoryIDs/accountIDs/tagIDs`, `TransactionItem.tagIDs`, `InboxDraft.tagIDs`.
//

import Foundation

enum CSVMirrorCodec {

    /// Decodifica un CSV `"uuid1,uuid2"` a `Set<UUID>`. Tokens inválidos se
    /// descartan silenciosamente. Retorna nil si el input es nil/vacío o si
    /// no sobrevive ningún UUID válido.
    static func decode(_ csv: String?) -> Set<UUID>? {
        guard let csv, !csv.isEmpty else { return nil }
        let uuids = csv.split(separator: ",").compactMap {
            UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces))
        }
        return uuids.isEmpty ? nil : Set(uuids)
    }

    /// Codifica una colección de UUIDs como CSV ordenado y deduplicado.
    /// Retorna nil para colección vacía (semántica "sin filtro", no "filtro vacío").
    static func encode(_ ids: some Collection<UUID>) -> String? {
        guard !ids.isEmpty else { return nil }
        return Set(ids).map(\.uuidString).sorted().joined(separator: ",")
    }
}
