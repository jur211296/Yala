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
//  **Qué hace, en cada arranque.** Agrupa los ajustes por su clave natural —línea (`cashFlowLine`, o `line` si aún
//  no migró) y mes— y en cada grupo:
//  - se queda **uno**, el de menor `id` (`survivor(among:)`), y borra los demás;
//  - al superviviente le pone `cashFlowLine` si no la tenía, y `line = nil` en el MISMO guardado. Un registro que
//    nunca entró en Production se exporta entero, y con `line` puesto saldría otra vez `CD_line` y otra vez el rechazo.
//
//  **Por qué el de menor `id`, mire la relación que mire** (ticket
//  `cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two`). Hasta 2.1 los ajustes no sincronizaban en
//  Production: alguien con dos iPhone pudo apuntar el mismo mes en los dos, y al actualizar cada uno sube el suyo y
//  recibe el del otro. Los ajustes no tienen fecha, así que «el más reciente» no se puede saber sin un campo nuevo de
//  iCloud. Lo que sí se puede es que **los dos teléfonos elijan el mismo**, sea cual sea el orden en que les llegan:
//  cada uno borra solo lo que no es el mínimo de lo que tiene, y el mínimo de un subconjunto que no es el mínimo de
//  todos lo borraría igual el otro. La regla anterior («gana el que ya estaba en la relación nueva») dependía del orden
//  de llegada: en `.dev`, un teléfono podía conservar el que el otro borraba, y entre los dos no quedaba ninguno.
//
//  **Un ajuste sin ninguna línea no se toca.** Es el que una versión vieja recibe por iCloud sin conocer
//  `CD_cashFlowLine` (ticket `cashflow-override-synced-to-an-old-version-stays-invisible-after-updating`): su registro
//  en iCloud sí tiene la línea, y al actualizar la recibe. Borrarlo viajaría a iCloud y se llevaría el ajuste del
//  otro teléfono.
//
//  **Idempotente y sin estado.** La segunda pasada no encuentra duplicados ni `line` puestos. No hay flag: un kill a
//  mitad deja el store como estaba (un solo `save()`), y lo que llegue tarde —un duplicado del otro teléfono, o una
//  build vieja de Yala Dev en el contenedor `.dev`, donde `CD_line` sí es STRING— se funde en el arranque siguiente.
//  Mientras tanto, los lectores ya enseñan el superviviente (`CashFlowLine.monthOverride(for:)`, que mira las dos
//  relaciones). No inserta nada.
//
//  **Dos pasadas por arranque** (`Scope`): la del paso 0.0, solo con lo que trae legado, y la completa detrás de la
//  puerta de quiescencia del import, que es la que funde lo que llegó por iCloud.
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
        /// Ajustes de un mes que su línea ya tenía (en cualquiera de las dos relaciones), borrados.
        var duplicatesRemoved = 0

        var touchedAnything: Bool { moved + cleared + duplicatesRemoved > 0 }
    }

    /// Clave natural de un ajuste: un mes por línea, que es lo que la pantalla pinta.
    private struct Slot: Hashable {
        let line: PersistentIdentifier
        let monthKey: String
    }

    /// El ajuste que se queda entre varios del mismo mes de una línea: el de menor `id`. La pasada de arranque y los
    /// lectores usan esta misma regla, así que la pantalla enseña ya el que va a sobrevivir.
    nonisolated static func survivor(among overrides: [CashFlowOverride]) -> CashFlowOverride? {
        overrides.min { $0.id.uuidString < $1.id.uuidString }
    }

    /// Qué grupos (línea + mes) toca una pasada.
    enum Scope {
        /// Solo los que traen algún ajuste con `line` puesto. Es la pasada del paso 0.0 del arranque, que corre antes
        /// de la puerta de quiescencia del import: esos ajustes son locales (Production los rechazaba), así que
        /// guardar ahí no compite con lo que baja de iCloud.
        case groupsWithLegacy
        /// Todos. Funde también los duplicados que llegan por iCloud, así que va DETRÁS de la puerta del import
        /// (`AppBootstrapper.awaitPersonalStoreReady`): guardar el contexto compartido con el import en curso es el
        /// crash de `BootSaveGateLogic`.
        case all
    }

    @discardableResult
    static func migrateIfNeeded(in context: ModelContext, scope: Scope = .all) -> Outcome {
        var outcome = Outcome()
        do {
            let all = try context.fetch(FetchDescriptor<CashFlowOverride>())

            // Agrupado por las filas y no por la inversa (`monthOverrides`): así no depende de cuándo SwiftData la
            // refresca tras una asignación. Un ajuste sin ninguna línea no entra: no tiene clave natural.
            var slots: [Slot: [CashFlowOverride]] = [:]
            for override in all {
                guard let target = override.cashFlowLine ?? override.line else { continue }
                slots[Slot(line: target.persistentModelID, monthKey: override.monthKey), default: []].append(override)
            }

            for group in slots.values {
                if scope == .groupsWithLegacy, !group.contains(where: { $0.line != nil }) { continue }
                guard let keeper = survivor(among: group) else { continue }
                for override in group where override !== keeper {
                    context.delete(override)
                    outcome.duplicatesRemoved += 1
                }
                if keeper.cashFlowLine == nil, let legacyLine = keeper.line {
                    keeper.cashFlowLine = legacyLine
                    keeper.line = nil
                    outcome.moved += 1
                } else if keeper.line != nil {
                    keeper.line = nil
                    outcome.cleared += 1
                }
            }

            guard outcome.touchedAnything else { return outcome }
            try context.save()
            #if DEBUG
            print("CashFlowOverrideLineMigration: moved \(outcome.moved), cleared \(outcome.cleared), duplicates removed \(outcome.duplicatesRemoved)")
            #endif
        } catch {
            // Sin `rollback()`: el contexto es el compartido del arranque. Lo que quedó sucio lo reescribe igual la
            // pasada siguiente, que vuelve a encontrar en el store los duplicados y los `line` puestos.
            #if DEBUG
            print("CashFlowOverrideLineMigration: Error: \(error)")
            #endif
            return Outcome()
        }
        return outcome
    }
}
