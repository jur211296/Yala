//
//  InboxDismissScheduledDraftCloudTests.swift
//  YalaTests / CloudSync
//
//  Ticket `inbox-dismiss-x-does-not-delete-the-draft-for-good`, modo nube con dos dispositivos. Cada teléfono es
//  un container on-disk propio; lo que uno sube llega al otro por el wire real: las filas de su outbox
//  (`drainOnce`) se vuelven una página del pull (`SyncPullClient.decodePage` + `applyPage`). El arranque es
//  `processDuePayments`, como en `InboxDismissScheduledDraftTests`, que cubre el modo iCloud.
//
//  `.serialized`: dos containers por test y singletons (`DraftService.shared`, `iCloudSyncService.shared`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Bandeja · descartar un pago programado en modo nube (dos dispositivos)", .serialized)
@MainActor
struct InboxDismissScheduledDraftCloudTests {

    init() {
        iCloudSyncService.shared._testReset()
    }

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("InboxDismissCloud-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "IDC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "IDC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "IDC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private let calendar = Calendar.current
    private var dueDate: Date {
        calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: .now)) ?? .now
    }

    /// El mismo pago en los dos teléfonos (misma identidad, como tras sincronizar).
    @discardableResult
    private func insertPayment(id: UUID, _ context: ModelContext) -> ScheduledPayment {
        let payment = ScheduledPayment(name: "Alquiler", amount: 1200, currencyCode: "PEN", nextDueDate: dueDate,
                                       dayOfMonth: calendar.component(.day, from: dueDate), isActive: true)
        payment.id = id
        context.insert(payment)
        return payment
    }

    private func pending(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }
    }

    /// Las filas del outbox de un teléfono (de UNA tabla) como una página del pull del otro.
    private func page(from outbox: [SyncOutbox], table: String, startingAt seq: Int) throws -> PulledPage {
        var serverSeq = seq
        let deltas = outbox.map { row -> String in
            serverSeq += 1
            return """
            {"entity_type":"\(table)","sync_id":"\(row.syncID.uuidString.lowercased())","op":"\(row.opRaw)",
            "fields":\(row.fieldsJSON),"field_hlcs":\(row.fieldHlcsJSON ?? "{}"),
            "hlc":"\(row.hlc)","server_seq":\(serverSeq),"schema_version":1}
            """
        }
        let json = #"{"deltas":[\#(deltas.joined(separator: ","))],"max_server_seq":\#(serverSeq)}"#
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    private func outboxRows(_ context: ModelContext, entity: String) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
            .filter { $0.entityType == entity }
    }

    // MARK: - El otro teléfono trae SU borrador de la ocurrencia descartada

    @Test func theOtherPhonesDraft_arrivingThroughTheCloud_isArchived_notShownAgain() throws {
        let dirA = freshDir(), dirB = freshDir()
        defer { try? FileManager.default.removeItem(at: dirA); try? FileManager.default.removeItem(at: dirB) }
        let a = try makeContext(dirA), b = try makeContext(dirB)
        let paymentID = UUID()

        // B abre la app el día del vencimiento y crea su borrador; lo sube.
        insertPayment(id: paymentID, b)
        try b.save()
        #expect(ScheduledPaymentDraftService.processDuePayments(context: b) == 1)
        let engineB = CloudSyncEngine()
        engineB.drainOnce(context: b)
        let fromB = try outboxRows(b, entity: SyncEntityType.inboxDraft)
        #expect(fromB.count == 1)

        // A crea el suyo y lo descarta con la x.
        let paymentA = insertPayment(id: paymentID, a)
        try a.save()
        ScheduledPaymentDraftService.processDuePayments(context: a)
        let mine = try #require(try pending(a).first)
        DraftService.shared.setContext(a)
        defer { DraftService.shared.setContext(nil) }
        try DraftService.shared.rejectDraft(mine)

        // El pull de A trae el borrador de B.
        let engineA = CloudSyncEngine()
        #expect(engineA.applyPage(try page(from: fromB, table: EntityEmissionMap.inboxDraft.table, startingAt: 0), context: a, now: .now))
        #expect(try pending(a).count == 1, "control: el borrador de B llegó pendiente")

        ScheduledPaymentDraftService.processDuePayments(context: a)
        #expect(try pending(a).isEmpty, "el borrador del otro teléfono volvió a la Bandeja")
        #expect(paymentA.isDateSkipped(dueDate))
    }

    // MARK: - El otro teléfono recibe el salto y archiva su propio borrador

    @Test func theOtherPhone_receivingTheSkipThroughTheCloud_archivesItsOwnDraft() throws {
        let dirA = freshDir(), dirB = freshDir()
        defer { try? FileManager.default.removeItem(at: dirA); try? FileManager.default.removeItem(at: dirB) }
        let a = try makeContext(dirA), b = try makeContext(dirB)
        let paymentID = UUID()

        // B tiene el pago y su borrador pendiente (ya subidos).
        insertPayment(id: paymentID, b)
        try b.save()
        ScheduledPaymentDraftService.processDuePayments(context: b)
        let theirs = try #require(try pending(b).first)
        let engineB = CloudSyncEngine()
        engineB.drainOnce(context: b)
        for row in try b.fetch(FetchDescriptor<SyncOutbox>()) { b.delete(row) }   // ya subidas
        try b.save()

        // A descarta su borrador: el pago sube con la ocurrencia saltada.
        let paymentA = insertPayment(id: paymentID, a)
        try a.save()
        ScheduledPaymentDraftService.processDuePayments(context: a)
        let mine = try #require(try pending(a).first)
        DraftService.shared.setContext(a)
        defer { DraftService.shared.setContext(nil) }
        try DraftService.shared.rejectDraft(mine)
        #expect(paymentA.isDateSkipped(dueDate))
        let engineA = CloudSyncEngine()
        engineA.drainOnce(context: a)
        let fromA = try outboxRows(a, entity: SyncEntityType.scheduledPayment)
        #expect(!fromA.isEmpty)

        // B baja el pago con el salto y arranca.
        #expect(engineB.applyPage(try page(from: fromA, table: EntityEmissionMap.scheduledPayment.table, startingAt: 10), context: b, now: .now))
        let paymentB = try #require(try b.fetch(FetchDescriptor<ScheduledPayment>()).first { $0.id == paymentID })
        #expect(paymentB.isDateSkipped(dueDate), "control: el salto llegó por el wire")

        ScheduledPaymentDraftService.processDuePayments(context: b)
        #expect(theirs.status == .rejected, "el borrador de B seguía en su Bandeja")
        #expect(try pending(b).isEmpty)
    }
}
