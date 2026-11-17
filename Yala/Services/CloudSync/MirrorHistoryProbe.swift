//
//  MirrorHistoryProbe.swift
//  Yala
//
//  ¿Puede el espejo de iCloud seguir leyendo el historial de este store donde lo dejó?
//
//  **Por qué existe (ticket `reverse-on-the-iphone-left-the-local-store-empty`, medido en el iPhone 14 el 2026-11-17).**
//  `NSPersistentCloudKitContainer` guarda en su tabla de metadatos (`ANSCKMETADATAENTRY`,
//  `NSCloudKitMirroringDelegateLastHistoryTokenKey`) la última transacción del historial que leyó. Mientras el teléfono
//  está en la nube el espejo está apagado y no avanza; si en ese tiempo algo purga el historial por detrás de esa
//  transacción, al remontar el espejo en la vuelta a iCloud su exportación falla con
//  `NSPersistentHistoryTokenExpiredError` (134301) y el espejo hace un «reset»: borra TODAS las filas del store (autor
//  `NSCloudKitMirroringDelegate.reset`, 8.842 cambios medidos) y la vuelta se cierra con el teléfono vacío. Las vuelve
//  a bajar de iCloud en el arranque siguiente, pero sin lo que se hizo en la época en la nube.
//
//  La purga de la época en la nube era `CloudSyncRuntime` → `CloudSyncEngine.purgeHistoryOnce`, y se apagó el mismo día
//  (`CloudSyncFlags.historyPurgeEnabled`). Este fichero es para los teléfonos que YA purgaron: la vuelta no se ofrece
//  si el espejo se encontraría su posición caducada (`ReverseEligibility.applyingMirrorHistory`), y una vuelta que ya
//  estaba en curso al actualizar sale a la nube antes de montarlo (`MigrationWorkExecutor.mirrorHistoryBlocksRemount`).
//
//  **Lectura READ-ONLY del SQLite**, como `CKIdentityCapture`: la tabla del espejo es privada de Core Data y no tiene
//  API. Todo lo que no se deja leer es `.unreadable`, que la elegibilidad trata como «no ahora»: no se monta un espejo
//  sobre un dato que no se leyó.
//

import Foundation
import SQLite3
import SwiftData

/// Lo que contesta `MirrorHistoryProbe`.
nonisolated enum MirrorHistoryState: Equatable, Sendable {
    /// El store nunca tuvo un espejo que guardara su posición en el historial (sin tabla de metadatos, o sin la
    /// posición): al montarlo, el espejo empieza por lo que haya y no puede encontrarla caducada.
    case noMirrorPosition
    /// Todas las transacciones posteriores a la posición del espejo siguen en el historial.
    case intact
    /// Falta alguna transacción posterior a la posición del espejo: al remontarlo, su exportación caduca y borra el store.
    case expired
    /// No se pudo leer (el SQLite no abre, falta una tabla o una columna, la posición no se descifra).
    case unreadable(String)
}

