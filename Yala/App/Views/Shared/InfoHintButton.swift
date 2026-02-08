//
//  InfoHintButton.swift
//  Yala
//
//  Optional info button for widgets that displays a hint popover.
//

import SwiftUI

/// A small info button that shows a popover with contextual help.
/// Visibility is controlled by the showWidgetHints AppStorage setting.
struct InfoHintButton: View {
    let title: String
    let message: String

    @AppStorage("showWidgetHints") private var showWidgetHints: Bool = true
    @State private var showPopover = false

    var body: some View {
        if showWidgetHints {
            Button {
                showPopover = true
            } label: {
                Image(systemName: "info.circle")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

#Preview {
    HStack {
        Text("Widget Title")
            .font(.headline)

        InfoHintButton(
            title: "Tendencias",
            message: "Muestra la evolucion de tu balance, ingresos o gastos en el periodo seleccionado"
        )

        Spacer()
    }
    .padding()
}
