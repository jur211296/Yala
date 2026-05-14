//
//  SetupDemoFirstExpenseView.swift
//  Yala
//
//  Demo standalone educativa del Step 2 (firstExpense) del Setup Checklist.
//  Replica fielmente el chrome del NewTransactionView reusando `YalaToolbarButton`,
//  `TransactionTypeSelectorView`, `SelectionChip` y los selectores
//  Account/Subcategory/Tags (vía `SetupDemoMockSelectorSheet`). Chrome del demo (progress bar, CTA, toast border) usa
//  `Color.electricIndigo` como color principal de marca.
//

import SwiftUI

// MARK: - Main View

struct SetupDemoFirstExpenseView: View {

    // MARK: - Callbacks

    let onClose: () -> Void
    let onComplete: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    // MARK: - Demo state

    @State private var demoTask: Task<Void, Never>?
    @State private var selectedDemoType: TransactionType = .expense
    @State private var descriptionText: String = ""
    @State private var amountValue: Int = 0
    @State private var filled: Set<SetupDemoMockSheet> = []
    @State private var saveButtonEnabled: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var activeMockSheet: SetupDemoMockSheet?

    // MARK: - Completion state

    @State private var demoCompleted: Bool = false
    @State private var progress: Double = 0
    @State private var ctaPulse: Bool = false

    // MARK: - Cached L10n

    @State private var descriptionExample: String = ""
    @State private var accountExample: String = ""
    @State private var subcategoryExample: String = ""
    @State private var tagExample: String = ""
    @State private var savedToastText: String = ""

