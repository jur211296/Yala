//
//  WelcomeGroupsChooserView.swift
//  Yala
//
//  2º nivel de «Vengo por un grupo» (G2 de Grupos-first): las DOS formas de empezar con un grupo —
//  organizarlo tú o entrar con la invitación que ya tienes.
//
//  **Por qué existe.** Hasta el 2026-08-11 la card del chooser decía «Me invitaron a un grupo» y le
//  hablaba SOLO al invitado con enlace; quien quería reemplazar Splitwise —el que crea el grupo e invita
//  a los demás— no se veía reflejado en ninguna de las tres cards del Welcome.
//
//  **Calco consciente de `WelcomeNewChooserView`**, como ese lo es de `WelcomeExistingChooserView`: los
//  docblocks de las tres lo llaman «réplica consciente» y no hay componente compartido. Copiar el molde
//  es lo esperado aquí, no un smell — refactorizar los hermanos para estrenar este habría tocado dos
//  flujos vivos por un calco.
//
//  **Es un STEP del `WelcomeFlowContainer`, no una presentación propia.** Toda salida del cover pasa por
//  su portal `leaveWelcome`, y una pantalla colgando del anchor de `ContentView` tendría que entrar en la
//  matriz de readiness (regla 3 de Presentaciones, `.claude/rules/swiftui-ds.md`). El precedente literal
//  es `.mirrorRelaunch`.
//

import SwiftUI

struct WelcomeGroupsChooserView: View {

    /// Los dos caminos. `String` + `CaseIterable` para que el rawValue alimente el identifier de XCUI
    /// igual que hace `WelcomeChooserView.Branch`, y para que un camino nuevo tenga que declararse.
    enum Path: String, CaseIterable {
        /// Organizar un grupo propio e invitar a los demás. **INERTE en G2** — ver `onCreate`.
        case create
        /// Ya tiene el enlace: sale por el MISMO `Destination .inviteRecovery` de siempre.
        case join
    }

    /// **G2 lo deja INERTE a propósito.** La rama organizador entera —comprobar el canal antes de escribir
    /// nada, sign-in, consent, nombre y el form— es el CHIP G3, y montarle aquí un stub (un alert
    /// «próximamente», una pantalla vacía) sería justo lo que el spec prohíbe: un camino muerto que el
    /// usuario puede tocar. Mientras no exista, la card no se pinta.
    ///
    /// TODO(G3): pasar el handler real de la rama organizador y quitar el filtro de `visiblePaths`.
    var onCreate: (() -> Void)?
    var onJoin: () -> Void
    var onBack: () -> Void

    /// Alto NATURAL del contenido de cada card, para igualarlas. Mismo mecanismo —y mismo porqué— que
    /// `WelcomeNewChooserView`: el alto depende del idioma (un título que envuelve en alemán y no en
    /// español), así que la igualación es de layout y no de copy.
    @State private var contentHeights: [Path: CGFloat] = [:]

    /// Con `onCreate` sin cablear se pinta UNA card. No es un caso degenerado: es el estado de G2, y la
    /// pantalla sigue teniendo sentido —el invitado ve su camino y el back sigue devolviéndolo al
    /// chooser—. En cuanto G3 cablee el handler aparecen las dos, en este orden.
    private var visiblePaths: [Path] {
        Path.allCases.filter { $0 != .create || onCreate != nil }
    }

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Welcome.Groups.title)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.Welcome.Groups.subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.md) {
                    ForEach(visiblePaths, id: \.self) { path in
                        pathCard(path)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }

    /// `nil` hasta que TODAS las cards visibles se han medido: igualar con media medición daría un salto
    /// en el primer frame.
    private var evenCardHeight: CGFloat? {
        let visibles = visiblePaths
        guard visibles.count > 1,
              visibles.allSatisfy({ contentHeights[$0] != nil }) else { return nil }
        return visibles.compactMap { contentHeights[$0] }.max()
    }

    private func title(for path: Path) -> String {
        switch path {
        case .create: L10n.Welcome.Groups.createTitle
        case .join: L10n.Welcome.Groups.joinTitle
        }
    }

    private func body(for path: Path) -> String {
        switch path {
        case .create: L10n.Welcome.Groups.createBody
        case .join: L10n.Welcome.Groups.joinBody
        }
    }

    private func iconName(for path: Path) -> String {
        switch path {
        case .create: "person.2.badge.plus"
        case .join: "link.circle.fill"
        }
    }

    private func iconTint(for path: Path) -> Color {
        switch path {
        case .create: .essentialNeed
        case .join: .neonCyan
        }
    }

    private func action(for path: Path) -> (() -> Void)? {
        switch path {
        case .create: onCreate
        case .join: onJoin
        }
    }

    private func systemIconCircle(name: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 48, height: 48)
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func pathCard(_ path: Path) -> some View {
        Button {
            guard let action = action(for: path) else { return }
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                systemIconCircle(name: iconName(for: path), tint: iconTint(for: path))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(for: path))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(body(for: path))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { alto in
                contentHeights[path] = alto
            }
            .frame(minHeight: evenCardHeight, alignment: .leading)
            .contentShape(Rectangle())
            .welcomeFlowCard(radius: DS.Radius.xl)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: path)). \(body(for: path))")
        .accessibilityIdentifier("welcome_groups_\(path.rawValue)")
    }
}
