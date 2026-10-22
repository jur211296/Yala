//
//  InboxGroupDraftsHiddenHereTests.swift
//  YalaTests
//
//  Un gasto de grupo cuyo grupo no está en este teléfono se quita de la Bandeja SOLO aquí, sin tocar ninguna fila (nada
//  viaja al otro dispositivo), y vuelve si el grupo llega. Ticket `prior-icloud-group-records-summed-without-their-group`.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID` y vacía el store en cada llamada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bandeja · quitar de aquí · la regla")
struct InboxGroupDraftHiddenHereLogicTests {

    private func shape(
        _ source: DraftSourceType = .groupExpense, status: DraftStatus = .pending,
        expenseID: String? = "E1", groupHere: Bool = false
    ) -> InboxGroupDraftHiddenHereLogic.DraftShape {
        .init(sourceType: source, status: status, expenseID: expenseID, groupExistsHere: groupHere)
    }

    @Test("Solo un gasto de grupo pendiente, con gasto conocido y sin su grupo aquí")
    func canHideHere() {
        #expect(InboxGroupDraftHiddenHereLogic.canHideHere(shape()))
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(groupHere: true)))
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(status: .rejected)))
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(expenseID: nil)))
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(expenseID: "")))
        // Las liquidaciones ya se rechazan y se borran; los demás borradores no son de grupo.
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(.groupSettlement)))
        #expect(!InboxGroupDraftHiddenHereLogic.canHideHere(shape(.voice)))
    }

    @Test("Oculto mientras su gasto esté en la lista y el grupo siga sin estar; vuelve si el grupo llega")
    func isHidden() {
        #expect(InboxGroupDraftHiddenHereLogic.isHidden(shape(), hiddenExpenseIDs: ["E1"]))
        #expect(!InboxGroupDraftHiddenHereLogic.isHidden(shape(), hiddenExpenseIDs: ["E2"]))
        #expect(!InboxGroupDraftHiddenHereLogic.isHidden(shape(groupHere: true), hiddenExpenseIDs: ["E1"]))
    }
}

@MainActor
@Suite("Bandeja · quitar de aquí · con el store", .serialized)
struct InboxGroupDraftsHiddenHereStoreTests {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// El borrador que deja «Sumarlos a mis datos»: un gasto de grupo de un grupo que no está en este teléfono.
    @discardableResult
    private func groupDraft(_ context: ModelContext, expenseID: String = UUID().uuidString, zone: String = "zona-ajena")
        -> InboxDraft {
        let draft = InboxDraft(
            note: "Cena del viaje", amount: -20, date: .now, account: nil, subcategory: nil,
            sourceType: .groupExpense, confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1,
            confidenceSubcategory: nil, needsUserInput: [DraftInputRequirement.account],
            splitExpenseID: expenseID, splitGroupZoneID: zone, splitSettlementID: nil, targetTransactionID: nil)
        context.insert(draft)
        return draft
    }

    @Test func sinSuGrupo_seOfrece_yAlQuitarlo_dejaDeVerse() throws {
        let context = try makeTestContext()
        let d = defaults()
        let draft = groupDraft(context)
        try context.save()

        #expect(InboxGroupDraftsHiddenHere.hideableIDs(in: [draft], context: context) == [draft.persistentModelID])
        #expect(InboxGroupDraftsHiddenHere.hide(draft, context: context, d))
        #expect(InboxGroupDraftsHiddenHere.visible([draft], context: context, d).isEmpty)
    }