    private var demoAccent: Color { Color.electricIndigo }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                mainContent
            }
            .navigationTitle(L10n.Transaction.newTransaction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        onClose()
                    }
                }
            }
        }
        .sheet(item: $activeMockSheet) { sheet in
            SetupDemoMockSelectorSheet(
                type: sheet,
                targetValue: exampleValue(for: sheet),
                categoryContext: .food,
                reduceMotion: reduceMotion,
                onSelected: { filled.insert(sheet) }
            )
            .interactiveDismissDisabled(true)
        }
        .task {
            cacheL10n()
            startDemoScript()
        }
        .onDisappear {
            demoTask?.cancel()
            demoTask = nil
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var mainContent: some View {
        mockTransactionScroll
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Spacing.sm) {
                    progressBar
                    ctaFooter
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
                .background(
                    Rectangle()
                        .fill(.thBackground)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
    }

    // MARK: - Mock NTV scroll

    private var mockTransactionScroll: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                TransactionTypeSelectorView(
                    selectedType: $selectedDemoType,
                    availableTypes: TransactionType.allCases,
                    onTypeChange: nil
                )
                .allowsHitTesting(false)

                dateChipMock
                descriptionMock
                amountMock
                quickActionsBarMock
                bottomChipsMock

                saveButtonMock
                    .padding(.horizontal, DS.Spacing.xl)

                if showSuccessToast {
                    VStack(spacing: DS.Spacing.md) {
                        successToast
                        restartButton
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            )
                    )
                }
            }
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDisabled(true)
    }

    private var restartButton: some View {
        Button {
            restartDemo()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.counterclockwise")
                    .font(DS.Typography.label.weight(.semibold))
                Text(L10n.SetupChecklist.Demo.restart)
                    .font(DS.Typography.label.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule().fill(Color.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.SetupChecklist.Demo.restart)
    }

    private var dateChipMock: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar")
                .font(DS.Typography.label)
            Text(L10n.Date.today)
                .font(DS.Typography.label)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            Capsule().fill(Color.primary.opacity(0.08))
        )
    }

    private var descriptionMock: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(descriptionText.isEmpty ? L10n.Transaction.description : descriptionText)
                .font(DS.Typography.title)
                .foregroundStyle(descriptionText.isEmpty ? Color.secondary : Color.primary)
                .frame(maxWidth: 280)
                .multilineTextAlignment(.center)
                .animation(reduceMotion ? nil : .smooth(duration: 0.15), value: descriptionText)
            Text(L10n.Transaction.descriptionHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var amountMock: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Text("S/")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(selectedDemoType.color.opacity(0.7))
            Text("\(amountValue)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(selectedDemoType.color)
                .contentTransition(.numericText(value: Double(amountValue)))
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: amountValue)
        }
    }

    private var quickActionsBarMock: some View {
        HStack(spacing: DS.Spacing.xl) {
            quickActionMock(icon: "percent", label: L10n.Action.calculate)
            quickActionMock(icon: "star", label: L10n.Action.favorite)
            quickActionMock(icon: "repeat", label: L10n.Action.recurring)
        }
    }

    private func quickActionMock(icon: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(.thCard)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )
            Text(label)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var bottomChipsMock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(SetupDemoMockSheet.allCases) { sheet in
                    let isFilled = filled.contains(sheet)
                    SelectionChip(
                        icon: sheet.chipIcon,
                        text: isFilled ? exampleValue(for: sheet) : sheet.chipPlaceholder,
                        isSelected: isFilled,
                        color: isFilled ? sheet.accentColor : nil
                    ) {}
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }

    private var saveButtonMock: some View {
        Button {
            // no-op en demo
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.headline)
                Text(L10n.Action.save)
                    .font(DS.Typography.headline)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(saveButtonEnabled ? theme.accent : DS.Semantic.disabledForeground.opacity(0.4))
        .controlSize(.large)
        .disabled(true)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: saveButtonEnabled)
    }

    private var successToast: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(demoAccent)
            Text(savedToastText)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            Capsule().fill(.thCard)
        )
        .overlay(
            Capsule().stroke(demoAccent.opacity(0.5), lineWidth: 1.5)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 4)
                Capsule()
                    .fill(demoAccent)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var ctaFooter: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                guard demoCompleted else { return }
                onComplete()
            } label: {
                Text(L10n.SetupChecklist.Demo.gotIt)
                    .font(DS.Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(demoCompleted ? demoAccent : DS.Semantic.disabledForeground.opacity(0.4))
            .controlSize(.large)
            .disabled(!demoCompleted)
            .scaleEffect(ctaPulse ? 1.03 : 1.0)
            .accessibilityHint(demoCompleted ? "" : L10n.SetupChecklist.Demo.waitForCompletion)

            if !demoCompleted {
                Text(L10n.SetupChecklist.Demo.waitForCompletion)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: demoCompleted)
    }

    // MARK: - Helpers

    private func exampleValue(for sheet: SetupDemoMockSheet) -> String {
        switch sheet {
        case .account: return accountExample
        case .subcategory: return subcategoryExample
        case .tags: return tagExample
        }
    }

    // MARK: - Script

    @MainActor
    private func cacheL10n() {
        descriptionExample = L10n.SetupChecklist.Demo.firstExpenseDescriptionExample
        accountExample = L10n.SetupChecklist.Demo.firstExpenseAccountExample
        subcategoryExample = L10n.SetupChecklist.Demo.firstExpenseSubcategoryExample
        tagExample = L10n.SetupChecklist.Demo.firstExpenseTagExample
        savedToastText = L10n.SetupChecklist.Demo.firstExpenseSavedToast
    }

    @MainActor
    private func startDemoScript() {
        demoTask?.cancel()

        if voiceOverEnabled {
            applyFinalState()
            demoCompleted = true
            progress = 1.0
            return
        }

        demoTask = Task { @MainActor in
            await runOneIteration()
            guard !Task.isCancelled else { return }
            demoCompleted = true
            pulseCTA()
        }
    }

    @MainActor
    private func restartDemo() {
        demoTask?.cancel()
        resetState(keepCompleted: true)
        startDemoScript()
    }

    @MainActor
    private func runOneIteration() async {
        await advance(to: 0.05)
        try? await Task.sleep(for: .milliseconds(500))

        // Typing descripción (~180ms por letra)
        for index in 1...descriptionExample.count {
            guard !Task.isCancelled else { return }
            descriptionText = String(descriptionExample.prefix(index))
            try? await Task.sleep(for: .milliseconds(180))
            await advance(to: 0.05 + (0.18 * Double(index) / Double(descriptionExample.count)))
        }

        try? await Task.sleep(for: .milliseconds(300))

        // Monto 0 → 5 → 50 → 500
        let amounts = [5, 50, 500]
        for (idx, value) in amounts.enumerated() {
            guard !Task.isCancelled else { return }
            amountValue = value
            try? await Task.sleep(for: .milliseconds(400))
            await advance(to: 0.23 + 0.12 * Double(idx + 1) / Double(amounts.count))
        }

        try? await Task.sleep(for: .milliseconds(400))

        // Sheets en orden — sub-view auto-dismiss y callback actualiza `filled`
        await runSheetStage(.account, targetProgress: 0.5)
        await runSheetStage(.subcategory, targetProgress: 0.65)
        await runSheetStage(.tags, targetProgress: 0.8)

        guard !Task.isCancelled else { return }
        saveButtonEnabled = true
        await advance(to: 0.93)
        try? await Task.sleep(for: .milliseconds(700))

        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            showSuccessToast = true
        }
        await advance(to: 1.0)
        try? await Task.sleep(for: .milliseconds(900))
    }

    @MainActor
    private func runSheetStage(_ type: SetupDemoMockSheet, targetProgress: Double) async {
        guard !Task.isCancelled else { return }
        activeMockSheet = type
        // Sub-view ejecuta su script interno (~1700ms) y dismisses solo.
        try? await Task.sleep(for: .milliseconds(2000))
        guard !Task.isCancelled else { return }
        // Defensa: si por race el sub-view no se cerró, fuerza el dismiss.
        if activeMockSheet == type {
            activeMockSheet = nil
            try? await Task.sleep(for: .milliseconds(300))
        }
        await advance(to: targetProgress)
        try? await Task.sleep(for: .milliseconds(200))
    }

    @MainActor
    private func advance(to target: Double) async {
        withAnimation(reduceMotion ? nil : .linear(duration: 0.2)) {
            progress = min(target, 1.0)
        }
    }

    @MainActor
    private func applyFinalState() {
        descriptionText = descriptionExample
        amountValue = 500
        filled = Set(SetupDemoMockSheet.allCases)
        saveButtonEnabled = true
        showSuccessToast = true
    }

    @MainActor
    private func resetState(keepCompleted: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            descriptionText = ""
            amountValue = 0
            filled.removeAll()
            saveButtonEnabled = false
            showSuccessToast = false
        }
        activeMockSheet = nil
        if !keepCompleted {
            demoCompleted = false
            progress = 0
        }
    }

    @MainActor
    private func pulseCTA() {
        guard !reduceMotion else { return }
        withAnimation(.smooth(duration: 0.25).repeatCount(2, autoreverses: true)) {
            ctaPulse.toggle()
        }
    }
}
