//
//  YalaAccountView.swift
//  Yala
//
//  Pantalla "Tu cuenta de Yala" (§3.3.5 del estudio MODO-NUBE-GESTION-DATOS-UX) — mapa/explainer del
//  enlace privado ↔ nube. Muestra el método de entrada, dónde viven los datos y los desenlaces aplicables
//  (Cerrar sesión / Volver a iCloud / Eliminar cuenta), cada uno enlazando al flujo EXISTENTE. NO implementa
//  mecánica nueva: es el mapa.
//
//  Vista NAVEGADA dentro del NavigationStack de ProfileView (stack del sheet de Profile ⇒ `.subtle`).
//  "Cerrar sesión"/"Eliminar cuenta" disparan el @State de ProfileView vía closures — ProfileView es el
//  DUEÑO ÚNICO de las hojas de alcance, los observers de `phase` y el cover terminal del root; re-hostear
//  esos observers aquí violaría "dos anchors ante el mismo observable" (bug device 2026-07-14). "Volver a
//  iCloud" es un `NavigationLink(value: .storageMode)` (destino registrado en el root del stack).
//
//  Desde el paso 9 es la ÚNICA puerta de «Eliminar mi cuenta» (App Store 5.1.1 v, a dos toques), así que
//  hereda el bloqueo cruzado que tenía la fila retirada de Ajustes: con un cierre o un borrado en curso, las
//  dos salidas quedan deshabilitadas (review adversarial del paso 9 — sin él se podían correr a la vez).
//

import SwiftUI

struct YalaAccountView: View {
    /// Dispara el flujo "Cerrar sesión" de ProfileView (la misma hoja por celda que su fila de Ajustes,
    /// `requestSignOut`).
    let onSignOut: () -> Void
    /// Dispara el flujo "Eliminar mi cuenta" de ProfileView (hoja de alcance con el resumen D5 READ-ONLY).
    let onDeleteAccount: () -> Void
    /// Un cierre o un borrado de cuenta en curso: el cierre no puede arrancar encima (lo decide ProfileView).
    var signOutDisabled: Bool = false
    /// Ídem para el borrado: tampoco con un cierre parado en un aviso, que sigue esperando una decisión.
    var deleteDisabled: Bool = false
    /// Solo para `#Preview`: fuerza un modelo concreto (las variantes `.cloud` son DARK e inalcanzables en
    /// sim). En runtime es `nil` ⇒ se computa VIVO de los singletons.
    var previewModel: YalaAccountLogic.Model?

    @Environment(\.yalaTheme) private var theme

    /// Provider crudo del wire, leído VIVO (lección I4 — `storedProvider()` se congela si se guarda al init).
    /// Seam DEBUG-only: bajo `-uitest-fake-backend-session` el `hasSession` real es `false` y
    /// `storedProvider()` es `nil` en sim → se muestra "apple" SOLO para QA (inerte en release vía `hasArg`).
    private var rawProvider: String? {
        UITestHooks.fakeBackendSession
            ? CloudSignInProvider.apple.rawValue
            : CloudAuthService.shared.storedProvider()
    }

    private var model: YalaAccountLogic.Model {
        if let previewModel { return previewModel }
        return YalaAccountLogic.model(
            provider: rawProvider,
            storageMode: CloudSyncFlags.storageMode,
            canDeleteAccount: AccountDeletionRowLogic.shouldShow(
                hasSession: UITestHooks.fakeBackendSession || CloudAuthService.shared.hasSession),
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                header
                dataLocationSection
                exitsSection
            }
            .padding(.vertical, DS.Spacing.xxl)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.yalaAccountTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("yala_account_screen")
    }

