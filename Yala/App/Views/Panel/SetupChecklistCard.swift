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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
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

            // Progress bar
            progressBar

            // Steps list
            let allSteps = manager.steps
            let currentID = allSteps.first { !$0.isCompleted && !$0.isLocked }?.id
            VStack(spacing: DS.Spacing.xxs) {
                ForEach(allSteps) { step in
                    SetupStepRow(
                        step: step,
                        isCurrent: currentID == step.id,
                        onTap: { onStepTapped(step.id) }
                    )
                }
            }

            // Collapse button
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
            .padding(DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(.thCardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(L10n.SetupChecklist.completeTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            Text(L10n.SetupChecklist.completeSubtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.successBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(.thSecondaryText.opacity(DS.Opacity.subtle))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(theme.accent)
                    .frame(width: geo.size.width * manager.progress, height: 6)
                    .animation(.easeInOut(duration: 0.4), value: manager.progress)
            }
        }
        .frame(height: 6)
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
