//
//  ChatInicioGreeting.swift
//  Yala
//
//  El chat vacío cuando Yala IA está disponible (encargo del 17-nov, «limpiar el chat lo más posible en cada paso»): el
//  saludo y debajo solo los tres botones de color, sin subtextos ni listas. Lo que antes iba dentro de cada ficha (el
//  ejemplo de apuntar, las tres preguntas, los atajos de crear) sale ahora como respuesta de Yala al tocar el botón
//  (`ChatInicioOptionsView`).
//
//  Los colores son los de la variante 3 de L14-4 (Jürgen, 2026-10-15): rellenos sólidos que llevan el blanco con
//  contraste AA (`emphasisPinkFill` 5,2:1; `electricIndigo` 4,6:1; `incomeFill` 5,1:1). Sin degradados ni brillos.
//

import SwiftUI

struct ChatInicioGreeting: View {

    /// Los botones que salen, en orden. La prueba de cortesía de Primeros pasos no lleva «Crea conversando».
    let branches: [ChatInicioBranch]
    let onSelect: (ChatInicioBranch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                // Con «Crea conversando» son tres cosas; sin ella (prueba de cortesía), el saludo de las dos de siempre.
                Text(branches.contains(.create) ? L10n.IAGuiados.greeting : L10n.UXL14.greetingTwoUses)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(.thCard)
                    .clipShape(ChatBubbleShape())
                Spacer(minLength: DS.Spacing.xxxl)
            }

            ForEach(branches, id: \.self) { branch in
                startButton(branch)
            }
        }
    }

    private func startButton(_ branch: ChatInicioBranch) -> some View {
        Button {
            onSelect(branch)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                SolidIconTile(systemName: Self.icon(branch), fill: .white.opacity(0.22))
                Text(Self.title(branch))
                    .font(DS.Typography.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            // A11Y-DM: blanco fijo sobre los tres rellenos sólidos (AA en claro y en oscuro).
            .foregroundStyle(Color.white)
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.fill(branch), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CourtesyAnchor(isLogExpense: branch == .logExpense))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(Self.identifier(branch))
    }

    static func title(_ branch: ChatInicioBranch) -> String {
        switch branch {
        case .logExpense: L10n.UXL14.logTitle
        case .askFinances: L10n.UXL14.askTitle
        case .create: L10n.IAGuiados.greetingCreateTitle
        }
    }

    static func icon(_ branch: ChatInicioBranch) -> String {
        switch branch {
        case .logExpense: "square.and.pencil"
        case .askFinances: "questionmark"
        case .create: "sparkles"
        }
    }

    static func fill(_ branch: ChatInicioBranch) -> Color {
        switch branch {
        case .logExpense: .emphasisPinkFill
        case .askFinances: .electricIndigo
        case .create: .incomeFill
        }
    }

    /// `chat_log_expense` es el de la ficha de antes: lo leen la guía de foco de la prueba y los XCUITest.
    static func identifier(_ branch: ChatInicioBranch) -> String {
        switch branch {
        case .logExpense: "chat_log_expense"
        case .askFinances: "chat_start_ask"
        case .create: "chat_start_create"
        }
    }
}

/// La guía de foco de la prueba de Yala IA de Primeros pasos (Y23-09) señala «Apunta un gasto».
private struct CourtesyAnchor: ViewModifier {
    let isLogExpense: Bool

    func body(content: Content) -> some View {
        if isLogExpense {
            content.coachMarkAnchor(ChatCourtesyTrial.logExpenseAnchor)
        } else {
            content
        }
    }
}
