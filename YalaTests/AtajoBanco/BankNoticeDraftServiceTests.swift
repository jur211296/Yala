//
//  BankNoticeDraftServiceTests.swift
//  YalaTests
//
//  Atajo del banco (2.3, B1): de la cola del App Group a la Bandeja. La cola va aislada por suite (`pendingStoreDefaults`)
//  y la última cuenta usada del App Group real la aísla `.lastUsedAccountIsolated`, como en `ApplePayDraftServiceTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct BankNoticeDraftServiceTests {

    private let pendingDefaults: UserDefaults

    init() {
        pendingDefaults = testDefaults(suiteName: "test.banknotice.drafts.\(UUID().uuidString)")!
        iCloudSyncService.shared._testReset()
    }

    private let bcpText = "Consumo con tu tarjeta\nRealizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."

    private func enqueue(_ text: String, bank: BankNoticeBank? = .bcp, at time: Double = 1_800_000_000) {
        let reading = BankNoticeParser.read(text, bankHint: bank) ?? .notUnderstood
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: text, bank: bank, reading: reading, receivedAt: time),
            defaults: pendingDefaults)
    }

    private func process(_ context: ModelContext) -> Int {
        BankNoticeDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: true)
    }

    private func drafts(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>())
    }

    @Test("Un aviso del BCP queda en la Bandeja como gasto por confirmar, con su origen y su texto")
    func bcpNotice_becomesAPendingExpenseDraft() throws {
        let context = try makeTestContext()
        let soles = makeTestAccount(context: context, name: "Débito BCP", currencyCode: "PEN")
        try context.save()
        enqueue(bcpText)

        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.amount == -12.5)
        #expect(draft.note == "TAMBO+ MIRAFLORES")
        #expect(draft.status == .pending)
        #expect(draft.sourceType == .automation)
        #expect(draft.evidence == "BCP")
        #expect(draft.rawText == bcpText)
        #expect(draft.account?.shortcutID == soles.shortcutID)
        #expect(draft.confidenceAmount == 1.0)
        #expect(draft.date == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(BankNoticePendingStore.peekAll(defaults: pendingDefaults).isEmpty, "consume-after-save")
    }

    @Test("Un pago recibido por Yape entra en positivo")
    func yapeIncome_isPositive() throws {
        let context = try makeTestContext()
        enqueue("Yape! Juan Pérez te envió un pago por S/ 10.00", bank: .yape)
        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.amount == 10)
        #expect(draft.note == "Juan Pérez")
        #expect(draft.evidence == "Yape")
    }

    @Test("Sin cuenta en esa moneda, el borrador pide la cuenta")
    func noMatchingAccount_asksForIt() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Euros", currencyCode: "EUR")
        try context.save()
        enqueue(bcpText)
        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.account == nil)
        #expect(draft.needsUserInput.contains("account"))
    }

    @Test("«No entendimos este aviso»: borrador sin importe con el texto del aviso para completarlo")
    func notUnderstood_leavesADraftToComplete() throws {
        let context = try makeTestContext()
        let text = "Operación por USD 12.00 en AMZN Mktp US*2K4"
        enqueue(text)
        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.amount == nil)
        #expect(draft.note == text)
        #expect(draft.rawText == text)
        #expect(draft.needsUserInput.contains("amount"))
        #expect(draft.evidence == "BCP")
    }

    @Test("Un aviso largo que no se entendió se recorta en la descripción, pero el texto entero se guarda")
    func notUnderstood_longText_isTrimmedInTheNote() throws {
        let context = try makeTestContext()
        let text = String(repeating: "Aviso raro sin importe ", count: 20)
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: text, bank: .bcp, reading: .notUnderstood, receivedAt: 1), defaults: pendingDefaults)
        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.note.count == BankNoticeDraftService.notUnderstoodNoteLimit)
        #expect(draft.note.hasSuffix("…"))
        #expect(draft.rawText == text)
    }

    @Test("«No era una compra» que llegue a la cola se descarta sin borrador")
    func notAMovement_isDropped() throws {
        let context = try makeTestContext()
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: "clave", bank: .bcp, reading: .notAMovement, receivedAt: 1), defaults: pendingDefaults)
        #expect(process(context) == 0)
        #expect(try drafts(context).isEmpty)
        #expect(BankNoticePendingStore.peekAll(defaults: pendingDefaults).isEmpty)
    }

    @Test("Dos pasadas no duplican")
    func idempotent() throws {
        let context = try makeTestContext()
        enqueue(bcpText)
        #expect(process(context) == 1)
        #expect(process(context) == 0)
        #expect(try drafts(context).count == 1)
    }

    @Test("Con el import de iCloud en curso no consume nada")
    func importNotQuiescent_keepsTheQueue() throws {
        let context = try makeTestContext()
        enqueue(bcpText)
        #expect(BankNoticeDraftService.processPending(context: context, pendingStoreDefaults: pendingDefaults, importQuiescent: false) == 0)
        #expect(BankNoticePendingStore.peekAll(defaults: pendingDefaults).count == 1)
    }

    @Test("La subcategoría la pone lo que Yala recuerda del comercio")
    func merchantMemory_setsTheSubcategory() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context, name: "Comida")
        let sub = makeTestSubcategory(context: context, name: "Supermercado", category: category)
        context.insert(MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize("TAMBO+ MIRAFLORES"), subcategory: sub,
            countApproved: 6, countCorrected: 0, lastApprovedAt: .now, aliases: ["TAMBO+ MIRAFLORES"]))
        try context.save()
        enqueue(bcpText)
        #expect(process(context) == 1)
        let draft = try #require(try drafts(context).first)
        #expect(draft.subcategory?.shortcutID == sub.shortcutID)
    }
}

