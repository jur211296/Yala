//
//  SetupStepsListSheet.swift
//  Yala
//
//  «Ver los 7 pasos» del mazo (Y23-05): la lista de Primeros pasos con los hechos marcados y el actual resaltado, y
//  «Seguir donde iba» para volver. Con el cristal del sistema a media altura y `.subtle` grande (regla «Ninguna hoja con
//  fondo gris»).
//
//  **Decisión de Jürgen (13-nov, E14 del recorrido):** la hoja abre GRANDE, con los siete a la vista en un iPhone 14 (a
//  media altura se veían seis y «Seguir donde iba» tapaba la descripción del sexto), y cualquier paso que no esté hecho
//  se abre tocándolo, aunque no sea el siguiente.
//

import SwiftUI

struct SetupStepsListSheet: View {
    let manager: SetupChecklistManager
    /// Un paso tocado en la lista. Quien presenta la hoja lo abre al terminar de cerrarla (`onDismiss`): pedirlo con la
    /// hoja aún arriba sería presentar sobre una presentación.
    var onOpenStep: (SetupStepID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = SetupStepsListLogic.initialDetent
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
                        row(step, position: index + 1, isCurrent: step.id == current)
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

    /// Un paso que se puede abrir es un botón con su chevron; uno hecho queda como texto, marcado.
    @ViewBuilder
    private func row(_ step: SetupStep, position: Int, isCurrent: Bool) -> some View {
        if SetupStepsListLogic.opens(step) {
            Button {
                DS.Haptic.selection()
                onOpenStep(step.id)
                dismiss()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    SetupStepRow(step: step, position: position, isCurrent: isCurrent)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setup_steps_row_\(String(describing: step.id))")
        } else {
            SetupStepRow(step: step, position: position, isCurrent: isCurrent)
                .accessibilityIdentifier("setup_steps_row_\(String(describing: step.id))")
        }
    }
}

/// Las reglas de «Ver los 7 pasos» (decisión de Jürgen del 13-nov), sin efectos.
enum SetupStepsListLogic {
    /// La hoja abre grande: a media altura, en un iPhone 14, el séptimo quedaba fuera.
    static let initialDetent: PresentationDetent = .large

    /// Se abre cualquier paso que no esté hecho, también uno omitido o uno que no es el siguiente.
    static func opens(_ step: SetupStep) -> Bool { !step.isCompleted }
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
