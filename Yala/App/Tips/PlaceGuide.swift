//
//  PlaceGuide.swift
//  Yala
//
//  Guías «dónde vive cada cosa» (Y23-15, bienvenida 2.3, docs/onboarding-2-3/SPEC.md). Con las pestañas nuevas
//  (Panel · Grupos · Registros), Presupuestos, Pagos planificados y Estadísticas viven en «Más», y al terminar cada
//  paso de Primeros pasos una guía de foco dice dónde quedó lo que se acaba de crear: dos toques para lo que vive en
//  «Más» (la pestaña y, dentro, su fila) y uno para Grupos (su pestaña). Los textos son los del prototipo oficial (v35).
//
//  Aquí vive el catálogo y su avance; las piezas que se pintan están en `PlaceGuideOverlay.swift`. Este lote usa las
//  dos de gráficas («días después» y el paso 6); las de presupuestos, pagos y grupos quedan listas para sus lotes,
//  que solo llaman a `PlaceGuideCenter.shared.start(_:)`.
//

import Foundation
import Observation

/// Una guía completa.
enum PlaceGuide: String, CaseIterable, Equatable {
    /// «Días después»: Configurar Panel, la pestaña Más y, dentro, Estadísticas.
    case chartsLater
    /// Paso 6 de Primeros pasos («Mira a dónde va tu dinero»): la pestaña Más y, dentro, Estadísticas.
    case chartsStep
    /// Al terminar el paso 3: la pestaña Más y, dentro, Presupuestos.
    case budgets
    /// Al terminar el paso 4: la pestaña Más y, dentro, Pagos planificados.
    case scheduledPayments
    /// Al terminar el paso 5: la pestaña Grupos.
    case groups
    /// Al terminar el paso 2 (Y23-10): la Bandeja, arriba a la izquierda del Panel.
    case inbox

    var stages: [PlaceGuideStage] {
        switch self {
        case .chartsLater:
            return [
                PlaceGuideStage(
                    target: .panelConfigure,
                    eyebrow: L10n.PlaceGuide.progress(1, 2),
                    title: L10n.PlaceGuide.configureTitle,
                    message: L10n.PlaceGuide.configureMessage,
                    advance: .button(L10n.TipKit.next),
                    showsSkip: true),
                PlaceGuideStage(
                    target: .moreTab,
                    eyebrow: L10n.PlaceGuide.progress(2, 2),
                    title: L10n.PlaceGuide.chartsTabTitle,
                    message: L10n.PlaceGuide.chartsTabMessageLater,
                    advance: .tapTab,
                    showsSkip: true),
                Self.chartsInMore,
            ]
        case .chartsStep:
            return [
                PlaceGuideStage(
                    target: .moreTab,
                    eyebrow: L10n.PlaceGuide.stepOf(6, 7),
                    title: L10n.PlaceGuide.chartsTabTitle,
                    message: L10n.PlaceGuide.chartsTabMessageStep,
                    advance: .tapTab,
                    showsSkip: true),
                Self.chartsInMore,
            ]
        case .budgets:
            return [
                PlaceGuideStage(
                    target: .moreTab,
                    eyebrow: L10n.Tab.planning,
                    title: L10n.PlaceGuide.budgetsTabTitle,
                    message: L10n.PlaceGuide.budgetsTabMessage,
                    advance: .tapTab,
                    showsSkip: true),
                PlaceGuideStage(
                    target: .moreItems(["budgets"]),
                    eyebrow: L10n.Tab.more,
                    title: L10n.PlaceGuide.budgetsMoreTitle,
                    message: L10n.PlaceGuide.budgetsMoreMessage,
                    advance: .button(L10n.Common.understood),
                    showsSkip: false),
            ]
        case .scheduledPayments:
            return [
                PlaceGuideStage(
                    target: .moreTab,
                    eyebrow: L10n.Tab.planning,
                    title: L10n.PlaceGuide.paymentsTabTitle,
                    message: L10n.PlaceGuide.paymentsTabMessage,
                    advance: .tapTab,
                    showsSkip: true),
                PlaceGuideStage(
                    target: .moreItems(["scheduledPayments"]),
                    eyebrow: L10n.Tab.more,
                    title: L10n.PlaceGuide.paymentsMoreTitle,
                    message: L10n.PlaceGuide.paymentsMoreMessage,
                    advance: .button(L10n.Common.understood),
                    showsSkip: false),
            ]
        case .inbox:
            return [
                PlaceGuideStage(
                    target: .panelInbox,
                    eyebrow: L10n.Accessibility.inbox,
                    title: L10n.PrimerosPasos23.Record.inboxGuideTitle,
                    message: L10n.PrimerosPasos23.Record.inboxGuideMessage,
                    advance: .button(L10n.Common.understood),
                    showsSkip: false),
            ]
        case .groups:
            return [
                PlaceGuideStage(
                    target: .groupsTab,
                    eyebrow: L10n.Tab.groups,
                    title: L10n.PlaceGuide.groupsTitle,
                    message: L10n.PlaceGuide.groupsMessage,
                    advance: .button(L10n.Common.understood),
                    showsSkip: false),
            ]
        }
    }

