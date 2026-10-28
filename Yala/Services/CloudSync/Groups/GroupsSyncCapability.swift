//
//  GroupsSyncCapability.swift
//  Yala
//
//  Qué versión del `group_capability_manifest.json` habla este teléfono con el canal de GRUPOS. Gemelo de
//  `SyncCapability` (canal personal), con su propio manifest, su propia versión y su propio nivel por defecto. Nació
//  el 2026-10-24 con el ticket `groups-canal-sin-capability-set`.
//
//  EL PROBLEMA QUE CIERRA. Hasta ese día el canal de Grupos no declaraba su versión de columnas: el cliente no mandaba
//  `X-Yala-Capability-Set` y el Worker hasheaba en el Merkle TODAS las columnas del manifest (`merkleColumnsGroup`).
//  Como el canon serializa un NULL como `key:null`, una columna nueva cambiaba la hoja de CADA fila de un teléfono
//  que no la conocía: divergencia falsa en el 100 % de sus grupos, con su reset de cursores y su re-pull. La primera
//  columna nueva (`split_groups.budget_limit_amount`, g14_01) lo esquivó subiendo `canon_version` a `c2`, que apagó
//  el Merkle de Grupos a todo el parque viejo. Desde aquí, como en el personal: cada columna lleva en el manifest
//  desde qué versión existe (`since`), el Worker proyecta `vN` sin las posteriores en el pull y en el Merkle y
//  ANUNCIA su `manifest_version`, y este teléfono declara la MENOR entre lo que entiende y lo que el Worker anunció.
//
//  LA DIFERENCIA CON EL PERSONAL: SIN ANUNCIO = 2, NO 1. Un Worker anterior a esto no anuncia nada y ya conocía el
//  presupuesto (g14_01 se desplegó el 2026-09-07), y el gateway trata la AUSENCIA de la cabecera como v2 por lo
//  mismo (`GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER`, `gateway/src/groups/manifest.ts`). Leerlo como 1 haría que este
//  teléfono, contra ese Worker, hashease sin el presupuesto mientras el Worker lo hashea con él.
//
//  LAS CUATRO PIEZAS DE LA PRÓXIMA COLUMNA (card u8cl, 2026-10-28). Hoy el nivel declarado es siempre 2 (el cliente
//  entiende 2 y todo Worker que exista anuncia 2 o no anuncia), así que ninguna muerde todavía. Están puestas para que
//  la primera columna con `since: 3` solo tenga que declararse en `columnSince` y en el manifest:
//   1. La EMISIÓN del drain sale de aquí (`emission(_:upTo:)`) y `DeltaEmitter.emit` recibe
//      `capabilityLevel: declaredLevel`: sin eso tomaba `SyncCapability.declaredLevel`, el nivel del canal PERSONAL, y
//      una columna nueva dejaba de subir en todo teléfono cuyo canal personal declara 1. El `since` de Grupos sigue
//      viviendo en `columnSince` y no en el `ColumnEmitter` (lo exige `GroupsCapabilityManifestParityTests`).
//   2. La SUBIDA de versión, molde `applyCapabilityUpgradeIfPending` del personal: lo que el drain no pudo subir se
//      apunta (`noteSuppressed`) y, al cruzar de versión (`recordBackendManifestVersion` deja pedida la subida), el
//      ciclo siguiente lo re-encola y vuelve a bajar desde 0 los grupos que hay aquí
//      (`GroupsSyncClient.applyCapabilityUpgradeIfPending`).
//   3. El GUARD DE DESPLIEGUE mira también el manifest de Grupos (`gateway/scripts/check-manifest-not-older.mjs`).
//   4. La PODA es por grupo de coherencia entero, como la del Worker (`droppedGroupsFor`): `keptColumns(of:level:)`, la
//      misma función para lo que viaja y lo que se hashea. Columna a columna, la primera `since: 3` dentro de un grupo
//      dejaba el Merkle local con media unidad y el remoto sin ella.
//
//  ⚠️ LA TRAMPA QUE CERRÓ LA PIEZA 1, para quien vuelva a tocar el drain: `DeltaEmitter.emit` tiene por defecto
//  `capabilityLevel: SyncCapability.declaredLevel`, el nivel del canal PERSONAL. Un `emit` de Grupos sin ese argumento
//  vuelve a la trampa.
//
//  QUIÉN LO LEE: `GroupsSyncClient` (cabecera del pull), `GroupsMerkleClient` (cabecera del Merkle) y
//  `GroupMerkleProjection` (qué columnas hashea). QUIÉN ESCRIBE lo anunciado: el pull y el Merkle de Grupos.
//
//  Es del TELÉFONO, no de la cuenta: el Worker es el mismo para todas. `nonisolated`: lo leen argumentos por defecto;
//  `UserDefaults` es seguro entre hilos.
//

