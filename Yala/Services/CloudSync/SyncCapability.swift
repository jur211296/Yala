//
//  SyncCapability.swift
//  Yala
//
//  Qué versión del `capability_manifest.json` habla este teléfono con el backend del Modo Nube. Nació con la
//  primera columna personal añadida después del lanzamiento (`accounts.parent_account_id`, tarjeta con varias
//  divisas, 2026-10-18) y sirve para todas las que vengan.
//
//  EL PROBLEMA QUE CIERRA. El Worker rechaza la fila ENTERA si trae una columna que no conoce
//  (`unknown_column`, `gateway/src/sync/manifest.ts`), y el Merkle serializa un NULL como `key:null`
//  (`gateway/src/sync/canon.ts`). Así que una columna nueva rompe dos cosas según quién vaya por delante:
//   - app nueva con un Worker viejo: cada alta de cuenta rechazada, y el Merkle de `accounts` divergente;
//   - Worker nuevo con la app vieja (2.1 en la calle manda `v1`): el Merkle de `accounts` divergente en cada
//     teléfono, para siempre.
//  Por eso cada columna lleva en el manifest desde qué versión existe (`since`), el Worker proyecta `vN` sin las
//  posteriores y ANUNCIA su `manifest_version` en el pull y en el Merkle, y este teléfono declara el MENOR entre
//  lo que entiende y lo que el backend anunció. Ningún build escribe una columna antes de que el backend la
//  conozca, publique quien publique primero.
//
//  LA SUBIDA DE VERSIÓN NO ES GRATIS, y su manejo vive en `CloudSyncEngine.applyCapabilityUpgradeIfPending`
//  (lo corre el bucle del pull). Mientras se hablaba `v1`, (a) lo que bajó llegó SIN la columna nueva, y (b) lo que
//  este teléfono cambió en ella no subió. Al subir: primero se encola lo de (b) —solo esas cuentas, apuntadas aquí
//  por quien filtró la columna (`noteSuppressedAccountLink`)—, para que el guard del apply las proteja; después se
//  re-baja todo desde 0 con la versión nueva, que repone (a). Reemitir a ciegas «toda cuenta con enlace» subiría
//  con un HLC fresco copias viejas de lo que otro teléfono ya cambió (lo cazó la review).
//
//  QUIÉN LO LEE: `DeltaEmitter` (qué columnas emite), `SyncMerkle` (qué columnas hashea, y con qué cabecera
//  pregunta), `SyncPullClient` (la cabecera del pull). QUIÉN ESCRIBE la versión: el pull y el Merkle, con lo que
//  anuncia el backend. Una respuesta SIN `manifest_version` es un Worker anterior a esto: cuenta como 1, también
//  tras un rollback.
//
//  Es del TELÉFONO, no de la cuenta: el Worker es el mismo para todas. `cloudSync.*` sobrevive al cierre de
//  sesión a propósito (lo excluye `removeUserPreferenceKeys`). `nonisolated`: lo leen argumentos por defecto de
//  funciones no aisladas; `UserDefaults` es seguro entre hilos.
//

import Foundation

