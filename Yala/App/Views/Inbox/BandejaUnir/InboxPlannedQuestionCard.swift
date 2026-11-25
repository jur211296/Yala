//
//  InboxPlannedQuestionCard.swift
//  Yala
//
//  Bandeja sin duplicados, lote 4: «¿Es tu pago «Luz del Sur»?». Un pendiente que puede ser un pago planificado y no se
//  unió solo al llegar (la primera vez que su comercio casa, o un fijo con otro importe), con el borrador del planificado
//  si ya lo tiene, y «Sí, es ese pago» / «No es ese pago». Mismo aspecto que «¿Es el mismo gasto?» (lote 3). Cada fila
//  sigue abriendo su borrador.
//

import SwiftData
import SwiftUI

struct InboxPlannedQuestionCard: View {
    let question: InboxPlannedQuestion
    let currencyCode: (InboxDraft) -> String
    let onOpen: (InboxDraft) -> Void
    let onConfirm: () -> Void
    let onDeny: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        if question.drafts.allSatisfy(\.isReadableInInbox) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(L10n.BandejaUnir.planificadoTitulo(question.paymentName), systemImage: "calendar.badge.checkmark")
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("inbox_planned_question_title")

                ForEach(question.drafts, id: \.persistentModelID) { draft in
                    InboxDraftRowView(draft: draft, currencyCode: currencyCode(draft)) { onOpen(draft) }
                }

                if question.plannedDraft == nil {
                    Text(question.plannedDetail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("inbox_planned_question_detail")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) { confirmButton; denyButton }
                    VStack(spacing: DS.Spacing.sm) { confirmButton; denyButton }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(theme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("inbox_planned_question")
        }
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text(L10n.BandejaUnir.planificadoSi)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(theme.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.BandejaUnir.planificadoSiPista)
        .accessibilityIdentifier("inbox_planned_question_yes")
    }

    private var denyButton: some View {
        Button(action: onDeny) {
            Text(L10n.BandejaUnir.planificadoNo)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(theme.accent.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.BandejaUnir.planificadoNoPista)
        .accessibilityIdentifier("inbox_planned_question_no")
    }
}
