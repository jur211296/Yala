//
//  FaceIDProtectionGuideView.swift
//  Yala
//
//  Guía informativa: cómo proteger la app con el bloqueo NATIVO de iOS
//  (mantener presionado el ícono → "Requerir Face ID"). Reemplaza al antiguo
//  bloqueo biométrico in-app. Sin LocalAuthentication — solo educación.
//

import SwiftUI

struct FaceIDProtectionGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(id: 1, title: L10n.FaceIDGuide.step1Title, detail: L10n.FaceIDGuide.step1Detail),
        Step(id: 2, title: L10n.FaceIDGuide.step2Title, detail: L10n.FaceIDGuide.step2Detail),
        Step(id: 3, title: L10n.FaceIDGuide.step3Title, detail: L10n.FaceIDGuide.step3Detail)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "faceid")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(.thAccent)
                        .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.FaceIDGuide.title)
                        .font(.title2.bold())
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.FaceIDGuide.subtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xxxl)

                // Steps
                VStack(spacing: DS.Spacing.none) {
                    ForEach(steps) { step in
                        stepRow(step)

                        if step.id < steps.count {
                            Divider()
                                .padding(.leading, DS.Spacing.xxxl)
                        }
                    }
                }
                .solidCard(radius: DS.Radius.lg)

                Spacer()
            }
            .padding(DS.Spacing.lg)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.faceIDProtection)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: Step) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "\(step.id).circle.fill")
                .font(.title2)
                .foregroundStyle(.thAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(step.title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Text(step.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
