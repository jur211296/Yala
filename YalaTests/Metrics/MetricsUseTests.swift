//
//  MetricsUseTests.swift
//  YalaTests
//
//  Telemetría propia, decisión 1 (opción C de Jürgen, 2026-11-06): «usó esta función», como mucho una vez al día por
//  función, más la oferta de Pro, el límite del plan gratis y los pasos del alta.
//

import Foundation
import Testing
@testable import Yala

private func date(_ iso: String) -> Date {
    guard let d = ISO8601DateFormatter().date(from: iso) else {
        Issue.record("ISO inválida: \(iso)")
        return .distantPast
    }
    return d
}

/// Red que nunca entrega (500): el vaciado corta con `.retry` y lo encolado se queda en la cola para leerlo.
private final class FailingSession: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(), response)
    }
}

@Suite("MetricsUseLogic y catálogo de funciones")
struct MetricsUseCatalogTests {

    @Test func unoAlDia_porFuncion_yDiaUTC() {
        let now = date("2026-11-06T23:30:00Z")
        #expect(MetricsUseLogic.shouldEmit(.panel, lastDays: [:], now: now))
        #expect(!MetricsUseLogic.shouldEmit(.panel, lastDays: ["panel": "2026-11-06"], now: now))
        #expect(MetricsUseLogic.shouldEmit(.panel, lastDays: ["panel": "2026-11-05"], now: now))
        #expect(MetricsUseLogic.shouldEmit(.grupos, lastDays: ["panel": "2026-11-06"], now: now), "cada función lleva su día")
        #expect(MetricsUseLogic.shouldEmit(.panel, lastDays: ["panel": "2026-11-07"], now: now), "reloj rebobinado: emite")
    }

    /// El gateway valida `n` con `[A-Za-z0-9_.-]{1,64}` y rechaza el LOTE ENTERO si uno no casa.
    @Test func todosLosSlugs_pasanLaRegexDelGateway() throws {
        let regex = try Regex("^[A-Za-z0-9_.-]{1,64}$")
        for feature in MetricsUseFeature.allCases {
            #expect(feature.rawValue.wholeMatch(of: regex) != nil, "\(feature.rawValue)")
        }
    }

    /// Cada paso del onboarding tiene su slug en el embudo: un paso nuevo sin él desaparecería del panel.
    @Test func cadaPasoDelOnboarding_tieneSuSlug() {
        for step in OnboardingStep.allCases {
            #expect(MetricsUseFeature.onboardingStep(trackingName: step.trackingName) != nil, "\(step)")
        }
        #expect(MetricsUseFeature.onboardingStep(trackingName: "inventado") == nil)
    }

    @Test func activarYalaCompleto_noCierraUnAlta() {
        #expect(MetricsUseFeature.closesSignUp(mode: "initial"))
        #expect(MetricsUseFeature.closesSignUp(mode: "groupInvite"))
        #expect(MetricsUseFeature.closesSignUp(mode: "groupsOrganizer"))
        #expect(!MetricsUseFeature.closesSignUp(mode: "fullActivation"))
    }

    @MainActor @Test func limiteGratis_soloLosDeCantidad() {
        #expect(MetricsUseFeature.freeLimit(.accounts) == .limiteGratisCuentas)
        #expect(MetricsUseFeature.freeLimit(.budgets) == .limiteGratisPresupuestos)
        #expect(MetricsUseFeature.freeLimit(.voiceInput) == nil, "la prueba de voz la cuenta el servidor")
        #expect(MetricsUseFeature.freeLimit(.chatAssistant) == nil)
    }

    @MainActor @Test func paginas_cuentanLaQueSeVe_yPlanificacionPorSuChip() {
        #expect(MetricsUseTabLogic.feature(displayed: .panel, planning: .budgets) == .panel)
        #expect(MetricsUseTabLogic.feature(displayed: .statistics, planning: .budgets) == .estadisticas)
        #expect(MetricsUseTabLogic.feature(displayed: .planning, planning: .budgets) == .presupuestos)
        #expect(MetricsUseTabLogic.feature(displayed: .planning, planning: .scheduledPayments) == .pagosProgramados)
        #expect(MetricsUseTabLogic.feature(displayed: .groups, planning: .budgets) == .grupos)
        #expect(MetricsUseTabLogic.feature(displayed: .more, planning: .budgets) == nil)
        #expect(MetricsUseTabLogic.feature(displayed: .search, planning: .budgets) == nil)
    }

    /// El panel (`panel/src/labels.ts`) pone nombre a cada slug: uno sin nombre saldría técnico en el panel.
    @Test func elPanelConoceCadaSlug() throws {
        let labels = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("panel/src/labels.ts")
        let source = try String(contentsOf: labels, encoding: .utf8)
        for feature in MetricsUseFeature.allCases where !feature.rawValue.hasPrefix("alta.") {
            let key = feature.rawValue.contains(".") ? "\"\(feature.rawValue)\":" : "\(feature.rawValue):"
            #expect(source.contains(key), "falta \(feature.rawValue) en panel/src/labels.ts")
        }
    }
}

