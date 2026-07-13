//
//  GroupAcceptShareErrorLogicTests.swift
//  YalaTests
//
//  Tabla completa de GroupAcceptShareErrorLogic (paquete de endurecimiento
//  Grupos-v1). Pure-logic: sin SwiftData, sin CloudKit real, sin UI.
//

import CloudKit
import Testing

@testable import Yala

@Suite("GroupAcceptShareErrorLogic · clasificación del error de acceptShare")
struct GroupAcceptShareErrorLogicTests {

    @Test func containerNil_enSecundaria_alerta_conCopyPropio() {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: false, isSecondarySession: true, ckErrorCode: nil
        ) == .secondarySession)
    }

    @Test func containerNil_fueraDeSecundaria_noAlerta_esTransitorioConRetry() {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: false, isSecondarySession: false, ckErrorCode: nil
        ) == .containerUnavailable)
    }

    /// El container-nil manda sobre cualquier código de error (no hubo accept que fallara).
    @Test func containerNil_ignoraCKErrorCode() {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: false, isSecondarySession: true, ckErrorCode: .notAuthenticated
        ) == .secondarySession)
    }

    @Test func notAuthenticated_alerta_necesitasICloud() {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: true, isSecondarySession: false, ckErrorCode: .notAuthenticated
        ) == .noICloudAccount)
    }

    @Test(arguments: [
        CKError.Code.networkUnavailable,
        .networkFailure,
        .serviceUnavailable,
        .zoneNotFound,
        .internalError,
    ])
    func otrosCKErrors_caenAlGenerico(_ code: CKError.Code) {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: true, isSecondarySession: false, ckErrorCode: code
        ) == .generic)
    }

    /// Error no-CKError (code nil) → genérico.
    @Test func errorSinCodigoCK_caeAlGenerico() {
        #expect(GroupAcceptShareErrorLogic.classify(
            containerAvailable: true, isSecondarySession: false, ckErrorCode: nil
        ) == .generic)
    }
}
