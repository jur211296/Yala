//
//  ICloudPersonalCorpusProbe.swift
//  Yala
//
//  Paso 4 del rediseño de sesiones · **preguntarle a iCloud qué hay ANTES de montarle el espejo encima.**
//
//  El problema que resuelve, medido en device el 2026-09-09: una instalación fresca monta el store
//  personal NEUTRO (`SwiftDataConfiguration.personalStoreDecision` → `.neutralNoMirror`), o sea sin
//  espejo de CloudKit. Ese store está VACÍO por construcción, así que cualquier detector que cuente
//  filas locales —`ContentView.checkHasExistingData`, `ModelContext.iCloudAccountSummary`— responde
//  «no hay datos» aunque el Apple ID tenga meses de histórico en su iCloud. Decisión de Jürgen
//  (2026-09-09): la validación **pregunta a CloudKit directamente y sin adjuntar el espejo**, para que
//  el aviso salga en el mismo gesto en que se elige «privado» y no haya pantalla de reinicio ciega.
//
//  ES EL PRIMER LECTOR DE REGISTROS DE CLOUDKIT DEL REPO, y conviene saberlo al tocarlo: hasta hoy había
//  tres call-sites del framework y ninguno leía nada —`allRecordZones()` como ping en
//  `iCloudSyncService.forceSync`, `userRecordID()` para la identidad de Grupos, y `CKNotification` para
//  clasificar un push—. Todo lo demás que «mira CloudKit» en `Yala/` lee las side-tables del mirror por
//  SQLite (`CKIdentityCapture`), que aquí no sirve: esas tablas son locales y en una instalación fresca
//  están vacías igual que el store.
//
//  **Por qué `recordZoneChanges` y no `CKQueryOperation`.** Una query sobre `CD_TransactionItem` exige
//  que el tipo tenga el índice `queryable` en el esquema, y eso NO está garantizado para los tipos que
//  crea `NSPersistentCloudKitContainer` (él sincroniza por cambios de zona, no por queries). Un fallo así
//  solo se vería en device y contra el contenedor de producción. `recordZoneChanges` no depende de
//  índices, pagina sola con `moreComing` y con `desiredKeys` acotado baja payloads mínimos.
//
//  **La zona NO se hardcodea.** Se enumeran las zonas reales con `allRecordZones()` y se filtran por
//  prefijo. El literal `com.apple.coredata.cloudkit.zone` no aparece hoy en producción —`CKIdentityCapture`
//  resuelve la zona por FK, precisamente para no depender de un nombre— y este fichero no lo convierte en
//  verdad única: si Apple añadiera una segunda zona al mirror, el prefijo la coge igual.
//
//  **Qué NO toca:** el contenedor de Grupos (`groupsCloudKitContainerIdentifier`) es OTRO contenedor y no
//  se enumera ni se borra. El ADR §6 dice que «Vaciar datos» nunca se lleva grupos, y esto es más
//  destructivo que aquello.
//

import CloudKit
import Foundation

// MARK: - Lo que la sonda encuentra

