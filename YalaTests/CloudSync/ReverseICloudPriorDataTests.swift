//
//  ReverseICloudPriorDataTests.swift
//  YalaTests / CloudSync
//
//  Ticket `reverse-to-icloud-merges-prior-icloud-data-without-asking` (decisión A de Jürgen, 2026-10-15): «Volver a
//  iCloud» en un teléfono nacido en la nube pregunta a iCloud qué sumaría y deja elegir. CloudKit no existe en el
//  simulador, así que aquí va todo lo que se puede fijar sin él:
//
//  - la lógica que decide qué hace el botón y el texto del aviso;
//  - el recuento de lo ajeno con `CKRecord` fabricados (no necesitan red), incluido el caso del QA del 15-oct: solo
//    gastos de grupo, que la sonda vieja no contaba;
//  - el lector de los metadatos locales del espejo, contra un SQLite fabricado a mano;
//  - el cableado de producción, por source-scan: que el botón pase por la pregunta y que «Empezar sin ellos» no empiece
//    la vuelta con el borrado a medias.
//

import CloudKit
import Foundation
import SQLite3
import Testing

@testable import Yala

// MARK: - Qué hace el botón

@Suite("Vuelta a iCloud con datos previos · decisión y texto")
@MainActor
struct ReverseICloudPriorDataLogicTests {

    private func corpus(transactions: Int = 0, groups: Int = 0, accounts: Int = 0, budgets: Int = 0,
                        other: Int = 0, truncated: Bool = false) -> ICloudForeignCorpus {
        ICloudForeignCorpus(transactions: transactions, groupTransactions: groups, accounts: accounts,
                            budgets: budgets, otherRecords: other, truncated: truncated, fieldsUnread: false)
    }

    @Test func onlyABornCloudPhoneAsksICloud() {
        #expect(ReverseICloudPriorDataLogic.asksICloud(isBornCloud: true))
        #expect(!ReverseICloudPriorDataLogic.asksICloud(isBornCloud: false))
    }

    @Test func nothingForeign_proceedsWithTheUsualConfirmations() {
        #expect(ReverseICloudPriorDataLogic.gate(.measured(.empty)) == .proceed)
    }

    /// Sin cuenta de iCloud la vuelta no empieza: esperaría a que la persona abra iCloud, y entonces el espejo sumaría lo
    /// que hubiera sin que nadie lo mirara.
    @Test func noICloudAccount_needsICloud() {
        #expect(ReverseICloudPriorDataLogic.gate(.noAccount) == .needsICloud)
    }

    /// Sin respuesta no se sigue: seguir sería sumar sin avisar, que es el bug.
    @Test func aFailedCheck_doesNotStartTheReverse() {
        #expect(ReverseICloudPriorDataLogic.gate(.failed("CKError.4")) == .cannotCheck("CKError.4"))
    }

    /// El caso del QA del 2026-10-15: solo 9 gastos de grupo de otra cuenta. Tiene que avisar, y por la casilla de los
    /// grupos sola: con otra casilla encendida al lado, un `hasAnyData` que olvidara los grupos pasaría igual.
    @Test func onlyGroupRecords_asks() {
        let found = corpus(groups: 9)
        #expect(found.hasAnyData)
        #expect(ReverseICloudPriorDataLogic.gate(.measured(found)) == .ask(found))
    }

    /// Cada casilla basta por sí sola.
    @Test func eachFigureAlone_counts() {
        #expect(corpus(transactions: 1).hasAnyData)
        #expect(corpus(accounts: 1).hasAnyData)
        #expect(corpus(budgets: 1).hasAnyData)
        #expect(!ICloudForeignCorpus.empty.hasAnyData)
    }

    /// Un registro ajeno sin casilla propia (una etiqueta, un borrador, una cuenta de sistema) también lo bajaría el espejo.
    @Test func onlyRecordsWithoutTheirOwnFigure_ask() {
        let found = corpus(other: 1)
        #expect(ReverseICloudPriorDataLogic.gate(.measured(found)) == .ask(found))
    }