nonisolated enum MirrorHistoryProbe {

    /// La clave con la que el espejo guarda su posición en el historial (`NSCloudKitMirroringDelegate`).
    static let lastHistoryTokenKey = "NSCloudKitMirroringDelegateLastHistoryTokenKey"

    // MARK: Decisión pura

    /// - Parameters:
    ///   - mirrorTransaction: la transacción del historial en la que se quedó el espejo; `nil` si no guardó posición.
    ///   - highestTransaction: el mayor número de transacción que el store llegó a dar (`Z_PRIMARYKEY.Z_MAX`), aunque
    ///     ya no esté en el historial.
    ///   - retainedFromMirror: cuántas transacciones siguen en el historial desde la del espejo, ELLA INCLUIDA.
    ///
    /// **Cuenta las que faltan, no mira la más vieja**: los números de transacción no se reutilizan, así que «todas
    /// siguen» es que haya una por cada número entre la del espejo y la última. Mirar solo la más vieja que queda no
    /// vería una purga que dejara la primera posterior y se llevara otras.
    ///
    /// **Y exige la del propio espejo** (review del 2026-11-17): no está medido si Core Data da por caducado un token cuya
    /// transacción ya no existe aunque sigan todas las posteriores, y una purga que cortó justo detrás de ella dejaría
    /// ese caso. Falla cerrado: en un teléfono que no purga, la del espejo sigue ahí.
    static func decide(mirrorTransaction: Int64?, highestTransaction: Int64, retainedFromMirror: Int64) -> MirrorHistoryState {
        guard let mirrorTransaction else { return .noMirrorPosition }
        // Con todo escrito ANTES del espejo (`highest < mirror`) no hay nada que exigir; no ocurre en un store sano.
        let expected = max(0, highestTransaction - mirrorTransaction + 1)
        if retainedFromMirror > expected { return .unreadable("history-count-inconsistent") }
        return retainedFromMirror < expected ? .expired : .intact
    }

    // MARK: Lectura del SQLite

    static func read(storeURL: URL) -> MirrorHistoryState {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return .noMirrorPosition }
        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard openRC == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            return .unreadable("open-failed")
        }
        defer { sqlite3_close(db) }
        // El espejo puede estar escribiendo: un cerrojo ocupado espera un poco en vez de devolver BUSY al instante.
        sqlite3_busy_timeout(db, 2_000)

        guard let tables = textColumn(db, "SELECT name FROM sqlite_master WHERE type='table'") else {
            return .unreadable("schema-unreadable")
        }
        let upper = Set(tables.map { $0.uppercased() })
        // Sin la tabla de metadatos del espejo, el store nunca espejó.
        guard upper.contains("ANSCKMETADATAENTRY") else { return .noMirrorPosition }
        guard let blobs = blobColumn(
            db, "SELECT ZTRANSFORMEDVALUE FROM ANSCKMETADATAENTRY WHERE ZKEY = '\(lastHistoryTokenKey)'")
        else { return .unreadable("token-query-failed") }
        guard let blob = blobs.first else { return .noMirrorPosition }
        guard let storeUUID = textColumn(db, "SELECT Z_UUID FROM Z_METADATA")?.first else {
            return .unreadable("store-uuid-unreadable")
        }
        guard let mirrorTransaction = transactionNumber(inToken: blob, storeUUID: storeUUID) else {
            return .unreadable("token-undecodable")
        }
        guard upper.contains("ATRANSACTION") else { return .unreadable("history-table-missing") }
        // Las dos cifras en UNA consulta, que es una sola lectura: en dos, lo que el motor guardara entre medias subiría
        // el recuento sin subir el máximo y taparía el hueco (review del 2026-11-17).
        guard let pair = integerPair(db, """
            SELECT (SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'TRANSACTION'),
                   (SELECT COUNT(*) FROM ATRANSACTION WHERE Z_PK >= \(mirrorTransaction))
            """) else { return .unreadable("history-count-failed") }
        guard let highest = pair.0 else { return .unreadable("highest-transaction-unreadable") }
        return decide(mirrorTransaction: mirrorTransaction, highestTransaction: highest, retainedFromMirror: pair.1 ?? 0)
    }

    /// El número de transacción de este store dentro de un `NSPersistentHistoryToken` archivado. El token es un
    /// diccionario «UUID del store → número»; su clase es privada de Core Data, así que se lee con una clase propia que
    /// solo decodifica ese diccionario. Un token sin la entrada de este store es `nil`: no se adivina.
    static func transactionNumber(inToken data: Data, storeUUID: String) -> Int64? {
        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        } catch {
            #if DEBUG
            print("MirrorHistoryProbe: el token no se deja abrir: \(error)")
            #endif
            return nil
        }
        unarchiver.requiresSecureCoding = true
        unarchiver.setClass(MirrorHistoryTokenShim.self, forClassName: "_NSPersistentHistoryToken")
        unarchiver.setClass(MirrorHistoryTokenShim.self, forClassName: "NSPersistentHistoryToken")
        defer { unarchiver.finishDecoding() }
        guard let shim = unarchiver.decodeObject(of: MirrorHistoryTokenShim.self, forKey: NSKeyedArchiveRootObjectKey)
        else { return nil }
        return shim.entries[storeUUID]
    }

    // MARK: SQLite (lecturas estrictas: una consulta cortada no es un resultado)

    private static func textColumn(_ db: OpaquePointer, _ sql: String) -> [String]? {
        rows(db, sql) { stmt in sqlite3_column_text(stmt, 0).map { String(cString: $0) } }
    }

    private static func integerColumn(_ db: OpaquePointer, _ sql: String) -> [Int64]? {
        rows(db, sql) { stmt in
            sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 0)
        }
    }

    /// Las dos columnas enteras de la única fila de un SELECT (cada una `nil` si es NULL), o `nil` si no terminó.
    private static func integerPair(_ db: OpaquePointer, _ sql: String) -> (Int64?, Int64?)? {
        rows(db, sql) { stmt -> (Int64?, Int64?)? in
            func column(_ i: Int32) -> Int64? {
                sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, i)
            }
            return (column(0), column(1))
        }?.first
    }

    private static func blobColumn(_ db: OpaquePointer, _ sql: String) -> [Data]? {
        rows(db, sql) { stmt in
            guard let ptr = sqlite3_column_blob(stmt, 0) else { return nil }
            return Data(bytes: ptr, count: Int(sqlite3_column_bytes(stmt, 0)))
        }
    }

    private static func rows<T>(_ db: OpaquePointer, _ sql: String, _ value: (OpaquePointer?) -> T?) -> [T]? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        var out: [T] = []
        var rc = sqlite3_step(stmt)
        while rc == SQLITE_ROW {
            if let v = value(stmt) { out.append(v) }
            rc = sqlite3_step(stmt)
        }
        return rc == SQLITE_DONE ? out : nil
    }
}

