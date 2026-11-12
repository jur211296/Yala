//
//  SetupStepsListSheet.swift
//  Yala
//
//  «Ver los 7 pasos» del mazo (Y23-05): la lista de Primeros pasos con los hechos marcados y el actual resaltado, y
//  «Seguir donde iba» para volver. Media altura, con el cristal del sistema y `.subtle` al estirarla (regla «Ninguna
//  hoja con fondo gris»).
//

import SwiftUI

struct SetupStepsListSheet: View {
    let manager: SetupChecklistManager

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = .medium
    /// En ventana ancha la hoja sale grande aunque la selección siga en `.medium` (`yalaSheetDetents`).
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    private var isLargeDetent: Bool { selectedDetent == .large || usesLargeSheets }

    var body: some View {
        let steps = manager.steps
        let current = manager.deck?.current
        VStack(spacing: 0) {
            HStack {
                Text(L10n.SetupChecklist.title)
                    .font(DS.Typography.title3)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.labelSmall.bold())
                        .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Action.close)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        SetupStepRow(step: step, position: index + 1, isCurrent: step.id == current)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button {
                dismiss()
            } label: {
                Text(L10n.SetupChecklist.Deck.resume)
                    .font(DS.Typography.bodyBold)
                    .frame(maxWidth: .infinity, minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.thAccentText)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
            .accessibilityIdentifier("setup_steps_resume")
        }
        .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
    }
}

/// La llegada con «Solo gastos» (Y23-05): la única acción es «Anotar el primer gasto», y debajo a qué cuenta van, que
/// Yala crea sola como hoy.
struct SetupFirstExpenseAction: View {
    let accountName: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.SetupChecklist.Deck.firstExpense, action: action)
                .accessibilityIdentifier("setup_first_expense")
            if let accountName {
                Text(L10n.SetupChecklist.Deck.firstExpenseNote(accountName))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
