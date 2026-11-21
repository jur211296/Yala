//
//  ProTryNowSection.swift
//  Yala
//
//  «Pruébalo ahora» de «¡Listo! Tienes Pro» (opción B de Jürgen, 20-nov-2026, tema 3 de las maquetas de Primeros pasos):
//  sustituye al tour Pro, que perseguía a la persona por Ajustes, el Panel y Estadísticas en días distintos. Tres accesos
//  que abren la función en el acto (dictar, leer un recibo, Yala IA) y una línea para temas e iconos. La función se abre
//  cuando la hoja de la compra termina de cerrarse: pedirla con la hoja arriba sería presentar sobre una presentación.
//

import SwiftUI

/// Lo que se abre desde «Pruébalo ahora».
enum ProTryNowAction: String, CaseIterable, Equatable {
    case voice
    case photo
    case yalaAI
}

/// El lado con efectos: abre la función por las puertas de siempre.
@MainActor
enum ProTryNow {
    /// Voz y foto van por la misma puerta que el Centro de Control y Siri (`AppBootstrapper.performPanelAction`: el Panel
    /// delante, el consentimiento si falta). Yala IA, por la de ⌘K (`pendingKeyboardPanelRequest`), que el Panel consume
    /// cuando está delante. Lo encola la ventana que la persona usa.
    static func open(_ action: ProTryNowAction) {
        switch action {
        case .voice:
            AppBootstrapper.shared.performPanelAction(.voiceEntry)
        case .photo:
            AppBootstrapper.shared.performPanelAction(.imageEntry)
        case .yalaAI:
            guard let navigation = SceneRegistry.shared.routingNavigation else { return }
            navigation.pendingKeyboardPanelRequest = .yalaAI
            navigation.selectMainTab(.panel)
        }
    }
}

/// «Pruébalo ahora» con sus tres filas y la línea de temas e iconos.
struct ProTryNowSection: View {
    private typealias T = PrimerosPasosPaso7Text.TryNow

    let onTry: (ProTryNowAction) -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(T.header)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(ProTryNowAction.allCases.enumerated()), id: \.element) { index, action in
                    if index > 0 { Divider().padding(.leading, DS.Spacing.md + 32 + DS.Spacing.md) }
                    row(action)
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            Text(T.extras)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pro_try_now_extras")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro_try_now")
    }

    private func row(_ action: ProTryNowAction) -> some View {
        Button {
            DS.Haptic.selection()
            onTry(action)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon(action))
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(action))
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail(action))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro_try_now_\(action.rawValue)")
    }

    private func icon(_ action: ProTryNowAction) -> String {
        switch action {
        case .voice: "waveform"
        case .photo: "doc.text.viewfinder"
        case .yalaAI: "sparkles"
        }
    }

    private func title(_ action: ProTryNowAction) -> String {
        switch action {
        case .voice: T.voiceTitle
        case .photo: T.photoTitle
        case .yalaAI: T.aiTitle
        }
    }

    private func detail(_ action: ProTryNowAction) -> String {
        switch action {
        case .voice: T.voiceDetail
        case .photo: T.photoDetail
        case .yalaAI: T.aiDetail
        }
    }
}
