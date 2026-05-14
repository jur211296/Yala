//
//  SetupDemoFirstBudgetView.swift
//  Yala
//
//  Demo standalone educativa del Step 3 (firstBudget) del Setup Checklist.
//  Replica chrome del BudgetEditorView reusando SectionBox + Picker(.segmented) +
//  FlowLayout threshold chips. SwiftUI puro sin SwiftData. Indigo para chrome
//  demo, theme.accent para contenido replicado.
//

import SwiftUI

struct SetupDemoFirstBudgetView: View {

    // MARK: - Callbacks

    let onClose: () -> Void
    let onComplete: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    // MARK: - Demo state

    @State private var demoTask: Task<Void, Never>?
    @State private var name: String = ""
    @State private var amountValue: Int = 0
    @State private var selectedPeriodType: BudgetPeriodType = .monthly
    @State private var alertEnabled: Bool = false
    @State private var selectedThresholds: Set<Int> = []
    @State private var selectedFilterAccount: String? = nil
    @State private var selectedFilterSubcategory: String? = nil
    @State private var saveButtonEnabled: Bool = false
    @State private var showSuccessToast: Bool = false

    // Completion state
    @State private var demoCompleted: Bool = false
    @State private var progress: Double = 0
    @State private var ctaPulse: Bool = false

    // Cached L10n
    @State private var nameExample: String = ""
    @State private var amountExample: String = ""
    @State private var alertCaption: String = ""
    @State private var savedToastText: String = ""

