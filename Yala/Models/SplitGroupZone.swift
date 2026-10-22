//
//  SplitGroupZone.swift
//  Yala
//
//  Contrato de nombrado de la zona de un grupo: `"SplitGroup-<uuid>"`.
//
//  Nació dentro de `CKConstants` (`Services/Groups/CloudKitConstants.swift`) porque el único consumidor
//  era CKSyncEngine, pero dejó de ser una constante de CloudKit: `SplitGroup.cloudKitZoneID` ES el
//  `group_id` server-side del canal backend (`split_groups`), así que el literal es un CONTRATO CON EL
//  SERVIDOR — cambiarlo rompería la identidad de TODOS los grupos existentes en el backend. Vive fuera
//  del fichero del transporte CloudKit para que retirar ese transporte no se lo lleve por delante:
//  el `init` de `SplitGroup` es su consumidor de producción y sobrevive.
//

import Foundation

enum SplitGroupZone {

    /// Prefijo del nombre de zona ≡ del `group_id` del wire. **Literal congelado**: es identidad
    /// server-side, no un detalle de formato.
    static let zonePrefix = "SplitGroup-"

    /// Deriva el nombre de zona desde el `id` del grupo. OJO: la derivación **solo vale para grupos
    /// nacidos en CloudKit** — un born-remote del pull backend se inserta con `SplitGroup()` (id nuevo) y
    /// se le PISA el `cloudKitZoneID` con el `group_id` del server (`GroupsSyncClient.applyGroupMeta`),
    /// así que quien necesite la zona REAL de una fila debe leer `cloudKitZoneID` (ver los docblocks de
    /// `GroupsIdentityPurgeGate.deleteRows` y `GroupZoneCacheGate`).
    ///
    /// **Su único caller de producción es `CKConstants.zoneID(for:)`** (`Services/Groups/`), que traduce el
    /// `id` de un grupo a la `CKRecordZone.ID` de SU zona — legítimo porque todo grupo que llega a tener
    /// zona CloudKit nació en CloudKit (`SplitZoneManager.createZone` guarda por `!isBackendGroup`). En
    /// tests lo usa el fixture de `GroupsIdentityPurgeGateTests` y el de `GroupZoneCacheGateTests`, los dos
    /// usando esa asimetría como control negativo.
    ///
    /// Este docblock decía «hoy su único caller superviviente es el fixture de …» y era FALSO: la usaban
    /// además `SplitSyncManager.deleteGroupCache` y `reuploadGroupRecords`, que es exactamente lo que había
    /// que arreglar (2026-08-03). Quien lea aquí «está muerta en producción» subestima el radio: antes de
    /// darlo por bueno, `grep -rn "SplitGroupZone.zoneName" --include="*.swift" Yala`.
    static func zoneName(for groupID: UUID) -> String {
        "\(zonePrefix)\(groupID.uuidString)"
    }
}
