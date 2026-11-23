//
//  ConectaTuIAGuide.swift
//  Yala
//
//  Los pasos para conectar Claude, ChatGPT o Grok y la dirección del conector con «Copiar». Una sola pieza para
//  Ajustes › Tu IA y el paso 7 de Primeros pasos, para que los dos digan lo mismo. Los pasos se hacen FUERA de Yala:
//  la app no puede saber si se hicieron.
//

import SwiftUI

struct ConectaTuIAGuide: View {
    @Binding var provider: ConectaTuIALogic.Provider
    /// Sin la cuenta de Yala los pasos se ven apagados: conectar ahí solo daría una IA que dice «no tienes datos».
    var isEnabled = true
    /// Dentro de una tarjeta propia (Ajustes) o sobre el fondo de la página (Primeros pasos), donde cada paso lleva la suya.
    var stepsOnCards = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Picker(L10n.ConectaTuIA.stepsHeader, selection: $provider) {
                ForEach(ConectaTuIALogic.Provider.allCases) { provider in
                    Text(verbatim: provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(L10n.ConectaTuIA.stepsHeader)
            .accessibilityIdentifier("conecta_ia_provider")

            if provider == .chatgpt {
                Label {
                    Text(L10n.ConectaTuIA.chatGPTNote).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("conecta_ia_chatgpt_note")
            }

            let steps = L10n.ConectaTuIA.steps(provider)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                step(index + 1, text)
                if index == 1 {
                    ConectaTuIAAddressCard(isEnabled: isEnabled, onCard: stepsOnCards)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .animation(nil, value: provider)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(verbatim: "\(number)")
                .font(DS.Typography.subheadline.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(stepsOnCards ? DS.Spacing.md : DS.Spacing.none)
        .background {
            if stepsOnCards { RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conecta_ia_step_\(number)")
    }
}

/// La dirección del conector de esta nube, con «Copiar».
struct ConectaTuIAAddressCard: View {
    var isEnabled = true
    var onCard = false

    @State private var copied = false
    @Environment(\.yalaTheme) private var theme

    private var address: String {
        #if DEV_BUILD
        ConectaTuIALogic.connectorAddress(isDevBuild: true)
        #else
        ConectaTuIALogic.connectorAddress(isDevBuild: false)
        #endif
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(verbatim: address)
                .font(DS.Typography.subheadline.monospaced())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("conecta_ia_address")
            Button {
                UIPasteboard.general.string = address
                copied = true
                DS.Haptic.success()
            } label: {
                Label(copied ? L10n.ConectaTuIA.copied : L10n.ConectaTuIA.copy,
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!isEnabled)
            .accessibilityHint(L10n.ConectaTuIA.copyHint)
            .accessibilityIdentifier("conecta_ia_copy")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(onCard ? theme.card : Color.secondary.opacity(0.12))
        )
        .task(id: copied) {
            guard copied else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                copied = false
            } catch {
                // Cancelada al salir de la pantalla: nada que volver a pintar.
            }
        }
    }
}
