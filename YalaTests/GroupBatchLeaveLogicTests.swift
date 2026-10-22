//
//  GroupBatchLeaveLogicTests.swift
//  YalaTests
//
//  Pure-logic del batch "salir de todos mis grupos" (D10): la tabla de clasificación por grupo + el motivo
//  de "necesitan tu decisión" + la terminalidad de fases. Sin SwiftData ni singletons.
//

import Foundation
import Testing

@testable import Yala

struct GroupBatchLeaveLogicTests {

    private func facts(
        isOwner: Bool = false,
        isBackendChannel: Bool = false,
        activeCoMemberCount: Int = 0,
        eligibleHeirCount: Int = 0,
        hasOutstandingDebt: Bool = false
    ) -> GroupBatchLeaveLogic.GroupFacts {
        .init(isOwner: isOwner, isBackendChannel: isBackendChannel,
              activeCoMemberCount: activeCoMemberCount, eligibleHeirCount: eligibleHeirCount,
              hasOutstandingDebt: hasOutstandingDebt)
    }

    // MARK: - classify

    @Test("Con deuda → skipHasDebt (gana sobre todo lo demás)")
    func debtWins() {
        // Aunque sea member, owner-solo, u owner+heredero: la deuda lo saca del batch.
        #expect(GroupBatchLeaveLogic.classify(facts(hasOutstandingDebt: true)) == .skipHasDebt)
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: true, activeCoMemberCount: 2,
                  eligibleHeirCount: 1, hasOutstandingDebt: true)) == .skipHasDebt)
    }

    @Test("Member (no owner) → leave")
    func member() {
        #expect(GroupBatchLeaveLogic.classify(facts(isOwner: false)) == .leave)
        // Aunque sea canal backend con co-members, si no soy owner → leave.
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: false, isBackendChannel: true, activeCoMemberCount: 3)) == .leave)
    }

    @Test("Owner sin co-members activos → deleteSolo")
    func ownerSolo() {
        #expect(GroupBatchLeaveLogic.classify(facts(isOwner: true, activeCoMemberCount: 0)) == .deleteSolo)
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: true, activeCoMemberCount: 0)) == .deleteSolo)
    }

    @Test("Owner + co-members, backend, con heredero elegible → transferThenLeave")
    func ownerBackendWithHeir() {
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: true, activeCoMemberCount: 2,
                  eligibleHeirCount: 1)) == .transferThenLeave)
    }

    @Test("Owner + co-members, backend SIN heredero elegible → needsDecision")
    func ownerBackendNoHeir() {
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: true, activeCoMemberCount: 2,
                  eligibleHeirCount: 0)) == .needsDecision)
    }

    @Test("Owner + co-members, CloudKit-legacy → needsDecision (no se migra, decisión A1)")
    func ownerCloudKitCoMembers() {
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: false, activeCoMemberCount: 2,
                  eligibleHeirCount: 0)) == .needsDecision)
        // Aun con "herederos" contados, sin canal backend NO se transfiere (CloudKit no lo soporta).
        #expect(GroupBatchLeaveLogic.classify(
            facts(isOwner: true, isBackendChannel: false, activeCoMemberCount: 2,
                  eligibleHeirCount: 2)) == .needsDecision)
    }

    // MARK: - needsDecisionReason

    @Test("Motivo: backend sin heredero vs CloudKit owner+co-members")
    func reasons() {
        #expect(GroupBatchLeaveLogic.needsDecisionReason(
            facts(isOwner: true, isBackendChannel: true, activeCoMemberCount: 2)) == .backendNoEligibleHeir)
        #expect(GroupBatchLeaveLogic.needsDecisionReason(
            facts(isOwner: true, isBackendChannel: false, activeCoMemberCount: 2)) == .cloudKitOwnerWithCoMembers)
    }

    // MARK: - isTerminal

    @Test("Fases terminales vs no-terminales")
    func terminality() {
        #expect(GroupBatchLeaveLogic.isTerminal(.done))
        #expect(GroupBatchLeaveLogic.isTerminal(.needsDecision))
        #expect(GroupBatchLeaveLogic.isTerminal(.failed))
        #expect(!GroupBatchLeaveLogic.isTerminal(.pending))
        #expect(!GroupBatchLeaveLogic.isTerminal(.inProgress))
    }
}