    /// El tope dice «al menos tantos», nunca «nada».
    @Test func aTruncatedScanWithNoFigures_asks() {
        let found = corpus(truncated: true)
        #expect(ReverseICloudPriorDataLogic.gate(.measured(found)) == .ask(found))
    }

    @Test func summary_listsTheFiguresInReadingOrder() {
        let parts = ReverseICloudPriorDataLogic.summaryParts(
            corpus(transactions: 12, groups: 9, accounts: 2, budgets: 1, other: 4))
        #expect(parts == [
            L10n.Welcome.Restore.foundTransactions(12),
            L10n.Storage.Revert.Prior.groupRecords(9),
            L10n.Welcome.Restore.foundAccounts(2),
            L10n.Welcome.Restore.foundBudgets(1),
        ])
    }

    @Test func summary_truncatedSaysAtLeast() {
        #expect(ReverseICloudPriorDataLogic.summaryParts(corpus(transactions: 20_000, truncated: true))
                == [L10n.Welcome.PrivateICloud.foundAtLeast(20_000)])
        #expect(ReverseICloudPriorDataLogic.summaryParts(corpus(truncated: true))
                == [L10n.Welcome.PrivateICloud.foundUnknownAmount])
    }

    /// Los registros de grupos se nombran aparte: llegan sin su grupo.
    @Test func message_namesTheGroupRecordsOnlyWhenThereAreAny() {
        let withGroups = ReverseICloudPriorDataLogic.message(corpus(transactions: 3, groups: 9))
        #expect(withGroups.hasSuffix(L10n.Storage.Revert.Prior.groupsNote))
        let withoutGroups = ReverseICloudPriorDataLogic.message(corpus(transactions: 3))
        #expect(!withoutGroups.contains(L10n.Storage.Revert.Prior.groupsNote))
        #expect(withoutGroups == L10n.Storage.Revert.Prior.body(L10n.Welcome.Restore.foundTransactions(3)))
    }

    /// Sin cifras que decir, el texto no promete números.
    @Test func message_withoutFigures_usesTheBodyWithoutCount() {
        #expect(ReverseICloudPriorDataLogic.message(corpus(other: 2)) == L10n.Storage.Revert.Prior.bodyNoCount)
    }

    @Test func canaryDetail() {
        #expect(ICloudForeignCorpusCheck.measured(corpus(other: 1)).canaryDetail == "found")
        #expect(ICloudForeignCorpusCheck.measured(.empty).canaryDetail == "none")
        #expect(ICloudForeignCorpusCheck.noAccount.canaryDetail == "noAccount")
        #expect(ICloudForeignCorpusCheck.failed("scanDeadline").canaryDetail == "failed:scanDeadline")
    }
}

// MARK: - Qué cuenta como ajeno

@Suite("Vuelta a iCloud con datos previos · recuento de lo ajeno")
@MainActor
struct ICloudForeignTallyTests {

    private let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

