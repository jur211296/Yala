//
//  GroupRefreshFlagsZoneGateTests.swift
//  YalaTests / CloudSync
//
//  `GroupService.refreshCurrentUserFlags` — el ÚLTIMO «decidir sobre una ZONA mirando UNA sola fila» de la
//  familia (puntos 6 a 13 de `.claude/rules/swiftdata-cloudkit.md`). Complementa a
//  `GroupServiceCurrentUserFlagsTests`, que cubre las cuatro decisiones de 2.6 con UNA fila por zona; esta
//  suite añade la única condición que hace observable el gate: el DUPLICADO.
//
//  El defecto: `refreshCurrentUserFlags` fetchea `SplitGroup` SIN `sortBy` y colapsa con
//  `Dictionary(uniquingKeysWith: { first, _ in first })`, y de esa fila arbitraria salían DOS guards:
//
//   1. `memberIsInBackendChannel`, que gobierna CUATRO decisiones — el `continue` que salta el member sin
//      sesión Yala, el guard del backfill de record-name, la elección de rama de `shouldBeCurrent` y la
//      inferencia local de `isGroupOwner`.
//   2. el guard C-3 del bucle de BACKFILL, que es un defecto HERMANO y PEOR por su forma: ese bucle itera
//      TODAS las filas (`backfillCandidates = allGroups`), así que en una zona mixta visitaba las dos y la
//      gemela NO-backend pasaba el guard ⇒ **no protegía nunca**, no «la mitad de las veces».
//
//  ── ALCANZABILIDAD: ENDURECIMIENTO, no un bug vivo (medido, no inferido) ───────────────────────────────
//  El estado que hace falta —una zona con duplicado MIXTO (una fila del canal backend y otra no)— no tiene
//  productor vivo. Los CUATRO sitios que insertan un `SplitGroup` en producción son `GroupService.createGroup`
//  y `GroupBackendMembershipService.createGroup` (zona recién nacida, no puede colisionar),
//  `GroupsSyncClient.applyGroupMeta` (resuelve por zona, solo inserta si está VACÍA, y su rama `else` voltea
//  TODAS las filas a backend ⇒ es la CURA de la mezcla) y `SplitSyncManager.applyGroupMeta` — el único capaz
//  de parir una fila NO-backend en zona ajena, y hoy cerrado fail-CERRADO por
//  `CloudKitGroupMetaApplyLogic.resolve` → `.skipBackendZone`, que ya está cableado. El productor que sí es
//  alcanzable (la ventana del `await` de `createGroup`, punto 13) produce duplicados HOMOGÉNEOS: las dos
//  filas con `isBackendGroup = true` ⇒ el gate da lo mismo con cualquiera de las dos y no se desarma.
//
//  Se arregla igual, y por la razón del punto 11: **lo que cierra la cadena es la ausencia de un productor,
//  no un guard**, y esa es justo la clase de hipótesis que caduca. Queda vivo el estado mixto LEGACY que ya
//  esté en disco de la ventana de `2efd2929`; lo colapsa el dedup del arranque, pero ese dedup está gateado
//  por quiescencia y tiene UN solo call-site sin reintento ⇒ un arranque no quiescente lo deja toda la sesión.
//
//  Molde: `GroupCloudKitWriteZoneGateTests` y `GroupCreateRaceZoneTests` (comportamiento + source-scan).
//  El entorno (`withIdentity`/`seed`) espeja el de `GroupServiceCurrentUserFlagsTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("GroupService.refreshCurrentUserFlags · el gate de canal decide por ZONA", .serialized)
struct GroupRefreshFlagsZoneGateTests {

    private static let sub = "11111111-1111-1111-1111-111111111111"
    private static let recordNameNow = "_recordNameActual"

    // MARK: - Entorno (molde de GroupServiceCurrentUserFlagsTests)

