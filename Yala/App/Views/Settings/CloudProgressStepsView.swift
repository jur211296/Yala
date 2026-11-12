//
//  CloudProgressStepsView.swift
//  Yala
//
//  Los pasos con su cifra de «Activar la nube» y «Volver a iCloud» (opción B del lienzo, decisión de Jürgen del
//  2026-10-22; ticket `cloud-progress-shows-real-steps-and-counts`). Pinta lo que decide `CloudProgressStepsLogic`: un
//  check en lo hecho, un indicador que gira en lo que está en marcha —con su barra y su cifra si las tiene— y un círculo
//  vacío en lo que falta. Sin barra quieta: lo que se mueve es la cifra real o el indicador del paso.
//

import SwiftUI

struct CloudProgressStepsView: View {
    let title: String
    let steps: [CloudProgressStepsLogic.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("storage_steps_title")
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    CloudProgressStepRow(step: step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_steps")
    }
}

private struct CloudProgressStepRow: View {
    let step: CloudProgressStepsLogic.Step

    @ScaledMetric(relativeTo: .body) private var markerSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            marker
                .frame(width: markerSize, height: markerSize)
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 5 }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(title)
                    .font(step.state == .active ? DS.Typography.bodyBold : DS.Typography.body)
                    .foregroundStyle(step.state == .pending ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                if step.state == .active, let detail {
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("storage_step_detail_\(identifier)")
                }
                countView
            }
        }
        .accessibilityElement(children: .contain)
        // El estado va en el identificador y no en `accessibilityValue`: VoiceOver leería «active» en inglés.
        .accessibilityIdentifier("storage_step_\(identifier)_\(stateDescription)")
    }

    @ViewBuilder private var marker: some View {
        switch step.state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(DS.Semantic.successForeground)
                .accessibilityHidden(true)
        case .active:
            ProgressView()
                .controlSize(.small)
                .tint(DS.Semantic.infoForeground)
                .accessibilityHidden(true)
        case .pending:
            Image(systemName: "circle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var countView: some View {
        switch step.count {
        case let .uploaded(done, total, fraction):
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ProgressView(value: fraction)
                    .tint(DS.Semantic.infoForeground)
                    .accessibilityHidden(true)
                Text(L10n.Storage.Steps.uploadedCount(done, of: total))
                    .font(DS.Typography.captionMono)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storage_step_count")
            }
        case let .pendingToICloud(count):
            Text(L10n.Storage.Steps.pendingCount(count))
                .font(DS.Typography.captionMono)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("storage_step_count")
        case let .wiped(count):
            Text(L10n.Storage.Steps.wipedCount(count))
                .font(DS.Typography.captionMono)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("storage_step_count")
        case nil:
            EmptyView()
        }
    }

    private var title: String {
        switch step.kind {
        case .connect:        return L10n.Storage.Steps.connect
        case .prepare:        return L10n.Storage.Steps.prepare
        case .upload:         return L10n.Storage.Steps.upload
        case .confirm:        return L10n.Storage.Steps.confirm
        case .waitICloud:     return L10n.Storage.Steps.waitICloud
        case .wipePrior:      return L10n.Storage.Steps.wipePrior
        case .bring:          return L10n.Storage.Steps.bring
        case .review:         return L10n.Storage.Steps.review
        case .uploadToICloud: return L10n.Storage.Steps.uploadToICloud
        }
    }

    /// La explicación del paso en marcha, solo donde lo que se espera es a iCloud.
    private var detail: String? {
        switch step.kind {
        case .waitICloud: return L10n.Storage.Steps.waitICloudDetail
        case .review:     return L10n.Storage.Steps.reviewDetail
        default:          return nil
        }
    }

    /// Los identificadores de XCUITest, uno por paso.
    private var identifier: String {
        switch step.kind {
        case .connect:        return "connect"
        case .prepare:        return "prepare"
        case .upload:         return "upload"
        case .confirm:        return "confirm"
        case .waitICloud:     return "waitICloud"
        case .wipePrior:      return "wipePrior"
        case .bring:          return "bring"
        case .review:         return "review"
        case .uploadToICloud: return "uploadToICloud"
        }
    }

    /// El estado, para los XCUITest.
    private var stateDescription: String {
        switch step.state {
        case .done:    return "done"
        case .active:  return "active"
        case .pending: return "pending"
        }
    }
}
