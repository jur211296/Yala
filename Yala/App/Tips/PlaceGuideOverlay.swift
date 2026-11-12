//
//  PlaceGuideOverlay.swift
//  Yala
//
//  Lo que se pinta de las guías «dónde vive cada cosa» (`PlaceGuide.swift`, Y23-15).
//
//  Dos sitios:
//   · En el Panel (`placeGuidePanelHost`): «Arma tu Panel» bajo «Configurar Panel», y «… viven en Más» / «Tus grupos,
//     a un toque» sobre la barra de abajo. La barra de arriba y la de abajo son de UIKit y quedan POR ENCIMA del
//     contenido de la página: no se les puede recortar un foco desde aquí. La página se oscurece, las barras quedan
//     encendidas (el «lift» del prototipo) y la tarjeta apunta a lo que hay que tocar; tocar la pestaña avanza
//     (`PlaceGuideCenter.tabDidChange`).
//   · En Más (`placeGuideMoreHost`): foco recortado alrededor de las tarjetas (`placeGuideAnchor`) y «Entendido».
//
//  Reducir movimiento deja solo fundidos; nada avanza solo, así que VoiceOver tampoco se ve arrastrado.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Marcos de lo que se señala

/// Dónde están, en la ventana, las piezas que una guía señala y que no cuelgan de la página.
@MainActor
@Observable
final class PlaceGuideFrames {
    static let shared = PlaceGuideFrames()
    /// El botón «Configurar Panel» de la barra de arriba del Panel.
    var configureButton: CGRect?
    /// El botón de la Bandeja de la barra de arriba del Panel (Y23-10).
    var inboxButton: CGRect?
}

/// La ubicación, en la ventana, de una pestaña de la barra de abajo. La barra es de UIKit: se busca su botón por la
/// etiqueta que lee VoiceOver. Si no aparece (otra forma de barra), la tarjeta sale sin flecha.
@MainActor
enum TabBarItemLocator {
    static func frame(ofTabLabeled label: String) -> CGRect? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let window, let tabBar = find(UITabBar.self, in: window) else { return nil }
        guard let item = firstView(in: tabBar, where: { $0.accessibilityLabel == label }) else { return nil }
        return item.convert(item.bounds, to: nil)
    }

    private static func find<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for sub in view.subviews { if let found = find(type, in: sub) { return found } }
        return nil
    }

    private static func firstView(in view: UIView, where match: (UIView) -> Bool) -> UIView? {
        for sub in view.subviews {
            if match(sub), !sub.isHidden, sub.bounds.width > 0 { return sub }
            if let found = firstView(in: sub, where: match) { return found }
        }
        return nil
    }
}

// MARK: - Anclas en Más

struct PlaceGuideAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marca una tarjeta de Más como destino de una guía. Sin `.id`: la tarjeta vive en un `ForEach` de una rejilla
    /// perezosa y su identidad la pone el `ForEach`.
    func placeGuideAnchor(_ id: String) -> some View {
        transformAnchorPreference(key: PlaceGuideAnchorKey.self, value: .bounds) { dict, anchor in
            dict[id] = anchor
        }
    }

    /// La parte de la guía que vive en el Panel, y el disparador de «días después».
    func placeGuidePanelHost(isPageShown: Bool) -> some View {
        modifier(PlaceGuidePanelHost(isPageShown: isPageShown))
    }

    /// La parte de la guía que vive en Más.
    func placeGuideMoreHost() -> some View {
        modifier(PlaceGuideMoreHost())
    }
}

// MARK: - Panel

private struct PlaceGuidePanelHost: ViewModifier {
    let isPageShown: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState

    func body(content: Content) -> some View {
        content
            // Implícita en el contenedor: dentro de una pestaña `ContentView` apaga las transacciones (swiftui-ds.md).
            .overlay {
                PanelPlaceGuideLayer()
                    .animation(reduceMotion ? nil : DS.Animation.appear, value: PlaceGuideCenter.shared.stage)
            }
            .task(id: LaterTriggerKey(dataVersion: sessionState.dataVersion, isPageShown: isPageShown)) {
                await offerLaterGuideIfDue()
            }
    }

    private struct LaterTriggerKey: Equatable {
        let dataVersion: Int
        let isPageShown: Bool
    }

