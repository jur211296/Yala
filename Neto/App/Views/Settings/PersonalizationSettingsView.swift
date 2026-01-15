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

    @State private var showingPeriodPicker = false
    @State private var showingTabBarConfig = false

    private var selectedPeriod: DetailPeriod {
        DetailPeriod(rawValue: defaultPeriodRaw) ?? .thisMonth
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.bottom, 8)

                        Text(L10n.Settings.personalization)
                            .font(.title2.bold())
                            .foregroundStyle(Color.netoPrimaryText)

                        Text(L10n.Settings.personalizationDescription)
                            .font(.body)
                            .foregroundStyle(Color.netoSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Tab Bar Configuration Section
                    VStack(alignment: .leading, spacing: 8) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
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
                    VStack(alignment: .leading, spacing: 8) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.Settings.colorfulIcons)
                                .font(.body)
                                .foregroundStyle(Color.netoPrimaryText)

                            Spacer()

                            Toggle("", isOn: $colorfulIcons)
                                .labelsHidden()
                                .tint(Color.brandPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if period != DetailPeriod.allCases.last {
            Divider()
                .padding(.leading, 16)
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environment(SessionState())
    }
}
