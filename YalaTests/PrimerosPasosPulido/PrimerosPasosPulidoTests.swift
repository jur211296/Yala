//
//  PrimerosPasosPulidoTests.swift
//  YalaTests
//
//  El pulido de Primeros pasos del 2026-11-20 (build 2.3 (5), notas de Jürgen del 19-nov): intros como historias,
//  nombre de la cuenta precargado, campos legibles, cards vecinas del mismo alto, «Día» y su número alineados, volver
//  un paso sin perder lo escrito, «No deseo crear…», los textos nuevos de los pasos 3 y 4, la guía de «Más» y el paso 6.
//  La parte que se ve la fija `YalaUITests/PrimerosPasosPulido/PrimerosPasosPulidoCapturasUITests`.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Yala

private enum PulidoSource {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PrimerosPasosPulido/
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

    static func swiftFiles(in directory: String) throws -> [String] {
        let url = repoRoot.appendingPathComponent(directory)
        return try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0.hasSuffix(".swift") }
            .map { "\(directory)/\($0)" }
            .sorted()
    }
}

// MARK: - 1 · Intros como historias

@Suite("Pulido Primeros pasos · intros como historias")
struct PrimerosPasosPulidoStoryTests {

    @Test("la mitad derecha avanza, la izquierda vuelve, sin dar la vuelta")
    func halvesStepWithoutWrapping() {
        #expect(TutorialStoryLogic.stepped(part: 0, by: 1, count: 3) == 1)
        #expect(TutorialStoryLogic.stepped(part: 1, by: -1, count: 3) == 0)
        #expect(TutorialStoryLogic.stepped(part: 0, by: -1, count: 3) == 0, "en la primera, la izquierda no hace nada")
        #expect(TutorialStoryLogic.stepped(part: 2, by: 1, count: 3) == 2, "en la última, la derecha no hace nada")
        #expect(TutorialStoryLogic.tapped(part: 2, count: 3) == 2)
        // La regla de las mitades es la del Welcome.
        #expect(WelcomeShowcaseLogic.tapStep(atX: 300, width: 400) == 1)
        #expect(WelcomeShowcaseLogic.tapStep(atX: 100, width: 400) == -1)
    }

    @Test("soltar tras mantener no cambia de parte; un toque corto sí")
    func holdIsNotATap() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        #expect(TutorialStoryLogic.wasAHold(pressedAt: now.addingTimeInterval(-2), now: now))
        #expect(!TutorialStoryLogic.wasAHold(pressedAt: now.addingTimeInterval(-0.1), now: now))
        #expect(!TutorialStoryLogic.wasAHold(pressedAt: nil, now: now))
    }

    @Test("con el dedo puesto no avanza sola")
    func pausedDoesNotAdvance() {
        #expect(TutorialStoryLogic.advancesAutomatically(part: 0, count: 3, reduceMotion: false, voiceOver: false))
        #expect(!TutorialStoryLogic.advancesAutomatically(part: 0, count: 3, reduceMotion: false, voiceOver: false,
                                                          paused: true))
    }

    @Test("la pausa congela la barra y al soltar sigue con lo que le quedaba")
    func pauseFreezesTheBar() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let dwell = TutorialStoryLogic.seconds(TutorialStoryLogic.partDuration)
        #expect(abs(dwell - 3.4) < 0.001)
        var clock = WelcomeShowcaseLogic.StoryClock.started(at: start, running: true)
        clock.pause(at: start.addingTimeInterval(1.7))
        #expect(abs(clock.progress(at: start.addingTimeInterval(10), dwell: dwell) - 0.5) < 0.001)
        clock.resume(at: start.addingTimeInterval(10))
        #expect(abs(clock.remaining(at: start.addingTimeInterval(10), dwell: dwell) - 1.7) < 0.001)
    }

    @Test("la página toca por mitades, pausa al mantener y llena las barras con el reloj")
    func pageWiring() throws {
        let page = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift")
        #expect(page.contains("WelcomeShowcaseLogic.tapStep("))
        #expect(page.contains("onLongPressGesture(minimumDuration: .infinity"))
        #expect(page.contains("paused = pressing"))
        #expect(page.contains("guard !held else { return }"))
        #expect(page.contains("WelcomeShowcaseLogic.segmentFill("))
        #expect(page.contains("if nowPaused { clock.pause(at: .now) }"))
    }

    @Test("las intros de los pasos 2, 3 y 4 no llevan «Omitir»")
    func introsHaveNoSkip() throws {
        let planning = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/PlanningIntroPages.swift")
        #expect(!planning.contains("skipStep"))
        #expect(!planning.contains("onSkip"))
        let record = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/RecordTutorialView.swift")
        #expect(!record.contains("record_tutorial_skip_step"))
        for flow in ["FirstBudgetFlowView", "FirstScheduledPaymentFlowView"] {
            let code = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/\(flow).swift")
            #expect(!code.contains("onSkip:"), "\(flow) aún pasa «Omitir» a su intro")
        }
    }
}

