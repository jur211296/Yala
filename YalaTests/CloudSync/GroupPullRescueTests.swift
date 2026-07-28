//
//  GroupPullRescueTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 2): comportamiento del RESCATE de pull sobre el store — el candado del invariante «el
//  rescate JAMÁS actualiza» y la existencia por id con los helpers concretos.
//
//  POR QUÉ NO SE EJERCITA `handleFetchedRecordZoneChanges` DIRECTAMENTE: su evento
//  (`CKSyncEngine.Event.FetchedRecordZoneChanges`) no es construible desde tests — Apple no expone su
//  init. El reparto es el mismo que ya usa el gate hermano C-4: aquí van la DECISIÓN (gate puro, en
//  `GroupPullRescueGateTests`) y la MUTACIÓN (este archivo), y el cableado del bucle lo pinnea el
//  source-scan de `GroupPullRescueWiringTests`. Las tres piezas juntas cubren el camino entero.
//

import CloudKit
import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("C-4 · rescate de pull (mutación)", .serialized)
struct GroupPullRescueTests {

    private let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-\(UUID().uuidString)")

    private var zoneName: String { zoneID.zoneName }

    // MARK: - Fixtures

    private func expenseRecord(
        id: UUID, amount: Double, description: String, paidBy: String = "member-a"
    ) -> CKRecord {
        typealias F = CKConstants.ExpenseField
        let record = CKRecord(
            recordType: CKConstants.RecordType.splitExpense,
            recordID: CKConstants.recordID(for: id, in: zoneID))
        record.encryptedValues[F.amount] = amount as CKRecordValue
        record.encryptedValues[F.description] = description as CKRecordValue
        record[F.paidByMemberID] = paidBy as CKRecordValue
        record[F.currencyCode] = "PEN" as CKRecordValue
        record[F.splitType] = "equal" as CKRecordValue
        return record
    }

    private func settlementRecord(id: UUID, amount: Double) -> CKRecord {
        typealias F = CKConstants.SettlementField
        let record = CKRecord(
            recordType: CKConstants.RecordType.splitSettlement,
            recordID: CKConstants.recordID(for: id, in: zoneID))
        record.encryptedValues[F.amount] = amount as CKRecordValue
        record[F.fromMemberID] = "member-a" as CKRecordValue
        record[F.toMemberID] = "member-b" as CKRecordValue
        record[F.currencyCode] = "PEN" as CKRecordValue
        return record
    }

    private func shareRecord(id: UUID, expenseID: UUID, amount: Double) -> CKRecord {
        typealias F = CKConstants.ShareField
        let record = CKRecord(
            recordType: CKConstants.RecordType.splitShare,
            recordID: CKConstants.recordID(for: id, in: zoneID))
        record.encryptedValues[F.amount] = amount as CKRecordValue
        record[F.expenseRecordName] = expenseID.uuidString as CKRecordValue
        record[F.memberID] = "member-a" as CKRecordValue
        return record
    }

    // MARK: - Lo que el rescate SÍ hace: adoptar lo nunca visto

    /// El caso que da nombre al ticket: un gasto que un invitado subió a CloudKit después del flip y que
    /// este device no tenía. Sin rescate se descartaba y el token del engine ya había avanzado ⇒ perdido
    /// para siempre.
    @Test func rescuesAnExpenseThatWasNeverSeen() throws {
        let context = try makeTestContext()
        let id = UUID()

        let inserted = SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            expenseRecord(id: id, amount: 42.50, description: "Cena del sábado"),
            context: context, engineName: "private")
        try context.save()

