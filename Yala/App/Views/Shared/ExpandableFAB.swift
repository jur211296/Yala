//
//  ExpandableFAB.swift
//  Yala
//
//  FAB expandible genérico: un botón principal (plus/xmark) que despliega una
//  lista de acciones flotantes en pills, replicando el lenguaje visual del FAB
//  del Panel (`FABStackView`) sin su acoplamiento a Pro/IA. Usado por el tab
//  Grupos (Nuevo grupo / Nuevo gasto).
//

import SwiftUI

/// Una acción del menú flotante del `ExpandableFAB`.
struct ExpandableFABAction: Identifiable {
    let id: String
    let icon: String
    let text: String
    let color: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct ExpandableFAB: View {

    // MARK: - Configuration

    let mainTint: Color
    let actions: [ExpandableFABAction]
    /// Label a11y del botón principal colapsado (abre el menú).
    let mainAccessibilityLabel: String
    /// Label a11y del botón principal expandido (cierra el menú).
    let closeAccessibilityLabel: String
    let mainAccessibilityIdentifier: String

    // MARK: - State

    @State private var showMenu = false

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation

    private static let fabSpring: Animation = .spring(
        response: DS.Animation.springResponse,
        dampingFraction: DS.Animation.springDamping
    )
    private static let fabScaleTransition: AnyTransition = .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)

    private func toggleMenu() {
        dsWithAnimation(reduceMotion, Self.fabSpring) { showMenu.toggle() }
    }

    private func dismissMenu() {
        dsWithAnimation(reduceMotion, Self.fabSpring) { showMenu = false }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.md) {
            if showMenu {
                menuButtons
            }
            mainButton
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        Button {
            DS.Haptic.medium()
            toggleMenu()
        } label: {
            Image(systemName: showMenu ? "xmark" : "plus")
                .font(DS.Typography.title)
                .foregroundStyle(theme.usesMaterial || showMenu ? .white : Color.contrastingText(for: mainTint))
                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                .rotationEffect(.degrees(showMenu ? 90 : 0))
                .modifier(FABSurfaceModifier(base: showMenu ? DS.Semantic.disabledForeground : mainTint))
        }
        .fabButtonStyle(usesMaterial: theme.usesMaterial)
        .dsFloatingShadow()
        .accessibilityLabel(showMenu ? closeAccessibilityLabel : mainAccessibilityLabel)
        .accessibilityIdentifier(mainAccessibilityIdentifier)
    }

    // MARK: - Menu Buttons

    private var menuButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(actions) { action in
                fabMenuButton(action)
            }
        }
        .transition(Self.fabScaleTransition)
    }

    private func fabMenuButton(_ action: ExpandableFABAction) -> some View {
        Button {
            DS.Haptic.selection()
            dismissMenu()
            action.action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: action.icon)
                    .font(DS.Typography.headline)
                    .frame(width: DS.Button.fabMenuIconSize)
                    .accessibilityHidden(true)

                Text(action.text)
                    .font(DS.Typography.headline)

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(width: DS.Button.fabMenuWidth)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(action.color)
            .clipShape(Capsule())
            .shadow(color: action.color.opacity(0.3), radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}
