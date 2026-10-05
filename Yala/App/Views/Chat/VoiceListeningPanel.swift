//
//  VoiceListeningPanel.swift
//  Yala
//
//  El panel de escucha de Yala IA: sustituye a la caja de escribir mientras dictas. Un orbe que late con tu voz, el
//  tiempo que llevas y dos salidas claras — Cancelar (descarta sin transcribir) y Listo (transcribe y deja el texto en
//  la caja). Al transcribir, el orbe gira y el panel recuerda que revises el texto antes de enviarlo.
//
//  El orbe y el tiempo son `VoiceListeningOrb`, que comparte con el registro por voz (`VoiceRecordingView`): las dos
//  formas de hablarle a Yala se ven y se mueven igual.
//

import SwiftUI

struct VoiceListeningPanel: View {
    let isTranscribing: Bool
    let duration: TimeInterval
    /// Nivel de la voz, de 0 a 1.
    let level: Double
    let accent: Color
    let reduceMotion: Bool
    let onCancel: () -> Void
    let onDone: () -> Void

    private let buttonHeight: CGFloat = 48 // A11Y-DT: tap target de Cancelar y Listo

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(isTranscribing ? L10n.Chat.transcribing : L10n.Chat.listening)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(isTranscribing ? L10n.Chat.voiceTranscribingHint : L10n.Chat.voiceHint)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            VoiceListeningOrb(
                isTranscribing: isTranscribing,
                duration: duration,
                level: level,
                accent: accent,
                reduceMotion: reduceMotion
            )

            if !isTranscribing {
                HStack(spacing: DS.Spacing.md) {
                    Button(action: onCancel) {
                        Text(L10n.Action.cancel)
                            .font(DS.Typography.body.weight(.medium))
                            .foregroundStyle(.thPrimaryText)
                            .frame(maxWidth: .infinity, minHeight: buttonHeight)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Accessibility.discardRecording)
                    .accessibilityIdentifier("chat_voice_cancel")

                    Button(action: onDone) {
                        Text(L10n.Action.done)
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(Color.contrastingText(for: accent))
                            .frame(maxWidth: .infinity, minHeight: buttonHeight)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_voice_done")
                }
                .padding(.top, DS.Spacing.xs)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat_voice_panel")
    }
}

/// El orbe del dictado y, debajo, el tiempo. Grabando, el halo late con la voz y un punto rojo parpadea junto al
/// tiempo; transcribiendo, un anillo gira y el tiempo pasa a «0:07 grabados». Con «Reducir movimiento», el halo se
/// queda quieto y el anillo es el spinner del sistema.
struct VoiceListeningOrb: View {
    let isTranscribing: Bool
    let duration: TimeInterval
    /// Nivel de la voz, de 0 a 1.
    let level: Double
    let accent: Color
    let reduceMotion: Bool

    @State private var isPulsing = false
    @State private var isSpinning = false

    private let orbSize: CGFloat = 64 // A11Y-DT: orbe central del dictado
    private let haloSize: CGFloat = 112 // A11Y-DT: halo que late con la voz
    private let ringInset: CGFloat = 28 // A11Y-DT: halo interior y anillo de «transcribiendo»

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            orb
            timeLabel
        }
        .onAppear {
            isPulsing = true
            isSpinning = true
        }
    }

    // MARK: - Orbe

    private var orb: some View {
        ZStack {
            if isTranscribing {
                if reduceMotion {
                    ProgressView()
                        .controlSize(.large)
                        .tint(accent)
                        .frame(width: haloSize, height: haloSize)
                } else {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 3)
                        .frame(width: haloSize - ringInset, height: haloSize - ringInset)
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: haloSize - ringInset, height: haloSize - ringInset)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
                }
            } else {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: haloSize, height: haloSize)
                    .scaleEffect(haloScale(strength: 0.2))
                Circle()
                    .fill(accent.opacity(0.32))
                    .frame(width: haloSize - ringInset, height: haloSize - ringInset)
                    .scaleEffect(haloScale(strength: 0.15))
            }

            Circle()
                .fill(isTranscribing ? Color(.tertiarySystemFill) : accent)
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .semibold)) // A11Y-DT: glifo del orbe
                        .foregroundStyle(isTranscribing ? Color.secondary : Color.contrastingText(for: accent))
                }
        }
        .frame(width: haloSize, height: haloSize)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }

    /// En silencio el halo descansa por debajo de su tamaño; con la voz crece hasta su tamaño y un poco más.
    private func haloScale(strength: Double) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return CGFloat(1 - strength + level * strength * 1.6)
    }

    // MARK: - Tiempo

    private var timeLabel: some View {
        HStack(spacing: DS.Spacing.sm) {
            if !isTranscribing {
                Circle()
                    .fill(DS.Semantic.errorForeground)
                    .frame(width: 8, height: 8) // A11Y-DT: punto de «grabando»
                    .opacity(reduceMotion || !isPulsing ? 1 : 0.35)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
            Text(isTranscribing ? L10n.Chat.voiceRecorded(formattedDuration) : formattedDuration)
                .font(DS.Typography.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var formattedDuration: String {
        Duration.seconds(duration.rounded(.down)).formatted(.time(pattern: .minuteSecond))
    }
}
