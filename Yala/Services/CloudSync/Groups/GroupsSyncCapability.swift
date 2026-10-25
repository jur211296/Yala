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
//  LO QUE AÚN NO HACE, A PROPÓSITO. Hoy el nivel declarado es siempre 2 (el cliente entiende 2 y todo Worker que
//  exista anuncia 2 o no anuncia), así que no hay subida de versión posible y nada de esto la gestiona. La primera
//  columna con `since: 3` tiene que traer lo que el personal paga en `CloudSyncEngine.applyCapabilityUpgradeIfPending`
//  (regla «Una columna nueva del canal personal…» de `.claude/rules/swiftdata-cloudkit.md`): filtrar la EMISIÓN por
//  `declaredLevel` (hoy `GroupsSyncClient` emite `emission.emitters` enteros), apuntar lo que se filtró y, al subir,
//  re-encolarlo y re-bajar desde 0 lo que bajó sin la columna.
//
//  ⚠️ LA TRAMPA PARA ESA COLUMNA: el `since` de Grupos vive en `columnSince`, NO en el `since` de `ColumnEmitter`.
//  El drain de Grupos llama a `DeltaEmitter.emit` SIN `capabilityLevel`, y ese parámetro tiene por defecto
//  `SyncCapability.declaredLevel`, el nivel del canal PERSONAL (medido el 2026-10-24, `GroupsSyncClient` ~L1393). Un
//  `since: 2` en el emisor del presupuesto le habría quitado la columna a la subida de todo teléfono cuyo canal
//  personal declara 1 (el que no tiene la nube personal, que es casi todo el que usa Grupos). Para usar el `since`
//  del emisor, ese `emit` tiene que pasar antes `capabilityLevel: GroupsSyncCapability.declaredLevel`.
//
//  QUIÉN LO LEE: `GroupsSyncClient` (cabecera del pull), `GroupsMerkleClient` (cabecera del Merkle) y
//  `GroupMerkleProjection` (qué columnas hashea). QUIÉN ESCRIBE lo anunciado: el pull y el Merkle de Grupos.
//
//  Es del TELÉFONO, no de la cuenta: el Worker es el mismo para todas. `nonisolated`: lo leen argumentos por defecto;
//  `UserDefaults` es seguro entre hilos.
//

import Foundation

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

    /// Apunta lo que anunció el Worker. `nil` = un Worker que no anuncia (anterior a esto, o tras un rollback): se
    /// borra la clave y vale `levelWhenUnannounced`. Un valor menor que 1 se lee como 1.
    static func recordBackendManifestVersion(_ advertised: Int?) {
        guard let advertised else {
            if defaults.object(forKey: backendManifestVersionKey) != nil {
                defaults.removeObject(forKey: backendManifestVersionKey)
            }
            return
        }
        let value = max(1, advertised)
        if defaults.integer(forKey: backendManifestVersionKey) != value {
            defaults.set(value, forKey: backendManifestVersionKey)
        }
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
