//
//  SettlementAmountChangeNoticeTests.swift
//  YalaTests
//
//  Ticket `settlement-amount-edited-after-approval-leaves-the-bank-stale` (decisión A de Jürgen): si otra persona corrige el
//  importe de una liquidación que ya aprobé a una cuenta real, el Inbox avisa y ofrece ajustar esa transacción. Dos suites:
//  la decisión pura (`GroupSettlementAmountChangeLogic`) y el recorrido contra el bridge y `DraftService` REALES con los
//  tres stores en disco (harness de `GroupsBridgeRestoreConvergenceTests`), que es donde vive el dinero: que ajustar no
//  cuente doble, que la misma corrección no pregunte otra vez y que una segunda sí, con la cifra al día.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Decisión pura

@Suite("Aviso de importe cambiado tras aprobar: la decisión pura")
struct SettlementAmountChangeLogicTests {

    private typealias Logic = GroupSettlementAmountChangeLogic

    private func mark(_ amount: Double, tx: Double? = nil, currency: String? = "USD") -> Logic.Mark {
        .init(amount: amount, transactionAmount: tx ?? amount, transactionCurrency: currency)
    }

    @Test("sin cambio de importe no se avisa, y sobra cualquier aviso viejo")
    func sameAmount_noNotice() {
        #expect(Logic.plan(settlementAmount: 25, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)], notices: []) == .nothing)
        let plan = Logic.plan(settlementAmount: 25, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)],
                              notices: [.init(status: .pending, amount: 30), .init(status: .rejected, amount: 30)])
        #expect(plan.pendingAmount == nil && plan.deleteIndices == [0, 1])
    }

    @Test("importe cambiado con la marca viva: un aviso con el importe nuevo y el signo de la marca")
    func changed_noticeWithSign() {
        let received = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)], notices: [])
        #expect(received == .init(pendingAmount: 30, keepPendingIndex: nil, deleteIndices: []))
        let sent = Logic.plan(settlementAmount: 50, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(-40)], notices: [])
        #expect(sent.pendingAmount == -50, "el aviso de un pago que hice yo sale en negativo, como la transacción")
    }

    @Test("la referencia es la marca, no la transacción: editar la transacción a mano no avisa")
    func referenceIsTheMark() {
        let plan = Logic.plan(settlementAmount: 25, settlementCurrency: "USD",
                              expectsOutflow: nil, marks: [mark(25, tx: 26)], notices: [])
        #expect(plan == .nothing)
    }

    @Test("un rechazado con el importe de hoy es la decisión: no se vuelve a preguntar")
    func rejectedAtTodaysAmount_isTheDecision() {
        let plan = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)],
                              notices: [.init(status: .rejected, amount: 30), .init(status: .pending, amount: 30)])
        #expect(plan == .init(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: [1]))
    }

    @Test("una segunda corrección vuelve a avisar con la cifra al día y retira lo de la anterior")
    func secondCorrection_asksAgain() {
        let afterKeep = Logic.plan(settlementAmount: 35, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)],
                                   notices: [.init(status: .rejected, amount: 30)])
        #expect(afterKeep == .init(pendingAmount: 35, keepPendingIndex: nil, deleteIndices: [0]))
        let stillPending = Logic.plan(settlementAmount: 35, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)],
                                      notices: [.init(status: .pending, amount: 30), .init(status: .pending, amount: 30)])
        #expect(stillPending == .init(pendingAmount: 35, keepPendingIndex: 0, deleteIndices: [1]),
                "se pone al día el primero y sobra el duplicado")
    }

    @Test("sin una marca viva, o en otra divisa, no hay nada que ajustar: sobran los pendientes y no los rechazados")
    func noLiveMark_orOtherCurrency() {
        let notices: [Logic.Notice] = [.init(status: .pending, amount: 30), .init(status: .rejected, amount: 30)]
        let gone = Logic.plan(settlementAmount: 30, settlementCurrency: "USD",
                              expectsOutflow: nil,
                              marks: [.init(amount: 25, transactionAmount: nil, transactionCurrency: nil)], notices: notices)
        #expect(gone == .init(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: [0]))
        let two = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25), mark(25)], notices: [])
        #expect(two == .nothing, "dos marcas vivas: el duplicado ya conocido, no se elige una a ciegas")
        let currency = Logic.plan(settlementAmount: 30, settlementCurrency: "USD",
                                  expectsOutflow: nil, marks: [mark(25, currency: "PEN")], notices: [])
        #expect(currency == .nothing)
    }

    @Test("la transacción ya en el importe nuevo (editada a mano) no pregunta: los dos botones dirían lo mismo")
    func transactionAlreadyAtTheNewAmount_noNotice() {
        let plan = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: false,
                              marks: [mark(25, tx: 30)], notices: [.init(status: .pending, amount: 30)])
        #expect(plan == .init(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: [0]))
    }

    @Test("si la liquidación cambió de sentido no se ajusta con el signo viejo; con el sentido de siempre, sí")
    func directionFlipped_noNotice() {
        let flipped = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: true,
                                 marks: [mark(25)], notices: [.init(status: .pending, amount: 30)])
        #expect(flipped == .init(pendingAmount: nil, keepPendingIndex: nil, deleteIndices: [0]))
        let same = Logic.plan(settlementAmount: 30, settlementCurrency: "USD", expectsOutflow: false,
                              marks: [mark(25)], notices: [])
        #expect(same.pendingAmount == 30)
        let sent = Logic.plan(settlementAmount: 50, settlementCurrency: "USD", expectsOutflow: true,
                              marks: [mark(-40)], notices: [])
        #expect(sent.pendingAmount == -50)
    }

    @Test("medio céntimo es el borde: 0,004 es el mismo importe y 0,006 no")
    func toleranceNeighbours() {
        #expect(Logic.plan(settlementAmount: 25.004, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)], notices: []) == .nothing)
        #expect(Logic.plan(settlementAmount: 25.006, settlementCurrency: "USD", expectsOutflow: nil, marks: [mark(25)], notices: [])
            .pendingAmount == 25.006)
    }
}