// MARK: - 2 y 6 · Cuenta: nombre precargado y volver sin perder lo escrito

@Suite("Pulido Primeros pasos · el nombre y volver un paso")
struct PrimerosPasosPulidoAccountTests {
    typealias Kind = FirstAccountFlowLogic.Kind

    @Test("el nombre llega con el del tipo elegido, también en tarjeta y bancos")
    func nameArrivesWithTheKindName() {
        #expect(FirstAccountFlowView.prefilledName(current: "", kind: .cash) == L10n.Account.AccountType.cash)
        #expect(FirstAccountFlowView.prefilledName(current: "", kind: .creditCard)
                == Kind.creditCard.accountType.localizedName)
        #expect(FirstAccountFlowView.prefilledName(current: "", kind: .checking)
                == Kind.checking.accountType.localizedName)
    }

    @Test("lo escrito se conserva al volver; el nombre de otro tipo se cambia por el del nuevo")
    func typedNameSurvives() {
        #expect(FirstAccountFlowView.prefilledName(current: "Visa del trabajo", kind: .creditCard) == "Visa del trabajo")
        let cash = FirstAccountFlowView.suggestedName(for: .cash)
        #expect(FirstAccountFlowView.prefilledName(current: cash, kind: .creditCard)
                == FirstAccountFlowView.suggestedName(for: .creditCard))
    }

    @Test("un saldo contestado vuelve como se escribe y se vuelve a leer igual")
    func amountRoundTrips() {
        let us = Locale(identifier: "en_US")
        #expect(FirstAccountFlowView.editableAmount(620, locale: us) == "620")
        #expect(FirstAccountFlowView.editableAmount(-620, locale: us) == "620", "la tarjeta guarda la deuda en negativo")
        #expect(FirstAccountFlowView.editableAmount(1200.5, locale: us) == "1200.5", "sin separador de miles")
        #expect(FirstAccountFlowView.editableAmount(0, locale: us) == "", "«Empieza en 0» no es algo escrito")
        #expect(FirstAccountFlowView.editableAmount(nil, locale: us) == "")
        #expect(FirstAccountFlowView.parsed(FirstAccountFlowView.editableAmount(1200.5, locale: us)) == 1200.5)
    }

    @Test("volver rellena con lo contestado en vez de vaciar; ya no hay «Sí, así está bien»")
    func backPrefillsWiring() throws {
        let flow = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift")
        #expect(flow.contains("amountText = Self.editableAmount(stored)"))
        #expect(flow.contains("dayText = draft.statementDay?.day.map(String.init) ?? \"\""))
        #expect(flow.contains("dayText = draft.paymentDay?.day.map(String.init) ?? \"\""))
        #expect(flow.contains("nameText = Self.prefilledName(current: draft.name, kind: draft.kind)"))
        #expect(!flow.contains("first_account_name_keep"))
    }
}

// MARK: - 3, 4 y 5 · Campos legibles, cards vecinas y «Día» con su número

@Suite("Pulido Primeros pasos · campos legibles")
struct CamposLegiblesTests {

    private struct RGB { let r: Double, g: Double, b: Double }