        #expect(inserted)
        let rows = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }))
        #expect(rows.count == 1)
        #expect(rows.first?.amount == 42.50)
        #expect(rows.first?.expenseDescription == "Cena del sábado")
        #expect(rows.first?.groupZoneID == zoneName)
    }

    @Test func rescuesASettlementAndAShareThatWereNeverSeen() throws {
        let context = try makeTestContext()
        let settlementID = UUID()
        let shareID = UUID()
        let expenseID = UUID()

        #expect(SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            settlementRecord(id: settlementID, amount: 15),
            context: context, engineName: "private"))
        #expect(SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            shareRecord(id: shareID, expenseID: expenseID, amount: 7.25),
            context: context, engineName: "private"))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SplitSettlement>(
            predicate: #Predicate { $0.id == settlementID })).first?.amount == 15)
        let share = try context.fetch(FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.id == shareID })).first
        #expect(share?.amount == 7.25)
        #expect(share?.expenseID == expenseID)
    }

    // MARK: - Lo que el rescate NUNCA hace (invariantes 1 y 3)

    /// INVARIANTE 1, el que no se puede romper: el eco stale de un grupo migrado NO se aplica. Si esto
    /// se rompiera, un miembro rezagado volvería a pisar las ediciones backend post-migración — el
    /// agujero exacto que G6-3 (C2) cerró.
    ///
    /// El assert es campo a campo a propósito: un `count == 1` pasaría igual con la fila SOBRESCRITA.
    @Test func neverUpdatesAnExistingRow() throws {
        let context = try makeTestContext()
        let id = UUID()

        let existing = SplitExpense()
        existing.id = id
        existing.groupZoneID = zoneName
        existing.amount = 100
        existing.expenseDescription = "Verdad del backend"
        existing.paidByMemberID = "member-backend"
        context.insert(existing)
        try context.save()

        let inserted = SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            expenseRecord(id: id, amount: 1, description: "Eco stale de CloudKit", paidBy: "member-stale"),
            context: context, engineName: "private")
        try context.save()

        #expect(!inserted)
        let rows = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }))
        #expect(rows.count == 1, "el rescate no debe duplicar")
        #expect(rows.first?.amount == 100, "el rescate NO debe pisar el importe del backend")
        #expect(rows.first?.expenseDescription == "Verdad del backend")
        #expect(rows.first?.paidByMemberID == "member-backend")
    }

    /// INVARIANTE 3: `SplitMember` es PULL-ONLY. Adoptarlo insertaría una fila que el drain del canal
    /// backend descarta sin decir nada.
    @Test func neverRescuesAMember() throws {
        let context = try makeTestContext()
        let id = UUID()
        let record = CKRecord(
            recordType: CKConstants.RecordType.splitMember,
            recordID: CKConstants.recordID(for: id, in: zoneID))
        record[CKConstants.MemberField.displayName] = "Fantasma" as CKRecordValue

        let inserted = SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            record, context: context, engineName: "private")
        try context.save()

        #expect(!inserted)
        #expect(try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == id })).isEmpty)
    }

    /// INVARIANTE 3: el `GroupMeta` de un grupo migrado solo puede traer meta stale — el grupo existe
    /// por definición (es lo que puso su zona en `backendZoneNames`).
    @Test func neverRescuesGroupMeta() throws {
        let context = try makeTestContext()
        let id = UUID()
        let record = CKRecord(
            recordType: CKConstants.RecordType.groupMeta,
            recordID: CKConstants.recordID(for: id, in: zoneID))
        record.encryptedValues[CKConstants.GroupMetaField.name] = "Grupo stale" as CKRecordValue

        let inserted = SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            record, context: context, engineName: "private")
        try context.save()

        #expect(!inserted)
        #expect(try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == id })).isEmpty)
    }

    // MARK: - `recordExistsLocally`: la pregunta que decide

    @Test func existsLocallyAnswersPerTypeById() throws {
        let context = try makeTestContext()
        let presentID = UUID()
        let absentID = UUID()

        let expense = SplitExpense()
        expense.id = presentID
        expense.groupZoneID = zoneName
        context.insert(expense)
        try context.save()

        #expect(SplitSyncManager.shared.recordExistsLocally(
            expenseRecord(id: presentID, amount: 1, description: "x"), context: context))
        #expect(!SplitSyncManager.shared.recordExistsLocally(
            expenseRecord(id: absentID, amount: 1, description: "x"), context: context))
    }

    /// «No sé» se traduce en «existe», nunca en «adóptalo»: un record type desconocido (schema futuro,
    /// record corrupto) no puede abrir la puerta del rescate por omisión.
    @Test func unknownRecordTypeCountsAsExisting() throws {
        let context = try makeTestContext()
        let record = CKRecord(
            recordType: "TipoQueNoExisteTodavia",
            recordID: CKConstants.recordID(for: UUID(), in: zoneID))
        #expect(SplitSyncManager.shared.recordExistsLocally(record, context: context))
        #expect(!SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            record, context: context, engineName: "private"))
    }

    /// Un recordName que no es un UUID no mapea a ninguna fila: tampoco se adopta.
    @Test func nonUUIDRecordNameIsNotRescued() throws {
        let context = try makeTestContext()
        let record = CKRecord(
            recordType: CKConstants.RecordType.splitExpense,
            recordID: CKRecord.ID(recordName: "no-soy-un-uuid", zoneID: zoneID))
        #expect(SplitSyncManager.shared.recordExistsLocally(record, context: context))
        #expect(!SplitSyncManager.shared.applyRemoteRecordIfAbsent(
            record, context: context, engineName: "private"))
        #expect(try context.fetch(FetchDescriptor<SplitExpense>()).isEmpty)
    }

    // MARK: - Idempotencia

    /// Dos entregas del mismo record (re-fetch, batch duplicado) adoptan UNA sola fila. La segunda cae
    /// en la rama del eco stale, que es exactamente lo correcto.
    @Test func rescueIsIdempotent() throws {
        let context = try makeTestContext()
        let id = UUID()
        let record = expenseRecord(id: id, amount: 33, description: "Taxi")

        #expect(SplitSyncManager.shared.applyRemoteRecordIfAbsent(record, context: context, engineName: "private"))
        try context.save()
        #expect(!SplitSyncManager.shared.applyRemoteRecordIfAbsent(record, context: context, engineName: "private"))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })).count == 1)
    }
}