    /// Lo último de las dos de gráficas: Más con el foco en las tres de Estadísticas.
    private static var chartsInMore: PlaceGuideStage {
        PlaceGuideStage(
            target: .moreItems(["insights", "trends", "categories"]),
            eyebrow: L10n.Tab.more,
            title: L10n.PlaceGuide.chartsMoreTitle,
            message: L10n.PlaceGuide.chartsMoreMessage,
            advance: .button(L10n.Common.understood),
            showsSkip: false)
    }
}

/// Un momento de la guía: dónde se pone el foco y qué dice la tarjeta.
struct PlaceGuideStage: Equatable {
    enum Target: Equatable {
        /// El botón «Configurar Panel» de la barra de arriba del Panel.
        case panelConfigure
        /// El botón de la Bandeja, arriba a la izquierda del Panel.
        case panelInbox
        /// La pestaña «Más» de la barra de abajo.
        case moreTab
        /// Unas tarjetas de la pantalla Más (`MoreView`, por su id: `insights`, `budgets`…).
        case moreItems([String])
        /// La pestaña «Grupos» de la barra de abajo.
        case groupsTab

        /// La pestaña en la que se pinta este momento.
        var tab: AppTab {
            switch self {
            case .panelConfigure, .panelInbox, .moreTab, .groupsTab: return .panel
            case .moreItems: return .more
            }
        }
    }

    /// Cómo se sigue.
    enum Advance: Equatable {
        /// Un botón de la tarjeta.
        case button(String)
        /// Tocar la pestaña señalada (la tarjeta no lleva botón para seguir).
        case tapTab
    }

    let target: Target
    let eyebrow: String
    let title: String
    let message: String
    let advance: Advance
    let showsSkip: Bool
}

/// La guía en curso. Del proceso, como el tour Pro (`ProTourManager`): es una por teléfono, no por ventana.
@MainActor
@Observable
final class PlaceGuideCenter {

    static let shared = PlaceGuideCenter()

    /// La guía que se está enseñando, o `nil`.
    private(set) var guide: PlaceGuide?
    /// El momento de la guía en curso.
    private(set) var stageIndex = 0

    /// Lo que pasa al terminarla entera (no al omitirla). Lo pasa quien la arranca: el paso 6 la da por hecha.
    @ObservationIgnored private var onFinish: (() -> Void)?

    init() {}

    var stage: PlaceGuideStage? {
        guard let guide else { return nil }
        return PlaceGuideLogic.stage(of: guide, at: stageIndex)
    }

    var isActive: Bool { guide != nil }

    /// Arranca una guía. Si ya hay otra en pantalla no hace nada: dos guías a la vez se taparían.
    @discardableResult
    func start(_ guide: PlaceGuide, onFinish: (() -> Void)? = nil) -> Bool {
        guard self.guide == nil else { return false }
        self.guide = guide
        stageIndex = 0
        self.onFinish = onFinish
        return true
    }

    /// El botón de la tarjeta.
    func advance() {
        guard let guide else { return }
        switch PlaceGuideLogic.next(after: stageIndex, in: guide) {
        case .stage(let index): stageIndex = index
        case .finished: finish()
        }
    }

    /// La persona cambió de pestaña. Si el momento pedía tocar esa pestaña, avanza; si se fue a otra, la guía se cierra
    /// (lo que señalaba ya no está a la vista).
    func tabDidChange(to tab: AppTab) {
        guard let stage else { return }
        switch PlaceGuideLogic.reaction(to: tab, at: stage) {
        case .advance: advance()
        case .close: close()
        case .stay: break
        }
    }

    /// «Omitir», o tocar fuera.
    func skip() {
        close()
    }

    private func finish() {
        let onFinish = self.onFinish
        close()
        onFinish?()
    }

    private func close() {
        guide = nil
        stageIndex = 0
        onFinish = nil
    }
}

/// Las reglas del avance, sin efectos.
enum PlaceGuideLogic {

