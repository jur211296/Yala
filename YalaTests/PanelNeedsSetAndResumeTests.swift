//
//  PanelNeedsSetAndResumeTests.swift
//  YalaTests
//
//  Lote P2 · rendimiento del Panel (2026-11-04), cards 3, 4 y 5:
//  - con dos necesidades filtradas, el chip y el widget enseñan las dos (`NeedSelectionLogic`, card 2y7e);
//  - la vuelta a primer plano no deja el freno puesto si la escena llega antes que la app (`ForegroundResume`, card n34p);
//  - la foto de los widgets se pide y varias peticiones seguidas son UNA (`WidgetDataCache.updateCache`, card 1hcz).
//

import Foundation
import SwiftData
import Testing
import UIKit

@testable import Yala

private func repoSource(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

// MARK: - Necesidades: un conjunto, no su `.first`

@Suite("Necesidades filtradas: todas, no una")
struct NeedSelectionLogicTests {

    private let point = NeedTrendPoint(date: Date(timeIntervalSince1970: 0), essential: 100, priority: 20, optional: 7,
                                       unclassified: 3)

    @Test("Sin filtro cuenta todo; con dos, la suma de las dos")
    func amount() {
        #expect(NeedSelectionLogic.amount(of: point, for: []) == 130)
        #expect(NeedSelectionLogic.amount(of: point, for: [.essential]) == 100)
        #expect(NeedSelectionLogic.amount(of: point, for: [.essential, .optional]) == 107)
    }

    @Test("Resaltadas: todas sin filtro, solo las elegidas con él")
    func includes() {
        #expect(SubcategoryNeed.allCases.allSatisfy { NeedSelectionLogic.includes($0, in: []) })
        let two: Set<SubcategoryNeed> = [.essential, .optional]
        #expect(NeedSelectionLogic.includes(.essential, in: two))
        #expect(NeedSelectionLogic.includes(.optional, in: two))
        #expect(!NeedSelectionLogic.includes(.priority, in: two))
    }

    @Test("Los chips salen en el orden de la leyenda, sea cual sea el del conjunto")
    func ordered() {
        #expect(NeedSelectionLogic.ordered([.unclassified, .essential, .optional]) == [.essential, .optional, .unclassified])
        #expect(NeedSelectionLogic.ordered([]).isEmpty)
    }

    @Test("El período anterior suma las elegidas que tienen dato; sin ninguna, nil")
    func previousAmount() {
        let byNeed: [SubcategoryNeed: Double] = [.essential: 80, .optional: 5]
        #expect(NeedSelectionLogic.previousAmount(total: 90, byNeed: byNeed, for: []) == 90)
        #expect(NeedSelectionLogic.previousAmount(total: 90, byNeed: byNeed, for: [.essential, .optional]) == 85)
        #expect(NeedSelectionLogic.previousAmount(total: 90, byNeed: byNeed, for: [.priority]) == nil)
    }

    @Test("Tocar una necesidad es «ver solo ésta»; si ya se veía sola, quita el filtro")
    func toggled() {
        #expect(NeedSelectionLogic.toggled(.essential, in: []) == [.essential])
        #expect(NeedSelectionLogic.toggled(.essential, in: [.essential]) == [])
        #expect(NeedSelectionLogic.toggled(.essential, in: [.essential, .optional]) == [.essential])
        #expect(NeedSelectionLogic.toggled(.priority, in: [.essential, .optional]) == [.priority])
    }
}

@MainActor
@Suite("Necesidades: el Panel lee el conjunto entero", .serialized)
struct PanelNeedsSetViewModelTests {

    @Test("Dos necesidades en la sesión → el Panel expone las dos")
    func panelExposesBothNeeds() {
        let saved = SessionState.shared.selectedNeeds
        defer { SessionState.shared.selectedNeeds = saved }
        SessionState.shared.selectedNeeds = [.essential, .optional]
        let viewModel = PanelViewModel()
        #expect(viewModel.selectedNeeds == [.essential, .optional])
        viewModel.toggleNeedFilter(.essential)
        #expect(SessionState.shared.selectedNeeds == [.essential])
        viewModel.toggleNeedFilter(.essential)
        #expect(SessionState.shared.selectedNeeds.isEmpty)
    }

    @Test("Cableado: nadie del Panel ni de Estadísticas colapsa las necesidades a una")
    func noSingleNeedReaders() throws {
        let panel = try repoSource("Yala/App/ViewModels/PanelViewModel.swift")
        #expect(!panel.contains("selectedNeeds.first"))
        #expect(!panel.contains("var selectedNeed:"))
        let widget = try repoSource("Yala/App/Views/Panel/NeedTrendWidget.swift")
        #expect(!widget.contains("selectedNeed:"))
        #expect(!widget.contains("let selectedNeed:"))
        let stats = try repoSource("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(!stats.contains("selectedNeeds.first"))
        let widgetCall = "// El conjunto entero: con dos necesidades filtradas, las dos (card 2y7e).\n            selectedNeeds: viewModel.selectedNeeds,"
        #expect(stats.components(separatedBy: widgetCall).count - 1 == 2, "las dos llamadas a NeedTrendWidget")
        #expect(!stats.contains("selectedNeed: selectedNeed"))
        let bar = try repoSource("Yala/App/Views/Panel/Components/PanelFilterControlBar.swift")
        #expect(bar.contains("ForEach(NeedSelectionLogic.ordered(viewModel.selectedNeeds), id: \\.self) { need in"))
        #expect(bar.contains("viewModel.selectedNeeds.remove(need)"))
    }
}

// MARK: - Volver a primer plano

@MainActor
@Suite("Volver a primer plano no deja el freno puesto", .serialized)
struct ForegroundResumeTests {

    @Test("Con la app activa corre en el acto")
    func activeApp_resumesNow() {
        var resumed = 0
        ForegroundResume.whenApplicationActive("test", isApplicationActive: { true }, center: NotificationCenter()) {
            resumed += 1
        }
        #expect(resumed == 1)
    }

    @Test("Con la escena activa y la app sin activar: espera a didBecomeActive y corre una sola vez")
    func inactiveApp_waitsForActivation_once() async throws {
        let center = NotificationCenter()
        var resumed = 0
        ForegroundResume.whenApplicationActive("test", isApplicationActive: { false }, center: center) {
            resumed += 1
        }
        #expect(resumed == 0, "antes de activarse no suelta el freno")
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        for _ in 0..<50 where resumed == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(resumed == 1)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(resumed == 1, "una espera, una vuelta")
    }

    @Test("Cableado: las seis pantallas con freno sueltan por ForegroundResume, sin el return que lo dejaba puesto")
    func sixScreens_useIt() throws {
        let screens = [
            ("Yala/App/Views/Panel/PanelView.swift", "panel"),
            ("Yala/App/Views/Records/RecordsStandaloneView.swift", "registros"),
            ("Yala/App/Views/Statistics/DetailContainerView.swift", "estadisticas"),
            ("Yala/App/Views/Groups/GroupsContainerView.swift", "grupos"),
            ("Yala/App/Views/Groups/GroupDetailView.swift", "detalle-grupo"),
            ("Yala/App/Views/Reports/FinancialReportView.swift", "informes"),
        ]
        for (path, site) in screens {
            let source = try repoSource(path)
            let start = try #require(source.range(of: "ForegroundResume.whenApplicationActive(\"\(site)\")"), "\(path)")
            let before = source[..<start.lowerBound].suffix(300)
            #expect(before.contains("case .active:"), "\(path): cuelga del case .active del scenePhase")
            #expect(!before.contains("guard UIApplication.shared.applicationState == .active else { return }"), "\(path)")
        }
    }
}

// MARK: - La foto de los widgets

@MainActor
@Suite("La foto de los widgets se pide y se funde", .serialized)
struct WidgetCacheCoalescingTests {

    @Test("Tres peticiones seguidas abren UNA espera; cancelar la olvida")
    func requestsCoalesce() throws {
        let context = try makeTestContext()
        WidgetDataCache.cancelPendingUpdate()
        defer { WidgetDataCache.cancelPendingUpdate() }
        let windows = WidgetDataCache.debugRebuildWindowsOpened
        WidgetDataCache.updateCache(context: context)
        WidgetDataCache.updateCache(context: context)
        WidgetDataCache.updateCache(context: context)
        #expect(WidgetDataCache.debugRebuildWindowsOpened == windows + 1)
        #expect(WidgetDataCache.hasPendingUpdate)
        WidgetDataCache.cancelPendingUpdate()
        #expect(!WidgetDataCache.hasPendingUpdate)
    }

    @Test("Vaciar la caché cancela la foto pedida: no repuebla lo que se acaba de retirar")
    func clearCancelsThePendingRebuild() throws {
        let context = try makeTestContext()
        defer { WidgetDataCache.cancelPendingUpdate() }
        WidgetDataCache.updateCache(context: context)
        #expect(WidgetDataCache.hasPendingUpdate)
        WidgetDataCache.clearCache(in: makeIsolatedDefaults(prefix: "widget-coalesce"))
        #expect(!WidgetDataCache.hasPendingUpdate)
    }

    @Test("Cableado: la foto en el acto es el cuerpo de siempre, y la piden quien no puede esperar")
    func wiring() throws {
        let cache = try repoSource("Yala/Services/WidgetDataCache.swift")
        let now = try #require(cache.range(of: "    static func updateCacheNow(context: ModelContext) {"))
        let body = cache[now.upperBound...].prefix(2600)
        #expect(body.contains("cancelPendingUpdate()"))
        #expect(body.contains("guard !isWipeArmed else {"))
        #expect(body.contains("buildSnapshot(context: context)"))
        #expect(body.contains("saveSnapshot(built.widget)"))
        #expect(body.contains("SiriFinanceSnapshotStore.write(built.siri, to: sharedDefaults)"))
        let clear = try #require(cache.range(of: "    static func clearCache(in defaults: UserDefaults?) {"))
        #expect(cache[clear.upperBound...].prefix(80).contains("cancelPendingUpdate()"))
        let background = try repoSource("Yala/App/BackgroundTaskManager.swift")
        #expect(background.components(separatedBy: "WidgetDataCache.updateCacheNow(").count - 1 == 2)
        #expect(!background.contains("WidgetDataCache.updateCache("))
        let app = try repoSource("Yala/App/YalaApp.swift")
        let bg = try #require(app.range(of: "} else if newPhase == .background {"))
        #expect(app[bg.upperBound...].prefix(3000).contains("WidgetDataCache.flushPendingUpdate()"))
        let boot = try repoSource("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("WidgetGroupsRefresh.shared.setContext(nil)\n        GroupNotificationService.shared.setContext(nil)\n        // Una foto de widgets pedida y aún sin hacer leería el contexto que se suelta (`WidgetDataCache.updateCache`).\n        WidgetDataCache.cancelPendingUpdate()"))
    }
}
