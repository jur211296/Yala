//
//  WelcomeShowcaseView.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-01 (vitrina y accesos) y Y23-06 (la puerta de Grupos). Sustituye al Hero de «Empezar» en el
//  mismo paso del contenedor: titular, una vitrina que rota sola con funciones reales de Yala y, debajo, los accesos.
//  Un botón por proveedor —sin «Empezar» ni «Ya tengo una cuenta»—: qué pasa después lo decide el contenedor.
//
//  Fondo F2 (base oscura con el índigo como brillo detrás de la vitrina), solo en modo oscuro como toda la bienvenida.
//  La mascota tiene su espacio reservado, vacío. Las reglas de qué se enseña y cuándo rota viven en
//  `WelcomeShowcaseLogic`, con su test.
//

import SwiftUI

struct WelcomeShowcaseView: View {
    typealias Door = WelcomeShowcaseLogic.Door
    typealias Demo = WelcomeShowcaseLogic.Demo
    typealias Access = WelcomeShowcaseLogic.Access

    /// La puerta con la que se monta (volver de una entrada de Grupos la deja en la suya).
    let initialDoor: Door
    /// La entrada a la cuenta de Yala está disponible (el kill-switch remoto la puede apagar): sin ella no se pintan
    /// los botones de Google y Apple, que no llevarían a ninguna parte.
    var providersAvailable: Bool = true
    var onAccess: (Access, Door) -> Void
    /// La puerta cambió: el contenedor la recuerda para volver a ella.
    var onDoorChange: (Door) -> Void = { _ in }

    @State private var door: Door
    @State private var index = 0
    @State private var paused = false
    /// Sube en cada función nueva: reinicia su temporizador y su animación de entrada.
    @State private var turn = 0
    @State private var hasTappedAccess = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @ScaledMetric(relativeTo: .body) private var stageDemoHeight: CGFloat = 176

    init(initialDoor: Door = .finances,
         providersAvailable: Bool = true,
         onAccess: @escaping (Access, Door) -> Void,
         onDoorChange: @escaping (Door) -> Void = { _ in }) {
        self.initialDoor = initialDoor
        self.providersAvailable = providersAvailable
        self.onAccess = onAccess
        self.onDoorChange = onDoorChange
        self._door = State(initialValue: initialDoor)
    }

    private var demos: [Demo] { WelcomeShowcaseLogic.demos(for: door) }
    private var current: Demo { demos[WelcomeShowcaseLogic.clamped(index, count: demos.count)] }
    /// La vitrina puede rotar sola en este entorno (sin Reducir movimiento ni VoiceOver).
    private var canRotate: Bool { !reduceMotion && !voiceOver }

    private var rotates: Bool {
        WelcomeShowcaseLogic.rotatesOnItsOwn(paused: paused, reduceMotion: reduceMotion, voiceOver: voiceOver)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    header
                    title
                    stage
                    accesses
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
                .frame(width: geo.size.width)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { WelcomeF2Background().ignoresSafeArea() }
        .welcomeBackButton(tint: .white, action: door == .groups ? { switchDoor(to: .finances) } : nil)
        .extendsUnderVerticalBar()
        // El temporizador de la función en pantalla: se rehace con cada función, puerta o pausa.
        .task(id: TimerKey(door: door, index: index, turn: turn, rotates: rotates)) {
            guard rotates else { return }
            do {
                try await Task.sleep(for: WelcomeShowcaseLogic.dwell)
            } catch {
                return  // la función cambió o la vista se fue: el temporizador se rehace con la siguiente
            }
            move(to: WelcomeShowcaseLogic.next(after: index, count: demos.count))
        }
    }

    private struct TimerKey: Equatable {
        let door: Door
        let index: Int
        let turn: Int
        let rotates: Bool
    }

    // MARK: - Cabecera y titular

