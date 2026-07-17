//
//  GroupsConsentView.swift
//  Yala
//
//  Pantalla de consentimiento informado de GRUPOS (G4-invites A2, §8 / contrato C5). Molde de
//  `CloudConsentView`: precede al PRIMER create/join backend y explica, en lenguaje claro, que los
//  grupos son compartidos por naturaleza y viven en la nube de Yala con lo MÍNIMO (alias + gastos del
//  grupo), mientras los datos personales siguen donde el usuario eligió. NO promete "cifrado" (G7 no
//  aterrizó — "protegidos" es lo honesto).
//
//  Al aceptar: `GroupsConsentState.register()` (PrefSyncKeys §C5) + telemetría
//  `cloudConsentAccepted(path: "groups")` (String directo — R7: el enum ConsentPath es del dominio
//  migración, prohibido contaminarlo) + `onAccept` (el caller continúa el flujo encadenado → join).
//
//  DARK: solo la presenta el drain de `.presentGroupsConsent` (flag `groupsBackendEnabled` OFF ⇒ el
//  intent jamás se submitea).
//

import SwiftUI

struct GroupsConsentView: View {
    /// Se invoca al ACEPTAR (tras registrar consent + telemetría). El caller continúa el join.
    var onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(Array(Self.points.enumerated()), id: \.offset) { _, point in
                            consentPoint(point)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Button {
                        openURL(AppConstants.privacyURL)
                    } label: {
                        Text(L10n.Storage.Consent.privacyLink)
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Semantic.infoForeground)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.Spacing.lg)

                    ctaSection
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Consent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("groups_consent_cancel")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: "person.2.fill")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.infoForeground)
            Text(L10n.Groups.Consent.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func consentPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xxs)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(L10n.Groups.Consent.accept, icon: "checkmark.shield") {
                registerConsent()
                onAccept()
            }
            .accessibilityIdentifier("groups_consent_accept")
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Registra el consentimiento (persistencia GDPR C5 + telemetría R7).
    private func registerConsent() {
        GroupsConsentState.register()
        MetricsService.cloudConsentAccepted(path: "groups")
    }

    /// Los 4 puntos de §8, en orden.
    private static var points: [String] {
        [
            L10n.Groups.Consent.point1,
            L10n.Groups.Consent.point2,
            L10n.Groups.Consent.point3,
            L10n.Groups.Consent.point4,
        ]
    }
}
