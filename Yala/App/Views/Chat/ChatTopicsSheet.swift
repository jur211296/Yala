//
//  ChatTopicsSheet.swift
//  Yala
//
//  «Temas de conversación» por áreas (UX 2.2 · L14-6, opción B elegida por Jürgen el 2026-10-18): Gastos,
//  Presupuestos, Pagos planificados y Apuntar, con dos o tres ejemplos cada una sacados de los datos del usuario
//  (`ChatTopicAreasLogic`). Antes repetía las tres sugerencias del saludo, en el mismo orden.
//
//  Tocar una pregunta cierra la hoja y la envía. Tocar un ejemplo de Apuntar la cierra y lo escribe en la caja, con el
//  teclado abierto: el importe es del usuario.
//

import SwiftUI

struct ChatTopicsSheet: View {

    let areas: [ChatTopicAreaContent]
    let onSelect: (ChatTopicExample) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    ForEach(areas) { content in
                        areaSection(content)
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Chat.Topics.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private func areaSection(_ content: ChatTopicAreaContent) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: Self.icon(for: content.area))
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
                Text(Self.title(for: content.area))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("chat_topics_area_\(content.area.rawValue)")

            ForEach(content.examples) { example in
                topicChip(example)
            }
        }
    }

    private func topicChip(_ example: ChatTopicExample) -> some View {
        Button {
            onSelect(example)
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(example.text)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Lo que se envía lleva la flecha de enviar; lo que se escribe en la caja, el lápiz.
                Image(systemName: example.sends ? "arrow.up" : "square.and.pencil")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(example.sends ? "" : L10n.UXL14D.logRowHint)
        .accessibilityIdentifier(example.sends ? "chat_topic" : "chat_topic_log")
    }

    private static func title(for area: ChatTopicArea) -> String {
        switch area {
        case .spending: return L10n.UXL14D.areaSpending
        case .budgets: return L10n.UXL14D.areaBudgets
        case .payments: return L10n.UXL14D.areaPayments
        case .log: return L10n.UXL14D.areaLog
        }
    }

    private static func icon(for area: ChatTopicArea) -> String {
        switch area {
        case .spending: return "chart.pie"
        case .budgets: return "chart.bar"
        case .payments: return "calendar"
        case .log: return "square.and.pencil"
        }
    }
}
