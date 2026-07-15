//
//  GroupCreateRoutingLogicTests.swift
//  YalaTests
//
//  Tabla del routing de CREAR GRUPO (G5-A, contrato C3). Pure-logic sin SwiftData/CloudKit.
//

import Testing

@testable import Yala

@Suite("GroupCreateRoutingLogic · routing de crear grupo (G5-A)")
struct GroupCreateRoutingLogicTests {

    typealias Route = GroupCreateRoutingLogic.Route

    // MARK: - Flag OFF → SIEMPRE cloudKit (byte-idéntico, sin importar sesión/consent)

    @Test func flagOff_alwaysCloudKit_regardlessOfSessionAndConsent() {
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: false, consentAccepted: false) == .cloudKit)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: false) == .cloudKit)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: false, consentAccepted: true) == .cloudKit)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: true) == .cloudKit)
    }

    // MARK: - Flag ON → precedencia sign-in → consent → backend

    @Test func flagOn_noSession_needsSignIn() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: false, consentAccepted: false) == .needsSignIn)
        // Sin sesión, el consent no importa: sign-in primero.
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: false, consentAccepted: true) == .needsSignIn)
    }

    @Test func flagOn_sessionButNoConsent_needsConsent() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: true, consentAccepted: false) == .needsConsent)
    }

    @Test func flagOn_sessionAndConsent_backend() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: true, consentAccepted: true) == .backend)
    }
}
