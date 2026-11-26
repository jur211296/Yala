//
//  GuiasSenalanBienTests.swift
//  YalaTests
//
//  Lote 2 de la observación en vivo del iPhone 14 (25-nov-2026): las guías y los avisos señalan donde deben.
//  (1) Las historias de Primeros pasos responden al gesto en toda la zona entre las rayitas y el botón.
//  (2) «Tus presupuestos / pagos / gráficas viven en Más»: la barra de pestañas va desplegada y la pestaña, bordeada.
//  (3) Paso 6: Más se desplaza hasta Estadísticas antes de enmarcar, y al terminar se vuelve al Panel.
//  (4) La intro de Grupos ya aceptada no vuelve tras cerrar sesión.
//

import Foundation
import SwiftUI
import Testing
@testable import Yala

private enum GuiasSource {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GuiasSenalanBien/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// El fichero sin las líneas de comentario: documentar lo que el test busca no lo pone en verde.
    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo que sigue a `marker`, hasta la llave que lo cierra.
    static func body(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker))
        var depth = marker.hasSuffix("{") ? 1 : 0
        var opened = depth > 0
        var result = ""
        for char in code[start.upperBound...] {
            if char == "{" { depth += 1; opened = true }
            if char == "}" { depth -= 1 }
            result.append(char)
            if opened && depth == 0 { break }
        }
        return result
    }
}

// MARK: - 1 · Historias: el gesto vale en toda la zona

@Suite("Guías · las historias responden en toda la zona")
struct GuiasHistoriasZonaTests {

    @Test("el alto mínimo de la zona es lo que el scroll deja ver, sin sus márgenes")
    func stageMinHeight_isTheVisibleScrollArea() {
        #expect(TutorialStoryLogic.stageMinHeight(containerHeight: 600, topInset: 0, bottomInset: 0) == 600)
        #expect(TutorialStoryLogic.stageMinHeight(containerHeight: 600, topInset: 10, bottomInset: 90) == 500)
        // Se redondea hacia abajo: medio punto de más dejaría desplazar una página que cabe.
        #expect(TutorialStoryLogic.stageMinHeight(containerHeight: 600.7, topInset: 0, bottomInset: 0) == 600)
        // Nunca negativo (al montar, el scroll aún no mide nada).
        #expect(TutorialStoryLogic.stageMinHeight(containerHeight: 0, topInset: 10, bottomInset: 90) == 0)
    }

    @Test("la zona que escucha toques y la pausa se estira al alto visible del scroll")
    func stage_stretchesToTheScrollHeight() throws {
        let code = try GuiasSource.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift")
        let page = try GuiasSource.body(after: "struct TutorialStoryPage<", in: code)
        // El marco con el alto mínimo va ANTES del `contentShape` y de los gestos: si va después, la forma tocable es
        // la del contenido corto y la mitad de abajo vuelve a estar muerta.
        let frame = try #require(page.range(of: "minHeight: stageMinHeight"))
        let shape = try #require(page.range(of: ".contentShape(Rectangle())", range: frame.upperBound..<page.endIndex))
        let tap = try #require(page.range(of: ".onTapGesture(coordinateSpace: .local)"))
        let hold = try #require(page.range(of: ".onLongPressGesture(minimumDuration: .infinity"))
        #expect(frame.lowerBound < shape.lowerBound)
        #expect(shape.lowerBound < tap.lowerBound)
        #expect(shape.lowerBound < hold.lowerBound)
        // Y el alto sale del propio scroll, no de un número fijo.
        #expect(page.contains(".onGeometryChange(for: CGFloat.self) { proxy in"))
        #expect(!page.contains(".onScrollGeometryChange("), "No avisa al aparecer: la zona se quedaba corta.")
        #expect(page.contains("TutorialStoryLogic.stageMinHeight("))
        #expect(page.contains("stageMinHeight = height"))
    }
}

// MARK: - 2 · «… viven en Más»: barra desplegada y pestaña bordeada

@Suite("Guías · el aviso de una pestaña la deja a la vista")
@MainActor
struct GuiasPestanaALaVistaTests {

    @Test("solo los momentos que señalan una pestaña de la barra la piden desplegada")
    func pointsAtTabBar_onlyForTabTargets() {
        #expect(PlaceGuideStage.Target.moreTab.pointsAtTabBar)
        #expect(PlaceGuideStage.Target.groupsTab.pointsAtTabBar)
        #expect(!PlaceGuideStage.Target.panelConfigure.pointsAtTabBar)
        #expect(!PlaceGuideStage.Target.panelInbox.pointsAtTabBar)
        #expect(!PlaceGuideStage.Target.moreItems(["budgets"]).pointsAtTabBar)
    }