    /// «Días después» (Y23-15): una vez, cuando ya hay registros en dos días distintos.
    private func offerLaterGuideIfDue() async {
        guard isPageShown else { return }
        // Quien volvió por «Ya tengo una cuenta» con datos da por vistas las guías de principiante (esta incluida).
        ReturningUserBeginnerTips.settleIfPending(context: modelContext)
        let center = PlaceGuideCenter.shared
        let proTourOnScreen = ProTourManager.shared.triggered && !ProTourManager.shared.hasCompleted
        let inputs = LaterChartsGuideLogic.Inputs(
            isFreshInstall: TabBarDefaultsMigration.isFreshInstall(),
            alreadyShown: LaterChartsGuideLogic.wasShown(),
            statisticsInBar: TabBarConfiguration.loadFromStandardDefaults().activeTabs.contains(.statistics),
            hasMoreTab: sizeClass != .regular,
            guideOnScreen: center.isActive || proTourOnScreen,
            stepSixResolved: SetupChecklistManager.shared.isResolved(.whereMoneyGoes),
            silencedForUITest: UITestHooks.isActive && !UITestHooks.showsLaterChartsGuide)
        guard LaterChartsGuideLogic.mayCheck(inputs) else { return }
        guard LaterChartsGuideLogic.distinctDays(in: recordDayBounds()) >= LaterChartsGuideLogic.minimumDistinctDays
        else { return }
        // Que el Panel termine de asentarse antes de oscurecerlo.
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        guard isPageShown, !center.isActive else { return }
        if center.start(.chartsLater, onFinish: { SetupChecklistManager.shared.markCompleted(.whereMoneyGoes) }) {
            LaterChartsGuideLogic.markShown()
        }
    }

    /// La fecha del primer y del último registro de la persona: si caen en días distintos, hay al menos dos días.
    private func recordDayBounds() -> [Date] {
        var oldest = SetupChecklistManager.userRecordsDescriptor()
        oldest.sortBy = [SortDescriptor(\TransactionItem.date, order: .forward)]
        oldest.fetchLimit = 1
        var newest = SetupChecklistManager.userRecordsDescriptor()
        newest.sortBy = [SortDescriptor(\TransactionItem.date, order: .reverse)]
        newest.fetchLimit = 1
        do {
            return try (modelContext.fetch(oldest) + modelContext.fetch(newest)).map(\.date)
        } catch {
            #if DEBUG
            print("PlaceGuidePanelHost: Error leyendo las fechas de los registros: \(error)")
            #endif
            return []
        }
    }
}

/// La capa del Panel: oscurece la página y pone la tarjeta junto a lo que señala. La tarjeta se coloca con el área
/// segura de la página (debajo de la barra de arriba, encima de la de abajo); los marcos medidos solo dan la x de la
/// flecha, porque el de un botón de la barra llega en las coordenadas de la barra, no en las de la ventana.
private struct PanelPlaceGuideLayer: View {
    private var center: PlaceGuideCenter { .shared }

    var body: some View {
        if let stage = center.stage, stage.target.tab == .panel {
            ZStack {
                PlaceGuideScrim(cutout: nil) { center.skip() }
                    .ignoresSafeArea()
                GeometryReader { proxy in
                    card(stage, proxy: proxy)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func card(_ stage: PlaceGuideStage, proxy: GeometryProxy) -> some View {
        let page = proxy.frame(in: .global)
        switch stage.target {
        case .panelConfigure, .panelInbox:
            VStack(spacing: 0) {
                PlaceGuideCard(stage: stage, pointer: .up(
                    x: stage.target == .panelInbox ? Self.inboxX(in: page) : Self.configureX(in: page)))
                Spacer(minLength: 0)
            }
            // El Panel pinta su contenido bajo la barra de arriba (el área segura solo descuenta la hora): la tarjeta
            // baja lo que mide esa barra para no tapar el botón que señala.
            .padding(.top, Self.topBarHeight + DS.Spacing.md)
        default:
            let label = stage.target == .groupsTab ? L10n.Tab.groups : L10n.Tab.more
            let tab = TabBarItemLocator.frame(ofTabLabeled: label)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                PlaceGuideCard(stage: stage, pointer: tab.map { .down(x: $0.midX) })
            }
            .padding(.bottom, DS.Spacing.md)
        }
    }

    /// Alto de la barra de arriba del Panel (botones de cristal de 44 pt y su margen).
    private static let topBarHeight: CGFloat = 60

    /// La x de la Bandeja, en la ventana. Si el marco medido no cae en la mitad izquierda de la página, el sitio de
    /// siempre: el primer botón de la izquierda.
    private static func inboxX(in page: CGRect) -> CGFloat {
        if let frame = PlaceGuideFrames.shared.inboxButton, page.minX..<page.midX ~= frame.midX {
            return frame.midX
        }
        return page.minX + 38
    }

    /// La x de «Configurar Panel», en la ventana. Si el marco medido no cae en la página, el sitio de siempre: el
    /// segundo botón del grupo de la derecha, junto al avatar.
    private static func configureX(in page: CGRect) -> CGFloat {
        if let frame = PlaceGuideFrames.shared.configureButton, page.minX..<page.maxX ~= frame.midX, frame.midX > page.midX {
            return frame.midX
        }
        return page.maxX - 92
    }
}

// MARK: - Más

private struct PlaceGuideMoreHost: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(PlaceGuideAnchorKey.self) { anchors in
            MorePlaceGuideLayer(anchors: anchors)
                .animation(reduceMotion ? nil : DS.Animation.appear, value: PlaceGuideCenter.shared.stage)
        }
    }
}

private struct MorePlaceGuideLayer: View {
    let anchors: [String: Anchor<CGRect>]
    private var center: PlaceGuideCenter { .shared }

