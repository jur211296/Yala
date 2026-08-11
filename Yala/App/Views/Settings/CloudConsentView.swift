//
//  CloudConsentView.swift
//  Yala
//
//  Pantalla de consentimiento informado del Modo Nube (§2.8 / §k.6, I14 P5). SIEMPRE precede al sign-in
//  (el login envía identidad) y a la doble confirmación de migración. Dice, en lenguaje claro, QUÉ sale
//  del dispositivo, QUIÉN puede leerlo y qué NO viaja. Al aceptar registra `cloudConsentAcceptedAt` +
//  `cloudConsentTextVersion` (trazabilidad GDPR §e.6) + telemetría, y ejecuta `onAccept` (el caller sigue
//  con la doble confirmación → migración/adopt).
//
//  Distinción (§k.6): este consent es sobre PRIVACIDAD (qué sale / quién lo lee). La doble confirmación de
//  migración (patrón `DataWipeService`) es sobre la ACCIÓN (mover los datos) y la muestra `StorageSettingsView`.
//
//  W3 (decisión del owner 2026-08-11, puntos 12-14 de MODO-NUBE-REVISION-FLUJOS-NOTAS): esto es una
//  LECTURA DE TÉRMINOS, no una alerta grave — el usuario está subiendo sus datos a la nube, como en la
//  mayoría de sus aplicaciones. De ahí que no haya iconografía de alarma (fuera el `hand.raised.fill` del
//  header y los `info.circle.fill` de cada punto) y que los 7 bullets sean TRES + un pie. Qué salió y a
//  dónde, para que legal no pierda el rastro: el resumen que viaja al proveedor de IA vive en el consent
//  de IA (`aiConsent.chatMessage`) y la ubicación de los servidores en la política de privacidad, a un tap
//  de aquí. `CloudConsentText.version` se bumpeó por ese recorte.
//
//  **La MISMA pantalla sirve a los tres contextos** —alta born-cloud, migración desde iCloud y re-entrada
//  a una cuenta que ya existe— y solo cambia el `path` de la telemetría. Por eso el copy no puede asumir
//  ninguno de los tres: el título habla de dónde viven los datos y no de «activar» nada.
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
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(Array(Self.points.enumerated()), id: \.offset) { _, point in
                            consentPoint(point)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Text(L10n.Storage.Consent.footer)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Viñeta tipográfica en vez de icono: la marca de lista es del documento, no una señal.
    /// Oculta a VoiceOver — leerla en voz alta antes de cada punto solo estorba.
    private func consentPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(verbatim: "•")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
        MetricsService.cloudConsentAccepted(path: path.rawValue)
    }

    /// Lo que el usuario tiene que saber ANTES de firmar, en orden: dónde acaban sus datos y
    /// quién los lee · qué NO viaja (las fotos: su ausencia es pérdida real) · cómo se entra y
    /// qué pasa si pierde ese acceso. El cuarto bloque —volver atrás es posible— va al pie:
    /// es un alivio, no una advertencia, y mezclarlo aquí lo disfrazaba de riesgo.
    private static var points: [String] {
        [
            L10n.Storage.Consent.pointServers,
            L10n.Storage.Consent.pointPhotos,
            L10n.Storage.Consent.pointAccess,
        ]
    }
}