    private var demoAccent: Color { Color.electricIndigo }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                mainContent
            }
            .navigationTitle(NSLocalizedString("budgets.new", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        onClose()
                    }
                }
            }
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
        mockBudgetScroll
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

    // MARK: - Mock BudgetEditorView

    private var mockBudgetScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    basicInfoMock
                    periodMock
                    alertsMock
                    budgetFilterBannerMock
                    filtersMock
                    saveButtonMock
                        .padding(.horizontal, DS.Spacing.xl)

                    if showSuccessToast {
                        VStack(spacing: DS.Spacing.md) {
                            successToast
                            restartButton
                        }
                        .id("toast")
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
                .padding(.horizontal, DS.Spacing.lg)
            }
            .onChange(of: showSuccessToast) { _, newValue in
                if newValue {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
                        proxy.scrollTo("toast", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - basicInfo mock (replica de BudgetEditorView.basicInfoSection)

    private var basicInfoMock: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.basic.info", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Name field mock
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    Text(name.isEmpty ? NSLocalizedString("budgets.editor.name.placeholder", comment: "") : name)
                        .font(DS.Typography.body)
                        .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(reduceMotion ? nil : .smooth(duration: 0.15), value: name)
                    Spacer()
                }
                .padding()

                SubsectionDivider()

                // Amount field mock
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        Text("S/")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text("\(amountValue)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: Double(amountValue)))
                            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: amountValue)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - period mock

    private var periodMock: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.period.type", comment: "")) {
            Picker(NSLocalizedString("budgets.editor.period.type", comment: ""), selection: $selectedPeriodType) {
                Text(NSLocalizedString("budgets.period.weekly", comment: "")).tag(BudgetPeriodType.weekly)
                Text(NSLocalizedString("budgets.period.monthly", comment: "")).tag(BudgetPeriodType.monthly)
                Text(NSLocalizedString("budgets.period.yearly", comment: "")).tag(BudgetPeriodType.yearly)
                Text(NSLocalizedString("budgets.period.unique", comment: "")).tag(BudgetPeriodType.unique)
            }
            .pickerStyle(.segmented)
            .allowsHitTesting(false)
            .padding()
        }
    }

    // MARK: - alerts mock

    private var alertsMock: some View {
        SectionBox(title: L10n.Budgets.alertsTitle) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: $alertEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.secondary)
                        Text(L10n.Budgets.alertsEnable)
                    }
                }
                .allowsHitTesting(false)
                .padding()

                if alertEnabled {
                    SubsectionDivider()

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.Budgets.alertsThresholds)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.sm)

                        FlowLayout(spacing: DS.Spacing.sm) {
                            ForEach([50, 75, 80, 90, 100], id: \.self) { threshold in
                                thresholdChip(threshold)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.md)

                        Text(alertCaption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Budget filter banner (replica ContextualGuideBanner.budgetFilterInfo)

    private var budgetFilterBannerMock: some View {
        let message: String
        if selectedFilterAccount == nil && selectedFilterSubcategory == nil {
            message = L10n.ContextualGuide.BudgetFilter.allExpenses
        } else {
            // Compone summary tipo "1 cuenta, Comida"
            var parts: [String] = []
            if selectedFilterAccount != nil {
                parts.append("1 \(NSLocalizedString("settings.accounts", comment: "").lowercased())")
            }
            if let sub = selectedFilterSubcategory {
                parts.append(sub)
            }
            message = parts.joined(separator: ", ")
        }
        return ContextualGuideBanner.budgetFilterInfo(message: message)
    }

    // MARK: - filters mock (replica fiel de BudgetEditorView.filtersSection)

    private var filtersMock: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.filters", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                filterSubsection(
                    icon: "creditcard",
                    title: NSLocalizedString("settings.accounts", comment: ""),
                    statusText: selectedFilterAccount == nil ? NSLocalizedString("filters.all", comment: "") : "1/3",
                    chips: [
                        ("Personal", Color.electricIndigo),
                        ("Ahorros", Color.priorityNeed),
                        ("Tarjeta", Color.hotPink),
                    ],
                    selected: selectedFilterAccount
                )

                Divider().padding(.leading, DS.Spacing.lg)

                filterSubsection(
                    icon: "tag",
                    title: NSLocalizedString("transaction.subcategory", comment: ""),
                    statusText: selectedFilterSubcategory == nil ? NSLocalizedString("filters.all", comment: "") : "1/3",
                    chips: [
                        ("Almuerzo", Color.essentialNeed),
                        ("Restaurante", Color.priorityNeed),
                        ("Café", Color.priorityNeedNew),
                    ],
                    selected: selectedFilterSubcategory
                )
            }
        }
    }

    private func filterSubsection(
        icon: String,
        title: String,
        statusText: String,
        chips: [(String, Color)],
        selected: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header replica FilterSectionHeader
            FilterSectionHeader(icon: icon, title: title, status: statusText)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            // Chips en FlowLayout — igual al filtersSection real
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    filterChip(chip.0, color: chip.1, isSelected: chip.0 == selected)
                }
            }
            .padding(.leading, DS.Spacing.formIndent)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    /// Chip replica fiel de `BudgetEditorView.accountChip` (sin scaleEffect — no existe en el real).
    private func filterChip(_ label: String, color: Color, isSelected: Bool) -> some View {
        Text(label)
            .font(DS.Typography.subheadline)
            .foregroundStyle(isSelected ? .white : .primary)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.tertiarySystemFill))
            )
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isSelected)
    }

    private func thresholdChip(_ threshold: Int) -> some View {
        let isSelected = selectedThresholds.contains(threshold)
        return Text("\(threshold)%")
            .font(DS.Typography.subheadline)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.accent : Color.primary.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isSelected)
    }

    // MARK: - Save button mock

    private var saveButtonMock: some View {
        Button {
            // no-op
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

    // MARK: - Toast + Restart

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
        .background(Capsule().fill(.thCard))
        .overlay(Capsule().stroke(demoAccent.opacity(0.5), lineWidth: 1.5))
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
            .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.SetupChecklist.Demo.restart)
    }

    // MARK: - Progress bar + CTA

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

    // MARK: - Script

    @MainActor
    private func cacheL10n() {
        nameExample = L10n.SetupChecklist.Demo.budgetNameExample
        amountExample = L10n.SetupChecklist.Demo.firstBudgetAmountExample
        alertCaption = L10n.SetupChecklist.Demo.budgetAlertCaption
        savedToastText = L10n.SetupChecklist.Demo.firstBudgetSavedToast
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
        // Stage 0: idle 500ms
        await advance(to: 0.05)
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 1: typing "Comida" (~180ms por letra)
        for index in 1...nameExample.count {
            guard !Task.isCancelled else { return }
            name = String(nameExample.prefix(index))
            try? await Task.sleep(for: .milliseconds(180))
            await advance(to: 0.05 + (0.18 * Double(index) / Double(nameExample.count)))
        }
        try? await Task.sleep(for: .milliseconds(300))

        // Stage 2: monto 0 → 500 (mock target)
        let amounts = [50, 200, 500]
        for (idx, value) in amounts.enumerated() {
            guard !Task.isCancelled else { return }
            amountValue = value
            try? await Task.sleep(for: .milliseconds(400))
            await advance(to: 0.23 + 0.12 * Double(idx + 1) / Double(amounts.count))
        }
        try? await Task.sleep(for: .milliseconds(400))

        // Stage 3: period cycling weekly → monthly → yearly → monthly (final)
        let periods: [BudgetPeriodType] = [.weekly, .monthly, .yearly, .monthly]
        for (idx, period) in periods.enumerated() {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                selectedPeriodType = period
            }
            try? await Task.sleep(for: .milliseconds(500))
            await advance(to: 0.45 + 0.15 * Double(idx + 1) / Double(periods.count))
        }
        try? await Task.sleep(for: .milliseconds(300))

        // Stage 4: alert + threshold 80
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            alertEnabled = true
        }
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            selectedThresholds = [80]
        }
        await advance(to: 0.7)
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 5: filters — selección de cuenta "Personal" + subcategoría "Almuerzo"
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            selectedFilterAccount = "Personal"
        }
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            selectedFilterSubcategory = "Almuerzo"
        }
        await advance(to: 0.85)
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 6: SaveButton enabled
        guard !Task.isCancelled else { return }
        saveButtonEnabled = true
        await advance(to: 0.93)
        try? await Task.sleep(for: .milliseconds(600))

        // Stage 6: toast
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            showSuccessToast = true
        }
        await advance(to: 1.0)
        try? await Task.sleep(for: .milliseconds(900))
    }

    @MainActor
    private func advance(to target: Double) async {
        withAnimation(reduceMotion ? nil : .linear(duration: 0.2)) {
            progress = min(target, 1.0)
        }
    }

    @MainActor
    private func applyFinalState() {
        name = nameExample
        amountValue = 500
        selectedPeriodType = .monthly
        alertEnabled = true
        selectedThresholds = [80]
        selectedFilterAccount = "Personal"
        selectedFilterSubcategory = "Almuerzo"
        saveButtonEnabled = true
        showSuccessToast = true
    }

    @MainActor
    private func resetState(keepCompleted: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            name = ""
            amountValue = 0
            selectedPeriodType = .monthly
            alertEnabled = false
            selectedThresholds = []
            selectedFilterAccount = nil
            selectedFilterSubcategory = nil
            saveButtonEnabled = false
            showSuccessToast = false
        }
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