    enum Next: Equatable {
        case stage(Int)
        case finished
    }

    enum TabReaction: Equatable {
        case advance
        case close
        case stay
    }

    static func stage(of guide: PlaceGuide, at index: Int) -> PlaceGuideStage? {
        let stages = guide.stages
        return stages.indices.contains(index) ? stages[index] : nil
    }

    static func next(after index: Int, in guide: PlaceGuide) -> Next {
        index + 1 < guide.stages.count ? .stage(index + 1) : .finished
    }

    /// Qué hace un cambio de pestaña en un momento dado.
    static func reaction(to tab: AppTab, at stage: PlaceGuideStage) -> TabReaction {
        switch stage.target {
        case .moreTab:
            return tab == .more ? .advance : (tab == .panel ? .stay : .close)
        case .groupsTab:
            return tab == .groups ? .advance : (tab == .panel ? .stay : .close)
        case .panelConfigure, .panelInbox:
            return tab == .panel ? .stay : .close
        case .moreItems:
            return tab == .more ? .stay : .close
        }
    }
}

// MARK: - Textos

extension L10n {
    /// Las guías «dónde vive cada cosa» (Y23-15). Textos del prototipo oficial v35.
    enum PlaceGuide {
        static func progress(_ index: Int, _ total: Int) -> String {
            String(format: NSLocalizedString("placeGuide.progress", comment: "Place guide step counter, '1 of 2'"), index, total)
        }
        static func stepOf(_ index: Int, _ total: Int) -> String {
            String(format: NSLocalizedString("placeGuide.stepOf", comment: "Place guide label: 'Step 6 of 7' of Getting started"), index, total)
        }
        static var skip: String {
            NSLocalizedString("placeGuide.skip", comment: "Place guide: skip button")
        }
        static var configureTitle: String {
            NSLocalizedString("placeGuide.configure.title", comment: "Place guide on the Panel settings button: build your Panel")
        }
        static var configureMessage: String {
            NSLocalizedString("placeGuide.configure.message", comment: "Place guide on the Panel settings button, body")
        }
        static var chartsTabTitle: String {
            NSLocalizedString("placeGuide.charts.tab.title", comment: "Place guide on the More tab: your charts live in More")
        }
        static var chartsTabMessageLater: String {
            NSLocalizedString("placeGuide.charts.tab.later", comment: "Place guide on the More tab, days later: tap More to see them")
        }
        static var chartsTabMessageStep: String {
            NSLocalizedString("placeGuide.charts.tab.step", comment: "Place guide on the More tab, step 6: tap More and we show you")
        }
        static var chartsMoreTitle: String {
            NSLocalizedString("placeGuide.charts.more.title", comment: "Place guide inside More, on Statistics: all your charts")
        }
        static var chartsMoreMessage: String {
            NSLocalizedString("placeGuide.charts.more.message", comment: "Place guide inside More, on Statistics, body")
        }
        static var budgetsTabTitle: String {
            NSLocalizedString("placeGuide.budgets.tab.title", comment: "Place guide on the More tab: your budgets live in More")
        }
        static var budgetsTabMessage: String {
            NSLocalizedString("placeGuide.budgets.tab.message", comment: "Place guide on the More tab: tap More to find them")
        }
        static var budgetsMoreTitle: String {
            NSLocalizedString("placeGuide.budgets.more.title", comment: "Place guide inside More, on Budgets: here are your budgets")
        }
        static var budgetsMoreMessage: String {
            NSLocalizedString("placeGuide.budgets.more.message", comment: "Place guide inside More, on Budgets, body")
        }
        static var paymentsTabTitle: String {
            NSLocalizedString("placeGuide.payments.tab.title", comment: "Place guide on the More tab: your planned payments live in More")
        }
        static var paymentsTabMessage: String {
            NSLocalizedString("placeGuide.payments.tab.message", comment: "Place guide on the More tab: tap More to see them")
        }
        static var paymentsMoreTitle: String {
            NSLocalizedString("placeGuide.payments.more.title", comment: "Place guide inside More, on Planned payments: here they are")
        }
        static var paymentsMoreMessage: String {
            NSLocalizedString("placeGuide.payments.more.message", comment: "Place guide inside More, on Planned payments, body")
        }
        static var groupsTitle: String {
            NSLocalizedString("placeGuide.groups.title", comment: "Place guide on the Groups tab: your groups, one tap away")
        }
        static var groupsMessage: String {
            NSLocalizedString("placeGuide.groups.message", comment: "Place guide on the Groups tab, body")
        }
    }
}
