//
//  MirrorHistoryProbeTests.swift
//  YalaTests
//
//  Ticket `reverse-on-the-iphone-left-the-local-store-empty`. Medido en el iPhone 14 el 2026-11-17: el espejo de iCloud
//  guardaba como posición la transacción 825 del historial, el store solo conservaba la 834 (la purga de la época en la
//  nube se llevó el resto) y al remontarlo en la vuelta su «reset» borró las 8.842 filas del store. Estos tests fijan la
//  lectura de esa posición (`MirrorHistoryProbe`), lo que la vuelta hace con ella (`ReverseEligibility`) y que la purga
//  que la caducaba sigue apagada.
//

import Foundation
import SQLite3
import Testing
@testable import Yala

/// El token real del iPhone 14 (`ANSCKMETADATAENTRY.ZTRANSFORMEDVALUE` de `NSCloudKitMirroringDelegateLastHistoryTokenKey`,
/// copiado del store con `devicectl` antes de remontar): un `_NSPersistentHistoryToken` archivado con la entrada
/// «82F42C0B-… → 825». Es la forma de Core Data, no una que fabrique el test.
private enum DeviceToken {
    static let storeUUID = "82F42C0B-6354-4FA5-8F84-8093CC468430"
    static let transaction: Int64 = 825
    static let data = Data(base64Encoded: "YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGnCwwRGRobIVUkbnVsbNINDg8QViRjbGFzc18QIk5TUGVyc2lzdGVudEhpc3RvcnlUb2tlbkRpY3Rpb25hcnmABoAC0xITDRQWGFdOUy5rZXlzWk5TLm9iamVjdHOhFYADoReABIAFXxAkODJGNDJDMEItNjM1NC00RkE1LThGODQtODA5M0NDNDY4NDMwEQM50hwdHh9aJGNsYXNzbmFtZVgkY2xhc3Nlc1xOU0RpY3Rpb25hcnmiHiBYTlNPYmplY3TSHB0iI18QGV9OU1BlcnNpc3RlbnRIaXN0b3J5VG9rZW6jJCUgXxAZX05TUGVyc2lzdGVudEhpc3RvcnlUb2tlbl8QGE5TUGVyc2lzdGVudEhpc3RvcnlUb2tlbgAIABEAGgAkACkAMgA3AEkATABRAFMAWwBhAGYAbQCSAJQAlgCdAKUAsACyALQAtgC4ALoA4QDkAOkA9AD9AQoBDQEWARsBNwE7AVcAAAAAAAACAQAAAAAAAAAmAAAAAAAAAAAAAAAAAAABcg==")!
}

@Suite("Vuelta a iCloud · posición del espejo en el historial (decisión)")
struct MirrorHistoryProbeDecisionTests {

    private func decide(_ mirror: Int64?, highest: Int64 = 834, retained: Int64) -> MirrorHistoryState {
        MirrorHistoryProbe.decide(mirrorTransaction: mirror, highestTransaction: highest, retainedFromMirror: retained)
    }

    @Test func withoutAPosition_theMirrorCannotFindItExpired() {
        #expect(decide(nil, retained: 0) == .noMirrorPosition)
    }

    /// El caso medido en el iPhone: del 825 al 834 solo queda el 834.
    @Test func theDeviceShape_isExpired() {
        #expect(decide(825, retained: 1) == .expired)
    }

    /// Control del anterior: con la del espejo y las nueve posteriores en su sitio, sigue donde lo dejó.
    @Test func everyTransactionFromTheMirrorKept_isIntact() {
        #expect(decide(825, retained: 10) == .intact)
    }

    /// Nada escrito desde que el espejo leyó: solo queda la suya, y basta.
    @Test func nothingWrittenSinceTheMirror_isIntact() {
        #expect(decide(825, highest: 825, retained: 1) == .intact)
    }

    /// Una sola que falte basta: el espejo pide la siguiente a la suya, no la última.
    @Test func oneMissingInTheMiddle_isExpired() {
        #expect(decide(825, retained: 9) == .expired)
    }

    /// Falla cerrado (review del 2026-11-17): sin medir si Core Data acepta un token cuya transacción ya no está, una
    /// purga que cortó justo detrás de ella (826–834 intactas) no se da por buena.
    @Test func theMirrorsOwnTransactionMissing_isExpired() {
        #expect(decide(825, retained: 9) == .expired)
    }

    /// Más transacciones que números posibles no es un historial: es una lectura que no cuadra.
    @Test func moreThanPossible_isUnreadable() {
        #expect(decide(825, retained: 11) == .unreadable("history-count-inconsistent"))
    }
}

@Suite("Vuelta a iCloud · token del espejo de Core Data")
struct MirrorHistoryTokenDecodingTests {