    private static let allThemes: [(String, YalaTheme)] = [
        ("Claro", .light), ("Oscuro", .dark), ("Índigo", .indigo), ("Rosa", .rosa), ("Teal", .teal),
        ("Minimalista", .minimalist), ("Traslúcido", .translucent), ("Traslúcido Rosa", .translucentRosa),
        ("Traslúcido Teal", .translucentTeal), ("Liquid Glass", .liquidGlass),
    ]

    private static func rgb(_ color: Color, dark: Bool, over base: RGB? = nil) -> RGB {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard let base, a < 1 else { return RGB(r: Double(r), g: Double(g), b: Double(b)) }
        let al = Double(a)
        return RGB(r: Double(r) * al + base.r * (1 - al), g: Double(g) * al + base.g * (1 - al),
                   b: Double(b) * al + base.b * (1 - al))
    }

    private static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double {
            let v = min(max(v, 0), 1)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// La tarjeta del campo, compuesta sobre el fondo cuando es translúcida, en el modo DEL TEMA.
    private static func card(of theme: YalaTheme) -> RGB {
        let dark = theme.baseColorScheme == .dark
        return rgb(theme.card, dark: dark, over: rgb(theme.background, dark: dark))
    }

    @Test("el texto escrito llega a AA (4,5:1) sobre la tarjeta del campo en los diez temas",
          arguments: allThemes.map(\.0))
    func typedText_isAA(name: String) throws {
        let theme = try #require(Self.allThemes.first { $0.0 == name }?.1)
        // `yalaFieldText` resuelve `primaryText` con el modo del tema, no con el del sistema.
        let text = Self.rgb(theme.primaryText, dark: theme.baseColorScheme == .dark)
        let value = Self.ratio(text, Self.card(of: theme))
        #expect(value >= 4.5, "\(name): \(String(format: "%.2f", value)):1")
    }

    @Test("el aviso de ejemplo se lee (3:1 o más) en los diez temas", arguments: allThemes.map(\.0))
    func prompt_isReadable(name: String) throws {
        let theme = try #require(Self.allThemes.first { $0.0 == name }?.1)
        let dark = theme.baseColorScheme == .dark
        let surface = Self.card(of: theme)
        let value = Self.ratio(Self.rgb(Color.secondary, dark: dark, over: surface), surface)
        #expect(value >= 3, "\(name): \(String(format: "%.2f", value)):1")
    }

    @Test("el estilo ata el texto al modo del tema")
    func styleUsesTheThemeScheme() throws {
        let style = try PulidoSource.code("Yala/App/DesignSystem/YalaFieldStyle.swift")
        #expect(style.contains(".foregroundStyle(theme.primaryText)"))
        #expect(style.contains(".environment(\\.colorScheme, theme.baseColorScheme)"))
    }

    /// Todo campo de Primeros pasos y de los asistentes de cuenta, presupuesto y pago lleva el estilo común.
    @Test("cada campo completable lleva el estilo común")
    func everyFieldUsesTheStyle() throws {
        let directories = [
            "Yala/App/Views/Onboarding/PrimerosPasos",
            "Yala/App/Views/Accounts/AsistenteCuenta",
            "Yala/App/Views/Shared/AsistenteCreacion/Presupuesto",
            "Yala/App/Views/Planning/AsistentePagoPlanificado",
        ]
        var fields = 0
        for directory in directories {
            for file in try PulidoSource.swiftFiles(in: directory) {
                let code = try PulidoSource.code(file)
                let count = code.components(separatedBy: "TextField(").count - 1
                fields += count
                #expect(code.components(separatedBy: ".yalaFieldText()").count - 1 == count,
                         "\(file): \(count) campos y no todos con .yalaFieldText()")
                #expect(!code.contains("prompt: Text(verbatim: \"0\").foregroundStyle(.tertiary)"), "\(file)")
            }
        }
        #expect(fields >= 14, "el barrido no encontró los campos (\(fields))")
    }

