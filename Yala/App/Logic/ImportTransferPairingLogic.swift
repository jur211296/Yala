//
//  ImportTransferPairingLogic.swift
//  Yala
//
//  Cómo empareja el import las dos patas de una transferencia que viene de un archivo de fuera (H9 de la auditoría del
//  import 2.2, ticket `import-transfer-pairing-ignores-accounts-and-currency-changes`). Hasta el 2026-11-22 usaba la
//  heurística del reconciliador de arranque —mismo día, importe y moneda, y solo grupos de una salida y una entrada—,
//  que no miraba la cuenta: una transferencia con cambio de moneda (PEN → USD) no se emparejaba nunca, dos del mismo
//  importe el mismo día tampoco, y dos patas de la MISMA cuenta sí.
//
//  El reconciliador de arranque (`TransferPairReconcileService`) no cambia: no sabe de qué archivo vino cada pata.
//

import Foundation

nonisolated enum ImportTransferPairingLogic {

    /// Una pata de transferencia recién importada.
    struct Leg: Equatable, Sendable {
        /// Su posición entre las patas que se pasan.
        let id: Int
        /// «2026-10-27» en la zona del teléfono.
        let day: String
        /// El importe en diezmilésimas, con signo: negativo sale, positivo entra.
        let amount: Int64
        let currencyCode: String
        let accountKey: String
        /// La nota normalizada (`ImportDuplicateLogic.normalizedNote`).
        let note: String
    }

    struct Pair: Equatable, Sendable {
        let outflow: Int
        let inflow: Int
    }

    /// Las parejas, en tres pasadas:
    ///
    /// 1. Mismo día, importe y moneda, en cuentas distintas. Si una salida tiene varias entradas candidatas, se queda
    ///    con las de nota igual a la suya (si hay alguna con nota); si todas las que quedan son de la misma cuenta, son
    ///    intercambiables y se empareja con la primera; si son de cuentas distintas, no se sabe y se deja. Se repite
    ///    hasta que no cambia nada: emparejar una puede dejar a otra con una sola candidata.
    /// 2. Con cambio de moneda: en un día con exactamente una salida y una entrada sueltas, en cuentas y monedas
    ///    distintas, son la misma transferencia.
    ///
    /// Dos patas de la misma cuenta no se emparejan nunca.
    static func pairs(_ legs: [Leg]) -> [Pair] {
        var paired: Set<Int> = []
        var result: [Pair] = []

        struct Key: Hashable { let day: String; let amount: Int64; let currency: String }
        let groups = Dictionary(grouping: legs.filter { $0.amount != 0 }) {
            Key(day: $0.day, amount: abs($0.amount), currency: $0.currencyCode)
        }
        let orderedKeys = groups.keys.sorted {
            ($0.day, $0.currency, $0.amount) < ($1.day, $1.currency, $1.amount)
        }
        for key in orderedKeys {
            guard let group = groups[key]?.sorted(by: { $0.id < $1.id }) else { continue }
            // Las mejores entradas de una salida: de otra cuenta y, si alguna tiene su misma nota, solo esas.
            func best(for outflow: Leg) -> [Leg] {
                let candidates = group.filter {
                    $0.amount > 0 && !paired.contains($0.id) && $0.accountKey != outflow.accountKey
                }
                let sameNote = outflow.note.isEmpty ? [] : candidates.filter { $0.note == outflow.note }
                return sameNote.isEmpty ? candidates : sameNote
            }
            var progress = true
            while progress {
                progress = false
                for outflow in group where outflow.amount < 0 && !paired.contains(outflow.id) {
                    let choices = best(for: outflow)
                    // Entradas de cuentas distintas: no se sabe a cuál fue.
                    guard let account = choices.first?.accountKey, choices.allSatisfy({ $0.accountKey == account }),
                          let inflow = choices.first else { continue }
                    // Y la cuenta tiene que alcanzar para todas las salidas que solo pueden ir a ella: dos salidas de
                    // cuentas distintas y UNA entrada no dicen de cuál vino.
                    let competitors = group.filter { other in
                        other.amount < 0 && !paired.contains(other.id)
                            && Set(best(for: other).map(\.accountKey)) == [account]
                            && best(for: other).contains { $0.id == inflow.id }
                    }
                    guard competitors.count <= choices.count
                        || Set(competitors.map(\.accountKey)).count == 1 else { continue }
                    paired.insert(outflow.id)
                    paired.insert(inflow.id)
                    result.append(Pair(outflow: outflow.id, inflow: inflow.id))
                    progress = true
                }
            }
        }

        // Pasada 2: cambio de moneda.
        let looseByDay = Dictionary(grouping: legs.filter { !paired.contains($0.id) && $0.amount != 0 }, by: \.day)
        for day in looseByDay.keys.sorted() {
            guard let loose = looseByDay[day] else { continue }
            let outflows = loose.filter { $0.amount < 0 }
            let inflows = loose.filter { $0.amount > 0 }
            guard outflows.count == 1, inflows.count == 1, let outflow = outflows.first, let inflow = inflows.first,
                  outflow.accountKey != inflow.accountKey, outflow.currencyCode != inflow.currencyCode else { continue }
            paired.insert(outflow.id)
            paired.insert(inflow.id)
            result.append(Pair(outflow: outflow.id, inflow: inflow.id))
        }
        return result
    }

    /// Cuántas patas quedan sin pareja.
    static func looseCount(_ legs: [Leg]) -> Int {
        legs.count - pairs(legs).count * 2
    }
}