    @Test("con el aviso de presupuestos, pagos o grupos a la vista, la barra no se encoge; al pasar a Más, sí")
    func center_holdsTheBarWhileATabIsPointedAt() {
        for guide in [PlaceGuide.budgets, .scheduledPayments, .groups] {
            let center = PlaceGuideCenter(defaults: makeIsolatedDefaults())
            #expect(!center.holdsTabBarExpanded)
            #expect(center.start(guide))
            #expect(center.holdsTabBarExpanded, "\(guide) arranca señalando su pestaña")
            if guide == .groups {
                center.advance()
            } else {
                center.tabDidChange(to: .more)
                // Ya en Más: el foco está en las tarjetas, no en la barra.
                #expect(!center.holdsTabBarExpanded)
                center.advance()
            }
            #expect(!center.isActive)
            #expect(!center.holdsTabBarExpanded)
        }
    }

    @Test("la barra queda fija al llegar a una pestaña y mientras la guía señala una")
    func expansionLogic() {
        #expect(!TabBarExpansionLogic.keepsExpanded(arriving: false, guidePointsAtTab: false))
        #expect(TabBarExpansionLogic.keepsExpanded(arriving: true, guidePointsAtTab: false))
        #expect(TabBarExpansionLogic.keepsExpanded(arriving: false, guidePointsAtTab: true))
    }

    @Test("el modificador de la barra lee la guía, y la capa del Panel bordea la pestaña y lo retira al irse")
    func wiring() throws {
        let modifier = try GuiasSource.code("Yala/App/Views/Shared/TabBarArrivesExpandedModifier.swift")
        #expect(modifier.contains("guidePointsAtTab: PlaceGuideCenter.shared.holdsTabBarExpanded"))
        #expect(modifier.contains(".tabBarMinimizeBehavior(keepsExpanded ? .never : .onScrollDown)"))

        let overlay = try GuiasSource.code("Yala/App/Tips/PlaceGuideOverlay.swift")
        let layer = try GuiasSource.body(after: "private struct PanelPlaceGuideLayer: View {", in: overlay)
        #expect(layer.contains("TabBarItemHalo.show(around: frame"))
        #expect(layer.contains(".onDisappear { TabBarItemHalo.hide() }"))
        #expect(layer.contains("guard key.target.pointsAtTabBar"))
        // El borde no se queda con el toque: tocar «Más» tiene que seguir la guía.
        let halo = try GuiasSource.body(after: "enum TabBarItemHalo {", in: overlay)
        #expect(halo.contains("view.isUserInteractionEnabled = false"))
    }

    @Test("el borde rodea el botón de la pestaña con un poco de aire")
    func haloFrame() {
        let item = CGRect(x: 300, y: 800, width: 80, height: 50)
        let ring = PlaceGuideTabHaloLogic.ringFrame(around: item)
        #expect(ring.contains(item))
        #expect(ring.width == item.width + 2 * PlaceGuideTabHaloLogic.outset)
        #expect(ring.midX == item.midX && ring.midY == item.midY)
    }
}

// MARK: - 3 · Paso 6: Estadísticas a la vista y vuelta al Panel

@Suite("Guías · el paso 6 enmarca Estadísticas y vuelve al Panel")
@MainActor
struct GuiasPaso6Tests {

    private let sections: [(MoreSectionKind, [String])] = [
        (.planning, ["budgets", "scheduledPayments"]),
        (.statistics, ["insights", "trends", "categories"]),
        (.reports, ["comparativa"]),
    ]

    @Test("la sección a desplazar es la que contiene lo señalado, en el orden de la persona")
    func sectionContainingTheTarget() {
        #expect(MorePlaceGuideScroll.section(containing: ["insights", "trends", "categories"], in: sections) == .statistics)
        #expect(MorePlaceGuideScroll.section(containing: ["budgets"], in: sections) == .planning)
        #expect(MorePlaceGuideScroll.section(containing: ["scheduledPayments"], in: sections) == .planning)
        #expect(MorePlaceGuideScroll.section(containing: ["nada"], in: sections) == nil)
        #expect(MorePlaceGuideScroll.sectionID(.statistics) != MorePlaceGuideScroll.sectionID(.planning))
    }

