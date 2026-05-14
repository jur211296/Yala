//
//  SetupDemoScheduledPaymentView.swift
//  Yala
//
//  Demo standalone educativa del Step 4 (scheduledPayment) del Setup Checklist.
//  Replica chrome del ScheduledPaymentEditorView reusando SectionBox + Picker
//  segmented + ContextualGuideBanner.scheduledEditor() + SetupDemoMockSelectorSheet
//  con context `.subscriptions`. Clímax visual: stagger de 3 fechas preview que
//  emergen una a una. SwiftUI puro sin SwiftData.
//

import SwiftUI

struct SetupDemoScheduledPaymentView: View {

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
    @State private var selectedSubcategory: String? = nil
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: String = "monthly"  // .monthly default
    @State private var previewDates: [Date] = []
    @State private var saveButtonEnabled: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var activeMockSheet: SetupDemoMockSheet? = nil

    // Completion state
    @State private var demoCompleted: Bool = false
    @State private var progress: Double = 0
    @State private var ctaPulse: Bool = false

    // Cached L10n
    @State private var nameExample: String = ""
    @State private var amountExample: String = ""
    @State private var subcategoryExample: String = ""
    @State private var notifCaption: String = ""
    @State private var savedToastText: String = ""

    private var demoAccent: Color { Color.electricIndigo }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                mainContent
            }
            .navigationTitle(NSLocalizedString("scheduled.new", comment: ""))
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
                targetValue: subcategoryExample,
                categoryContext: .subscriptions,
                reduceMotion: reduceMotion,
                onSelected: { selectedSubcategory = subcategoryExample }
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
        mockScroll
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

    // MARK: - Mock ScheduledPaymentEditorView

    private var mockScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    ContextualGuideBanner.scheduledEditor()

                    basicInfoMock
                    classificationMock
                    recurrenceMock
                        .id("recurrence")

                    if !previewDates.isEmpty {
                        previewMock
                            .id("preview")
                            .transition(reduceMotion ? .opacity : .opacity)
                    }

                    notificationsMock
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

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .onChange(of: selectedSubcategory) { _, newValue in
                if newValue != nil {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
                        proxy.scrollTo("recurrence", anchor: .top)
                    }
                }
            }
            .onChange(of: previewDates.count) { _, newValue in
                // Cuando emergen las 3 fechas, scroll a bottom para anticipar el final
                if newValue >= 3 {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
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

    // MARK: - basicInfo mock

    private var basicInfoMock: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.basic.info", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Tipo segmented (Gasto / Ingreso) — siempre Gasto en demo
                Picker("", selection: .constant("expense")) {
                    Text(NSLocalizedString("transaction.type.expense", comment: "")).tag("expense")
                    Text(NSLocalizedString("transaction.type.income", comment: "")).tag("income")
                }
                .pickerStyle(.segmented)
                .allowsHitTesting(false)
                .padding()

                SubsectionDivider()

                // Name
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    Text(name.isEmpty ? NSLocalizedString("scheduled.editor.name.placeholder", comment: "") : name)
                        .font(DS.Typography.body)
                        .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(reduceMotion ? nil : .smooth(duration: 0.15), value: name)
                    Spacer()
                }
                .padding()

                SubsectionDivider()

                // Amount
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

    // MARK: - classification mock (chip subcategoría que abre sheet)

    private var classificationMock: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.classification", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("transaction.subcategory", comment: ""))
                        .font(DS.Typography.body)

                    Spacer()

                    if let sub = selectedSubcategory {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "play.rectangle.fill")
                                .font(DS.Typography.labelTiny)
                            Text(sub)
                                .font(DS.Typography.labelTiny)
                        }
                        .foregroundStyle(Color.essentialNeed)
                        .padding(.horizontal, DS.Chip.paddingH)
                        .padding(.vertical, DS.Chip.paddingV)
                        .background(
                            Capsule().fill(Color.essentialNeed.opacity(0.12))
                        )
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    } else {
                        Text(NSLocalizedString("common.none", comment: ""))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - recurrence mock (replica recurrenceSection real)

    private var recurrenceMock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Scheduled.Editor.recurrence)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
            }
            .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                Picker("", selection: $isRecurring) {
                    Text(NSLocalizedString("scheduled.recurrence.onetime", comment: "")).tag(false)
                    Text(NSLocalizedString("scheduled.recurrence.recurring", comment: "")).tag(true)
                }
                .pickerStyle(.segmented)
                .allowsHitTesting(false)
                .padding()

                if isRecurring {
                    SubsectionDivider()

                    // Interval row mock: "Cada 1 mes"
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "repeat")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(NSLocalizedString("scheduled.recurrence.interval", comment: ""))
                            .font(DS.Typography.body)
                        Spacer()
                        Text(NSLocalizedString("scheduled.recurrence.monthly", comment: ""))
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    SubsectionDivider()

                    // Day of month mock
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(NSLocalizedString("scheduled.day.of.month", comment: ""))
                            .font(DS.Typography.body)
                        Spacer()
                        Text("1")
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .solidCard()
        }
    }

    // MARK: - preview mock (clímax visual con stagger)

    private var previewMock: some View {
        SectionBox(title: L10n.Scheduled.Editor.preview) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(previewDates.enumerated()), id: \.offset) { index, date in
                    previewDateRow(date, index: index + 1)
                    if index < previewDates.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
        }
    }

    private func previewDateRow(_ date: Date, index: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(date, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(date, format: .dateTime.month(.abbreviated))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                Text("#\(index)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
    }

    // MARK: - notifications mock

    private var notificationsMock: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.notifications", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: .constant(true)) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "bell")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(NSLocalizedString("scheduled.notify.on.due", comment: ""))
                    }
                }
                .allowsHitTesting(false)
                .padding()

                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(NSLocalizedString("scheduled.notify.days.before", comment: ""))
                        .font(DS.Typography.body)
                    Spacer()
                    Text("3")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .padding()

                if !previewDates.isEmpty {
                    SubsectionDivider()

                    Text(notifCaption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Save button mock

    private var saveButtonMock: some View {
        Button {} label: {
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
        nameExample = L10n.SetupChecklist.Demo.scheduledNameExample
        amountExample = L10n.SetupChecklist.Demo.scheduledPaymentAmountExample
        subcategoryExample = L10n.SetupChecklist.Demo.scheduledPaymentSubcategoryExample
        notifCaption = L10n.SetupChecklist.Demo.scheduledNotifCaption
        savedToastText = L10n.SetupChecklist.Demo.scheduledPaymentSavedToast
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
        // Stage 0: idle
        await advance(to: 0.05)
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 1: typing "Netflix"
        for index in 1...nameExample.count {
            guard !Task.isCancelled else { return }
            name = String(nameExample.prefix(index))
            try? await Task.sleep(for: .milliseconds(230))
            await advance(to: 0.05 + (0.15 * Double(index) / Double(nameExample.count)))
        }
        try? await Task.sleep(for: .milliseconds(400))

        // Stage 2: monto 0 → 45
        let amounts = [15, 45]
        for (idx, value) in amounts.enumerated() {
            guard !Task.isCancelled else { return }
            amountValue = value
            try? await Task.sleep(for: .milliseconds(500))
            await advance(to: 0.20 + 0.10 * Double(idx + 1) / Double(amounts.count))
        }
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 3: subcategoría sheet (.subscriptions, target "Streaming")
        guard !Task.isCancelled else { return }
        activeMockSheet = .subcategory
        try? await Task.sleep(for: .milliseconds(2500))
        guard !Task.isCancelled else { return }
        if activeMockSheet == .subcategory {
            activeMockSheet = nil
            try? await Task.sleep(for: .milliseconds(400))
        }
        await advance(to: 0.5)
        try? await Task.sleep(for: .milliseconds(500))

        // Stage 4: isRecurring = true (segmented switch)
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            isRecurring = true
        }
        await advance(to: 0.62)
        try? await Task.sleep(for: .milliseconds(750))

        // Stage 5: preview dates stagger 3 fechas
        let calendar = Calendar.current
        let now = Date()
        let nextDates: [Date] = (1...3).compactMap { month in
            calendar.date(byAdding: .month, value: month, to: now)
        }
        for (idx, date) in nextDates.enumerated() {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                previewDates.append(date)
            }
            try? await Task.sleep(for: .milliseconds(350))
            await advance(to: 0.70 + 0.10 * Double(idx + 1) / Double(nextDates.count))
        }
        try? await Task.sleep(for: .milliseconds(700))

        // Stage 6: SaveButton enabled
        guard !Task.isCancelled else { return }
        saveButtonEnabled = true
        await advance(to: 0.93)
        try? await Task.sleep(for: .milliseconds(800))

        // Stage 7: toast
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            showSuccessToast = true
        }
        await advance(to: 1.0)
        try? await Task.sleep(for: .milliseconds(1200))
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
        amountValue = 45
        selectedSubcategory = subcategoryExample
        isRecurring = true
        let calendar = Calendar.current
        previewDates = (1...3).compactMap { calendar.date(byAdding: .month, value: $0, to: Date()) }
        saveButtonEnabled = true
        showSuccessToast = true
    }

    @MainActor
    private func resetState(keepCompleted: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            name = ""
            amountValue = 0
            selectedSubcategory = nil
            isRecurring = false
            previewDates = []
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
