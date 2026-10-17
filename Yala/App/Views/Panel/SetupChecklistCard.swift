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

    /// UX 2.2 · L5-4 (variante 2, decisión de Jürgen): un solo paso grande —su icono en una ficha de color y un botón
    /// «Empezar»— y la lista entera a un toque con «Ver los N pasos». Antes era una lista gris de siete filas con seis
    /// candados, sin ningún botón.
    @State private var showsAllSteps = false

    private var expandedView: some View {
        let currentStep = manager.currentStep

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header

            progressBar

            if let currentStep {
                currentStepFocus(currentStep)
            }

            if showsAllSteps {
                VStack(spacing: DS.Spacing.xxs) {
                    ForEach(manager.steps) { step in
                        SetupStepRow(
                            step: step,
                            isCurrent: currentStep?.id == step.id,
                            onTap: { onStepTapped(step.id) }
                        )
                    }
                }
                .transition(.opacity)
            }

            footer
        }
        .yalaCard(padding: DS.Spacing.md, radius: DS.Radius.md, shadow: false)
        .animation(.easeInOut(duration: 0.25), value: showsAllSteps)
    }

    private var header: some View {
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
    }

    /// El paso que toca: ficha de color con su icono, «Siguiente paso» y el botón «Empezar».
    private func currentStepFocus(_ step: SetupStep) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: step.icon)
                    .font(.system(size: 20, weight: .semibold)) // A11Y-DT: icono de la ficha, tamaño fijo del molde Kargul
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(theme.accent))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.SetupChecklist.nextStepLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                    Text(step.id.localizedTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            YalaPrimaryButton(L10n.SetupChecklist.start) {
                onStepTapped(step.id)
            }
            .accessibilityHint(L10n.SetupChecklist.nextStep(step.id.localizedTitle))
            .accessibilityIdentifier("setup_checklist_start")
        }
    }

    private var footer: some View {
        HStack {
            Button {
                showsAllSteps.toggle()
            } label: {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(showsAllSteps
                         ? L10n.SetupChecklist.hideAllSteps
                         : L10n.SetupChecklist.showAllSteps(manager.totalCount))
                        .font(DS.Typography.caption)
                    Image(systemName: showsAllSteps ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)) // A11Y-DT: chevron decorativo junto al texto
                }
                .foregroundStyle(.thAccent)
                .frame(minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setup_checklist_toggle_steps")

            Spacer()

            Button {
                manager.toggleCollapsed()
            } label: {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(L10n.SetupChecklist.collapse)
                        .font(DS.Typography.caption)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10)) // A11Y-DT: chevron decorativo junto al texto
                }
                .foregroundStyle(.thSecondaryText)
                .frame(minHeight: DS.Button.actionSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
            .solidCard(padding: DS.Spacing.md, radius: DS.Radius.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed View

    private var completedView: some View {
        HStack {
            VStack(spacing: DS.Spacing.sm) {
                // Con algún paso saltado no dice «¡Ya eres experto!» (UX 2.2 · L5-2).
                Text(manager.hasSkippedSteps ? L10n.SetupChecklist.basicsTitle : L10n.SetupChecklist.completeTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(manager.hasSkippedSteps ? L10n.SetupChecklist.basicsSubtitle : L10n.SetupChecklist.completeSubtitle)
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
                    .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
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