nonisolated enum SyncCapability {

    /// La versión del manifest que este build entiende. Súbela SOLO junto con la columna que la estrena.
    static let clientManifestVersion = 3

    /// Versión del manifest que estrena `accounts.parent_account_id`.
    static let accountLinksSince = 2

    /// Versión del manifest que estrena `cashflow_lines.amount_changes_raw` (UX 2.2 · L18-8: los cambios de monto «desde
    /// este mes» de una línea del flujo de caja).
    static let cashFlowAmountChangesSince = 3

    static let backendManifestVersionKey = "cloudSync.backendManifestVersion"
    static let lastDeclaredLevelKey = "cloudSync.lastDeclaredLevel"
    static let upgradePendingKey = "cloudSync.capabilityUpgradePending"
    static let suppressedAccountLinksKey = "cloudSync.accountLinksSuppressed"
    static let suppressedCashFlowAmountChangesKey = "cloudSync.cashFlowAmountChangesSuppressed"

    /// Bajo tests NUNCA `.standard`: el host es la app del simulador y un valor de una suite se leería luego en
    /// una corrida a mano. Inyectable (los tests que lo fijan lo restauran en `defer`).
    nonisolated(unsafe) static var defaults: UserDefaults = SyncCapability.makeDefaults()

    /// Lo último que anunció el backend; 1 si nunca anunció nada.
    static var backendManifestVersion: Int {
        max(1, defaults.integer(forKey: backendManifestVersionKey))
    }

    /// La versión con la que este teléfono habla ahora: la menor de las dos.
    static var declaredLevel: Int { min(clientManifestVersion, backendManifestVersion) }

    /// Cabecera `X-Yala-Capability-Set` de una versión (`v1`, `v2`…).
    static func header(forLevel level: Int) -> String { "v\(level)" }

    static var declaredHeader: String { header(forLevel: declaredLevel) }

    /// Apunta lo que anunció el backend. `nil` = un Worker que no anuncia (anterior a esto) = 1. Si con esto el
    /// teléfono PASA a hablar una versión más alta —cualquiera: cada versión estrena columnas—, deja pedida la subida
    /// (`upgradePending`): la cumple el bucle del pull antes de aplicar nada más. Hasta 2026-10-21 solo la pedía al
    /// cruzar la de los enlaces de tarjeta (v2); con la v3 (cambios de monto del flujo de caja) el cruce de v2 a v3
    /// también deja columnas que bajaron sin ella y cambios que no subieron.
    ///
    /// «Antes» es lo que el teléfono DECLARÓ la última vez que apuntó (`lastDeclaredLevelKey`), no lo que declararía
    /// este build con la versión de antes: la versión también sube al ACTUALIZAR LA APP, sin que el backend cambie, y
    /// recalculado con el build nuevo el «antes» ya valía la versión nueva y nadie pedía la subida (lo cazó la review
    /// del 2026-10-21). Sin apunte —un build anterior a esto— se supone que el build de antes hablaba una versión
    /// menos: pedir la subida de más solo vuelve a bajar desde 0.
    static func recordBackendManifestVersion(_ advertised: Int?) {
        let before = (defaults.object(forKey: lastDeclaredLevelKey) as? Int)
            ?? min(clientManifestVersion - 1, backendManifestVersion)
        let value = max(1, advertised ?? 1)
        if defaults.integer(forKey: backendManifestVersionKey) != value {
            defaults.set(value, forKey: backendManifestVersionKey)
        }
        let now = declaredLevel
        if now > before && now >= accountLinksSince {
            defaults.set(true, forKey: upgradePendingKey)
            CloudSyncBreadcrumb.capabilityUpgraded(from: before, to: now)
        }
        if (defaults.object(forKey: lastDeclaredLevelKey) as? Int) != now {
            defaults.set(now, forKey: lastDeclaredLevelKey)
        }
    }

    /// Hay una subida de versión sin cumplir: reemitir lo apuntado y re-bajar desde 0.
    static var upgradePending: Bool {
        get { defaults.bool(forKey: upgradePendingKey) }
        set {
            if newValue { defaults.set(true, forKey: upgradePendingKey) }
            else { defaults.removeObject(forKey: upgradePendingKey) }
        }
    }

    /// La subida está pedida Y el teléfono ya habla una versión que conoce los enlaces. Con la petición puesta pero
    /// la versión vuelta atrás (un rollback del Worker entre medias) no hay nada que cumplir todavía: sin este
    /// segundo término, el bucle del pull esperaría para siempre a una subida que no puede ocurrir.
    static var upgradeDue: Bool { upgradePending && declaredLevel >= accountLinksSince }

    // MARK: - Enlaces que no subieron

    /// Las cuentas (por `shortcutID`) cuyo enlace este teléfono cambió o subió mientras hablaba una versión que no
    /// lo conoce: la emisión quitó la columna y el servidor no lo tiene.
    static var suppressedAccountLinks: Set<UUID> {
        Set((defaults.stringArray(forKey: suppressedAccountLinksKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    /// Lo llama quien filtró `parent_account_id` por la versión (el drain en un cambio, `DeltaEmitter` en una fila
    /// entera con enlace). Apuntar de más es inocuo: la reemisión sube el valor de ese momento.
    static func noteSuppressedAccountLink(_ shortcutID: UUID) {
        var current = suppressedAccountLinks
        guard current.insert(shortcutID).inserted else { return }
        defaults.set(current.map(\.uuidString).sorted(), forKey: suppressedAccountLinksKey)
    }

    /// Retira las que ya se encolaron. Solo esas: una que se apuntó mientras tanto se queda para la siguiente.
    static func clearSuppressedAccountLinks(_ shortcutIDs: Set<UUID>) {
        let remaining = suppressedAccountLinks.subtracting(shortcutIDs)
        if remaining.isEmpty { defaults.removeObject(forKey: suppressedAccountLinksKey) }
        else { defaults.set(remaining.map(\.uuidString).sorted(), forKey: suppressedAccountLinksKey) }
    }

    // MARK: - Cambios de monto del flujo de caja que no subieron (v3)

    /// Las líneas del flujo de caja (por `id`) cuyos cambios «desde este mes» este teléfono cambió o subió mientras
    /// hablaba una versión que no conoce la columna: la emisión la quitó y el servidor no la tiene.
    static var suppressedCashFlowAmountChanges: Set<UUID> {
        Set((defaults.stringArray(forKey: suppressedCashFlowAmountChangesKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    /// Lo llama quien filtró `amount_changes_raw` por la versión. Apuntar de más es inocuo: la reemisión sube el valor
    /// de ese momento.
    static func noteSuppressedCashFlowAmountChange(_ lineID: UUID) {
        var current = suppressedCashFlowAmountChanges
        guard current.insert(lineID).inserted else { return }
        defaults.set(current.map(\.uuidString).sorted(), forKey: suppressedCashFlowAmountChangesKey)
    }

    /// Retira las que ya se encolaron. Solo esas: una que se apuntó mientras tanto se queda para la siguiente.
    static func clearSuppressedCashFlowAmountChanges(_ lineIDs: Set<UUID>) {
        let remaining = suppressedCashFlowAmountChanges.subtracting(lineIDs)
        if remaining.isEmpty { defaults.removeObject(forKey: suppressedCashFlowAmountChangesKey) }
        else { defaults.set(remaining.map(\.uuidString).sorted(), forKey: suppressedCashFlowAmountChangesKey) }
    }

    private static func makeDefaults() -> UserDefaults {
        let isRunningTests = ProcessInfo.processInfo.environment["YALA_TEST_MODE"] == "1"
            || NSClassFromString("XCTestObservationCenter") != nil
        guard isRunningTests else { return .standard }
        let suite = "yala.tests.syncCapability"
        let testDefaults = UserDefaults(suiteName: suite) ?? .standard
        testDefaults.removePersistentDomain(forName: suite)
        return testDefaults
    }
}
