//
//  PersonalizationSettingsView.swift
//  Neto
//
//  Personalization settings sheet with default period selector.
//

import SwiftUI

struct PersonalizationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState

    @AppStorage("defaultPeriod") private var defaultPeriodRaw: String = DetailPeriod.allTime
        .rawValue
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue
    @AppStorage("colorfulIcons") private var colorfulIcons: Bool = true
    @AppStorage("firstWeekday") private var firstWeekdayRaw: Int = 2  // Default to Monday
    @AppStorage("showWidgetHints") private var showWidgetHints: Bool = true
    @AppStorage("useRoundedAmounts") private var useRoundedAmounts: Bool = true

    @State private var showingPeriodPicker = false
    @State private var showingTabBarConfig = false
    @State private var showingWeekdayPicker = false

    private var selectedPeriod: DetailPeriod {
        DetailPeriod(rawValue: defaultPeriodRaw) ?? .thisMonth
    }

    private var selectedWeekday: FirstWeekday {
        FirstWeekday(rawValue: firstWeekdayRaw) ?? .monday
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.personalization)
                            .font(.title2.bold())
                            .foregroundStyle(Color.netoPrimaryText)

                        Text(L10n.Settings.personalizationDescription)
                            .font(.body)
                            .foregroundStyle(Color.netoSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // Tab Bar Configuration Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Button {
                            showingTabBarConfig = true
                        } label: {
                            HStack {
                                Text(L10n.Settings.tabBarConfig)
                                    .font(.body)
                                    .foregroundStyle(Color.netoPrimaryText)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .background(Color.netoCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Text(L10n.Settings.tabBarConfigInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    // Default Period Section - Single Row Style
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        // Period Row
                        Button {
                            showingPeriodPicker = true
                        } label: {
                            HStack {
                                Text(L10n.Settings.defaultPeriod)
                                    .font(.body)
                                    .foregroundStyle(Color.netoPrimaryText)

                                Spacer()

                                Text(selectedPeriod.displayName)
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .background(Color.netoCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // Explanatory text
                        Text(
                            L10n.Settings.defaultPeriodDescription
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }

                    // Colorful Icons Toggle Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(L10n.Settings.colorfulIcons)
                                .font(.body)
                                .foregroundStyle(Color.netoPrimaryText)

                            Spacer()

                            Toggle("", isOn: $colorfulIcons)
                                .labelsHidden()
                                .tint(Color.brandPrimary)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Color.netoCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                        Text(
                            L10n.Settings.colorfulIconsDescription
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }

                    // First Weekday Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Button {
                            showingWeekdayPicker = true
                        } label: {
                            HStack {
                                Text(L10n.Settings.firstWeekday)
                                    .font(.body)
                                    .foregroundStyle(Color.netoPrimaryText)

                                Spacer()

                                Text(selectedWeekday.displayName)
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .background(Color.netoCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Text(L10n.Settings.firstWeekdayDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    // Widget Hints Toggle Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(L10n.Settings.widgetHints)
                                .font(.body)
                                .foregroundStyle(Color.netoPrimaryText)

                            Spacer()

                            Toggle("", isOn: $showWidgetHints)
                                .labelsHidden()
                                .tint(Color.brandPrimary)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Color.netoCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                        Text(L10n.Settings.widgetHintsDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    // Rounded Amounts Toggle Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(L10n.Settings.roundedAmounts)
                                .font(.body)
                                .foregroundStyle(Color.netoPrimaryText)

                            Spacer()

                            Toggle("", isOn: $useRoundedAmounts)
                                .labelsHidden()
                                .tint(Color.brandPrimary)
                                .onChange(of: useRoundedAmounts) { _, _ in
                                    // Trigger UI refresh for all views showing formatted amounts
                                    SessionState.shared.formattingVersion += 1
                                }
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Color.netoCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                        Text(L10n.Settings.roundedAmountsDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(L10n.Settings.personalization)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingPeriodPicker) {
            PeriodPickerSheet(
                selectedPeriod: selectedPeriod,
                onSelect: { period in
                    defaultPeriodRaw = period.rawValue
                    sessionState.selectedPeriod = period
                    showingPeriodPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingTabBarConfig) {
            TabBarConfigView()
        }
        .sheet(isPresented: $showingWeekdayPicker) {
            WeekdayPickerSheet(
                selectedWeekday: selectedWeekday,
                onSelect: { weekday in
                    firstWeekdayRaw = weekday.rawValue
                    // Force recalculation of dateInterval with new firstWeekday
                    let currentPeriod = sessionState.selectedPeriod
                    sessionState.selectedPeriod = currentPeriod
                    showingWeekdayPicker = false
                }
            )
            .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Period Picker Sheet

private struct PeriodPickerSheet: View {
    let selectedPeriod: DetailPeriod
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(DetailPeriod.allCases) { period in
                            periodRow(for: period)
                        }
                    }
                    .background(Color.netoCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .padding()
                }
            }
            .navigationTitle(L10n.Settings.defaultPeriod)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func periodRow(for period: DetailPeriod) -> some View {
        let isSelected = selectedPeriod == period

        Button {
            onSelect(period)
        } label: {
            HStack {
                Text(period.displayName)
                    .font(.body)
                    .foregroundStyle(Color.netoPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if period != DetailPeriod.allCases.last {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Weekday Picker Sheet

private struct WeekdayPickerSheet: View {
    let selectedWeekday: FirstWeekday
    let onSelect: (FirstWeekday) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(FirstWeekday.allCases) { weekday in
                            weekdayRow(for: weekday)
                        }
                    }
                    .background(Color.netoCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .padding()
                }
            }
            .navigationTitle(L10n.Settings.firstWeekday)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func weekdayRow(for weekday: FirstWeekday) -> some View {
        let isSelected = selectedWeekday == weekday

        Button {
            onSelect(weekday)
        } label: {
            HStack {
                Text(weekday.displayName)
                    .font(.body)
                    .foregroundStyle(Color.netoPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if weekday != FirstWeekday.allCases.last {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environment(SessionState())
    }
}