/// Qué hay en el iCloud privado de este Apple ID, contado en el propio contenedor.
///
/// **Espeja `ICloudAccountSummary` a propósito, y no lo reusa.** Aquél cuenta filas de un `ModelContext`
/// —o sea, lo que el espejo ya bajó— y esta sonda existe justamente para el momento en que no hay espejo.
/// Los criterios de exclusión sí son los mismos, porque el hecho que describen es el mismo: cuentas y
/// categorías de sistema no son datos del usuario (las crea el bridge de Grupos en el bootstrap, antes
/// del onboarding, y contarlas diría «hay datos» en una instalación recién hecha), y las transacciones
/// bridgeadas son derivados de un grupo, no movimientos que el usuario escribiera.
nonisolated struct ICloudPersonalCorpus: Equatable, Sendable, Identifiable {
    /// Movimientos del usuario: `CD_TransactionItem` sin `CD_splitExpenseID` ni `CD_splitSettlementID`.
    let transactions: Int
    /// Cuentas propias: `CD_Account` sin `CD_isSystemAccount`.
    let accounts: Int
    /// Subcategorías propias: `CD_Subcategory` sin `CD_isSystem`.
    let categories: Int
    /// Presupuestos: `CD_Budget`, todos. **Sin exclusiones y no es un descuido**: en producción un
    /// `Budget` nace de `BudgetEditorViewModel`, de `OnboardingView.createOnboardingBudget()` (si la
    /// persona lo pide al cerrar el onboarding), del backfill de migración o del apply de Modo Nube
    /// (`EntityApplyMap`, hoy DARK) —los seeds que crean presupuestos son `#if DEBUG`—, así que no hay
    /// «presupuesto de sistema» del que defenderse, y el conteo del store hermano
    /// (`ModelContext.iCloudAccountSummary`) tampoco filtra ninguno.
    let budgets: Int
    /// El movimiento más antiguo, para el «desde <fecha>» del aviso. `nil` si no hay ninguno con fecha
    /// legible — el copy tiene que aguantarlo sin prometer una fecha que no tiene.
    let oldestTransactionDate: Date?
    /// Se alcanzó el tope de registros y las cifras son un MÍNIMO, no un total. El copy lo dice.
    let truncated: Bool

    /// Mismo criterio que `ICloudAccountSummary.hasAnyData`: **cuatro** cifras, cualquiera de ellas
    /// basta. **Se pregunta por todas y no solo por los movimientos** porque un corpus real puede no
    /// tener ninguno todavía —alguien que creó sus cuentas y lo dejó, o que solo dejó presupuestos— y
    /// borrárselo sin avisar sería el mismo bug con otro disfraz.
    ///
    /// **Los grupos no están aquí, y tampoco en el predicado hermano: es la misma decisión, medida el
    /// 2026-09-21** (`restore-treats-budgets-and-groups-as-no-data`). `SplitGroup` vive en
    /// `groupsSchema`, cuyo store monta `cloudKitDatabase: .none`, y sus filas llegan por el backend de
    /// Yala; el contenedor de Grupos es otro y este fichero no lo toca a propósito (ver la cabecera).
    ///
    /// **Matiz que cazó la review, y que conviene no perder: «no hay grupos en el contenedor personal»
    /// es cierto POR DISEÑO, no por observación.** Hasta el 2026-06-14 `groupsConfiguration` omitía su
    /// `cloudKitDatabase: .none` y llegó a subir `CD_Split*` a este contenedor (`docs/DECISIONS.md`,
    /// confirmado entonces en el Dashboard); el arreglo fue una línea y **no borró lo ya subido**
    /// (`docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md`, INV-04: estado server-side NO VERIFICADO).
    /// Esos residuos caen en el `default` de `classify` y no encienden ninguna cifra, pero **sí suman a
    /// `scanned`** y por tanto acercan el `truncated`. Si algún día hay que detectarlos o limpiarlos,
    /// este párrafo es el permiso: lo que se prohíbe es contarlos como «datos del usuario», no mirarlos.
    ///
    /// **Y `truncated` cuenta como «sí hay», aunque las cuatro cifras sean cero** (review adversarial,
    /// 2026-09-10). El tope se cuenta sobre TODOS los tipos de la zona —el schema personal espeja
    /// tasas, notificaciones, etiquetas, presupuestos…— y `recordZoneChanges` no garantiza ningún orden,
    /// así que un corpus enorme puede agotar el tope antes de que llegue el primer `CD_TransactionItem`.
    /// `truncated` significa **«no lo sé»**, y leerlo como «no hay» borraría el histórico de quien más
    /// tiene sin decirle una palabra — que es exactamente el bug de este ticket, con otro disfraz.
    var hasAnyData: Bool {
        truncated || transactions > 0 || accounts > 0 || categories > 0 || budgets > 0
    }

    /// `Identifiable` para el `.sheet(item:)` del aviso tardío. La identidad son las CIFRAS: dos sondas
    /// que miden lo mismo describen el mismo hecho, así que no re-presentan la hoja. El fallo seguro es
    /// ese — una hoja que reaparece encima de sí misma sería una presentación sobre otra.
    var id: String { "\(transactions)-\(accounts)-\(categories)-\(budgets)-\(truncated)" }

    static let empty = ICloudPersonalCorpus(
        transactions: 0, accounts: 0, categories: 0, budgets: 0,
        oldestTransactionDate: nil, truncated: false)
}

