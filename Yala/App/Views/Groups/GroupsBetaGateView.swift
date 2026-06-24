//
//  GroupsBetaGateView.swift
//  Yala
//
//  Pantalla de bloqueo del tab Grupos mientras el dispositivo no está desbloqueado
//  con el código beta. Se monta en lugar de `GroupsContainerView` (ver
//  `MainTabView.viewForTab(.groups)`) para los caminos que NO pasan por la card de
//  "Más" (tab visible, deeplinks, notificaciones).
//
//  Gate TEMPORAL (validación v2.0.1). Remover al estabilizar — ver
//  `GroupsBetaGateLogic`.
//

import SwiftUI

struct GroupsBetaGateView: View {
    @Environment(\.yalaTheme) private var theme
    @State private var showCodeEntry = false

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))  // A11Y-DT: ícono hero del gate; escala vía contenedor
                .foregroundStyle(theme.accent)
                .frame(width: 96, height: 96)
                .background(
                    Circle().fill(theme.accent.opacity(0.12))
                )

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Beta.title)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Beta.message)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            YalaPrimaryButton(L10n.Groups.Beta.haveCode) {
                showCodeEntry = true
            }
            .accessibilityIdentifier("groups_beta_gate_have_code")
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yalaScreenBackground(.panel)
        .accessibilityIdentifier("groups_beta_gate")
        // onUnlock vacío: al validar, `groupsBetaUnlocked` cambia y `MainTabView`
        // recompone `viewForTab(.groups)` → reemplaza esta vista por GroupsContainerView.
        .betaCodeEntry(isPresented: $showCodeEntry)
    }
}

// MARK: - Flujo de ingreso del código beta (compartido card de Más + gate)

/// Alert de ingreso del código + alert de error, con la validación en
/// `GroupsBetaGateLogic`. Un solo flujo reusable: la card de "Más" lo dispara tras
/// su alert intro; `GroupsBetaGateView` lo dispara desde su botón. Al validar
/// correcto escribe `groupsBetaUnlocked = true` (recordado per-device) y ejecuta
/// `onUnlock` (la card navega a Grupos; el gate no hace nada — se auto-reemplaza).
private struct BetaCodeEntryModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onUnlock: () -> Void = {}

    // @AppStorage directo (síncrono): reacciona y propaga a los demás lectores del
    // flag (MainTabView, MoreView) sin el tick async del observer de AppPreferences.
    @AppStorage(AppPreferences.Keys.groupsBetaUnlocked) private var groupsBetaUnlocked = false
    @State private var codeInput = ""
    @State private var showWrongCode = false

    func body(content: Content) -> some View {
        content
            .alert(L10n.Groups.Beta.codePrompt, isPresented: $isPresented) {
                TextField(L10n.Groups.Beta.placeholder, text: $codeInput)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("beta_code_field")
                Button(L10n.Action.continueAction) { validate() }
                    .accessibilityIdentifier("beta_code_validate")
                Button(L10n.Action.cancel, role: .cancel) { codeInput = "" }
            }
            .alert(L10n.Groups.Beta.wrongCode, isPresented: $showWrongCode) {
                Button(L10n.Common.ok) {
                    codeInput = ""
                    // Difiere al próximo runloop: reabrir un alert dentro de la acción
                    // del que se cierra es frágil; el Task lo presenta tras el dismiss.
                    Task { @MainActor in isPresented = true }
                }
            }
    }

    private func validate() {
        if GroupsBetaGateLogic.isValidCode(codeInput) {
            codeInput = ""
            groupsBetaUnlocked = true
            onUnlock()
        } else {
            codeInput = ""
            Task { @MainActor in showWrongCode = true }
        }
    }
}

extension View {
    /// Adjunta el flujo de ingreso/validación del código beta de Grupos.
    /// - Parameters:
    ///   - isPresented: controla el alert de ingreso del código.
    ///   - onUnlock: se ejecuta tras validar correcto (además de marcar desbloqueado).
    func betaCodeEntry(isPresented: Binding<Bool>, onUnlock: @escaping () -> Void = {}) -> some View {
        modifier(BetaCodeEntryModifier(isPresented: isPresented, onUnlock: onUnlock))
    }
}
