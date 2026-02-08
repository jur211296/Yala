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
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()

    @State private var localConfig: TabBarConfiguration = .default

    private var canDeactivate: Bool {
        localConfig.activeTabs.count > 1
    }

    private var canActivate: Bool {
        localConfig.activeTabs.count < 3
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.tabBarConfig)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Action.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.save) {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            localConfig = TabBarConfiguration.fromJSON(tabConfigJSON)
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundStyle(Color.electricIndigo)

            Text(L10n.Settings.tabBarConfigInfo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.electricIndigo.opacity(0.1))
        )
    }

    // MARK: - Active Tabs Section (Reorderable)

    private var activeTabsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Settings.tabBarConfigActive)
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(0.6))

                Spacer()

                Text("\(localConfig.activeTabs.count)/3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            List {
                ForEach(Array(localConfig.activeTabs.enumerated()), id: \.element) { index, tab in
                    activeTabRow(tab, position: index + 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.yalaCard)
                        .listRowSeparator(index == localConfig.activeTabs.count - 1 ? .hidden : .visible)
                }
                .onMove(perform: moveTab)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(localConfig.activeTabs.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 20)

            // Tab icon
            Image(systemName: tab.iconName)
                .font(.body)
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 28, height: 28)

            // Tab name
            Text(tab.displayName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Panel is locked (always first, cannot remove)
            if tab == .panel {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if canDeactivate {
                // Remove button for other tabs
                Button {
                    removeTab(tab)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
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
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(localConfig.inactiveTabs.enumerated()), id: \.element) { index, tab in
                    availableTabRow(tab)

                    if index < localConfig.inactiveTabs.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)

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
                .font(.body)
                .foregroundStyle(Color.secondary)
                .frame(width: 28, height: 28)
                .padding(.leading, 20) // Align with active tabs

            // Tab name
            Text(tab.displayName)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            // Add button
            Button {
                addTab(tab)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canActivate ? Color.electricIndigo : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canActivate)
            .accessibilityHint(!canActivate ? "Límite de pestañas alcanzado" : "")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    private func validationMessage(_ text: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 6)
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
        tabConfigJSON = localConfig.toJSON()
        dismiss()
    }
}

#Preview {
    TabBarConfigView()
}
