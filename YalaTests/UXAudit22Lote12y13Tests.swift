//
//  UXAudit22Lote12y13Tests.swift
//  YalaTests
//
//  Implementación de la auditoría UX 2.2, lotes 12 y 13 (Grupos): los pasos de los estados vacíos (L12-2), la hoja
//  «está listo» tras crear (L12-10), invitar desde Miembros (L12-13), los saldos con palabras y «Saldar» solo en lo
//  tuyo (L13-1), confirmar un pago (L13-2) y qué pasó con tu dinero al guardar un gasto (L13-3).
//

import Foundation
import Testing

@testable import Yala

// MARK: - L12-2 · Los pasos del estado vacío

@MainActor
struct GroupsEmptyStepsLogicTests {

    @Test func theThreeSetupStates_markTheirStep() {
        let educational = GroupsEmptyStepsLogic.card(for: .needsEducational, flagOn: true, hasArchivedGroups: false)
        #expect(educational.currentStep == .account)
        #expect(educational.action == .tellMe)
        #expect(educational.showsFootnote)

        let account = GroupsEmptyStepsLogic.card(for: .createAccount, flagOn: true, hasArchivedGroups: false)
        #expect(account.currentStep == .account)
        #expect(account.action == .createAccount)

        let consent = GroupsEmptyStepsLogic.card(for: .needsConsent, flagOn: true, hasArchivedGroups: false)
        #expect(consent.currentStep == .consent)
        #expect(consent.action == .tellMe)
        #expect(consent.showsFootnote)
    }

    /// El educativo va antes que todo; quien ya tiene cuenta (o también aceptó) no ve «Crea tu cuenta» como lo que toca.
    @Test func educational_marksTheFirstStepThatIsReallyMissing() {
        let withSession = GroupsEmptyStepsLogic.card(
            for: .needsEducational, flagOn: true, hasArchivedGroups: false, hasSession: true, isConsented: false)
        #expect(withSession.currentStep == .consent)
        let allDone = GroupsEmptyStepsLogic.card(
            for: .needsEducational, flagOn: true, hasArchivedGroups: false, hasSession: true, isConsented: true)
        #expect(allDone.currentStep == .create)
        #expect(allDone.action == .tellMe)
    }

    @Test func standard_withTheChannelOn_marksTheLastStep_withoutTheFootnote() {
        let card = GroupsEmptyStepsLogic.card(for: .standard, flagOn: true, hasArchivedGroups: false)
        #expect(card.currentStep == .create)
        #expect(card.action == .createGroup)
        #expect(!card.showsFootnote)
    }

    /// Quien ya tuvo grupos (todos archivados) o no tiene canal de cuentas no está ante su «primer grupo».
    @Test func standard_withArchivedGroupsOrChannelOff_hasNoSteps() {
        #expect(GroupsEmptyStepsLogic.card(for: .standard, flagOn: true, hasArchivedGroups: true).currentStep == nil)
        #expect(GroupsEmptyStepsLogic.card(for: .standard, flagOn: false, hasArchivedGroups: false).currentStep == nil)
        #expect(GroupsEmptyStepsLogic.card(for: .standard, flagOn: false, hasArchivedGroups: false).action == .createGroup)
    }

    @Test func signInToView_isNotAFirstGroup() {
        let card = GroupsEmptyStepsLogic.card(for: .signInToView, flagOn: true, hasArchivedGroups: false)
        #expect(card.currentStep == nil)
        #expect(card.action == .signIn)
        #expect(!card.showsSteps)
    }

    /// Cada estado de `GroupsEmptyStateLogic` tiene su tarjeta: un case nuevo que no la tenga no compila aquí y se ve.
    @Test func everyKind_hasACard() {
        for kind in GroupsEmptyStateLogic.Kind.allCases {
            _ = GroupsEmptyStepsLogic.card(for: kind, flagOn: true, hasArchivedGroups: false)
        }
    }

    @Test func stepStates_beforeCurrentAreDone_afterAreUpcoming() {
        #expect(GroupsEmptyStepsLogic.state(of: .account, current: .consent) == .done)
        #expect(GroupsEmptyStepsLogic.state(of: .consent, current: .consent) == .current)
        #expect(GroupsEmptyStepsLogic.state(of: .create, current: .consent) == .upcoming)
        #expect(GroupsEmptyStepsLogic.state(of: .account, current: .account) == .current)
        #expect(GroupsEmptyStepsLogic.state(of: .consent, current: .create) == .done)
    }
}