    @Test func theDeviceToken_readsTransaction825() {
        #expect(MirrorHistoryProbe.transactionNumber(inToken: DeviceToken.data, storeUUID: DeviceToken.storeUUID)
                == DeviceToken.transaction)
    }

    /// El token es de otro store: no se adivina con su único número.
    @Test func aTokenOfAnotherStore_isNotRead() {
        #expect(MirrorHistoryProbe.transactionNumber(inToken: DeviceToken.data, storeUUID: UUID().uuidString) == nil)
    }

    @Test func garbage_isNotRead() {
        #expect(MirrorHistoryProbe.transactionNumber(inToken: Data("no es un archivo".utf8), storeUUID: DeviceToken.storeUUID)
                == nil)
    }
}

@Suite("Vuelta a iCloud · posición del espejo leída del SQLite")
struct MirrorHistoryProbeReadTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MirrorHistory-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func hex(_ data: Data) -> String { data.map { String(format: "%02X", $0) }.joined() }

    /// Un SQLite con las tablas de Core Data que lee la sonda, con sus nombres de columna reales (medidos en el store del
    /// iPhone). `token` nil = la tabla del espejo existe sin la posición; `mirrorTable: false` = el store nunca espejó.
    private func makeStore(_ dir: URL, token: Data? = DeviceToken.data, mirrorTable: Bool = true,
                           highest: Int64? = 834, kept: [Int64]) -> URL {
        let url = dir.appendingPathComponent("YalaModel-Dev.store")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        var sql = [
            "CREATE TABLE Z_METADATA (Z_VERSION INTEGER PRIMARY KEY, Z_UUID VARCHAR(255), Z_PLIST BLOB)",
            "INSERT INTO Z_METADATA VALUES (1, '\(DeviceToken.storeUUID)', NULL)",
            "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR, Z_SUPER INTEGER, Z_MAX INTEGER)",
            "INSERT INTO Z_PRIMARYKEY VALUES (31, 'TransactionItem', 0, 2370)",
            "CREATE TABLE ATRANSACTION (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, ZTIMESTAMP FLOAT, ZAUTHOR VARCHAR)",
        ]
        if let highest { sql.append("INSERT INTO Z_PRIMARYKEY VALUES (16002, 'TRANSACTION', 0, \(highest))") }
        sql += kept.map { "INSERT INTO ATRANSACTION VALUES (\($0), 16002, 0, NULL)" }
        if mirrorTable {
            sql.append("CREATE TABLE ANSCKMETADATAENTRY (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, ZKEY VARCHAR, ZTRANSFORMEDVALUE BLOB)")
            sql.append("INSERT INTO ANSCKMETADATAENTRY VALUES (1, 17009, 'PFCloudKitMetadataFrameworkVersionKey', NULL)")
            if let token {
                sql.append("INSERT INTO ANSCKMETADATAENTRY VALUES (2, 17009, '\(MirrorHistoryProbe.lastHistoryTokenKey)', X'\(hex(token))')")
            }
        }
        for statement in sql {
            #expect(sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK, "SQL: \(statement)")
        }
        sqlite3_close(db)
        return url
    }

    /// El store del iPhone justo antes del remonte que lo vació: posición 825, solo queda la 834.
    @Test func theDeviceStore_beforeTheRemount_isExpired() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, kept: [834])) == .expired)
    }

    /// Control positivo del anterior: el mismo store con el historial entero.
    @Test func theSameStore_withTheWholeHistory_isIntact() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, kept: Array(825...834))) == .intact)
    }

    /// Una transacción ANTERIOR a la posición que ya no está no le importa al espejo: ya la leyó.
    @Test func purgedBeforeThePosition_isIntact() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, kept: [700] + Array(825...834))) == .intact)
    }

    @Test func aGapAfterThePosition_isExpired() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, kept: [825, 826] + Array(830...834))) == .expired)
    }

    /// Un teléfono nacido en la nube nunca montó el espejo: no hay posición que caducar.
    @Test func aStoreThatNeverMirrored_hasNoPosition() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, mirrorTable: false, kept: [834])) == .noMirrorPosition)
    }

    @Test func aMirrorTableWithoutThePosition_hasNoPosition() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: makeStore(dir, token: nil, kept: [834])) == .noMirrorPosition)
    }

    @Test func aMissingStoreFile_hasNoPosition() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        #expect(MirrorHistoryProbe.read(storeURL: dir.appendingPathComponent("nada.store")) == .noMirrorPosition)
    }

    /// Lo que no se deja leer no se da por bueno: ni un token que no se descifra ni un historial sin su contador.
    @Test func whatCannotBeRead_isUnreadable() {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let garbage = MirrorHistoryProbe.read(storeURL: makeStore(dir, token: Data("roto".utf8), kept: [834]))
        #expect(garbage == .unreadable("token-undecodable"))
        let dir2 = freshDir(); defer { discardTestStoreDirectory(dir2) }
        let noCounter = MirrorHistoryProbe.read(storeURL: makeStore(dir2, highest: nil, kept: [834]))
        #expect(noCounter == .unreadable("highest-transaction-unreadable"))
    }
}

