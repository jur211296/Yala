//
//  CashFlowOverrideLineMigration.swift
//  Yala
//
//  Pasa los ajustes de un mes del flujo de caja de la relación legado `CashFlowOverride.line` a la nueva
//  `CashFlowOverride.cashFlowLine` (ticket `personal-cloudkit-cashflow-override-line-declared-as-reference`).
//
//  **Por qué hace falta.** En Production de `iCloud.com.jurgenschmidt.yala` el campo `CD_CashFlowOverride.CD_line`
//  es REFERENCE y el espejo de SwiftData escribe STRING: iCloud rechaza el registro entero, y desde 1.2.6 se sabe
//  que ese rechazo atasca también el resto de la subida (`CashFlowWipeService`). Un tipo no se cambia en
//  Production, así que la relación pasó a otra propiedad y por tanto a un campo nuevo (`CD_cashFlowLine`).
//
//  **Qué hace, en cada arranque.** Para cada ajuste con `line` puesto:
//  - sin `cashFlowLine` y sin otro ajuste del mismo mes en esa línea → `cashFlowLine = line`;
//  - si la línea YA tiene un ajuste de ese mes en la relación nueva → este es un duplicado superado y se borra
//    (en Production nunca llegó al servidor: el borrado solo retira su subida pendiente);
//  - siempre, `line = nil` en el MISMO guardado. Un registro que nunca entró en Production se exporta entero, y
//    con `line` puesto saldría otra vez `CD_line` y otra vez el rechazo.
//
//  **Idempotente y sin estado.** Solo mira ajustes con `line` puesto, así que la segunda pasada no encuentra nada.
//  No hay flag: un kill a mitad deja el store como estaba (un solo `save()`), y lo que llegue tarde con `line`
//  puesto —una build vieja de Yala Dev en otro dispositivo, en el contenedor `.dev`, donde `CD_line` sí es STRING—
//  se migra en el arranque siguiente. No inserta nada: no puede crear duplicados.
//

import Foundation
import SwiftData

@MainActor
enum CashFlowOverrideLineMigration {

    struct Outcome: Equatable {
        /// Ajustes que pasaron de `line` a `cashFlowLine`.
        var moved = 0
        /// Ajustes que ya tenían `cashFlowLine` y solo se les vació `line`.
        var cleared = 0
        /// Duplicados superados (su línea ya tenía un ajuste de ese mes en la relación nueva), borrados.
        var duplicatesRemoved = 0

        var touchedAnything: Bool { moved + cleared + duplicatesRemoved > 0 }
    }

    /// Clave de un ajuste dentro de su línea: un mes por línea, que es lo que la pantalla pinta.
    private struct Slot: Hashable {
        let line: PersistentIdentifier
        let monthKey: String
    }

    @discardableResult
    static func migrateIfNeeded(in context: ModelContext) -> Outcome {
        var outcome = Outcome()
        do {
            let all = try context.fetch(FetchDescriptor<CashFlowOverride>())
            let legacy = all.filter { $0.line != nil }
            guard !legacy.isEmpty else { return outcome }

            // Lo que ya ocupa la relación nueva, leído de las filas y no de la inversa: así no depende de cuándo
            // SwiftData refresca `monthOverrides` tras una asignación.
            var taken = Set<Slot>()
            for override in all {
                guard let target = override.cashFlowLine else { continue }
                taken.insert(Slot(line: target.persistentModelID, monthKey: override.monthKey))
            }

            // Orden estable (por `id`): dos dispositivos con los mismos ajustes eligen el mismo superviviente.
            for override in legacy.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                guard let legacyLine = override.line else { continue }
                if override.cashFlowLine != nil {
                    override.line = nil
                    outcome.cleared += 1
                    continue
                }
                let slot = Slot(line: legacyLine.persistentModelID, monthKey: override.monthKey)
                if taken.contains(slot) {
                    context.delete(override)
                    outcome.duplicatesRemoved += 1
                    continue
                }
                override.cashFlowLine = legacyLine
                override.line = nil
                taken.insert(slot)
                outcome.moved += 1
            }

            try context.save()
            #if DEBUG
            print("CashFlowOverrideLineMigration: moved \(outcome.moved), cleared \(outcome.cleared), duplicates removed \(outcome.duplicatesRemoved)")
            #endif
        } catch {
            // Sin `rollback()`: el contexto es el compartido del arranque. Lo que quedó sucio lo reescribe igual la
            // pasada siguiente, que vuelve a encontrar los ajustes con `line` puesto en el store.
            #if DEBUG
            print("CashFlowOverrideLineMigration: Error: \(error)")
            #endif
            return Outcome()
        }
        return outcome
    }
}
