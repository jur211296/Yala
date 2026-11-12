//
//  MemoryDiagnosticsLogicTests.swift
//  YalaTests
//
//  YALA-IOS-B (2026-11-12): el único cierre por memoria de producción llegó a Sentry sin un dato útil. La limpieza
//  borraba el estado de los rastros de ciclo de vida y nadie medía la memoria. Esto fija qué viaja ahora y qué no.
//

import Foundation
import Testing

@testable import Yala

@Suite("Sentry · memoria y pantalla en los avisos")
struct MemoryDiagnosticsLogicTests {

    // MARK: - Limpieza: lo que se conserva

    @Test("un rastro de ciclo de vida conserva su estado, y solo los cuatro conocidos")
    func lifecycleKeepsItsState() {
        for state in ["active", "inactive", "background", "foreground"] {
            let kept = ErrorReportScrubLogic.breadcrumbData(category: "app.lifecycle", type: "navigation", data: ["state": state])
            #expect(kept?["state"] as? String == state)
        }
        let unknown = ErrorReportScrubLogic.breadcrumbData(
            category: "app.lifecycle", type: "navigation", data: ["state": "Cena con Ana", "extra": 1]
        )
        #expect(unknown == nil)
    }

    @Test("un rastro de sistema conserva su acción constante y pierde el resto")
    func deviceEventKeepsOnlyTheAction() {
        let lowMemory = ErrorReportScrubLogic.breadcrumbData(
            category: "device.event", type: "system", data: ["action": "LOW_MEMORY"]
        )
        #expect(lowMemory?["action"] as? String == "LOW_MEMORY")

        let timezone = ErrorReportScrubLogic.breadcrumbData(
            category: "device.event", type: "system",
            data: ["action": "TIMEZONE_CHANGE", "previous_timezone": "America/Lima", "current_timezone": "Europe/Madrid"]
        )
        #expect(timezone?["action"] as? String == "TIMEZONE_CHANGE")
        #expect(timezone?["previous_timezone"] == nil)
        #expect(timezone?["current_timezone"] == nil)

        // Una «acción» que no es un identificador de código no pasa.
        let text = ErrorReportScrubLogic.breadcrumbData(category: "device.event", type: "system", data: ["action": "Pagué S/ 80"])
        #expect(text == nil)
    }

    @Test("un rastro de memoria conserva sus cifras enteras y nada más")
    func memoryKeepsItsFigures() {
        let kept = ErrorReportScrubLogic.breadcrumbData(
            category: MemoryDiagnosticsLogic.memoryCategory, type: nil,
            data: ["footprint_mb": 812, "available_mb": 2100, "step_mb": 768, "nota": "Viaje a Cusco", "footprint_text": "812"]
        )
        #expect(kept?["footprint_mb"] as? Int == 812)
        #expect(kept?["available_mb"] as? Int == 2100)
        #expect(kept?["step_mb"] as? Int == 768)
        #expect(kept?["nota"] == nil)
        #expect(kept?["footprint_text"] == nil)
    }

    @Test("un rastro de pestaña conserva solo los nombres fijos")
    func tabKeepsOnlyKnownNames() {
        let kept = ErrorReportScrubLogic.breadcrumbData(
            category: MemoryDiagnosticsLogic.tabCategory, type: "navigation", data: ["tab": "statistics"]
        )
        #expect(kept?["tab"] as? String == "statistics")
        let title = ErrorReportScrubLogic.breadcrumbData(
            category: MemoryDiagnosticsLogic.tabCategory, type: "navigation", data: ["tab": "Viaje a Cusco"]
        )
        #expect(title == nil)
    }

    @Test("los rastros de interfaz siguen sin datos: pueden llevar títulos con nombres o importes")
    func uiLifecycleStillLosesItsData() {
        let screen = ErrorReportScrubLogic.breadcrumbData(
            category: "ui.lifecycle", type: "navigation", data: ["screen": "UIHostingController", "title": "Viaje a Cusco"]
        )
        #expect(screen == nil)
    }

    @MainActor
    @Test("cada pestaña tiene un nombre fijo que la limpieza deja pasar")
    func everyTabNameIsAllowed() {
        let tabs: [AppTab] = [.panel, .statistics, .planning, .more, .search, .records, .reports, .groups]
        let names = Set(tabs.map(MemoryDiagnosticsLogic.tabName))
        #expect(names == MemoryDiagnosticsLogic.tabNames)
    }