    /// El criterio del ticket: quitarlo aquí no le quita nada al otro dispositivo. Todo lo que viaja (espejo de iCloud,
    /// drain de la nube) sale de una fila cambiada, y aquí no cambia ninguna: el contexto no queda sucio, el borrador
    /// sigue pendiente con sus punteros y la cuenta de filas es la misma.
    @Test func quitarloAqui_noCambiaNingunaFila() throws {
        let context = try makeTestContext()
        let d = defaults()
        let expenseID = UUID().uuidString
        let draft = groupDraft(context, expenseID: expenseID)
        try context.save()
        let before = try context.fetchCount(FetchDescriptor<InboxDraft>())

        #expect(InboxGroupDraftsHiddenHere.hide(draft, context: context, d))

        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == before)
        let stored = try #require(try context.fetch(FetchDescriptor<InboxDraft>()).first)
        #expect(stored.status == .pending)
        #expect(stored.splitExpenseID == expenseID)
        #expect(stored.sourceType == .groupExpense)
        #expect(stored.needsUserInput == [DraftInputRequirement.account])
    }

    /// Control del anterior: rechazar —la salida que el ticket descarta— SÍ cambia la fila, y por eso viajaría.
    @Test func control_rechazar_siCambiaLaFila() throws {
        let context = try makeTestContext()
        let draft = InboxDraft(
            note: "Café", amount: -5, date: .now, account: nil, subcategory: nil, sourceType: .voice,
            confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1, confidenceSubcategory: nil,
            needsUserInput: [], splitExpenseID: nil, splitGroupZoneID: nil, splitSettlementID: nil,
            targetTransactionID: nil)
        context.insert(draft)
        try context.save()

        draft.status = .rejected
        #expect(context.hasChanges)
        context.rollback()
    }

    /// Si el grupo llega (el otro dispositivo, o el canal de Grupos de esta cuenta), el borrador vuelve a salir solo.
    @Test func siElGrupoLlega_vuelveASalir() throws {
        let context = try makeTestContext()
        let d = defaults()
        let draft = groupDraft(context, zone: "zona-que-llega")
        try context.save()
        #expect(InboxGroupDraftsHiddenHere.hide(draft, context: context, d))

        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = "zona-que-llega"
        context.insert(group)
        try context.save()

        #expect(InboxGroupDraftsHiddenHere.visible([draft], context: context, d) == [draft])
        #expect(InboxGroupDraftsHiddenHere.hideableIDs(in: [draft], context: context).isEmpty)
    }

    /// Con su gasto aquí (aunque la zona no case), el grupo está: no se ofrece ni se oculta.
    @Test func conSuGastoAqui_noSeOfrece() throws {
        let context = try makeTestContext()
        let d = defaults()
        let expense = SplitExpense(groupZoneID: "otra-zona", amount: 20, currencyCode: "PEN")
        context.insert(expense)
        let draft = groupDraft(context, expenseID: expense.id.uuidString)
        try context.save()

        #expect(InboxGroupDraftsHiddenHere.hideableIDs(in: [draft], context: context).isEmpty)
        #expect(!InboxGroupDraftsHiddenHere.hide(draft, context: context, d))
        #expect(InboxGroupDraftsHiddenHere.hiddenExpenseIDs(d).isEmpty)
    }

    /// La clave es el gasto, no el borrador: el otro dispositivo re-puentea y crea un borrador NUEVO del mismo gasto que
    /// baja por el espejo. Ese también queda oculto.
    @Test func unBorradorNuevoDelMismoGasto_sigueOculto() throws {
        let context = try makeTestContext()
        let d = defaults()
        let expenseID = UUID().uuidString
        let first = groupDraft(context, expenseID: expenseID)
        try context.save()
        #expect(InboxGroupDraftsHiddenHere.hide(first, context: context, d))

        let second = groupDraft(context, expenseID: expenseID)
        try context.save()

        #expect(InboxGroupDraftsHiddenHere.visible([first, second], context: context, d).isEmpty)
    }

    /// Los demás borradores no se tocan.
    @Test func losDemasBorradores_siguenViendose() throws {
        let context = try makeTestContext()
        let d = defaults()
        let hidden = groupDraft(context)
        let other = groupDraft(context)
        try context.save()
        #expect(InboxGroupDraftsHiddenHere.hide(hidden, context: context, d))

        #expect(InboxGroupDraftsHiddenHere.visible([hidden, other], context: context, d) == [other])
    }

    /// El borrado de datos retira la lista con las demás claves que salen de las filas.
    @Test func vaciarDatos_retiraLaLista() {
        let d = defaults()
        d.set(["E1"], forKey: InboxGroupDraftsHiddenHere.key)
        DataWipeService.removeRowDerivedKeys(from: d)
        #expect(InboxGroupDraftsHiddenHere.hiddenExpenseIDs(d).isEmpty)
    }

    /// La Bandeja (lista y recuento) y el contador del Panel leen la misma lista. Usa `UserDefaults.standard` porque es
    /// el que leen los view models; restaura lo que hubiera.
    @Test func bandejaYPanel_noCuentanElOculto() throws {
        let context = try makeTestContext()
        let draft = groupDraft(context)
        try context.save()
        let previous = UserDefaults.standard.object(forKey: InboxGroupDraftsHiddenHere.key)
        defer { UserDefaults.standard.set(previous, forKey: InboxGroupDraftsHiddenHere.key) }
        UserDefaults.standard.removeObject(forKey: InboxGroupDraftsHiddenHere.key)
        #expect(InboxGroupDraftsHiddenHere.hide(draft, context: context))

        let inbox = InboxViewModel()
        inbox.setContext(context)
        inbox.loadData()
        #expect(inbox.pendingDrafts.isEmpty)
        #expect(inbox.countForFilter(.pending) == 0)

        let panel = PanelViewModel()
        panel.setContext(context, defaultCurrencyCode: "PEN", sessionState: SessionState.shared)
        panel.loadData()
        #expect(panel.pendingDrafts.isEmpty)
    }
}