/// La posición del espejo del store PERSONAL, leída **una vez por proceso** (también la que no se deja leer). La consultan
/// la elegibilidad de la vuelta (`CloudMigrationController.reverseEligibility`, que la pantalla repinta cada segundo),
/// `startReverse` y el paso previo al montaje (`MigrationWorkExecutor.mirrorHistoryBlocksRemount`). Con la purga del
/// historial apagada no cambia mientras la app corre; una lectura fallida se vuelve a intentar en el arranque siguiente,
/// y mientras tanto la vuelta no se ofrece.
@MainActor
enum MirrorHistoryCheck {
    private static var cached: MirrorHistoryState?

    /// Seam: la lectura real del SQLite del store personal. Los tests la sustituyen (`_testSet`).
    static var reader: @MainActor () -> MirrorHistoryState = { liveRead() }

    static func personalStore() -> MirrorHistoryState {
        if let cached { return cached }
        let state = reader()
        cached = state
        switch state {
        case .unreadable(let reason):
            CloudSyncBreadcrumb.localReadFailed(step: "reverse-mirror-history", errorType: reason)
            // Si un iOS nuevo cambia el archivado del token, aquí caerían todos los teléfonos migrados: que se vea.
            MetricsService.canaryOnce(.cloudReverseMirrorHistoryUnreadable, key: "process", detail: reason)
        case .expired:
            MetricsService.canaryOnce(.cloudReverseMirrorHistoryExpired, key: "process")
        case .noMirrorPosition, .intact:
            break
        }
        return state
    }

    /// ¿Remontar el espejo vaciaría el store? `true` también si no se pudo leer: no se monta sobre un dato sin leer.
    static func blocksRemount() -> Bool {
        switch personalStore() {
        case .expired, .unreadable: return true
        case .noMirrorPosition, .intact: return false
        }
    }

    private static func liveRead() -> MirrorHistoryState {
        MirrorHistoryProbe.read(storeURL: SwiftDataConfiguration.personalConfiguration.url)
    }

    #if DEBUG
    /// Solo tests: fija lo que lee la sonda y olvida la lectura guardada. `nil` vuelve a la lectura real.
    static func _testSet(_ state: MirrorHistoryState?) {
        cached = nil
        if let state { reader = { state } } else { reader = { liveRead() } }
    }
    #endif
}

/// Lee solo el diccionario de un `NSPersistentHistoryToken` archivado (`NSPersistentHistoryTokenDictionary`). Lo
/// archivan también los tests, con la misma clave, para fabricar un token con la forma del de Core Data.
@objc(YalaMirrorHistoryTokenShim)
nonisolated final class MirrorHistoryTokenShim: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let entries: [String: Int64]

    init(entries: [String: Int64]) {
        self.entries = entries
    }

    required init?(coder: NSCoder) {
        guard let dict = coder.decodeObject(
            of: [NSDictionary.self, NSString.self, NSNumber.self],
            forKey: "NSPersistentHistoryTokenDictionary") as? [String: NSNumber]
        else { return nil }
        entries = dict.mapValues { $0.int64Value }
    }

    func encode(with coder: NSCoder) {
        coder.encode(entries.mapValues { NSNumber(value: $0) } as NSDictionary,
                     forKey: "NSPersistentHistoryTokenDictionary")
    }
}