    var body: some View {
        if let stage = center.stage, case .moreItems(let ids) = stage.target {
            GeometryReader { proxy in
                let rects = ids.compactMap { anchors[$0].map { proxy[$0] } }
                // Si Más quedó desplazada y lo señalado no se ve entero, la tarjeta sale centrada y sin recorte.
                let visible = CGRect(origin: .zero, size: proxy.size)
                let highlight = rects.dropFirst().reduce(rects.first) { $0?.union($1) }
                    .map { $0.insetBy(dx: -DS.Spacing.sm, dy: -DS.Spacing.sm) }
                    .flatMap { visible.contains($0) ? $0 : nil }
                // Tocar lo resaltado la cumple, como «Entendido»; tocar fuera, la omite.
                PlaceGuideScrim(cutout: highlight, onCutoutTap: { center.advance() }) { center.skip() }
                if let highlight {
                    let below = highlight.midY < proxy.size.height * 0.5
                    VStack(spacing: 0) {
                        if !below { Spacer(minLength: 0) }
                        PlaceGuideCard(stage: stage, pointer: below ? .up(x: highlight.midX) : .down(x: highlight.midX))
                        if below { Spacer(minLength: 0) }
                    }
                    .padding(below ? .top : .bottom,
                             below ? highlight.maxY + DS.Spacing.md : proxy.size.height - highlight.minY + DS.Spacing.md)
                } else {
                    VStack { Spacer(); PlaceGuideCard(stage: stage, pointer: nil); Spacer() }
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Piezas

/// El oscurecido, con un hueco opcional. Tocarlo cierra la guía, como «Omitir» (y como la guía de foco de siempre);
/// tocar el hueco hace `onCutoutTap`.
private struct PlaceGuideScrim: View {
    let cutout: CGRect?
    var onCutoutTap: (() -> Void)?
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        // Las mismas dos opacidades que la guía de foco de siempre (`CoachMarkLayout`).
        let opacity = theme.baseColorScheme == .dark ? 0.75 : 0.65 // A11Y-DM: oscurecido de la guía de foco
        let dim = Path { path in
            path.addRect(CGRect(x: -2000, y: -2000, width: 6000, height: 6000))
            if let cutout {
                path.addRoundedRect(in: cutout, cornerSize: CGSize(width: DS.Radius.lg, height: DS.Radius.lg))
            }
        }
        ZStack {
            dim
                .fill(Color.black.opacity(opacity), style: FillStyle(eoFill: true))
                .contentShape(dim, eoFill: true)
                .onTapGesture(perform: onTap)
                .accessibilityHidden(true)

            if let cutout, let onCutoutTap {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .onTapGesture(perform: onCutoutTap)
                    .accessibilityHidden(true)
            }

            if let cutout {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(theme.accent, lineWidth: 2.5)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// La tarjeta de un momento: el rótulo («1 de 2», «Más»…), el título, el texto y sus botones.
struct PlaceGuideCard: View {
    enum Pointer: Equatable {
        case up(x: CGFloat)
        case down(x: CGFloat)
    }

    let stage: PlaceGuideStage
    let pointer: Pointer?

    @Environment(\.yalaTheme) private var theme
    /// VoiceOver va a la tarjeta cuando aparece o cambia de momento: la guía sale sola y lo de debajo queda tapado.
    @AccessibilityFocusState private var titleFocused: Bool
    private var center: PlaceGuideCenter { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(stage.eyebrow)
                .font(DS.Typography.labelSmall.bold())
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(theme.accent))

            // Con texto grande, el texto se desplaza dentro de la tarjeta y los botones siguen a la vista.
            ViewThatFits(in: .vertical) {
                texts
                ScrollView { texts }
                    .scrollBounceBehavior(.basedOnSize)
            }

            if stage.showsSkip || stage.advance != .tapTab {
                HStack {
                    if stage.showsSkip {
                        Button {
                            center.skip()
                        } label: {
                            Text(L10n.PlaceGuide.skip)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: DS.Button.actionSize, minHeight: DS.Button.actionSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("place_guide_skip")
                    }
                    Spacer()
                    if case .button(let label) = stage.advance {
                        Button {
                            center.advance()
                        } label: {
                            Text(label)
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(theme.onAccent)
                                .padding(.horizontal, DS.Spacing.lg)
                                .frame(minHeight: DS.Button.actionSize)
                                .background(Capsule().fill(theme.accent))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("place_guide_advance")
                    }
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: DS.Adaptive.readableWidth, alignment: .leading)
        .background {
            if theme.usesMaterial {
                RoundedRectangle(cornerRadius: DS.Radius.lg).fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(alignment: .top) { pointerView(up: true) }
        .overlay(alignment: .bottom) { pointerView(up: false) }
        .padding(.horizontal, DS.Spacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("place_guide_card")
        .onAppear { titleFocused = true }
        .onChange(of: stage.title) { _, _ in titleFocused = true }
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(stage.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)

            Text(stage.message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// La flecha hacia lo que se señala, en su x.
    @ViewBuilder
    private func pointerView(up: Bool) -> some View {
        if let pointer {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                switch (pointer, up) {
                case (.up(let x), true):
                    triangle(up: true)
                        .position(x: min(max(x - frame.minX, DS.Spacing.xl), proxy.size.width - DS.Spacing.xl), y: -6)
                case (.down(let x), false):
                    triangle(up: false)
                        .position(x: min(max(x - frame.minX, DS.Spacing.xl), proxy.size.width - DS.Spacing.xl),
                                  y: proxy.size.height + 6)
                default:
                    EmptyView()
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func triangle(up: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: up ? 12 : 0))
            path.addLine(to: CGPoint(x: 12, y: up ? 0 : 12))
            path.addLine(to: CGPoint(x: 24, y: up ? 12 : 0))
            path.closeSubpath()
        }
        .fill(theme.usesMaterial ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.card))
        .frame(width: 24, height: 12)
    }
}

// MARK: - «Días después»

/// Y23-15: la guía de las gráficas sale sola UNA vez, cuando ya hay registros en dos o más días distintos. Solo en
/// una instalación nueva de 2.3 (a quien ya usaba Yala las gráficas no se le movieron), con Estadísticas fuera de la
/// barra y «Más» a la vista, sin otra guía en pantalla y si el paso 6 no la dio ya.
nonisolated enum LaterChartsGuideLogic {

    static let shownKey = "placeGuide.chartsLater.shown"
    static let minimumDistinctDays = 2

    struct Inputs: Equatable {
        var isFreshInstall: Bool
        var alreadyShown: Bool
        var statisticsInBar: Bool
        var hasMoreTab: Bool
        var guideOnScreen: Bool
        var stepSixResolved: Bool
        var silencedForUITest: Bool
    }

    /// Todo lo que no cuesta leer el almacén. Si da `false`, no se cuentan días.
    static func mayCheck(_ inputs: Inputs) -> Bool {
        inputs.isFreshInstall && !inputs.alreadyShown && !inputs.statisticsInBar && inputs.hasMoreTab
            && !inputs.guideOnScreen && !inputs.stepSixResolved && !inputs.silencedForUITest
    }

    /// Cuántos días de calendario distintos hay entre unas fechas.
    static func distinctDays(in dates: [Date], calendar: Calendar = .current) -> Int {
        Set(dates.map { calendar.startOfDay(for: $0) }).count
    }

    static func wasShown(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: shownKey)
    }

    static func markShown(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: shownKey)
    }
}

// MARK: - Pestaña elegida

extension View {
    /// Avisa a la guía en curso de cada cambio de pestaña (`PlaceGuideCenter.tabDidChange`).
    func placeGuideFollowsTab(_ selection: AppTab) -> some View {
        onChange(of: selection) { _, tab in PlaceGuideCenter.shared.tabDidChange(to: tab) }
    }
}
