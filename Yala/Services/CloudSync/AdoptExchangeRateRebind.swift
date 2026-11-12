//
//  AdoptExchangeRateRebind.swift
//  Yala
//
//  «Entrar con mi cuenta» subía 366 tipos de cambio en cada teléfono (card hov2 del QA guiado del 19-oct; medido en la
//  flota: `cloudAdoptOrphanReconciled` = 366 en las cinco entradas desde el 14-oct). Son los que el arranque descarga antes
//  del Welcome (`AppBootstrapper.loadExchangeRates`, un año, una fila por día) sin identidad del backend, así que el adopt
//  los trataba como huérfanos y los subía ANTES de dejar pasar: decenas de segundos de «Conectando con tu cuenta…» y una
//  copia más de cada día en la cuenta por cada teléfono.
//
//  Un tipo de cambio es un dato público del día: el del backend para la misma fecha y la misma base es el mismo. Así que el
//  adopt le da a la fila local la identidad del backend en vez de acuñarle una nueva, y deja de ser huérfana. El pull
//  siguiente le baja el contenido del backend con esa identidad.
//

import Foundation

nonisolated enum AdoptExchangeRateRebind {

    /// Una fila local candidata: sin identidad todavía, con su ancla de contenido (`SyncContentAnchor.exchangeRate`).
    struct Candidate: Equatable {
        let index: Int
        let anchor: String
    }

    /// A qué identidad del backend pasa cada candidata (por su `index`). Reglas, y por qué:
    /// - **Solo filas VIVAS del backend** con la misma ancla. Un tombstone no se resucita.
    /// - **Con varias en el backend para la misma ancla** —cada teléfono que entró antes de este arreglo subió las suyas—,
    ///   la de menor `syncID`. Es arbitrario a propósito y es seguro: ningún modelo apunta a un tipo de cambio (no hay
    ///   relación ni espejo CSV hacia `ExchangeRate`), así que elegir una u otra no rompe nada, y todos los teléfonos
    ///   eligen la misma.
    /// - **Una identidad que ya lleva una fila local no se da** (`taken`): dos filas vivas con el mismo `syncID` colapsan en
    ///   el servidor (el bug que el backfill cura re-acuñando).
    /// - **Solo una fecha y base que este teléfono tiene UNA vez** (`localAnchors`: las anclas de TODAS sus filas, con o sin
    ///   identidad). Con dos filas del mismo día, una puede ser la del líder importada por iCloud, cuya identidad —la misma
    ///   del backend— puede llegar más tarde: casar la otra dejaría dos filas vivas con un `syncID` (lo cazó la review).
    ///   Las dos suben como antes.
    static func plan(candidates: [Candidate], backendLive: [UUID: String], taken: Set<UUID>,
                     localAnchors: [String]) -> [Int: UUID] {
        var localCount: [String: Int] = [:]
        for anchor in localAnchors { localCount[anchor, default: 0] += 1 }
        var byAnchor: [String: [UUID]] = [:]
        for (syncID, anchor) in backendLive where !taken.contains(syncID) {
            byAnchor[anchor, default: []].append(syncID)
        }
        for anchor in byAnchor.keys {
            byAnchor[anchor]?.sort { $0.uuidString < $1.uuidString }
        }
        var assignment: [Int: UUID] = [:]
        for candidate in candidates where localCount[candidate.anchor] == 1 {
            guard var available = byAnchor[candidate.anchor], !available.isEmpty else { continue }
            assignment[candidate.index] = available.removeFirst()
            byAnchor[candidate.anchor] = available.isEmpty ? nil : available
        }
        return assignment
    }

    /// El ancla de una fila del backend, leída de su wire. `nil` si falta un campo o no es un texto: esa fila no casa con
    /// nada y la local, si la hay, sube como antes.
    static func backendAnchor(fields: [String: WireValue]) -> String? {
        guard case .string(let dateKey)? = fields["date_key"], case .string(let base)? = fields["base"] else { return nil }
        return SyncContentAnchor.exchangeRate(dateKey: dateKey, base: base)
    }
}
