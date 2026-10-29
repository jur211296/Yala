//
//  VoiceLiveListeningViews.swift
//  Yala
//
//  Las piezas de «Escuchando» del registro por voz (propuesta A de la card tjws): la onda de barras que corre de
//  derecha a izquierda con el nivel del micrófono, el tiempo con su punto rojo y la frase que va entendiendo el iPhone.
//

import SwiftUI

/// Barras que siguen la voz, la más nueva a la derecha y las viejas desvaneciéndose hacia la izquierda, como Notas de
/// voz. Con «Reducir movimiento» se queda quieta. Oculta a VoiceOver, como el orbe: la frase y el tiempo dicen lo mismo.
struct VoiceWaveform: View {
    /// Niveles de 0 a 1, del más viejo al más nuevo (`VoiceLiveListeningLogic.appending`).
    let levels: [Double]
    let accent: Color
    let reduceMotion: Bool

    private let barWidth: CGFloat = 3 // A11Y-DT: grosor de cada barra de la onda
    private let barGap: CGFloat = 3 // A11Y-DT: aire entre barras
    private let height: CGFloat = 64 // A11Y-DT: alto de la onda

    var body: some View {
        Canvas { context, size in
            let step = barWidth + barGap
            let count = max(0, Int((size.width + barGap) / step))
            let bars = VoiceLiveListeningLogic.visibleBars(reduceMotion ? [] : levels, count: count)
            let usedWidth = CGFloat(count) * step - barGap
            let originX = max(0, (size.width - usedWidth) / 2)
            for (index, level) in bars.enumerated() {
                let barHeight = max(barWidth, CGFloat(level) * size.height)
                let rect = CGRect(
                    x: originX + CGFloat(index) * step,
                    y: (size.height - barHeight) / 2,
                    width: barWidth,
                    height: barHeight
                )
                let fade = count > 1 ? 0.35 + 0.65 * Double(index) / Double(count - 1) : 1
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(accent.opacity(fade)))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        // Para VoiceOver no existe; en XCUITest se deja ver, con cuántas barras suenan, para probar que sigue la voz.
        .accessibilityElement()
        .accessibilityValue("\(levels.filter { $0 > VoiceLiveListeningLogic.silentLevel }.count)")
        .accessibilityHidden(!UITestHooks.isActive)
        .accessibilityIdentifier("voice_waveform")
    }
}

/// El tiempo grabado con el punto rojo que parpadea (el mismo del orbe de Yala IA).
struct VoiceRecordingTimeLabel: View {
    let duration: TimeInterval
    let reduceMotion: Bool

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(DS.Semantic.errorForeground)
                .frame(width: 8, height: 8) // A11Y-DT: punto de «grabando»
                .opacity(reduceMotion || !isPulsing ? 1 : 0.35)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text(Duration.seconds(duration.rounded(.down)).formatted(.time(pattern: .minuteSecond)))
                .font(DS.Typography.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .onAppear { isPulsing = true }
    }
}

/// La frase en vivo: lo anterior en secundario y las tres últimas palabras en primario. Recorta por delante para que
/// siempre se vea lo último que dijiste. Sin texto ocupa su sitio igual, para que la hoja no salte al llegar.
struct VoiceLiveTranscriptText: View {
    let text: String

    var body: some View {
        let parts = VoiceLiveListeningLogic.split(text)
        let older = Text(parts.older.isEmpty ? "" : parts.older + " ").foregroundStyle(.secondary)
        let recent = Text(parts.recent).foregroundStyle(.thPrimaryText)
        Text("\(older)\(recent)")
            .font(DS.Typography.body)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .truncationMode(.head)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 66, alignment: .top) // A11Y-DT: sitio reservado para la frase en vivo
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Voice.liveTranscriptAccessibility)
            .accessibilityValue(text)
            .accessibilityHidden(text.isEmpty)
            .accessibilityIdentifier("voice_live_transcript")
    }
}
