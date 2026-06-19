//
//  GroupExpenseViewModelM6Tests.swift
//  YalaTests
//
//  M6: validación de canSave + isReady + resetAccountIfIncompatible para Caso A
//  con cuenta personal real seleccionable.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupExpenseViewModelM6Tests {

    // MARK: - Helpers

    private func makeMembers(currentUserID: UUID = UUID(), otherID: UUID = UUID()) -> (current: SplitMember, other: SplitMember) {
        let current = SplitMember(displayName: "Me", isCurrentUser: true)
        // Forzar id estable para identidad consistente.
        current.id = currentUserID
        let other = SplitMember(displayName: "Maria")
        other.id = otherID
        return (current, other)
    }

    private func makeAccount(name: String = "BCP", currency: String = "PEN") -> Account {
        Account(
            name: name,
            currencyCode: currency,
            colorHex: "#000000",
            iconName: "creditcard",
            type: "checking"
        )
    }

    private func makeVM(
        members: [SplitMember],
        currencyCode: String = "PEN",
        isGroupInviteOverride: Bool? = false
    ) -> GroupExpenseViewModel {
        let group = SplitGroup(name: "Test Group", currencyCode: currencyCode)
        let nameLookup = Dictionary(uniqueKeysWithValues: members.map { ($0.id.uuidString, $0.displayName) })
        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: nameLookup)
        vm.currencyCode = currencyCode
        vm.isGroupInviteOverride = isGroupInviteOverride
        // Setup mínimo para satisfacer otros validators de canSave (los M6 son la matriz target).
        vm.amountString = "100"
        vm.expenseDescription = "Cena"
        vm.selectedMemberIDs = Set(members.map { $0.id.uuidString })
        return vm
    }

    // MARK: - isReady

    @Test func isReady_falseWhenNoCurrentUserMember() {
        let other = SplitMember(displayName: "Maria")  // no isCurrentUser
        let vm = makeVM(members: [other])
        #expect(vm.isReady == false)
        #expect(vm.currentUserMemberID == nil)
    }

    @Test func isReady_trueWhenCurrentUserPresent() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other])
        #expect(vm.isReady == true)
        #expect(vm.currentUserMemberID == current.id.uuidString)
    }

    // MARK: - isCaseA

    @Test func isCaseA_trueWhenPaidByMatchesCurrentUser() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other])
        vm.paidByMemberID = current.id.uuidString
        #expect(vm.isCaseA == true)
    }

    @Test func isCaseA_falseWhenPaidByOther() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other])
        vm.paidByMemberID = other.id.uuidString
        #expect(vm.isCaseA == false)
    }

    // MARK: - canSave matriz

    @Test func canSave_falseWhenCaseAFullModeAndNoAccount() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], isGroupInviteOverride: false)
        vm.paidByMemberID = current.id.uuidString
        // selectedAccount = nil → bloqueo
        #expect(vm.isAccountRequired == true)
        #expect(vm.canSave == false)
    }

    @Test func canSave_trueWhenCaseAFullModeAndCompatibleAccount() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], currencyCode: "PEN", isGroupInviteOverride: false)
        vm.paidByMemberID = current.id.uuidString
        vm.selectedAccount = makeAccount(currency: "PEN")
        #expect(vm.isAccountCompatibleWithCurrency == true)
        #expect(vm.canSave == true)
    }

    @Test func canSave_falseWhenCaseACompatibleAccountWrongCurrency() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], currencyCode: "PEN", isGroupInviteOverride: false)
        vm.paidByMemberID = current.id.uuidString
        vm.selectedAccount = makeAccount(currency: "USD")  // mismatch
        #expect(vm.isAccountCompatibleWithCurrency == false)
        #expect(vm.canSave == false)
    }

    @Test func canSave_ignoresAccountWhenCaseB() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], isGroupInviteOverride: false)
        vm.paidByMemberID = other.id.uuidString  // otro pagó
        vm.selectedAccount = nil
        #expect(vm.isAccountRequired == false)
        #expect(vm.canSave == true)
    }

    @Test func canSave_ignoresAccountWhenGroupInviteMode() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], isGroupInviteOverride: true)  // groupInvite
        vm.paidByMemberID = current.id.uuidString  // Caso A
        vm.selectedAccount = nil
        #expect(vm.isAccountRequired == false)  // groupInvite skip
        #expect(vm.canSave == true)
    }

    // MARK: - resetAccountIfIncompatible

    @Test func resetAccountIfIncompatible_clearsOnMismatch() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], currencyCode: "PEN")
        vm.selectedAccount = makeAccount(currency: "USD")
        vm.resetAccountIfIncompatible()
        #expect(vm.selectedAccount == nil)
    }

    @Test func resetAccountIfIncompatible_keepsOnMatch() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other], currencyCode: "PEN")
        let acc = makeAccount(currency: "PEN")
        vm.selectedAccount = acc
        vm.resetAccountIfIncompatible()
        #expect(vm.selectedAccount?.name == acc.name)
    }

    @Test func resetAccountIfIncompatible_noopWhenNil() {
        let (current, other) = makeMembers()
        let vm = makeVM(members: [current, other])
        vm.selectedAccount = nil
        vm.resetAccountIfIncompatible()
        #expect(vm.selectedAccount == nil)
    }
}