    private var header: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Image("YalaLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .colorMultiply(.white)
                .accessibilityHidden(true)
            Spacer()
            // Espacio reservado para la mascota (fuera de alcance: se suma después).
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(.white.opacity(0.25))
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var title: some View {
        let (lead, accent, tint): (String, String, Color) = door == .finances
            ? (L10n.Showcase.financesTitle, L10n.Showcase.financesTitleAccent, .hotPink)
            : (L10n.Showcase.groupsTitle, L10n.Showcase.groupsTitleAccent, .neonCyan)
        var leadPart = AttributedString(lead + " ")
        leadPart.foregroundColor = .white
        var accentPart = AttributedString(accent)
        accentPart.foregroundColor = tint
        return Text(leadPart + accentPart)
            .font(DS.Typography.welcomeHeadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("welcome_showcase_title")
    }

    // MARK: - Vitrina

    private var stage: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                segments
                // Con Reducir movimiento o VoiceOver la vitrina no rota sola: no hay nada que pausar (review: el botón
                // pintaba «play» y decía «Pausar» sin hacer nada).
                if canRotate {
                Button {
                    DS.Haptic.selection()
                    paused.toggle()
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.1), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(paused ? L10n.Showcase.resume : L10n.Showcase.pause)
                .accessibilityIdentifier("welcome_showcase_pause")
                // Como el «Volver» del Welcome: el icono no crece más allá de su círculo (a AX5 se salía).
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon(for: current))
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(Color.neonCyan)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .accessibilityHidden(true)
                Text(name(for: current))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                if current.isPro {
                    Text(verbatim: "PRO")
                        .font(DS.Typography.labelTiny)
                        // A11Y-DM: el rótulo PRO del prototipo (ámbar sobre la vitrina oscura fija).
                        .foregroundStyle(Color(red: 0x2A / 255, green: 0x1D / 255, blue: 0))
                        .padding(.horizontal, DS.Spacing.xs + DS.Spacing.xxs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Color(red: 0xF5 / 255, green: 0xB4 / 255, blue: 0), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                }
            }
            // VoiceOver lee qué función es y en qué posición («Cuida un presupuesto, 5 de 6»); los segmentos cambian.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Showcase.position(name(for: current), index + 1, demos.count)
                                + (current.isPro ? ", PRO" : ""))
            .accessibilityIdentifier("welcome_showcase_current")

            WelcomeShowcaseDemoView(demo: current, turn: turn, reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity, minHeight: stageDemoHeight, alignment: .center)
                .id(DemoIdentity(door: door, index: index))
                .transition(.opacity)
                .accessibilityHidden(true)

            (Text(caption(for: current)).foregroundStyle(.white.opacity(0.72)))
                .font(DS.Typography.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            exampleTag

            // Sin entrada a la cuenta de Yala, la puerta de Grupos sería un callejón: no se ofrece.
            if providersAvailable, WelcomeShowcaseLogic.offersGroupsDoor(current, on: door) {
                Button {
                    DS.Haptic.selection()
                    switchDoor(to: .groups)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Showcase.groupsDoorLink)
                        Image(systemName: "chevron.right").font(DS.Typography.caption)
                    }
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 44)
                    .background(.white.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcome_showcase_groups_door")
            }
        }
        .padding(DS.Spacing.md + DS.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl + DS.Spacing.xs, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl + DS.Spacing.xs, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        }
        .contentShape(Rectangle())
        // Pausa al tocar la vitrina (si rota) y desliza entre funciones, como el prototipo. El deslizamiento es el de
        // UIKit (`HorizontalSwipeGesture`): un `DragGesture` dentro del scroll vertical le quitaba el arrastre a la
        // página (regla de `swiftui-ds.md`, review adversarial).
        .onTapGesture {
            guard canRotate else { return }
            DS.Haptic.selection()
            paused.toggle()
        }
        .gesture(HorizontalSwipeGesture(minimumDistance: WelcomeShowcaseLogic.swipeThreshold) { towardsNext in
            step(by: towardsNext ? 1 : -1)
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome_showcase_stage")
    }

    private struct DemoIdentity: Hashable {
        let door: Door
        let index: Int
    }

    private var exampleTag: some View {
        Text(L10n.Showcase.example.uppercased())
            .font(DS.Typography.labelTiny)
            .foregroundStyle(Color.neonCyan)
            .padding(.horizontal, DS.Spacing.xs + DS.Spacing.xxs)
            .padding(.vertical, DS.Spacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .foregroundStyle(Color.neonCyan)
            )
            .accessibilityHidden(true)
    }

    private var segments: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(demos.enumerated()), id: \.offset) { offset, demo in
                Button {
                    DS.Haptic.selection()
                    move(to: offset)
                } label: {
                    ShowcaseSegment(state: offset < index ? .done : (offset == index ? .now : .ahead),
                                    animates: rotates, turn: turn)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name(for: demo))
                .accessibilityAddTraits(offset == index ? .isSelected : [])
                .accessibilityIdentifier("welcome_showcase_segment_\(demo.rawValue)")
            }
        }
    }

    // MARK: - Accesos

    private var accesses: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(WelcomeShowcaseLogic.accesses(for: door, providersAvailable: providersAvailable), id: \.self) { access in
                switch access {
                case .google:
                    GoogleSignInButton(variant: .dark, purpose: .enter) { choose(.google) }
                        .frame(height: WelcomeFormLayout.buttonHeight)
                        .accessibilityIdentifier("welcome_access_google")
                case .apple:
                    WelcomeAppleEnterButton { choose(.apple) }
                        .frame(height: WelcomeFormLayout.buttonHeight)
                        .accessibilityIdentifier("welcome_access_apple")
                case .iCloud:
                    iCloudCard
                }
            }
            if door == .groups {
                Text(L10n.Showcase.groupsNeedAccount)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("welcome_access_groups_note")
            }
        }
    }

    private var iCloudCard: some View {
        Button { choose(.iCloud) } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "icloud.fill")
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(Color.neonCyan)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Showcase.enterWithICloud)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.white)
                    Text(L10n.Showcase.iCloudLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md + DS.Spacing.xxs)
            .padding(.vertical, DS.Spacing.md - 1)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("welcome_access_icloud")
    }

    // MARK: - Acciones

    private func choose(_ access: Access) {
        // Un toque doble no dispara dos entradas: la primera ya cambia de paso o abre la hoja del sistema.
        guard !hasTappedAccess else { return }
        hasTappedAccess = true
        DS.Haptic.selection()
        onAccess(access, door)
        // La hoja del sistema puede cancelarse y devolver aquí sin desmontar la vista: se libera tras un momento.
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                #if DEBUG
                print("WelcomeShowcaseView: Error: \(error)")
                #endif
            }
            hasTappedAccess = false
        }
    }

    private func switchDoor(to newDoor: Door) {
        guard newDoor != door else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: WelcomeCoverContentLogic.crossfadeSeconds)) {
            door = newDoor
            index = 0
            turn += 1
        }
        onDoorChange(newDoor)
    }

    private func step(by delta: Int) {
        let target = delta > 0
            ? WelcomeShowcaseLogic.next(after: index, count: demos.count)
            : WelcomeShowcaseLogic.previous(before: index, count: demos.count)
        DS.Haptic.selection()
        move(to: target)
    }

    /// Cambiar de función es un fundido: vale también con Reducir movimiento.
    private func move(to target: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            index = WelcomeShowcaseLogic.clamped(target, count: demos.count)
            turn += 1
        }
    }

    // MARK: - Textos por función

    private func name(for demo: Demo) -> String {
        switch demo {
        case .receipt: L10n.Showcase.receiptName
        case .voice: L10n.Showcase.voiceName
        case .organize: L10n.Showcase.organizeName
        case .splitAny: L10n.Showcase.splitName
        case .budget: L10n.Showcase.budgetName
        case .whoOwes: L10n.Showcase.whoOwesName
        case .settle: L10n.Showcase.settleName
        }
    }

    private func caption(for demo: Demo) -> String {
        switch demo {
        case .receipt: L10n.Showcase.receiptCaption
        case .voice: L10n.Showcase.voiceCaption
        case .organize: L10n.Showcase.organizeCaption
        case .splitAny: L10n.Showcase.splitCaption
        case .budget: L10n.Showcase.budgetCaption
        case .whoOwes: L10n.Showcase.whoOwesCaption
        case .settle: L10n.Showcase.settleCaption
        }
    }

    private func icon(for demo: Demo) -> String {
        switch demo {
        case .receipt: "camera.fill"
        case .voice: "mic.fill"
        case .organize: "chart.pie.fill"
        case .splitAny: "person.2.fill"
        case .budget: "chart.bar.fill"
        case .whoOwes: "list.bullet"
        case .settle: "checkmark"
        }
    }
}