// MARK: - L13-1 / L13-2 · Saldos

@MainActor
struct GroupBalancesPresentationLogicTests {

    private let me = "me"
    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    @Test func summary_sumsTheDebtsYouSee_perCurrency() throws {
        let debts = [
            debt("beto", me, 110), debt("beto", me, 40, "USD"),
            debt("ana", me, 80), debt("ana", me, 6.67, "USD"),
            debt("beto", "ana", 30),
        ]
        let summary = try #require(GroupBalancesPresentationLogic.summary(debts: debts, currentUserMemberID: me))
        #expect(summary.kind == .owedToMe)
        #expect(summary.owedToMe == [
            .init(currencyCode: "PEN", amount: 190),
            .init(currencyCode: "USD", amount: 46.67),
        ])
        #expect(summary.iOwe.isEmpty)
    }

    /// Lo que se vio en el simulador: el saldo neto por miembro daba $ 46.66 y las deudas de debajo 40.00 + 6.67.
    @Test func summary_agreesWithTheDebtsBelow_toTheCent() throws {
        let summary = try #require(GroupBalancesPresentationLogic.summary(
            debts: [debt("beto", me, 40, "USD"), debt("ana", me, 6.67, "USD")], currentUserMemberID: me))
        let usd = try #require(summary.owedToMe.first)
        #expect(abs(usd.amount - 46.67) < 0.0001)
    }

    @Test func summary_iOwe_andMixedCurrencies() throws {
        let owe = try #require(GroupBalancesPresentationLogic.summary(
            debts: [debt(me, "ana", 25)], currentUserMemberID: me))
        #expect(owe.kind == .iOwe)
        #expect(owe.iOwe == [.init(currencyCode: "PEN", amount: 25)])

        let mixed = try #require(GroupBalancesPresentationLogic.summary(
            debts: [debt("ana", me, 30), debt(me, "beto", 10, "USD")], currentUserMemberID: me))
        #expect(mixed.kind == .owedToMe)
        #expect(mixed.iOwe == [.init(currencyCode: "USD", amount: 10)])
    }

    @Test func summary_settled_andWithoutUser() throws {
        let settled = try #require(GroupBalancesPresentationLogic.summary(
            debts: [debt("beto", "ana", 30)], currentUserMemberID: me))
        #expect(settled.kind == .settled)
        #expect(GroupBalancesPresentationLogic.summary(debts: [debt("beto", me, 1)], currentUserMemberID: nil) == nil)
    }

    /// Las tuyas primero y con botón; las de los demás, después y sin él.
    @Test func debtCards_mineFirst_andOnlyMineInvolveMe() {
        let cards = GroupBalancesPresentationLogic.debtCards(
            debts: [debt("beto", "ana", 30), debt("beto", me, 110), debt(me, "ana", 5), debt("beto", me, 40, "USD")],
            currentUserMemberID: me
        )
        #expect(cards.map(\.id) == ["beto-me", "me-ana", "beto-ana"])
        #expect(cards.map(\.involvesMe) == [true, true, false])
        #expect(cards.map(\.isOwedToMe) == [true, false, false])
        #expect(cards[0].debts.map(\.currencyCode) == ["PEN", "USD"])
    }

    @Test func debtCards_withoutUser_noneInvolveMe() {
        let cards = GroupBalancesPresentationLogic.debtCards(debts: [debt("beto", me, 1)], currentUserMemberID: nil)
        #expect(cards.allSatisfy { !$0.involvesMe })
    }

    @Test func onlyTheReceiver_confirmsAPendingPayment() {
        #expect(GroupBalancesPresentationLogic.needsMyConfirmation(isConfirmed: false, toMemberID: me, currentUserMemberID: me))
        #expect(!GroupBalancesPresentationLogic.needsMyConfirmation(isConfirmed: true, toMemberID: me, currentUserMemberID: me))
        #expect(!GroupBalancesPresentationLogic.needsMyConfirmation(isConfirmed: false, toMemberID: "ana", currentUserMemberID: me))
        #expect(!GroupBalancesPresentationLogic.needsMyConfirmation(isConfirmed: false, toMemberID: me, currentUserMemberID: nil))
    }
}

