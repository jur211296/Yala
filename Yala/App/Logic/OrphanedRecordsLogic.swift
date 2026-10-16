//
//  OrphanedRecordsLogic.swift
//  Yala
//
//  Movimientos que se quedaron sin cuenta: cuáles son y a qué cuenta se pueden mover.
//  Cards `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw` (decisión de Jürgen del 2026-10-15: avisar y dejar
//  elegir a qué cuenta moverlos) y `tablero-eliminar-una-cuenta-todavia-puede-dejar-mjzx` (los que llegan tarde).
//

import Foundation

/// Las decisiones puras del aviso «Movimientos sin cuenta».
///
/// **De dónde salen:** `Account.transactions` es `.nullify`. Antes de la 2.1, eliminar una cuenta dejaba sus movimientos
/// sin cuenta; desde la 2.1 la hoja de eliminar pregunta, pero solo ve lo que hay en ESTE teléfono: lo que llega después
/// por sync (una restauración a medias, otro dispositivo que apuntó un gasto en esa cuenta a la vez) también se queda sin
/// cuenta. Nada en la app crea un movimiento sin cuenta a propósito.
///
/// **Por qué importa:** el saldo y los gastos del Panel solo suman movimientos de cuentas elegibles, y el resumen de
/// Registros tampoco los cuenta: el dinero desaparece de las cifras sin que nada lo diga.
///
/// **La salida (decisión de Jürgen):** avisar y dejar elegir a qué cuenta moverlos. El recuento es CONTINUO —se hace en
/// cada recarga del Panel—, así que también aparecen los que llegan tarde. Mover sigue las reglas de la hoja de eliminar
/// cuenta (`AccountRemovalLogic`): misma conversión de moneda y mismo trato de las transferencias.
enum OrphanedRecordsLogic {

    /// Lo que decide si un movimiento cuenta como «sin cuenta».
    struct Candidate: Equatable {
        let hasAccount: Bool
        /// Lleva puntero a un gasto o liquidación de grupo.
        let hasGroupPointer: Bool
    }

    /// Sin cuenta y SIN puntero de grupo.
    ///
    /// **Las filas de grupo se quedan fuera, a propósito:** una pata virtual vive en una cuenta de sistema de Grupos, y
    /// con esa cuenta aún sin hidratar se lee igual que una huérfana (`BridgedEditPolicy` la trata así). Moverla a una
    /// cuenta real la convertiría en una pata real y el gasto contaría dos veces. Las gobierna el puente de grupos.
    static func isOrphan(_ candidate: Candidate) -> Bool {
        !candidate.hasAccount && !candidate.hasGroupPointer
    }

    /// ¿Se enseña el aviso? Con algo que mover y el import QUIETO: durante una restauración un movimiento puede llegar
    /// antes que su cuenta, y avisar ahí de miles de filas a medio hidratar sería falso. No bloquea nada: el recuento se
    /// repite en cada recarga.
    static func showsNotice(orphanCount: Int, importIsQuiescent: Bool) -> Bool {
        orphanCount > 0 && importIsQuiescent
    }

    /// Qué pasa al mover los huérfanos a una cuenta.
    struct MoveOutcome: Equatable {
        /// Los que quedan en la cuenta destino.
        let moved: Int
        /// De esos, los que cambian de moneda (con el tipo de cambio de su fecha).
        let converted: Int
        /// Los que pasan TAL CUAL en otra moneda: transferencias, que no admiten conversión.
        let keptInTheirCurrency: Int
        /// Los que se quitan: patas de transferencia que quedarían dentro de la cuenta destino.
        let removed: Int
    }

    /// Qué pasa al mover los huérfanos a `destinationID`, con las reglas de la hoja de eliminar cuenta
    /// (`AccountRemovalLogic`), salvo una.
    ///
    /// **Nunca se bloquea por moneda**, a diferencia de eliminar una cuenta. Allí el bloqueo protegía una cuenta que
    /// existía: mover su transferencia a otra moneda la desemparejaba, y la salida era borrar. Aquí no hay cuenta que
    /// proteger ni otra salida: un huérfano ya está fuera del saldo, y bloquear dejaba el aviso puesto para siempre (una
    /// cuenta en dólares borrada con transferencias a dos cuentas en soles no tenía ningún destino). Una transferencia
    /// en otra moneda pasa tal cual, sin convertir —su pareja no cambia—, que es lo que ya hace la hoja de eliminar con
    /// una fila que venía desemparejada (`AccountRemovalLogic.rowConverts`).
    ///
    /// **Se quita** la pata cuya pareja vive en el destino, y las dos patas de una transferencia que quedó entera sin
    /// cuenta (`pairedWithinOrphans`): las dos acabarían en el destino, y dentro de una cuenta no mueven dinero.
    static func moveOutcome<ID: Hashable>(
        rows: [AccountRemovalLogic.Row<ID>],
        pairedWithinOrphans: [Bool],
        to destinationID: ID,
        currencyCode: String
    ) -> MoveOutcome {
        let target = normalizeCurrencyCode(currencyCode)
        var moved = 0
        var converted = 0
        var kept = 0
        var removed = 0
        for (index, row) in rows.enumerated() {
            let pairedInside = index < pairedWithinOrphans.count && pairedWithinOrphans[index]
            if pairedInside || row.transferPartnerAccount == destinationID {
                removed += 1
                continue
            }
            moved += 1
            if AccountRemovalLogic.rowConverts(row, to: target) {
                converted += 1
            } else if normalizeCurrencyCode(row.currencyCode) != target {
                kept += 1
            }
        }
        return MoveOutcome(moved: moved, converted: converted, keptInTheirCurrency: kept, removed: removed)
    }
}