/// ¿Tiene este iCloud alguna fila que el ADOPT tendría que probar? Lo pregunta el reconcile del adopt con el espejo adjunto
/// y nada local que pida linaje (ticket `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`).
///
/// **No es `ICloudProbeOutcome` a propósito.** Aquél cuenta el corpus para un aviso (cuatro cifras, con exclusiones de
/// sistema y un tope); éste contesta sí o no para una guarda, y cuenta TODO lo que el adopt subiría si llegara: las 16
/// entidades del canal personal menos los tipos de cambio (`adoptRelevantRecordTypes`). Una fila de sistema también sube
/// si llega, así que aquí también cuenta.
nonisolated enum ICloudAdoptCorpusCheck: Equatable, Sendable {
    /// Hay al menos un registro de ese tipo. El adopt espera a que el espejo lo baje.
    case found(recordType: String)
    /// Ningún registro de esos tipos en las zonas del espejo (o no hay zonas).
    case none
    /// CloudKit dice que no hay cuenta a la que preguntar: no hay espejo que vaya a importar nada.
    case noAccount
    /// No se pudo contestar (red, CloudKit, el plazo). El adopt no entra sin respuesta: reintenta.
    case failed(String)

    /// El detalle del canario `cloudAdoptICloudCorpusChecked`: una serie por desenlace, así que `found` NO lleva el tipo de
    /// registro (va en el rastro del dispositivo). Sin PII: literales fijos y el código del fallo.
    var canaryDetail: String {
        switch self {
        case .found:              return "found"
        case .none:               return "none"
        case .noAccount:          return "noAccount"
        case .failed(let reason): return "failed:\(reason)"
        }
    }
}

/// Cómo terminó la sonda. Tres desenlaces y **ninguno bloquea**, que es la regla del ADR §9.
nonisolated enum ICloudProbeOutcome: Equatable, Sendable {
    /// Se pudo preguntar. El corpus puede estar vacío — eso también es una respuesta.
    case measured(ICloudPersonalCorpus)
    /// No hay iCloud en el dispositivo (estado **K** de la matriz). No es un error: no hay a quién
    /// preguntar, y la app sigue en local.
    case noAccount
    /// Se pudo intentar y falló: red, CloudKit caído, timeout. Se distingue de `noAccount` porque el
    /// remedio es distinto — aquí reintentar puede funcionar, allí no.
    case failed(String)
}

// MARK: - La sonda

/// Lee y borra el corpus personal del contenedor de iCloud **sin adjuntar el espejo al store**.
///
/// `@MainActor` como el resto de servicios del Welcome; el trabajo real está en `await`, así que no
/// bloquea. Los dos seams son `static var` inyectables y no un protocolo, siguiendo el molde ya usado por
/// `GroupICloudIdentitySeed.recordNameFetcher`: hay un solo implementador de producción y lo que los
/// tests necesitan es sustituirlo, no abstraerlo.
@MainActor
enum ICloudPersonalCorpusProbe {

    /// Tope de registros que se recorren antes de rendirse y decir «al menos N». Un corpus de años cabe
    /// de sobra.
    static let recordScanCap = 20_000

    /// **Y el tope que de verdad acota la ESPERA.** El de registros no lo hace, y el docblock decía que
    /// sí: una página que vuelve vacía no incrementa el contador, así que la terminación dependía entera
    /// de que el servidor dijera `moreComing == false`. Con CloudKit lento, la persona se quedaba mirando
    /// «Revisando qué hay en tu iCloud…» sin salida — y en la puerta del Welcome eso es la app entera.
    ///
    /// Rendirse por tiempo cae en `.failed`, no en «vacío»: la pantalla ofrece reintentar **y** seguir sin
    /// comprobar. Lo que no puede pasar es que decidamos por ella que no tiene datos.
    static let scanDeadline: TimeInterval = 25