// MARK: - L13-3 · Qué pasó con tu dinero

@MainActor
struct GroupExpensePersonalOutcomeTests {

    private func outcome(
        caseA: Bool, groupsOnly: Bool = false, bridge: Bool = true, account: String? = "Cuenta Principal",
        creation: Bool = true, optIn: Bool? = nil, myShare: Double = 50
    ) -> GroupExpensePersonalOutcome {
        GroupExpenseSuccessLogic.personalOutcome(
            isCaseA: caseA, isGroupsOnlySession: groupsOnly, bridgeEnabled: bridge, accountName: account,
            isCreation: creation, optInDraftCreated: optIn, myShare: myShare)
    }

    @Test func paidByMe_withTheBridge_chargesTheAccount() {
        #expect(outcome(caseA: true) == .chargedToAccount(accountName: "Cuenta Principal"))
        // En una edición el puente conserva la cuenta original o deja un borrador si cambió la moneda: no se afirma nada.
        #expect(outcome(caseA: true, creation: false) == .none)
        #expect(outcome(caseA: true, account: nil) == .none)
    }

    @Test func paidByMe_bridgeOff_dependsOnTheAnswer() {
        #expect(outcome(caseA: true, bridge: false, optIn: true) == .waitingInInbox)
        #expect(outcome(caseA: true, bridge: false, optIn: false) == .shareAsGroupExpense(amount: 50))
        #expect(outcome(caseA: true, bridge: false, optIn: nil) == .none)
        // En una edición no se sabe si queda la transacción real de un «Sí» anterior.
        #expect(outcome(caseA: true, bridge: false, creation: false, optIn: false) == .none)
    }

    @Test func paidBySomeoneElse_isYourShare() {
        #expect(outcome(caseA: false) == .shareAsGroupExpense(amount: 50))
        #expect(outcome(caseA: false, bridge: false) == .shareAsGroupExpense(amount: 50))
        #expect(outcome(caseA: false, myShare: 0) == .none)
    }

    @Test func groupsOnly_hasNoPersonalFinancesToTalkAbout() {
        #expect(outcome(caseA: true, groupsOnly: true) == .none)
        #expect(outcome(caseA: false, groupsOnly: true) == .none)
    }

    @Test func debtors_leaveYouOut_andEqualPartsSayEach() {
        let parts = [(id: "me", name: "Tú", amount: 50.0), (id: "a", name: "Ana", amount: 50.0),
                     (id: "b", name: "Beto", amount: 50.0)]
        let debtors = GroupExpenseSuccessLogic.debtors(participants: parts, currentUserMemberID: "me")
        #expect(debtors.map(\.name) == ["Ana", "Beto"])
        #expect(GroupExpenseSuccessLogic.allEqual(debtors.map(\.amount)))
        #expect(!GroupExpenseSuccessLogic.allEqual([40, 60]))
        #expect(!GroupExpenseSuccessLogic.allEqual([]))
        // Un céntimo de diferencia ya no es «cada uno»: alguien debe 33,34.
        #expect(!GroupExpenseSuccessLogic.allEqual([33.33, 33.34]))
        #expect(GroupExpenseSuccessLogic.allEqual([33.33, 33.33]))
    }
}

// MARK: - Cableado (source-scan)

