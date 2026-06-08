//
//  GroupExpenseViewModelTests.swift
//  YalaTests
//
//  Tests para GroupExpenseViewModel — form state, validation, split calculations.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupExpenseViewModelTests {

    // MARK: - Helpers

    private func makeGroup(currency: String = "USD", defaultSplit: String = "equal") -> SplitGroup {
        let group = SplitGroup()
        group.name = "Test Group"
        group.currencyCode = currency
        group.defaultSplitType = defaultSplit
        return group
    }

    private func makeMembers() -> [SplitMember] {
        let m1 = SplitMember()
        m1.displayName = "Alice"
        m1.isCurrentUser = true

        let m2 = SplitMember()
        m2.displayName = "Bob"
        m2.isCurrentUser = false

        let m3 = SplitMember()
        m3.displayName = "Charlie"
        m3.isCurrentUser = false

        return [m1, m2, m3]
    }

    private func makeLookup(_ members: [SplitMember]) -> [String: String] {
        Dictionary(
            members.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { a, _ in a }
        )
    }

    private func makeViewModel(
        currency: String = "USD",
        defaultSplit: String = "equal"
    ) -> (GroupExpenseViewModel, [SplitMember]) {
        let group = makeGroup(currency: currency, defaultSplit: defaultSplit)
        let members = makeMembers()
        let lookup = makeLookup(members)
        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: lookup)
        return (vm, members)
    }

    // MARK: - Initialization

    @Test func defaultPaidByIsCurrentUser() {
        let (vm, members) = makeViewModel()
        let currentUser = members.first(where: \.isCurrentUser)!
        #expect(vm.paidByMemberID == currentUser.id.uuidString)
    }

    @Test func defaultCurrencyFromGroup() {
        let (vm, _) = makeViewModel(currency: "EUR")
        #expect(vm.currencyCode == "EUR")
    }

    @Test func defaultSplitTypeFromGroup() {
        let (vm, _) = makeViewModel(defaultSplit: "percentage")
        #expect(vm.splitType == .percentage)
    }

    @Test func allMembersSelectedByDefault() {
        let (vm, members) = makeViewModel()
        #expect(vm.selectedMemberIDs.count == members.count)
        for member in members {
            #expect(vm.selectedMemberIDs.contains(member.id.uuidString))
        }
    }

    @Test func inactiveMembersExcludedByDefault() {
        let group = makeGroup()
        let members = makeMembers()
        members[2].memberStatus = .removed
        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: makeLookup(members))

        #expect(vm.selectedMemberIDs.count == 2)
        #expect(!vm.selectedMemberIDs.contains(members[2].id.uuidString))
    }

    @Test func isNotEditModeByDefault() {
        let (vm, _) = makeViewModel()
        #expect(vm.isEditMode == false)
        #expect(vm.editingExpense == nil)
    }

    // MARK: - Validation

    @Test func cannotSaveWithEmptyAmount() {
        let (vm, _) = makeViewModel()
        vm.amountString = ""
        vm.expenseDescription = "Dinner"
        #expect(vm.canSave == false)
        #expect(vm.isAmountValid == false)
    }

    @Test func cannotSaveWithEmptyDescription() {
        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = ""
        #expect(vm.canSave == false)
        #expect(vm.isDescriptionValid == false)
    }

    @Test func cannotSaveWithWhitespaceOnlyDescription() {
        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = "   "
        #expect(vm.isDescriptionValid == false)
    }

    @Test func cannotSaveWithNoMembers() {
        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = "Dinner"
        vm.deselectAllMembers()
        #expect(vm.canSave == false)
        #expect(vm.hasSelectedMembers == false)
    }

    @Test func canSaveWithValidState() {
        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = "Dinner"
        // All members selected by default, split is equal by default.
        // M6: Caso A (Alice = current user = payer default) requiere cuenta personal.
        // Override a `.groupInvite` para skip account requirement (test legacy semantics).
        vm.isGroupInviteOverride = true
        #expect(vm.canSave == true)
    }

    // MARK: - Split Calculations

    @Test func equalSplitCalculatesShares() {
        let (vm, members) = makeViewModel()
        vm.amountString = "90"
        vm.expenseDescription = "Lunch"

        guard let shares = vm.calculatedShares else {
            Issue.record("Expected shares")
            return
        }
        #expect(shares.count == members.count)
        let total = shares.reduce(0.0) { $0 + $1.amount }
        #expect(abs(total - 90) < 0.02)
    }

    @Test func isSharesBalancedForEqualSplit() {
        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = "Test"
        #expect(vm.isSharesBalanced == true)
    }

    // MARK: - Member Selection

    @Test func toggleMemberRemovesAndAdds() {
        let (vm, members) = makeViewModel()
        let id = members[1].id.uuidString

        #expect(vm.selectedMemberIDs.contains(id))
        vm.toggleMember(id)
        #expect(!vm.selectedMemberIDs.contains(id))
        vm.toggleMember(id)
        #expect(vm.selectedMemberIDs.contains(id))
    }

    @Test func selectAllMembersRestoresAll() {
        let (vm, members) = makeViewModel()
        vm.deselectAllMembers()
        #expect(vm.selectedMemberIDs.isEmpty)
        vm.selectAllMembers()
        #expect(vm.selectedMemberIDs.count == members.count)
    }

    @Test func deselectAllClearsSelection() {
        let (vm, _) = makeViewModel()
        vm.deselectAllMembers()
        #expect(vm.selectedMemberIDs.isEmpty)
        #expect(vm.hasSelectedMembers == false)
    }

    // MARK: - Prefill (Edit Mode)

    @Test func prefillSetsEditMode() {
        let (vm, _) = makeViewModel()
        let expense = SplitExpense()
        expense.expenseDescription = "Taxi"
        expense.amount = 50
        expense.currencyCode = "USD"
        expense.paidByMemberID = "member-1"
        expense.splitType = "equal"
        expense.date = .now

        vm.prefill(from: expense, shares: [])
        #expect(vm.isEditMode == true)
        #expect(vm.editingExpense === expense)
        #expect(vm.expenseDescription == "Taxi")
        #expect(vm.currencyCode == "USD")
    }

    @Test func prefillPopulatesSelectedMembers() {
        let (vm, members) = makeViewModel()
        let expense = SplitExpense()
        expense.expenseDescription = "Dinner"
        expense.amount = 100
        expense.splitType = "equal"

        let share1 = SplitShare()
        share1.memberID = members[0].id.uuidString
        share1.amount = 50

        let share2 = SplitShare()
        share2.memberID = members[1].id.uuidString
        share2.amount = 50

        vm.prefill(from: expense, shares: [share1, share2])
        #expect(vm.selectedMemberIDs.count == 2)
        #expect(vm.selectedMemberIDs.contains(members[0].id.uuidString))
        #expect(vm.selectedMemberIDs.contains(members[1].id.uuidString))
        #expect(!vm.selectedMemberIDs.contains(members[2].id.uuidString))
    }

    // MARK: - Save Without Context

    @Test func saveFailsWithoutContext() {
        // El singleton GroupExpenseService.shared puede tener contexto inyectado por
        // AppBootstrapper durante boot del test runner. Limpiarlo para verificar
        // el branch `noContext`.
        GroupExpenseService.shared._testResetContext()

        let (vm, _) = makeViewModel()
        vm.amountString = "100"
        vm.expenseDescription = "Test"
        let result = vm.save()
        #expect(result == false)
    }

    // MARK: - Note preservation regression (refactor mayo 2026)

    /// El form ya no expone `note` field pero el VM debe preservar la nota
    /// histórica al editar una TX antigua que ya la tenía. Este test bloquea
    /// regresiones futuras (alguien eliminando `var note` o cambiando `prefill`).
    @Test func prefillPreservesHistoricalNote() {
        let (vm, _) = makeViewModel()
        let expense = SplitExpense()
        expense.expenseDescription = "Cena Hyatt"
        expense.amount = 100
        expense.currencyCode = "USD"
        expense.splitType = "equal"
        expense.note = "Cumpleaños Mati"
        expense.paidByMemberID = vm.paidByMemberID

        vm.prefill(from: expense, shares: [])

        #expect(vm.note == "Cumpleaños Mati")
    }

    @Test func prefillWithNilNoteResultsInEmptyString() {
        let (vm, _) = makeViewModel()
        let expense = SplitExpense()
        expense.expenseDescription = "X"
        expense.amount = 50
        expense.currencyCode = "USD"
        expense.splitType = "equal"
        expense.note = nil
        expense.paidByMemberID = vm.paidByMemberID

        vm.prefill(from: expense, shares: [])

        #expect(vm.note == "")
    }

    // MARK: - Single Participant (división trivial)

    @Test func multipleParticipantsAreConfigurable() {
        let (vm, _) = makeViewModel()
        // Por default los 3 miembros activos quedan seleccionados.
        #expect(vm.isSplitConfigurable == true)
    }

    @Test func singleParticipantIsNotConfigurable() {
        let (vm, members) = makeViewModel()
        vm.deselectAllMembers()
        vm.toggleMember(members[0].id.uuidString)  // solo el current user
        #expect(vm.selectedMemberIDs.count == 1)
        #expect(vm.isSplitConfigurable == false)
    }

    @Test func singleParticipantIsBalancedEvenWhenTypeWouldUnbalance() {
        // Tipo .percentage sin porcentajes configurados normalmente queda "desbalanceado",
        // pero con un solo participante la división es trivial → balanceada, sin warning.
        let (vm, members) = makeViewModel(defaultSplit: "percentage")
        vm.deselectAllMembers()
        vm.toggleMember(members[0].id.uuidString)

        vm.amountString = "100"
        #expect(vm.isSharesBalanced == true)

        // También con monto en 0 (estado inicial) — no debe marcar desbalance prematuro.
        vm.amountString = "0"
        #expect(vm.isSharesBalanced == true)
    }
}
