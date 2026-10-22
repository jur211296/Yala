//
//  GroupZoneCacheGate.swift
//  Yala
//
//  Limpieza de la CACHÉ LOCAL de una zona de Grupos cuando CloudKit dice que la zona ya no está
//  (`fetchedDatabaseChanges.deletions` con `.deleted`/`.purged`, y el `zoneNotFound` de un save pendiente).
//  Sale de `SplitSyncManager.deleteGroupCache` + el guard G6-3 que lo protegía, que estaban SEPARADOS y por
//  eso podían hablar de FILAS DISTINTAS de la misma zona.
//
//  ── Por qué existe este fichero y no un método privado más ─────────────────────────────────────────────
//  `deleteGroupCache` era `private` sobre un singleton con CKSyncEngine vivo y sus dos handlers reciben
//  eventos de CKSyncEngine que no tienen init público ⇒ NADA de esto era testeable. Separado aquí se prueba
//  con un `ModelContext` in-memory, molde EXACTO de `GroupsIdentityPurgeGate` (`Yala/App/Logic/`), que
//  resolvió el mismo problema —decidir por ZONA y no por fila— para la purga por cambio de Apple ID. El
//  cableado, que es lo que la lógica pura no puede probar, lo fija un source-scan.
//
//  ── Los DOS defectos que cierra (medidos 2026-08-03; ver `.claude/rules/swiftdata-cloudkit.md`) ─────────
//  (1) **El barrido del GRUPO iba por `id`, no por zona.** `deleteGroupCache` borraba las cuatro clases de
//      hijas por `groupZoneID == zoneName` (correcto: el `zoneName` se reconstruía del `groupID` que el
//      caller ya había parseado del nombre de zona del EVENTO, así que la derivación round-trip era exacta)
//      pero el `SplitGroup` por `#Predicate { $0.id == groupID }` y `.first` — UNA fila. Eso NO deja
//      huérfanas, que es como lo describían la regla y el índice: deja un **CASCARÓN**, la fila del grupo
//      viva con todas sus hijas muertas, en las dos formas en que `id` y zona divergen — una fila
//      born-remote (`GroupsSyncClient.applyGroupMeta` inserta `SplitGroup()` con id fresco y le PISA el
//      `cloudKitZoneID` con el `group_id` del server) y un `SplitGroup` DUPLICADO en la zona
//      (`SplitGroupDeduplicationService`), donde además elegía cuál borrar sin `sortBy`.
//  (2) **El guard decidía con UNA fila.** Consultaba `GroupService.group(for:)`, que devuelve `results.first`
//      ordenado por `createdAt` ASC. Con un duplicado MIXTO (una fila backend y su gemela sin marcar —
//      `GroupsSyncClient.fetchSplitGroup` tiene `fetchLimit = 1` SIN `sortBy`, así que la adopción voltea
//      una arbitraria) el guard puede leer la NO-backend y no disparar. Y el desempate no es fiable ni
//      siquiera en teoría: la fila born-remote toma su `createdAt` del WIRE (`applyGroupMeta`) y la CloudKit
//      del record, así que pueden EMPATAR, y ahí SwiftData no garantiza orden.
//      Consecuencia del par: se borraban las hijas de toda la zona bajo el autor POR DEFECTO mientras la fila
//      backend SOBREVIVÍA ⇒ la zona seguía en `GroupsSyncClient.backendGroupZoneIDs` (un fetch de filas
//      VIVAS) ⇒ el drain traducía esos borrados a tombstones de `split_expenses`/`split_shares`/
//      `split_settlements` con HLC fresco, que el servidor aplica con `is_group_writer` — más laxo que el
//      `is_group_admin` que protege la meta. Blast radius: los GASTOS del grupo, para TODOS los miembros.
//      El `guard !updateOnly` que se añadió el 2026-08-02 NO cubre esto: es solo para `split_groups`, y el
//      tombstone de un gasto SÍ tiene que viajar (`GroupsSyncHardeningTests:373` lo exige por escrito).
//
//  ── Alcanzabilidad, para que la hipótesis CADUQUE bien ─────────────────────────────────────────────────
//  Ambos exigen una zona **viva en CloudKit y conocida por el backend a la vez**, y hoy nadie la fabrica:
//  `GroupMigrationUploader` se borró (`5010db6a`, 2026-07-28); `migrate_group` está revocada también a
//  `authenticated` en los DOS entornos (`supabase-groups-staging.ddl:1335`, mismo día) y no está en el
//  `PARAM_ALLOWLIST` del gateway; `movedToBackendAt` no tiene NI UN escritor local (los dos de
//  `CKRecordTranslator` copian de un CKRecord ya fetcheado ⇒ punto fijo en `nil`); y un grupo del canal
//  backend nunca adquiere zona CloudKit (`SplitZoneManager.createZone`/`createShare` guardan por
//  `!isBackendGroup`). El orden lo remata: el uploader murió el 2026-07-28 y `groupsBackendCompiledDefault`
//  pasó a `true` el 2026-07-30 ⇒ ningún build distribuido tuvo las dos cosas a la vez.
//  ⇒ **esto es endurecimiento, no un incidente.** Se arregla porque la cadena que lo cierra es «el productor
//  ya no existe» y no un guard, y porque el coste de la clase es alto. **Residual que no se resuelve leyendo
//  código**: `2efd2929` (2026-07-18) encendió el flag compilado con el uploader vivo y se revirtió el mismo
//  día; si algún device de dogfooding llegó a migrar, esa zona quedó dual-canal para siempre. Es una
//  consulta al servidor.
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupZoneCacheGate {

    #if DEBUG
    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")
    #endif

    // MARK: - Decisión

    enum Classification: Equatable {
        /// Ninguna fila de la zona pertenece al canal backend ⇒ la caché local se puede borrar.
        case cloudKitZone
        /// ALGUNA fila pertenece al canal backend (o es una copia congelada) ⇒ NO tocar: su verdad vive en
        /// el backend y el borrado de la zona CloudKit es un no-evento para ella.
        case backendZone
        /// El fetch lanzó: no se pudo clasificar. **FAIL-CLOSED** — se trata como intocable.
        case unclassifiable
    }

    /// Decisión PURA de una ZONA. La unidad es la zona y no la fila porque las hijas cuelgan del string
    /// plano `groupZoneID`, sin `@Relationship`: una zona pertenece al canal backend si **CUALQUIERA** de
    /// sus filas lo hace. Es el mismo criterio (y por la misma razón) que
    /// `GroupsIdentityPurgeGate.decideForZone`.
    ///
    /// El predicado de pertenencia es `GroupBackendIdentityLogic.belongsToBackendChannel` y no
    /// `GroupFreezeLogic.isFrozen`: aquí no se decide si el grupo puede ESCRIBIR a CKSyncEngine (donde la
    /// mitigación #9 del owner-tras-reinstall pide el predicado estrecho) sino si sus datos locales son
    /// destruibles, que es exactamente la pregunta de RETENCIÓN.
    static func belongsToBackendChannel(
        rowsInZone: [(isBackendGroup: Bool, movedToBackendAt: Date?)]
    ) -> Bool {
        rowsInZone.contains {
            GroupBackendIdentityLogic.belongsToBackendChannel(
                isBackendGroup: $0.isBackendGroup, movedToBackendAt: $0.movedToBackendAt)
        }
    }

    /// Clasifica la zona leyendo **TODAS** sus filas.
    ///
    /// **FAIL-CLOSED, y ése es el cambio de comportamiento respecto del guard anterior.** El guard era
    /// `if let localGroup = GroupService.shared.group(for: zoneName), localGroup.isBackendGroup || …`, y
    /// `group(for:)` devuelve `nil` tanto con el `modelContext` ausente como cuando el fetch LANZA (loguea y
    /// `return nil`) ⇒ un fallo de LECTURA abría el camino DESTRUCTIVO. Aquí una zona que no se puede
    /// clasificar no se borra: perder una limpieza de caché es reversible (el próximo evento la repite, y
    /// nada la resucita mal), destruir las hijas de un grupo backend no lo es.
    static func classify(zoneName: String, context: ModelContext) -> Classification {
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(
                FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneName }))
        } catch {
            #if DEBUG
            logger.error("GroupZoneCacheGate: fetch de la zona falló — se trata como intocable: \(error)")
            #endif
            return .unclassifiable
        }
        let belongs = belongsToBackendChannel(
            rowsInZone: rows.map { (isBackendGroup: $0.isBackendGroup, movedToBackendAt: $0.movedToBackendAt) })
        return belongs ? .backendZone : .cloudKitZone
    }

    // MARK: - Barrido

    struct Result: Equatable {
        /// Filas `SplitGroup` borradas. Puede ser >1 (zona con duplicado) y puede ser 0 (zona ya limpia, o
        /// el `SplitGroup` lo borró antes el camino local y solo quedaban hijas).
        var groups = 0
        var members = 0
        var shares = 0
        var expenses = 0
        var settlements = 0
        /// El borrado de hijas lanzó a mitad: el `SplitGroup` YA se fue (va primero, igual que
        /// `GroupsIdentityPurgeGate.deleteRows`) ⇒ lo que queda son huérfanas invisibles, jamás un grupo
        /// fantasma en la lista. El caller lo delata por breadcrumb.
        var partial = false
    }

    /// Borra la caché local de la zona: **todas** sus filas `SplitGroup` y las cuatro clases de hijas.
    ///
    /// La clave es SIEMPRE el `zoneName` del evento y JAMÁS `SplitGroupZone.zoneName(for: group.id)`: esa
    /// derivación solo vale para los grupos nacidos en CloudKit (ver el docblock de `SplitGroupZone`), y era
    /// la mitad del defecto (1) de la cabecera.
    ///
    /// **NO salva** — el caller hace UN `save()` con su `SaveBreadcrumb`, como el resto de los handlers del
    /// delegate. Paridad deliberada con `GroupsIdentityPurgeGate.apply`.
    ///
    /// Precondición: la zona ya está clasificada como `.cloudKitZone`. Se re-comprueba dentro para que el
    /// invariante no dependa del orden de dos llamadas en el caller — la separación guard/borrado es
    /// exactamente lo que permitía que ambos hablaran de filas distintas de la misma zona.
    @discardableResult
    static func deleteCache(zoneName: String, context: ModelContext) -> Result {
        var result = Result()
        guard classify(zoneName: zoneName, context: context) == .cloudKitZone else { return result }

        let groups: [SplitGroup]
        do {
            groups = try context.fetch(
                FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneName }))
        } catch {
            #if DEBUG
            logger.error("GroupZoneCacheGate: fetch del grupo falló: \(error)")
            #endif
            result.partial = true
            return result
        }
        for group in groups { context.delete(group) }
        result.groups = groups.count

        do {
            // `#Predicate` CONCRETO por tipo: uno genérico-protocolo compila y CRASHEA al ejecutar el fetch.
            let members = try context.fetch(
                FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for member in members { context.delete(member) }
            result.members = members.count

            let shares = try context.fetch(
                FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for share in shares { context.delete(share) }
            result.shares = shares.count

            let expenses = try context.fetch(
                FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for expense in expenses { context.delete(expense) }
            result.expenses = expenses.count

            let settlements = try context.fetch(
                FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for settlement in settlements { context.delete(settlement) }
            result.settlements = settlements.count
        } catch {
            #if DEBUG
            logger.error("GroupZoneCacheGate: borrado de hijas falló: \(error)")
            #endif
            result.partial = true
        }
        return result
    }
}