@MainActor
struct UXAudit22Lote12y13WiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// L12-10: el formulario apunta el grupo ANTES de cerrarse, y la pestaña abre la hoja en el `onDismiss` del
    /// formulario (no a la vez: dos hojas del mismo ancla no se presentan).
    @Test func createdGroup_reachesTheInviteSheetThroughTheFormDismissal() throws {
        let form = try Self.source("Yala/App/Views/Groups/GroupFormView.swift")
        let backendCase = try #require(form.components(separatedBy: "case .backend:").dropFirst().first?
            .components(separatedBy: "case .needsConsent:").first)
        #expect(backendCase.contains("let created = try await GroupBackendMembershipService("))
        #expect(backendCase.contains("onCreated?(created)"), "el grupo creado no llega a quien abrió el formulario")
        #expect(!backendCase.contains("dismiss()"), "la hoja se cierra antes de apuntar el grupo")

        let tab = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(tab.contains("GroupFormView(group: nil, onCreated: { receiveCreatedGroup($0) })"))
        // Si la persona cerró el formulario mientras se guardaba, su `onDismiss` ya pasó: la hoja se abre en el acto.
        let receive = try #require(tab.components(separatedBy: "private func receiveCreatedGroup(_ group: SplitGroup) {").dropFirst().first)
        let receiveBody = receive.components(separatedBy: "\n    }").first ?? ""
        #expect(receiveBody.contains("if viewModel.showCreateGroup {"))
        #expect(receiveBody.contains("groupReadyToInvite = group"))
        let formSheet = try #require(tab.components(separatedBy: ".sheet(isPresented: $viewModel.showCreateGroup, onDismiss: {").dropFirst().first)
        let onDismissBody = formSheet.components(separatedBy: "}) {").first ?? ""
        #expect(onDismissBody.contains("presentCreatedGroupInviteIfPending()"))
        #expect(tab.contains(".sheet(item: $groupReadyToInvite"))
        #expect(tab.contains("GroupCreatedInviteSheet(group: group"))
    }

    /// El aviso de notificaciones (salta con el primer grupo) espera a la hoja «está listo».
    @Test func notificationPrompt_waitsForTheInviteSheet() throws {
        let tab = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        let fn = try #require(tab.components(separatedBy: "private func maybeShowGroupsNotificationPrompt() {").dropFirst().first)
        let guardBlock = fn.components(separatedBy: "else { return }").first ?? ""
        #expect(guardBlock.contains("groupAwaitingInviteSheet == nil"))
        #expect(guardBlock.contains("groupReadyToInvite == nil"))
    }

    /// L13-1: «Saldar» solo en las deudas tuyas.
    @Test func settleButton_onlyOnDebtsInvolvingYou() throws {
        let view = try Self.source("Yala/App/Views/Groups/GroupBalancesView.swift")
        #expect(view.contains("if card.involvesMe, onSettleDebt != nil {\n                    settleButton(card)"))
        #expect(view.components(separatedBy: "settleButton(card)").count == 2, "«Saldar» se pinta en otro sitio")
    }

    /// L13-2: «No me llegó» pregunta antes; el rechazo solo sale del botón destructivo de la alerta.
    @Test func rejectingAPayment_asksFirst() throws {
        let view = try Self.source("Yala/App/Views/Groups/GroupBalancesView.swift")
        let calls = view.components(separatedBy: "onRejectSettlement?(").count - 1
        #expect(calls == 1, "el rechazo se llama desde \(calls) sitios")
        let alert = try #require(view.components(separatedBy: ".alert(L10n.Groups.Settlement.rejectQuestion").dropFirst().first)
        let alertActions = alert.components(separatedBy: "} message: {").first ?? ""
        #expect(alertActions.contains("onRejectSettlement?(settlement)"))
        #expect(alertActions.contains("Button(L10n.Common.cancel) {"), "la alerta sin «Cancelar» visible")
    }

    /// Quien no es el receptor conserva la forma de quitar un pendiente (antes la ✗ salía en todos), con la misma pregunta.
    @Test func pendingPaymentsOfOthers_canStillBeRemoved() throws {
        let view = try Self.source("Yala/App/Views/Groups/GroupBalancesView.swift")
        let row = try #require(view.components(separatedBy: "private func settlementRow(_ settlement: SplitSettlement) -> some View {").dropFirst().first)
        let pendingBranch = row.components(separatedBy: "} else if settlement.isConfirmed").first ?? ""
        #expect(pendingBranch.contains("if !settlement.isConfirmed, onRejectSettlement != nil {"))
        #expect(pendingBranch.contains("settlementToReject = settlement"))
        #expect(pendingBranch.contains("showRejectConfirm = true"))
    }

    /// L12-2: los estados vacíos de Grupos ya no usan `YalaEmptyState` (icono gris y enlace de texto).
    @Test func groupsEmptyStates_useTheStepsCard() throws {
        let tab = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(!tab.contains("YalaEmptyState."))
        #expect(tab.components(separatedBy: "GroupsEmptyStepsCard(").count - 1 == 5)
    }

    /// L12-13: el aviso del «acceso por enlace» que no se puede apagar ya no sale en Miembros.
    @Test func members_dropTheLinkAccessWarning() throws {
        let view = try Self.source("Yala/App/Views/Groups/GroupMembersView.swift")
        #expect(!view.contains("inviteLinkHint"))
        #expect(view.contains("inviteCard"))
    }
}