    private func record(_ type: String, _ name: String = UUID().uuidString,
                        fields: [String: CKRecordValue] = [:]) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name, zoneID: zone))
        for (key, value) in fields { record[key] = value }
        return record
    }

    private func tally(known: Set<String> = [], readsFields: Bool = true) -> ICloudPersonalCorpusProbe.ForeignTally {
        ICloudPersonalCorpusProbe.ForeignTally(
            known: known, countedTypes: ICloudPersonalCorpusProbe.reverseCountedRecordTypes, readsFields: readsFields)
    }

    /// El QA del 15-oct, con la forma que tenían las filas: gastos puenteados de un grupo y la cuenta de sistema del puente.
    /// `ICloudPersonalCorpus` los dejaba fuera a los dos; aquí cuentan.
    @Test func theQACase_groupExpensesAndTheBridgeAccount_count() {
        var t = tally()
        for _ in 0..<9 {
            t.add(record("CD_TransactionItem", fields: ["CD_splitExpenseID": UUID().uuidString as NSString]))
        }
        t.add(record("CD_Account", fields: ["CD_isSystemAccount": NSNumber(value: 1)]))
        let corpus = t.corpus(truncated: false)
        #expect(corpus.groupTransactions == 9)
        #expect(corpus.transactions == 0)
        #expect(corpus.accounts == 0)
        #expect(corpus.otherRecords == 1)
        #expect(corpus.hasAnyData)
    }

    @Test func eachTypeGoesToItsFigure() {
        var t = tally()
        t.add(record("CD_TransactionItem"))
        t.add(record("CD_TransactionItem", fields: ["CD_splitSettlementID": UUID().uuidString as NSString]))
        t.add(record("CD_Account", fields: ["CD_isSystemAccount": NSNumber(value: 0)]))
        t.add(record("CD_Account"))
        t.add(record("CD_Budget"))
        t.add(record("CD_Tag"))
        t.add(record("CD_InboxDraft"))
        let corpus = t.corpus(truncated: false)
        #expect(corpus == ICloudForeignCorpus(transactions: 1, groupTransactions: 1, accounts: 2, budgets: 1,
                                              otherRecords: 2, truncated: false, fieldsUnread: false))
    }

    /// Lo que el espejo de este store ya conoce no se suma: se reconcilia con su fila. Es la copia propia de una vuelta
    /// anterior a medias, y avisar por ella sería un aviso falso.
    @Test func recordsTheLocalMirrorAlreadyKnows_doNotCount() {
        var t = tally(known: ["mio-1", "mio-2"])
        let ownTransaction = t.add(record("CD_TransactionItem", "mio-1"))
        let ownAccount = t.add(record("CD_Account", "mio-2"))
        let foreign = t.add(record("CD_TransactionItem", "ajeno-1"))
        #expect(!ownTransaction)
        #expect(!ownAccount)
        #expect(foreign)
        #expect(t.corpus(truncated: false).transactions == 1)
        #expect(t.counted == 1)
    }

    /// Los tipos de cambio los siembra cualquier teléfono y el marcador es de la migración de otra cuenta: no son datos.
    @Test func exchangeRatesAndMarkers_doNotCount() {
        var t = tally()
        let rate = t.add(record("CD_ExchangeRate"))
        let marker = t.add(record("CD_CloudMigrationMarker"))
        #expect(!rate)
        #expect(!marker)
        #expect(!t.corpus(truncated: false).hasAnyData)
    }

    /// Sin campos (el plan B si el servidor rechaza la lista) se cuenta de más, nunca de menos.
    @Test func withoutFields_groupExpensesCountAsRecordsAndSystemAccountsAsAccounts() {
        var t = tally(readsFields: false)
        t.add(record("CD_TransactionItem", fields: ["CD_splitExpenseID": UUID().uuidString as NSString]))
        t.add(record("CD_Account", fields: ["CD_isSystemAccount": NSNumber(value: 1)]))
        let corpus = t.corpus(truncated: false)
        #expect(corpus.transactions == 1)
        #expect(corpus.groupTransactions == 0)
        #expect(corpus.accounts == 1)
        #expect(corpus.fieldsUnread)
    }

    /// Qué cuenta y qué borra «Empezar sin ellos». El borrado incluye los tipos de cambio (que el espejo no baje nada
    /// que esta cuenta no tenga) y nunca el marcador.
    @Test func countedAndWipedTypes() {
        let counted = ICloudPersonalCorpusProbe.reverseCountedRecordTypes
        let wiped = ICloudPersonalCorpusProbe.reverseWipedRecordTypes
        #expect(counted.contains("CD_TransactionItem"))
        #expect(counted.contains("CD_InboxDraft"))
        #expect(!counted.contains("CD_ExchangeRate"))
        #expect(!counted.contains("CD_CloudMigrationMarker"))
        #expect(wiped == counted.union(["CD_ExchangeRate"]))
        #expect(!wiped.contains("CD_CloudMigrationMarker"))
    }

    /// «Empezar sin ellos» borra lo ajeno de los tipos del canal personal y nada que el espejo local ya conozca: esa es
    /// la copia propia, y borrarla podría llevarse las filas locales al remontar.
    @Test func theWipe_takesOnlyForeignRecordsOfPersonalTypes() {
        let known: Set<String> = ["mio"]
        #expect(ICloudPersonalCorpusProbe.wipesForeignRecord(type: "CD_TransactionItem", recordName: "ajeno", known: known))
        #expect(ICloudPersonalCorpusProbe.wipesForeignRecord(type: "CD_ExchangeRate", recordName: "ajeno", known: known))
        #expect(!ICloudPersonalCorpusProbe.wipesForeignRecord(type: "CD_TransactionItem", recordName: "mio", known: known))
        #expect(!ICloudPersonalCorpusProbe.wipesForeignRecord(type: "CD_CloudMigrationMarker", recordName: "ajeno",
                                                              known: known))
    }

    /// Un fallo por registro llega dentro del resultado: no se puede dar el borrado por hecho. «Ya no estaba», sí.
    @Test func aPartialDeleteFailure_isAFailure_butAMissingRecordIsNot() {
        let id1 = CKRecord.ID(recordName: "a", zoneID: zone)
        let id2 = CKRecord.ID(recordName: "b", zoneID: zone)
        #expect(ICloudPersonalCorpusProbe.deleteFailure(in: [:]) == nil)
        #expect(ICloudPersonalCorpusProbe.deleteFailure(in: [
            id1: .success(()), id2: .failure(CKError(.unknownItem)),
        ]) == nil)
        #expect(ICloudPersonalCorpusProbe.deleteFailure(in: [
            id1: .success(()), id2: .failure(CKError(.zoneBusy)),
        ]) == "CKError.\(CKError.Code.zoneBusy.rawValue)")
    }

    /// Solo CloudKit declara «no hay cuenta»; todo lo demás es «no se supo», que no deja empezar.
    @Test func checkErrors_mapToTheirOutcome() {
        #expect(ICloudPersonalCorpusProbe.foreignCheckOutcome(for: CKError(.notAuthenticated)) == .noAccount)
        #expect(ICloudPersonalCorpusProbe.foreignCheckOutcome(for: CKError(.managedAccountRestricted)) == .noAccount)
        #expect(ICloudPersonalCorpusProbe.foreignCheckOutcome(for: CKError(.networkUnavailable))
                == .failed("CKError.\(CKError.Code.networkUnavailable.rawValue)"))
        #expect(ICloudPersonalCorpusProbe.foreignCheckOutcome(
            for: ICloudPersonalCorpusProbe.ForeignScanError.partialRecordFailure) == .failed("partialRecordFailure"))
        #expect(ICloudPersonalCorpusProbe.foreignCheckOutcome(
            for: ICloudPersonalCorpusProbe.ForeignScanError.deadline) == .failed("scanDeadline"))
    }
}

