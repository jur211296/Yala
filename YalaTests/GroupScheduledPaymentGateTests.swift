//
//  GroupScheduledPaymentGateTests.swift
//  YalaTests
//
//  Pure-logic tests for `GroupScheduledPaymentGate` — decide si un pago planificado de
//  grupo procede, reintenta (race de sync) o se pausa (grupo inválido / no soy miembro).
//

import Foundation
import Testing

@testable import Yala

@Suite("Group Scheduled Payment Gate")
struct GroupScheduledPaymentGateTests {

    @Test func groupNotFound_retryLater() {
        // No distinguible de "sync pendiente" → nunca pausar.
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: false, isArchived: false, isHidden: false,
            memberExists: false, memberIsActive: false
        ) == .retryLater)
    }

    @Test func archived_pauses() {
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: true, isArchived: true, isHidden: false,
            memberExists: true, memberIsActive: true
        ) == .pause)
    }

    @Test func hidden_pauses() {
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: true, isArchived: false, isHidden: true,
            memberExists: true, memberIsActive: true
        ) == .pause)
    }

    @Test func memberNotFound_retryLater() {
        // Miembro propio aún no sincronizado → reintentar, no pausar.
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: true, isArchived: false, isHidden: false,
            memberExists: false, memberIsActive: false
        ) == .retryLater)
    }

    @Test func memberInactive_pauses() {
        // Removido/salido del grupo → pausar el pago.
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: true, isArchived: false, isHidden: false,
            memberExists: true, memberIsActive: false
        ) == .pause)
    }

    @Test func activeMemberInValidGroup_proceeds() {
        #expect(GroupScheduledPaymentGate.decide(
            groupExists: true, isArchived: false, isHidden: false,
            memberExists: true, memberIsActive: true
        ) == .proceed)
    }
}
