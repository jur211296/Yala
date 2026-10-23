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
    /// Por dónde entró el usuario (`organizer` | `invite` | `tab`). Viaja al registro de la cuenta como
    /// diagnóstico —jamás PII, y el RPC lo acota a 32 chars—: sirve para saber qué puerta produce los
    /// consents y, en un incidente, cuál dejó de producirlos.
    var path: String = "invite"
    /// Se invoca al ACEPTAR (tras registrar consent + telemetría). El caller continúa el join.
    var onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    // UX 2.2 · L12-5 (decisión B de Jürgen, 2026-10-18): UN solo título. Antes salía en la barra y otra
                    // vez como cabecera; se queda el de dentro, que es el que se lee.
                    header
                    GroupsConsentPoints()
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
        Text(L10n.Groups.Consent.title)
            .font(DS.Typography.title2)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, DS.Spacing.lg)
    }

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(L10n.Groups.Consent.accept, icon: "checkmark.shield") {
                Self.registerAcceptance(path: path)
                onAccept()
            }
            .accessibilityIdentifier("groups_consent_accept")
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Registra el consentimiento (persistencia GDPR + telemetría R7).
    ///
    /// Es el CHOKE-POINT ÚNICO que comparten organizador, invitado y tab, y por eso el intent durable se
    /// arma aquí dentro (`GroupsConsentRegistrar.register`) y **antes** de `onAccept()`: ese callback
    /// cierra el sheet y continúa el flujo, así que armar después de él ya sería tarde.
    ///
    /// El registro contra la cuenta NO bloquea al usuario: aceptó de verdad y un fallo nuestro de red no
    /// puede castigarle. La caché local se escribe siempre y las cinco tablas de routing la leen, así que
    /// la puerta no depende del request.
    ///
    /// Desde UX 2.2 · L12-4 hay DOS sitios donde se acepta (esta hoja y el paso 3 del educativo), y los dos pasan por
    /// aquí: un segundo escritor es como el registro legal empieza a divergir.
    static func registerAcceptance(path: String) {
        GroupsConsentRegistrar.shared.register(path: path)
        MetricsService.cloudConsentAccepted(path: "groups")
    }
}

/// Los cuatro puntos del consentimiento de Grupos, cada uno con su icono en el índigo de la marca (UX 2.2 · L12-5,
/// decisión B: nube, persona, candado, salida; antes eran cuatro «i» iguales en el azul del sistema y no se leía
/// ninguno). Una sola pieza para la hoja y para el paso 3 del educativo, que desde L12-4 ES el consentimiento: así los
/// dos sitios donde se acepta enseñan el mismo texto.
struct GroupsConsentPoints: View {
    /// Los 4 puntos de §8, en orden, con su icono.
    static var points: [(icon: String, text: String)] {
        [
            ("icloud.fill", L10n.Groups.Consent.point1),
            ("person.fill", L10n.Groups.Consent.point2),
            ("lock.fill", L10n.Groups.Consent.point3),
            ("rectangle.portrait.and.arrow.right", L10n.Groups.Consent.point4),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(Array(Self.points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: point.icon)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text(point.text)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