// MARK: - Segmento de progreso

private struct ShowcaseSegment: View {
    enum State { case done, now, ahead }
    let state: State
    let animates: Bool
    let turn: Int

    @SwiftUI.State private var fill: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.18))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(.white.opacity(state == .now && !animates ? 0.6 : 1))
                        .frame(width: geo.size.width * width)
                }
            }
            .clipShape(Capsule())
            .frame(maxHeight: .infinity)
            .onAppear(perform: restart)
            .onChange(of: turn) { _, _ in restart() }
            .onChange(of: animates) { _, _ in restart() }
    }

    private var width: CGFloat {
        switch state {
        case .done: 1
        case .ahead: 0
        case .now: animates ? fill : 1
        }
    }

    private func restart() {
        fill = 0
        guard state == .now, animates else { return }
        withAnimation(.linear(duration: 5)) { fill = 1 }
    }
}

// MARK: - Botón «Entrar con Apple»

/// El par del botón de Google, del mismo tamaño y con el estilo de Apple sobre fondo oscuro (blanco, logo y texto en
/// negro). Un botón propio y no `ASAuthorizationAppleIDButton`: el del sistema no deja escribir «Entrar con Apple».
struct WelcomeAppleEnterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "apple.logo")
                    // A11Y-DT: paridad con el botón de Google, que tampoco escala (contrato de marca).
                    .font(.system(size: 19, weight: .medium))
                    .accessibilityHidden(true)
                Text(L10n.Showcase.enterWithApple)
                    .font(.system(size: 19, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // A11Y-DM: blanco y negro de Apple sobre la bienvenida oscura fija.
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fondo F2

/// Fondo F2 del prototipo: base oscura con el índigo como brillo detrás de la vitrina y un toque turquesa arriba.
struct WelcomeF2Background: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // A11Y-DM: la bienvenida es solo oscura (SPEC 2.3, «Fuera de alcance: modo claro»).
                Color(red: 8 / 255, green: 8 / 255, blue: 26 / 255)
                RadialGradient(colors: [Color.electricIndigo.opacity(0.62), Color.electricIndigo.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0.26),
                               startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.55)
                RadialGradient(colors: [Color.neonCyan.opacity(0.14), .clear],
                               center: UnitPoint(x: 0.88, y: 0.06),
                               startRadius: 0,
                               endRadius: geo.size.width * 0.45)
            }
        }
        .accessibilityHidden(true)
    }
}