// MARK: - Qué conoce ya el espejo local

@Suite("Vuelta a iCloud con datos previos · metadatos locales del espejo", .serialized)
@MainActor
struct MirroredRecordNamesTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MirroredNames-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeDatabase(_ dir: URL, _ statements: [String]) -> URL {
        let url = dir.appendingPathComponent("store.sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        for sql in statements {
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "SQL: \(sql)")
        }
        sqlite3_close(db)
        return url
    }

    /// Las filas con `ZCKRECORDNAME` y nada más: las `NULL` son exports pendientes, que iCloud todavía no tiene.
    @Test func readsTheRecordNames_skippingPendingExports() {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = makeDatabase(dir, [
            "CREATE TABLE ZTRANSACTIONITEM (Z_PK INTEGER)",
            "CREATE TABLE ANSCKRECORDZONEMETADATA (Z_PK INTEGER, ZCKRECORDZONENAME TEXT)",
            "CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT)",
            "INSERT INTO ANSCKRECORDMETADATA VALUES (1, 10, 5, 'rec-a')",
            "INSERT INTO ANSCKRECORDMETADATA VALUES (2, 11, 5, 'rec-b')",
            "INSERT INTO ANSCKRECORDMETADATA VALUES (3, 12, 5, NULL)",
        ])
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: url) == .names(["rec-a", "rec-b"]))
    }

    /// Un store que nunca montó el espejo no tiene la tabla: no conoce nada, y eso es una respuesta.
    @Test func aStoreThatNeverMirrored_knowsNothing() {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = makeDatabase(dir, ["CREATE TABLE ZTRANSACTIONITEM (Z_PK INTEGER)"])
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: url) == .names([]))
    }

    /// Con side-tables del espejo y sin la de metadatos, el formato cambió: no se sabe qué conoce, y «nada» llevaría el
    /// borrado a la copia propia.
    @Test func mirrorTablesWithoutTheMetadataTable_areUnreadable() {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = makeDatabase(dir, ["CREATE TABLE ANSCKRECORDZONEMETADATA (Z_PK INTEGER, ZCKRECORDZONENAME TEXT)"])
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: url) == .unreadable("meta-table-missing"))
    }

    @Test func aTableWithoutTheRecordNameColumn_isUnreadable() {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = makeDatabase(dir, ["CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER, ZENTITYPK INTEGER)"])
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: url) == .unreadable("meta-columns-missing"))
    }

    @Test func aMissingStore_isUnreadable() {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: dir.appendingPathComponent("nada.sqlite"))
                == .unreadable("open-failed"))
    }

    /// Un fichero que no es una base de datos no puede leerse como «el espejo no conoce nada».
    @Test func aFileThatIsNotADatabase_isUnreadable() throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("basura.sqlite")
        try Data(repeating: 0x41, count: 4096).write(to: url)
        #expect(CKIdentityCapture.mirroredRecordNames(storeURL: url) == .unreadable("schema-unreadable"))
    }
}

