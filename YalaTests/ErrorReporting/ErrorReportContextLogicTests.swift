//
//  ErrorReportContextLogicTests.swift
//  YalaTests
//
//  Con qué entorno y con qué usuario anónimo llega a Sentry un aviso.
//

import Foundation
import Testing

@testable import Yala

@Suite("Sentry · entorno y usuario anónimo")
struct ErrorReportContextLogicTests {

    @Test("una build release de TestFlight va como testflight y la de la App Store como production")
    func releaseSplitsTestFlightFromAppStore() {
        #expect(ErrorReportContextLogic.environment(flavor: .release, receiptFileName: "sandboxReceipt") == "testflight")
        #expect(ErrorReportContextLogic.environment(flavor: .release, receiptFileName: "receipt") == "production")
        // Sin recibo (recién instalada, aún sin descargar) no se inventa TestFlight.
        #expect(ErrorReportContextLogic.environment(flavor: .release, receiptFileName: nil) == "production")
    }

    @Test("las builds de desarrollo no miran el recibo")
    func developmentBuildsIgnoreTheReceipt() {
        #expect(ErrorReportContextLogic.environment(flavor: .development, receiptFileName: "sandboxReceipt") == "development")
        #expect(ErrorReportContextLogic.environment(flavor: .debug, receiptFileName: "sandboxReceipt") == "debug")
    }

    @Test("cuelgues y watchdog en App Store y TestFlight, no en desarrollo")
    func hangTrackingFollowsTheEnvironment() {
        #expect(ErrorReportContextLogic.tracksHangsAndWatchdog(environment: "production"))
        #expect(ErrorReportContextLogic.tracksHangsAndWatchdog(environment: "testflight"))
        #expect(!ErrorReportContextLogic.tracksHangsAndWatchdog(environment: "development"))
        #expect(!ErrorReportContextLogic.tracksHangsAndWatchdog(environment: "debug"))
    }

    @Test("el id de la instalación se conserva si es un UUID y se crea si no")
    func installID() {
        let fixed = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF") ?? UUID()
        let kept = ErrorReportContextLogic.installID(stored: fixed.uuidString, makeNew: { UUID() })
        #expect(kept.id == fixed.uuidString)
        #expect(!kept.isNew)

        for stored in [nil, "", "ana.perez@gmail.com"] as [String?] {
            let made = ErrorReportContextLogic.installID(stored: stored, makeNew: { fixed })
            #expect(made.id == fixed.uuidString)
            #expect(made.isNew)
        }
    }

    @Test("dos instalaciones no comparten id")
    func installIDIsRandom() {
        let a = ErrorReportContextLogic.installID(stored: nil).id
        let b = ErrorReportContextLogic.installID(stored: nil).id
        #expect(a != b)
    }
}
