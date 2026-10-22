//
//  GroupScheduledExpenseSingleDraftTests.swift
//  YalaTests
//
//  Ticket `shared-scheduled-expense-shows-twice-in-inbox`: un gasto compartido planificado salía dos
//  veces en la Bandeja.
//
//  Las rutas que CREAN el borrador planificado no duplican (primer caso: las cuatro dejan uno). El
//  segundo borrador nacía al APROBAR: la Bandeja abre el formulario de grupo con importe, reparto,
//  cuenta y fecha del pago, pero sin su categoría. El gasto de grupo nacía sin clasificar y el puente
//  de grupos dejaba otro borrador del mismo gasto —misma nota, mismo importe, misma fecha— pidiendo la
//  categoría que la persona ya había elegido al planificarlo.
//
//  El segundo caso recorre el gesto entero: `processDuePayments` → la plantilla que construye la
//  Bandeja → `GroupExpenseViewModel.applyTemplate` + `save()` → el puente → el cierre del ciclo
//  (`handleGroupScheduledExpenseApproved`). El puente se llama a mano con `shouldSave: false`, que es
//  lo mismo que hace `createExpense` salvo el `save()` con efectos de app que tumban el runner (R8): por
//  eso el VM guarda con el puente sin contexto y el test lo puentea justo después, como `createExpense`.
//
//  El tercero es el barrido de los teléfonos que ya tienen ese segundo borrador.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Pago compartido planificado · un solo borrador en la Bandeja", .serialized)
@MainActor
struct GroupScheduledExpenseSingleDraftTests {

    // MARK: - Montaje

    private struct Escena {
        let context: ModelContext
        let group: SplitGroup
        let members: [SplitMember]
        let account: Account
        let subcategory: Subcategory
        let payment: ScheduledPayment
    }

