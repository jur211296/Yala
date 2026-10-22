//
//  ChatMessageBubble.swift
//  Yala
//
//  Burbuja de un mensaje del chat, como en una app de mensajería: el color dice quién habla (la del usuario en el
//  acento, a la derecha; la de Yala IA en blanco, a la izquierda) y no hay nombres ni iconos por mensaje.
//

import SwiftUI

struct ChatMessageBubble: View {

    let message: ChatMessage
    var viewModel: ChatAssistantViewModel?

    @Environment(\.yalaTheme) private var theme

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: DS.Spacing.xxxl) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: DS.Spacing.sm) {
                bubbleText
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(isUser ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
                    .clipShape(ChatBubbleShape())

                if let attachments = message.attachments,
                   !attachments.isEmpty,
                   let viewModel
                {
                    ChatAttachmentsView(
                        messageID: message.id,
                        attachments: attachments,
                        viewModel: viewModel
                    )
                }
            }

            if !isUser { Spacer(minLength: DS.Spacing.xxxl) }
        }
    }

    /// El texto, en párrafos separados. La negrita y el `código` llegan del markdown en línea de la respuesta; las
    /// cifras van con dígitos de ancho fijo para que un importe se lea de un vistazo.
    private var bubbleText: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(ChatBubbleText.paragraphs(of: message.text).enumerated()), id: \.offset) { _, paragraph in
                Text(LocalizedStringKey(paragraph))
            }
        }
        .font(DS.Typography.body.monospacedDigit())
        .foregroundStyle(isUser ? AnyShapeStyle(Color.contrastingText(for: theme.accent)) : AnyShapeStyle(.thPrimaryText))
    }
}

/// La forma de toda burbuja del chat: radio grande y esquina continua. La comparten el mensaje, el saludo con sus
/// sugerencias y el «pensando», para que el hilo tenga una sola silueta.
struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).path(in: rect)
    }
}

/// Cómo se parte el texto de una burbuja.
enum ChatBubbleText {
    /// Párrafos: lo que separa una línea en blanco. Los saltos simples se quedan dentro del párrafo, y un texto sin
    /// líneas en blanco es un solo párrafo, tal cual.
    nonisolated static func paragraphs(of text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return blocks.isEmpty ? [text] : blocks
    }
}
