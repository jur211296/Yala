//
//  TabBarConfigView.swift
//  Yala
//
//  Configure which tabs appear in the main TabView.
//  Min 1, Max 3 tabs (plus More which is always visible).
//

import SwiftUI

struct TabBarConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var localConfig: TabBarConfiguration = .default

    private var canDeactivate: Bool {
        localConfig.activeTabs.count > 1
    }

    private var canActivate: Bool {
        localConfig.activeTabs.count < 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                        infoHeader
                        activeTabsSection
                        if !localConfig.inactiveTabs.isEmpty {
                            availableTabsSection
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle(L10n.Settings.tabBarConfig)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { saveAndDismiss() }, accessibilityID: "tabconfig_save")
                }
            }
        }
        .onAppear {
            localConfig = TabBarConfiguration.fromJSON(appPreferences.tabConfigJSON)
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)

            Text(L10n.Settings.tabBarConfigInfo)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.accent.opacity(0.1))
        )
    }

    // MARK: - Active Tabs Section (Reorderable)

    private var activeTabsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Settings.tabBarConfigActive)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.primary.opacity(0.6))

                Spacer()

                Text("\(localConfig.activeTabs.count)/3")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Chip.paddingV)

            List {
                ForEach(Array(localConfig.activeTabs.enumerated()), id: \.element) { index, tab in
                    activeTabRow(tab, position: index + 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(index == localConfig.activeTabs.count - 1 ? .hidden : .visible)
                }
                .onMove(perform: moveTab)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(localConfig.activeTabs.count) * DS.FormRow.minHeight)
            .solidCard()
            .environment(\.editMode, .constant(.active))

            // Validation message
            if !canDeactivate {
                validationMessage(L10n.Settings.tabBarConfigMinWarning, icon: "exclamationmark.circle")
            }
        }
    }

    private func activeTabRow(_ tab: ConfigurableTab, position: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Position indicator
            Text("\(position)")
                .font(DS.Typography.captionMonoBold)
                .foregroundStyle(.thAccent)
                .frame(width: 20)

            // Tab icon
            Image(systemName: tab.iconName)
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
                .frame(width: 28, height: 28)

            // Tab name
            Text(tab.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            // Panel is locked (always first, cannot remove)
            if tab == .panel {
                Image(systemName: "lock.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            } else if canDeactivate {
                // Remove button for other tabs
                Button {
                    removeTab(tab)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Semantic.errorForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Quitar \(tab.displayName)"))
                .accessibilityIdentifier("tabconfig_remove_\(tab.id)")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Available Tabs Section

    private var availableTabsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Settings.tabBarConfigAvailable)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(localConfig.inactiveTabs.enumerated()), id: \.element) { index, tab in
                    availableTabRow(tab)

                    if index < localConfig.inactiveTabs.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.formIndent)
                    }
                }
            }
            .solidCard()

            // Max warning
            if !canActivate {
                validationMessage(L10n.Settings.tabBarConfigMaxWarning, icon: "exclamationmark.circle")
            }
        }
    }

    private func availableTabRow(_ tab: ConfigurableTab) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Tab icon
            Image(systemName: tab.iconName)
                .font(DS.Typography.body)
                .foregroundStyle(Color.secondary)
                .frame(width: 28, height: 28)
                .padding(.leading, DS.Spacing.xl) // Align with active tabs

            // Tab name
            Text(tab.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            // Add button
            Button {
                addTab(tab)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.title)
                    .foregroundStyle(canActivate ? theme.accent : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canActivate)
            .accessibilityHint(!canActivate ? L10n.Accessibility.tabLimitReached : "")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    private func validationMessage(_ text: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Semantic.warningForeground)

            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, DS.Chip.paddingV)
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Actions

    private func moveTab(from source: IndexSet, to destination: Int) {
        // Prevent moving panel from first position
        if source.contains(0) { return }
        // Prevent moving other tabs to first position (before panel)
        if destination == 0 { return }

        dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
            localConfig.activeTabs.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func addTab(_ tab: ConfigurableTab) {
        dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
            _ = localConfig.activate(tab)
        }
    }

    private func removeTab(_ tab: ConfigurableTab) {
        dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
            _ = localConfig.deactivate(tab)
        }
    }

    private func saveAndDismiss() {
        appPreferences.tabConfigJSON = localConfig.toJSON()
        dismiss()
    }
}

#Preview {
    TabBarConfigView()
        .previewAppPreferences()
}
