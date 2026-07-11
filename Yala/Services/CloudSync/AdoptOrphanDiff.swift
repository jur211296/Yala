//
//  AdoptOrphanDiff.swift
//  Yala
//
//  Lógica PURA (DIFERIDOS #30, mecanismo v1 DARK) que compara el inventario LOCAL de un device que adopta
//  (`.icloud`→`.cloud`) contra el set de identidades que el backend ya conoce, y produce el PLAN de filas
//  huérfanas a re-subir. Cierra el hueco multi-device del cutover (§g.4): una fila que un 2º device escribió
//  a la base CloudKit compartida durante la ventana `localModeSet→mirrorOff` — que el LÍDER nunca importó —
//  queda AUSENTE del backend; al adoptar, ese device la ve barato (está en su store local) y la sube.
//
//  Sin (A) esta pieza, TODO adopt multi-device con writes de ventana termina en divergencia Merkle
//  local-ahead PERPETUA (autoridad backend→local en el pull; la clase exacta del bug FX de la corrida device
//  2026-07-11) — no solo el caso "fila perdida".
//
//  `nonisolated enum` PURO (patrón `AccountClaimDecision`): sin `ModelContext`, sin I/O, sin `Date`. El
//  EXECUTOR (`MigrationWorkExecutor.runAdoptOrphanReconcile`) le pasa el inventario ya fetcheado + el set
//  del backend, acuña las identidades frescas (vía `SyncIdentityService.backfillIdentities`) y sube.
//

import Foundation

nonisolated enum AdoptOrphanDiff {

    /// Plan de reconciliación (sin I/O). Keyed por NOMBRE DE TABLA Postgres (`tx_items`, `accounts`, …), el
    /// mismo criterio que el diff del backend (`PulledDelta.entityType`).
    struct Plan: Equatable {
        /// table → identidades presentes LOCALMENTE y ausentes del backend → subir fila COMPLETA. Orden
        /// determinista (identidades asc por `uuidString`) para reproducibilidad en tests order-independientes.
        let orphans: [String: [UUID]]
        /// table → nº de filas locales SIN identidad (`syncID == nil`). Solo posible en las 6 entidades de
        /// identidad SINTÉTICA; las 10 id-estables tienen identidad inherente no-opcional → jamás producen nil
        /// (contrato). El executor les acuña UUID fresco (backfill) antes de subir — y tras el backfill TODAS
        /// caen a `orphans` (un UUID fresco jamás está en el backend). En el DRY-RUN del panel (sin backfill)
        /// este contador es lo que se muestra por tabla.
        let needsIdentity: [String: Int]

        /// Total de filas huérfanas a subir.
        var uploadCount: Int { orphans.values.reduce(0) { $0 + $1.count } }
        /// Total de filas sin identidad (dry-run del panel).
        var identityCount: Int { needsIdentity.values.reduce(0, +) }
    }

    /// Diffea el inventario local contra el set del backend.
    ///
    /// - Parameters:
    ///   - inventory: `(table, syncID?)` de TODAS las filas VIVAS locales (sin soft-delete: borrado = inexistente).
    ///   - backendSyncIDs: TODAS las identidades que el backend conoce — upserts Y tombstones. Un tombstone del
    ///     backend significa "el backend YA sabe de esa fila": la copia local viva es un ZOMBIE que el apply
    ///     normal del adopt borrará, JAMÁS un huérfano a re-subir → por eso se cuenta como CONOCIDA.
    /// - Returns: el plan (huérfanas a subir + conteo de sin-identidad).
    static func compute(
        inventory: [(table: String, syncID: UUID?)],
        backendSyncIDs: Set<UUID>
    ) -> Plan {
        var orphans: [String: [UUID]] = [:]
        var needsIdentity: [String: Int] = [:]
        for row in inventory {
            if let sid = row.syncID {
                // Identidad presente: huérfana SOLO si el backend no la conoce (ni por upsert ni por tombstone).
                if !backendSyncIDs.contains(sid) {
                    orphans[row.table, default: []].append(sid)
                }
            } else {
                needsIdentity[row.table, default: 0] += 1
            }
        }
        // Orden determinista por tabla (reproducibilidad; el orden de fetch de SwiftData no está garantizado).
        for (table, ids) in orphans {
            orphans[table] = ids.sorted { $0.uuidString < $1.uuidString }
        }
        return Plan(orphans: orphans, needsIdentity: needsIdentity)
    }
}