import Foundation
import os

nonisolated enum GroupsSyncCapability {

    /// La versión del manifest de Grupos que este build entiende. Súbela SOLO junto con la columna que la estrena.
    static let clientManifestVersion = 2

    /// Versión del manifest de Grupos que estrena `split_groups.budget_limit_amount` (g14_01).
    static let budgetLimitSince = 2

    /// `since` de cada columna de Grupos posterior a la v1, por tabla (las que no están, 1). Espejo del `since` de
    /// `group_capability_manifest.json`, y `GroupsCapabilityManifestParityTests` exige que casen columna a columna.
    /// Vive aquí y no en el `ColumnEmitter`: ver la trampa de la cabecera.
    static let columnSince: [String: [String: Int]] = [
        "split_groups": ["budget_limit_amount": budgetLimitSince],
    ]

    /// `since` de una columna de Grupos (1 si no figura en `columnSince`).
    static func since(table: String, column: String) -> Int { columnSince[table]?[column] ?? 1 }

    /// Nivel que se supone a un Worker que no anuncia `manifest_version` en el canal de Grupos: todos los desplegados
    /// antes de esto ya conocían el presupuesto. Espejo de `GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER` del gateway.
    static let levelWhenUnannounced = 2

    static let backendManifestVersionKey = "groupsSync.backendManifestVersion"

    /// Bajo tests NUNCA `.standard`: el host es la app del simulador. Inyectable (los tests lo restauran en `defer`).
    nonisolated(unsafe) static var defaults: UserDefaults = GroupsSyncCapability.makeDefaults()

    /// Lo último que anunció el Worker; `levelWhenUnannounced` si nunca anunció nada (o el último no anunciaba).
    static var backendManifestVersion: Int {
        let stored = defaults.integer(forKey: backendManifestVersionKey)
        return stored > 0 ? stored : levelWhenUnannounced
    }

    /// La versión con la que este teléfono habla ahora: la menor de las dos.
    static var declaredLevel: Int { declaredLevel(client: clientManifestVersion, backend: backendManifestVersion) }

    /// La decisión, pura: la menor entre lo que entiende el cliente y lo que anunció el Worker, nunca por debajo de 1.
    static func declaredLevel(client: Int, backend: Int) -> Int { max(1, min(client, backend)) }

    /// Cabecera `X-Yala-Capability-Set` de una versión (`v1`, `v2`…). Mismo formato que el canal personal.
    static func header(forLevel level: Int) -> String { "v\(level)" }

    static var declaredHeader: String { header(forLevel: declaredLevel) }

    private static let logger = Logger(subsystem: "com.yala", category: "GroupsSync")

    static let lastDeclaredLevelKey = "groupsSync.lastDeclaredLevel"
    static let upgradePendingLevelKey = "groupsSync.capabilityUpgradePendingLevel"
    static let suppressedRowsKey = "groupsSync.suppressedColumns"

    /// Apunta lo que anunció el Worker. `nil` = un Worker que no anuncia (anterior a esto, o tras un rollback): se
    /// borra la clave y vale `levelWhenUnannounced`. Un valor menor que 1 se lee como 1.
    ///
    /// Card u8cl (pieza 2): si con esto el teléfono PASA a hablar una versión más alta, deja pedida la subida
    /// (`upgradeDue`). «Antes» es lo que DECLARÓ la última vez (`lastDeclaredLevelKey`), no lo que declararía este build:
    /// la versión también sube al actualizar la app con el Worker ya por delante (la lección de la v3 del personal). Sin
    /// apunte —un build anterior a esto— vale `levelWhenUnannounced`: todo build hasta hoy declaró 2, y suponer menos
    /// pediría a todo el parque volver a bajar sus grupos desde 0 por nada.
    static func recordBackendManifestVersion(_ advertised: Int?) {
        let before = (defaults.object(forKey: lastDeclaredLevelKey) as? Int) ?? levelWhenUnannounced
        if let advertised {
            let value = max(1, advertised)
            if defaults.integer(forKey: backendManifestVersionKey) != value {
                defaults.set(value, forKey: backendManifestVersionKey)
            }
        } else if defaults.object(forKey: backendManifestVersionKey) != nil {
            defaults.removeObject(forKey: backendManifestVersionKey)
        }
        let now = declaredLevel
        if now > before {
            let pending = (defaults.object(forKey: upgradePendingLevelKey) as? Int) ?? 0
            if now > pending { defaults.set(now, forKey: upgradePendingLevelKey) }
            // Rastro aquí y no en `GroupsSyncBreadcrumb`, que es del main actor: esto lo llaman argumentos por defecto.
            logger.notice("GroupsSync capabilityUpgraded from=\(before, privacy: .public) to=\(now, privacy: .public)")
        }
        if (defaults.object(forKey: lastDeclaredLevelKey) as? Int) != now {
            defaults.set(now, forKey: lastDeclaredLevelKey)
        }
    }

    // MARK: - Pieza 2 · la subida de versión

    /// La versión a la que se pidió subir, o `nil` si no hay subida pedida.
    static var upgradePendingLevel: Int? { defaults.object(forKey: upgradePendingLevelKey) as? Int }

    /// Hay una subida pedida Y el teléfono ya habla esa versión. Con la petición puesta y el Worker vuelto atrás entre
    /// medias no hay nada que cumplir todavía: la petición espera, sin bloquear el ciclo.
    static var upgradeDue: Bool { upgradePendingLevel.map { declaredLevel >= $0 } ?? false }

    /// Retira la petición, solo si sigue siendo la que se cumplió: una más alta pedida entre medias se queda.
    static func clearUpgrade(level: Int) {
        guard let pending = upgradePendingLevel, pending <= level else { return }
        defaults.removeObject(forKey: upgradePendingLevelKey)
    }

    /// Una fila cuyo cambio el drain no pudo subir entero: llevaba columnas que la versión que habla el teléfono aún no
    /// conoce. `ownerUserID` es el dueño que el drain le dio a la fila (`GroupsOutboxOwnershipLogic`): la re-emisión sale
    /// con él, y una fila de otra cuenta se queda retenida como cualquier otra.
    struct SuppressedRow: Codable, Equatable, Sendable {
        let entityType: String
        let syncID: UUID
        let groupID: String
        let ownerUserID: String?
        let columns: [String]

        var key: String { "\(entityType)|\(syncID.uuidString)" }
    }

    /// Lo apuntado, por `entityType|syncID`.
    static var suppressedRows: [String: SuppressedRow] {
        guard let data = defaults.data(forKey: suppressedRowsKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: SuppressedRow].self, from: data)
        } catch {
            #if DEBUG
            print("GroupsSyncCapability: Error decoding suppressed rows: \(error)")
            #endif
            return [:]
        }
    }

    /// Lo llama el drain cuando filtra por la versión una columna con valor. Apuntar de más es inocuo: la re-emisión sube
    /// el valor de ese momento. Dos cambios de la misma fila juntan sus columnas.
    static func noteSuppressed(entityType: String, syncID: UUID, groupID: String, ownerUserID: String?,
                               columns: Set<String>) {
        guard !columns.isEmpty else { return }
        var rows = suppressedRows
        let key = SuppressedRow(entityType: entityType, syncID: syncID, groupID: groupID, ownerUserID: ownerUserID,
                                columns: []).key
        let merged = Set(rows[key]?.columns ?? []).union(columns).sorted()
        let row = SuppressedRow(entityType: entityType, syncID: syncID, groupID: groupID,
                                ownerUserID: ownerUserID ?? rows[key]?.ownerUserID, columns: merged)
        guard rows[key] != row else { return }
        rows[key] = row
        persistSuppressed(rows)
    }

    /// Retira lo que ya se re-encoló. Solo si no cambió entre medias: lo apuntado después se queda para la siguiente.
    static func clearSuppressed(_ reemitted: [SuppressedRow]) {
        var rows = suppressedRows
        for row in reemitted where rows[row.key] == row { rows.removeValue(forKey: row.key) }
        persistSuppressed(rows)
    }

    private static func persistSuppressed(_ rows: [String: SuppressedRow]) {
        guard !rows.isEmpty else {
            defaults.removeObject(forKey: suppressedRowsKey)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(rows), forKey: suppressedRowsKey)
        } catch {
            #if DEBUG
            print("GroupsSyncCapability: Error encoding suppressed rows: \(error)")
            #endif
        }
    }

    // MARK: - Piezas 1 y 4 · qué columnas viajan y se hashean

    /// Las columnas de `emission` que existen en la versión `level` del manifest de Grupos, **por grupo de coherencia
    /// entero**: si una columna de un grupo no existe aún, el grupo entero se queda fuera. Espejo de `groupColumnsUpTo`
    /// + `droppedGroupsFor` del Worker (`gateway/src/groups/manifest.ts`). La usan la emisión del drain y la hoja del
    /// Merkle, para que lo que viaja y lo que se hashea sean lo mismo.
    @MainActor
    static func keptColumns<M>(of emission: EntityEmission<M>, level: Int) -> Set<String> {
        keptColumns(table: emission.table, columns: emission.emitters.map { ($0.column, $0.group) }, level: level)
    }

    /// La decisión, pura: columnas con su grupo de coherencia (`nil` = suelta). `since` inyectable para probar una columna
    /// posterior dentro de un grupo, que hoy no existe en el manifest.
    static func keptColumns(
        table: String, columns: [(column: String, group: String?)], level: Int,
        since sinceOf: (String, String) -> Int = { since(table: $0, column: $1) }
    ) -> Set<String> {
        let known = Set(columns.map(\.column).filter { sinceOf(table, $0) <= level })
        let droppedGroups = Set(columns.compactMap { known.contains($0.column) ? nil : $0.group })
        return Set(columns.compactMap { entry in
            guard known.contains(entry.column) else { return nil }
            if let group = entry.group, droppedGroups.contains(group) { return nil }
            return entry.column
        })
    }

    /// La emisión de Grupos de la versión `level`: solo los emisores de `keptColumns`.
    @MainActor
    static func emission<M>(_ emission: EntityEmission<M>, upTo level: Int) -> EntityEmission<M> {
        let kept = keptColumns(of: emission, level: level)
        guard kept.count != emission.emitters.count else { return emission }
        return EntityEmission(table: emission.table, emitters: emission.emitters.filter { kept.contains($0.column) },
                              columnKeyPaths: emission.columnKeyPaths)
    }

    private static func makeDefaults() -> UserDefaults {
        let isRunningTests = ProcessInfo.processInfo.environment["YALA_TEST_MODE"] == "1"
            || NSClassFromString("XCTestObservationCenter") != nil
        guard isRunningTests else { return .standard }
        let suite = "yala.tests.groupsSyncCapability"
        let testDefaults = UserDefaults(suiteName: suite) ?? .standard
        testDefaults.removePersistentDomain(forName: suite)
        return testDefaults
    }
}