    @Test("«No lo sé» y «Prefiero no decirlo» lado a lado miden lo mismo; las fichas de una fila también")
    func neighboursShareHeight() throws {
        let flow = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift")
        #expect(flow.contains("HStack(spacing: DS.Spacing.sm) { dayNoButtons(fillsRow: true) }\n                        .fixedSize(horizontal: false, vertical: true)"))
        #expect(flow.contains("maxHeight: fillsHeight ? .infinity : nil"))
        let pieces = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialQuestionPieces.swift")
        #expect(pieces.contains("minHeight: 104, maxHeight: .infinity"))
    }

    @Test("«Día» y su número van en la misma línea base y letra, con aire")
    func prefixAndNumberAlign() throws {
        #expect(YalaFieldPrefix.spacing == DS.Spacing.sm)
        let flow = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift")
        #expect(flow.contains("Text(T.dayPrefix).font(YalaFieldPrefix.font)"))
        #expect(flow.components(separatedBy: "HStack(alignment: .firstTextBaseline, spacing: YalaFieldPrefix.spacing)")
            .count - 1 == 2, "el día y el saldo")
        let pieces = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/TutorialQuestionPieces.swift")
        #expect(pieces.contains("HStack(alignment: .firstTextBaseline, spacing: YalaFieldPrefix.spacing)"))
    }
}

// MARK: - 7 a 10 · «No deseo crear…» y los textos nuevos

@Suite("Pulido Primeros pasos · textos de los pasos 3 y 4")
struct PrimerosPasosPulidoTextTests {

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]
    private static let keys = ["budget.noneOption", "payment.noneOption", "payment.kindQuestion",
                               "payment.kindAutoDetect", "budget.doneFreeLimit", "budget.createAnother",
                               "payment.doneFree"]

    @Test("los siete textos existen en los 16 idiomas, en su propia tabla", arguments: locales)
    func everyLocaleHasEveryKey(locale: String) throws {
        let url = PulidoSource.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/PrimerosPasosPulido.strings")
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale) sin tabla")
        for key in Self.keys {
            let value = try #require(table["primerosPasosPulido.\(key)"], "\(locale): falta \(key)")
            #expect(!value.isEmpty)
            if key == "budget.doneFreeLimit" { #expect(value.contains("%d"), "\(locale): sin el número") }
        }
        let localizable = try String(
            contentsOf: PulidoSource.repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings"),
            encoding: .utf8)
        #expect(!localizable.contains("primerosPasosPulido."), "\(locale): textos nuevos en Localizable")
    }

    @Test("el final del presupuesto dice el límite gratis REAL del código")
    func budgetLimitIsTheRealOne() {
        #expect(FirstBudgetFlowView.freeBudgetLimit == ProFeature.budgets.freeLimit)
        #expect(FirstBudgetFlowView.freeBudgetLimit > 0)
        #expect(PrimerosPasosPulidoText.budgetDoneFreeLimit(FirstBudgetFlowView.freeBudgetLimit)
            .contains("\(FirstBudgetFlowView.freeBudgetLimit)"))
    }

    @Test("los pagos planificados no tienen tope gratis: su final no inventa un número")
    func paymentsHaveNoFreeLimit() {
        #expect(!ProFeature.allCases.map(\.rawValue).contains { $0.lowercased().contains("scheduled") })
        #expect(!PrimerosPasosPulidoText.paymentDoneFree.contains { $0.isNumber })
    }

    @Test("«No deseo crear…» va arriba de las respuestas y omite el paso; «Crear otro» al terminar")
    func declineAndAnotherWiring() throws {
        let budget = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstBudgetFlowView.swift")
        let scope = try #require(budget.range(of: "case .scope:"))
        let decline = try #require(budget.range(of: "id: \"first_budget_none\""))
        let firstAnswer = try #require(budget.range(of: "TutorialOptionButton(title: T.scopeAll"))
        #expect(scope.lowerBound < decline.lowerBound && decline.lowerBound < firstAnswer.lowerBound)
        #expect(budget.contains("onClose(created ? .created : .skipped)"))
        #expect(budget.contains("anotherID: \"first_budget_another\""))
        let payment = try PulidoSource.code("Yala/App/Views/Onboarding/PrimerosPasos/FirstScheduledPaymentFlowView.swift")
        let kindDock = try #require(payment.range(of: "private var kindDock: some View {"))
        let paymentDecline = try #require(payment.range(of: "id: \"first_payment_none\""))
        let grid = try #require(payment.range(of: "LazyVGrid(", range: kindDock.upperBound..<payment.endIndex))
        #expect(paymentDecline.lowerBound < grid.lowerBound)
        #expect(payment.contains("case .kind: return PrimerosPasosPulidoText.paymentKindQuestion"))
        #expect(payment.contains("case .kind: return PrimerosPasosPulidoText.paymentKindAutoDetect"))
    }
}