    /// Prefijo de las zonas que crea `NSPersistentCloudKitContainer` para el store privado. Se compara
    /// por PREFIJO y no por igualdad: si el mirror repartiera el schema en varias zonas, las coge todas.
    static let mirrorZonePrefix = "com.apple.coredata.cloudkit"

    /// Los únicos campos que se bajan. Todo lo demás llega como metadato del sistema (`recordType`,
    /// `creationDate`), que es gratis.
    ///
    /// **La lista es UNA para una zona MULTI-TIPO, y eso no está medido contra CloudKit real.**
    /// `CD_isSystemAccount` no existe en el schema de `CD_TransactionItem` ni `CD_date` en el de
    /// `CD_Account`. Lo esperado es que el servidor devuelva cada registro sin las keys que no le
    /// corresponden; si en cambio validara la lista contra el schema del tipo, **cada página lanzaría** y
    /// la rama privada quedaría en «reintentar» para siempre. Es el primer lector de registros del repo,
    /// así que no hay precedente donde apoyarse: **va como punto BLOQUEANTE del device-QA**, con su plan B
    /// escrito (bajar solo metadatos y sobrecontar, que falla hacia el lado seguro).
    ///
    /// Una key que falte degrada la CIFRA, nunca la decisión: sin `CD_splitExpenseID` las bridgeadas
    /// contarían como movimientos y el aviso diría un número de más.
    static let desiredKeys: [CKRecord.FieldKey] = [
        "CD_splitExpenseID", "CD_splitSettlementID", "CD_isSystemAccount", "CD_isSystem", "CD_date"
    ]

    // MARK: Seams

    /// Sonda de producción. Sustituible en tests (no hay CloudKit en simulador ni en CI).
    static var probe: @MainActor () async -> ICloudProbeOutcome = { await measureFromCloudKit() }

    /// Borrado de producción. Devuelve `nil` si fue bien, o el motivo del fallo.
    static var wipe: @MainActor () async -> String? = { await deleteMirrorZonesFromCloudKit() }

    /// **¿Espeja ESTE arranque?** No es «¿hay iCloud?», y la diferencia es el defecto más grave que cazó
    /// la review adversarial del 2026-09-10.
    ///
    /// **Solo lo consume el aviso TARDÍO**, y el matiz es load-bearing: contesta si el espejo está puesto
    /// AHORA, que es exactamente la pregunta de ese camino —«¿hay algo bajando encima de lo que la persona
    /// acaba de crear?»— y **no** la de la puerta del Welcome. Allí el mount es `.neutralNoMirror`, que
    /// devuelve `false` porque todavía no adjunta nada; usarlo como pre-filtro apagaba la puerta justo en
    /// el caso principal del ticket.
    ///
    /// La primera versión preguntaba `SwiftDataConfiguration.isICloudAvailable()`, o sea
    /// `ubiquityIdentityToken != nil`, que mide **iCloud Drive**. Un Apple ID con Drive apagado y CloudKit
    /// funcionando salía por «no se pudo validar» → la persona continuaba → y el mount `.localNoMirror`
    /// **adjunta el espejo igual**, porque no pasa `cloudKitDatabase:` y cae en `.automatic` (medido en la
    /// auditoría R1(c), `PersonalStoreDecision.attachesCloudKitMirror`). O sea: el histórico bajaba encima
    /// del onboarding recién hecho, por el predicado elegido para impedirlo.
    ///
    /// El hecho que importa es si **este proceso montó un store que espeja**, y de eso hay un testigo
    /// exacto y gratis. `CKContainer.accountStatus()` sigue descartado por la decisión escrita en
    /// `ICloudCutoverGateLogic` y `MigrationWorkExecutor`: aquí no se añade una segunda verdad, se lee la
    /// que ya gobierna.
    static var mirrorWillSync: @MainActor () -> Bool = {
        SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror
    }

    #if DEBUG
    /// Repone los cuatro seams. Lo llaman los tests entre casos.
    static func _testReset() {
        probe = { await measureFromCloudKit() }
        wipe = { await deleteMirrorZonesFromCloudKit() }
        mirrorWillSync = { SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror }
        adoptRelevantRecords = { await findAdoptRelevantRecord() }
    }
    #endif

