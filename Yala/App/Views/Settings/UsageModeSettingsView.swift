//
//  UsageModeSettingsView.swift
//  Yala
//
//  Ajustes › Preferencias › «Cómo usas Yala» (card p0iu, entrada A del lienzo elegida por Jürgen el 2026-10-26): dos
//  tarjetas, «Yala completo» y «Solo grupos». La fila sigue en Preferencias también en solo grupos: el mismo sitio sirve
//  para ir y para volver.
//
//  - Completo → «Solo grupos»: hoja de confirmación (`GroupsOnlyConfirmSheet`). Al confirmar se cierra Ajustes y la
//    shell se reduce después, como en «Vaciar datos»: con Ajustes encima, la página que la presenta podría desmontarse.
//  - Solo grupos → «Yala completo»: pide `.presentFullModeActivation`. Con sesión privada es la vuelta y cierra Ajustes
//    antes (`ContentView` espera a que se vaya); sin ella es la activación de siempre, encima de Ajustes.
//

import SwiftUI

struct UsageModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @Environment(\.yalaTheme) private var theme
    @Environment(SessionState.self) private var sessionState

    /// Cierra la hoja de Ajustes ENTERA (esta vista va empujada: su `dismiss` solo haría *pop*) y, si hace falta, deja
    /// intents en el router, que los retiene hasta que la hoja se ha ido (`ProfileView.leaveSettings`).
    let onLeaveSettings: ([RouterIntent]) -> Void

    @State private var showsLeaveConfirmation = false
    @State private var confirmedLeave = false

    private var isGroupsOnly: Bool { sessionState.isGroupsFocusedShell }

    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                Text(L10n.UsageMode.screenIntro)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, DS.Spacing.xs)
            }
            YalaSettingsSection {
                option(
                    id: "usage_mode_full", icon: "square.grid.2x2.fill", tint: theme.accent,
                    title: L10n.UsageMode.fullTitle, body: L10n.UsageMode.fullBody, isSelected: !isGroupsOnly
                ) {
                    chooseFull()
                }
                option(
                    id: "usage_mode_groups_only", icon: "person.3.fill", tint: .orange,
                    title: L10n.UsageMode.groupsOnlyTitle,
                    body: sessionState.hasPrivateSession ? L10n.UsageMode.groupsOnlyBody : L10n.UsageMode.groupsOnlyBodyNew,
                    isSelected: isGroupsOnly
                ) {
                    chooseGroupsOnly()
                }
            } footer: {
                // Solo es verdad para quien tiene algo guardado que volver a ver.
                if sessionState.hasPrivateSession {
                    Text(L10n.UsageMode.screenFooter)
                }
            }
        }
        .navigationTitle(L10n.UsageMode.rowTitle)
        .navigationBarTitleDisplayMode(.inline)
        .yalaScreenBackground(.subtle)
        .swipeBack()
        .toolbar {
            // Con la lista de Ajustes al lado, la lista es la vuelta (UX 2.2 · L16-20).
            if !settingsListIsAlongside {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
            }
        }
        // Hoja → cerrar Ajustes en su `onDismiss`: dos contenedores distintos, sin carrera en el mismo anchor.
        .sheet(isPresented: $showsLeaveConfirmation, onDismiss: applyLeaveIfConfirmed) {
            GroupsOnlyConfirmSheet(
                showsProLine: FeatureGateService.shared.isProUser,
                onConfirm: {
                    confirmedLeave = true
                    showsLeaveConfirmation = false
                },
                onCancel: { showsLeaveConfirmation = false })
        }
    }

    // MARK: - Acciones

    /// La vuelta cierra Ajustes (cambia la shell y su pregunta cuelga del ancla de `ContentView`, que espera a que la
    /// hoja se vaya); la activación de quien nunca tuvo Yala completo sale ENCIMA de Ajustes, como desde su botón.
    private func chooseFull() {
        guard isGroupsOnly else { return }
        if sessionState.hasPrivateSession {
            onLeaveSettings([.presentFullModeActivation])
        } else {
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        }
    }

    private func chooseGroupsOnly() {
        guard !isGroupsOnly, sessionState.hasPrivateSession else { return }
        showsLeaveConfirmation = true
    }

    private func applyLeaveIfConfirmed() {
        guard confirmedLeave else { return }
        confirmedLeave = false
        onLeaveSettings([])
        // La shell se reduce cuando Ajustes ya se fue: la pestaña que la presenta (el Panel, por ejemplo) desaparece con
        // ella. Mismo molde y misma espera que «Vaciar datos» (`UserDataResetView.handleWipeAllData`).
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            await UsageModeService.enterGroupsOnly()
        }
    }

    // MARK: - Tarjeta

    private func option(id: String, icon: String, tint: Color, title: String, body: String, isSelected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.onFill(tint))
                    .frame(width: 36, height: 36)
                    .background(tint, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                    Text(body)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(isSelected ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(id)
    }
}