    // MARK: - Header (método de entrada + nota de vínculo)

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(DS.Typography.title)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text(methodLine)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Q1 (owner): nota general del vínculo Apple↔Google, siempre (H4 no detectable client-side).
            if model.showLinkingNote {
                Text(L10n.Settings.yalaAccountLinkingNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .solidCard(radius: DS.Radius.xl)
    }

    private var methodLine: String {
        switch model.method {
        case .apple:   return L10n.Settings.yalaAccountMethodApple
        case .google:  return L10n.Settings.yalaAccountMethodGoogle
        case .unknown: return L10n.Settings.yalaAccountMethodUnknown
        }
    }

    // MARK: - Dónde viven los datos

    private var dataLocationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Settings.yalaAccountDataLocationTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(dataLocationText)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .solidCard(radius: DS.Radius.xl)
    }

    private var dataLocationText: String {
        switch model.dataLocation {
        case .cloud:               return L10n.Settings.yalaAccountDataLocationCloud
        case .groupsOnly:          return L10n.Settings.yalaAccountDataLocationGroupsOnly
        case .groupsOnlyNoPrivate: return L10n.Settings.yalaAccountDataLocationGroupsOnlyNoPrivate
        }
    }

    /// Qué se lleva «Eliminar mi cuenta», en una línea. En el «equipo» (D) se borra la cuenta de GRUPOS y lo
    /// personal sigue en iCloud: «Se borra todo, para siempre» contradecía a su propia hoja (review adversarial
    /// del paso 9). En la nube completa y en solo grupos sí se va todo.
    private var deleteScopeText: String {
        model.dataLocation == .groupsOnly
            ? L10n.Settings.deleteAccountScopeCloudGroupsOnly
            : L10n.Settings.yalaAccountDeleteScope
    }

    // MARK: - Desenlaces (mapa accionable — cada uno enlaza al flujo existente)

    private var exitsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(model.exits.indices, id: \.self) { i in
                if i > 0 { SubsectionDivider() }
                exitRow(model.exits[i])
            }
        }
        .solidCard(radius: DS.Radius.xl)
    }

    @ViewBuilder
    private func exitRow(_ exit: YalaAccountLogic.Exit) -> some View {
        switch exit {
        case .signOut:
            Button(action: onSignOut) {
                exitRowContent(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: L10n.Settings.signOut,
                    subtitle: L10n.Settings.yalaAccountSignOutScope,
                    destructive: false)
            }
            .buttonStyle(.plain)
            .disabled(signOutDisabled)
            .accessibilityIdentifier("yala_account_signout")

        case .returnToICloud:
            NavigationLink(value: ProfileDestination.storageMode) {
                exitRowContent(
                    icon: "lock.icloud",
                    title: L10n.Settings.yalaAccountReturnICloud,
                    subtitle: L10n.Settings.yalaAccountReturnICloudScope,
                    destructive: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("yala_account_return_icloud")

        case .deleteAccount:
            Button(action: onDeleteAccount) {
                exitRowContent(
                    icon: "trash",
                    title: L10n.Settings.deleteAccount,
                    subtitle: deleteScopeText,
                    destructive: true)
            }
            .buttonStyle(.plain)
            .disabled(deleteDisabled)
            .accessibilityIdentifier("yala_account_delete")
        }
    }

    private func exitRowContent(icon: String, title: String, subtitle: String, destructive: Bool) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(destructive ? DS.Semantic.errorForeground : theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(destructive ? DS.Semantic.errorForeground : .primary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(DS.Typography.labelSmall.weight(.medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }
}

#Preview("Nube (.cloud)") {
    NavigationStack {
        YalaAccountView(
            onSignOut: {}, onDeleteAccount: {},
            previewModel: .init(method: .apple, showLinkingNote: true, dataLocation: .cloud,
                                exits: [.signOut, .returnToICloud, .deleteAccount]))
    }
    .previewAppPreferences()
}

#Preview("Solo grupos (5b)") {
    NavigationStack {
        YalaAccountView(
            onSignOut: {}, onDeleteAccount: {},
            previewModel: .init(method: .google, showLinkingNote: true, dataLocation: .groupsOnly,
                                exits: [.signOut, .deleteAccount]))
    }
    .previewAppPreferences()
}
