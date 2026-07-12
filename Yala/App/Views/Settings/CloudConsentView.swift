//
//  CloudConsentView.swift
//  Yala
//
//  Pantalla de consentimiento informado del Modo Nube (§2.8 / §k.6, I14 P5). SIEMPRE precede al sign-in
//  (el login envía identidad) y a la doble confirmación de migración. Enumera, en lenguaje claro, QUÉ sale
//  del dispositivo, QUIÉN puede leerlo y DÓNDE se guarda (los 7 puntos de §k.6). Al aceptar registra
//  `cloudConsentAcceptedAt` + `cloudConsentTextVersion` (trazabilidad GDPR §e.6) + telemetría, y ejecuta
//  `onAccept` (el caller sigue con la doble confirmación → migración/adopt).
//
//  Distinción (§k.6): este consent es sobre PRIVACIDAD (qué sale / quién lo lee). La doble confirmación de
//  migración (patrón `DataWipeService`) es sobre la ACCIÓN (mover los datos) y la muestra `StorageSettingsView`.
//

import SwiftUI

struct CloudConsentView: View {
    /// Ruta que abrió el consent (para la telemetría §j.4).
    let path: CloudMigrationController.ConsentPath
    /// Se invoca al ACEPTAR (tras registrar consent + telemetría). El caller sigue con la doble confirmación.
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
            .navigationTitle(L10n.Storage.Consent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("storage_consent_cancel")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: "hand.raised.fill")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.infoForeground)
            Text(L10n.Storage.Consent.title)
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
            YalaPrimaryButton(L10n.Storage.Consent.accept, icon: "checkmark.icloud") {
                registerConsent()
                onAccept()
            }
            .accessibilityIdentifier("storage_consent_accept")
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Registra el consentimiento (persistencia GDPR + telemetría). En `.icloud` va a iKV y el drenaje del
    /// cutover lo lleva al backend; en `.cloud` (adopt) va directo al outbox de prefs.
    private func registerConsent() {
        PreferenceSyncService.shared.set(
            int: Int(Date.now.timeIntervalSince1970),
            forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
        PreferenceSyncService.shared.set(
            int: CloudConsentText.version,
            forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)
        TelemetryService.cloudConsentAccepted(path: path.rawValue)
    }

    /// Los 7 puntos de §k.6, en orden.
    private static var points: [String] {
        [
            L10n.Storage.Consent.point1,
            L10n.Storage.Consent.point2,
            L10n.Storage.Consent.point3,
            L10n.Storage.Consent.point4,
            L10n.Storage.Consent.point5,
            L10n.Storage.Consent.point6,
            L10n.Storage.Consent.point7,
        ]
    }
}