@Suite("Atajo del banco · origen en la Bandeja")
@MainActor
struct BankNoticeOriginTests {

    @Test("Un borrador del atajo dice el banco; sin importe, «No entendimos este aviso»")
    func label() {
        let withAmount = BankNoticeOrigin.label(sourceType: .automation, evidence: "BCP", hasAmount: true)
        #expect(withAmount == String(format: BankNoticeOrigin.localized("inbox.sourceBankNotice"), "BCP"))
        #expect(withAmount?.contains("BCP") == true)
        let notUnderstood = BankNoticeOrigin.label(sourceType: .automation, evidence: "Yape", hasAmount: false)
        #expect(notUnderstood == BankNoticeOrigin.localized("inbox.sourceBankNoticeNotUnderstood"))
        #expect(BankNoticeOrigin.label(sourceType: .automation, evidence: "Aviso", hasAmount: true)
                == BankNoticeOrigin.localized("inbox.sourceBankNoticeOther"))
    }

    @Test("Las claves existen: no se enseña la clave cruda")
    func keysResolve() {
        for key in ["inbox.sourceBankNotice", "inbox.sourceBankNoticeOther", "inbox.sourceBankNoticeNotUnderstood"] {
            #expect(BankNoticeOrigin.localized(key) != key, "\(key)")
        }
    }

    @Test("Los demás `.automation` (Yala web) y los otros orígenes no cambian")
    func otherDrafts_keepTheirLabel() {
        #expect(BankNoticeOrigin.label(sourceType: .automation, evidence: WebDraftLogic.evidence, hasAmount: true) == nil)
        #expect(BankNoticeOrigin.label(sourceType: .automation, evidence: nil, hasAmount: true) == nil)
        #expect(BankNoticeOrigin.label(sourceType: .applePay, evidence: "BCP", hasAmount: true) == nil)
    }

    @Test("La fila de la Bandeja usa la etiqueta del aviso")
    func inboxRow_usesTheLabel() {
        let draft = InboxDraft(note: "TAMBO+", amount: -12.5, sourceType: .automation, evidence: "BCP")
        #expect(draft.sourceDisplayName == BankNoticeOrigin.label(sourceType: .automation, evidence: "BCP", hasAmount: true))
        let web = InboxDraft(note: "x", amount: -1, sourceType: .automation, evidence: WebDraftLogic.evidence)
        #expect(web.sourceDisplayName == L10n.Inbox.sourceAutomation)
    }
}

@Suite("Atajo del banco · cableado (source-scan)")
struct BankNoticeWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("La purga de las fronteras de cuenta vacía también la cola de avisos del banco")
    func purgeCoversTheQueue() throws {
        let src = try Self.source("Yala/Services/CloudSync/AppGroupInboundPurge.swift")
        #expect(src.contains("BankNoticePendingStore.remove(keys: BankNoticePendingStore.peekAll().map(\\.key))"))
    }

    @Test("La acción no toca SwiftData, no enseña UI y no manda notificación propia (A5)")
    func intentStaysInTheBackground() throws {
        let src = try Self.source("Yala/App/Intents/BankNoticeIntent.swift")
        #expect(src.contains("static var openAppWhenRun: Bool = false"))
        #expect(!src.contains("ModelContainer"))
        #expect(!src.contains("ProvidesDialog"))
        #expect(!src.contains("sendNotification"))
        #expect(src.contains("GroupsOnlyIntentGate.current()"))
    }

    @Test("La acción de prueba que emite avisos solo existe en DEBUG")
    func testEmitterIsDebugOnly() throws {
        let src = try Self.source("Yala/App/Intents/BankNoticeTestEmitIntent.swift")
        let code = src.components(separatedBy: "\n").filter { !$0.hasPrefix("//") }.joined(separator: "\n")
        #expect(code.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#if DEBUG"))
        #expect(code.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("#endif"))
    }
}
