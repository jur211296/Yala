//
//  GroupsEmptyStepsCard.swift
//  Yala
//
//  Auditoría UX 2.2 · L12-2. La tarjeta de cristal de los estados vacíos de Grupos: con los tres pasos cuando el estado
//  está en el camino hacia el primer grupo, y sin ellos cuando no (volver a entrar, todo archivado, canal apagado). La
//  acción va siempre en un botón relleno del color de acento (morado en el tema de siempre: decisión de Jürgen del 15-oct;
//  sigue al tema elegido, como todo `YalaPrimaryButton`), y el paso que toca, en rosa.
//

import SwiftUI

struct GroupsEmptyStepsCard: View {

    @ScaledMetric(relativeTo: .body) private var stepSize: CGFloat = 30 // A11Y-DT: @ScaledMetric

    let card: GroupsEmptyStepsLogic.Card
    /// Título y mensaje de la tarjeta sin pasos (la de pasos lleva el suyo).
    let title: String
    let message: String?
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let current = card.currentStep {
                Text(L10n.UXL12.stepsTitle)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(GroupsEmptyStepsLogic.Step.allCases, id: \.rawValue) { step in
                        stepRow(step, state: GroupsEmptyStepsLogic.state(of: step, current: current))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.title3)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            YalaPrimaryButton(actionTitle, icon: card.action == .tellMe ? "hand.tap.fill" : nil, action: action)
                .padding(.top, DS.Spacing.xs)

            if card.showsFootnote {
                Text(L10n.UXL12.stepsFootnote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: DS.Adaptive.readableWidth, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .padding(.horizontal, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func stepRow(_ step: GroupsEmptyStepsLogic.Step, state: GroupsEmptyStepsLogic.StepState) -> some View {
        let text = stepText(step)
        return HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(circleFill(state))
                    .frame(width: stepSize, height: stepSize)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue)")
                        .font(DS.Typography.label)
                        .foregroundStyle(state == .current ? Color.white : Color.secondary)
                }
            }
            Text(text)
                .font(state == .current ? DS.Typography.label : DS.Typography.subheadline)
                .foregroundStyle(state == .upcoming ? .secondary : .primary)
                .strikethrough(state == .done, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepA11y(text, state: state))
    }

    private func circleFill(_ state: GroupsEmptyStepsLogic.StepState) -> Color {
        switch state {
        case .done: Color.electricIndigo
        case .current: Color.hotPink
        case .upcoming: Color.secondary.opacity(0.2)
        }
    }

    private func stepText(_ step: GroupsEmptyStepsLogic.Step) -> String {
        switch step {
        case .account: L10n.UXL12.stepAccount
        case .consent: L10n.UXL12.stepConsent
        case .create: L10n.UXL12.stepCreate
        }
    }

    private func stepA11y(_ text: String, state: GroupsEmptyStepsLogic.StepState) -> String {
        switch state {
        case .done: L10n.UXL12.stepDoneA11y(text)
        case .current: L10n.UXL12.stepCurrentA11y(text)
        case .upcoming: L10n.UXL12.stepNextA11y(text)
        }
    }
}