// MARK: - Cableado de producción

@Suite("Vuelta a iCloud con datos previos · cableado (source-scan)")
@MainActor
struct ReverseICloudPriorDataWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo de la función que abre `marker`, de su llave a la de cierre, en líneas recortadas y sin comentarios: nombrar
    /// algo en un comentario no puede pintar el test de verde.
    private static func body(of marker: String, in source: String) throws -> [String] {
        let start = try #require(source.range(of: marker), "no encuentro «\(marker)»")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let viewPath = "Yala/App/Views/Settings/StorageSettingsView.swift"
    private static let controllerPath = "Yala/Services/CloudSync/CloudMigrationController.swift"

    /// El botón «Volver a iCloud» pasa por la pregunta. Las confirmaciones de siempre solo se abren cuando iCloud contestó
    /// que no hay nada ajeno: con un `confirmRevert1 = true` en otro sitio, la vuelta podría empezar sin preguntar.
    @Test func theRevertButton_asksICloudBeforeTheConfirmations() throws {
        let view = try Self.source(Self.viewPath)
        let card = try Self.body(of: "private func revertCard(_ controller: CloudMigrationController) -> some View {",
                                 in: view)
        #expect(card.contains("Task { await beginRevert() }"))
        #expect(Self.codeOnly(view).components(separatedBy: "confirmRevert1 = true").count - 1 == 1,
                "una sola apertura de las confirmaciones de siempre")
        let begin = try Self.body(of: "private func beginRevert() async {", in: view)
        #expect(begin == [
            "guard let controller else { return }",
            "revertMergesPriorData = false",
            "confirmRevert1 = false",
            "showRevertPriorData = false",
            "showRevertCheckFailed = false",
            "switch await controller.checkICloudBeforeReverse() {",
            "case nil:",
            "return",
            "case .proceed:",
            "confirmRevert1 = true",
            "case .ask(let corpus):",
            "revertPriorData = corpus",
            "showRevertPriorData = true",
            "case .cannotCheck:",
            "revertNeedsICloud = false",
            "showRevertCheckFailed = true",
            "case .needsICloud:",
            "revertNeedsICloud = true",
            "showRevertCheckFailed = true",
            "}",
        ])
    }

    /// Cada salida del aviso va a su acción: un swap entre «Sumarlos» y «Empezar sin ellos» compila y borra lo que la
    /// persona quería sumar.
    @Test func theDialogs_routeEachChoiceToItsAction() throws {
        let view = Self.codeOnly(try Self.source(Self.viewPath))
        #expect(view.contains("onMerge: chooseMergingPriorData,"))
        #expect(view.contains("onDiscard: { Task { await controller?.startReverseDiscardingICloudPriorData() } },"))
        #expect(view.contains("onRetryCheck: retryRevertCheck))"))
        #expect(view.contains("Button(L10n.Storage.Revert.Prior.merge) { onMerge() }"))
        #expect(view.contains("Button(L10n.Storage.Revert.Prior.discard, role: .destructive) { confirmDiscard = true }"))
        #expect(view.contains("Button(L10n.Storage.Revert.Prior.discardConfirm, role: .destructive) { onDiscard() }"))
        let merge = try Self.body(of: "private func chooseMergingPriorData() {", in: try Self.source(Self.viewPath))
        #expect(merge == ["revertMergesPriorData = true", "confirmRevert2 = true"])
    }

    /// Solo pregunta un teléfono nacido en la nube, y la sonda que produce el veredicto es la de lo ajeno.
    @Test func theCheck_isGatedByBornCloud_andUsesTheForeignProbe() throws {
        let body = try Self.body(
            of: "func checkICloudBeforeReverse() async -> ReverseICloudPriorDataLogic.Gate? {",
            in: try Self.source(Self.controllerPath))
        #expect(body.first
                == "guard ReverseICloudPriorDataLogic.asksICloud(isBornCloud: Self.readIsBornCloud()) else { return .proceed }")
        #expect(body[1] == "guard !isCheckingICloudBeforeReverse else { return nil }")
        // Dos veces: la rama DEBUG (tras el seam) y la de release. Con una sola, la otra rama podría preguntar a otra cosa.
        #expect(body.filter { $0 == "check = await ICloudPersonalCorpusProbe.foreignCorpusForReverse()" }.count == 2)
        #expect(body.last == "return ReverseICloudPriorDataLogic.gate(check)")
    }

    /// «Empezar sin ellos» no empieza la vuelta con el borrado a medias: el espejo sumaría lo que quedó.
    @Test func discarding_startsTheReverseOnlyAfterTheWipeFinished() throws {
        let body = try Self.body(of: "func startReverseDiscardingICloudPriorData() async {",
                                 in: try Self.source(Self.controllerPath))
        // Las comprobaciones de la vuelta van ANTES del borrado, que no tiene vuelta.
        let checks = try #require(body.firstIndex(
            of: "guard !isWorking, uiState == .cloudActive, reverseEligibility() == .eligible else {"))
        let journal = try #require(body.firstIndex(of: "guard let journal = readJournalDecisionInputs() else {"))
        let pendingExit = try #require(body.firstIndex(
            of: "if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journal.phase) {"))
        let wipe = try #require(body.firstIndex(
            of: "failure = await ICloudPersonalCorpusProbe.wipeForeignCorpusForReverse()"))
        #expect(checks < journal && journal < pendingExit && pendingExit < wipe)
        let failure = try #require(body.firstIndex(of: "if let failure {"))
        let start = try #require(body.firstIndex(of: "await startReverse()"))
        #expect(Array(body[failure...(failure + 4)]) == [
            "if let failure {",
            "MetricsService.cloudReverseICloudPriorDataChoice(\"discardFailed:\\(failure)\")",
            "lastError = L10n.Storage.Revert.Prior.wipeFailed",
            "return",
            "}",
        ])
        #expect(failure < start)
        #expect(body.filter { $0 == "await startReverse()" }.count == 1)
        #expect(body.contains("failure = await ICloudPersonalCorpusProbe.wipeForeignCorpusForReverse()"))
    }

    /// Los seams de producción son las implementaciones contra CloudKit: sin esto, el teléfono preguntaría a un stub.
    @Test func productionSeams_pointAtCloudKit() throws {
        let probe = Self.codeOnly(try Self.source("Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift"))
        #expect(probe.contains("""
            static var foreignCorpusForReverse: @MainActor () async -> ICloudForeignCorpusCheck = {
                    await measureForeignCorpusFromCloudKit()
                }
            """))
        #expect(probe.contains("""
            static var wipeForeignCorpusForReverse: @MainActor () async -> String? = {
                    await deleteForeignRecordsFromCloudKit()
                }
            """))
    }
}
