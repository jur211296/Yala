//
//  ScheduledPaymentGroupSaveTests.swift
//  YalaTests
//
//  Cubre el path de GRUPO de pagos planificados (gasto compartido recurrente, commit b98f31cd):
//    - `ScheduledPaymentEditorViewModel.savePayment` con config de grupo:
//        `amount` = MI PARTE, `splitTotalAmount` = total de la factura, config de split persistida.
//    - `ScheduledPaymentDraftService.processDuePayments` → `createDraft` (privado, cubierto vía la
//        API pública): la decisión del `GroupScheduledPaymentGate` gobierna si se materializa el
//        `InboxDraft` `.groupScheduledExpense` (proceed crea 1, pause/retryLater NO crean).
//
//  Toca SwiftData + el singleton `iCloudSyncService.shared` (gate de quiescencia de
//  `processDuePayments`) → `@Suite(.serialized)` obligatorio (contrato de `makeTestContext` +
//  regla de singletons) con `_testReset()` en defer.
//
//  NOTA: `createDraft`, `groupGateDecision`, `hasExistingDraft` son `private` en el service; se
//  cubren indirectamente vía `processDuePayments`. La lógica pura del gate y del codec ya tienen
//  sus propios tests (`GroupScheduledPaymentGateTests`, `SplitConfigCodecTests`); aquí se verifica
//  el CABLEADO end-to-end contra un `ModelContext` real.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct ScheduledPaymentGroupSaveTests {

    // Fecha fija en el pasado para que el pago esté "vencido" (nextDueDate <= hoy) de forma
    // determinista sin depender de la hora exacta de ejecución.
    private static func fixedPastDueDate() -> Date {
        var c = DateComponents()
        c.year = 2020
        c.month = 1
        c.day = 15
        c.hour = 12
        return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 1_579_000_000)
    }

    private let me = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private let other = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

    /// Deja el singleton de sync en estado quiescente (import asentado) para que
    /// `processDuePayments` no haga early-return por el gate de quiescencia.
    @MainActor
    private func resetSyncSingleton() {
        iCloudSyncService.shared._testReset()
        // Tras `_testReset`: status = .idle, lastSuccessfulImportDate = nil
        // → SubcategoryDedupGate.decide == .run → isImportQuiescent == true.
        #expect(iCloudSyncService.shared.isImportQuiescent == true)
    }

    // MARK: - savePayment (config de grupo persistida)

    @MainActor @Test func savePayment_group_amountIsMyPart_splitTotalIsInvoiceTotal() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        // Factura total 200, mi parte 80 (reparto exact/percentage).
        let paymentID = vm.savePayment(
            existing: nil,
            name: "Netflix familiar",
            amount: 80,               // MI PARTE
            note: "",
            currencyCode: "PEN",
            transactionType: "expense",
            paymentCategory: .subscription,
            account: nil,
            subcategory: nil,
            selectedTags: [],
            isRecurring: true,
            recurrenceType: .monthly,
            recurrenceInterval: 1,
            paymentDate: Self.fixedPastDueDate(),
            dayOfMonth: 15,
            selectedWeekdays: [],
            yearlyMonth: nil,
            yearlyDay: nil,
            endDate: nil,
            notifyOnDueDate: false,
            notifyDaysBefore: 0,
            isActive: true,
            splitTotalAmount: 200,    // TOTAL de la factura
            groupZoneID: "SplitGroup-ZONE1",
            splitType: "exact",
            splitParticipantIDs: [me, other],
            splitValues: [me: 80, other: 120]
        )

        let id = try #require(paymentID)
        let saved = try #require(fetchPayment(id: id, in: context))

        #expect(saved.amount == 80)               // amount = MI PARTE (no el total)
        #expect(saved.splitTotalAmount == 200)    // splitTotalAmount = total de la factura
    }

    @MainActor @Test func savePayment_group_marksIsGroupPaymentViaZone() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        let id = try #require(saveGroupPayment(vm: vm, zone: "SplitGroup-ZONE2"))
        let saved = try #require(fetchPayment(id: id, in: context))

        #expect(saved.groupZoneID == "SplitGroup-ZONE2")
        #expect(saved.isGroupPayment == true)
    }

    @MainActor @Test func savePayment_group_persistsSplitType() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        let id = try #require(saveGroupPayment(vm: vm, zone: "SplitGroup-ZONE3", splitType: "shares"))
        let saved = try #require(fetchPayment(id: id, in: context))

        #expect(saved.splitType == "shares")
    }

    @MainActor @Test func savePayment_group_persistsParticipantsAsCSV() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        let id = try #require(saveGroupPayment(vm: vm, zone: "SplitGroup-ZONE4"))
        let saved = try #require(fetchPayment(id: id, in: context))

        // El codec ordena y deduplica; el round-trip debe devolver ambos participantes.
        #expect(Set(saved.resolvedParticipantIDs()) == Set([me, other]))
    }

    @MainActor @Test func savePayment_group_persistsPerParticipantValues() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        let id = try #require(saveGroupPayment(
            vm: vm, zone: "SplitGroup-ZONE5", values: [me: 80, other: 120]))
        let saved = try #require(fetchPayment(id: id, in: context))

        let values = saved.resolvedSplitValues()
        #expect(values[me] == 80)
        #expect(values[other] == 120)
    }

    @MainActor @Test func savePayment_editExistingToPersonal_clearsGroupFields() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let vm = ScheduledPaymentEditorViewModel()
        vm.setContext(context, deletionService: EntityDeletionService.shared)

        // 1) Crear como gasto de grupo.
        let id = try #require(saveGroupPayment(vm: vm, zone: "SplitGroup-ZONE6"))
        let saved = try #require(fetchPayment(id: id, in: context))
        #expect(saved.isGroupPayment == true)

        // 2) Editar apagando el toggle de grupo (groupZoneID nil, [] limpia la config).
        _ = vm.savePayment(
            existing: saved,
            name: "Ahora personal",
            amount: 80,
            note: "",
            currencyCode: "PEN",
            transactionType: "expense",
            paymentCategory: .recurring,
            account: nil,
            subcategory: nil,
            selectedTags: [],
            isRecurring: true,
            recurrenceType: .monthly,
            recurrenceInterval: 1,
            paymentDate: Self.fixedPastDueDate(),
            dayOfMonth: 15,
            selectedWeekdays: [],
            yearlyMonth: nil,
            yearlyDay: nil,
            endDate: nil,
            notifyOnDueDate: false,
            notifyDaysBefore: 0,
            isActive: true,
            splitTotalAmount: nil,
            groupZoneID: nil,
            splitType: nil,
            splitParticipantIDs: [],
            splitValues: [:]
        )

        let after = try #require(fetchPayment(id: id, in: context))
        #expect(after.isGroupPayment == false)
        #expect(after.splitTotalAmount == nil)
        #expect(after.resolvedParticipantIDs().isEmpty)
    }

    // MARK: - processDuePayments → createDraft (gate.proceed)

    @MainActor @Test func processDuePayments_gateProceed_createsOneGroupScheduledExpenseDraft() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-PROCEED"
        // Grupo válido (no archivado/oculto) + miembro actual activo → gate.proceed.
        insertGroup(zone: zone, in: context)
        insertCurrentUserMember(zone: zone, status: .active, in: context)
        insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        let created = ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(created == 1)

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.count == 1)
        #expect(drafts.first?.sourceType == .groupScheduledExpense)
    }

    @MainActor @Test func processDuePayments_gateProceed_draftCarriesZoneAndMyPartAmount() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-PROCEED2"
        insertGroup(zone: zone, in: context)
        insertCurrentUserMember(zone: zone, status: .active, in: context)
        insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        _ = ScheduledPaymentDraftService.processDuePayments(context: context)

        let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(draft.splitGroupZoneID == zone)
        // Gasto: el draft guarda el monto con signo negativo = MI PARTE (no el total).
        #expect(draft.amount == -80)
    }

    // MARK: - processDuePayments → gate.pause (grupo archivado)

    @MainActor @Test func processDuePayments_gatePause_archivedGroup_createsNoDraft() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-ARCHIVED"
        let group = insertGroup(zone: zone, in: context)
        group.isArchived = true  // → gate.pause
        insertCurrentUserMember(zone: zone, status: .active, in: context)
        insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        let created = ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(created == 0)

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.isEmpty)
    }

    @MainActor @Test func processDuePayments_gatePause_deactivatesPayment() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-ARCHIVED2"
        let group = insertGroup(zone: zone, in: context)
        group.isArchived = true  // → gate.pause
        insertCurrentUserMember(zone: zone, status: .active, in: context)
        let payment = insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        _ = ScheduledPaymentDraftService.processDuePayments(context: context)

        // pause desactiva el pago para no generar drafts huérfanos.
        #expect(payment.isActive == false)
    }

    @MainActor @Test func processDuePayments_gatePause_memberRemoved_createsNoDraft() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-REMOVED"
        insertGroup(zone: zone, in: context)
        // Miembro presente pero NO activo (removido) → gate.pause.
        insertCurrentUserMember(zone: zone, status: .removed, in: context)
        insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        let created = ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(created == 0)
    }

    // MARK: - processDuePayments → gate.retryLater (grupo aún no sincronizado)

    @MainActor @Test func processDuePayments_gateRetryLater_groupNotSynced_createsNoDraft() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-NOT-SYNCED"
        // NO insertamos SplitGroup ni SplitMember → grupo no existe → gate.retryLater.
        insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        let created = ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(created == 0)

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(drafts.isEmpty)
    }

    @MainActor @Test func processDuePayments_gateRetryLater_doesNotDeactivatePayment() throws {
        let context = try makeTestContext()
        resetSyncSingleton()
        defer { iCloudSyncService.shared._testReset() }

        let zone = "SplitGroup-NOT-SYNCED2"
        // Grupo ausente → race de sync → retryLater: NUNCA pausar (el pago sigue activo).
        let payment = insertDueGroupPayment(zone: zone, myPart: 80, in: context)
        try context.save()

        _ = ScheduledPaymentDraftService.processDuePayments(context: context)

        #expect(payment.isActive == true)
    }

    // MARK: - Helpers

    private func fetchPayment(id: UUID, in context: ModelContext) -> ScheduledPayment? {
        var d = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    /// Guarda un pago de grupo estándar (total 200, mi parte 80) vía la API pública del VM.
    @MainActor
    private func saveGroupPayment(
        vm: ScheduledPaymentEditorViewModel,
        zone: String,
        splitType: String = "exact",
        values: [UUID: Double] = [:]
    ) -> UUID? {
        vm.savePayment(
            existing: nil,
            name: "Grupo",
            amount: 80,
            note: "",
            currencyCode: "PEN",
            transactionType: "expense",
            paymentCategory: .recurring,
            account: nil,
            subcategory: nil,
            selectedTags: [],
            isRecurring: true,
            recurrenceType: .monthly,
            recurrenceInterval: 1,
            paymentDate: Self.fixedPastDueDate(),
            dayOfMonth: 15,
            selectedWeekdays: [],
            yearlyMonth: nil,
            yearlyDay: nil,
            endDate: nil,
            notifyOnDueDate: false,
            notifyDaysBefore: 0,
            isActive: true,
            splitTotalAmount: 200,
            groupZoneID: zone,
            splitType: splitType,
            splitParticipantIDs: [me, other],
            splitValues: values
        )
    }

    @MainActor
    @discardableResult
    private func insertGroup(zone: String, in context: ModelContext) -> SplitGroup {
        let group = SplitGroup(name: "Casa", isOwner: true)
        group.cloudKitZoneID = zone
        context.insert(group)
        return group
    }

    @MainActor
    @discardableResult
    private func insertCurrentUserMember(
        zone: String,
        status: SplitMemberStatus,
        in context: ModelContext
    ) -> SplitMember {
        let member = SplitMember(
            groupZoneID: zone,
            displayName: "Yo",
            status: status,
            isCurrentUser: true
        )
        context.insert(member)
        return member
    }

    /// Inserta un pago planificado de grupo VENCIDO (nextDueDate en el pasado, activo).
    @MainActor
    @discardableResult
    private func insertDueGroupPayment(
        zone: String,
        myPart: Double,
        in context: ModelContext
    ) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: "Servicio compartido",
            amount: myPart,
            currencyCode: "PEN",
            transactionType: "expense",
            nextDueDate: Self.fixedPastDueDate(),
            isActive: true
        )
        payment.groupZoneID = zone
        payment.splitTotalAmount = 200
        payment.splitType = "exact"
        payment.setSplitConfig(participantIDs: [me, other], values: [me: myPart, other: 200 - myPart])
        context.insert(payment)
        return payment
    }
}