// MARK: - 11 y 12 · La guía de «Más» y el paso 6

@MainActor
@Suite("Pulido Primeros pasos · la guía de Más", .serialized)
struct PrimerosPasosPulidoGuideTests {

    @Test("tras el paso 3 y el 4, la tarjeta de un solo momento dice «Entendido», no «Omitir»")
    func singleMomentSaysUnderstood() {
        for guide in [PlaceGuide.budgets, .scheduledPayments] {
            let first = guide.stages[0]
            #expect(first.target == .moreTab)
            #expect(!first.showsSkip, "\(guide)")
            #expect(first.closeLabel == L10n.Common.understood, "\(guide)")
        }
        // La de «días después» tiene contador («1 de 2»): sigue con «Omitir».
        #expect(PlaceGuide.chartsLater.stages[0].showsSkip)
    }

    @Test("«Entendido» la cierra sin resolver nada")
    func closeResolvesNothing() {
        let center = PlaceGuideCenter()
        var finished = 0
        center.start(.budgets) { finished += 1 }
        center.dismiss()
        #expect(!center.isActive)
        #expect(finished == 0)
    }

    @Test("el paso 6 es un solo momento en Más, con «Entendido», y terminarlo lo da por hecho")
    func stepSixShowsMoreDirectly() {
        let stages = PlaceGuide.chartsStep.stages
        #expect(stages.count == 1)
        #expect(stages[0].target == .moreItems(["insights", "trends", "categories"]))
        #expect(stages[0].advance == .button(L10n.Common.understood))
        #expect(!stages[0].showsSkip)
        #expect(stages[0].eyebrow == L10n.PlaceGuide.stepOf(6, 7))
        let center = PlaceGuideCenter()
        var finished = 0
        center.start(.chartsStep) { finished += 1 }
        center.tabDidChange(to: .more)
        #expect(center.isActive, "abrir Más no la cierra")
        center.advance()
        #expect(finished == 1)
    }

    @Test("el Panel abre Más al arrancar el paso 6")
    func panelSelectsMore() throws {
        let panel = try PulidoSource.code("Yala/App/Views/Panel/PanelView.swift")
        let start = try #require(panel.range(of: "private func startChartsStepGuide()"))
        let body = panel[start.upperBound...].prefix(900)
        #expect(body.contains("navigation.selectMainTab(.more)"))
    }

    @Test("la flecha vuelve a medir la pestaña hasta que la barra se queda quieta")
    func pointerTracksTheTab() throws {
        let a = CGRect(x: 280, y: 800, width: 60, height: 50)
        #expect(PlaceGuideTabTracking.isSettled(previous: a, next: a))
        #expect(!PlaceGuideTabTracking.isSettled(previous: a, next: a.offsetBy(dx: 12, dy: 0)))
        #expect(!PlaceGuideTabTracking.isSettled(previous: nil, next: a))
        #expect(!PlaceGuideTabTracking.remeasureDelays.isEmpty)
        let overlay = try PulidoSource.code("Yala/App/Tips/PlaceGuideOverlay.swift")
        #expect(overlay.contains("let tab = tabFrame ?? TabBarItemLocator.frame(ofTabLabeled: label)"))
        #expect(overlay.contains(".task(id: stage.target) { await followTab(of: stage.target) }"))
    }
}