@Suite("MetricsSpool — los `use` ceden su sitio antes que los canarios")
struct MetricsSpoolUseEvictionTests {

    @Test func colaLlena_caeElUseMasViejo_noElCanario() {
        let defaults = makeIsolatedDefaults()
        MetricsSpool.enqueue(.use(.panel), defaults: defaults)
        for i in 0..<(MetricsSpool.capacity - 1) {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        MetricsSpool.enqueue(.canary(name: "nuevo", detail: nil, value: 1), defaults: defaults)
        let pending = MetricsSpool.pending(defaults)
        #expect(pending.count == MetricsSpool.capacity)
        #expect(!pending.contains(.use(.panel)), "se fue el use")
        #expect(pending.first?.n == "c0", "el canario más viejo se queda")
        #expect(pending.last?.n == "nuevo")
    }

    @Test func colaLlenaDeCanarios_unUseNuevo_noEchaANinguno() {
        let defaults = makeIsolatedDefaults()
        for i in 0..<MetricsSpool.capacity {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        MetricsSpool.enqueue(.use(.grupos), defaults: defaults)
        let pending = MetricsSpool.pending(defaults)
        #expect(pending.allSatisfy { $0.e == "canary" })
        #expect(pending.first?.n == "c0")
    }

    @Test func sinUse_siguenCayendoLosMasViejos() {
        let defaults = makeIsolatedDefaults()
        for i in 0..<(MetricsSpool.capacity + 3) {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        #expect(MetricsSpool.pending(defaults).first?.n == "c3")
    }
}

@MainActor
@Suite("MetricsService.used — uno al día y sin servicio nada", .serialized)
struct MetricsServiceUseTests {

    private func withStartedService(_ body: (UserDefaults) -> Void) {
        let defaults = makeIsolatedDefaults()
        MetricsService._testReset()
        MetricsService.start(client: MetricsClient(baseURL: URL(fileURLWithPath: "/"), urlSession: FailingSession()), defaults: defaults)
        defer { MetricsService._testReset() }
        body(defaults)
    }

    @Test func mismoDia_unaVez_otroDia_otra() {
        withStartedService { defaults in
            let day1 = date("2026-11-06T10:00:00Z")
            MetricsService.used(.panel, now: day1)
            MetricsService.used(.panel, now: day1.addingTimeInterval(3600))
            MetricsService.used(.grupos, now: day1)
            MetricsService.used(.panel, now: date("2026-11-07T00:00:01Z"))
            let uses = MetricsSpool.pending(defaults).filter { $0.e == "use" }.compactMap(\.n)
            #expect(uses == ["panel", "grupos", "panel"])
        }
    }

    @Test func altaLocal_cierraElEmbudo_salvoActivarYalaCompleto() {
        withStartedService { defaults in
            MetricsService.localRegistrationCompleted(mode: "fullActivation")
            #expect(!MetricsSpool.pending(defaults).contains(.use(.altaTermina)))
            MetricsService.localRegistrationCompleted(mode: "initial")
            #expect(MetricsSpool.pending(defaults).contains(.use(.altaTermina)))
        }
    }

    @Test func sinServicio_enTests_noEscribeNada() {
        MetricsService._testReset()
        let before = MetricsSpool.pending(.standard).count
        MetricsService.used(.exportar)
        #expect(MetricsSpool.pending(.standard).count == before, "en tests jamás toca .standard")
    }

    @Test func resetLocalState_olvidaLosDias() {
        withStartedService { defaults in
            MetricsService.used(.panel, now: date("2026-11-06T10:00:00Z"))
            MetricsService.resetLocalState(defaults)
            #expect(defaults.dictionary(forKey: MetricsService.useDaysKey) == nil)
        }
    }
}

@Suite("WidgetURLHelper — marca de origen del widget")
struct WidgetSourceMarkerTests {

    @Test func enLaApp_noSeMarca() throws {
        let url = try #require(WidgetURLHelper.url(for: "statistics/insights"))
        #expect(url.absoluteString.hasSuffix("://statistics/insights"))
        #expect(!WidgetURLHelper.cameFromWidget(url))
    }

    @Test func conLaMarca_seReconoce_yLasRutasNoCambian() throws {
        let url = try #require(URL(string: "yala://statistics/trends/in-and-out?src=widget"))
        #expect(WidgetURLHelper.cameFromWidget(url))
        #expect(url.host == "statistics")
        #expect(url.pathComponents == ["/", "trends", "in-and-out"])
        #expect(!WidgetURLHelper.cameFromWidget(try #require(URL(string: "yala://panel?src=otro"))))
    }
}