    // MARK: - La pregunta del adopt

    /// Los tipos de registro que el adopt tendría que probar si llegaran: `CD_` + cada entidad del canal personal
    /// (`CloudSyncEngine.personalEntityNames`) menos los tipos de cambio, que el adopt no pide probar
    /// (`MigrationWorkExecutor.adoptLineageExemptTables`: los siembra cualquier teléfono al arrancar). Un test ata las dos
    /// exenciones: si una cambia sin la otra, la guarda esperaría filas que nunca pedirán prueba, o dejaría pasar las que sí.
    /// `CD_CloudMigrationMarker` no está: el marcador no sube al backend.
    static let adoptExemptEntityNames: Set<String> = [SyncEntityType.exchangeRate]
    static var adoptRelevantRecordTypes: Set<String> {
        Set(CloudSyncEngine.personalEntityNames.subtracting(adoptExemptEntityNames).map { "CD_" + $0 })
    }

    /// ¿Hay en las zonas del espejo algún registro de `adoptRelevantRecordTypes`? Sin adjuntar el espejo y sin bajar campos.
    ///
    /// **Solo metadatos (`desiredKeys: []`) y para en el PRIMERO.** Es el plan B que `desiredKeys` de arriba deja escrito
    /// para la sonda del aviso: el tipo del registro viaja siempre, así que no depende de que el servidor acepte una lista de
    /// claves de otro tipo. Y no cuenta: un corpus de años contesta en la primera página.
    ///
    /// **Los tipos de cambio de ESTE teléfono estarán ahí**: el espejo adjunto exporta los que sembró el arranque. Por eso no
    /// cuentan, y por eso un iCloud «vacío» contesta `.none` aunque su zona exista.
    ///
    /// Un registro que falla, una zona que lanza o el plazo son `.failed`: no se sabe, y el adopt no entra sin saberlo.
    static var adoptRelevantRecords: @MainActor () async -> ICloudAdoptCorpusCheck = { await findAdoptRelevantRecord() }

