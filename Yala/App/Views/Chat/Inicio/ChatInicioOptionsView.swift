//
//  ChatInicioOptionsView.swift
//  Yala
//
//  Lo que Yala ofrece debajo de su respuesta a un botón del inicio (encargo del 17-nov):
//  - «Anotaré un gasto»: tres ejemplos. Tocar uno lo escribe en la caja, SIN enviarlo: la persona pone lo suyo.
//  - «Preguntaré por mis finanzas»: las tres preguntas de hoy. Tocar una la envía.
//  - «Quiero crear algo»: lo que se crea conversando. Tocar una abre su guiado.
//  Las pinta `ChatSheetView` mientras la respuesta sea lo último del hilo (`ChatInicioLogic.showsOptions`); en cuanto
//  entra otro mensaje se van y queda un chat normal.
//

import SwiftUI

struct ChatInicioOptionsView: View {

    let branch: ChatInicioBranch
    let suggestions: [ChatSuggestion]
    /// Mientras se preparan las preguntas de hoy, la ficha lo dice en su sitio en vez de enseñar filas vacías.
    let isPreparing: Bool
    let onExample: (String) -> Void
    let onSuggestion: (ChatSuggestion) -> Void
    let onCreate: (ChatInicioCreateOption) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            switch branch {
            case .logExpense:
                rows(YalaIAInicioText.logExamples) { exampleRow($0) }
            case .askFinances:
                if isPreparing {
                    preparingRow
                        .transition(.loadingPlaceholder)
                } else {
                    rows(Array(suggestions.prefix(ChatInicioLogic.askOptionCount))) { suggestionRow($0) }
                }
            case .create:
                rows(ChatInicioLogic.createOptions()) { createRow($0) }
            }
        }
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        // «Preparando…» → las preguntas, fundiéndose (card C7). Detrás del fondo y el recorte: así la ficha crece con
        // ellas en vez de saltar a su alto final.
        .animation(reduceMotion ? nil : DS.Animation.appear, value: isPreparing)
    }

    /// Filas con un separador entre una y otra.
    private func rows<Item, Row: View>(_ items: [Item], @ViewBuilder row: @escaping (Item) -> Row) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            if index > 0 {
                Divider()
                    .padding(.leading, DS.Spacing.lg)
            }
            row(item)
        }
    }

    // MARK: - Filas

    /// Un ejemplo de apuntar: se escribe en la caja con el teclado abierto, sin enviarse.
    private func exampleRow(_ example: String) -> some View {
        Button {
            onExample(example)
        } label: {
            optionLabel(text: example, trailing: "square.and.pencil")
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.UXL14D.logRowHint)
        .accessibilityIdentifier("chat_start_example")
    }

    /// Una pregunta de hoy: se envía al tocarla.
    private func suggestionRow(_ suggestion: ChatSuggestion) -> some View {
        Button {
            onSuggestion(suggestion)
        } label: {
            optionLabel(text: suggestion.text, trailing: "arrow.up.circle.fill")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_suggestion")
    }

    /// Algo que se crea conversando: abre su guiado.
    private func createRow(_ option: ChatInicioCreateOption) -> some View {
        Button {
            onCreate(option)
        } label: {
            optionLabel(text: option.title, leading: option.systemImage, trailing: "arrow.right.circle.fill")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.accessibilityIdentifier)
    }

    private func optionLabel(text: String, leading: String? = nil, trailing: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            if let leading {
                Image(systemName: leading)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accentText)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: trailing)
                .font(DS.Typography.title3)
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    private var preparingRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.Chat.preparingAI)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}