// MARK: - Contra el bridge y DraftService reales

@Suite("Aviso de importe cambiado tras aprobar, contra el bridge real", .serialized)
@MainActor
struct SettlementAmountChangeBehaviourTests {

    // MARK: - Infra (harness de GroupsBridgeRestoreConvergenceTests)

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettlementAmountChange-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("SettlementAmountChangeNoticeTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "SAC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "SAC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "SAC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        // Sin autosave: un `approveDraft` que lanza deja cambios que el temporizador guardaría con la carpeta ya borrada.
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let bank: Account
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let bank = Account(name: "Banco", currencyCode: "USD", colorHex: "#222222",
                           iconName: "building.columns", type: "bank")
        context.insert(bank)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, bank: bank)
    }

    private func withEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        DraftService.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previousPrivateSession
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            DraftService.shared.setContext(nil)
        }
        SessionState.shared.hasPrivateSession = true
        try body()
    }

    /// Ana me pagó `amount` (Caso D), confirmada.
    private func received(_ context: ModelContext, _ f: Fixture, _ amount: Double, note: String? = "Cena") throws
        -> SplitSettlement {
        let s = SplitSettlement(groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.ana.id.uuidString,
                                toMemberID: f.me.id.uuidString, amount: amount, currencyCode: "USD", note: note)
        s.isConfirmed = true
        context.insert(s)
        try context.save()
        return s
    }

    /// Le pagué yo a Ana `amount` (Caso C), confirmada.
    private func paid(_ context: ModelContext, _ f: Fixture, _ amount: Double) throws -> SplitSettlement {
        let s = SplitSettlement(groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.me.id.uuidString,
                                toMemberID: f.ana.id.uuidString, amount: amount, currencyCode: "USD")
        s.isConfirmed = true
        context.insert(s)
        try context.save()
        return s
    }

    private func drafts(_ context: ModelContext, _ s: SplitSettlement) throws -> [InboxDraft] {
        let id = s.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitSettlementID == id }))
    }

    private func notices(_ context: ModelContext, _ s: SplitSettlement) throws -> [InboxDraft] {
        try drafts(context, s).filter(\.isSettlementAmountChangeNotice)
    }

    private func pendingNotices(_ context: ModelContext, _ s: SplitSettlement) throws -> [InboxDraft] {
        try notices(context, s).filter { $0.status == .pending }
    }

    private func mark(_ context: ModelContext, _ s: SplitSettlement) throws -> InboxDraft {
        try #require(try drafts(context, s).first { $0.status == .approved && !$0.isSettlementAmountChangeNotice },
                     "no hay marca de aprobación")
    }

    private func bankRows(_ context: ModelContext, _ f: Fixture) throws -> [Double] {
        try context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.account?.persistentModelID == f.bank.persistentModelID }
            .map(\.amount)
    }

    private func legs(_ context: ModelContext, _ s: SplitSettlement) throws -> [TransactionItem] {
        let id = s.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitSettlementID == id }))
    }

    /// La persona aprueba en el Inbox el borrador pendiente, con su banco, por el camino REAL.
    @discardableResult
    private func bridgeAndApprove(_ context: ModelContext, _ s: SplitSettlement, _ f: Fixture) throws -> TransactionItem {
        try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
        let pending = try #require(try drafts(context, s).first { $0.status == .pending },
                                   "el fixture no deja un borrador pendiente de la liquidación")
        pending.account = f.bank
        return try DraftService.shared.approveDraft(pending, currencyConverter: CurrencyConverter())
    }

    /// Lo que hace el pull del backend con una edición remota del importe (`GroupsSyncClient.applySettlement`): escribe el
    /// importe en la fila y re-puentea.
    private func remoteEdit(_ context: ModelContext, _ s: SplitSettlement, amount: Double? = nil, note: String? = nil)
        throws {
        if let amount { s.amount = amount }
        if let note { s.note = note }
        try context.save()
        try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
    }

    private func adjust(_ notice: InboxDraft) throws -> TransactionItem {
        try DraftService.shared.approveDraft(notice, currencyConverter: CurrencyConverter())
    }

    // MARK: - El caso del ticket

    @Test("Ana corrige de 25 a 30 una liquidación aprobada: el Inbox avisa con quién, el grupo y el importe nuevo")
    func correctedAfterApproval_noticeAppears() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            let real = try bridgeAndApprove(context, s, f)

            try remoteEdit(context, s, amount: 30)

            let notice = try #require(try pendingNotices(context, s).first, "la corrección no avisó en el Inbox")
            #expect(try pendingNotices(context, s).count == 1)
            #expect(notice.amount == 30)
            // El aviso NO se enlaza a la transacción: la relación es uno a uno y le quitaría el enlace a la marca.
            #expect(notice.approvedTransaction == nil)
            #expect(try mark(context, s).approvedTransaction?.persistentModelID == real.persistentModelID,
                    "el aviso le quitó la transacción a la marca")
            let fresh = ModelContext(context.container)
            let idStr = s.id.uuidString
            let approvedRaw = DraftStatus.approved.rawValue
            let storedMark = try #require(try fresh.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitSettlementID == idStr && $0.statusRaw == approvedRaw })).first)
            #expect(storedMark.isLiveSettlementApprovalMark, "en disco la marca quedó sin su transacción")
            #expect(notice.requiresApprovalForm, "deslizar o «Aprobar todo» ajustarían sin ver las cifras")
            #expect(notice.originActorName == "Ana" && notice.originGroupName == "Viaje")
            #expect(notice.account?.persistentModelID == f.bank.persistentModelID && notice.isReadyToApprove)
            #expect(!notice.isLiveSettlementApprovalMark, "el aviso no es la marca")
            #expect(try bankRows(context, f) == [25], "D7: la transacción real no se toca sola")
            #expect(try mark(context, s).amount == 25)
            #expect(try legs(context, s).map(\.amount) == [-30], "la pata virtual sigue a la liquidación, como antes")

            // Otro re-puente con la misma cifra no lo sustituye: es el mismo registro (la hoja puede estar abierta).
            let id = notice.persistentModelID
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            #expect(try pendingNotices(context, s).map(\.persistentModelID) == [id])
        }
    }

    @Test("un aviso rechazado no cuenta como resolución: si un receptor se lleva la marca y la real, se vuelve a preguntar")
    func rejectedNotice_isNotAResolution() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            let real = try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            try DraftService.shared.rejectDraft(try #require(try pendingNotices(context, s).first))
            // Un receptor tardío de «Vaciar datos» se lleva la real y su marca (regla de la marca, punto 1).
            context.delete(try mark(context, s))
            context.delete(real)
            try context.save()

            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            let ask = try drafts(context, s).filter { $0.status == .pending && !$0.isSettlementAmountChangeNotice }
            #expect(ask.count == 1, "el rechazo de un aviso se leyó como «la persona no quiere registrarlo»")
            #expect(ask.first?.amount == 30)
        }
    }

    @Test("ajustar deja el banco en el importe nuevo, sin contar doble, y la misma corrección no vuelve a avisar")
    func adjust_setsTheBankOnce_andDoesNotAskAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            let real = try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)

            let adjusted = try adjust(try #require(try pendingNotices(context, s).first))

            #expect(adjusted.persistentModelID == real.persistentModelID, "ajustar creó otra transacción")
            #expect(try bankRows(context, f) == [30])
            #expect(adjusted.splitSettlementID == nil, "D7: la real sigue sin enlace a la liquidación")
            #expect(try mark(context, s).amount == 30)
            #expect(try notices(context, s).isEmpty)
            let net = try bankRows(context, f).reduce(0, +) + legs(context, s).map(\.amount).reduce(0, +)
            #expect(net == 0, "cobro real y pata virtual se compensan: nada cuenta doble")

            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            #expect(try notices(context, s).isEmpty, "el re-puente volvió a avisar de una corrección ya ajustada")
            #expect(try bankRows(context, f) == [30])
        }
    }

    @Test("dejarla como está no toca el banco, el aviso se va y la misma corrección no vuelve a preguntar")
    func keep_leavesTheBank_andSticks() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)

            try DraftService.shared.rejectDraft(try #require(try pendingNotices(context, s).first))

            #expect(try bankRows(context, f) == [25])
            #expect(try pendingNotices(context, s).isEmpty)
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            try GroupTransactionBridge.reconcileSettlementAmountChangeNotices(context: context)
            #expect(try pendingNotices(context, s).isEmpty, "dejarla como estaba no duró al re-puente")
            #expect(try notices(context, s).map(\.status) == [.rejected])
            #expect(try mark(context, s).amount == 25)
        }
    }

    @Test("una segunda corrección vuelve a avisar con la cifra al día, tras dejarla y tras ajustar")
    func secondCorrection_asksAgainWithTheCurrentFigure() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let kept = try received(context, f, 25)
            try bridgeAndApprove(context, kept, f)
            try remoteEdit(context, kept, amount: 30)
            try DraftService.shared.rejectDraft(try #require(try pendingNotices(context, kept).first))
            try remoteEdit(context, kept, amount: 35)
            #expect(try pendingNotices(context, kept).map(\.amount) == [35])
            #expect(try notices(context, kept).count == 1, "el rechazo de la corrección anterior sobra")

            let adjusted = try received(context, f, 10, note: "Taxi")
            try bridgeAndApprove(context, adjusted, f)
            try remoteEdit(context, adjusted, amount: 12)
            _ = try adjust(try #require(try pendingNotices(context, adjusted).first))
            try remoteEdit(context, adjusted, amount: 15)
            let second = try #require(try pendingNotices(context, adjusted).first)
            #expect(second.amount == 15)
            _ = try adjust(second)
            #expect(try bankRows(context, f).sorted() == [15, 25])
        }
    }

    @Test("una corrección que se deshace antes de contestar retira el aviso")
    func correctionUndone_removesTheNotice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            #expect(try pendingNotices(context, s).count == 1)
            try remoteEdit(context, s, amount: 25)
            #expect(try notices(context, s).isEmpty)
        }
    }

    @Test("un pago que hice yo (Caso C): el aviso y el ajuste salen en negativo")
    func caseC_sentPayment() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try paid(context, f, 40)
            try bridgeAndApprove(context, s, f)
            #expect(try bankRows(context, f) == [-40])
            try remoteEdit(context, s, amount: 50)
            let notice = try #require(try pendingNotices(context, s).first)
            #expect(notice.amount == -50 && notice.originActorName == "Ana")
            _ = try adjust(notice)
            #expect(try bankRows(context, f) == [-50])
        }
    }

    // MARK: - Controles

    @Test("control: sin aprobación previa el borrador pendiente sigue a la liquidación y no hay aviso")
    func control_notApproved() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            try remoteEdit(context, s, amount: 30)
            #expect(try notices(context, s).isEmpty)
            #expect(try drafts(context, s).map(\.amount) == [30])
            #expect(try bankRows(context, f).isEmpty)
        }
    }

    @Test("control: aprobada y re-puenteada sin cambiar el importe, o cambiando solo la nota, no avisa")
    func control_approvedWithoutAmountChange() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            #expect(try notices(context, s).isEmpty)
            try remoteEdit(context, s, note: "Cena corregida")
            #expect(try notices(context, s).isEmpty)
            #expect(try bankRows(context, f) == [25])
        }
    }

    // MARK: - Lo que lee la marca no lee el aviso

    @Test("el aviso no se borra, ni deslizando ni en lote, y la poda en frío no lo toma por un pendiente sobrante")
    func notice_cannotBeDeleted_andIsNotPruned() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let notice = try #require(try pendingNotices(context, s).first)

            #expect(throws: DraftServiceError.self) { try DraftService.shared.deleteDraft(notice) }
            try DraftService.shared.bulkDelete([notice])
            try GroupTransactionBridge.pruneSettlementDraftsAlreadyResolved(context: context)
            #expect(try pendingNotices(context, s).count == 1, "el aviso desapareció sin contestarlo")

            try DraftService.shared.rejectDraft(notice)
            #expect(throws: DraftServiceError.self) { try DraftService.shared.deleteDraft(notice) }
            #expect(try notices(context, s).map(\.status) == [.rejected])
        }
    }

    @Test("al soltar el grupo el aviso se borra: convertido a manual, aprobarlo crearía otra transacción")
    func freeze_deletesTheNotice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let notice = try #require(try pendingNotices(context, s).first)
            let all = try context.fetch(FetchDescriptor<InboxDraft>())
            let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: all)
            #expect(plan.draftsToDelete.contains { $0 === notice })
            #expect(!plan.draftsToConvert.contains { $0 === notice })
            #expect(plan.draftsToConvert.contains { $0.status == .approved }, "la marca sigue su camino de siempre")
        }
    }

    @Test("con la transacción borrada no hay nada que ajustar: el aviso se retira, y ajustar uno huérfano da error")
    func transactionDeleted() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            let real = try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let notice = try #require(try pendingNotices(context, s).first)
            context.delete(real)
            try context.save()

            #expect(throws: DraftServiceError.self) { _ = try adjust(notice) }
            #expect(try bankRows(context, f).isEmpty, "ajustar sin transacción creó una")
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            #expect(try pendingNotices(context, s).isEmpty)
        }
    }

    @Test("«Aprobar todo» no ajusta el aviso: queda pendiente para decidirlo en su hoja")
    func bulkApprove_skipsTheNotice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let notice = try #require(try pendingNotices(context, s).first)
            _ = try DraftService.shared.bulkApprove([notice], currencyConverter: CurrencyConverter())
            #expect(try bankRows(context, f) == [25])
            #expect(try pendingNotices(context, s).count == 1)
        }
    }

    @Test("si la cuenta cambió de divisa el aviso no se aplica: ajustar da error y no toca nada")
    func adjust_afterTheAccountChangedCurrency_refuses() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            let real = try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let notice = try #require(try pendingNotices(context, s).first)
            real.currencyCode = "PEN"
            real.amount = 93
            try context.save()

            #expect(throws: DraftServiceError.self) { _ = try adjust(notice) }
            #expect(try bankRows(context, f) == [93])
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.id])
            #expect(try pendingNotices(context, s).isEmpty)
        }
    }

    @Test("si la liquidación cambia de sentido no hay aviso: ajustar conservaría el signo viejo")
    func directionFlipped_noNotice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            s.fromMemberID = f.me.id.uuidString
            s.toMemberID = f.ana.id.uuidString
            try remoteEdit(context, s, amount: 30)
            #expect(try notices(context, s).isEmpty)
            #expect(try bankRows(context, f) == [25])
        }
    }

    // MARK: - En frío y entre dispositivos

    @Test("en frío avisa de lo que el re-puente no vio, y dos avisos de dos dispositivos quedan en uno")
    func coldStart_createsMissingAndDedupes() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            s.amount = 30
            try context.save()
            #expect(try notices(context, s).isEmpty)

            try GroupTransactionBridge.reconcileSettlementAmountChangeNotices(context: context)
            let first = try #require(try pendingNotices(context, s).first, "el arranque no avisó")

            // Otro dispositivo creó el suyo antes de ver este (llega por el espejo).
            let twin = InboxDraft(note: first.note, amount: 30, date: first.date, account: f.bank,
                                  subcategory: first.subcategory, sourceType: .groupSettlement,
                                  needsUserInput: [], splitGroupZoneID: first.splitGroupZoneID,
                                  splitSettlementID: first.splitSettlementID,
                                  originReasonKey: DraftOriginReason.settlementAmountChanged.rawValue)
            context.insert(twin)
            try context.save()
            twin.createdAt = first.createdAt.addingTimeInterval(60)
            try context.save()
            let firstID = first.persistentModelID
            #expect(try GroupTransactionBridge.reconcileSettlementAmountChangeNotices(context: context) == 1)
            #expect(try pendingNotices(context, s).map(\.persistentModelID) == [firstID],
                    "se conserva el más antiguo: dos dispositivos con los mismos avisos tienen que quedarse con el mismo")
            #expect(try GroupTransactionBridge.reconcileSettlementAmountChangeNotices(context: context) == 0,
                    "una segunda pasada sin nada que hacer volvió a escribir")
        }
    }

    @Test("ajustar desde un aviso duplicado es un ajuste, no una suma, y se lleva el gemelo")
    func adjustIsIdempotentAcrossTwins() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            try remoteEdit(context, s, amount: 30)
            let first = try #require(try pendingNotices(context, s).first)
            let twin = InboxDraft(note: first.note, amount: 30, sourceType: .groupSettlement, needsUserInput: [],
                                  splitSettlementID: first.splitSettlementID,
                                  originReasonKey: DraftOriginReason.settlementAmountChanged.rawValue)
            context.insert(twin)
            try context.save()

            _ = try adjust(first)
            #expect(try bankRows(context, f) == [30])
            #expect(try notices(context, s).isEmpty, "el gemelo sigue preguntando por una corrección ya ajustada")
        }
    }

    @Test("sin vida personal no hay aviso, ni en el re-puente ni en frío")
    func groupsOnly_noNotice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let s = try received(context, f, 25)
            try bridgeAndApprove(context, s, f)
            SessionState.shared.hasPrivateSession = false
            try remoteEdit(context, s, amount: 30)
            #expect(try GroupTransactionBridge.reconcileSettlementAmountChangeNotices(context: context) == 0)
            #expect(try notices(context, s).isEmpty)
        }
    }
}

// MARK: - Cableado del escenario de QA

@Suite("Aviso de importe cambiado: el arg del escenario de QA es el mismo en la app y en el lanzador")
struct SettlementAmountChangeSeedWiringTests {

    @Test("`-uitest-seed-settlement-amount-change` casa entre UITestHooks y launchForUITest")
    func seedArgumentParity() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let hooks = try String(contentsOf: root.appending(path: "Yala/App/UITestHooks.swift"), encoding: .utf8)
        let launcher = try String(
            contentsOf: root.appending(path: "YalaUITests/Support/XCUIApplication+Yala.swift"), encoding: .utf8)
        let literal = "\"-uitest-seed-settlement-amount-change\""
        #expect(hooks.contains("hasArg(\(literal))"), "UITestHooks ya no lee el arg del escenario")
        #expect(launcher.contains("args.append(\(literal))"), "launchForUITest ya no pasa el arg del escenario")
    }
}