    private static func findAdoptRelevantRecord() async -> ICloudAdoptCorpusCheck {
        let startedAt = Date()
        let relevant = adoptRelevantRecordTypes
        do {
            for zoneID in try await mirrorZoneIDs() {
                var token: CKServerChangeToken?
                var moreComing = true
                while moreComing {
                    let batch: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                                deletions: [CKDatabase.RecordZoneChange.Deletion],
                                changeToken: CKServerChangeToken, moreComing: Bool)
                    do {
                        batch = try await privateDatabase.recordZoneChanges(
                            inZoneWith: zoneID, since: token, desiredKeys: [])
                    } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                        // La zona se borró entre la lista y la lectura (el mismo trato que le da el borrado de abajo): no
                        // tiene registros que el espejo vaya a bajar.
                        break
                    }
                    for (_, result) in batch.modificationResultsByID {
                        guard case .success(let modification) = result else { return .failed("partialRecordFailure") }
                        let type = modification.record.recordType
                        if relevant.contains(type) { return .found(recordType: type) }
                    }
                    token = batch.changeToken
                    moreComing = batch.moreComing
                    if Date().timeIntervalSince(startedAt) > scanDeadline { return .failed("scanDeadline") }
                }
            }
            return .none
        } catch let error as CKError {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: adopt check failed: \(error)")
            #endif
            if error.code == .notAuthenticated || error.code == .managedAccountRestricted { return .noAccount }
            return .failed("CKError.\(error.code.rawValue)")
        } catch {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: adopt check failed: \(error)")
            #endif
            return .failed(String(describing: type(of: error)))
        }
    }

    // MARK: Implementación de producción

    private static var privateDatabase: CKDatabase {
        CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier).privateCloudDatabase
    }

    /// Enumera las zonas del mirror. Vacío significa «este Apple ID nunca espejó nada aquí», que es una
    /// respuesta legítima y no un error.
    private static func mirrorZoneIDs() async throws -> [CKRecordZone.ID] {
        try await privateDatabase.allRecordZones()
            .map(\.zoneID)
            .filter { $0.zoneName.hasPrefix(mirrorZonePrefix) }
    }

    /// **No hay gate local antes de preguntar, y es deliberado.** Quien sabe si CloudKit puede contestar
    /// es CloudKit: `notAuthenticated` y `managedAccountRestricted` SON la respuesta «no hay cuenta a la
    /// que preguntar», y cualquier predicado local que se adelante a ellas es un pre-filtro que tapa al
    /// criterio (aquí lo fue: ver `mirrorWillSync`).
    private static func measureFromCloudKit() async -> ICloudProbeOutcome {
        let startedAt = Date()
        do {
            var transactions = 0
            var accounts = 0
            var categories = 0
            var budgets = 0
            var oldest: Date?
            var scanned = 0
            var truncated = false

            for zoneID in try await mirrorZoneIDs() {
                var token: CKServerChangeToken?
                var moreComing = true
                while moreComing {
                    let batch = try await privateDatabase.recordZoneChanges(
                        inZoneWith: zoneID, since: token, desiredKeys: desiredKeys)
                    for (_, result) in batch.modificationResultsByID {
                        // **Un registro que falla NO se salta en silencio.** Los fallos parciales son el
                        // canal normal de reporte de esta API, y descartarlos mide de menos hacia el lado
                        // peligroso: menos registros ⇒ «iCloud vacío» ⇒ borrado sin avisar. Un throw a
                        // nivel de zona ya da `.failed`; los dos hechos son el mismo y merecen el mismo
                        // veredicto.
                        guard case .success(let modification) = result else {
                            return .failed("partialRecordFailure")
                        }
                        scanned += 1
                        classify(modification.record,
                                 transactions: &transactions,
                                 accounts: &accounts,
                                 categories: &categories,
                                 budgets: &budgets,
                                 oldest: &oldest)
                    }
                    token = batch.changeToken
                    moreComing = batch.moreComing
                    if scanned >= recordScanCap {
                        truncated = true
                        moreComing = false
                    }
                    // El deadline corta la ESPERA, no el conteo: si se agota, lo medido hasta aquí no es
                    // una respuesta y no puede presentarse como tal.
                    if Date().timeIntervalSince(startedAt) > scanDeadline {
                        return .failed("scanDeadline")
                    }
                }
                if truncated { break }
            }

            return .measured(ICloudPersonalCorpus(
                transactions: transactions,
                accounts: accounts,
                categories: categories,
                budgets: budgets,
                oldestTransactionDate: oldest,
                truncated: truncated))
        } catch let error as CKError {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: probe failed: \(error)")
            #endif
            // **`notAuthenticated` es el estado K de verdad**, y solo CloudKit puede declararlo.
            if error.code == .notAuthenticated || error.code == .managedAccountRestricted {
                return .noAccount
            }
            // El código, no el nombre del tipo: `CKError` a secas no distingue una cuota agotada de una
            // red caída, y el canario que lo recibe es la única superficie de observación que hay.
            return .failed("CKError.\(error.code.rawValue)")
        } catch {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: probe failed: \(error)")
            #endif
            return .failed(String(describing: type(of: error)))
        }
    }

    /// Un registro → su casilla.
    ///
    /// **`CD_Budget` se cuenta desde el 2026-09-21**; `CD_SplitGroup` cae en el `default` y no se
    /// cuenta — el porqué, y el matiz de los residuos legacy que sí pueden existir ahí, en `hasAnyData`
    /// arriba.
    ///
    /// **Las exclusiones se PARECEN a las de `ModelContext.iCloudAccountSummary`, no la espejan.** Aquél
    /// descarta además las cuentas archivadas y las de `type == "system"`; aquí no se puede sin ampliar
    /// `desiredKeys`, que es justo la lista que el device-QA tiene que validar primero. La diferencia
    /// cuenta de MÁS (un Apple ID cuyo único corpus sean cuentas archivadas dispara el aviso), y ese es el
    /// lado seguro: un aviso que sobra se cancela, uno que falta borra un histórico.
    private static func classify(_ record: CKRecord,
                                 transactions: inout Int,
                                 accounts: inout Int,
                                 categories: inout Int,
                                 budgets: inout Int,
                                 oldest: inout Date?) {
        switch record.recordType {
        case "CD_TransactionItem":
            guard record["CD_splitExpenseID"] == nil, record["CD_splitSettlementID"] == nil else { return }
            transactions += 1
            if let date = record["CD_date"] as? Date, oldest.map({ date < $0 }) ?? true {
                oldest = date
            }
        case "CD_Account":
            guard !isFlagSet(record["CD_isSystemAccount"]) else { return }
            accounts += 1
        case "CD_Subcategory":
            guard !isFlagSet(record["CD_isSystem"]) else { return }
            categories += 1
        case "CD_Budget":
            // Sin `guard`: no hay presupuestos de sistema de los que defenderse (ver `budgets`). Y sin
            // keys nuevas en `desiredKeys` —el tipo basta para contar—, así que el punto bloqueante del
            // device-QA sobre esa lista no crece.
            budgets += 1
        default:
            return
        }
    }

    /// **Un `Bool` de Core Data NO viaja como `Bool` por CloudKit: viaja como número**, así que
    /// `as? Bool` da `nil` siempre y `as? Int` depende de si el valor llega como `Int64` nativo o
    /// puenteado desde `NSNumber` — `Int64` no casa con `Int` por `as?` aunque midan lo mismo. `NSNumber`
    /// es lo único que cubre las tres formas (`Bool`, `Int`, `Int64`) por bridging.
    ///
    /// **Y el default es `false` —«no es de sistema, cuéntalo»— a propósito.** Los dos errores no cuestan
    /// lo mismo: contar de más saca un aviso que la persona cancela; contar de menos deja el aviso sin
    /// salir y le borra su histórico sin preguntar. Ante un campo ilegible, sobra un aviso.
    private static func isFlagSet(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue ?? false
    }

    /// Borra las zonas del mirror. **Borrar la zona y no sus registros** es lo que deja el contenedor a
    /// cero sin adjuntar el espejo: `NSPersistentCloudKitContainer` recrea una zona vacía la próxima vez
    /// que arranque con el mirror puesto.
    ///
    /// **Es idempotente, y de eso depende la kill-safety**: borrar una zona que ya no existe no es un
    /// error, y si no queda ninguna la operación no tiene nada que hacer.
    private static func deleteMirrorZonesFromCloudKit() async -> String? {
        do {
            let zoneIDs = try await mirrorZoneIDs()
            guard !zoneIDs.isEmpty else { return nil }
            let (_, deleteResults) = try await privateDatabase.modifyRecordZones(
                saving: [], deleting: zoneIDs)
            // **`modifyRecordZones` solo LANZA por un fallo de la operación entera.** Los fallos POR ZONA
            // —`zoneBusy`, `quotaExceeded`, una red que se cae a medio batch— llegan aquí dentro, en
            // silencio. Descartar este tuple con `_ =` era reportar éxito sobre un borrado que no ocurrió:
            // el arm se retiraba, nadie reintentaba, y en el camino tardío el store local ya se había
            // vaciado ⇒ la persona se quedaba sin sus datos locales Y con el corpus viejo entero en
            // iCloud, que es la peor combinación de las posibles.
            for (_, result) in deleteResults {
                guard case .failure(let error) = result else { continue }
                if let ck = error as? CKError,
                   ck.code == .zoneNotFound || ck.code == .userDeletedZone { continue }
                #if DEBUG
                print("ICloudPersonalCorpusProbe: zone delete failed: \(error)")
                #endif
                return (error as? CKError).map { "CKError.\($0.code.rawValue)" }
                    ?? String(describing: type(of: error))
            }
            return nil
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            // Ya no estaba: el borrado anterior llegó a completarse aunque su arm no se limpiara.
            return nil
        } catch let error as CKError {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: wipe failed: \(error)")
            #endif
            return "CKError.\(error.code.rawValue)"
        } catch {
            #if DEBUG
            print("ICloudPersonalCorpusProbe: wipe failed: \(error)")
            #endif
            return String(describing: type(of: error))
        }
    }
}