    private func withIdentity(
        backendEnabled: Bool,
        sub: String?,
        cachedRecordName: String?,
        _ body: () async throws -> Void
    ) async throws {
        let previousProvider = GroupService.backendUserIDProvider
        let previousRecordName = GroupUserIdentityService.shared.cachedRecordName
        GroupService.backendUserIDProvider = { sub }
        GroupUserIdentityService.shared._testSetCachedRecordName(cachedRecordName)
        CloudSyncFlags.groupsBackendEnabled = backendEnabled
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupService.backendUserIDProvider = previousProvider
            GroupUserIdentityService.shared._testSetCachedRecordName(previousRecordName)
        }
        try await body()
    }

    /// Una zona con DOS filas `SplitGroup` — el estado que hace observable el gate. El fixture NO puede
    /// depender de cuál gane el uniquing (fetch sin `sortBy`); lo que se afirma es que el resultado ya no
    /// depende de eso.
    @discardableResult
    private func seedMixedZone(
        in context: ModelContext,
        isOwner: Bool = false,
        memberUserID: String? = nil,
        memberRecordName: String = "",
        isCurrentUser: Bool = false,
        isGroupOwner: Bool = false
    ) throws -> (zone: String, nonBackend: SplitGroup, backend: SplitGroup, member: SplitMember) {
        let nonBackend = SplitGroup(name: "Viaje", isOwner: isOwner)
        nonBackend.createdAt = Date(timeIntervalSince1970: 1_000_000)
        let zone = nonBackend.cloudKitZoneID

        let backend = SplitGroup(name: "Viaje", isOwner: isOwner)
        backend.cloudKitZoneID = zone
        backend.createdAt = Date(timeIntervalSince1970: 2_000_000)
        backend.isBackendGroup = true

        let member = SplitMember(
            groupZoneID: zone,
            displayName: "Yo",
            cloudKitUserRecordID: memberRecordName,
            isGroupOwner: isGroupOwner,
            isCurrentUser: isCurrentUser
        )
        member.userID = memberUserID

        context.insert(nonBackend)
        context.insert(backend)
        context.insert(member)
        try context.save()
        return (zone, nonBackend, backend, member)
    }

    // MARK: - (1) Los tests que NO están aquí, y la medición que los retiró
    //
    // Hubo tres de comportamiento sobre `memberIsInBackendChannel` —member legacy que conserva su flag,
    // gemela CONGELADA, y el `continue` sin sesión Yala— y los tres se RETIRARON tras medir su mutante.
    // Con el gate devuelto a la forma por fila, cuatro corridas del MISMO binario dieron:
    //
    //     corrida 1: legacy ✘ · congelada ✘ · backfill ✘ · sin-sesión ·
    //     corrida 2: legacy ✘ · congelada ·  · backfill ✘ · sin-sesión ✘
    //     corrida 3: legacy ·  · congelada ·  · backfill ✘ · sin-sesión ·
    //     corrida 4: legacy ✘ · congelada ✘ · backfill ·  · sin-sesión ✘
    //
    // Los tres dependen de qué fila gane el `uniquingKeysWith: { first, _ in first }` sobre un fetch SIN
    // `sortBy`, y ese orden no es estable **ni entre ejecuciones del mismo proceso** ⇒ eran flakes
    // disfrazados de pin: pasarían el gate de una sesión y fallarían el de otra. Es la lección del punto 9
    // de `.claude/rules/swiftdata-cloudkit.md`, repetida — y la evidencia empírica de por qué el fix hace
    // falta, porque ese no-determinismo es EXACTAMENTE el bug visto desde el otro lado.
    //
    // El invariante que fijaban lo sostiene `sourceScan_channelPredicateReadsTheWholeZone_notTheUniquedRow`,
    // cuyo rojo es determinista. El del backfill se conserva porque el suyo NO depende del uniquing: ese
    // bucle recorre TODAS las filas, así que la gemela NO-backend pasa su guard siempre — 4/4 abajo.

    // MARK: - (2) El guard C-3 del backfill, el defecto HERMANO

    /// El bucle de backfill itera TODAS las filas, así que en una zona mixta visitaba las dos y la gemela
    /// NO-backend pasaba su guard ⇒ estampaba el record-name igual. Es el caso que C-3 existe para impedir:
    /// el humano NUEVO escribiéndose encima de un member ajeno del grupo anterior.
    ///
    /// MUTACIÓN: devolver el `guard !belongsToBackendChannel(isBackendGroup: group.isBackendGroup, ...)` por
    /// fila → rojo **4 de 4 corridas**, y por construcción: el bucle recorre TODAS las filas, así que la
    /// gemela NO-backend pasa el guard con independencia de qué fila gane el uniquing. Es el ÚNICO test de
    /// comportamiento de esta suite cuyo rojo no depende de un orden no garantizado — ver el bloque (1).
    @Test("Zona MIXTA: el backfill NO estampa el record-name (el guard C-3 protege la zona entera)")
    func mixedZone_backfillNeverStampsRecordName() async throws {
        let context = try makeTestContext()
        // `isCurrentUser` + `cloudKitUserRecordID` vacío es exactamente el candidato del backfill legacy.
        let seeded = try seedMixedZone(
            in: context, memberUserID: nil, memberRecordName: "", isCurrentUser: true)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.cloudKitUserRecordID.isEmpty,
                "El backfill estampó por la gemela NO-backend: es el estampado sobre un member ajeno que C-3 impide.")
    }

    // MARK: - (3) Lo que NO cambia: una fila por zona sigue byte-idéntico

    /// La red de seguridad del fix. Con UNA sola fila por zona el cuantificador no puede cambiar nada, y esa
    /// es la población real de hoy: si algo de esto se moviera, la suite de 2.6 entera estaría midiendo otra
    /// cosa. Se afirma en los dos sentidos (zona backend y zona CloudKit pura).
    @Test("Una sola fila por zona: comportamiento sin cambios en los dos sentidos")
    func singleRowZones_behaveExactlyAsBefore() async throws {
        let context = try makeTestContext()

        // (a) zona backend pura: el member born-backend se enciende por `sub`.
        let backendOnly = SplitGroup(name: "Backend")
        backendOnly.isBackendGroup = true
        let backendMember = SplitMember(groupZoneID: backendOnly.cloudKitZoneID, displayName: "Yo")
        backendMember.userID = Self.sub

        // (b) zona CloudKit pura: el member legacy se enciende por record-name.
        let cloudKitOnly = SplitGroup(name: "CloudKit")
        let cloudKitMember = SplitMember(
            groupZoneID: cloudKitOnly.cloudKitZoneID, displayName: "Yo",
            cloudKitUserRecordID: Self.recordNameNow)

        context.insert(backendOnly)
        context.insert(cloudKitOnly)
        context.insert(backendMember)
        context.insert(cloudKitMember)
        try context.save()

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(backendMember.isCurrentUser, "El canal backend resuelve por sub (2.6).")
        #expect(cloudKitMember.isCurrentUser, "El canal CloudKit sigue resolviendo por record-name.")
    }

    // MARK: - Source-scan (lo que ningún test de comportamiento puede fijar)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func serviceSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/Services/Groups/GroupService.swift"),
            encoding: .utf8)
    }

    /// **El invariante del CUANTIFICADOR.** Los tests de arriba prueban el efecto con un duplicado montado a
    /// mano; este fija que la fuente del predicado es el mapa por zona y NO el diccionario de fila única.
    /// Hace falta porque el mutante «volver a `groupsByZone[...].map { belongsToBackendChannel(...) }`» tiene
    /// una variante que los de comportamiento no distinguen: leer del diccionario y aplicar el OR sobre esa
    /// sola fila da el MISMO resultado en cuanto el uniquing elija la gemela backend, y ese orden no es
    /// estable entre corridas — un test de comportamiento que dependiera de él sería un flake disfrazado de
    /// pin (la lección del punto 9 de la regla).
    ///
    /// MUTACIÓN: sustituir `backendZones.contains(member.groupZoneID)` por la forma vieja → rojo.
    @Test func sourceScan_channelPredicateReadsTheWholeZone_notTheUniquedRow() throws {
        let source = try Self.serviceSource()
        #expect(source.contains("let backendZones: Set<String> = Set(\n                Dictionary(grouping: allGroups, by: \\.cloudKitZoneID)"),
                "el mapa de zonas del canal dejó de agruparse por cloudKitZoneID")
        #expect(source.contains("GroupZoneCacheGate.belongsToBackendChannel(\n                            rowsInZone: rows.map { ($0.isBackendGroup, $0.movedToBackendAt) })"),
                "el predicado por zona dejó de usar el helper ANY-row, o perdió movedToBackendAt")
        #expect(source.contains("let memberIsInBackendChannel = backendZones.contains(member.groupZoneID)"),
                "el gate del member volvió a resolver por una fila")
        #expect(!source.contains("groupsByZone[member.groupZoneID].map {"),
                "volvió el predicado de canal calculado sobre la fila del uniquing")
    }

    /// Los DOS guards leen la MISMA fuente. Es lo que impide el estado que este fix encontró: dos respuestas
    /// distintas a la misma pregunta —«¿esta zona es del canal backend?»— dentro de la misma función, una por
    /// fila del iterador y otra por la fila del uniquing.
    ///
    /// MUTACIÓN: devolver el guard del backfill a `belongsToBackendChannel(isBackendGroup: group...)` → rojo.
    @Test func sourceScan_bothGuardsShareOneSourceOfTruth() throws {
        let source = try Self.serviceSource()
        #expect(source.contains("guard !backendZones.contains(group.cloudKitZoneID) else { continue }"),
                "el guard C-3 del backfill volvió a preguntar por la fila del iterador")
        // Dos consumidores del Set y ni uno más: un tercero que no pase por aquí sería otra fuente.
        #expect(source.components(separatedBy: "backendZones.contains(").count - 1 == 2,
                "cambió el número de consumidores de backendZones: ¿el nuevo decide por zona?")
        // Cero llamadas por fila al predicado dentro de esta función. Fuera de ella siguen siendo legítimas.
        let scope = try #require(source.range(of: "func refreshCurrentUserFlags("))
        let body = String(source[scope.lowerBound...].prefix(9000))
        #expect(!body.contains("GroupBackendIdentityLogic.belongsToBackendChannel(\n                    isBackendGroup: group.isBackendGroup"),
                "reapareció el predicado de canal evaluado sobre una fila suelta")
    }

    /// `groupsByZone` se conserva A PROPÓSITO para sus otros dos usos, y eso también es un invariante: nadie
    /// debe «terminar el trabajo» fusionando `isOwner` por zona. Es una credencial que HABILITA (permite
    /// inferir `isGroupOwner` y encolar a CKSyncEngine), y el criterio del punto 11 dice que esas no se
    /// heredan al colapsar filas — solo lo que RESTRINGE.
    ///
    /// MUTACIÓN: cambiar `group.isOwner` por un `anyRowIsOwner` → rojo.
    @Test func sourceScan_ownerCredentialStaysPerRow() throws {
        let source = try Self.serviceSource()
        #expect(source.contains("let group = groupsByZone[member.groupZoneID],\n                   group.isOwner,"),
                "isOwner dejó de leerse por fila: una credencial que habilita no se fusiona por zona")
        #expect(source.contains("uniquingKeysWith: { first, _ in first }"),
                "desapareció groupsByZone, que sigue sirviendo al enqueueSave y a la inferencia de rol")
    }
}
