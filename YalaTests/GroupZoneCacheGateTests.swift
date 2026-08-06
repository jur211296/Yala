//
//  GroupZoneCacheGateTests.swift
//  YalaTests
//
//  Limpieza de la caché local cuando CloudKit dice que una zona de Grupos ya no está.
//
//  Lo que estos tests fijan, y por qué NINGUNO se podía escribir antes: la decisión («¿es tocable esta
//  zona?») y el barrido («borra sus filas») vivían SEPARADOS dentro de `SplitSyncManager` —un guard sobre
//  `GroupService.group(for:)` y un `deleteGroupCache` privado— así que podían hablar de FILAS DISTINTAS de
//  la misma zona, y ninguno era alcanzable desde un test (los handlers reciben eventos de CKSyncEngine, que
//  no tienen init público). `GroupZoneCacheGate` los une y los saca a `Yala/App/Logic/`, molde EXACTO de
//  `GroupsIdentityPurgeGate`; el cableado, que es lo que la lógica no puede probar, va por source-scan.
//
//  Fixtures al molde de `GroupsIdentityPurgeGateTests`: la zona de las hijas SALE de `group.cloudKitZoneID`
//  y no se deriva del `id`, salvo donde esa asimetría ES el sujeto.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupZoneCacheGateTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        return try makeTestContext()
    }

    /// Un `SplitGroup` con UN hijo de cada tipo en la zona indicada. Si `zone` es `nil` usa la del `init`
    /// (id ↔ zona consistentes, o sea un grupo nacido en CloudKit).
    @discardableResult
    private func seed(
        in context: ModelContext,
        name: String,
        zone: String? = nil,
        isBackendGroup: Bool = false,
        movedToBackendAt: Date? = nil,
        createdAt: Date? = nil,
        withChildren: Bool = true
    ) throws -> SplitGroup {
        let group = SplitGroup(name: name)
        if let zone { group.cloudKitZoneID = zone }
        group.isBackendGroup = isBackendGroup
        group.movedToBackendAt = movedToBackendAt
        if let createdAt { group.createdAt = createdAt }
        context.insert(group)
        if withChildren {
            let z = group.cloudKitZoneID
            context.insert(SplitMember(groupZoneID: z, displayName: "Ana"))
            context.insert(SplitExpense(groupZoneID: z, amount: 300, expenseDescription: "Cena"))
            context.insert(SplitShare(memberID: "m1", amount: 100, groupZoneID: z))
            context.insert(SplitSettlement(groupZoneID: z, fromMemberID: "m1", toMemberID: "m2", amount: 100))
        }
        try context.save()
        return group
    }

    private func counts(
        _ context: ModelContext, zone: String
    ) throws -> (groups: Int, members: Int, expenses: Int, shares: Int, settlements: Int) {
        (
            try context.fetchCount(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zone }))
        )
    }

    // MARK: - Decisión pura (ANY-row)

    /// La unidad es la ZONA: basta UNA fila del canal backend para que la zona entera sea intocable. Es la
    /// mitad del defecto (2) — el guard viejo leía UNA fila y podía leer la equivocada.
    @Test(arguments: [
        // (filas de la zona, esperado)
        ([(false, false)], false),                 // zona CloudKit pura
        ([(true, false)], true),                   // dueño backend
        ([(false, true)], true),                   // copia congelada del member
        ([(false, false), (true, false)], true),   // DUPLICADO MIXTO: la backend NO es la primera
        ([(true, false), (false, false)], true),   // ...ni depende del orden
        ([], false),                               // zona sin filas: nada que retener
    ])
    func belongsToBackendChannel_isAnyRow(rows: [(Bool, Bool)], expected: Bool) {
        let mapped = rows.map {
            (isBackendGroup: $0.0, movedToBackendAt: $0.1 ? Date(timeIntervalSince1970: 1) : nil)
        }
        #expect(GroupZoneCacheGate.belongsToBackendChannel(rowsInZone: mapped) == expected)
    }

    // MARK: - Barrido

    /// Caso sano: zona 100 % CloudKit ⇒ se borra entera, grupo y las cuatro clases de hijas.
    @Test func deleteCache_cloudKitZone_wipesGroupAndAllChildren() throws {
        let context = try makeContext()
        let zone = try seed(in: context, name: "Viaje").cloudKitZoneID

        let result = GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(result == .init(groups: 1, members: 1, shares: 1, expenses: 1, settlements: 1, partial: false))
        let after = try counts(context, zone: zone)
        #expect(after == (0, 0, 0, 0, 0))
    }

    /// **La aserción que carga el peso del defecto (1).** Una fila born-remote nace con `SplitGroup()` (id
    /// fresco) y el `cloudKitZoneID` PISADO por el `group_id` del server ⇒ `id` y zona divergen. El barrido
    /// viejo buscaba el grupo por `id == UUID(zona)` y no lo encontraba: borraba las hijas y dejaba la fila
    /// del grupo viva. No es «huérfanas» —que es como lo describían la regla y el índice—: es un CASCARÓN.
    ///
    /// MUTACIÓN: devolver el fetch del grupo a `#Predicate { $0.id == groupID }` deja `groups == 0` y el
    /// `fetchCount` de `SplitGroup` en 1 ⇒ dos aserciones en rojo.
    @Test func deleteCache_rowWhoseIDDoesNotMatchItsZone_isStillDeleted() throws {
        let context = try makeContext()
        // Molde `GroupsSyncClient.applyGroupMeta`: id fresco + zona del server encima.
        let zone = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"
        let group = try seed(in: context, name: "Born-remote", zone: zone)
        try #require(zone != SplitGroupZone.zoneName(for: group.id),
                     "fixture inválido: la zona tiene que diferir de la derivación del id")

        let result = GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(result.groups == 1, "la fila del grupo tiene que morir con sus hijas, o queda un cascarón")
        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    /// Zona con DUPLICADO homogéneo: mueren las DOS filas. El barrido viejo usaba `.first` sobre el fetch
    /// por `id`, así que como mucho podía llevarse una.
    ///
    /// MUTACIÓN: cambiar el bucle por `if let group = groups.first` deja `groups == 1` y una fila viva.
    @Test func deleteCache_duplicateRowsInZone_deletesAllOfThem() throws {
        let context = try makeContext()
        let zone = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"
        try seed(in: context, name: "Canónico", zone: zone)
        try seed(in: context, name: "Duplicado", zone: zone, withChildren: false)
        try #require(try counts(context, zone: zone).groups == 2)

        let result = GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(result.groups == 2)
        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    /// **La aserción que carga el peso del defecto (2), y el escenario que costó el hallazgo.** Duplicado
    /// MIXTO: la fila backend NO es la más antigua, que es justo lo que `GroupService.group(for:)`
    /// (`sortBy createdAt` ASC, `results.first`) devolvía al guard ⇒ no disparaba. Con la fila backend viva
    /// y las hijas muertas bajo el autor por defecto, la zona seguía en `backendZoneIDs` y el drain emitía
    /// tombstones de `split_expenses`/`split_shares`/`split_settlements` al servidor.
    ///
    /// MUTACIÓN: volver a decidir con UNA sola fila (p. ej. `rowsInZone.first.map { … } ?? false`) deja las
    /// cuatro aserciones de supervivencia en rojo.
    @Test func deleteCache_mixedDuplicate_backendRowIsNewer_zoneIsUntouched() throws {
        let context = try makeContext()
        let zone = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        try seed(in: context, name: "CloudKit (más vieja)", zone: zone, createdAt: old)
        try seed(in: context, name: "Backend (más nueva)", zone: zone, isBackendGroup: true,
                 createdAt: old.addingTimeInterval(60), withChildren: false)
        // Precondición del escenario: el criterio VIEJO habría elegido la NO-backend.
        let byCreatedAt = try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zone },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        try #require(byCreatedAt.first?.isBackendGroup == false, "fixture inválido: la más vieja debe ser la NO-backend")

        #expect(GroupZoneCacheGate.classify(zoneName: zone, context: context) == .backendZone)
        let result = GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(result == .init(), "una zona con CUALQUIER fila backend es intocable")
        #expect(try counts(context, zone: zone) == (2, 1, 1, 1, 1))
    }

    /// El mismo par, con el orden inverso de `createdAt`: sigue intocable. Sin este control el test de
    /// arriba probaría «gana la más nueva» en vez de «gana cualquiera».
    @Test func deleteCache_mixedDuplicate_backendRowIsOlder_zoneIsUntouched() throws {
        let context = try makeContext()
        let zone = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        try seed(in: context, name: "Backend (más vieja)", zone: zone, isBackendGroup: true, createdAt: old)
        try seed(in: context, name: "CloudKit (más nueva)", zone: zone,
                 createdAt: old.addingTimeInterval(60), withChildren: false)

        GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(try counts(context, zone: zone) == (2, 1, 1, 1, 1))
    }

    /// La copia CONGELADA del member (`movedToBackendAt != nil`, `isBackendGroup == false`) también retiene:
    /// porta el token del CTA de re-join y borrarla deja al humano fuera sin camino de vuelta.
    @Test func deleteCache_frozenCopy_isUntouched() throws {
        let context = try makeContext()
        let zone = try seed(in: context, name: "Congelado",
                            movedToBackendAt: Date(timeIntervalSince1970: 1_700_000_000)).cloudKitZoneID

        #expect(GroupZoneCacheGate.classify(zoneName: zone, context: context) == .backendZone)
        GroupZoneCacheGate.deleteCache(zoneName: zone, context: context)
        try context.save()

        #expect(try counts(context, zone: zone) == (1, 1, 1, 1, 1))
    }

    /// Zona sin ninguna fila local: `.cloudKitZone` (no hay nada que retener) y el barrido es un no-op
    /// silencioso. Es el caso normal cuando el camino LOCAL ya limpió antes de que llegue el evento.
    @Test func deleteCache_unknownZone_isANoOp() throws {
        let context = try makeContext()
        let other = try seed(in: context, name: "Otra").cloudKitZoneID
        let ghost = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"

        #expect(GroupZoneCacheGate.classify(zoneName: ghost, context: context) == .cloudKitZone)
        #expect(GroupZoneCacheGate.deleteCache(zoneName: ghost, context: context) == .init())
        try context.save()
        #expect(try counts(context, zone: other) == (1, 1, 1, 1, 1), "la zona vecina no se toca")
    }

    /// Aislamiento: el barrido está acotado a SU zona. Sin esto, un `#Predicate` mal escrito pasaría todos
    /// los tests de arriba mientras vacía el resto del store.
    @Test func deleteCache_doesNotTouchOtherZones() throws {
        let context = try makeContext()
        let target = try seed(in: context, name: "Objetivo").cloudKitZoneID
        let bystander = try seed(in: context, name: "Vecina").cloudKitZoneID

        GroupZoneCacheGate.deleteCache(zoneName: target, context: context)
        try context.save()

        #expect(try counts(context, zone: target) == (0, 0, 0, 0, 0))
        #expect(try counts(context, zone: bystander) == (1, 1, 1, 1, 1))
    }
}