@Suite("Vuelta a iCloud · el espejo caducado no se ofrece", .serialized)
@MainActor
struct ReverseMirrorHistoryEligibilityTests {

    /// Solo CIERRA una vuelta elegible; no abre ninguna ni tapa los otros motivos.
    @Test func applyingMirrorHistory_onlyClosesAnEligibleReverse() {
        typealias E = ReverseEligibility
        #expect(E.applyingMirrorHistory(.eligible, .noMirrorPosition) == .eligible)
        #expect(E.applyingMirrorHistory(.eligible, .intact) == .eligible)
        #expect(E.applyingMirrorHistory(.eligible, .expired) == .mirrorHistoryExpired)
        #expect(E.applyingMirrorHistory(.eligible, .unreadable("x")) == .mirrorHistoryUnreadable)
        for other: E.Decision in [.notCloudMode, .degradedNoMap, .reverseAlreadyTerminal, .mapUnreadable] {
            #expect(E.applyingMirrorHistory(other, .expired) == other)
            #expect(E.applyingMirrorHistory(other, .intact) == other)
        }
    }

    /// Una lectura por proceso, también la que falla: la pantalla repinta cada segundo y no puede abrir el SQLite cada vez.
    @Test func theProbe_isReadOncePerProcess() {
        defer { MirrorHistoryCheck._testSet(nil) }
        for state: MirrorHistoryState in [.unreadable("open-failed"), .expired, .intact] {
            var reads = 0
            MirrorHistoryCheck._testSet(state)
            MirrorHistoryCheck.reader = { reads += 1; return state }
            #expect(MirrorHistoryCheck.personalStore() == state)
            #expect(MirrorHistoryCheck.personalStore() == state)
            #expect(reads == 1, "\(state)")
        }
    }

    /// Lo que no deja remontar el espejo: caducado o sin leer. Sano o sin posición, sí.
    @Test func blocksRemount_onlyWhenExpiredOrUnreadable() {
        defer { MirrorHistoryCheck._testSet(nil) }
        let cases: [(MirrorHistoryState, Bool)] = [
            (.expired, true), (.unreadable("x"), true), (.intact, false), (.noMirrorPosition, false)]
        for (state, blocks) in cases {
            MirrorHistoryCheck._testSet(state)
            #expect(MirrorHistoryCheck.blocksRemount() == blocks, "\(state)")
        }
    }

    /// El texto del aviso es el suyo, distinto del «ahora mismo» y del de otro dispositivo.
    @Test func theIneligibleText_namesTheExpiredMirror() {
        #expect(StorageSettingsView.revertIneligibleText(.mirrorHistoryExpired) == L10n.Storage.Revert.ineligibleMirrorHistory)
        #expect(StorageSettingsView.revertIneligibleText(.mirrorHistoryUnreadable) == L10n.Storage.Revert.ineligible)
        #expect(StorageSettingsView.revertIneligibleText(.degradedNoMap) == L10n.Storage.Revert.ineligibleOtherDevice)
        #expect(StorageSettingsView.revertIneligibleIdentifier(.mirrorHistoryExpired) == "storage_revert_ineligible_mirror_history")
        #expect(L10n.Storage.Revert.ineligibleMirrorHistory != "storage.revert.ineligibleMirrorHistory")
    }
}

@Suite("Vuelta a iCloud · la purga del historial sigue apagada")
struct HistoryPurgeStaysOffTests {

    /// La purga de la época en la nube caducaba la posición del espejo (medido en el iPhone 14). Encenderla otra vez
    /// exige una purga que respete esa posición: este test es el que obliga a pensarlo.
    @Test func theProductionDefault_isOff() throws {
        let source = try String(contentsOfFile: Self.repoRoot + "/Yala/Services/CloudSync/CloudSyncFlags.swift", encoding: .utf8)
        #expect(source.contains("static var historyPurgeEnabled = false"))
        #expect(!source.contains("static var historyPurgeEnabled = true"))
    }

    /// El controlador consulta la sonda en la elegibilidad de la pantalla, detrás de la decisión de siempre.
    @Test func theControllerAppliesTheProbe() throws {
        let source = try String(contentsOfFile: Self.repoRoot + "/Yala/Services/CloudSync/CloudMigrationController.swift",
                                encoding: .utf8)
        // Entero: con `base != .eligible` en el ternario, el teléfono caducado quedaría elegible y «Empezar sin ellos»
        // borraría lo de iCloud antes de que `startReverse` lo frenara (lo cazó la review).
        let lines = source.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let start = try #require(lines.firstIndex(of: "let decision = base == .eligible"))
        #expect(Array(lines[start...].prefix(3)) == [
            "let decision = base == .eligible",
            "? ReverseEligibility.applyingMirrorHistory(base, MirrorHistoryCheck.personalStore())",
            ": base",
        ])
    }

    private static var repoRoot: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
}