    private static func pastDueDate() -> Date {
        var c = DateComponents()
        c.year = 2020; c.month = 1; c.day = 15; c.hour = 12
        return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 1_579_000_000)
    }

    /// Grupo de dos (yo pago: Caso A), cuenta real PEN, una categoría del usuario y un pago planificado
    /// de grupo VENCIDO con esa categoría y esa cuenta, a partes iguales sobre 100.
    private func montar(subcategoryOnPayment: Bool = true) throws -> Escena {
        let context = try makeTestContext()
        iCloudSyncService.shared._testReset()
        #expect(iCloudSyncService.shared.isImportQuiescent == true)

        let group = SplitGroup(name: "Casa", currencyCode: "PEN")
        group.defaultSplitType = "equal"
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(me); context.insert(ana)

        let account = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let category = makeTestCategory(context: context, name: "Hogar")
        let subcategory = makeTestSubcategory(context: context, name: "Streaming", category: category)

        let payment = ScheduledPayment(
            name: "Netflix familiar",
            amount: 50,                       // mi parte
            currencyCode: "PEN",
            transactionType: "expense",
            account: account,
            subcategory: subcategoryOnPayment ? subcategory : nil,
            nextDueDate: Self.pastDueDate(),
            dayOfMonth: 15,
            isActive: true
        )
        payment.groupZoneID = group.cloudKitZoneID
        payment.splitTotalAmount = 100
        payment.splitType = "equal"
        payment.setSplitConfig(participantIDs: [me.id, ana.id], values: [:])
        context.insert(payment)
        try context.save()

        return Escena(context: context, group: group, members: [me, ana], account: account,
                      subcategory: subcategory, payment: payment)
    }

    private func pendientes(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.statusRaw == "pending" }))
    }

    private func conEntornoDeGrupos(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        let sesionPrivadaPrevia = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true   // Caso A con cuenta real exige sesión privada
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupTransactionBridge.shared._testClearContext()
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            SessionState.shared.hasPrivateSession = sesionPrivadaPrevia
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            iCloudSyncService.shared._testReset()
        }
        try body()
    }

    /// Lo que hace la Bandeja al aprobar el borrador planificado, en el orden de `GroupExpenseFormView`.
    private func aprobarDesdeLaBandeja(_ draft: InboxDraft, _ e: Escena) throws -> String {
        let template = GroupScheduledExpenseTemplateLogic.buildTemplate(
            payment: e.payment, draftDate: draft.effectiveDate
        )
        let lookup = Dictionary(e.members.map { ($0.id.uuidString, $0.displayName) }, uniquingKeysWith: { a, _ in a })
        let vm = GroupExpenseViewModel(group: e.group, members: e.members, memberNameLookup: lookup)
        vm.setContext(e.context)
        vm.isGroupsOnlyOverride = false
        vm.applyTemplate(template)
        #expect(vm.canSave)

        // El puente sin contexto mientras guarda el VM: `createExpense` no puentea y no corre el `save()` R8.
        GroupTransactionBridge.shared._testClearContext()
        #expect(vm.save())
        let expenseID = try #require(vm.lastCreatedExpenseID)
        let expenseUUID = try #require(UUID(uuidString: expenseID))
        let expense = try #require(try e.context.fetch(
            FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseUUID })).first)

        // Lo mismo que `createExpense` cuando el puente está listo, con el `save()` a mano.
        GroupTransactionBridge.shared.setContext(e.context)
        let atendido = try GroupTransactionBridge.shared.bridgeExpense(
            expense, in: e.group, accountForCurrentUser: vm.selectedAccount, shouldSave: false
        )
        #expect(atendido)
        try e.context.save()

        // `onExpenseCreated` del formulario.
        ScheduledPaymentDraftService.handleGroupScheduledExpenseApproved(
            draft: draft, expenseID: expenseID, context: e.context
        )
        return expenseID
    }

    // MARK: - Las rutas que crean el borrador

    @Test("arranque, primer plano, adelantar y des-saltar dejan UN solo borrador pendiente")
    func lasRutasDeCreacionDejanUnSoloBorrador() throws {
        let e = try montar()
        defer { iCloudSyncService.shared._testReset() }

        #expect(ScheduledPaymentDraftService.processDuePayments(context: e.context) == 1)  // arranque
        #expect(ScheduledPaymentDraftService.processDuePayments(context: e.context) == 0)  // primer plano
        #expect(ScheduledPaymentDraftService.createAdvancedDraft(from: e.payment, context: e.context) == nil)
        ScheduledPaymentDraftService.recreateDraftIfNeeded(for: e.payment, date: Self.pastDueDate(), context: e.context)
        try e.context.save()

        let drafts = try pendientes(e.context)
        #expect(drafts.count == 1)
        #expect(drafts.first?.sourceType == .groupScheduledExpense)
        #expect(drafts.first?.sourceScheduledPaymentID == e.payment.id.uuidString)
    }

    // MARK: - Aprobar

    @Test("aprobar el planificado no deja otro borrador del mismo gasto, y el gasto nace con su categoría")
    func aprobarNoDejaOtroBorrador() throws {
        let e = try montar()
        try conEntornoDeGrupos(e.context) {
            #expect(ScheduledPaymentDraftService.processDuePayments(context: e.context) == 1)
            let draft = try #require(try pendientes(e.context).first)

            let expenseID = try aprobarDesdeLaBandeja(draft, e)

            let quedan = try pendientes(e.context)
            #expect(quedan.isEmpty, """
                Tras aprobar el gasto compartido planificado quedan \(quedan.count) borradores pendientes \
                (\(quedan.map { "\($0.sourceTypeRaw) \($0.needsUserInput)" })). Es el doble del ticket: el \
                gasto nació sin la categoría del pago y el puente pidió elegirla otra vez.
                """)

            let real = try e.context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID == expenseID }))
                .filter { $0.account?.isSystemAccount == false }
            #expect(real.count == 1)                                   // control: el puente sí creó la real
            #expect(real.first?.subcategory?.id == e.subcategory.id)
            #expect(real.first?.scheduledPaymentID == e.payment.id.uuidString)
        }
    }

    @Test("CONTROL: un pago planificado SIN categoría sigue pidiéndola al aprobar")
    func sinCategoriaSiguePidiendola() throws {
        let e = try montar(subcategoryOnPayment: false)
        try conEntornoDeGrupos(e.context) {
            #expect(ScheduledPaymentDraftService.processDuePayments(context: e.context) == 1)
            let draft = try #require(try pendientes(e.context).first)

            _ = try aprobarDesdeLaBandeja(draft, e)

            // Sin categoría que heredar, el gasto nace sin clasificar y el puente la pide: es correcto.
            let quedan = try pendientes(e.context)
            #expect(quedan.count == 1)
            #expect(quedan.first?.sourceType == .groupExpense)
            #expect(quedan.first?.needsUserInput == [DraftInputRequirement.subcategory])
        }
    }

    // MARK: - Barrido de lo que ya está en los teléfonos

    /// El estado que deja aprobar un planificado ANTES del arreglo: la transacción real del gasto, enlazada al pago y
    /// sin categoría, más el borrador pendiente que solo pide categoría. El pago queda en el futuro para que
    /// `processDuePayments` no cree nada y solo corra el barrido.
    private struct Herencia {
        let real: TransactionItem
        let pointer: InboxDraft
    }

    private func sembrarHerencia(
        _ e: Escena,
        linkToPayment: Bool = true,
        optIn: Bool = false,
        needs: [String] = [DraftInputRequirement.subcategory]
    ) throws -> Herencia {
        e.payment.nextDueDate = Date(timeIntervalSince1970: 4_102_444_800)  // 2100: no vence
        let expenseID = UUID().uuidString
        let real = TransactionItem(date: Self.pastDueDate(), amount: -100, currencyCode: "PEN",
                                   note: "Netflix familiar", account: e.account)
        real.splitExpenseID = expenseID
        real.splitGroupZoneID = e.group.cloudKitZoneID
        if linkToPayment { real.scheduledPaymentID = e.payment.id.uuidString }
        e.context.insert(real)
        let pointer = InboxDraft(
            note: "Netflix familiar", amount: -100, date: Self.pastDueDate(), account: e.account,
            subcategory: nil, sourceType: .groupExpense, confidenceAmount: 1, confidenceDate: 1,
            confidenceMerchant: 1, confidenceSubcategory: nil, needsUserInput: needs,
            splitExpenseID: expenseID, splitGroupZoneID: e.group.cloudKitZoneID, splitSettlementID: nil,
            targetTransactionID: nil, optInPersonalOnly: optIn
        )
        e.context.insert(pointer)
        try e.context.save()
        return Herencia(real: real, pointer: pointer)
    }

    @Test("el barrido resuelve el «elige categoría» de un planificado ya aprobado, y es idempotente")
    func barridoResuelveYEsIdempotente() throws {
        let e = try montar()
        defer { iCloudSyncService.shared._testReset() }
        let h = try sembrarHerencia(e)

        _ = ScheduledPaymentDraftService.processDuePayments(context: e.context)
        #expect(try pendientes(e.context).isEmpty)
        #expect(h.real.subcategory?.id == e.subcategory.id)
        #expect(h.real.category?.id == e.subcategory.safeCategory.id)

        _ = ScheduledPaymentDraftService.processDuePayments(context: e.context)
        #expect(try pendientes(e.context).isEmpty)
        #expect(h.real.subcategory?.id == e.subcategory.id)
    }

    @Test("CONTROL: el barrido no toca lo que no prueba que venga de un planificado con categoría",
          arguments: ["sinEnlace", "pagoSinCategoria", "optIn", "pideCuenta", "yaClasificada"])
    func barridoNoTocaLoQueNoPrueba(_ caso: String) throws {
        let e = try montar(subcategoryOnPayment: caso != "pagoSinCategoria")
        defer { iCloudSyncService.shared._testReset() }
        let h = try sembrarHerencia(
            e,
            linkToPayment: caso != "sinEnlace",
            optIn: caso == "optIn",
            needs: caso == "pideCuenta"
                ? [DraftInputRequirement.account, DraftInputRequirement.subcategory]
                : [DraftInputRequirement.subcategory]
        )
        let otra = makeTestSubcategory(context: e.context, name: "Otra", category: e.subcategory.safeCategory)
        if caso == "yaClasificada" { h.real.subcategory = otra }
        try e.context.save()

        _ = ScheduledPaymentDraftService.processDuePayments(context: e.context)

        #expect(try pendientes(e.context).count == 1, "caso \(caso): el barrido se llevó un borrador que no le toca")
        #expect(h.real.subcategory?.id == (caso == "yaClasificada" ? otra.id : nil),
                "caso \(caso): el barrido cambió la categoría de la transacción")
    }
}