/// Cableado de producción (source-scan). `deleteGroupCache` es `private` sobre un singleton con CKSyncEngine
/// vivo y sus dos handlers reciben eventos de `CKSyncEngine` SIN init público: la lógica de arriba puede ser
/// perfecta y sus tests verdes mientras nadie la invoca donde hace falta. Mismo patrón y misma razón que
/// `AttestWiringTests` / `GroupInviteChannelRoutingWiringTests` / `GroupsIdentityPurgeWiringTests`.
@MainActor
@Suite("Caché de zona · cableado de producción (source-scan)")
struct GroupZoneCacheGateWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    // Los TRES source-scans de este fichero — `zoneDeletionPaths_decideThroughTheZoneGate`,
    // `theTwoZoneSweeps_keyOnTheEventZone_neverOnTheIDDerivation` y `theGateRunsBeforeTheSweep_inBothHandlers`
    // — RETIRADOS en la Fase 3. Anclaban en los cuerpos de `handleFetchedDatabaseChanges` y
    // `handleZoneNotFound` de `SplitSyncManager`, y en `deleteGroupCache`/`reuploadGroupRecords`. El commit 1
    // borró ese fichero: sus tres sujetos ya no existen, y un source-scan sobre un fichero borrado LANZA en
    // runtime sin romper la compilación (la familia de «Executed 0 tests»), así que retirarlos aquí no es
    // adelantar trabajo de B2: es no dejar tres rojos mudos.
    //
    // **Lo que esto deja huérfano, declarado:** `GroupZoneCacheGate.classify` y `.deleteCache` pierden TODOS
    // sus call-sites de producción. El fichero NO se borra porque `belongsToBackendChannel` sobrevive y tiene
    // consumidores vivos (`GroupChannelFreshness`, `GroupsSyncClient`), y sus tests de comportamiento —los de
    // arriba, que son la mayoría de este fichero— siguen siendo la red de ese predicado.
}
