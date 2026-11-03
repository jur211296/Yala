//
//  ErrorReportingPreviewGateTests.swift
//  YalaTests
//
//  Sentry no arranca dentro de una preview de Xcode (YALA-IOS-3 y YALA-IOS-4, 2026-11-02). Las doce caídas de la app de
//  desarrollo de esa noche eran las previews de «Tu parte» (`GroupSplitLinesCard`): Xcode las corre con la app en el
//  simulador, y su fixture de almacén en memoria con el espejo de iCloud colgado reventaba en el primer fetch
//  («No eligible connection available») o bloqueaba el hilo principal al recrearse en cada redibujo. El fixture se
//  arregló en #738; aquí se fija que una preview no vuelva a mandar nada a Sentry. (Un caso con el fixture viejo pasa en
//  el host de tests, que no cuelga el espejo de iCloud: no reproduce la caída y no se dejó.)
//

import Foundation
import Testing

@testable import Yala

@Suite("Sentry · cuándo arranca")
struct ErrorReportingPreviewGateTests {

    @Test("en la app de verdad, sí")
    func startsInTheRealApp() {
        #expect(ErrorReportingService.shouldStart(isRunningTests: false, isUITest: false, environment: [:]))
        #expect(ErrorReportingService.shouldStart(
            isRunningTests: false, isUITest: false, environment: ["XCODE_RUNNING_FOR_PREVIEWS": "0"]))
    }

    @Test("dentro de una preview de Xcode, no")
    func doesNotStartInAPreview() {
        #expect(!ErrorReportingService.shouldStart(
            isRunningTests: false, isUITest: false, environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]))
    }

    @Test("en unit tests y XCUITest, no")
    func doesNotStartInTests() {
        #expect(!ErrorReportingService.shouldStart(isRunningTests: true, isUITest: false, environment: [:]))
        #expect(!ErrorReportingService.shouldStart(isRunningTests: false, isUITest: true, environment: [:]))
    }
}