    // MARK: - Cuándo se escribe

    @Test("un escalón se avisa la primera vez que se cruza, y el más alto si salta varios")
    func steps() {
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 0, currentMB: 100) == nil)
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 0, currentMB: 256) == 256)
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 256, currentMB: 300) == nil)
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 300, currentMB: 1100) == 1024)
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 1100, currentMB: 900) == nil)
        #expect(MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: 3000, currentMB: 9000) == 4096)
    }

    @Test("el contexto se reescribe la primera vez, al cambiar de pestaña o con 16 MB de diferencia")
    func republish() {
        #expect(MemoryDiagnosticsLogic.shouldRepublish(lastPublishedMB: nil, currentMB: 80, screenChanged: false))
        #expect(MemoryDiagnosticsLogic.shouldRepublish(lastPublishedMB: 80, currentMB: 80, screenChanged: true))
        #expect(!MemoryDiagnosticsLogic.shouldRepublish(lastPublishedMB: 80, currentMB: 95, screenChanged: false))
        #expect(MemoryDiagnosticsLogic.shouldRepublish(lastPublishedMB: 80, currentMB: 96, screenChanged: false))
        #expect(MemoryDiagnosticsLogic.shouldRepublish(lastPublishedMB: 96, currentMB: 80, screenChanged: false))
    }

    @Test("un aviso de memoria baja manda evento como mucho cada 10 minutos")
    func lowMemoryEventRate() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(MemoryDiagnosticsLogic.shouldSendLowMemoryEvent(lastSentAt: nil, now: start))
        #expect(!MemoryDiagnosticsLogic.shouldSendLowMemoryEvent(lastSentAt: start, now: start.addingTimeInterval(599)))
        #expect(MemoryDiagnosticsLogic.shouldSendLowMemoryEvent(lastSentAt: start, now: start.addingTimeInterval(600)))
        // Un reloj que vuelve atrás no calla el aviso para siempre.
        #expect(MemoryDiagnosticsLogic.shouldSendLowMemoryEvent(lastSentAt: start, now: start.addingTimeInterval(-1)))
    }

    @Test("el contexto lleva cifras y la pestaña, y omite lo que iOS no da")
    func context() {
        let full = MemoryDiagnosticsLogic.context(footprintMB: 900, availableMB: 1200, peakMB: 1000, screen: "records")
        #expect(full["footprint_mb"] as? Int == 900)
        #expect(full["available_mb"] as? Int == 1200)
        #expect(full["peak_mb"] as? Int == 1000)
        #expect(full["screen"] as? String == "records")
        let simulator = MemoryDiagnosticsLogic.context(footprintMB: 90, availableMB: nil, peakMB: 90, screen: nil)
        #expect(simulator["available_mb"] == nil)
        #expect(simulator["screen"] == nil)
    }

    @Test("la memoria se lee y es plausible")
    func footprintReads() throws {
        let sample = try #require(MemoryFootprint.current())
        let mb = MemoryDiagnosticsLogic.megabytes(sample.footprintBytes)
        #expect(mb > 1 && mb < 16_384)
    }

    // MARK: - Cableado

    @Test("Sentry arranca la medida de memoria y la pestaña la avisa")
    func wiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func code(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? String(line) }
                .joined(separator: "\n")
        }
        let service = try code("Yala/Services/ErrorReporting/ErrorReportingService.swift")
        #expect(service.contains("MemoryDiagnostics.shared.start()"))
        // Después de arrancar el SDK: sin SDK, la medida no tiene a dónde mandar nada.
        let sdkStart = try #require(service.range(of: "SentrySDK.start"))
        let diagnosticsStart = try #require(service.range(of: "MemoryDiagnostics.shared.start()"))
        #expect(sdkStart.lowerBound < diagnosticsStart.lowerBound)
        let navigation = try code("Yala/App/Models/SceneNavigation.swift")
        #expect(navigation.contains("MemoryDiagnostics.shared.noteTab(selectedMainTab)"))
        let diagnostics = try code("Yala/Services/ErrorReporting/MemoryDiagnostics.swift")
        #expect(diagnostics.contains("UIApplication.didReceiveMemoryWarningNotification"))
    }
}