    @Test("Más desplaza hasta la sección señalada antes de que la guía enmarque, y cada sección lleva su ancla")
    func moreRevealsTheTarget() throws {
        let code = try GuiasSource.code("Yala/App/Views/More/MoreView.swift")
        #expect(code.contains(".task(id: GuideRevealKey(targetIDs: guideTargetIDs, isShown: isRootPageShown))"))
        let reveal = try GuiasSource.body(after: "private func revealGuideTarget() async {", in: code)
        #expect(reveal.contains("guard isRootPageShown,"), "Desplazar Más oculta no la mueve: espera a que se vea.")
        #expect(code.contains("scrollPosition.scrollTo(id: MorePlaceGuideScroll.sectionID(kind), anchor: .top)"))
        #expect(code.contains(".scrollPosition($scrollPosition)"))
        #expect(code.contains("ForEach(orderedSectionKinds) { kind in"), "El ancla es la identidad que el `ForEach` da a cada sección.")
        #expect(MorePlaceGuideScroll.sectionID(.statistics) == MoreSectionKind.statistics.id)
        let targets = try GuiasSource.body(after: "private var guideTargetIDs: [String]? {", in: code)
        #expect(targets.contains("case .moreItems(let ids) = PlaceGuideCenter.shared.stage?.target"))
    }

    @Test("terminar la guía del paso 6 da el paso por hecho y vuelve al Panel")
    func stepSixFinishesOnThePanel() throws {
        let code = try GuiasSource.code("Yala/App/Views/Panel/PanelView.swift")
        let start = try GuiasSource.body(after: "private func startChartsStepGuide() {", in: code)
        let finish = try GuiasSource.body(after: "let finishAndReturn = {", in: start)
        #expect(finish.contains("markDone()"))
        #expect(finish.contains("navigation.selectMainTab(.panel)"))
        #expect(start.contains("start(.chartsStep, onFinish: finishAndReturn,"))
    }

    @Test("la guía del paso 6 termina con «Entendido» y llama a su cierre; al omitirla, no")
    func chartsStep_finishCallsOnFinish() {
        let center = PlaceGuideCenter(defaults: makeIsolatedDefaults())
        var finished = 0
        var skipped = 0
        #expect(center.start(.chartsStep, onFinish: { finished += 1 }, onSkip: { skipped += 1 }))
        center.tabDidChange(to: .more)
        #expect(center.isActive)
        center.advance()
        #expect(finished == 1 && skipped == 0)
        #expect(!center.isActive)
    }
}

// MARK: - 4 · La intro de Grupos sobrevive al cierre de sesión

@Suite("Guías · la intro de Grupos ya aceptada no vuelve tras cerrar sesión")
@MainActor
struct GuiasIntroGruposTrasCerrarSesionTests {
    private let key = AppPreferences.Keys.hasShownGroupsOnboarding

    @Test("el borrado del cierre de sesión conserva la marca de la intro de Grupos")
    func signOutSweep_keepsTheGroupsIntroMark() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: key)
        defaults.set("keepNot", forKey: "userTheme")

        let kept = SignOutKeptLearning.capture(from: defaults)
        DataWipeService.removeUserPreferenceKeys(from: defaults)
        SignOutKeptLearning.restore(kept, into: defaults)

        #expect(defaults.bool(forKey: key))
        // Lo demás sí se va: solo se conserva la marca de «visto».
        #expect(defaults.object(forKey: "userTheme") == nil)
    }

    @Test("sin la marca puesta, no inventa una")
    func signOutSweep_withoutTheMark_staysUnset() {
        let defaults = makeIsolatedDefaults()
        let kept = SignOutKeptLearning.capture(from: defaults)
        DataWipeService.removeUserPreferenceKeys(from: defaults)
        SignOutKeptLearning.restore(kept, into: defaults)
        #expect(defaults.object(forKey: key) == nil)
    }

    @Test("«Vaciar datos» y «Empezar de cero» la siguen reiniciando")
    func otherSweeps_stillResetIt() {
        let general = makeIsolatedDefaults()
        general.set(true, forKey: key)
        DataWipeService.removeUserPreferenceKeys(from: general)
        #expect(general.object(forKey: key) == nil)

        let groups = makeIsolatedDefaults()
        groups.set(true, forKey: key)
        DataWipeService.removeGroupsDomainPreferenceKeys(from: groups)
        #expect(groups.object(forKey: key) == nil)
    }

    @Test("el reset del cierre de sesión envuelve el barrido con la marca conservada")
    func resetForSignOutWipe_wraps() throws {
        let code = try GuiasSource.code("Yala/Utils/DataWipeService.swift")
        let body = try GuiasSource.body(after: "static func resetForSignOutWipe() {", in: code)
        let capture = try #require(body.range(of: "SignOutKeptLearning.capture(from: UserDefaults.standard)"))
        let sweep = try #require(body.range(of: "resetAllUserPreferences()"))
        let restore = try #require(body.range(of: "SignOutKeptLearning.restore(learned, into: UserDefaults.standard)"))
        #expect(capture.lowerBound < sweep.lowerBound)
        #expect(sweep.lowerBound < restore.lowerBound)
        #expect(SignOutKeptLearning.keys == [AppPreferences.Keys.hasShownGroupsOnboarding])
    }
}
