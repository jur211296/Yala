//
//  SystemEntityMergePolicy.swift
//  Yala
//
//  Política v1 (Modo Nube Fase 4, residual del gate de flags — NOTA-2 de I12-B) para las entidades de
//  SISTEMA que sincronizan con `sync_id` ACUÑADO POR DEVICE y cuyo nombre es LOCALIZADO, así que dos
//  devices en idiomas distintos crean filas distintas para la MISMA entidad lógica:
//
//   - `Account.isSystemAccount` (cuentas virtuales `Grupos [moneda]` del bridge de Grupos): la identidad
//     lógica real es `(isSystemAccount, currencyCode)` — el nombre lo interpola `L10n.Account.System.groups`.
//   - Subcategoría `balanceAdjustment` (sembrada por nombre del idioma actual; matching multi-idioma en
//     `Subcategory.balanceAdjustmentNames`).
//
//  Sin política, cada device acuña la suya → 2+ filas vivas server-side → el saldo virtual de Grupos queda
//  PARTIDO entre dos cuentas y el dedup local del bridge (`GroupBridgeSystemEntities.ensureSystemAccount`)
//  re-colapsa LOCALMENTE pero NO converge server-side (ambas siguen vivas).
//
//  ESTA lógica es PURA (sin `ModelContext`): agrupa filas por identidad lógica y elige un GANADOR
//  DETERMINISTA-GLOBAL con el MISMO criterio que el dedup del bridge — orden `(name, shortcutID.uuidString)`
//  ascendente, conserva la primera. El `CloudSyncReconciler.reconcileSystemEntities` la consume: re-apunta
//  las referencias de las perdedoras a la ganadora y las tombstonea bajo autor DEFAULT (el delete DEBE
//  drenar/viajar). El caller es quien toca SwiftData.
//
//  Por qué el criterio `(name, shortcutID)` es SEGURO cross-device (a diferencia del hazard de I11-4, donde
//  `pickAccountWinner` usa conteo de TXs LOCAL-dependiente → ganadores distintos → ambos mueren): se computa
//  sobre filas que AMBOS devices ven idénticas tras converger el pull → misma elección en todos → el doble
//  tombstone de la perdedora es noop HLC-idempotente. Es ADEMÁS el mismo criterio de `ensureSystemAccount`
//  (`GroupBridgeSystemEntities.swift`, dedup por `(name, shortcutID.uuidString)`), así que el bridge y este
//  pase elegirían al MISMO ganador → cero pelea (el bridge NO se toca; este doc-comment lo ancla — si el
//  bridge cambiara su criterio de desempate hay que reflejarlo aquí).
//
//  DIFERIDOS (nombrados para el gate de encendido de flags):
//   - D1: las 7 subcategorías de ROL del bridge (`GroupBridgeSystemEntities.SystemSubcategoryRole`) — mismo
//     patrón multi-idioma que balanceAdjustment, fuera de v1 (exigiría replicar el matching de roles).
//   - D2: red server-side (índice parcial `UNIQUE (user_id, currency_code) WHERE is_system_account AND NOT
//     deleted` o dedup en el RPC) — imposible client-side; ADEMÁS el server no puede re-apuntar las refs del
//     device perdedor. Candidato de RED complementaria, no de política (ver `qa/cloud/README.md`).
//   - D3: el problema GENERAL de seeds duplicados cross-idioma (toda la siembra por nombre localizado) — la
//     instancia de sistema es balanceAdjustment; el caso de usuario queda para un diseño propio.
//

import Foundation

nonisolated enum SystemEntityMergePolicy {

    /// Un grupo lógico con >1 fila: el ganador determinista + las perdedoras a tombstonear.
    struct MergeResult<Row> {
        let winner: Row
        let losers: [Row]
    }

    /// PURE. Agrupa `rows` por `groupKey` (currency para cuentas; constante para balanceAdjustment) y, en
    /// cada grupo con ≥2 filas, elige ganador por `(name, tiebreak)` ASCENDENTE (conserva la primera). Grupos
    /// de 1 → omitidos (no-op). Devuelve SOLO grupos con ≥1 perdedor, ordenados por `groupKey` (determinismo
    /// total: cualquier orden de entrada → mismo resultado). `tiebreak` = `shortcutID.uuidString`.
    static func plan<Row>(
        _ rows: [Row],
        groupKey: (Row) -> String,
        name: (Row) -> String,
        tiebreak: (Row) -> String
    ) -> [MergeResult<Row>] {
        var byGroup: [String: [Row]] = [:]
        for row in rows { byGroup[groupKey(row), default: []].append(row) }

        var result: [MergeResult<Row>] = []
        for key in byGroup.keys.sorted() {
            guard let group = byGroup[key], group.count > 1 else { continue }
            let sorted = group.sorted { a, b in
                let na = name(a), nb = name(b)
                if na != nb { return na < nb }
                return tiebreak(a) < tiebreak(b)
            }
            result.append(MergeResult(winner: sorted[0], losers: Array(sorted.dropFirst())))
        }
        return result
    }
}
