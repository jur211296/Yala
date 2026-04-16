//
//  SetupChecklistCard.swift
//  Yala
//
//  "Configura tu Yala" — persistent card on Panel guiding new users through 8 setup steps.
//  Three states: expanded (full list), collapsed (progress bar only), completed (celebration).
//

import SwiftUI

struct SetupChecklistCard: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let manager: SetupChecklistManager
    let onStepTapped: (SetupStepID) -> Void

    // MARK: - State

    @State private var showCelebration = false

    // MARK: - Body

    var body: some View {
        if manager.shouldShow {
            ZStack {
                if manager.isAllComplete {
                    completedView
                } else if manager.isCollapsed {
                    collapsedView
                } else {
                    expandedView
                }

                if showCelebration {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: manager.isCollapsed)
            .animation(.easeInOut(duration: 0.3), value: manager.isAllComplete)
            .onChange(of: manager.isAllComplete) { _, isComplete in
                if isComplete {
                    showCelebration = true
                    DS.Haptic.success()
                }
            }
        }
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        let currentStep = manager.currentStep
        let allSteps = manager.steps

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                if let step = currentStep {
                    onStepTapped(step.id)
                }
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Image(systemName: "target")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thAccent)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.SetupChecklist.title)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.thPrimaryText)

                            Text(L10n.SetupChecklist.progress(manager.completedCount, manager.totalCount))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.thSecondaryText)
                        }

                        Spacer()
                    }

                    progressBar

                    VStack(spacing: DS.Spacing.xxs) {
                        ForEach(allSteps) { step in
                            SetupStepRow(
                                step: step,
                                isCurrent: currentStep?.id == step.id
                            )
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                currentStep.map { L10n.SetupChecklist.nextStep($0.id.localizedTitle) } ?? ""
            )
            .accessibilityHint(L10n.SetupChecklist.stepTapToStart)

            HStack {
                Spacer()
                Button {
                    manager.toggleCollapsed()
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Text(L10n.SetupChecklist.collapse)
                            .font(DS.Typography.caption)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.thSecondaryText)
                }
            }
        }
        .yalaCard(padding: DS.Spacing.md, radius: DS.Radius.md, shadow: false)
    }

    // MARK: - Collapsed View

    private var collapsedView: some View {
        Button {
            manager.toggleCollapsed()
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "target")
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccent)

                    Text(L10n.SetupChecklist.progress(manager.completedCount, manager.totalCount))
                        .font(DS.Typography.label)
                        .foregroundStyle(.thPrimaryText)

                    Spacer()

                    HStack(spacing: DS.Spacing.xxs) {
                        Text(L10n.SetupChecklist.continueSetup)
                            .font(DS.Typography.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.thAccent)
                }

                progressBar
            }
            .glassCard(.regular, radius: DS.Radius.md, padding: DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed View

    private var completedView: some View {
        HStack {
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.SetupChecklist.completeTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(L10n.SetupChecklist.completeSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }
            .frame(maxWidth: .infinity)

            Button {
                manager.dismissCompleted()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.thSecondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("action.close", comment: "Close"))
        }
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Progress Bar

    @State private var progressBarWidth: CGFloat = 0

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(.thSecondaryText.opacity(DS.Opacity.subtle))
                .frame(height: 6)

            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(theme.accent)
                .frame(width: progressBarWidth * manager.progress, height: 6)
                .animation(.easeInOut(duration: 0.4), value: manager.progress)
        }
        .frame(height: 6)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { progressBarWidth = $0 }
    }
}

// MARK: - Preview

#Preview("Expanded") {
    SetupChecklistCard(
        manager: .shared,
        onStepTapped: { _ in }
    )
    .padding()
}
